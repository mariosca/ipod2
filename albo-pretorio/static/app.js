/* Albo Pretorio - logica dell'interfaccia: carica gli atti dall'API, filtra, ordina, esporta. */
(function () {
  'use strict';

  const $ = (sel) => document.querySelector(sel);
  const el = {
    ente: $('#ente'), sezione: $('#sezione'), linkOrigine: $('#link-origine'), linkOriginePie: $('#link-origine-pie'),
    tema: $('#tema'), statoRiga: $('#stato-riga'), statoErrore: $('#stato-errore'),
    progresso: $('#progresso'), progressoBarra: $('#progresso-barra'), progressoTesto: $('#progresso-testo'),
    formAggiorna: $('#form-aggiorna'), aggiorna: $('#aggiorna'), opzDettagli: $('#opz-dettagli'), opzCsv: $('#opz-csv'),
    q: $('#q'), tipo: $('#tipo'), da: $('#da'), a: $('#a'), ordine: $('#ordine'), soloPubblicati: $('#solo-pubblicati'),
    conteggio: $('#conteggio'), azzera: $('#azzera'), exportCsv: $('#export-csv'), exportJson: $('#export-json'),
    righe: $('#righe'), vuoto: $('#vuoto'), tpl: $('#tpl-riga'),
  };

  let config = { sezioni: {}, sezione_predefinita: 'papca-ap', base_url: '' };
  let atti = [];
  let ultimaEstrazione = null;
  let timerStato = null;
  let inCorsoPrecedente = false;
  const oggi = new Date().toISOString().slice(0, 10);

  // ---------- utilità ----------
  function dataIt(iso) {
    if (!iso) return '—';
    const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
    return m ? `${m[3]}/${m[2]}/${m[1]}` : iso;
  }
  function dataOraIt(iso) {
    if (!iso) return '—';
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return iso;
    return d.toLocaleString('it-IT', { dateStyle: 'short', timeStyle: 'short' });
  }
  function normalizza(s) {
    return (s || '').toString().toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  }
  function escapeHtml(s) {
    return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }
  function urlSezione(sezione) {
    return `${config.base_url}/web/trasparenza/${sezione}`;
  }
  async function api(percorso, opzioni) {
    const r = await fetch(percorso, opzioni);
    const dati = await r.json().catch(() => ({}));
    if (!r.ok && r.status !== 409) throw new Error(dati.errore || `Errore ${r.status}`);
    return dati;
  }

  // ---------- tema ----------
  function applicaTema(t) {
    if (t) document.documentElement.setAttribute('data-tema', t);
    else document.documentElement.removeAttribute('data-tema');
  }
  try { applicaTema(localStorage.getItem('albo-tema')); } catch (e) { /* ignora */ }
  el.tema.addEventListener('click', () => {
    const attuale = document.documentElement.getAttribute('data-tema')
      || (matchMedia('(prefers-color-scheme: dark)').matches ? 'scuro' : 'chiaro');
    const nuovo = attuale === 'scuro' ? 'chiaro' : 'scuro';
    applicaTema(nuovo);
    try { localStorage.setItem('albo-tema', nuovo); } catch (e) { /* ignora */ }
  });

  // ---------- stato dell'estrazione ----------
  function mostraStato(stato) {
    const s = stato || {};
    if (s.in_corso && s.sezione === el.sezione.value) {
      el.progresso.hidden = false;
      const p = s.progresso || {};
      let testo = 'Avvio…';
      let quota = null;
      if (p.fase === 'elenco') {
        testo = `Elenco: pagina ${p.pagina}${p.pagine ? ' di ' + p.pagine : ''}, ${p.atti} atti trovati${p.totale ? ' su ' + p.totale : ''}`;
        if (p.totale) quota = Math.min(1, p.atti / p.totale) * 0.4;
        else if (p.pagine) quota = Math.min(1, p.pagina / p.pagine) * 0.4;
      } else if (p.fase === 'csv') {
        testo = `Scarico l'export CSV del portale (${p.atti} atti dall'elenco)…`;
        quota = 0.45;
      } else if (p.fase === 'dettagli') {
        testo = `Dettagli: ${p.fatti} di ${p.totale}`;
        quota = 0.45 + (p.totale ? p.fatti / p.totale : 0) * 0.55;
      }
      el.progressoTesto.textContent = testo;
      el.progressoBarra.classList.toggle('indeterminata', quota === null);
      el.progressoBarra.style.width = quota === null ? '' : `${Math.round(quota * 100)}%`;
      el.aggiorna.disabled = true;
      el.aggiorna.textContent = 'Estrazione in corso…';
    } else {
      el.progresso.hidden = true;
      el.aggiorna.disabled = false;
      el.aggiorna.textContent = 'Aggiorna dall\'albo';
    }
    const errore = s.esito === 'errore' && s.sezione === el.sezione.value ? s.errore : null;
    el.statoErrore.hidden = !errore;
    el.statoErrore.textContent = errore ? `L'ultima estrazione non è riuscita: ${errore}` : '';
  }

  function mostraRigaStato() {
    if (!ultimaEstrazione) {
      el.statoRiga.textContent = 'Nessuna estrazione ancora eseguita per questa sezione: premi "Aggiorna dall\'albo".';
      return;
    }
    const st = ultimaEstrazione.statistiche || {};
    const parti = [
      `Ultima estrazione ${dataOraIt(ultimaEstrazione.conclusa)}`,
      `${ultimaEstrazione.n_atti} atti`,
      st.pagine ? `${st.pagine} pagine` : null,
      st.strategia ? `lettura: ${st.strategia}` : null,
      st.durata_s ? `${st.durata_s} s` : null,
    ].filter(Boolean);
    let testo = parti.join(' · ');
    if (ultimaEstrazione.errori && ultimaEstrazione.errori.length) {
      testo += ` · ${ultimaEstrazione.errori.length} avvisi`;
    }
    el.statoRiga.textContent = testo;
  }

  async function controllaStato() {
    try {
      const stato = await api('/api/stato');
      mostraStato(stato);
      if (inCorsoPrecedente && !stato.in_corso) {
        await caricaAtti();
      }
      inCorsoPrecedente = !!stato.in_corso;
      clearTimeout(timerStato);
      if (stato.in_corso) timerStato = setTimeout(controllaStato, 1500);
    } catch (e) {
      el.statoErrore.hidden = false;
      el.statoErrore.textContent = `Impossibile leggere lo stato: ${e.message}`;
    }
  }

  el.formAggiorna.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    el.aggiorna.disabled = true;
    try {
      const r = await api('/api/aggiorna', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ sezione: el.sezione.value, dettagli: el.opzDettagli.checked, csv: el.opzCsv.checked }),
      });
      inCorsoPrecedente = true;
      mostraStato(r.stato);
      clearTimeout(timerStato);
      timerStato = setTimeout(controllaStato, 800);
    } catch (e) {
      el.aggiorna.disabled = false;
      el.statoErrore.hidden = false;
      el.statoErrore.textContent = `Avvio non riuscito: ${e.message}`;
    }
  });

  // ---------- atti ----------
  async function caricaAtti() {
    const sezione = el.sezione.value;
    const dati = await api(`/api/atti?sezione=${encodeURIComponent(sezione)}`);
    if (el.sezione.value !== sezione) return;
    atti = dati.atti || [];
    ultimaEstrazione = dati.ultima_estrazione;
    const scelto = el.tipo.value;
    el.tipo.innerHTML = '<option value="">Tutte</option>';
    Object.entries(dati.tipi || {}).forEach(([nome, n]) => {
      const o = document.createElement('option');
      o.value = nome; o.textContent = `${nome} (${n})`;
      el.tipo.appendChild(o);
    });
    el.tipo.value = scelto;
    if (el.tipo.value !== scelto) el.tipo.value = '';
    mostraRigaStato();
    render();
  }

  function filtrati() {
    const parole = normalizza(el.q.value).split(/\s+/).filter(Boolean);
    const tipo = el.tipo.value;
    const da = el.da.value;
    const a = el.a.value;
    const solo = el.soloPubblicati.checked;
    return atti.filter((x) => {
      if (solo && !x.in_pubblicazione) return false;
      if (tipo && (x.tipo || '(senza tipologia)') !== tipo) return false;
      if (da && (x.data_inizio || '') < da) return false;
      if (a && (x.data_inizio || '9999') > a) return false;
      if (parole.length) {
        const pagliaio = normalizza([x.oggetto, x.numero, x.tipo, x.ente, x.numero_atto,
          Object.values(x.altri_campi || {}).join(' ')].join(' '));
        if (!parole.every((p) => pagliaio.includes(p))) return false;
      }
      return true;
    });
  }

  function ordina(lista) {
    const k = el.ordine.value;
    const numero = (x) => {
      const m = /(\d+)/.exec(x.numero || '');
      return m ? parseInt(m[1], 10) : -1;
    };
    const copia = lista.slice();
    if (k === 'data_asc') copia.sort((x, y) => (x.data_inizio || '').localeCompare(y.data_inizio || ''));
    else if (k === 'scadenza') copia.sort((x, y) => (x.data_fine || '9999').localeCompare(y.data_fine || '9999'));
    else if (k === 'numero') copia.sort((x, y) => numero(y) - numero(x));
    else if (k === 'tipo') copia.sort((x, y) => (x.tipo || '').localeCompare(y.tipo || '', 'it') || (y.data_inizio || '').localeCompare(x.data_inizio || ''));
    else copia.sort((x, y) => (y.data_inizio || '').localeCompare(x.data_inizio || '') || numero(y) - numero(x));
    return copia;
  }

  function classeScadenza(x) {
    if (!x.data_fine) return x.in_pubblicazione ? 'attivo' : '';
    if (x.data_fine < oggi) return 'scaduto';
    const giorni = Math.round((new Date(x.data_fine) - new Date(oggi)) / 86400000);
    return giorni <= 3 ? 'scadenza' : 'attivo';
  }

  function render() {
    const lista = ordina(filtrati());
    el.righe.innerHTML = '';
    el.conteggio.textContent = atti.length
      ? `${lista.length} di ${atti.length} atti${lista.length !== atti.length ? ' (filtrati)' : ''}`
      : '';
    el.vuoto.hidden = lista.length > 0;
    el.vuoto.textContent = atti.length
      ? 'Nessun atto corrisponde ai filtri.'
      : 'L\'archivio locale è vuoto: premi "Aggiorna dall\'albo" per scaricare gli atti pubblicati.';
    const frag = document.createDocumentFragment();
    for (const x of lista) {
      const riga = el.tpl.content.firstElementChild.cloneNode(true);
      riga.dataset.id = x.id;
      const scad = classeScadenza(x);
      if (scad === 'scaduto') riga.classList.add('scaduta');
      riga.querySelector('.numero').textContent = x.numero || '—';
      const badge = riga.querySelector('.badge');
      badge.textContent = x.tipo || 'Senza tipologia';
      const link = riga.querySelector('.oggetto-link');
      link.textContent = x.oggetto || '(senza oggetto)';
      if (x.url) link.href = x.url; else { link.removeAttribute('href'); link.removeAttribute('target'); }
      riga.querySelector('.ente').textContent = x.ente || '';
      riga.querySelector('.dal').textContent = dataIt(x.data_inizio);
      const al = riga.querySelector('.al');
      al.textContent = dataIt(x.data_fine);
      if (scad === 'scadenza') al.innerHTML = `<span class="badge scadenza">${escapeHtml(dataIt(x.data_fine))}</span>`;
      if (scad === 'scaduto') al.innerHTML = `<span class="badge scaduto" title="Pubblicazione conclusa">${escapeHtml(dataIt(x.data_fine))}</span>`;
      const allegati = riga.querySelector('.allegati');
      const lista_allegati = (x.allegati || []).filter((al_) => !al_.firmato);
      const mostrati = lista_allegati.length ? lista_allegati : (x.allegati || []);
      mostrati.slice(0, 2).forEach((al_) => {
        const a = document.createElement('a');
        a.href = al_.url; a.target = '_blank'; a.rel = 'noopener';
        a.textContent = al_.nome; a.title = al_.nome;
        allegati.appendChild(a);
      });
      if (mostrati.length > 2) {
        const s = document.createElement('span');
        s.className = 'altri tenue';
        s.textContent = `+${mostrati.length - 2} altri`;
        allegati.appendChild(s);
      }
      if (!mostrati.length) allegati.innerHTML = '<span class="tenue">—</span>';
      frag.appendChild(riga);
    }
    el.righe.appendChild(frag);
    aggiornaLinkExport();
  }

  function rigaDettaglio(x) {
    const tr = document.createElement('tr');
    tr.className = 'dettaglio';
    const campi = [
      ['Numero registro', x.numero], ['Tipologia', x.tipo], ['Ente / ufficio', x.ente],
      ['Inizio pubblicazione', dataIt(x.data_inizio)], ['Fine pubblicazione', dataIt(x.data_fine)],
      ['Numero atto', x.numero_atto], ['Data atto', dataIt(x.data_atto)], ['Anno', x.anno],
      ['Identificativo', x.id],
      ['In pubblicazione', x.in_pubblicazione ? 'sì (presente nell\'ultima estrazione)' : 'no (non più presente nell\'albo)'],
      ['Rilevato la prima volta', dataOraIt(x.primo_visto)], ['Ultimo aggiornamento', dataOraIt(x.ultimo_visto)],
    ];
    Object.entries(x.altri_campi || {}).forEach(([k, v]) => campi.push([k, v]));
    let html = '<td colspan="7"><dl class="dettaglio-griglia">';
    for (const [k, v] of campi) {
      if (v === null || v === undefined || v === '' || v === '—') continue;
      html += `<div><dt>${escapeHtml(k)}</dt><dd>${escapeHtml(v)}</dd></div>`;
    }
    html += '</dl>';
    if ((x.allegati || []).length) {
      html += '<ul class="dettaglio-allegati">';
      for (const al of x.allegati) {
        html += `<li><a href="${escapeHtml(al.url)}" target="_blank" rel="noopener">${escapeHtml(al.nome)}</a>${al.firmato ? ' <span class="tenue">(firmato digitalmente)</span>' : ''}</li>`;
      }
      html += '</ul>';
    }
    html += '<div class="dettaglio-azioni">';
    if (x.url) html += `<a class="pulsante secondario" href="${escapeHtml(x.url)}" target="_blank" rel="noopener">Apri sull'albo ufficiale ↗</a>`;
    html += `<a class="pulsante secondario" href="/api/atti/${encodeURIComponent(x.sezione)}/${encodeURIComponent(x.id)}" target="_blank" rel="noopener">JSON</a>`;
    html += '</div></td>';
    tr.innerHTML = html;
    return tr;
  }

  el.righe.addEventListener('click', (ev) => {
    const bottone = ev.target.closest('.espandi');
    if (!bottone) return;
    const riga = bottone.closest('tr.riga');
    const successiva = riga.nextElementSibling;
    if (successiva && successiva.classList.contains('dettaglio')) {
      successiva.remove();
      bottone.setAttribute('aria-expanded', 'false');
      bottone.textContent = '+';
      return;
    }
    const x = atti.find((a) => String(a.id) === riga.dataset.id);
    if (!x) return;
    riga.after(rigaDettaglio(x));
    bottone.setAttribute('aria-expanded', 'true');
    bottone.textContent = '−';
  });

  function aggiornaLinkExport() {
    const p = new URLSearchParams({ sezione: el.sezione.value });
    if (el.q.value) p.set('q', el.q.value);
    if (el.tipo.value) p.set('tipo', el.tipo.value);
    if (el.da.value) p.set('da', el.da.value);
    if (el.a.value) p.set('a', el.a.value);
    if (el.soloPubblicati.checked) p.set('solo_pubblicati', '1');
    el.exportCsv.href = `/api/export?formato=csv&${p}`;
    el.exportJson.href = `/api/export?formato=json&${p}`;
  }

  // ---------- eventi ----------
  let timerRicerca = null;
  el.q.addEventListener('input', () => { clearTimeout(timerRicerca); timerRicerca = setTimeout(render, 120); });
  [el.tipo, el.da, el.a, el.ordine, el.soloPubblicati].forEach((c) => c.addEventListener('change', render));
  el.azzera.addEventListener('click', () => {
    el.q.value = ''; el.tipo.value = ''; el.da.value = ''; el.a.value = ''; el.soloPubblicati.checked = false;
    el.ordine.value = 'data_desc';
    render();
  });
  el.sezione.addEventListener('change', async () => {
    el.linkOrigine.href = urlSezione(el.sezione.value);
    el.linkOriginePie.href = urlSezione(el.sezione.value);
    try { localStorage.setItem('albo-sezione', el.sezione.value); } catch (e) { /* ignora */ }
    atti = []; render();
    await caricaAtti();
    await controllaStato();
  });

  // ---------- avvio ----------
  async function avvio() {
    try {
      config = await api('/api/config');
      el.ente.textContent = config.ente + (config.demo ? ' · modalità demo (dati di esempio)' : '');
      document.title = `Albo Pretorio – ${config.ente}`;
      el.sezione.innerHTML = '';
      Object.entries(config.sezioni).forEach(([id, nome]) => {
        const o = document.createElement('option');
        o.value = id; o.textContent = nome;
        el.sezione.appendChild(o);
      });
      let sezione = config.sezione_predefinita;
      try { sezione = localStorage.getItem('albo-sezione') || sezione; } catch (e) { /* ignora */ }
      if (!config.sezioni[sezione]) sezione = config.sezione_predefinita;
      el.sezione.value = sezione;
      el.linkOrigine.href = urlSezione(sezione);
      el.linkOriginePie.href = urlSezione(sezione);
      await caricaAtti();
      await controllaStato();
    } catch (e) {
      el.statoRiga.textContent = '';
      el.statoErrore.hidden = false;
      el.statoErrore.textContent = `Errore di avvio: ${e.message}`;
    }
  }
  avvio();
})();
