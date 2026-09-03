/* Pagina elenco annunci: ricerca, filtri, ordinamento, preferiti.
   Lo stato dei filtri e' riflesso nella query string, cosi' una ricerca
   e' condivisibile con un link. */
(function () {
  'use strict';

  var CONDIZIONI = ['Ottimo', 'Buono', 'Da riparare'];

  var stato = {
    testo: '',
    categoria: '',
    prezzoMin: null,
    prezzoMax: null,
    condizioni: [],
    regione: '',
    spedizione: false,
    trattabili: false,
    preferiti: false,
    ordina: 'recenti'
  };

  var el = {};

  function q(sel) { return document.querySelector(sel); }

  function leggiUrl() {
    var p = new URLSearchParams(location.search);
    if (p.get('q')) stato.testo = p.get('q');
    if (p.get('categoria')) stato.categoria = p.get('categoria');
    if (p.get('min')) stato.prezzoMin = Number(p.get('min'));
    if (p.get('max')) stato.prezzoMax = Number(p.get('max'));
    if (p.get('condizione')) stato.condizioni = p.get('condizione').split(',');
    if (p.get('regione')) stato.regione = p.get('regione');
    if (p.get('spedizione') === '1') stato.spedizione = true;
    if (p.get('trattabili') === '1') stato.trattabili = true;
    if (p.get('preferiti') === '1') stato.preferiti = true;
    if (p.get('ordina')) stato.ordina = p.get('ordina');
  }

  function scriviUrl() {
    var p = new URLSearchParams();
    if (stato.testo) p.set('q', stato.testo);
    if (stato.categoria) p.set('categoria', stato.categoria);
    if (stato.prezzoMin != null && !isNaN(stato.prezzoMin)) p.set('min', stato.prezzoMin);
    if (stato.prezzoMax != null && !isNaN(stato.prezzoMax)) p.set('max', stato.prezzoMax);
    if (stato.condizioni.length) p.set('condizione', stato.condizioni.join(','));
    if (stato.regione) p.set('regione', stato.regione);
    if (stato.spedizione) p.set('spedizione', '1');
    if (stato.trattabili) p.set('trattabili', '1');
    if (stato.preferiti) p.set('preferiti', '1');
    if (stato.ordina !== 'recenti') p.set('ordina', stato.ordina);
    var query = p.toString();
    history.replaceState(null, '', query ? '?' + query : location.pathname);
  }

  /* ---------- filtro e ordinamento ---------- */

  function normalizza(testo) {
    var t = String(testo == null ? '' : testo).toLowerCase();
    return t.normalize ? t.normalize('NFD').replace(/[\u0300-\u036f]/g, '') : t;
  }

  function corrisponde(a) {
    if (stato.categoria && a.categoria !== stato.categoria) return false;
    if (stato.prezzoMin != null && !isNaN(stato.prezzoMin) && a.prezzo < stato.prezzoMin) return false;
    if (stato.prezzoMax != null && !isNaN(stato.prezzoMax) && a.prezzo > stato.prezzoMax) return false;
    if (stato.condizioni.length && stato.condizioni.indexOf(a.condizione) === -1) return false;
    if (stato.regione && a.regione !== stato.regione) return false;
    if (stato.spedizione && !a.spedizione) return false;
    if (stato.trattabili && !a.trattabile) return false;
    if (stato.preferiti && !window.RC.isPreferito(a.id)) return false;

    if (stato.testo) {
      var parole = normalizza(stato.testo).split(/\s+/).filter(Boolean);
      var pagliaio = normalizza([
        a.titolo, a.descrizione, a.citta, a.regione, a.condizione,
        window.RC.categoria(a.categoria).nome,
        (a.dotazione || []).join(' '),
        Object.keys(a.specifiche || {}).map(function (k) { return k + ' ' + a.specifiche[k]; }).join(' ')
      ].join(' '));
      for (var i = 0; i < parole.length; i++) {
        if (pagliaio.indexOf(parole[i]) === -1) return false;
      }
    }
    return true;
  }

  function ordinaElenco(elenco) {
    var copia = elenco.slice();
    if (stato.ordina === 'prezzo-asc') {
      copia.sort(function (a, b) { return a.prezzo - b.prezzo; });
    } else if (stato.ordina === 'prezzo-desc') {
      copia.sort(function (a, b) { return b.prezzo - a.prezzo; });
    } else if (stato.ordina === 'titolo') {
      copia.sort(function (a, b) { return a.titolo.localeCompare(b.titolo, 'it'); });
    } else {
      copia.sort(function (a, b) { return String(b.pubblicato).localeCompare(String(a.pubblicato)); });
    }
    return copia;
  }

  function risultati() {
    return ordinaElenco(window.RC.tuttiGliAnnunci().filter(corrisponde));
  }

  /* ---------- disegno ---------- */

  function disegnaCategorie() {
    var tutti = window.RC.tuttiGliAnnunci();
    var html = '<button class="categoria-pill' + (stato.categoria ? '' : ' is-attiva') +
      '" type="button" data-cat="">Tutte <span class="n">' + tutti.length + '</span></button>';

    window.RC.categorie().forEach(function (c) {
      var n = tutti.filter(function (a) { return a.categoria === c.id; }).length;
      if (!n) return;
      html += '<button class="categoria-pill' + (stato.categoria === c.id ? ' is-attiva' : '') +
        '" type="button" data-cat="' + c.id + '">' + window.RC.escapeHtml(c.nome) +
        ' <span class="n">' + n + '</span></button>';
    });
    el.categorie.innerHTML = html;
  }

  function disegnaFiltri() {
    el.condizioni.innerHTML = CONDIZIONI.map(function (c) {
      var attiva = stato.condizioni.indexOf(c) !== -1;
      return '<label class="opzione"><input type="checkbox" value="' + c + '" data-condizione' +
        (attiva ? ' checked' : '') + '> ' + c + '</label>';
    }).join('');

    var regioni = window.RC.tuttiGliAnnunci().map(function (a) { return a.regione; })
      .filter(function (r, i, arr) { return r && arr.indexOf(r) === i; })
      .sort(function (a, b) { return a.localeCompare(b, 'it'); });

    el.regione.innerHTML = '<option value="">Tutta Italia</option>' + regioni.map(function (r) {
      return '<option value="' + window.RC.escapeHtml(r) + '"' +
        (stato.regione === r ? ' selected' : '') + '>' + window.RC.escapeHtml(r) + '</option>';
    }).join('');

    el.cerca.value = stato.testo;
    el.prezzoMin.value = stato.prezzoMin != null && !isNaN(stato.prezzoMin) ? stato.prezzoMin : '';
    el.prezzoMax.value = stato.prezzoMax != null && !isNaN(stato.prezzoMax) ? stato.prezzoMax : '';
    el.soloSpedizione.checked = stato.spedizione;
    el.soloTrattabili.checked = stato.trattabili;
    el.soloPreferiti.checked = stato.preferiti;
    el.ordina.value = stato.ordina;
  }

  function disegnaStatistiche() {
    var tutti = window.RC.tuttiGliAnnunci();
    var conSped = tutti.filter(function (a) { return a.spedizione; }).length;
    var media = tutti.length
      ? Math.round(tutti.reduce(function (s, a) { return s + a.prezzo; }, 0) / tutti.length)
      : 0;
    q('[data-stat-annunci]').textContent = tutti.length;
    q('[data-stat-categorie]').textContent = window.RC.categorie().filter(function (c) {
      return tutti.some(function (a) { return a.categoria === c.id; });
    }).length;
    q('[data-stat-spedizione]').textContent = conSped;
    q('[data-stat-prezzo]').textContent = window.RC.prezzo(media);
  }

  function disegnaElenco() {
    var elenco = risultati();
    el.conta.textContent = elenco.length;
    q('[data-conta-testo]').textContent = elenco.length === 1 ? 'annuncio' : 'annunci';

    if (!elenco.length) {
      el.griglia.innerHTML = '<div class="vuoto">' +
        '<h3>Nessun annuncio trovato</h3>' +
        '<p>Prova ad allargare la ricerca: meno parole chiave, un intervallo di prezzo più ampio ' +
        'oppure tutte le regioni.</p>' +
        '<button class="bottone bottone--fantasma" type="button" data-azzera>Azzera i filtri</button>' +
        '</div>';
      return;
    }
    el.griglia.innerHTML = elenco.map(window.RC.cardAnnuncio).join('');
  }

  function disegnaFooterCategorie() {
    var lista = q('[data-footer-categorie]');
    if (!lista) return;
    lista.innerHTML = window.RC.categorie().map(function (c) {
      return '<li><a href="index.html?categoria=' + encodeURIComponent(c.id) + '">' +
        window.RC.escapeHtml(c.nome) + '</a></li>';
    }).join('');
  }

  function aggiorna() {
    scriviUrl();
    disegnaCategorie();
    disegnaElenco();
  }

  /* ---------- eventi ---------- */

  function collega() {
    q('[data-form-cerca]').addEventListener('submit', function (ev) {
      ev.preventDefault();
      stato.testo = el.cerca.value.trim();
      aggiorna();
    });

    var timer;
    el.cerca.addEventListener('input', function () {
      clearTimeout(timer);
      timer = setTimeout(function () {
        stato.testo = el.cerca.value.trim();
        aggiorna();
      }, 200);
    });

    el.categorie.addEventListener('click', function (ev) {
      var b = ev.target.closest('[data-cat]');
      if (!b) return;
      stato.categoria = b.getAttribute('data-cat');
      aggiorna();
    });

    el.condizioni.addEventListener('change', function () {
      var scelte = el.condizioni.querySelectorAll('[data-condizione]:checked');
      stato.condizioni = Array.prototype.map.call(scelte, function (i) { return i.value; });
      aggiorna();
    });

    [el.prezzoMin, el.prezzoMax].forEach(function (campo) {
      campo.addEventListener('change', function () {
        stato.prezzoMin = el.prezzoMin.value === '' ? null : Number(el.prezzoMin.value);
        stato.prezzoMax = el.prezzoMax.value === '' ? null : Number(el.prezzoMax.value);
        aggiorna();
      });
    });

    el.regione.addEventListener('change', function () {
      stato.regione = el.regione.value;
      aggiorna();
    });

    el.soloSpedizione.addEventListener('change', function () {
      stato.spedizione = el.soloSpedizione.checked; aggiorna();
    });
    el.soloTrattabili.addEventListener('change', function () {
      stato.trattabili = el.soloTrattabili.checked; aggiorna();
    });
    el.soloPreferiti.addEventListener('change', function () {
      stato.preferiti = el.soloPreferiti.checked; aggiorna();
    });

    el.ordina.addEventListener('change', function () {
      stato.ordina = el.ordina.value; aggiorna();
    });

    /* Azzera: presente nei filtri e nello stato vuoto */
    document.addEventListener('click', function (ev) {
      if (!ev.target.closest('[data-azzera]')) return;
      stato.testo = '';
      stato.categoria = '';
      stato.prezzoMin = null;
      stato.prezzoMax = null;
      stato.condizioni = [];
      stato.regione = '';
      stato.spedizione = false;
      stato.trattabili = false;
      stato.preferiti = false;
      disegnaFiltri();
      aggiorna();
    });

    /* Cuore preferiti sulle card */
    el.griglia.addEventListener('click', function (ev) {
      var b = ev.target.closest('[data-preferito]');
      if (!b) return;
      var attivo = window.RC.togglePreferito(b.getAttribute('data-preferito'));
      b.classList.toggle('is-attivo', attivo);
      b.setAttribute('aria-pressed', attivo ? 'true' : 'false');
      if (stato.preferiti) disegnaElenco();
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    el = {
      categorie: q('[data-categorie]'),
      condizioni: q('[data-condizioni]'),
      regione: q('[data-regione]'),
      cerca: q('[data-cerca]'),
      prezzoMin: q('[data-prezzo-min]'),
      prezzoMax: q('[data-prezzo-max]'),
      soloSpedizione: q('[data-solo-spedizione]'),
      soloTrattabili: q('[data-solo-trattabili]'),
      soloPreferiti: q('[data-solo-preferiti]'),
      ordina: q('[data-ordina]'),
      griglia: q('[data-griglia]'),
      conta: q('[data-conta]')
    };

    leggiUrl();
    disegnaStatistiche();
    disegnaFiltri();
    disegnaFooterCategorie();
    aggiorna();
    collega();
  });
}());
