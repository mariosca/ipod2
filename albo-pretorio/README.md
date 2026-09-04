# Albo Pretorio — estrattore e consultazione degli atti pubblicati

Web app che scarica **tutti gli atti pubblicati sull'albo pretorio on line del
Comune di Città di Castello** (<https://albopretorio.comune.cittadicastello.pg.it>),
li conserva in un archivio locale e li rende consultabili con ricerca, filtri,
ordinamento ed export CSV/JSON.

La piattaforma dell'ente è **JCityGov Albo Pubblicazioni** (Liferay), la stessa
usata da centinaia di altri comuni italiani: cambiando un indirizzo l'app funziona
anche per loro (vedi [Configurazione](#configurazione)).

## Avvio rapido

```bash
cd albo-pretorio
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python app.py              # apri http://localhost:8000
```

Nell'interfaccia premi **Aggiorna dall'albo**: l'app scorre tutte le pagine
dell'elenco, integra i dati con l'export CSV del portale, scarica le schede di
dettaglio con gli allegati e salva tutto in `data/albo.sqlite`.

Per provare l'interfaccia senza rete, con dati di esempio:

```bash
python app.py --demo
```

## Cosa fa

- **Estrazione completa** di una sezione dell'albo:
  - `papca-ap` — Albo pretorio (atti attualmente in pubblicazione), sezione predefinita
  - `papca-p` — Storico atti (delibere, determine, ordinanze, decreti)
  - `papca-pm` — Pubblicazioni di matrimonio
- **Tre fonti combinate**, così l'estrazione resiste ai cambiamenti di impaginazione del portale:
  1. le pagine HTML dell'elenco (paginazione automatica, tabella o schede);
  2. l'export CSV nativo del portlet (`exportList`), usato per completare o, se
     l'HTML non fosse leggibile, sostituire l'elenco;
  3. la pagina di dettaglio di ogni atto (`/-/papca/display/<id>`), da cui arrivano
     numero e data dell'atto, campi aggiuntivi e tutti gli allegati (anche firmati `.p7m`).
- **Archivio locale SQLite**: gli atti restano anche quando la pubblicazione scade;
  il campo *in pubblicazione* indica se erano presenti nell'ultima estrazione.
- **Interfaccia**: ricerca full-text (accenti e maiuscole ignorati), filtro per
  tipologia e intervallo di date, ordinamento, evidenza degli atti in scadenza,
  scheda di dettaglio espandibile con tutti i campi e gli allegati, export CSV/JSON
  con i filtri correnti, tema chiaro/scuro, layout responsive.
- **API REST** e **riga di comando** per usare i dati altrove.

## Riga di comando

```bash
python -m albo.scraper --sezione papca-ap --formato json --out atti.json
python -m albo.scraper --formato csv --out atti.csv --senza-dettagli   # più veloce
python -m albo.scraper --base-url https://albopretorio.comune.rimini.it -v
python -m albo.scraper --demo
```

## API

| Metodo e percorso | Cosa fa |
| --- | --- |
| `GET /api/config` | ente, indirizzo del portale, sezioni, conteggi |
| `GET /api/atti?sezione=papca-ap` | atti in archivio, tipologie, ultima estrazione |
| `GET /api/atti/<sezione>/<id>` | singolo atto |
| `POST /api/aggiorna` `{"sezione": "papca-ap", "dettagli": true, "csv": true}` | avvia un'estrazione in background (409 se già in corso) |
| `GET /api/stato` | avanzamento dell'estrazione e storico delle ultime esecuzioni |
| `GET /api/export?sezione=…&formato=csv\|json&q=…&tipo=…&da=…&a=…&solo_pubblicati=1` | download con gli stessi filtri dell'interfaccia |

Ogni atto è un oggetto di questa forma:

```json
{
  "id": "3749029",
  "sezione": "papca-ap",
  "url": "https://albopretorio.comune.cittadicastello.pg.it/web/trasparenza/papca-ap/-/papca/display/3749029",
  "numero": "1532/2026",
  "tipo": "Determinazioni",
  "oggetto": "Approvazione del calendario delle manifestazioni …",
  "data_inizio": "2026-09-01",
  "data_fine": "2026-09-16",
  "ente": "Comune di Città di Castello - Settore Cultura",
  "numero_atto": "812",
  "data_atto": "2026-08-29",
  "anno": "2026",
  "allegati": [{ "nome": "Determina_1532.pdf", "url": "…downloadAllegato…", "firmato": false }],
  "altri_campi": { "Responsabile del procedimento": "…" },
  "in_pubblicazione": true,
  "primo_visto": "2026-09-04T08:30:00+00:00",
  "ultimo_visto": "2026-09-04T08:30:00+00:00"
}
```

## Configurazione

Tutto si regola con variabili d'ambiente (vedi `albo/config.py`):

| Variabile | Predefinito | Significato |
| --- | --- | --- |
| `ALBO_BASE_URL` | `https://albopretorio.comune.cittadicastello.pg.it` | installazione JCityGov da interrogare |
| `ALBO_ENTE` | `Comune di Città di Castello` | nome mostrato nell'interfaccia |
| `ALBO_SEZIONE` | `papca-ap` | sezione predefinita |
| `ALBO_DB` | `data/albo.sqlite` | percorso dell'archivio |
| `ALBO_PAUSA` | `0.25` | secondi di pausa tra le richieste al portale |
| `ALBO_THREAD_DETTAGLI` | `4` | schede di dettaglio scaricate in parallelo |
| `ALBO_RIGHE_PER_PAGINA` | `75` | righe richieste per pagina dell'elenco |
| `ALBO_MAX_PAGINE` | `500` | limite di sicurezza sulle pagine scorse |
| `ALBO_HOST`, `PORT` | `127.0.0.1`, `8000` | indirizzo e porta del server |
| `ALBO_DEMO` | | `1` per usare le pagine di esempio |

## Struttura

```
app.py                  server Flask: interfaccia + API + estrazione in background
albo/config.py          indirizzi, sezioni e parametri del portlet JCityGov
albo/parser.py          analisi HTML (elenco, dettaglio) e CSV — senza rete
albo/scraper.py         scaricamento, paginazione, fusione delle fonti, CLI
albo/storage.py         archivio SQLite e storico delle estrazioni
albo/demo.py            recuperatore che serve le pagine di esempio
static/                 interfaccia (HTML, CSS, JS vanilla)
tests/                  test unitari + fixture HTML/CSV che imitano il portale
```

Test:

```bash
python -m unittest discover -s tests -v
```

## Come funziona il parser

Le pagine JCityGov cambiano da ente a ente (tabella o schede, etichette diverse),
perciò `albo/parser.py` non dipende da classi CSS precise:

1. cerca una **tabella** con un'intestazione "Oggetto" e legge le colonne per etichetta;
2. altrimenti individua i **link di dettaglio** (`/papca/display/<id>`) e analizza il
   contenitore di ciascuno (`dt/dd`, coppie `label/value`, `<strong>Etichetta:</strong>`,
   infine il testo piatto "Etichetta: valore");
3. riconosce le etichette con un elenco di sinonimi (`Numero registrazione`,
   `N. registro`, `Tipologia`, `Tipo atto`, `Data inizio pubblicazione`,
   `Pubblicato dal`, `Scadenza`, …) e normalizza le date in ISO;
4. i campi non riconosciuti finiscono comunque in `altri_campi`.

La paginazione segue il link "successiva" quando c'è, altrimenti i parametri
standard `cur`/`delta` del SearchContainer Liferay, e si ferma quando una pagina non
porta atti nuovi o quando raggiunge il totale dichiarato dal portale.

## Avvertenze

- Il parser è stato sviluppato e testato su pagine di esempio costruite sul modello
  delle installazioni JCityGov pubbliche: **alla prima esecuzione contro il portale
  reale verifica** che numero di atti, date e allegati coincidano con l'albo ufficiale.
  Se l'ente usa un'impaginazione diversa, il caso da coprire è quasi sempre un nuovo
  sinonimo in `CAMPI` (in `albo/parser.py`) o una fixture aggiuntiva.
- L'app fa richieste con pausa e con un `User-Agent` esplicito: usala con
  moderazione, è un servizio pubblico condiviso.
- Fanno fede esclusivamente le pubblicazioni sull'albo ufficiale dell'ente.
