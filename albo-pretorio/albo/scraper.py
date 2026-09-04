"""Estrazione degli atti: scarica l'elenco pagina per pagina, l'export CSV e i dettagli.

Uso da riga di comando::

    python -m albo.scraper --sezione papca-ap --formato json --out atti.json
    python -m albo.scraper --demo            # usa le pagine di esempio in tests/fixtures
"""

from __future__ import annotations

import argparse
import csv
import json
import logging
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Callable
from urllib.parse import parse_qs, urlparse

import requests

from . import config
from .parser import CHIAVI_PRINCIPALI, chiave_allegato, parse_csv, parse_dettaglio, parse_lista

log = logging.getLogger("albo")

Progresso = Callable[[dict], None]


class Recuperatore:
    """Scarica URL con sessione, riprova e pausa tra le richieste."""

    def __init__(self, base_url: str = config.BASE_URL, pausa: float = config.PAUSA,
                 timeout: float = config.TIMEOUT, tentativi: int = 3, sessione: requests.Session | None = None):
        self.base_url = base_url
        self.pausa = pausa
        self.timeout = timeout
        self.tentativi = tentativi
        self.sessione = sessione or requests.Session()
        self.sessione.headers.update({
            "User-Agent": config.USER_AGENT,
            "Accept-Language": "it-IT,it;q=0.9",
            "Accept": "text/html,application/xhtml+xml,text/csv,*/*;q=0.8",
        })
        self._ultima = 0.0
        self.richieste = 0

    def get(self, url: str) -> requests.Response:
        errore: Exception | None = None
        for tentativo in range(1, self.tentativi + 1):
            attesa = self.pausa - (time.monotonic() - self._ultima)
            if attesa > 0:
                time.sleep(attesa)
            try:
                self._ultima = time.monotonic()
                self.richieste += 1
                r = self.sessione.get(url, timeout=self.timeout)
                if r.status_code >= 500:
                    raise requests.HTTPError(f"HTTP {r.status_code}", response=r)
                r.raise_for_status()
                return r
            except (requests.RequestException, OSError) as e:  # noqa: PERF203
                errore = e
                log.warning("tentativo %d/%d fallito per %s: %s", tentativo, self.tentativi, url, e)
                time.sleep(min(2 ** tentativo, 10))
        raise RuntimeError(f"impossibile scaricare {url}: {errore}")

    def testo(self, url: str) -> str:
        r = self.get(url)
        if not r.encoding or r.encoding.lower() in ("iso-8859-1", "latin-1"):
            r.encoding = r.apparent_encoding or "utf-8"
        return r.text

    def contenuto(self, url: str) -> bytes:
        return self.get(url).content


