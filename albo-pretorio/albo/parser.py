"""Analisi delle pagine HTML e dell'export CSV della piattaforma JCityGov.

Il parser non dipende dalla rete: riceve testo HTML/CSV e restituisce dizionari.
È scritto per essere tollerante: prova prima la struttura a tabella, poi i
contenitori (righe, liste, schede) che circondano i link "papca/display/<id>",
e in ogni caso riconosce le etichette dei campi con un elenco di sinonimi.
"""

from __future__ import annotations

import csv
import hashlib
import io
import re
from datetime import date
from typing import Iterable
from urllib.parse import parse_qs, urljoin, urlparse

from bs4 import BeautifulSoup, NavigableString, Tag

from . import config

RE_DISPLAY = re.compile(r"/papca/display/(\d+)")
RE_DATA = re.compile(r"\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})\b")
RE_DATA_ISO = re.compile(r"(?<!\d)(\d{4})-(\d{2})-(\d{2})(?!\d)")
RE_SPAZI = re.compile(r"\s+")

# Chiavi normalizzate e sinonimi (regex, minuscole) delle etichette usate dagli enti.
# L'ordine conta: i pattern più specifici precedono quelli generici.
CAMPI: list[tuple[str, list[str]]] = [
    ("numero_atto", [r"numero\s+(atto|provvedimento|documento|delibera|determina|ordinanza|decreto)",
                     r"^n\.?\s*(atto|provvedimento|documento)"]),
    ("data_atto", [r"data\s+(atto|adozione|provvedimento|documento|emissione|delibera|determina)"]),
    ("anno", [r"^anno"]),
    ("numero", [r"numero\s+registr", r"n\.?\s*registr", r"^registro", r"numero\s+pubblicazione",
                r"n\.?\s*pubblicazione", r"numero\s+albo", r"n\.?\s*albo", r"^numero$", r"^n\.?$",
                r"^num\.?$", r"progressivo", r"^n\.?\s*prot", r"^protocollo"]),
    ("tipo", [r"tipo(logia)?\s*(atto|documento|pubblicazione|provvedimento)?$", r"tipo\s+di\s+atto",
              r"categoria", r"^tipo"]),
    ("oggetto", [r"^oggetto", r"^descrizione", r"^titolo"]),
    ("data_inizio", [r"data\s+inizio", r"inizio\s+pubbl", r"data\s+(di\s+)?pubblicazione",
                     r"pubblicat[oa]\s+(dal|il)", r"^dal$", r"data\s+affissione", r"^dal\s+giorno",
                     r"in\s+pubblicazione\s+dal"]),
    ("data_fine", [r"data\s+fine", r"fine\s+pubbl", r"scadenza", r"^al$", r"fino\s+al",
                   r"data\s+defissione", r"^al\s+giorno", r"in\s+pubblicazione\s+(fino\s+)?al"]),
    ("ente", [r"^ente", r"mittente", r"proponente", r"^ufficio", r"struttura", r"^settore",
              r"^servizio", r"richiedente", r"emittente", r"^organo", r"^area", r"unit[àa]\s+organizzativa",
              r"^u\.?o\.?$", r"^soggetto"]),
]
CAMPI_COMPILATI = [(chiave, [re.compile(p) for p in pattern]) for chiave, pattern in CAMPI]
CHIAVI_PRINCIPALI = ["numero", "tipo", "oggetto", "data_inizio", "data_fine", "ente",
                     "numero_atto", "data_atto", "anno"]
CHIAVI_DATA = {"data_inizio", "data_fine", "data_atto"}

# Testi dei link che NON sono l'oggetto dell'atto.
TESTI_LINK_GENERICI = {"dettaglio", "dettagli", "visualizza", "apri", "vedi", "mostra", "leggi",
                       "scheda", "vai", "info", "informazioni", "»", ">", "..."}
TESTI_LINK_SUCCESSIVA = {"»", "›", ">", ">>", "successiva", "successivo", "successivi", "avanti",
                         "next", "seguente", "pagina successiva", "prossima"}
COLONNE_NON_CAMPO = {"documenti", "documento", "allegati", "allegato", "file", "download", "scarica",
                     "azioni", "azione", "dettaglio", "dettagli", "visualizza", "apri", ""}
