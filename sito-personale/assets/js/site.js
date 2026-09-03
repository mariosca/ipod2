/* Home: riempie le sezioni dai dati di dati.js e gestisce
   evidenziazione del menu, copia dell'indirizzo email e scritti. */
(function () {
  'use strict';

  function q(sel) { return document.querySelector(sel); }

  function riempiApertura() {
    var p = window.PROFILO;
    var esc = window.SITO.escapeHtml;

    document.title = p.nome + ' — ' + p.ruolo.toLowerCase();
    q('[data-disponibilita]').textContent = p.disponibilita;
    q('[data-dichiarazione]').textContent = p.dichiarazione;
    q('[data-intro]').textContent = p.intro;

    var mail = q('[data-mail]');
    mail.textContent = p.email;
    mail.setAttribute('href', 'mailto:' + p.email);

    q('[data-contatti]').innerHTML = p.contatti.map(function (c) {
      return '<a href="' + esc(c.href) + '"' +
        (c.href.charAt(0) === '#' ? ' aria-disabled="true"' : '') + '>' +
        '<span class="k">' + esc(c.etichetta) + '</span>' +
        '<span class="v">' + esc(c.valore) + '</span></a>';
    }).join('');
  }

  function riempiProgetti() {
    var esc = window.SITO.escapeHtml;
    var progetti = window.PROGETTI || [];

    q('[data-nota-lavori]').textContent = progetti.length + ' progetti, dal ' +
      progetti[progetti.length - 1].anno + ' a oggi';

    q('[data-progetti]').innerHTML = progetti.map(function (pr) {
      return '<a class="progetto comparsa" href="progetto.html?id=' + encodeURIComponent(pr.id) + '">' +
        '<span class="progetto__anno">' + esc(pr.anno) + '</span>' +
        '<span>' +
          '<span class="progetto__titolo" style="display:block">' + esc(pr.titolo) + '</span>' +
          '<span class="progetto__sommario" style="display:block">' + esc(pr.sommario) + '</span>' +
          '<span class="progetto__tag">' +
            pr.tag.map(function (t) { return '<span class="tag">' + esc(t) + '</span>'; }).join('') +
          '</span>' +
        '</span>' +
        '<span class="progetto__freccia" aria-hidden="true">' +
          '<svg viewBox="0 0 24 24"><path d="M5 12h12.2l-4.6-4.6L14 6l7 7-7 7-1.4-1.4 4.6-4.6H5z"/></svg>' +
        '</span>' +
      '</a>';
    }).join('');
  }

  function riempiChiSono() {
    var p = window.PROFILO;
    var esc = window.SITO.escapeHtml;

    q('[data-competenze]').innerHTML = p.competenze.map(function (c) {
      return '<li>' + esc(c) + '</li>';
    }).join('');

    q('[data-clienti]').innerHTML = p.clienti.map(function (c) {
      return '<span class="tag">' + esc(c) + '</span>';
    }).join('');

    q('[data-percorso]').innerHTML = p.percorso.map(function (r) {
      return '<li><span class="anni">' + esc(r.anni) + '</span>' +
        '<span><span class="cosa">' + esc(r.cosa) + '</span><br>' +
        '<span class="dove">' + esc(r.dove) + '</span></span></li>';
    }).join('');
  }

  function riempiScritti() {
    var esc = window.SITO.escapeHtml;
    q('[data-scritti]').innerHTML = (window.SCRITTI || []).map(function (s) {
      return '<details class="scritto comparsa">' +
        '<summary>' +
          '<span class="scritto__data">' + window.SITO.dataEstesa(s.data) + '</span>' +
          '<span class="scritto__titolo">' + esc(s.titolo) + '</span>' +
          '<span class="scritto__lettura">' + esc(s.lettura) + '</span>' +
        '</summary>' +
        '<div class="scritto__testo"><p>' + esc(s.testo) + '</p></div>' +
      '</details>';
    }).join('');
  }

  function selezionaMail() {
    var nodo = q('[data-mail]');
    if (!nodo || !window.getSelection || !document.createRange) return;
    var intervallo = document.createRange();
    intervallo.selectNodeContents(nodo);
    var selezione = window.getSelection();
    selezione.removeAllRanges();
    selezione.addRange(intervallo);
  }

  function copiaEmail() {
    var bottone = q('[data-copia]');
    var originale = bottone.textContent;

    bottone.addEventListener('click', function () {
      var email = window.PROFILO.email;
      var fatto = function (ok) {
        if (ok) {
          bottone.textContent = 'Copiato ✓';
        } else {
          /* Se il browser blocca la copia, almeno selezioniamo l'indirizzo. */
          bottone.textContent = 'Selezionato: copialo a mano';
          selezionaMail();
        }
        setTimeout(function () { bottone.textContent = originale; }, 2600);
      };

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(email).then(function () { fatto(true); },
          function () { fatto(false); });
        return;
      }
      /* Ripiego per i browser senza clipboard API o su file:// */
      var campo = document.createElement('textarea');
      campo.value = email;
      campo.setAttribute('readonly', '');
      campo.style.position = 'fixed';
      campo.style.opacity = '0';
      document.body.appendChild(campo);
      campo.select();
      var ok = false;
      try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
      document.body.removeChild(campo);
      fatto(ok);
    });
  }

  /* Evidenzia nel menu la sezione che si sta leggendo. */
  function menuAttivo() {
    var voci = Array.prototype.slice.call(document.querySelectorAll('.menu a[href^="#"]'));
    var sezioni = voci.map(function (v) { return document.querySelector(v.getAttribute('href')); })
      .filter(Boolean);
    if (!('IntersectionObserver' in window) || !sezioni.length) return;

    var osservatore = new IntersectionObserver(function (voci2) {
      voci2.forEach(function (voce) {
        if (!voce.isIntersecting) return;
        voci.forEach(function (v) {
          v.classList.toggle('is-attivo', v.getAttribute('href') === '#' + voce.target.id);
        });
      });
    }, { rootMargin: '-45% 0px -50% 0px' });

    sezioni.forEach(function (s) { osservatore.observe(s); });
  }

  document.addEventListener('DOMContentLoaded', function () {
    riempiApertura();
    riempiProgetti();
    riempiChiSono();
    riempiScritti();
    copiaEmail();
    menuAttivo();
    /* Le card dei progetti nascono dopo il primo giro: ripeti l'osservazione. */
    window.SITO.iniziaComparse();
  });
}());
