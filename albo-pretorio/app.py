"""Web app: interfaccia e API REST sopra l'estrattore dell'albo pretorio.

Avvio::

    python app.py                # http://localhost:8000
    python app.py --demo         # usa le pagine di esempio invece della rete
    python app.py --porta 5000 --host 0.0.0.0
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import logging
import os
import threading
from datetime import datetime, timezone

from flask import Flask, Response, abort, jsonify, request, send_from_directory

from albo import __version__, config
from albo.scraper import COLONNE_CSV, Estrattore, scrivi_csv
from albo.storage import Archivio, adesso

log = logging.getLogger("albo.app")
CARTELLA_STATIC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")


def filtra_atti(atti: list[dict], q: str = "", tipo: str = "", da: str = "", a: str = "",
                solo_pubblicati: bool = False) -> list[dict]:
    """Stesso filtro dell'interfaccia, usato per l'export lato server."""
    parole = [p for p in (q or "").lower().split() if p]
    ris = []
    for atto in atti:
        if solo_pubblicati and not atto.get("in_pubblicazione"):
            continue
        if tipo and (atto.get("tipo") or "") != tipo:
            continue
        if da and (atto.get("data_inizio") or "") < da:
            continue
        if a and (atto.get("data_inizio") or "9999") > a:
            continue
        if parole:
            pagliaio = " ".join(str(v) for v in (atto.get("oggetto"), atto.get("numero"), atto.get("tipo"),
                                                  atto.get("ente"), atto.get("numero_atto"),
                                                  " ".join(atto.get("altri_campi", {}).values()))).lower()
            if not all(p in pagliaio for p in parole):
                continue
        ris.append(atto)
    return ris


class Lavoro:
    """Stato dell'estrazione in corso (una sola alla volta)."""

    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.thread: threading.Thread | None = None
        self.stato: dict = {"in_corso": False, "sezione": None, "progresso": None,
                            "iniziata": None, "conclusa": None, "esito": None, "errore": None}

    def in_corso(self) -> bool:
        return bool(self.thread and self.thread.is_alive())