ESTENSIONI_ALLEGATO = (".pdf", ".p7m", ".doc", ".docx", ".odt", ".xls", ".xlsx", ".ods", ".zip",
                       ".xml", ".rtf", ".txt", ".jpg", ".jpeg", ".png", ".tif", ".tiff", ".dwg")
RE_CLASSE_CONTENITORE = re.compile(r"line|item|row|entry|result|risultat|pubblicazion|atto|card|elemento|record|scheda",
                                   re.I)


# ----------------------------------------------------------------------------------------------
# utilità
# ----------------------------------------------------------------------------------------------

def testo(el: Tag | NavigableString | None) -> str:
    """Testo di un elemento con gli spazi normalizzati."""
    if el is None:
        return ""
    if isinstance(el, NavigableString):
        return RE_SPAZI.sub(" ", str(el)).strip()
    return RE_SPAZI.sub(" ", el.get_text(" ", strip=True)).strip()


def normalizza_etichetta(etichetta: str) -> str:
    e = RE_SPAZI.sub(" ", etichetta or "").strip().lower()
    e = e.rstrip(":*").strip()
    return e


def chiave_campo(etichetta: str) -> str | None:
    """Mappa un'etichetta ("Data inizio pubblicazione") alla chiave normalizzata ("data_inizio")."""
    e = normalizza_etichetta(etichetta)
    if not e or len(e) > 60:
        return None
    for chiave, patterns in CAMPI_COMPILATI:
        for p in patterns:
            if p.search(e):
                return chiave
    return None


def normalizza_data(valore: str | None) -> str | None:
    """Converte "31/12/2026" (o "31-12-2026", "31.12.2026") in ISO "2026-12-31"."""
    if not valore:
        return None
    m = RE_DATA.search(valore)
    if m:
        g, me, a = (int(x) for x in m.groups())
        try:
            return date(a, me, g).isoformat()
        except ValueError:
            return None
    m = RE_DATA_ISO.search(valore)
    if m:
        try:
            return date(int(m.group(1)), int(m.group(2)), int(m.group(3))).isoformat()
        except ValueError:
            return None
    return None


def id_da_url(url: str | None) -> str | None:
    if not url:
        return None
    m = RE_DISPLAY.search(url)
    return m.group(1) if m else None


def id_sintetico(*parti: str | None) -> str:
    """Identificativo stabile per un atto senza link di dettaglio (p.es. proveniente dal CSV)."""
    base = "|".join((p or "").strip().lower() for p in parti)
    return "h-" + hashlib.sha1(base.encode("utf-8")).hexdigest()[:16]


def atto_vuoto(sezione: str) -> dict:
    return {
        "id": None, "sezione": sezione, "url": None,
        "numero": None, "tipo": None, "oggetto": None,
        "data_inizio": None, "data_fine": None, "ente": None,
        "numero_atto": None, "data_atto": None, "anno": None,
        "allegati": [], "altri_campi": {},
    }


def applica_campi(atto: dict, campi: dict[str, str]) -> None:
    """Riversa un dizionario etichetta -> valore nell'atto, normalizzando le chiavi."""
    for etichetta, valore in campi.items():
        valore = RE_SPAZI.sub(" ", valore or "").strip()
        if not valore:
            continue
        chiave = chiave_campo(etichetta)
        if chiave is None:
            if etichetta.strip():
                atto["altri_campi"].setdefault(etichetta.strip().rstrip(":").strip(), valore)
            continue
        if chiave in CHIAVI_DATA:
            iso = normalizza_data(valore)
            if iso is None:
                atto["altri_campi"].setdefault(etichetta.strip().rstrip(":").strip(), valore)
                continue
            valore = iso
        if not atto.get(chiave):
            atto[chiave] = valore
        elif atto[chiave] != valore:
            atto["altri_campi"].setdefault(etichetta.strip().rstrip(":").strip(), valore)


def completa_atto(atto: dict) -> dict:
    """Ricava i campi mancanti dove possibile (anno dal numero o dalle date, id sintetico)."""
    if atto.get("numero") and not atto.get("anno"):
        m = re.search(r"(20\d{2}|19\d{2})", atto["numero"])
        if m:
            atto["anno"] = m.group(1)
    if not atto.get("anno") and atto.get("data_inizio"):
        atto["anno"] = atto["data_inizio"][:4]
    if not atto.get("id"):
        atto["id"] = id_sintetico(atto.get("sezione"), atto.get("numero"), atto.get("oggetto"),
                                  atto.get("data_inizio"))
    return atto


