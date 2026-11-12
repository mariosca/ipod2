# Dove Sono Ora — app per iPhone

App nativa SwiftUI: mostra la tua posizione GPS su mappa ibrida, satellitare o
stradale (Apple Maps) oppure sulle carte OpenStreetMap per l'escursionismo
(vedi sotto), con latitudine e longitudine in gradi e decimali, precisione,
altitudine, velocità e direzione, e la condivide via WhatsApp, Telegram, SMS,
email, foglio di condivisione di iOS o appunti. Se il permesso di posizione è
negato puoi inserire le coordinate a mano.

Nessuna chiave API, nessuna dipendenza esterna. iOS 17 o successivo.

## Mappe

| Pulsante | Mappa |
| --- | --- |
| Ibrido, Satellite, Mappa | Apple Maps |
| OSM | Carta OpenStreetMap standard con sopra i sentieri segnati (Waymarked Trails) |
| Topo | OpenTopoMap: sentieri, curve di livello e rilievo |

Le carte OpenStreetMap vengono scaricate dai server pubblici del progetto e
tenute in cache (fino a 300 MB). Servono internet: in zone senza campo restano
visibili solo le zone già viste. Oltre lo zoom massimo del server la mappa
ingrandisce l'ultima tessera disponibile. La scelta della mappa viene ricordata.

## Installarla sul tuo iPhone (gratis, serve un Mac)

1. Installa **Xcode 16** (o più recente) dal Mac App Store.
2. Apri `ios/DoveSonoOra/DoveSonoOra.xcodeproj`.
3. Xcode → **Settings › Accounts**: aggiungi il tuo Apple ID (va bene quello
   gratuito, non serve l'Apple Developer Program).
4. Seleziona il target **DoveSonoOra** → scheda **Signing & Capabilities**:
   - **Team**: scegli il tuo nome (Personal Team);
   - se Xcode segnala che il **Bundle Identifier** è già in uso, cambialo
     (es. `it.tuonome.dovesonoora`).
5. Collega l'iPhone con il cavo, sbloccalo e conferma "Autorizza questo computer".
6. Sull'iPhone attiva **Impostazioni › Privacy e sicurezza › Modalità sviluppatore**
   (il telefono si riavvia).
7. In alto in Xcode scegli il tuo iPhone come destinazione e premi **▶︎ Run**.
8. Al primo avvio iOS blocca l'app: vai su **Impostazioni › Generali ›
   VPN e gestione dispositivi**, tocca il tuo Apple ID e scegli **Autorizza**.
   Riapri l'app e consenti la posizione "Mentre usi l'app".

Con un Apple ID gratuito l'app resta firmata per **7 giorni**: dopo, ricollega
l'iPhone e premi di nuovo Run. Con l'Apple Developer Program (99 €/anno) dura
un anno e puoi distribuirla via TestFlight.

## Senza Mac: la versione web da aggiungere alla Home

La stessa app esiste come pagina web in [`../dove-sono-ora/`](../dove-sono-ora/),
pronta per essere installata sulla schermata Home:

1. Pubblica il repository su GitHub Pages (Settings › Pages › Deploy from a
   branch) e apri `https://<utente>.github.io/ipod2/dove-sono-ora/` in **Safari**.
2. Tocca **Condividi › Aggiungi alla schermata Home**.
3. Apri l'icona dalla Home e consenti la posizione.

Si apre a schermo intero come un'app, con la sua icona. Il GPS funziona perché
la pagina non è dentro un riquadro.

## Struttura

```
DoveSonoOra.xcodeproj       progetto Xcode (cartelle sincronizzate, Xcode 16+)
DoveSonoOra/
  DoveSonoOraApp.swift      punto d'ingresso
  ContentView.swift         pannello coordinate, condivisione
  MapView.swift             mappa (MKMapView), carte OpenStreetMap e OpenTopoMap
  LocationModel.swift       CoreLocation: permesso, aggiornamenti, coordinate manuali
  Formatting.swift          gradi/primi/secondi, testo e link di condivisione
  Assets.xcassets           icona e colore d'accento
```

Il testo del permesso di posizione è nelle impostazioni di build
(`INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`): Info.plist viene generato
da Xcode.
