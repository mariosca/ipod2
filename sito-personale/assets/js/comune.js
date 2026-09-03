/* Utilità condivise dalle pagine del sito: tema, menu, testate, copertine. */
(function () {
  'use strict';

  var CHIAVE_TEMA = 'sito-personale:tema';

  function leggiTema() {
    try { return localStorage.getItem(CHIAVE_TEMA); } catch (e) { return null; }
  }

  function scriviTema(valore) {
    try { localStorage.setItem(CHIAVE_TEMA, valore); } catch (e) { /* memoria bloccata */ }
  }

  function applicaTema(tema) {
    if (tema === 'chiaro' || tema === 'scuro') {
      document.documentElement.setAttribute('data-tema', tema);
    } else {
      document.documentElement.removeAttribute('data-tema');
    }
  }

  function iniziaTema() {
    applicaTema(leggiTema());
    document.addEventListener('click', function (ev) {
      var b = ev.target.closest && ev.target.closest('[data-tema]');
      if (!b) return;
      var attuale = document.documentElement.getAttribute('data-tema');
      if (!attuale) {
        attuale = (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches)
          ? 'scuro' : 'chiaro';
      }
      var nuovo = attuale === 'scuro' ? 'chiaro' : 'scuro';
      scriviTema(nuovo);
      applicaTema(nuovo);
    });
  }

  function escapeHtml(testo) {
    return String(testo == null ? '' : testo)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  function numeroDa(testo) {
    var n = 0;
    for (var i = 0; i < String(testo).length; i++) {
      n = (n * 31 + String(testo).charCodeAt(i)) % 100000;
    }
    return n;
  }

  /* Copertina generata: nessuna immagine da caricare, ogni progetto ha la sua
     composizione, sempre la stessa perché derivata dall'id. */
  function copertina(progetto) {
    var tinta = progetto.tinta || ['#333333', '#111111'];
    var seme = numeroDa(progetto.id);
    var gid = 'cop-' + progetto.id;
    var forme = '';
    var righe = 7;

    for (var i = 0; i < righe; i++) {
      var y = 12 + i * 11;
      var larghezza = 18 + ((seme >> i) % 9) * 8;
      var x = 8 + ((seme >> (i + 3)) % 7) * 6;
      var opacita = (0.16 + (i % 4) * 0.13).toFixed(2);
      forme += '<rect x="' + x + '" y="' + y + '" width="' + larghezza + '" height="5" rx="2.5" ' +
        'fill="#ffffff" opacity="' + opacita + '"/>';
    }

    var raggio = 16 + (seme % 9);
    forme += '<circle cx="' + (74 + (seme % 11)) + '" cy="' + (32 + (seme % 17)) + '" r="' + raggio +
      '" fill="none" stroke="#ffffff" stroke-width="1.2" opacity="0.5"/>';
    forme += '<circle cx="' + (74 + (seme % 11)) + '" cy="' + (32 + (seme % 17)) + '" r="' +
      (raggio / 2.4).toFixed(1) + '" fill="#ffffff" opacity="0.22"/>';

    return '<svg viewBox="0 0 130 100" preserveAspectRatio="xMidYMid slice" role="img" ' +
      'aria-label="Illustrazione astratta del progetto ' + escapeHtml(progetto.titolo) + '">' +
      '<defs><linearGradient id="' + gid + '" x1="0" y1="0" x2="1" y2="1">' +
      '<stop offset="0" stop-color="' + tinta[0] + '"/>' +
      '<stop offset="1" stop-color="' + tinta[1] + '"/></linearGradient></defs>' +
      '<rect width="130" height="100" fill="url(#' + gid + ')"/>' + forme + '</svg>';
  }

  var MESI = ['gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio',
    'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'];

  function dataEstesa(iso) {
    var p = String(iso).split('-');
    if (p.length !== 3) return iso;
    return Number(p[2]) + ' ' + MESI[Number(p[1]) - 1] + ' ' + p[0];
  }

  /* Compare gli elementi .comparsa quando entrano nello schermo. */
  function iniziaComparse() {
    var elementi = document.querySelectorAll('.comparsa');
    if (!('IntersectionObserver' in window) ||
        (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches)) {
      for (var i = 0; i < elementi.length; i++) elementi[i].classList.add('is-visibile');
      return;
    }
    var osservatore = new IntersectionObserver(function (voci) {
      voci.forEach(function (voce) {
        if (voce.isIntersecting) {
          voce.target.classList.add('is-visibile');
          osservatore.unobserve(voce.target);
        }
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });

    for (var j = 0; j < elementi.length; j++) osservatore.observe(elementi[j]);
  }

  function iniziaTesta() {
    var testa = document.querySelector('[data-testa]');
    if (testa) {
      var aggiorna = function () {
        testa.classList.toggle('is-staccata', window.scrollY > 8);
      };
      aggiorna();
      window.addEventListener('scroll', aggiorna, { passive: true });
    }

    var apri = document.querySelector('[data-apri-menu]');
    var menu = document.querySelector('[data-menu]');
    if (apri && menu) {
      apri.addEventListener('click', function () {
        var aperto = menu.classList.toggle('is-aperto');
        apri.setAttribute('aria-expanded', aperto ? 'true' : 'false');
      });
      menu.addEventListener('click', function (ev) {
        if (ev.target.tagName === 'A') {
          menu.classList.remove('is-aperto');
          apri.setAttribute('aria-expanded', 'false');
        }
      });
    }

    var firma = document.querySelector('[data-firma]');
    if (firma && window.PROFILO) {
      firma.innerHTML = escapeHtml(window.PROFILO.nome) +
        ' <span>' + escapeHtml(window.PROFILO.ruolo) + '</span>';
    }

    var anno = document.querySelector('[data-anno]');
    if (anno) anno.textContent = new Date().getFullYear();

    var piedeNome = document.querySelector('[data-piede-nome]');
    if (piedeNome && window.PROFILO) piedeNome.textContent = window.PROFILO.nome;
  }

  window.SITO = {
    escapeHtml: escapeHtml,
    copertina: copertina,
    dataEstesa: dataEstesa,
    iniziaComparse: iniziaComparse,
    iniziaTesta: iniziaTesta
  };

  iniziaTema();
  document.addEventListener('DOMContentLoaded', function () {
    iniziaTesta();
    iniziaComparse();
  });
}());