# ----------------------------------------------------------------------------------------------
# allegati
# ----------------------------------------------------------------------------------------------

def e_link_allegato(href: str) -> bool:
    h = href.lower()
    if "downloadallegato" in h or "downloadfile" in h or "download" in h and "allegat" in h:
        return True
    percorso = urlparse(h).path
    return percorso.endswith(ESTENSIONI_ALLEGATO)


def chiave_allegato(url: str) -> str:
    """Chiave di confronto tra allegati: id del file sulla piattaforma (se c'è) oppure l'URL."""
    u = urlparse(url)
    qs = parse_qs(u.query)
    id_file = qs.get(config.PREFISSO_PARAM + "id", [None])[0]
    if id_file:
        firmato = qs.get(config.PREFISSO_PARAM + "downloadSigned", ["false"])[0].lower()
        return f"id:{id_file}:{firmato}"
    return u._replace(query="&".join(sorted(u.query.split("&")))).geturl()


def estrai_allegati(contenitore: Tag, base_url: str) -> list[dict]:
    allegati: list[dict] = []
    visti: set[str] = set()
    for a in contenitore.find_all("a", href=True):
        href = a["href"].strip()
        if not href or href.startswith(("javascript:", "#", "mailto:")):
            continue
        if not e_link_allegato(href):
            continue
        url = urljoin(base_url, href)
        chiave = chiave_allegato(url)
        if chiave in visti:
            continue
        visti.add(chiave)
        qs = parse_qs(urlparse(url).query)
        firmato = qs.get(config.PREFISSO_PARAM + "downloadSigned", ["false"])[0].lower() == "true" \
            or urlparse(url).path.lower().endswith(".p7m")
        nome = testo(a) or a.get("title") or ""
        if not nome or nome.lower() in ("download", "scarica", "apri", "documento"):
            nome = a.get("title") or nome or urlparse(url).path.rsplit("/", 1)[-1] or "Allegato"
        allegati.append({"nome": nome, "url": url, "firmato": firmato})
    return allegati


# ----------------------------------------------------------------------------------------------
# estrazione etichetta -> valore da un contenitore
# ----------------------------------------------------------------------------------------------

def _coppie_dl(contenitore: Tag) -> dict[str, str]:
    campi: dict[str, str] = {}
    for dt in contenitore.find_all("dt"):
        dd = dt.find_next_sibling("dd")
        if dd is not None:
            campi.setdefault(testo(dt), testo(dd))
    return campi


def _coppie_label_value(contenitore: Tag) -> dict[str, str]:
    """Elementi con classe *label* seguiti da un fratello (o da un elemento con classe *value*)."""
    campi: dict[str, str] = {}
    for lab in contenitore.find_all(class_=re.compile(r"(^|[\s_-])(label|etichetta|field-name|nome-campo)($|[\s_-])", re.I)):
        etichetta = testo(lab)
        if not etichetta:
            continue
        val = lab.find_next_sibling(class_=re.compile(r"value|valore|field-value|contenuto", re.I))
        if val is None:
            val = lab.find_next_sibling()
        if val is None and lab.parent is not None:
            # <div class="campo"><span class="label">X</span> testo</div>
            resto = "".join(str(s) for s in lab.next_siblings)
            val = BeautifulSoup(resto, "html.parser")
        if val is not None:
            v = testo(val)
            if v and v != etichetta:
                campi.setdefault(etichetta, v)
    for lab in contenitore.find_all("label"):
        etichetta = testo(lab)
        if not etichetta:
            continue
        val = None
        if lab.get("for"):
            val = contenitore.find(id=lab["for"])
        if val is None:
            val = lab.find_next_sibling()
        if val is not None:
            v = testo(val)
            if v and v != etichetta:
                campi.setdefault(etichetta, v)
    return campi