def crea_app(archivio: Archivio | None = None, demo: bool = False) -> Flask:
    app = Flask(__name__, static_folder=None)
    app.config["JSON_AS_ASCII"] = False
    archivio = archivio or Archivio()
    lavoro = Lavoro()

    def nuovo_estrattore(progresso) -> Estrattore:
        if demo:
            from albo.demo import RecuperatoreDemo
            return Estrattore(config.BASE_URL, recuperatore=RecuperatoreDemo(config.BASE_URL), progresso=progresso)
        return Estrattore(config.BASE_URL, progresso=progresso)

    def esegui_estrazione(sezione: str, con_dettagli: bool, con_csv: bool) -> None:
        iniziata = adesso()

        def progresso(info: dict) -> None:
            with lavoro.lock:
                lavoro.stato["progresso"] = info

        with lavoro.lock:
            lavoro.stato.update({"in_corso": True, "sezione": sezione, "progresso": {"fase": "avvio"},
                                 "iniziata": iniziata, "conclusa": None, "esito": None, "errore": None})
        try:
            ris = nuovo_estrattore(progresso).estrai(sezione, con_dettagli=con_dettagli, con_csv=con_csv)
            if ris["atti"]:
                archivio.salva_estrazione(sezione, ris["atti"], ris["statistiche"], ris["errori"], iniziata)
                esito, errore = "ok", None
            else:
                msg = "nessun atto trovato: " + ("; ".join(ris["errori"]) or "la pagina non contiene atti riconoscibili")
                archivio.registra_errore(sezione, msg, iniziata)
                esito, errore = "errore", msg
        except Exception as e:  # noqa: BLE001
            log.exception("estrazione fallita")
            archivio.registra_errore(sezione, str(e), iniziata)
            esito, errore = "errore", str(e)
        with lavoro.lock:
            lavoro.stato.update({"in_corso": False, "conclusa": adesso(), "esito": esito, "errore": errore})

    # ---- pagine statiche ---------------------------------------------------------------------

    @app.get("/")
    def home():
        return send_from_directory(CARTELLA_STATIC, "index.html")

    @app.get("/static/<path:nome>")
    def statici(nome: str):
        return send_from_directory(CARTELLA_STATIC, nome)

    # ---- API ------------------------------------------------------------------------------------

    @app.get("/api/config")
    def api_config():
        return jsonify({
            "ente": config.ENTE, "base_url": config.BASE_URL, "sezioni": config.SEZIONI,
            "sezione_predefinita": config.SEZIONE_PREDEFINITA, "demo": demo, "versione": __version__,
            "conteggi": archivio.conteggi(),
        })

    @app.get("/api/atti")
    def api_atti():
        sezione = request.args.get("sezione", config.SEZIONE_PREDEFINITA)
        if sezione not in config.SEZIONI:
            abort(400, "sezione sconosciuta")
        atti = archivio.atti(sezione)
        tipi: dict[str, int] = {}
        for a in atti:
            t = a.get("tipo") or "(senza tipologia)"
            tipi[t] = tipi.get(t, 0) + 1
        return jsonify({
            "sezione": sezione, "atti": atti, "totale": len(atti),
            "in_pubblicazione": sum(1 for a in atti if a.get("in_pubblicazione")),
            "tipi": dict(sorted(tipi.items(), key=lambda kv: (-kv[1], kv[0]))),
            "ultima_estrazione": archivio.ultima_estrazione(sezione),
        })

    @app.get("/api/atti/<sezione>/<id_atto>")
    def api_atto(sezione: str, id_atto: str):
        atto = archivio.atto(sezione, id_atto)
        if atto is None:
            abort(404)
        return jsonify(atto)

    @app.post("/api/aggiorna")
    def api_aggiorna():
        dati = request.get_json(silent=True) or {}
        sezione = dati.get("sezione", config.SEZIONE_PREDEFINITA)
        if sezione not in config.SEZIONI:
            abort(400, "sezione sconosciuta")
        with lavoro.lock:
            if lavoro.in_corso():
                return jsonify({"avviato": False, "motivo": "estrazione già in corso", "stato": lavoro.stato}), 409
            lavoro.thread = threading.Thread(
                target=esegui_estrazione,
                args=(sezione, bool(dati.get("dettagli", True)), bool(dati.get("csv", True))),
                daemon=True, name="estrazione",
            )
            lavoro.stato.update({"in_corso": True, "sezione": sezione, "progresso": {"fase": "avvio"},
                                 "esito": None, "errore": None})
            lavoro.thread.start()
        return jsonify({"avviato": True, "stato": lavoro.stato}), 202

    @app.get("/api/stato")
    def api_stato():
        with lavoro.lock:
            stato = dict(lavoro.stato)
            stato["in_corso"] = lavoro.in_corso()
        stato["estrazioni"] = archivio.estrazioni(request.args.get("sezione"), limite=10)
        return jsonify(stato)

    @app.get("/api/export")
    def api_export():
        sezione = request.args.get("sezione", config.SEZIONE_PREDEFINITA)
        if sezione not in config.SEZIONI:
            abort(400, "sezione sconosciuta")
        formato = request.args.get("formato", "csv")
        atti = filtra_atti(
            archivio.atti(sezione), q=request.args.get("q", ""), tipo=request.args.get("tipo", ""),
            da=request.args.get("da", ""), a=request.args.get("a", ""),
            solo_pubblicati=request.args.get("solo_pubblicati") in ("1", "true", "si"),
        )
        data = datetime.now(timezone.utc).strftime("%Y%m%d")
        nome = f"albo-pretorio-{sezione}-{data}"
        if formato == "json":
            corpo = json.dumps({"ente": config.ENTE, "sezione": sezione, "estratto_il": adesso(),
                                "totale": len(atti), "atti": atti}, ensure_ascii=False, indent=2)
            return Response(corpo, mimetype="application/json",
                            headers={"Content-Disposition": f'attachment; filename="{nome}.json"'})
        buf = io.StringIO()
        buf.write("﻿")  # BOM: Excel riconosce l'UTF-8
        scrivi_csv(atti, buf)
        return Response(buf.getvalue(), mimetype="text/csv; charset=utf-8",
                        headers={"Content-Disposition": f'attachment; filename="{nome}.csv"'})

    @app.errorhandler(400)
    @app.errorhandler(404)
    @app.errorhandler(409)
    def errore_api(e):
        if request.path.startswith("/api/"):
            return jsonify({"errore": getattr(e, "description", str(e))}), e.code
        return e

    app.extensions["archivio"] = archivio
    app.extensions["lavoro"] = lavoro
    return app


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(description="Web app dell'albo pretorio.")
    p.add_argument("--host", default=os.environ.get("ALBO_HOST", "127.0.0.1"))
    p.add_argument("--porta", type=int, default=int(os.environ.get("PORT", os.environ.get("ALBO_PORTA", "8000"))))
    p.add_argument("--demo", action="store_true", default=os.environ.get("ALBO_DEMO") == "1",
                   help="usa le pagine di esempio invece della rete")
    p.add_argument("--db", default=config.PERCORSO_DB, help="percorso del database SQLite")
    p.add_argument("--debug", action="store_true")
    args = p.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    app = crea_app(Archivio(args.db), demo=args.demo)
    print(f"Albo pretorio di {config.ENTE} - http://{args.host}:{args.porta}/" + ("  [modalità demo]" if args.demo else ""))
    app.run(host=args.host, port=args.porta, debug=args.debug, threaded=True)


if __name__ == "__main__":
    main()