class Estrattore:
    """Orchestra l'estrazione completa di una sezione dell'albo."""

    def __init__(self, base_url: str = config.BASE_URL, recuperatore: Recuperatore | None = None,
                 righe: int = config.RIGHE_PER_PAGINA, max_pagine: int = config.MAX_PAGINE,
                 thread_dettagli: int = config.THREAD_DETTAGLI, progresso: Progresso | None = None):
        self.base_url = base_url.rstrip("/")
        self.rec = recuperatore or Recuperatore(self.base_url)
        self.righe = righe
        self.max_pagine = max_pagine
        self.thread_dettagli = max(1, thread_dettagli)
        self.progresso = progresso or (lambda _info: None)
        self.errori: list[str] = []

    # ---- elenco -------------------------------------------------------------------------------

    def elenco(self, sezione: str) -> tuple[list[dict], dict]:
        """Scorre tutte le pagine dell'elenco. Restituisce (atti, statistiche)."""
        atti: list[dict] = []
        visti: set[str] = set()
        url_visti: set[str] = set()
        url = config.url_pagina_lista(sezione, 1, self.righe, self.base_url)
        pagina = 1
        dimensione_prima_pagina = None
        strategia = "nessuna"
        totale_dichiarato = None
        while pagina <= self.max_pagine:
            if url in url_visti:
                break
            url_visti.add(url)
            log.info("pagina %d: %s", pagina, url)
            html = self.rec.testo(url)
            ris = parse_lista(html, self.base_url, sezione, url)
            if ris["strategia"] != "nessuna":
                strategia = ris["strategia"]
            pag = ris["paginazione"]
            totale_dichiarato = totale_dichiarato or pag.get("totale")
            nuovi = [a for a in ris["atti"] if a["id"] not in visti]
            if not nuovi:
                log.info("nessun atto nuovo nella pagina %d: fine dell'elenco", pagina)
                break
            for a in nuovi:
                visti.add(a["id"])
                atti.append(a)
            if dimensione_prima_pagina is None:
                dimensione_prima_pagina = len(ris["atti"])
            self.progresso({"fase": "elenco", "pagina": pagina, "atti": len(atti),
                            "totale": totale_dichiarato, "pagine": pag.get("pagine")})

            # condizioni di fine
            if pag.get("pagine") and pagina >= pag["pagine"]:
                break
            if totale_dichiarato and len(atti) >= totale_dichiarato:
                break
            if not pag.get("url_successiva"):
                if not pag.get("pagine") and not totale_dichiarato and len(ris["atti"]) < dimensione_prima_pagina:
                    break
            pagina += 1
            if pag.get("url_successiva"):
                url = pag["url_successiva"]
            else:
                url = config.url_pagina_lista(sezione, pagina, self.righe, self.base_url)
        stat = {"pagine": pagina if atti else 0, "atti_elenco": len(atti), "strategia": strategia,
                "totale_dichiarato": totale_dichiarato}
        return atti, stat

    # ---- csv -----------------------------------------------------------------------------------

    def csv(self, sezione: str) -> list[dict]:
        url = config.url_export_csv(sezione, self.base_url)
        log.info("export csv: %s", url)
        r = self.rec.get(url)
        tipo = (r.headers.get("Content-Type") or "").lower()
        contenuto = r.content
        if "html" in tipo and b"<html" in contenuto[:2000].lower():
            raise RuntimeError("l'export CSV ha restituito una pagina HTML (funzione non disponibile?)")
        return parse_csv(contenuto, sezione)

    # ---- dettaglio ---------------------------------------------------------------------------

    def dettaglio(self, sezione: str, atto: dict) -> dict:
        url = atto.get("url") or config.url_dettaglio(sezione, atto["id"], self.base_url)
        html = self.rec.testo(url)
        return parse_dettaglio(html, self.base_url, sezione, url)

    # ---- fusione -------------------------------------------------------------------------------

    @staticmethod
    def fondi(destinazione: dict, sorgente: dict) -> dict:
        """Completa `destinazione` con i campi di `sorgente` senza sovrascrivere quelli già noti."""
        for k in CHIAVI_PRINCIPALI + ["url"]:
            if not destinazione.get(k) and sorgente.get(k):
                destinazione[k] = sorgente[k]
        # un id sintetico (h-…) viene sostituito da quello vero della piattaforma
        id_dest, id_sorg = str(destinazione.get("id") or ""), str(sorgente.get("id") or "")
        if id_sorg and id_dest.startswith("h-") and not id_sorg.startswith("h-"):
            destinazione["id"] = id_sorg
        noti = {chiave_allegato(a["url"]) for a in destinazione.get("allegati", [])}
        for al in sorgente.get("allegati", []):
            chiave = chiave_allegato(al["url"])
            if chiave not in noti:
                destinazione.setdefault("allegati", []).append(al)
                noti.add(chiave)
        for k, v in sorgente.get("altri_campi", {}).items():
            destinazione.setdefault("altri_campi", {}).setdefault(k, v)
        return destinazione

    @staticmethod
    def _chiavi_corrispondenza(a: dict) -> list[str]:
        chiavi = []
        if a.get("numero"):
            chiavi.append("n:" + a["numero"].strip().lower())
        if a.get("oggetto"):
            chiavi.append("o:" + a["oggetto"].strip().lower()[:120] + "|" + (a.get("data_inizio") or ""))
        return chiavi

    def integra_csv(self, atti: list[dict], atti_csv: list[dict]) -> int:
        """Arricchisce gli atti dell'elenco con i campi del CSV; aggiunge quelli mancanti."""
        indice: dict[str, dict] = {}
        for a in atti:
            for k in self._chiavi_corrispondenza(a):
                indice.setdefault(k, a)
        aggiunti = 0
        for c in atti_csv:
            bersaglio = None
            for k in self._chiavi_corrispondenza(c):
                if k in indice:
                    bersaglio = indice[k]
                    break
            if bersaglio is None:
                atti.append(c)
                aggiunti += 1
                for k in self._chiavi_corrispondenza(c):
                    indice.setdefault(k, c)
            else:
                self.fondi(bersaglio, c)
        return aggiunti

    # ---- estrazione completa -----------------------------------------------------------------

    def estrai(self, sezione: str = config.SEZIONE_PREDEFINITA, con_dettagli: bool = True,
               con_csv: bool = True) -> dict:
        inizio = time.monotonic()
        self.errori = []
        atti: list[dict] = []
        stat: dict = {"sezione": sezione, "atti_csv": 0, "csv_aggiunti": 0, "dettagli_ok": 0,
                      "dettagli_errore": 0}
        try:
            atti, stat_elenco = self.elenco(sezione)
            stat.update(stat_elenco)
        except Exception as e:  # noqa: BLE001
            log.exception("errore nell'elenco")
            self.errori.append(f"elenco: {e}")
            stat.update({"pagine": 0, "atti_elenco": 0, "strategia": "errore"})

        if con_csv:
            self.progresso({"fase": "csv", "atti": len(atti)})
            try:
                atti_csv = self.csv(sezione)
                stat["atti_csv"] = len(atti_csv)
                stat["csv_aggiunti"] = self.integra_csv(atti, atti_csv)
            except Exception as e:  # noqa: BLE001
                log.warning("export csv non disponibile: %s", e)
                self.errori.append(f"csv: {e}")

        if con_dettagli:
            da_scaricare = [a for a in atti if a.get("url") or not str(a["id"]).startswith("h-")]
            fatti = 0

            def lavoro(a: dict) -> tuple[dict, dict | None, Exception | None]:
                try:
                    return a, self.dettaglio(sezione, a), None
                except Exception as e:  # noqa: BLE001
                    return a, None, e

            with ThreadPoolExecutor(max_workers=self.thread_dettagli) as pool:
                futuri = [pool.submit(lavoro, a) for a in da_scaricare]
                for f in as_completed(futuri):
                    a, det, err = f.result()
                    fatti += 1
                    if det is not None:
                        self.fondi(a, det)
                        stat["dettagli_ok"] += 1
                    else:
                        stat["dettagli_errore"] += 1
                        self.errori.append(f"dettaglio {a['id']}: {err}")
                    if fatti % 5 == 0 or fatti == len(da_scaricare):
                        self.progresso({"fase": "dettagli", "fatti": fatti, "totale": len(da_scaricare),
                                        "atti": len(atti)})

        atti.sort(key=lambda a: (a.get("data_inizio") or "", a.get("numero") or ""), reverse=True)
        stat["atti"] = len(atti)
        stat["richieste"] = getattr(self.rec, "richieste", None)
        stat["durata_s"] = round(time.monotonic() - inizio, 1)
        return {"sezione": sezione, "ente": config.ENTE, "base_url": self.base_url, "atti": atti,
                "statistiche": stat, "errori": self.errori}