def _coppie_grassetto(contenitore: Tag) -> dict[str, str]:
    """<strong>Etichetta:</strong> valore  (oppure <b>, <th> in tabelle verticali)."""
    campi: dict[str, str] = {}
    for th in contenitore.find_all("th"):
        td = th.find_next_sibling("td")
        if td is not None and testo(th):
            campi.setdefault(testo(th), testo(td))
    for tag in contenitore.find_all(["strong", "b"]):
        etichetta = testo(tag)
        if not etichetta or chiave_campo(etichetta) is None:
            continue
        parti: list[str] = []
        for sib in tag.next_siblings:
            if isinstance(sib, Tag) and sib.name in ("strong", "b", "br", "dt", "li", "tr", "div", "p"):
                if sib.name == "br" and not parti:
                    continue
                if sib.name in ("br",):
                    break
                if sib.name in ("strong", "b"):
                    break
                t = testo(sib)
                if t:
                    parti.append(t)
                break
            t = testo(sib)
            if t:
                parti.append(t)
        valore = " ".join(parti).strip().lstrip(":").strip()
        if valore:
            campi.setdefault(etichetta, valore)
    return campi


def _coppie_testo(contenitore: Tag) -> dict[str, str]:
    """Ultima spiaggia: "Etichetta: valore" nel testo piatto, spezzato sulle etichette note."""
    campi: dict[str, str] = {}
    t = testo(contenitore)
    if not t:
        return campi
    # per ogni ":" guarda le 1-4 parole precedenti e cerca l'etichetta riconosciuta più lunga
    # con la forma tipica "Parola parola parola" (prima maiuscola, le altre minuscole)
    trovate: list[tuple[int, int, str]] = []
    for m in re.finditer(r":\s", t):
        prima = t[:m.start()]
        parole = list(re.finditer(r"\S+", prima))
        candidati = []
        for n in range(1, 5):
            if n > len(parole):
                break
            inizio = parole[-n].start()
            etichetta = prima[inizio:].strip().rstrip("*")
            if not re.fullmatch(r"[A-Za-zÀ-ÿ.'/ ]+", etichetta) or chiave_campo(etichetta) is None:
                continue
            forma_tipica = etichetta[0].isupper() and all(p.islower() for p in etichetta.split()[1:])
            candidati.append((forma_tipica, n, inizio, etichetta))
        if not candidati:
            continue
        tipici = [c for c in candidati if c[0]]
        scelto = max(tipici, key=lambda c: c[1]) if tipici else min(candidati, key=lambda c: c[1])
        trovate.append((scelto[2], m.end(), scelto[3]))
    for i, (inizio, fine, etichetta) in enumerate(trovate):
        fine_valore = trovate[i + 1][0] if i + 1 < len(trovate) else len(t)
        valore = t[fine:fine_valore].strip(" ;,|-")
        if valore:
            campi.setdefault(etichetta, valore)
    return campi


def estrai_campi(contenitore: Tag) -> dict[str, str]:
    campi: dict[str, str] = {}
    for estrattore in (_coppie_dl, _coppie_label_value, _coppie_grassetto):
        for k, v in estrattore(contenitore).items():
            campi.setdefault(k, v)
    chiavi_presenti = {chiave_campo(k) for k in campi}
    if "oggetto" not in chiavi_presenti or "data_inizio" not in chiavi_presenti:
        for k, v in _coppie_testo(contenitore).items():
            campi.setdefault(k, v)
    return campi


# ----------------------------------------------------------------------------------------------
# elenco: strategia A (tabella con intestazioni)
# ----------------------------------------------------------------------------------------------

def _intestazioni_tabella(tabella: Tag) -> tuple[list[str], Tag | None]:
    thead = tabella.find("thead")
    riga = None
    if thead is not None:
        riga = thead.find("tr")
    if riga is None:
        riga = tabella.find("tr")
    if riga is None:
        return [], None
    celle = riga.find_all(["th", "td"], recursive=False)
    intest = [testo(c) for c in celle]
    if not any(c.name == "th" for c in celle) and not any(chiave_campo(i) == "oggetto" for i in intest):
        return [], None
    return intest, riga


def _tabella_elenco(soup: BeautifulSoup) -> tuple[Tag, list[str], Tag] | None:
    migliore = None
    for tabella in soup.find_all("table"):
        intest, riga = _intestazioni_tabella(tabella)
        if not intest:
            continue
        chiavi = {chiave_campo(i) for i in intest} - {None}
        if "oggetto" not in chiavi:
            continue
        righe = tabella.find_all("tr")
        punteggio = len(chiavi) * 100 + len(righe)
        if migliore is None or punteggio > migliore[0]:
            migliore = (punteggio, tabella, intest, riga)
    if migliore is None:
        return None
    return migliore[1], migliore[2], migliore[3]


