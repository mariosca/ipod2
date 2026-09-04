"""Modalità dimostrativa: serve le pagine di esempio in tests/fixtures al posto della rete.

Utile per provare l'interfaccia senza connessione e per i test automatici.
"""

from __future__ import annotations

import os
from urllib.parse import parse_qs, urlparse

from . import config
from .parser import RE_DISPLAY

CARTELLA_FIXTURES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tests", "fixtures")


class RecuperatoreDemo:
    """Stesso contratto di :class:`albo.scraper.Recuperatore`, ma legge file locali."""

    def __init__(self, base_url: str = config.BASE_URL, cartella: str = CARTELLA_FIXTURES):
        self.base_url = base_url
        self.cartella = cartella
        self.richieste = 0
        self.url_richiesti: list[str] = []

    def _file(self, url: str) -> str:
        u = urlparse(url)
        qs = parse_qs(u.query)
        m = RE_DISPLAY.search(u.path)
        if m:
            specifico = os.path.join(self.cartella, f"dettaglio_{m.group(1)}.html")
            return specifico if os.path.exists(specifico) else os.path.join(self.cartella, "dettaglio.html")
        if qs.get("p_p_resource_id", [""])[0] == "exportList":
            return os.path.join(self.cartella, "export.csv")
        cur = qs.get(config.PREFISSO_PARAM + "cur", ["1"])[0]
        return os.path.join(self.cartella, f"lista_{cur}.html")

    def contenuto(self, url: str) -> bytes:
        self.richieste += 1
        self.url_richiesti.append(url)
        percorso = self._file(url)
        if not os.path.exists(percorso):
            raise RuntimeError(f"pagina di esempio non disponibile per {url}")
        with open(percorso, "rb") as f:
            return f.read()

    def testo(self, url: str) -> str:
        return self.contenuto(url).decode("utf-8")

    def get(self, url: str):
        class _Risposta:
            def __init__(self, contenuto: bytes):
                self.content = contenuto
                self.headers = {"Content-Type": "text/csv" if url.endswith("csv") or "exportList" in url
                                else "text/html; charset=utf-8"}
                self.status_code = 200
                self.encoding = "utf-8"
                self.text = contenuto.decode("utf-8")

        return _Risposta(self.contenuto(url))
