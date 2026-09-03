/* Funzioni condivise da tutte le pagine di Claude RC.
   Nessuna dipendenza esterna: il sito funziona anche aperto da file:// */
(function () {
  'use strict';

  var STORAGE_PREFERITI = 'claude-rc:preferiti';
  var STORAGE_ANNUNCI = 'claude-rc:annunci-utente';
  var STORAGE_TEMA = 'claude-rc:tema';

  /* ---------- storage tollerante ai browser che lo bloccano ---------- */

  function leggi(chiave, fallback) {
    try {
      var raw = localStorage.getItem(chiave);
      return raw ? JSON.parse(raw) : fallback;
    } catch (e) {
      return fallback;
    }
  }

  function scrivi(chiave, valore) {
    try {
      localStorage.setItem(chiave, JSON.stringify(valore));
      return true;
    } catch (e) {
      return false;
    }
  }

  /* ---------- dati ---------- */

  function categorie() {
    return window.CLAUDE_RC_CATEGORIES || [];
  }

  function categoria(id) {
    var trovate = categorie().filter(function (c) { return c.id === id; });
    return trovate[0] || { id: id, nome: 'Altro', icona: 'gear' };
  }

  function annunciUtente() {
    var salvati = leggi(STORAGE_ANNUNCI, []);
    return Array.isArray(salvati) ? salvati : [];
  }

  function tuttiGliAnnunci() {
    return annunciUtente().concat(window.CLAUDE_RC_LISTINGS || []);
  }

  function annuncio(id) {
    var trovati = tuttiGliAnnunci().filter(function (a) { return a.id === id; });
    return trovati[0] || null;
  }

  function salvaAnnuncio(nuovo) {
    var elenco = annunciUtente();
    elenco.unshift(nuovo);
    return scrivi(STORAGE_ANNUNCI, elenco);
  }

  /* ---------- preferiti ---------- */

  function preferiti() {
    var salvati = leggi(STORAGE_PREFERITI, []);
    return Array.isArray(salvati) ? salvati : [];
  }

  function isPreferito(id) {
    return preferiti().indexOf(id) !== -1;
  }

  function togglePreferito(id) {
    var elenco = preferiti();
    var i = elenco.indexOf(id);
    if (i === -1) { elenco.push(id); } else { elenco.splice(i, 1); }
    scrivi(STORAGE_PREFERITI, elenco);
    aggiornaContatorePreferiti();
    return elenco.indexOf(id) !== -1;
  }

  function aggiornaContatorePreferiti() {
    var n = preferiti().length;
    var nodi = document.querySelectorAll('[data-conta-preferiti]');
    for (var i = 0; i < nodi.length; i++) {
      nodi[i].textContent = n ? String(n) : '';
      nodi[i].hidden = n === 0;
    }
  }

  /* ---------- formattazione ---------- */

  var MESI = ['gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
    'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'];

  function prezzo(valore) {
    if (valore === 0) return 'Gratis';
    return '€ ' + Number(valore).toLocaleString('it-IT');
  }

  function dataBreve(iso) {
    var parti = String(iso).split('-');
    if (parti.length !== 3) return iso;
    return Number(parti[2]) + ' ' + MESI[Number(parti[1]) - 1] + ' ' + parti[0];
  }

  function daQuanto(iso) {
    var oggi = new Date();
    var d = new Date(iso + 'T00:00:00');
    if (isNaN(d.getTime())) return '';
    var giorni = Math.round((oggi - d) / 86400000);
    if (giorni <= 0) return 'oggi';
    if (giorni === 1) return 'ieri';
    if (giorni < 7) return giorni + ' giorni fa';
    if (giorni < 14) return 'una settimana fa';
    if (giorni < 60) return Math.round(giorni / 7) + ' settimane fa';
    return Math.round(giorni / 30) + ' mesi fa';
  }

  function escapeHtml(testo) {
    return String(testo == null ? '' : testo)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  /* ---------- illustrazioni ---------- */
  /* Le anteprime sono SVG generati: nessuna immagine da scaricare, quindi
     il sito resta leggero e funziona offline. */

  var SAGOME = {
    car: '<path d="M18 68 L30 50 H70 L82 68 Z" /><rect x="34" y="38" width="32" height="14" rx="4" /><circle cx="32" cy="72" r="9" /><circle cx="68" cy="72" r="9" />',
    drone: '<circle cx="50" cy="50" r="10" /><rect x="46" y="20" width="8" height="60" rx="4" transform="rotate(45 50 50)" /><rect x="46" y="20" width="8" height="60" rx="4" transform="rotate(-45 50 50)" /><circle cx="24" cy="24" r="8" /><circle cx="76" cy="24" r="8" /><circle cx="24" cy="76" r="8" /><circle cx="76" cy="76" r="8" />',
    plane: '<path d="M50 18 L58 46 L92 56 L58 58 L54 82 L50 70 L46 82 L42 58 L8 56 L42 46 Z" />',
    heli: '<rect x="14" y="26" width="72" height="5" rx="2.5" /><rect x="47" y="31" width="6" height="10" /><path d="M32 41 H62 L72 55 L62 66 H36 Z" /><rect x="62" y="50" width="28" height="5" rx="2.5" /><circle cx="88" cy="52" r="7" fill="none" stroke-width="4" />',
    boat: '<path d="M16 62 H84 L72 80 H28 Z" /><rect x="47" y="18" width="5" height="42" /><path d="M52 22 L76 56 H52 Z" /><path d="M46 30 L26 56 H46 Z" />',
    radio: '<rect x="26" y="34" width="48" height="44" rx="8" /><circle cx="38" cy="52" r="7" /><circle cx="62" cy="52" r="7" /><rect x="34" y="66" width="32" height="5" rx="2.5" /><rect x="44" y="14" width="4" height="20" /><rect x="58" y="20" width="4" height="14" />',
    battery: '<rect x="22" y="34" width="52" height="36" rx="6" /><rect x="74" y="44" width="8" height="16" rx="3" /><rect x="30" y="42" width="10" height="20" rx="2" opacity="0.55" /><rect x="44" y="42" width="10" height="20" rx="2" opacity="0.55" /><rect x="58" y="42" width="8" height="20" rx="2" opacity="0.55" />',
    gear: '<path d="M50 26 L57 30 L65 27 L69 35 L78 37 L77 46 L83 52 L77 58 L78 67 L69 69 L65 77 L57 74 L50 78 L43 74 L35 77 L31 69 L22 67 L23 58 L17 52 L23 46 L22 37 L31 35 L35 27 L43 30 Z" /><circle cx="50" cy="52" r="11" fill="none" stroke-width="6" />'
  };

  var TINTE = {
    auto: ['#f97316', '#b91c1c'],
    droni: ['#38bdf8', '#1d4ed8'],
    aerei: ['#34d399', '#047857'],
    elicotteri: ['#a78bfa', '#5b21b6'],
    barche: ['#22d3ee', '#0e7490'],
    radio: ['#fbbf24', '#b45309'],
    batterie: ['#4ade80', '#15803d'],
    ricambi: ['#94a3b8', '#334155']
  };

  function anteprima(cat, seme) {
    var info = categoria(cat);
    var tinta = TINTE[cat] || TINTE.ricambi;
    var gid = 'g-' + cat + '-' + (seme || '0');
    var sagoma = SAGOME[info.icona] || SAGOME.gear;
    return '<svg viewBox="0 0 100 100" role="img" aria-label="Illustrazione categoria ' +
      escapeHtml(info.nome) + '" preserveAspectRatio="xMidYMid slice">' +
      '<defs><linearGradient id="' + gid + '" x1="0" y1="0" x2="1" y2="1">' +
      '<stop offset="0" stop-color="' + tinta[0] + '"/><stop offset="1" stop-color="' + tinta[1] + '"/>' +
      '</linearGradient></defs>' +
      '<rect width="100" height="100" fill="url(#' + gid + ')"/>' +
      '<g fill="rgba(255,255,255,0.92)" stroke="rgba(255,255,255,0.92)" stroke-width="0">' +
      sagoma + '</g></svg>';
  }

  /* ---------- tema chiaro/scuro ---------- */

  function applicaTema(tema) {
    if (tema === 'chiaro' || tema === 'scuro') {
      document.documentElement.setAttribute('data-tema', tema);
    } else {
      document.documentElement.removeAttribute('data-tema');
    }
    var bottoni = document.querySelectorAll('[data-cambia-tema]');
    for (var i = 0; i < bottoni.length; i++) {
      bottoni[i].setAttribute('aria-label',
        tema === 'scuro' ? 'Passa al tema chiaro' : 'Passa al tema scuro');
    }
  }

  function iniziaTema() {
    applicaTema(leggi(STORAGE_TEMA, null));
    document.addEventListener('click', function (ev) {
      var bottone = ev.target.closest && ev.target.closest('[data-cambia-tema]');
      if (!bottone) return;
      var attuale = document.documentElement.getAttribute('data-tema');
      if (!attuale) {
        var scuroDiSistema = window.matchMedia &&
          window.matchMedia('(prefers-color-scheme: dark)').matches;
        attuale = scuroDiSistema ? 'scuro' : 'chiaro';
      }
      var nuovo = attuale === 'scuro' ? 'chiaro' : 'scuro';
      scrivi(STORAGE_TEMA, nuovo);
      applicaTema(nuovo);
    });
  }

  /* ---------- card annuncio ---------- */

  function cardAnnuncio(a) {
    var cat = categoria(a.categoria);
    var preferito = isPreferito(a.id);
    return '' +
      '<article class="card" data-id="' + escapeHtml(a.id) + '">' +
        '<a class="card__media" href="annuncio.html?id=' + encodeURIComponent(a.id) + '" ' +
          'aria-label="Apri l\'annuncio ' + escapeHtml(a.titolo) + '">' +
          anteprima(a.categoria, a.id) +
          (a.mio ? '<span class="badge badge--mio">Il tuo annuncio</span>' : '') +
        '</a>' +
        '<button class="cuore' + (preferito ? ' is-attivo' : '') + '" type="button" ' +
          'data-preferito="' + escapeHtml(a.id) + '" aria-pressed="' + (preferito ? 'true' : 'false') + '" ' +
          'title="Salva tra i preferiti">' +
          '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 20s-7-4.35-7-9.5A4.5 4.5 0 0 1 12 7a4.5 4.5 0 0 1 7 3.5C19 15.65 12 20 12 20z"/></svg>' +
          '<span class="sr-only">Preferito</span>' +
        '</button>' +
        '<div class="card__corpo">' +
          '<p class="card__prezzo">' + prezzo(a.prezzo) +
            (a.trattabile ? ' <span class="card__tratt">trattabili</span>' : '') + '</p>' +
          '<h3 class="card__titolo">' +
            '<a href="annuncio.html?id=' + encodeURIComponent(a.id) + '">' + escapeHtml(a.titolo) + '</a>' +
          '</h3>' +
          '<p class="card__meta">' + escapeHtml(cat.nome) + ' · ' + escapeHtml(a.condizione) + '</p>' +
          '<p class="card__luogo">' +
            '<span>' + escapeHtml(a.citta) + '</span>' +
            '<span>' + daQuanto(a.pubblicato) + '</span>' +
          '</p>' +
          (a.spedizione ? '<p class="chip chip--spedizione">Spedizione disponibile</p>' : '') +
        '</div>' +
      '</article>';
  }

  /* ---------- header condiviso ---------- */

  function iniziaHeader() {
    aggiornaContatorePreferiti();
    var apri = document.querySelector('[data-apri-menu]');
    var menu = document.querySelector('[data-menu]');
    if (apri && menu) {
      apri.addEventListener('click', function () {
        var aperto = menu.classList.toggle('is-aperto');
        apri.setAttribute('aria-expanded', aperto ? 'true' : 'false');
      });
    }
  }

  window.RC = {
    categorie: categorie,
    categoria: categoria,
    tuttiGliAnnunci: tuttiGliAnnunci,
    annuncio: annuncio,
    salvaAnnuncio: salvaAnnuncio,
    annunciUtente: annunciUtente,
    preferiti: preferiti,
    isPreferito: isPreferito,
    togglePreferito: togglePreferito,
    aggiornaContatorePreferiti: aggiornaContatorePreferiti,
    prezzo: prezzo,
    dataBreve: dataBreve,
    daQuanto: daQuanto,
    escapeHtml: escapeHtml,
    anteprima: anteprima,
    cardAnnuncio: cardAnnuncio,
    iniziaTema: iniziaTema,
    iniziaHeader: iniziaHeader
  };

  iniziaTema();
  document.addEventListener('DOMContentLoaded', iniziaHeader);
}());