def _righe_tabella(tabella: Tag, riga_intestazione: Tag) -> Iterable[Tag]:
    for tr in tabella.find_all("tr"):
        if tr is riga_intestazione:
            continue
        # righe di tabelle annidate appartengono alla riga esterna
        if tr.find_parent("table") is not tabella:
            continue
        if tr.find("td") is None:
            continue
        yield tr


def _atti_da_tabella(soup: BeautifulSoup, base_url: str, sezione: str) -> list[dict]:
    trovata = _tabella_elenco(soup)
    if trovata is None:
        return []
    tabella, intest, riga_int = trovata
    atti = []
    for tr in _righe_tabella(tabella, riga_int):
        celle = tr.find_all("td", recursive=False)
        if not celle:
            continue
        atto = atto_vuoto(sezione)
        campi: dict[str, str] = {}
        for i, cella in enumerate(celle):
            etichetta = intest[i] if i < len(intest) else (cella.get("data-title") or cella.get("headers") or "")
            if isinstance(etichetta, list):
                etichetta = " ".join(etichetta)
            valore = testo(cella)
            # le colonne "Documenti"/"Azioni" contengono solo link: non sono campi dell'atto
            if normalizza_etichetta(etichetta) in COLONNE_NON_CAMPO:
                continue
            if etichetta and valore:
                campi.setdefault(etichetta, valore)
        _applica_link_dettaglio(atto, tr, base_url)
        applica_campi(atto, campi)
        atto["allegati"] = estrai_allegati(tr, base_url)
        # la cella con l'oggetto spesso contiene solo il link
        if not atto["oggetto"]:
            atto["oggetto"] = _oggetto_da_link(tr)
        if atto["oggetto"] or atto["numero"]:
            atti.append(completa_atto(atto))
    return atti


# ----------------------------------------------------------------------------------------------
# elenco: strategia B (contenitori intorno ai link di dettaglio)
# ----------------------------------------------------------------------------------------------

def _link_dettaglio(el: Tag) -> Tag | None:
    for a in el.find_all("a", href=True):
        if RE_DISPLAY.search(a["href"]):
            return a
    return None


def _applica_link_dettaglio(atto: dict, el: Tag, base_url: str) -> None:
    a = _link_dettaglio(el)
    if a is None:
        return
    url = urljoin(base_url, a["href"].strip())
    # via i parametri volatili di sessione
    url = re.sub(r";jsessionid=[^?]*", "", url)
    url = re.sub(r"[?&]p_auth=[^&]*", "", url)
    url = re.sub(r"[?&]p_p_state=pop_up", "", url)
    atto["url"] = url
    atto["id"] = id_da_url(url)


def _oggetto_da_link(el: Tag) -> str | None:
    a = _link_dettaglio(el)
    if a is not None:
        t = testo(a)
        if t and t.lower().strip(" .»>") not in TESTI_LINK_GENERICI and len(t) > 3:
            return t
    # altrimenti il blocco di testo più lungo (esclusi i link agli allegati)
    migliore = ""
    for tag in el.find_all(["h1", "h2", "h3", "h4", "h5", "p", "span", "div", "td", "dd", "li"]):
        if tag.find(["h1", "h2", "h3", "h4", "p", "div", "table", "ul"]) is not None:
            continue
        t = testo(tag)
        if len(t) > len(migliore) and not RE_DATA.fullmatch(t) and chiave_campo(t) is None:
            migliore = t
    return migliore or None


def _ids_in(el: Tag) -> set[str]:
    return {m.group(1) for a in el.find_all("a", href=True) for m in [RE_DISPLAY.search(a["href"])] if m}


def _contenitore_atto(a: Tag, n_ids_pagina: int) -> Tag:
    """Risale dal link di dettaglio finché il contenitore include un solo atto."""
    corrente: Tag = a
    livelli = 0
    while corrente.parent is not None and isinstance(corrente.parent, Tag):
        genitore = corrente.parent
        if genitore.name in ("body", "html", "form", "table", "tbody", "ul", "ol"):
            # per <table>/<ul> il contenitore giusto è la riga/elemento già raggiunta
            if genitore.name in ("body", "html"):
                break
            if corrente.name in ("tr", "li"):
                break
        if len(_ids_in(genitore)) > 1:
            break
        corrente = genitore
        livelli += 1
        if corrente.name in ("tr", "li", "article"):
            break
        classi = " ".join(corrente.get("class", []))
        if RE_CLASSE_CONTENITORE.search(classi) and n_ids_pagina == 1:
            break
        if n_ids_pagina == 1 and livelli >= 4:
            break
    return corrente


