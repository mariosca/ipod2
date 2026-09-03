/* Form di pubblicazione: validazione lato client e salvataggio nel browser. */
(function () {
  'use strict';

  var REGIONI = ['Abruzzo', 'Basilicata', 'Calabria', 'Campania', 'Emilia-Romagna',
    'Friuli-Venezia Giulia', 'Lazio', 'Liguria', 'Lombardia', 'Marche', 'Molise',
    'Piemonte', 'Puglia', 'Sardegna', 'Sicilia', 'Toscana', 'Trentino-Alto Adige',
    'Umbria', "Valle d'Aosta", 'Veneto'];

  function q(sel) { return document.querySelector(sel); }

  function mostraErrore(campo, testo) {
    var nodo = document.querySelector('[data-errore="' + campo + '"]');
    if (!nodo) return;
    nodo.textContent = testo || '';
    nodo.hidden = !testo;
  }

  function pulisciErrori() {
    var nodi = document.querySelectorAll('[data-errore]');
    for (var i = 0; i < nodi.length; i++) { nodi[i].hidden = true; nodi[i].textContent = ''; }
  }

  function idDaTitolo(titolo) {
    var t = titolo.toLowerCase();
    if (t.normalize) { t = t.normalize('NFD').replace(/[\u0300-\u036f]/g, ''); }
    t = t.replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'annuncio';
    return 'mio-' + t + '-' + Date.now().toString(36);
  }

  function oggi() {
    var d = new Date();
    function due(n) { return (n < 10 ? '0' : '') + n; }
    return d.getFullYear() + '-' + due(d.getMonth() + 1) + '-' + due(d.getDate());
  }

  function riempiSelect() {
    q('[data-select-categoria]').innerHTML = window.RC.categorie().map(function (c) {
      return '<option value="' + c.id + '">' + window.RC.escapeHtml(c.nome) + '</option>';
    }).join('');

    q('[data-select-regione]').innerHTML = REGIONI.map(function (r) {
      return '<option value="' + window.RC.escapeHtml(r) + '">' + window.RC.escapeHtml(r) + '</option>';
    }).join('');
  }

  function disegnaMiei() {
    var miei = window.RC.annunciUtente();
    var box = q('[data-miei-annunci]');
    if (!miei.length) {
      box.innerHTML = '<div class="vuoto">Non hai ancora pubblicato annunci in questo browser.</div>';
      return;
    }
    box.innerHTML = miei.map(window.RC.cardAnnuncio).join('');
  }

  function valida(dati) {
    var errori = 0;
    pulisciErrori();

    if (dati.titolo.length < 8) { mostraErrore('titolo', 'Scrivi almeno 8 caratteri.'); errori++; }
    if (!dati.categoria) { mostraErrore('categoria', 'Scegli una categoria.'); errori++; }
    if (dati.prezzo === '' || isNaN(Number(dati.prezzo)) || Number(dati.prezzo) < 0) {
      mostraErrore('prezzo', 'Inserisci un prezzo valido (0 per regalo).'); errori++;
    }
    if (dati.citta.length < 2) { mostraErrore('citta', 'Indica la città.'); errori++; }
    if (dati.nome.length < 2) { mostraErrore('nome', 'Indica come vuoi essere contattato.'); errori++; }
    if (dati.descrizione.length < 30) {
      mostraErrore('descrizione', 'Servono almeno 30 caratteri: aggiungi qualche dettaglio.'); errori++;
    }
    return errori === 0;
  }

  document.addEventListener('DOMContentLoaded', function () {
    riempiSelect();
    disegnaMiei();

    var form = q('[data-form-vendi]');
    var esito = q('[data-esito]');

    form.addEventListener('submit', function (ev) {
      ev.preventDefault();
      var f = new FormData(form);

      var dati = {
        titolo: String(f.get('titolo') || '').trim(),
        categoria: String(f.get('categoria') || ''),
        condizione: String(f.get('condizione') || 'Buono'),
        prezzo: String(f.get('prezzo') || '').trim(),
        citta: String(f.get('citta') || '').trim(),
        regione: String(f.get('regione') || ''),
        nome: String(f.get('nome') || '').trim(),
        descrizione: String(f.get('descrizione') || '').trim(),
        dotazione: String(f.get('dotazione') || '').trim()
      };

      if (!valida(dati)) {
        esito.hidden = true;
        var primo = document.querySelector('[data-errore]:not([hidden])');
        if (primo) primo.scrollIntoView({ block: 'center' });
        return;
      }

      var annuncio = {
        id: idDaTitolo(dati.titolo),
        mio: true,
        titolo: dati.titolo,
        categoria: dati.categoria,
        prezzo: Number(dati.prezzo),
        condizione: dati.condizione,
        citta: dati.citta,
        regione: dati.regione,
        spedizione: f.get('spedizione') === 'on',
        trattabile: f.get('trattabile') === 'on',
        pubblicato: oggi(),
        venditore: { nome: dati.nome, annunci: window.RC.annunciUtente().length + 1 },
        descrizione: dati.descrizione,
        dotazione: dati.dotazione ? dati.dotazione.split('\n').map(function (r) { return r.trim(); })
          .filter(Boolean) : [],
        specifiche: {}
      };

      var salvato = window.RC.salvaAnnuncio(annuncio);
      esito.hidden = false;

      if (salvato) {
        esito.innerHTML = 'Annuncio pubblicato. ' +
          '<a href="annuncio.html?id=' + encodeURIComponent(annuncio.id) + '">Guardalo ora</a> ' +
          'oppure <a href="index.html">torna all\'elenco</a>.';
        form.reset();
        riempiSelect();
        disegnaMiei();
      } else {
        esito.innerHTML = 'Non è stato possibile salvare l\'annuncio: il browser blocca la memoria locale ' +
          '(finestra privata o cookie disattivati).';
      }
      esito.scrollIntoView({ block: 'center' });
    });

    /* Cuore preferiti sulle card dei propri annunci */
    q('[data-miei-annunci]').addEventListener('click', function (ev) {
      var b = ev.target.closest('[data-preferito]');
      if (!b) return;
      var attivo = window.RC.togglePreferito(b.getAttribute('data-preferito'));
      b.classList.toggle('is-attivo', attivo);
      b.setAttribute('aria-pressed', attivo ? 'true' : 'false');
    });
  });
}());
