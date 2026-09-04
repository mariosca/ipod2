"""Archivio locale SQLite: conserva gli atti estratti e lo storico delle estrazioni.

Un atto resta in archivio anche quando scompare dall'albo (pubblicazione scaduta):
il campo ``in_pubblicazione`` indica se era presente nell'ultima estrazione completa.
"""

from __future__ import annotations

import json
import os
import sqlite3
import threading
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Iterator

from . import config

SCHEMA = """
CREATE TABLE IF NOT EXISTS atti (
    sezione     TEXT NOT NULL,
    id          TEXT NOT NULL,
    dati        TEXT NOT NULL,
    primo_visto TEXT NOT NULL,
    ultimo_visto TEXT NOT NULL,
    PRIMARY KEY (sezione, id)
);
CREATE TABLE IF NOT EXISTS estrazioni (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    sezione     TEXT NOT NULL,
    iniziata    TEXT NOT NULL,
    conclusa    TEXT,
    esito       TEXT,
    n_atti      INTEGER,
    statistiche TEXT,
    errori      TEXT
);
"""


def adesso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


class Archivio:
    def __init__(self, percorso: str = config.PERCORSO_DB):
        self.percorso = percorso
        if percorso != ":memory:":
            os.makedirs(os.path.dirname(os.path.abspath(percorso)), exist_ok=True)
        self._memoria = None
        self._lock = threading.RLock()
        if percorso == ":memory:":
            self._memoria = sqlite3.connect(":memory:", check_same_thread=False)
            self._memoria.row_factory = sqlite3.Row
        with self._conn() as c:
            c.executescript(SCHEMA)

    @contextmanager
    def _conn(self) -> Iterator[sqlite3.Connection]:
        """Connessione con commit automatico; quella su file viene chiusa a fine blocco."""
        if self._memoria is not None:
            with self._lock, self._memoria:
                yield self._memoria
            return
        c = sqlite3.connect(self.percorso, timeout=30)
        c.row_factory = sqlite3.Row
        try:
            with c:
                yield c
        finally:
            c.close()

    # ---- scrittura --------------------------------------------------------------------------

    def salva_estrazione(self, sezione: str, atti: list[dict], statistiche: dict | None = None,
                         errori: list[str] | None = None, iniziata: str | None = None) -> int:
        t = adesso()
        with self._conn() as c:
            for a in atti:
                dati = json.dumps(a, ensure_ascii=False)
                c.execute(
                    "INSERT INTO atti (sezione, id, dati, primo_visto, ultimo_visto) VALUES (?, ?, ?, ?, ?) "
                    "ON CONFLICT(sezione, id) DO UPDATE SET dati = excluded.dati, ultimo_visto = excluded.ultimo_visto",
                    (sezione, str(a["id"]), dati, t, t),
                )
            cur = c.execute(
                "INSERT INTO estrazioni (sezione, iniziata, conclusa, esito, n_atti, statistiche, errori) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                (sezione, iniziata or t, t, "ok" if atti else "vuota", len(atti),
                 json.dumps(statistiche or {}, ensure_ascii=False), json.dumps(errori or [], ensure_ascii=False)),
            )
            return int(cur.lastrowid)

    def registra_errore(self, sezione: str, errore: str, iniziata: str | None = None) -> None:
        t = adesso()
        with self._conn() as c:
            c.execute(
                "INSERT INTO estrazioni (sezione, iniziata, conclusa, esito, n_atti, statistiche, errori) "
                "VALUES (?, ?, ?, 'errore', 0, '{}', ?)",
                (sezione, iniziata or t, t, json.dumps([errore], ensure_ascii=False)),
            )

    # ---- lettura ------------------------------------------------------------------------------

    def ultima_estrazione(self, sezione: str) -> dict | None:
        with self._conn() as c:
            r = c.execute(
                "SELECT * FROM estrazioni WHERE sezione = ? AND esito = 'ok' ORDER BY id DESC LIMIT 1", (sezione,)
            ).fetchone()
        if r is None:
            return None
        return self._riga_estrazione(r)

    def estrazioni(self, sezione: str | None = None, limite: int = 20) -> list[dict]:
        with self._conn() as c:
            if sezione:
                righe = c.execute("SELECT * FROM estrazioni WHERE sezione = ? ORDER BY id DESC LIMIT ?",
                                  (sezione, limite)).fetchall()
            else:
                righe = c.execute("SELECT * FROM estrazioni ORDER BY id DESC LIMIT ?", (limite,)).fetchall()
        return [self._riga_estrazione(r) for r in righe]

    @staticmethod
    def _riga_estrazione(r) -> dict:
        d = dict(r)
        d["statistiche"] = json.loads(d.get("statistiche") or "{}")
        d["errori"] = json.loads(d.get("errori") or "[]")
        return d

    def atti(self, sezione: str) -> list[dict]:
        """Tutti gli atti conservati per la sezione, più recenti prima."""
        ultima = self.ultima_estrazione(sezione)
        marca = ultima["conclusa"] if ultima else None
        with self._conn() as c:
            righe = c.execute("SELECT dati, primo_visto, ultimo_visto FROM atti WHERE sezione = ?",
                              (sezione,)).fetchall()
        risultato = []
        for r in righe:
            a = json.loads(r["dati"])
            a["primo_visto"] = r["primo_visto"]
            a["ultimo_visto"] = r["ultimo_visto"]
            a["in_pubblicazione"] = bool(marca) and r["ultimo_visto"] >= marca
            risultato.append(a)
        risultato.sort(key=lambda a: (a.get("data_inizio") or "", a.get("numero") or "", a.get("id") or ""),
                       reverse=True)
        return risultato

    def atto(self, sezione: str, id_atto: str) -> dict | None:
        for a in self.atti(sezione):
            if str(a.get("id")) == str(id_atto):
                return a
        return None

    def conteggi(self) -> dict[str, int]:
        with self._conn() as c:
            righe = c.execute("SELECT sezione, COUNT(*) AS n FROM atti GROUP BY sezione").fetchall()
        return {r["sezione"]: r["n"] for r in righe}
