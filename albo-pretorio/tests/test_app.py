import csv
import io
import time
import unittest

from albo.storage import Archivio
from app import crea_app, filtra_atti


class TestApp(unittest.TestCase):
    def setUp(self):
        self.app = crea_app(Archivio(":memory:"), demo=True)
        self.client = self.app.test_client()

    def attendi_fine(self, timeout: float = 10.0) -> dict:
        scadenza = time.time() + timeout
        while time.time() < scadenza:
            stato = self.client.get("/api/stato").get_json()
            if not stato["in_corso"]:
                return stato
            time.sleep(0.05)
        self.fail("estrazione non conclusa in tempo")

    def test_pagina_e_config(self):
        r = self.client.get("/")
        self.assertEqual(r.status_code, 200)
        self.assertIn(b"Albo Pretorio", r.data)
        cfg = self.client.get("/api/config").get_json()
        self.assertTrue(cfg["demo"])
        self.assertIn("papca-ap", cfg["sezioni"])
        self.assertEqual(self.client.get("/static/app.js").status_code, 200)

    def test_archivio_vuoto(self):
        dati = self.client.get("/api/atti?sezione=papca-ap").get_json()
        self.assertEqual(dati["totale"], 0)
        self.assertIsNone(dati["ultima_estrazione"])
        self.assertEqual(self.client.get("/api/atti?sezione=xyz").status_code, 400)

    def test_aggiorna_ed_esporta(self):
        r = self.client.post("/api/aggiorna", json={"sezione": "papca-ap"})
        self.assertEqual(r.status_code, 202)
        self.assertTrue(r.get_json()["avviato"])
        stato = self.attendi_fine()
        self.assertEqual(stato["esito"], "ok", stato)
        self.assertEqual(stato["estrazioni"][0]["n_atti"], 6)

        dati = self.client.get("/api/atti?sezione=papca-ap").get_json()
        self.assertEqual(dati["totale"], 6)
        self.assertEqual(dati["in_pubblicazione"], 6)
        self.assertEqual(dati["tipi"]["Determinazioni"], 1)
        self.assertEqual(dati["ultima_estrazione"]["esito"], "ok")

        atto = self.client.get("/api/atti/papca-ap/3749029").get_json()
        self.assertEqual(atto["numero"], "1532/2026")
        self.assertEqual(self.client.get("/api/atti/papca-ap/0").status_code, 404)

        r = self.client.get("/api/export?sezione=papca-ap&formato=csv&q=imu")
        self.assertEqual(r.status_code, 200)
        self.assertIn("attachment", r.headers["Content-Disposition"])
        righe = list(csv.DictReader(io.StringIO(r.data.decode("utf-8-sig")), delimiter=";"))
        self.assertEqual(len(righe), 1)
        self.assertEqual(righe[0]["numero"], "1531/2026")
        self.assertIn("Delibera GC 210.pdf", righe[0]["allegati"])

        r = self.client.get("/api/export?sezione=papca-ap&formato=json&tipo=Avvisi")
        self.assertEqual(r.get_json()["totale"], 1)

    def test_una_estrazione_alla_volta(self):
        lavoro = self.app.extensions["lavoro"]
        import threading
        blocco = threading.Event()
        lavoro.thread = threading.Thread(target=blocco.wait, daemon=True)
        lavoro.thread.start()
        try:
            r = self.client.post("/api/aggiorna", json={"sezione": "papca-ap"})
            self.assertEqual(r.status_code, 409)
        finally:
            blocco.set()

    def test_filtra_atti(self):
        atti = [
            {"oggetto": "Avviso IMU", "tipo": "Avvisi", "data_inizio": "2026-09-01", "in_pubblicazione": True, "altri_campi": {}},
            {"oggetto": "Determina", "tipo": "Determinazioni", "data_inizio": "2026-08-01", "in_pubblicazione": False, "altri_campi": {"Note": "urgente"}},
        ]
        self.assertEqual(len(filtra_atti(atti, q="imu")), 1)
        self.assertEqual(len(filtra_atti(atti, q="urgente")), 1)
        self.assertEqual(len(filtra_atti(atti, tipo="Avvisi")), 1)
        self.assertEqual(len(filtra_atti(atti, da="2026-08-15")), 1)
        self.assertEqual(len(filtra_atti(atti, a="2026-08-15")), 1)
        self.assertEqual(len(filtra_atti(atti, solo_pubblicati=True)), 1)
        self.assertEqual(len(filtra_atti(atti)), 2)


if __name__ == "__main__":
    unittest.main()
