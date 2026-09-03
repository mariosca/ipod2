/* Tutti i contenuti del sito stanno qui: profilo, progetti, scritti.
   Sono dati di esempio: sostituiscili con i tuoi e il sito si aggiorna da solo. */

window.PROFILO = {
  nome: 'Marta Vinci',
  ruolo: 'Designer e sviluppatrice',
  luogo: 'Bologna, Italia',
  dichiarazione: 'Progetto e costruisco interfacce che restano leggibili quando i dati diventano complicati.',
  intro: 'Lavoro con team piccoli su prodotti digitali: dalla prima ricerca alla messa in produzione, ' +
    'senza passare la palla a metà strada. Dieci anni tra editoria, sanità e strumenti interni.',
  disponibilita: 'Disponibile per nuovi progetti da ottobre 2026',
  email: 'ciao@esempio.it',
  contatti: [
    { etichetta: 'Email', valore: 'ciao@esempio.it', href: 'mailto:ciao@esempio.it' },
    { etichetta: 'LinkedIn', valore: '/in/esempio', href: '#' },
    { etichetta: 'GitHub', valore: '@esempio', href: '#' },
    { etichetta: 'CV', valore: 'PDF, 180 kB', href: '#' }
  ],
  competenze: [
    'Design di sistema e librerie di componenti',
    'Prototipi navigabili in codice, non in slide',
    'Front-end: TypeScript, React, CSS moderno',
    'Accessibilità: WCAG 2.2 AA come base, non come extra',
    'Ricerca con utenti e test di usabilità leggeri',
    'Data visualization e interfacce dense di dati'
  ],
  clienti: ['Editoriale Nord', 'Azienda sanitaria regionale', 'Fondazione Rete Civica',
    'Studio Terzi', 'Cooperativa Mulino', 'Osservatorio Trasporti'],
  percorso: [
    { anni: '2021 — oggi', cosa: 'Indipendente', dove: 'Progetti per team di prodotto e istituzioni' },
    { anni: '2018 — 2021', cosa: 'Lead designer', dove: 'Piattaforma editoriale, 40 persone' },
    { anni: '2015 — 2018', cosa: 'Product designer', dove: 'Software gestionale per la sanità' }
  ]
};

