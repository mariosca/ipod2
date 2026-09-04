import os
import unittest

from albo.parser import (chiave_campo, normalizza_data, parse_csv, parse_dettaglio, parse_lista)

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")
BASE = "https://albopretorio.comune.cittadicastello.pg.it"


def leggi(nome: str, binario: bool = False):
    with open(os.path.join(FIXTURES, nome), "rb" if binario else "r", **({} if binario else {"encoding": "utf-8"})) as f:
        return f.read()


class TestEtichette(unittest.TestCase):
    def test_sinonimi(self):
        casi = {
            "Numero registrazione": "numero", "N. Registro": "numero", "Numero albo:": "numero",
            "Tipologia": "tipo", "Tipo atto": "tipo", "Categoria": "tipo",
            "Oggetto": "oggetto", "Descrizione": "oggetto",
            "Data inizio pubblicazione": "data_inizio", "Data pubblicazione": "data_inizio", "Pubblicato dal": "data_inizio",
            "Data fine pubblicazione": "data_fine", "Scadenza": "data_fine", "al": "data_fine",
            "Ente": "ente", "Mittente": "ente", "Ufficio proponente": "ente",
            "Numero atto": "numero_atto", "Data atto": "data_atto", "Data adozione": "data_atto", "Anno": "anno",
        }
        for etichetta, atteso in casi.items():
            self.assertEqual(chiave_campo(etichetta), atteso, etichetta)
        self.assertIsNone(chiave_campo("Responsabile del procedimento"))
        self.assertIsNone(chiave_campo(""))

    def test_date(self):
        self.assertEqual(normalizza_data("01/09/2026"), "2026-09-01")
        self.assertEqual(normalizza_data("dal 1-9-2026"), "2026-09-01")
        self.assertEqual(normalizza_data("2026-09-01T00:00"), "2026-09-01")
        self.assertIsNone(normalizza_data("31/02/2026"))
        self.assertIsNone(normalizza_data("n.d."))


class TestLista(unittest.TestCase):
    def test_tabella(self):
        url = BASE + "/web/trasparenza/papca-ap?_jcitygovalbopubblicazioni_WAR_jcitygovalbiportlet_cur=1"
        r = parse_lista(leggi("lista_1.html"), BASE, "papca-ap", url)
        self.assertEqual(r["strategia"], "tabella")
        self.assertEqual(len(r["atti"]), 3)
        primo = r["atti"][0]
        self.assertEqual(primo["id"], "3749029")
        self.assertEqual(primo["url"], BASE + "/web/trasparenza/papca-ap/-/papca/display/3749029")
        self.assertEqual(primo["numero"], "1532/2026")
        self.assertEqual(primo["tipo"], "Determinazioni")
        self.assertTrue(primo["oggetto"].startswith("Approvazione del calendario"))
        self.assertEqual(primo["data_inizio"], "2026-09-01")
        self.assertEqual(primo["data_fine"], "2026-09-16")
        self.assertEqual(primo["ente"], "Comune di Città di Castello - Settore Cultura")
        self.assertEqual(primo["anno"], "2026")
        self.assertEqual(len(primo["allegati"]), 2)
        self.assertFalse(primo["allegati"][0]["firmato"])
        self.assertTrue(primo["allegati"][1]["firmato"])
        self.assertNotIn("Documenti", primo["altri_campi"])
        # atto senza allegati
        self.assertEqual(r["atti"][2]["allegati"][0]["nome"], "Avviso.pdf")

    def test_paginazione(self):
        r = parse_lista(leggi("lista_1.html"), BASE, "papca-ap")
        pag = r["paginazione"]
        self.assertEqual(pag["totale"], 5)
        self.assertEqual(pag["pagina"], 1)
        self.assertEqual(pag["pagine"], 2)
        self.assertEqual(pag["per_pagina"], 3)
        self.assertIn("_jcitygovalbopubblicazioni_WAR_jcitygovalbiportlet_cur=2", pag["url_successiva"])
        ultima = parse_lista(leggi("lista_2.html"), BASE, "papca-ap")["paginazione"]
        self.assertIsNone(ultima["url_successiva"])
        self.assertEqual(ultima["pagina"], 2)

    def test_contenitori(self):
        r = parse_lista(leggi("lista_contenitori.html"), BASE, "papca-ap")
        self.assertEqual(r["strategia"], "contenitori")
        self.assertEqual([a["id"] for a in r["atti"]], ["111", "110"])
        a, b = r["atti"]
        self.assertEqual(a["numero"], "77/2026")
        self.assertEqual(a["tipo"], "Decreti")
        self.assertEqual(a["oggetto"], "Decreto di nomina del responsabile della protezione dei dati")
        self.assertEqual((a["data_inizio"], a["data_fine"]), ("2026-09-02", "2026-09-17"))
        self.assertEqual(a["allegati"][0]["url"], BASE + "/documenti/decreto_77.pdf")
        self.assertEqual(b["numero"], "76/2026")
        self.assertEqual(b["tipo"], "Avvisi")
        self.assertEqual(b["oggetto"], "Avviso di selezione per rilevatori statistici")
        self.assertEqual((b["data_inizio"], b["data_fine"]), ("2026-09-01", "2026-09-30"))
        self.assertEqual(r["paginazione"]["totale"], 2)

    def test_pagina_senza_atti(self):
        r = parse_lista("<html><body><p>Nessun risultato trovato</p></body></html>", BASE, "papca-ap")
        self.assertEqual(r["strategia"], "nessuna")
        self.assertEqual(r["atti"], [])


class TestDettaglio(unittest.TestCase):
    def test_campi_e_allegati(self):
        url = BASE + "/web/trasparenza/papca-ap/-/papca/display/3749029"
        d = parse_dettaglio(leggi("dettaglio.html"), BASE, "papca-ap", url)
        self.assertEqual(d["id"], "3749029")
        self.assertEqual(d["numero"], "1532/2026")
        self.assertEqual(d["numero_atto"], "812")
        self.assertEqual(d["data_atto"], "2026-08-29")
        self.assertEqual(d["altri_campi"]["Responsabile del procedimento"], "Dott. Mario Rossi")
        self.assertEqual([a["nome"] for a in d["allegati"]], ["Determina_1532.pdf", "Allegato A - Calendario.pdf"])


class TestCsv(unittest.TestCase):
    def test_export(self):
        atti = parse_csv(leggi("export.csv", binario=True), "papca-ap")
        self.assertEqual(len(atti), 6)
        self.assertEqual(atti[0]["numero"], "1532/2026")
        self.assertEqual(atti[0]["data_inizio"], "2026-09-01")
        self.assertEqual(atti[0]["numero_atto"], "812")
        self.assertTrue(atti[0]["id"].startswith("h-"))
        self.assertEqual(atti[5]["tipo"], "Concorsi")

    def test_virgole_e_bom(self):
        dati = "﻿Oggetto,Data pubblicazione,Numero\nProva,05/09/2026,12/2026\n".encode("utf-8")
        atti = parse_csv(dati)
        self.assertEqual(atti[0]["oggetto"], "Prova")
        self.assertEqual(atti[0]["data_inizio"], "2026-09-05")
        self.assertEqual(atti[0]["numero"], "12/2026")

    def test_vuoto(self):
        self.assertEqual(parse_csv(b""), [])


if __name__ == "__main__":
    unittest.main()
