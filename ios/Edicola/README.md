# Edicola — le prime notizie dei quotidiani, per iPhone

App nativa SwiftUI (iOS 17+) che legge i feed RSS dei principali quotidiani
italiani e stranieri e mostra le prime 10 notizie di ciascuno.

- **Italia / Estero**: il selettore in alto divide i giornali per zona.
- **Vista d'insieme**: ogni giornale è un riquadro con il nome, da quanto è
  aggiornato e le prime tre notizie (la prima con foto, se il feed la fornisce).
  I riquadri sono ordinati **dal giornale aggiornato più di recente**.
- **Un giornale**: tocca il riquadro per vedere le sue prime 10 notizie con
  sommario; tocca una notizia per leggerla nel browser interno (con modalità
  lettura di Safari).
- **Aggiornamento**: all'apertura, al ritorno nell'app dopo 10 minuti e
  tirando giù l'elenco. Le ultime notizie restano salvate e compaiono subito.
- **Giornali** (icona in alto a destra): attiva o disattiva i giornali,
  correggi un indirizzo, aggiungine di nuovi, eliminali o ripristina l'elenco.

Nessuna chiave API, nessun server, nessuna dipendenza esterna.

## Feed inclusi

Indirizzi pubblici dei giornali. Non è stato possibile scaricarli per
verificarli mentre l'app veniva scritta: se uno non funziona, nell'app compare
l'errore sotto il suo nome e lo si corregge da **Giornali**.

### Italia

| Giornale | Feed RSS |
| --- | --- |
| ANSA | https://www.ansa.it/sito/notizie/topnews/topnews_rss.xml |
| Corriere della Sera | https://xml2.corriereobjects.it/rss/homepage.xml |
| la Repubblica | https://www.repubblica.it/rss/homepage/rss2.0.xml |
| La Stampa | https://www.lastampa.it/rss/copertina.xml |
| Il Sole 24 Ore | https://www.ilsole24ore.com/rss/italia.xml |
| Il Fatto Quotidiano | https://www.ilfattoquotidiano.it/feed/ |
| Il Post | https://www.ilpost.it/feed/ |
| Il Messaggero | https://www.ilmessaggero.it/rss/home.xml |
| Avvenire | https://www.avvenire.it/rss |
| Rai News | https://www.rainews.it/rss/tutti |

### Estero

| Giornale | Paese | Feed RSS |
| --- | --- | --- |
| BBC News | Regno Unito | https://feeds.bbci.co.uk/news/rss.xml |
| The Guardian | Regno Unito | https://www.theguardian.com/international/rss |
| The New York Times | USA | https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml |
| The Washington Post | USA | https://feeds.washingtonpost.com/rss/world |
| The Wall Street Journal | USA | https://feeds.a.dj.com/rss/RSSWorldNews.xml |
| NPR | USA | https://feeds.npr.org/1001/rss.xml |
| Le Monde | Francia | https://www.lemonde.fr/rss/une.xml |
| Le Figaro | Francia | https://www.lefigaro.fr/rss/figaro_actualites.xml |
| El País | Spagna | https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada |
| Der Spiegel | Germania | https://www.spiegel.de/schlagzeilen/index.rss |
| Frankfurter Allgemeine | Germania | https://www.faz.net/rss/aktuell/ |
| Al Jazeera | Qatar | https://www.aljazeera.com/xml/rss/all.xml |

Il primo elenco è in `Edicola/Models.swift` (`Feed.defaults`). Le modifiche
fatte dall'app restano salvate sul telefono.

Molti giornali offrono anche feed per sezione (politica, economia, sport…): di
solito sono elencati in una pagina "RSS" linkata in fondo al sito. Si
aggiungono da **Giornali › Aggiungi giornale**. L'app accetta solo indirizzi
`https://`.

## Installarla sull'iPhone

Come per Dove Sono Ora (vedi [`../README.md`](../README.md)):

1. Apri `ios/Edicola/Edicola.xcodeproj` con Xcode 16 o più recente.
2. Target **Edicola** › **Signing & Capabilities** › **Team**: il tuo Apple ID.
   Se il Bundle Identifier è già in uso, cambialo (es. `it.tuonome.edicola`).
3. Collega l'iPhone, sceglilo in alto come destinazione e premi **▶︎**.

## Struttura

```
Edicola/
  EdicolaApp.swift          punto d'ingresso
  Models.swift              giornale, notizia, elenco iniziale dei feed
  FeedParser.swift          lettura di RSS 2.0, RSS 1.0 e Atom, date, pulizia HTML
  FeedStore.swift           scaricamento in parallelo, ordine, cache, modifiche all'elenco
  HomeView.swift            Italia/Estero e vista d'insieme a riquadri
  FeedDetailView.swift      prime 10 notizie di un giornale, browser interno
  FeedsSettingsView.swift   gestione dei giornali
```
