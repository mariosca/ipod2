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

I dati arrivano dall'API pubblica di Yahoo Finance, che non consente richieste dirette da
un altro dominio (CORS). L'app prova in sequenza più sorgenti:

1. il **proxy locale** `/api/chart` (vedi sotto);
2. Yahoo Finance in diretta;
3. i proxy CORS pubblici `corsproxy.io` e `allorigins.win`;
4. l'ultimo aggiornamento salvato nel browser;
5. **dati dimostrativi simulati**, segnalati con un avviso ben visibile.

Il modo più affidabile è il server locale, che serve la pagina e fa da proxy:

```bash
cd ecosuntek-monitor
python3 server.py
# poi apri http://localhost:8000
```

Pubblicata su GitHub Pages o altro hosting statico, l'app usa i proxy CORS pubblici.
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

Le informazioni sono a solo scopo informativo e non costituiscono consulenza finanziaria.
