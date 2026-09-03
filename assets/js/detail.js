/* Pagina di dettaglio: legge ?id= e mostra l'annuncio corrispondente. */
(function () {
  'use strict';

  function iniziali(nome) {
    return String(nome || '?').split(/\s+/).map(function (p) { return p.charAt(0); })
      .join('').slice(0, 2).toUpperCase();
  }

  function disegnaNonTrovato(contenitore) {
    contenitore.innerHTML = '<div class="vuoto" style="margin:30px 0 60px">' +
      '<h1>Annuncio non disponibile</h1>' +
      '<p>Il link potrebbe essere scaduto oppure l\'annuncio è stato rimosso.</p>' +
      '<a class="bottone" href="index.html">Vedi tutti gli annunci</a></div>';
  }

  function disegna(a) {
    var RC = window.RC;
    var cat = RC.categoria(a.categoria);
    var preferito = RC.isPreferito(a.id);

    document.title = a.titolo + ' — Claude RC';

    var briciole = document.querySelector('[data-briciole]');
    briciole.innerHTML = '<a href="index.html">Annunci</a> › ' +
      '<a href="index.html?categoria=' + encodeURIComponent(cat.id) + '">' +
      RC.escapeHtml(cat.nome) + '</a> › ' + RC.escapeHtml(a.titolo);

    var specifiche = Object.keys(a.specifiche || {}).map(function (k) {
      return '<li><span>' + RC.escapeHtml(k) + '</span><span>' +
        RC.escapeHtml(a.specifiche[k]) + '</span></li>';
    }).join('');

    var dotazione = (a.dotazione || []).map(function (d) {
      return '<li>' + RC.escapeHtml(d) + '</li>';
    }).join('');

    document.querySelector('[data-annuncio]').innerHTML = '' +
      '<div class="annuncio">' +
        '<div>' +
          '<div class="annuncio__media">' + RC.anteprima(a.categoria, a.id) + '</div>' +
          '<div class="pannello" style="margin-top:18px">' +
            '<h2>Descrizione</h2>' +
            '<p>' + RC.escapeHtml(a.descrizione).replace(/\n/g, '<br>') + '</p>' +
          '</div>' +
          (dotazione ? '<div class="pannello"><h2>Cosa è incluso</h2>' +
            '<ul class="lista-dotazione">' + dotazione + '</ul></div>' : '') +
          (specifiche ? '<div class="pannello"><h2>Caratteristiche</h2>' +
            '<ul class="dati">' + specifiche + '</ul></div>' : '') +
        '</div>' +

        '<div>' +
          '<div class="pannello">' +
            '<p class="annuncio__prezzo">' + RC.prezzo(a.prezzo) + '</p>' +
            '<p class="card__tratt" style="margin:0 0 8px">' +
              (a.trattabile ? 'Prezzo trattabile' : 'Prezzo non trattabile') + '</p>' +
            '<h1 class="annuncio__titolo">' + RC.escapeHtml(a.titolo) + '</h1>' +
            '<ul class="dati">' +
              '<li><span>Categoria</span><span>' + RC.escapeHtml(cat.nome) + '</span></li>' +
              '<li><span>Condizione</span><span>' + RC.escapeHtml(a.condizione) + '</span></li>' +
              '<li><span>Zona</span><span>' + RC.escapeHtml(a.citta) + ' (' + RC.escapeHtml(a.regione) + ')</span></li>' +
              '<li><span>Spedizione</span><span>' + (a.spedizione ? 'Disponibile' : 'Solo ritiro a mano') + '</span></li>' +
              '<li><span>Pubblicato</span><span>' + RC.dataBreve(a.pubblicato) + '</span></li>' +
            '</ul>' +
            '<div class="azioni" style="margin-top:16px">' +
              '<button class="bottone" type="button" data-contatta>Contatta il venditore</button>' +
              '<button class="bottone bottone--fantasma' + (preferito ? ' is-salvato' : '') + '" type="button" data-preferito-dettaglio>' +
                (preferito ? 'Salvato ♥' : 'Salva ♡') + '</button>' +
            '</div>' +
            '<p class="avviso" data-messaggio hidden></p>' +
          '</div>' +

          '<div class="pannello">' +
            '<h2>Venditore</h2>' +
            '<div class="venditore">' +
              '<span class="venditore__avatar" aria-hidden="true">' + iniziali(a.venditore && a.venditore.nome) + '</span>' +
              '<span>' +
                '<span class="venditore__nome">' + RC.escapeHtml((a.venditore && a.venditore.nome) || 'Privato') + '</span><br>' +
                '<span class="venditore__info">' +
                  ((a.venditore && a.venditore.valutazione) ? '★ ' + a.venditore.valutazione + ' · ' : '') +
                  ((a.venditore && a.venditore.annunci) || 1) + ' annunci pubblicati</span>' +
              '</span>' +
            '</div>' +
            '<p class="avviso">Chiedi sempre foto aggiuntive e, per l\'elettronica, una prova di funzionamento ' +
              'prima di concludere l\'acquisto.</p>' +
          '</div>' +
        '</div>' +
      '</div>';

    collegaAzioni(a);
    disegnaSimili(a);
  }

  function collegaAzioni(a) {
    var messaggio = document.querySelector('[data-messaggio]');

    document.querySelector('[data-contatta]').addEventListener('click', function () {
      messaggio.hidden = false;
      messaggio.textContent = 'Demo: in un sito reale qui si apre la chat con ' +
        ((a.venditore && a.venditore.nome) || 'il venditore') + '. Nessun messaggio è stato inviato.';
    });

    var salva = document.querySelector('[data-preferito-dettaglio]');
    salva.addEventListener('click', function () {
      var attivo = window.RC.togglePreferito(a.id);
      salva.textContent = attivo ? 'Salvato ♥' : 'Salva ♡';
    });
  }

  function disegnaSimili(a) {
    var RC = window.RC;
    var simili = RC.tuttiGliAnnunci().filter(function (x) {
      return x.id !== a.id && x.categoria === a.categoria;
    }).slice(0, 4);

    if (!simili.length) {
      simili = RC.tuttiGliAnnunci().filter(function (x) { return x.id !== a.id; }).slice(0, 4);
    }

    var sezione = document.querySelector('[data-simili]');
    sezione.innerHTML = '<h2 style="margin-bottom:14px">Annunci simili</h2>' +
      '<div class="griglia" data-griglia-simili style="padding-bottom:50px">' +
      simili.map(RC.cardAnnuncio).join('') + '</div>';

    sezione.addEventListener('click', function (ev) {
      var b = ev.target.closest('[data-preferito]');
      if (!b) return;
      var attivo = RC.togglePreferito(b.getAttribute('data-preferito'));
      b.classList.toggle('is-attivo', attivo);
      b.setAttribute('aria-pressed', attivo ? 'true' : 'false');
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    var id = new URLSearchParams(location.search).get('id');
    var a = id ? window.RC.annuncio(id) : null;
    if (!a) { disegnaNonTrovato(document.querySelector('[data-annuncio]')); return; }
    disegna(a);
  });
}());
