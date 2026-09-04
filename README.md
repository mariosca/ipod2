# Progetti web in questo repository

| Cartella | Sito |
| --- | --- |
| radice (`index.html`, `annuncio.html`, `vendi.html`) | **Claude RC** — mercatino dell'usato per il modellismo radiocomandato |
| [`sito-personale/`](sito-personale/) | **Sito personale** — portfolio editoriale a sezioni con schede di progetto |
| [`albo-pretorio/`](albo-pretorio/) | **Albo Pretorio** — web app Python che estrae e rende consultabili tutti gli atti pubblicati sull'albo pretorio on line del Comune di Città di Castello |

I primi due sono statici, senza build e senza dipendenze esterne; l'albo pretorio ha un
piccolo server Flask (vedi il suo README).

---

# Claude RC — mercatino dell'usato per il modellismo radiocomandato

Sito web statico per annunci di modellismo RC di seconda mano: auto, droni FPV,
aerei, elicotteri, barche, radio, batterie e ricambi.
Nessun framework, nessuna build, nessuna dipendenza esterna.

## Come si apre

Basta aprire `index.html` con un doppio clic: funziona anche da `file://`
perché i dati degli annunci sono in un file JavaScript e non vengono caricati via `fetch`.

Per lavorarci con un server locale (consigliato, così i link relativi si comportano
come in produzione):

```bash
python3 -m http.server 8000
# poi apri http://localhost:8000
```

Il sito è pubblicabile così com'è su GitHub Pages, Netlify, o qualsiasi hosting statico.

## Pagine

| File | Cosa fa |
| --- | --- |
| `index.html` | Elenco annunci con ricerca testuale, filtri, ordinamento e preferiti |
| `annuncio.html?id=…` | Scheda del singolo annuncio con dotazione, caratteristiche e venditore |
| `vendi.html` | Form di pubblicazione con validazione; l'annuncio resta nel browser |

## Funzionalità

- **Ricerca full-text** su titolo, descrizione, dotazione, caratteristiche, città e categoria
  (accenti e maiuscole ignorati, più parole in AND).
- **Filtri**: categoria, prezzo minimo/massimo, condizione, regione, solo con spedizione,
  solo prezzi trattabili, solo preferiti.
- **Ordinamento**: più recenti, prezzo crescente/decrescente, titolo A-Z.
- **Stato nell'URL**: ogni ricerca è condivisibile con un link
  (es. `index.html?categoria=droni&max=300&spedizione=1`).
- **Preferiti** salvati in `localStorage`, con contatore nell'header.
- **Pubblicazione annunci** dal form `vendi.html`: validazione lato client e salvataggio
  nel browser; i propri annunci compaiono in cima all'elenco con l'etichetta "Il tuo annuncio".
- **Tema chiaro/scuro**: segue il sistema, con interruttore manuale che viene ricordato.
- **Layout responsive** con menu mobile, e anteprime SVG generate al volo (nessuna immagine da scaricare).

## Struttura

```
index.html            elenco annunci
annuncio.html         dettaglio annuncio
vendi.html            pubblicazione annuncio
assets/css/style.css  stile unico, token colore per tema chiaro/scuro
assets/js/listings.js dati: categorie e annunci di esempio
assets/js/common.js   utilità condivise (storage, formattazione, card, tema)
assets/js/app.js      logica dell'elenco (ricerca, filtri, ordinamento)
assets/js/detail.js   logica della scheda annuncio
assets/js/sell.js     logica del form di pubblicazione
```

## Modificare gli annunci

Gli annunci vivono in `assets/js/listings.js` come semplici oggetti:

```js
{
  id: 'tt02-pro',                      // usato nell'URL: annuncio.html?id=tt02-pro
  titolo: 'Tamiya TT-02 Pro 1/10…',
  categoria: 'auto',                   // uno degli id in CLAUDE_RC_CATEGORIES
  prezzo: 185,                         // numero in euro, 0 = "Gratis"
  condizione: 'Buono',                 // Ottimo | Buono | Da riparare
  citta: 'Torino',
  regione: 'Piemonte',
  spedizione: true,
  trattabile: true,
  pubblicato: '2026-08-28',            // AAAA-MM-GG
  venditore: { nome: 'Marco P.', valutazione: 4.8, annunci: 12 },
  descrizione: '…',
  dotazione: ['…'],                    // elenco puntato "Cosa è incluso"
  specifiche: { Scala: '1/10' }        // tabella "Caratteristiche", chiavi libere
}
```

Per collegare un vero backend basta sostituire `window.CLAUDE_RC_LISTINGS` con i dati
dell'API: il resto del sito legge sempre e solo da `RC.tuttiGliAnnunci()`.

## Note

Progetto dimostrativo: gli annunci sono inventati, il pulsante "Contatta il venditore"
non invia nulla e tutti i dati dell'utente (preferiti, annunci pubblicati, tema)
restano nel `localStorage` del browser.
