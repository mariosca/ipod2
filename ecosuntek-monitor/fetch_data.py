#!/usr/bin/env python3
"""Scarica lo storico giornaliero da Yahoo Finance e lo salva in data/<SIMBOLO>.json.

Il file ha lo stesso formato della risposta dell'API "chart" di Yahoo, con in più il
campo fetchedAt, così l'app lo legge senza passare da proxy. Solo libreria standard.

Uso:
    python3 fetch_data.py            # ECK.MI
    python3 fetch_data.py ENI.MI     # altro simbolo
"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

HOSTS = ("query1.finance.yahoo.com", "query2.finance.yahoo.com")
SYMBOL_RE = re.compile(r"^[A-Z0-9.^=\-]{1,20}$")


def fetch(symbol: str, rng: str = "1y") -> dict:
    last_err = None
    for attempt in range(3):
        for host in HOSTS:
            url = (
                f"https://{host}/v8/finance/chart/{urllib.parse.quote(symbol)}"
                f"?range={rng}&interval=1d&events=div,splits"
            )
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "application/json"})
            try:
                with urllib.request.urlopen(req, timeout=20) as resp:
                    data = json.load(resp)
                result = (data.get("chart") or {}).get("result")
                if not result or not result[0].get("timestamp"):
                    err = (data.get("chart") or {}).get("error") or {}
                    raise RuntimeError(err.get("description") or "risposta senza dati")
                return data
            except Exception as e:  # rete, HTTP, JSON
                last_err = e
        time.sleep(2 * (attempt + 1))
    raise SystemExit(f"Download fallito per {symbol}: {last_err}")


def main() -> None:
    symbol = (sys.argv[1] if len(sys.argv) > 1 else "ECK.MI").upper()
    if not SYMBOL_RE.match(symbol):
        raise SystemExit(f"Simbolo non valido: {symbol}")
    data = fetch(symbol)
    data["fetchedAt"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    out = Path(__file__).resolve().parent / "data" / f"{symbol}.json"
    out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(data, separators=(",", ":")) + "\n", encoding="utf-8")
    n = len(data["chart"]["result"][0]["timestamp"])
    price = data["chart"]["result"][0]["meta"].get("regularMarketPrice")
    print(f"{symbol}: {n} sedute salvate in {out.relative_to(Path.cwd()) if out.is_relative_to(Path.cwd()) else out}; ultimo prezzo {price}")


if __name__ == "__main__":
    main()