def _atti_da_contenitori(soup: BeautifulSoup, base_url: str, sezione: str) -> list[dict]:
    ancore: dict[str, Tag] = {}
    for a in soup.find_all("a", href=True):
        m = RE_DISPLAY.search(a["href"])
        if m and m.group(1) not in ancore:
            ancore[m.group(1)] = a
    atti = []
    for id_atto, a in ancore.items():
        cont = _contenitore_atto(a, len(ancore))
        atto = atto_vuoto(sezione)
        _applica_link_dettaglio(atto, cont, base_url)
        applica_campi(atto, estrai_campi(cont))
        atto["allegati"] = estrai_allegati(cont, base_url)
        if not atto["oggetto"]:
            atto["oggetto"] = _oggetto_da_link(cont)
        atti.append(completa_atto(atto))
    return atti


# ----------------------------------------------------------------------------------------------
# paginazione
# ----------------------------------------------------------------------------------------------

def _numero(s: str | None) -> int | None:
    if s is None:
        return None
    m = re.search(r"\d+", s.replace(".", ""))
    return int(m.group()) if m else None


def analizza_paginazione(soup: BeautifulSoup, base_url: str, url_pagina: str | None = None) -> dict:
    t = testo(soup)
    info: dict = {"totale": None, "pagina": None, "pagine": None, "url_successiva": None, "per_pagina": None}
    for p in (r"(\d[\d.]*)\s+risultat", r"risultati\s*(?:trovati|totali)?\s*[:=]?\s*(\d[\d.]*)",
              r"(?:su|di)\s+(\d[\d.]*)\s+(?:risultati|elementi|atti|pubblicazioni|totali)",
              r"totale\s*(?:risultati|atti|elementi)?\s*[:=]?\s*(\d[\d.]*)",
              r"(?:trovat[ei]|elementi)\s*[:=]?\s*(\d[\d.]*)"):
        m = re.search(p, t, re.I)
        if m:
            info["totale"] = _numero(m.group(1))
            break
    m = re.search(r"pagina\s+(\d+)\s+(?:di|su|/)\s+(\d+)", t, re.I)
    if m:
        info["pagina"], info["pagine"] = int(m.group(1)), int(m.group(2))
    m = re.search(r"(?:visualizzat[ei]|mostrat[ei]|elementi)\s+(\d+)\s*[-–]\s*(\d+)", t, re.I)
    if m:
        info["per_pagina"] = int(m.group(2)) - int(m.group(1)) + 1

    # pagina corrente dall'URL
    if url_pagina:
        qs = parse_qs(urlparse(url_pagina).query)
        cur = qs.get(config.PREFISSO_PARAM + "cur") or qs.get("cur")
        if cur and info["pagina"] is None:
            info["pagina"] = _numero(cur[0])

    # link "successiva"
    for a in soup.find_all("a", href=True):
        href = a["href"].strip()
        etichetta = (testo(a) or a.get("title") or a.get("aria-label") or "").lower().strip()
        classi = " ".join(a.get("class", [])).lower()
        rel = " ".join(a.get("rel", [])).lower() if a.get("rel") else ""
        candidato = (
            "next" in rel
            or re.search(r"(^|[\s_-])(next|successiv|avanti)", classi) is not None
            or etichetta in TESTI_LINK_SUCCESSIVA
            or etichetta.startswith(("successiv", "avanti", "pagina successiva", "next"))
        )
        if not candidato:
            continue
        genitore = a.parent
        if genitore is not None and isinstance(genitore, Tag) and \
                re.search(r"disabled|inactive|disattiv", " ".join(genitore.get("class", [])), re.I):
            continue
        if href.startswith("javascript:") or href in ("#", ""):
            continue
        info["url_successiva"] = urljoin(base_url, href)
        break

    # numeri di pagina nella barra di paginazione (per stimare il totale delle pagine)
    if info["pagine"] is None:
        numeri = []
        for a in soup.find_all("a", href=True):
            tt = testo(a)
            if tt.isdigit() and (config.PREFISSO_PARAM + "cur" in a["href"] or "cur=" in a["href"]
                                 or "page=" in a["href"].lower()):
                numeri.append(int(tt))
        if numeri:
            info["pagine"] = max(numeri)
    return info


