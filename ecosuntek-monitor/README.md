# Ecosuntek Monitor

Web app statica che monitora il titolo **Ecosuntek** (ticker `ECK`, Euronext Growth Milan,
su Yahoo Finance `ECK.MI`) e riassume in italiano le sue oscillazioni giornaliere.
Nessun framework, nessuna build, nessuna dipendenza esterna.

## Cosa mostra

- **Schede di sintesi**: ultimo prezzo con variazione rispetto alla chiusura precedente,
  apertura, minimo/massimo di seduta con escursione, volume rispetto alla media.
- **Riassunto delle oscillazioni** generato automaticamente:
  - *Ultima seduta*: apertura, chiusura, variazione, escursione intraday, posizione della
    chiusura nel range, volumi rispetto alla media.
  - *Segnali*: movimento anomalo (oltre 2 deviazioni standard), escursione o volumi doppi
    rispetto alla media, chiusura sui massimi/minimi, serie di 3+ sedute nello stesso verso.
  - *Periodo selezionato*: andamento, rialzi/ribassi, variazione media, ampiezza media,
    volatilità, miglior/peggior seduta, distanza da massimo e minimo, media mobile a 20 sedute.
- **Grafici** (SVG, con tooltip al passaggio del mouse): prezzo di chiusura e variazione
  giornaliera in %.
- **Tabella** delle sedute del periodo.
- Periodi: 1 settimana, 1 mese, 3 mesi, 6 mesi, 1 anno. Aggiornamento automatico ogni 5 minuti.

## Come si avvia

### Online, senza installare nulla (consigliato)

Il workflow GitHub Actions `.github/workflows/ecosuntek-monitor.yml` scarica ogni ora,
nei giorni di Borsa, le quotazioni da Yahoo Finance e le salva in `data/ECK.MI.json`;
poi pubblica l'app su GitHub Pages. Per attivarlo, una volta sola:

1. porta questa cartella e il workflow sul branch predefinito del repository (`main`);
2. su GitHub apri **Settings → Pages** e in *Build and deployment* scegli **Source: GitHub Actions**;
3. in **Actions → Ecosuntek Monitor** premi *Run workflow* (oppure aspetta la prossima ora).

L'app sarà su `https://<utente>.github.io/<repository>/ecosuntek-monitor/`.

### In locale

I dati arrivano dall'API pubblica di Yahoo Finance, che non consente richieste dirette da
un altro dominio (CORS). L'app prova in sequenza più sorgenti:

1. il file `data/<SIMBOLO>.json` salvato nel repository dal workflow (se ha meno di 2 giorni);
2. il **proxy locale** `/api/chart` (vedi sotto);
3. Yahoo Finance in diretta;
4. i proxy CORS pubblici `corsproxy.io` e `allorigins.win`;
5. il file del repository anche se vecchio, poi l'ultimo aggiornamento salvato nel browser;
6. **dati dimostrativi simulati**, segnalati con un avviso ben visibile.

Il server locale serve la pagina e fa da proxy:

```bash
cd ecosuntek-monitor
python3 server.py
# poi apri http://localhost:8000
```

Per aggiornare a mano il file del repository: `python3 fetch_data.py` (crea `data/ECK.MI.json`).
In alternativa si può **importare un CSV** (pulsante «Importa CSV») esportato da Yahoo Finance
o da Borsa Italiana: separatori `,` `;` e virgole decimali sono riconosciuti in automatico.

## Altro titolo

Aggiungi `?symbol=TICKER` all'indirizzo, ad esempio `index.html?symbol=ENI.MI`.

## File

| File | Cosa fa |
| --- | --- |
| `index.html` | Struttura della pagina |
| `style.css` | Stile, con tema chiaro e scuro automatico |
| `app.js` | Caricamento dati, statistiche, riassunto, grafici e tabella |
| `demo-data.js` | Serie simulata usata solo quando nessuna sorgente è raggiungibile |
| `server.py` | Server statico + proxy verso Yahoo Finance (solo libreria standard) |
| `fetch_data.py` | Scarica lo storico e lo salva in `data/<SIMBOLO>.json` (usato dal workflow) |
| `data/` | Quotazioni salvate dal workflow GitHub Actions |

Le informazioni sono a solo scopo informativo e non costituiscono consulenza finanziaria.