# ---- riga di comando -----------------------------------------------------------------------

COLONNE_CSV = ["id", "sezione", "numero", "tipo", "oggetto", "data_inizio", "data_fine", "ente",
               "numero_atto", "data_atto", "anno", "url", "allegati", "altri_campi"]


def scrivi_csv(atti: list[dict], flusso) -> None:
    w = csv.DictWriter(flusso, fieldnames=COLONNE_CSV, delimiter=";", extrasaction="ignore",
                       quoting=csv.QUOTE_ALL)
    w.writeheader()
    for a in atti:
        riga = dict(a)
        riga["allegati"] = " | ".join(f"{x['nome']} <{x['url']}>" for x in a.get("allegati", []))
        riga["altri_campi"] = " | ".join(f"{k}: {v}" for k, v in a.get("altri_campi", {}).items())
        w.writerow(riga)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Estrae gli atti pubblicati sull'albo pretorio (JCityGov).")
    p.add_argument("--sezione", default=config.SEZIONE_PREDEFINITA, choices=sorted(config.SEZIONI),
                   help="sezione dell'albo (predefinita: %(default)s)")
    p.add_argument("--base-url", default=config.BASE_URL, help="indirizzo dell'installazione JCityGov")
    p.add_argument("--senza-dettagli", action="store_true", help="non scaricare le pagine di dettaglio")
    p.add_argument("--senza-csv", action="store_true", help="non usare l'export CSV del portale")
    p.add_argument("--formato", default="json", choices=["json", "csv"])
    p.add_argument("--out", default="-", help="file di uscita (predefinito: standard output)")
    p.add_argument("--demo", action="store_true", help="usa le pagine di esempio invece della rete")
    p.add_argument("-v", "--verbose", action="store_true")
    args = p.parse_args(argv)

    logging.basicConfig(level=logging.INFO if args.verbose else logging.WARNING,
                        format="%(levelname)s %(message)s", stream=sys.stderr)

    if args.demo:
        from .demo import RecuperatoreDemo
        estrattore = Estrattore(args.base_url, recuperatore=RecuperatoreDemo(args.base_url))
    else:
        estrattore = Estrattore(args.base_url)

    def progresso(info: dict) -> None:
        if args.verbose:
            print(json.dumps(info, ensure_ascii=False), file=sys.stderr)

    estrattore.progresso = progresso
    risultato = estrattore.estrai(args.sezione, con_dettagli=not args.senza_dettagli, con_csv=not args.senza_csv)

    flusso = sys.stdout if args.out == "-" else open(args.out, "w", encoding="utf-8", newline="")
    try:
        if args.formato == "json":
            json.dump(risultato, flusso, ensure_ascii=False, indent=2)
            flusso.write("\n")
        else:
            scrivi_csv(risultato["atti"], flusso)
    finally:
        if flusso is not sys.stdout:
            flusso.close()

    stat = risultato["statistiche"]
    print(f"{stat['atti']} atti estratti dalla sezione {args.sezione} "
          f"({stat.get('pagine', 0)} pagine, strategia {stat.get('strategia')}, {stat['durata_s']} s)",
          file=sys.stderr)
    for e in risultato["errori"]:
        print("avviso:", e, file=sys.stderr)
    return 0 if risultato["atti"] else 1


if __name__ == "__main__":
    sys.exit(main())
