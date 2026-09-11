#!/usr/bin/env python3
"""Server locale per Ecosuntek Monitor.

Serve i file statici della cartella e fa da proxy verso Yahoo Finance su /api/chart,
così il browser non incontra il blocco CORS. Solo libreria standard.

Uso:
    python3 server.py            # http://localhost:8000
    python3 server.py 8080       # porta diversa
"""
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SYMBOL_RE = re.compile(r"^[A-Z0-9.^=\-]{1,20}$")
RANGES = {"5d", "1mo", "3mo", "6mo", "1y", "2y", "5y", "max"}
CACHE_TTL = 60  # secondi
_cache = {}


def fetch_chart(symbol, rng):
    key = (symbol, rng)
    now = time.time()
    hit = _cache.get(key)
    if hit and now - hit[0] < CACHE_TTL:
        return hit[1]
    url = (
        "https://query1.finance.yahoo.com/v8/finance/chart/"
        f"{urllib.parse.quote(symbol)}?range={rng}&interval=1d&events=div,splits"
    )
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        body = resp.read()
    json.loads(body)  # verifica che sia JSON valido
    _cache[key] = (now, body)
    return body


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_GET(self):
        parsed = urllib.parse.urlsplit(self.path)
        if parsed.path != "/api/chart":
            return super().do_GET()
        qs = urllib.parse.parse_qs(parsed.query)
        symbol = qs.get("symbol", ["ECK.MI"])[0].upper()
        rng = qs.get("range", ["1y"])[0]
        if not SYMBOL_RE.match(symbol) or rng not in RANGES:
            return self._send(400, {"error": "parametri non validi"})
        try:
            body = fetch_chart(symbol, rng)
        except urllib.error.HTTPError as e:
            return self._send(e.code, {"error": f"Yahoo Finance ha risposto {e.code}"})
        except Exception as e:  # rete assente, timeout, JSON corrotto
            return self._send(502, {"error": str(e)})
        self._send(200, body)

    def _send(self, status, payload):
        data = payload if isinstance(payload, bytes) else json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.log_date_time_string(), fmt % args))


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    print(f"Ecosuntek Monitor su http://localhost:{port}  (Ctrl+C per fermare)")
    ThreadingHTTPServer(("", port), Handler).serve_forever()