# ----------------------------------------------------------------------------------------------
# API pubblica: elenco, dettaglio, csv
# ----------------------------------------------------------------------------------------------

def parse_lista(html: str, base_url: str = config.BASE_URL, sezione: str = config.SEZIONE_PREDEFINITA,
                url_pagina: str | None = None) -> dict:
    """Restituisce {"atti": [...], "paginazione": {...}, "strategia": "tabella"|"contenitori"|"nessuna"}."""
    soup = BeautifulSoup(html, "html.parser")
    for s in soup(["script", "style", "noscript"]):
        s.decompose()
    atti = _atti_da_tabella(soup, base_url, sezione)
    strategia = "tabella"
    if not atti:
        atti = _atti_da_contenitori(soup, base_url, sezione)
        strategia = "contenitori" if atti else "nessuna"
    # dedup per id conservando l'ordine
    visti: set[str] = set()
    unici = []
    for a in atti:
        if a["id"] in visti:
            continue
        visti.add(a["id"])
        unici.append(a)
    return {"atti": unici, "paginazione": analizza_paginazione(soup, base_url, url_pagina), "strategia": strategia}


def _area_contenuto(soup: BeautifulSoup) -> Tag:
    for sel in (
        {"id": re.compile(config.PORTLET_ID, re.I)},
        {"class_": re.compile(r"portlet-body|portlet-content|master-detail|dettaglio", re.I)},
        {"id": re.compile(r"^(content|main|contenuto)", re.I)},
    ):
        el = soup.find(**sel)
        if el is not None and len(testo(el)) > 40:
            return el
    return soup.find("main") or soup.body or soup


def parse_dettaglio(html: str, base_url: str = config.BASE_URL, sezione: str = config.SEZIONE_PREDEFINITA,
                    url_pagina: str | None = None) -> dict:
    """Analizza la pagina di dettaglio di un atto (papca/display/<id>)."""
    soup = BeautifulSoup(html, "html.parser")
    for s in soup(["script", "style", "noscript", "nav", "header", "footer"]):
        s.decompose()
    area = _area_contenuto(soup)
    atto = atto_vuoto(sezione)
    atto["url"] = url_pagina
    atto["id"] = id_da_url(url_pagina)
    if atto["id"] is None:
        canon = soup.find("link", rel="canonical")
        atto["id"] = id_da_url(canon["href"]) if canon and canon.get("href") else None
    applica_campi(atto, estrai_campi(area))
    atto["allegati"] = estrai_allegati(area, base_url)
    if not atto["oggetto"]:
        for h in area.find_all(["h1", "h2", "h3"]):
            t = testo(h)
            if len(t) > 10 and chiave_campo(t) is None and "albo" not in t.lower():
                atto["oggetto"] = t
                break
    return completa_atto(atto)


def parse_csv(dati: bytes | str, sezione: str = config.SEZIONE_PREDEFINITA) -> list[dict]:
    """Analizza l'export CSV del portlet (resource "exportList", format=csv)."""
    if isinstance(dati, bytes):
        for codifica in ("utf-8-sig", "utf-8", "cp1252", "latin-1"):
            try:
                t = dati.decode(codifica)
                break
            except UnicodeDecodeError:
                continue
    else:
        t = dati
    t = t.strip("﻿ \r\n")
    if not t:
        return []
    prima_riga = t.splitlines()[0]
    delimitatore = max((";", ",", "\t", "|"), key=prima_riga.count)
    lettore = csv.DictReader(io.StringIO(t), delimiter=delimitatore)
    atti = []
    for riga in lettore:
        if not riga or not any((v or "").strip() for v in riga.values()):
            continue
        atto = atto_vuoto(sezione)
        campi = {(k or "").strip(): (v or "") for k, v in riga.items() if k is not None}
        applica_campi(atto, campi)
        for k, v in list(campi.items()):
            if v and ("http://" in v or "https://" in v) and id_da_url(v):
                atto["url"] = v.strip()
                atto["id"] = id_da_url(v)
        if atto["oggetto"] or atto["numero"]:
            atti.append(completa_atto(atto))
    return atti
