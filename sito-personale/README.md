# Sito personale (portfolio)

Sito personale statico, di impostazione editoriale: una home a sezioni
(apertura, lavori, chi sono, scritti, contatti) più una scheda per ogni progetto.
Nessun framework, nessuna build, nessuna richiesta di rete: si apre anche con
un doppio clic su `index.html`.

## Come si apre

```bash
# dalla cartella del repository
python3 -m http.server 8000
# poi apri http://localhost:8000/sito-personale/
```

Pubblicabile così com'è su GitHub Pages, Netlify o qualsiasi hosting statico.

## Struttura

```
index.html              home a sezioni
progetto.html?id=…      scheda del singolo progetto
assets/css/style.css    stile unico, token colore per tema chiaro e scuro
assets/js/dati.js       TUTTI i contenuti: profilo, progetti, scritti
assets/js/comune.js     tema, menu, testata, copertine generate, comparse
assets/js/site.js       costruzione della home
assets/js/progetto.js   costruzione della scheda progetto
```

## Personalizzarlo

Si modifica un solo file: `assets/js/dati.js`.

- `window.PROFILO` — nome, ruolo, dichiarazione di apertura, testo introduttivo,
  disponibilità, email, contatti, competenze, clienti, percorso professionale.
- `window.PROGETTI` — un oggetto per progetto: `id` (compare nell'URL),
  `anno`, `titolo`, `sommario`, `ruolo`, `durata`, `tag`, `tinta` (i due colori
  della copertina generata), `contesto`, `intervento`, `risultati`.
- `window.SCRITTI` — data, titolo, tempo di lettura e testo di ogni nota.

Restano da aggiornare a mano solo tre cose fuori dai dati:
il `<title>` e i meta `description`/`og:` nelle due pagine HTML, la favicon
(una `data:` URI nel `<head>`, con l'iniziale del nome), e i tre paragrafi
biografici nella sezione "Chi sono" di `index.html`.

I contenuti attuali sono di esempio: la persona, i progetti e i risultati
sono inventati e servono solo a mostrare il sito pieno.

## Cosa fa

- **Tema chiaro/scuro**: segue il sistema, con interruttore che viene ricordato
  (`localStorage`, con accesso protetto per i browser che lo bloccano).
- **Navigazione**: la voce di menu si evidenzia in base alla sezione che si sta
  leggendo, con un menu a comparsa da telefono.
- **Comparsa allo scorrimento** via `IntersectionObserver`, disattivata
  automaticamente se il sistema chiede meno animazioni.
- **Copertine generate**: composizioni SVG deterministiche derivate dall'`id`
  del progetto, quindi nessuna immagine da caricare o gestire.
- **Copia dell'indirizzo email** con un ripiego che, se il browser blocca la
  copia, seleziona comunque l'indirizzo.
- **Accessibilità**: link "vai al contenuto", focus visibile, contrasti
  verificati in entrambi i temi, gerarchia dei titoli coerente, testi
  alternativi sulle illustrazioni.
- Layout responsive, tipografia fluida, stile di stampa essenziale.