window.PROGETTI = [
  {
    id: 'archivio-editoriale',
    anno: '2026',
    titolo: 'Archivio editoriale consultabile',
    sommario: 'Ottant\'anni di numeri arretrati resi cercabili in una singola interfaccia.',
    ruolo: 'Design e front-end',
    durata: '5 mesi',
    tag: ['Ricerca', 'Design system', 'React'],
    tinta: ['#1f4b6e', '#0b2233'],
    contesto: 'Una casa editrice aveva digitalizzato l\'intero archivio storico, ma i lettori non ' +
      'riuscivano a trovarci nulla: la ricerca restituiva migliaia di risultati indistinguibili.',
    intervento: 'Ho riorganizzato i risultati per tipo di contenuto e periodo, introdotto filtri ' +
      'combinabili con lo stato riflesso nell\'URL e un\'anteprima che mostra il contesto della ' +
      'citazione senza aprire il documento. La griglia dei risultati usa una densità variabile: ' +
      'compatta per chi scorre, estesa per chi legge.',
    risultati: [
      'Ricerche che finiscono con un documento aperto: dal 31% al 68%',
      'Tempo medio per trovare un numero specifico: da 4 minuti a 40 secondi',
      'Trentadue componenti documentati, riusati poi su altri due prodotti interni'
    ]
  },
  {
    id: 'cartella-clinica',
    anno: '2025',
    titolo: 'Cartella clinica per reparti di terapia intensiva',
    sommario: 'Meno clic tra il dato e la decisione, in un contesto dove i secondi contano.',
    ruolo: 'Design, ricerca, prototipi',
    durata: '9 mesi',
    tag: ['Sanità', 'Interfacce dense', 'Accessibilità'],
    tinta: ['#175c4c', '#08241e'],
    contesto: 'Il personale compilava a mano su carta i parametri già presenti a monitor, perché ' +
      'la schermata di inserimento richiedeva undici passaggi e non funzionava con i guanti.',
    intervento: 'Tre settimane di osservazione in reparto prima di disegnare qualsiasi cosa. ' +
      'Ho ridotto l\'inserimento a un flusso unico con conferma implicita, aree tattili da 56 px ' +
      'e una vista di turno che mette in colonna solo i valori fuori soglia.',
    risultati: [
      'Passaggi per registrare un parametro: da 11 a 3',
      'Doppia trascrizione su carta praticamente scomparsa nei reparti pilota',
      'Contrasto e dimensioni validati anche con luce di emergenza'
    ]
  },
  {
    id: 'bilancio-aperto',
    anno: '2025',
    titolo: 'Bilancio comunale in chiaro',
    sommario: 'Un sito che spiega dove vanno i soldi pubblici a chi non legge bilanci.',
    ruolo: 'Design, data visualization, sviluppo',
    durata: '4 mesi',
    tag: ['Dati aperti', 'Visualizzazione', 'Statico'],
    tinta: ['#7a3d10', '#2b1305'],
    contesto: 'I dati erano già pubblici, in fogli di calcolo da 900 righe. Nessuno li apriva, ' +
      'e le poche visualizzazioni esistenti erano illeggibili da telefono.',
    intervento: 'Ho costruito un percorso a tre livelli: la cifra complessiva, la ripartizione ' +
      'per settore, la singola voce con la sua storia negli anni. Ogni grafico ha una versione ' +
      'tabellare accessibile e un link permanente citabile da un articolo.',
    risultati: [
      'Ventimila visite nel primo mese, il 62% da telefono',
      'Ripreso da tre testate locali con link diretti alle singole voci',
      'Pubblicato come sito statico: costo di gestione vicino a zero'
    ]
  },
  {
    id: 'strumenti-interni',
    anno: '2024',
    titolo: 'Pannello operativo per la logistica',
    sommario: 'Lo strumento più usato dell\'azienda, finalmente progettato come un prodotto.',
    ruolo: 'Design e front-end',
    durata: '7 mesi',
    tag: ['Strumenti interni', 'Tabelle', 'Performance'],
    tinta: ['#4a3a86', '#181137'],
    contesto: 'Otto ore al giorno su una tabella con 60 colonne, filtri che si azzeravano a ogni ' +
      'ricaricamento e nessuna scorciatoia da tastiera.',
    intervento: 'Ho lavorato accanto a chi la usa per due settimane, poi riscritto la tabella con ' +
      'colonne configurabili per ruolo, filtri persistenti nell\'URL e una palette di comandi da ' +
      'tastiera. Il rendering è virtualizzato: 50.000 righe scorrono fluide.',
    risultati: [
      'Tempo per completare un turno di controlli: -35%',
      'Righe gestibili senza rallentamenti: da 2.000 a 50.000',
      'Formazione per un nuovo assunto: da due giorni a mezza giornata'
    ]
  },
  {
    id: 'identita-fondazione',
    anno: '2023',
    titolo: 'Identità digitale di una fondazione civica',
    sommario: 'Un sistema visivo che tiene insieme sito, report annuali e materiali di sala.',
    ruolo: 'Design di sistema',
    durata: '3 mesi',
    tag: ['Identità', 'Tipografia', 'Documentazione'],
    tinta: ['#8a2f4a', '#2c0c17'],
    contesto: 'Quattro agenzie in sei anni avevano lasciato sette varianti di logo e nessuna ' +
      'regola scritta. Ogni nuovo documento ripartiva da zero.',
    intervento: 'Scala tipografica unica per schermo e stampa, palette ridotta a cinque colori ' +
      'con contrasti verificati, e un manuale di quaranta pagine con esempi di ciò che si può e ' +
      'non si può fare. Consegnati anche modelli pronti per i documenti ricorrenti.',
    risultati: [
      'Tempo di produzione del report annuale: da sei settimane a due',
      'Materiali prodotti internamente senza passare da fornitori esterni',
      'Manuale ancora in uso senza modifiche dopo tre anni'
    ]
  },
  {
    id: 'orari-trasporti',
    anno: '2022',
    titolo: 'Orari del trasporto locale, leggibili in un colpo d\'occhio',
    sommario: 'Progressive web app per chi aspetta l\'autobus sotto la pioggia.',
    ruolo: 'Design e sviluppo',
    durata: '2 mesi',
    tag: ['PWA', 'Offline', 'Mobile'],
    tinta: ['#0f5b6b', '#052227'],
    contesto: 'L\'app ufficiale richiedeva sei tocchi e una connessione stabile per sapere quando ' +
      'passa il prossimo mezzo alla fermata più vicina.',
    intervento: 'Una schermata sola: fermata rilevata, prossime tre corse, ritardo in evidenza. ' +
      'Gli orari statici restano in cache, quindi funziona anche senza rete; il tempo reale è un ' +
      'miglioramento, non un requisito.',
    risultati: [
      'Dal lancio alla risposta utile: un tocco',
      'Funziona offline sul 100% delle fermate della rete',
      '48 kB totali di JavaScript'
    ]
  }
];

window.SCRITTI = [
  {
    data: '2026-06-14',
    titolo: 'Le tabelle sono interfacce, non contenitori',
    lettura: '8 min',
    testo: 'La maggior parte degli strumenti interni è una tabella travestita da prodotto. ' +
      'Trattarla come tale — densità scelta dall\'utente, filtri persistenti, scorciatoie da ' +
      'tastiera, stati di caricamento che non spostano le righe — vale più di qualsiasi ' +
      'restyling. Tre anni di note su cosa ha funzionato e cosa ho dovuto rifare.'
  },
  {
    data: '2026-02-03',
    titolo: 'Prototipi in codice: quando conviene e quando no',
    lettura: '6 min',
    testo: 'Un prototipo in codice risponde a domande che un prototipo cliccabile non tocca: ' +
      'come si comporta con dati reali, quanto pesa, cosa succede quando la rete cade. Costa ' +
      'più tempo all\'inizio e lo restituisce quando serve discutere di comportamenti anziché ' +
      'di schermate.'
  },
  {
    data: '2025-10-21',
    titolo: 'Accessibilità come vincolo iniziale',
    lettura: '5 min',
    testo: 'Se il contrasto e l\'ordine di tabulazione arrivano in revisione, arrivano tardi: ' +
      'a quel punto sono una lista di correzioni. Messi tra i vincoli del primo giorno, ' +
      'diventano decisioni di progetto, e spesso semplificano anche il resto.'
  },
  {
    data: '2025-05-09',
    titolo: 'Consegnare un design system che qualcuno usi davvero',
    lettura: '9 min',
    testo: 'Un design system senza chi lo mantiene è un archivio di file. Quello che ha ' +
      'funzionato: pochi componenti davvero finiti invece di tanti abbozzati, esempi di uso ' +
      'sbagliato accanto a quelli corretti, e una persona con il mandato di dire no.'
  }
];
