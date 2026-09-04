import unittest

from albo import config
from albo.demo import RecuperatoreDemo
from albo.scraper import Estrattore
from albo.storage import Archivio


class TestEstrattoreDemo(unittest.TestCase):
    def setUp(self):
        self.rec = RecuperatoreDemo(config.BASE_URL)
        self.progressi = []
        self.estrattore = Estrattore(config.BASE_URL, recuperatore=self.rec, progresso=self.progressi.append)

    def test_elenco_scorre_le_pagine(self):
        atti, stat = self.estrattore.elenco("papca-ap")
        self.assertEqual(len(atti), 5)
        self.assertEqual(stat["pagine"], 2)
        self.assertEqual(stat["strategia"], "tabella")
        self.assertEqual(stat["totale_dichiarato"], 5)
        self.assertEqual(self.rec.richieste, 2)

    def test_estrazione_completa(self):
        ris = self.estrattore.estrai("papca-ap")
        stat = ris["statistiche"]
        self.assertEqual(stat["atti_elenco"], 5)
        self.assertEqual(stat["atti_csv"], 6)
        self.assertEqual(stat["csv_aggiunti"], 1)      # il CSV contiene un atto in più
        self.assertEqual(stat["dettagli_ok"], 5)
        self.assertEqual(stat["dettagli_errore"], 0)
        self.assertEqual(stat["atti"], 6)
        self.assertEqual(ris["errori"], [])
        per_id = {a["id"]: a for a in ris["atti"]}
        # i campi del dettaglio completano quelli dell'elenco
        a = per_id["3749010"]
        self.assertEqual(a["numero_atto"], "210")
        self.assertEqual(a["data_atto"], "2026-08-28")
        self.assertEqual(a["altri_campi"]["Responsabile del procedimento"], "Dott.ssa Anna Bianchi")
        self.assertEqual(len(a["allegati"]), 2)
        # l'atto presente solo nel CSV ha un id sintetico e nessun link
        solo_csv = [x for x in ris["atti"] if x["id"].startswith("h-")]
        self.assertEqual(len(solo_csv), 1)
        self.assertEqual(solo_csv[0]["tipo"], "Concorsi")
        # ordinamento: più recenti prima
        self.assertEqual([x["numero"] for x in ris["atti"]][:2], ["1532/2026", "1531/2026"])
        fasi = {p["fase"] for p in self.progressi}
        self.assertEqual(fasi, {"elenco", "csv", "dettagli"})

    def test_senza_dettagli_e_csv(self):
        ris = self.estrattore.estrai("papca-ap", con_dettagli=False, con_csv=False)
        self.assertEqual(ris["statistiche"]["atti"], 5)
        self.assertEqual(self.rec.richieste, 2)

    def test_fusione_non_sovrascrive(self):
        dest = {"id": "h-abc", "numero": "1/2026", "oggetto": "A", "allegati": [], "altri_campi": {"x": "1"}}
        sorg = {"id": "42", "numero": "9/2026", "tipo": "Avvisi", "allegati": [{"nome": "f", "url": "u", "firmato": False}],
                "altri_campi": {"x": "2", "y": "3"}}
        Estrattore.fondi(dest, sorg)
        self.assertEqual(dest["id"], "42")
        self.assertEqual(dest["numero"], "1/2026")
        self.assertEqual(dest["tipo"], "Avvisi")
        self.assertEqual(dest["altri_campi"], {"x": "1", "y": "3"})
        self.assertEqual(len(dest["allegati"]), 1)


class TestArchivio(unittest.TestCase):
    def test_salva_e_rileggi(self):
        archivio = Archivio(":memory:")
        ris = Estrattore(config.BASE_URL, recuperatore=RecuperatoreDemo()).estrai("papca-ap", con_dettagli=False)
        archivio.salva_estrazione("papca-ap", ris["atti"], ris["statistiche"], ris["errori"])
        atti = archivio.atti("papca-ap")
        self.assertEqual(len(atti), 6)
        self.assertTrue(all(a["in_pubblicazione"] for a in atti))
        self.assertEqual(archivio.conteggi(), {"papca-ap": 6})
        ultima = archivio.ultima_estrazione("papca-ap")
        self.assertEqual(ultima["n_atti"], 6)
        self.assertEqual(ultima["statistiche"]["strategia"], "tabella")
        # una nuova estrazione con meno atti: quelli spariti restano ma non sono più "in pubblicazione"
        import time
        time.sleep(1.1)
        archivio.salva_estrazione("papca-ap", ris["atti"][:2], {}, [])
        atti = archivio.atti("papca-ap")
        self.assertEqual(len(atti), 6)
        self.assertEqual(sum(1 for a in atti if a["in_pubblicazione"]), 2)
        self.assertIsNotNone(archivio.atto("papca-ap", ris["atti"][0]["id"]))
        self.assertIsNone(archivio.atto("papca-ap", "non-esiste"))


if __name__ == "__main__":
    unittest.main()
