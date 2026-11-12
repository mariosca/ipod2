# Edicola — le prime notizie dei quotidiani, per iPhone

App nativa SwiftUI (iOS 17+) che legge i feed RSS dei principali quotidiani
italiani e stranieri e mostra le prime 10 notizie di ciascuno.

- **Intestazione**: la tua foto (toccala per sceglierla dalla galleria, tienila
  premuta per toglierla), il titolo "MARIO'S EDICOLA" e sotto la data e l'ora di
  oggi, aggiornate ogni minuto. Toccando il titolo si apre una nuova email.
- **Sezioni**: News - Ita, News - Eng, Economia, Tecnologia, IA, Programmazione,
  Sicurezza, Scienza, Sport, Cultura, Design, Cucina, Vegan Giuliana, Vegan Inglesi, Videogiochi, Fumetti,
  Podcast, YouTube e Reddit, in una fila scorrevole in alto. Si scaricano solo i
  feed della sezione che stai guardando.
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
| Il Giornale | https://www.ilgiornale.it/feed.xml |
| Il Messaggero | https://www.ilmessaggero.it/rss/home.xml |
| Il Mattino | https://www.ilmattino.it/rss/home.xml |
| Rai News | https://www.rainews.it/rss/tutti |

### Estero

| Giornale | Paese | Feed RSS |
| --- | --- | --- |
| BBC News | Regno Unito | https://feeds.bbci.co.uk/news/rss.xml |
| The Guardian | Regno Unito | https://www.theguardian.com/international/rss |
| The New York Times | USA | https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml |
| The Washington Post | USA | https://feeds.washingtonpost.com/rss/world |
| NPR | USA | https://feeds.npr.org/1001/rss.xml |
| Le Monde | Francia | https://www.lemonde.fr/rss/une.xml |
| Le Figaro | Francia | https://www.lefigaro.fr/rss/figaro_actualites.xml |
| El País | Spagna | https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada |
| Der Spiegel | Germania | https://www.spiegel.de/schlagzeilen/index.rss |
| Frankfurter Allgemeine | Germania | https://www.faz.net/rss/aktuell/ |
| Al Jazeera | Qatar | https://www.aljazeera.com/xml/rss/all.xml |
| The Independent | Regno Unito | https://www.independent.co.uk/news/world/rss |
| Süddeutsche Zeitung | Germania | https://rss.sueddeutsche.de/rss/Topthemen |
| Neue Zürcher Zeitung | Svizzera | https://www.nzz.ch/recent.rss |
| The Times of India | India | https://timesofindia.indiatimes.com/rssfeedstopstories.cms |
| France 24 | Francia | https://www.france24.com/en/rss |

Il primo elenco è in `Edicola/Models.swift` (`Feed.defaults`). Le modifiche
fatte dall'app restano salvate sul telefono. Quando un feed dell'elenco iniziale
viene tolto o aggiunto, la modifica va anche in `Feed.migrations`: così arriva
pure a chi ha già l'app, senza far ricomparire i giornali che ha eliminato.

Molti giornali offrono anche feed per sezione (politica, economia, sport…): di
solito sono elencati in una pagina "RSS" linkata in fondo al sito. Si
aggiungono da **Giornali › Aggiungi giornale**. L'app accetta solo indirizzi
`https://`.

### Le altre sezioni

Vengono dalla pagina [I migliori feed RSS](https://feeder.co/it/knowledge-base/rss-content/popular-rss-feeds/)
di Feeder: 149 feed, nella sezione `Feed.migrations` versione 4 di `Models.swift`.
Gli indirizzi `http://` sono stati portati a `https://` (iOS non scarica feed
non cifrati): se uno di questi non risponde in https, compare in errore.
Esclusi: i due feed del Wall Street Journal (tolto dall'elenco su richiesta), i
doppioni di giornali già presenti e i bollettini tecnici di Bell Helicopter.

### Vegan Giuliana e Vegan Inglesi

**Vegan Giuliana**: otto blog in italiano, con i feed scaricati e controllati prima di inserirli:
Vegolosi (ricette vegane), Benvenuti a Las Vegans, Timo e lenticchie, greenMe
(ricette vegan), Ortaggi che passione, Studenti ai fornelli, Anna e la sua
cucina, In cucina con Mary (le ultime cinque sono blog di GialloZafferano, per
alcune solo la categoria vegana). **Vegan Inglesi**: quattordici blog in inglese, dall'elenco
[Top Vegan RSS Feeds](https://rss.feedspot.com/vegan_rss_feeds/) di Feedspot:
Vegan Richa, It Doesn't Taste Like Chicken, Pick Up Limes, Connoisseurus Veg,
Lazy Cat Kitchen, Minimalist Baker, Nora Cooks, Rainbow Plant Life, Elavegan,
Oh She Glows, The First Mess, The Plant Based School, The Vegan Italian Kitchen
e VegNews. Esclusi VeganBlog.it (blocca le app) e Cucina Botanica (non ha un
feed).

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
