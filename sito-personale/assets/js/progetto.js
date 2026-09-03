/* Scheda di progetto: legge ?id= e costruisce la pagina dai dati. */
(function () {
  'use strict';

  function nonTrovato(dove) {
    dove.innerHTML = '<div class="vuoto">' +
      '<h1 class="titolo-progetto" style="margin:0 auto 14px">Progetto non trovato</h1>' +
      '<p>Il collegamento potrebbe essere vecchio o incompleto.</p>' +
      '<p><a class="pulsante" href="index.html#lavori">Vedi tutti i lavori</a></p></div>';
  }

  function vicini(indice, elenco) {
    var esc = window.SITO.escapeHtml;
    var prima = elenco[indice - 1];
    var dopo = elenco[indice + 1];
    var html = '<nav class="avanti" aria-label="Altri progetti">';

    if (prima) {
      html += '<a href="progetto.html?id=' + encodeURIComponent(prima.id) + '">' +
        '<span class="k">← Precedente</span><span class="t">' + esc(prima.titolo) + '</span></a>';
    }
    if (dopo) {
      html += '<a class="fine" href="progetto.html?id=' + encodeURIComponent(dopo.id) + '">' +
        '<span class="k">Successivo →</span><span class="t">' + esc(dopo.titolo) + '</span></a>';
    }
    return html + '</nav>';
  }

  function disegna(pr, indice, elenco) {
    var esc = window.SITO.escapeHtml;
    document.title = pr.titolo + ' — ' + window.PROFILO.nome;

    var meta = document.querySelector('meta[name="description"]');
    if (meta) meta.setAttribute('content', pr.sommario);

    document.querySelector('[data-progetto]').innerHTML = '' +
      '<p class="briciola"><a href="index.html">Home</a> / <a href="index.html#lavori">Lavori</a> / ' +
        esc(pr.anno) + '</p>' +

      '<h1 class="titolo-progetto">' + esc(pr.titolo) + '</h1>' +
      '<p class="sottotitolo">' + esc(pr.sommario) + '</p>' +

      '<div class="scheda">' +
        '<div><span class="k">Anno</span>' + esc(pr.anno) + '</div>' +
        '<div><span class="k">Ruolo</span>' + esc(pr.ruolo) + '</div>' +
        '<div><span class="k">Durata</span>' + esc(pr.durata) + '</div>' +
        '<div><span class="k">Ambito</span>' + pr.tag.map(esc).join(', ') + '</div>' +
      '</div>' +

      '<div class="copertina comparsa">' + window.SITO.copertina(pr) + '</div>' +

      '<section class="blocco comparsa"><h2>Il contesto</h2><p>' + esc(pr.contesto) + '</p></section>' +
      '<section class="blocco comparsa"><h2>Cosa ho fatto</h2><p>' + esc(pr.intervento) + '</p></section>' +
      '<section class="blocco comparsa"><h2>Risultati</h2><ul class="risultati">' +
        pr.risultati.map(function (r) { return '<li>' + esc(r) + '</li>'; }).join('') +
      '</ul></section>' +

      vicini(indice, elenco);
  }

  document.addEventListener('DOMContentLoaded', function () {
    var dove = document.querySelector('[data-progetto]');
    var id = new URLSearchParams(location.search).get('id');
    var elenco = window.PROGETTI || [];
    var indice = -1;

    for (var i = 0; i < elenco.length; i++) {
      if (elenco[i].id === id) { indice = i; break; }
    }

    if (indice === -1) { nonTrovato(dove); return; }
    disegna(elenco[indice], indice, elenco);
    window.SITO.iniziaComparse();
  });
}());
