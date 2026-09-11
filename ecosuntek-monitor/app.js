/* Ecosuntek Monitor — logica dell'app (nessuna dipendenza esterna). */
(function () {
  'use strict';

  // ---------- Configurazione ----------
  const params = new URLSearchParams(location.search);
  const SYMBOL = (params.get('symbol') || 'ECK.MI').toUpperCase().replace(/[^A-Z0-9.^=\-]/g, '');
  const FETCH_RANGE = '1y';
  const REFRESH_MS = 5 * 60 * 1000;
  const CACHE_KEY = 'eck-monitor:cache:' + SYMBOL;
  const MANUAL_KEY = 'eck-monitor:manual:' + SYMBOL;
  const RANGE_KEY = 'eck-monitor:range';

  const yahooUrl = () =>
    `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(SYMBOL)}?range=${FETCH_RANGE}&interval=1d&events=div,splits`;

  // Sorgenti provate in ordine: proxy locale (server.py), Yahoo diretto, proxy CORS pubblici.
  const SOURCES = [
    { name: 'proxy locale', url: () => `/api/chart?symbol=${encodeURIComponent(SYMBOL)}&range=${FETCH_RANGE}` },
    { name: 'Yahoo Finance', url: yahooUrl },
    { name: 'corsproxy.io', url: () => `https://corsproxy.io/?url=${encodeURIComponent(yahooUrl())}` },
    { name: 'allorigins', url: () => `https://api.allorigins.win/raw?url=${encodeURIComponent(yahooUrl())}` },
  ];

  // ---------- Formattazione (it-IT) ----------
  const fmtPrice = new Intl.NumberFormat('it-IT', { minimumFractionDigits: 3, maximumFractionDigits: 3 });
  const fmtPct = new Intl.NumberFormat('it-IT', { minimumFractionDigits: 2, maximumFractionDigits: 2, signDisplay: 'exceptZero' });
  const fmtPctAbs = new Intl.NumberFormat('it-IT', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
  const fmtInt = new Intl.NumberFormat('it-IT', { maximumFractionDigits: 0 });
  const fmtMult = new Intl.NumberFormat('it-IT', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
  const fmtDateLong = new Intl.DateTimeFormat('it-IT', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' });
  const fmtDateShort = new Intl.DateTimeFormat('it-IT', { day: 'numeric', month: 'short' });
  const fmtDateTable = new Intl.DateTimeFormat('it-IT', { weekday: 'short', day: '2-digit', month: '2-digit', year: 'numeric' });
  const fmtTime = new Intl.DateTimeFormat('it-IT', { hour: '2-digit', minute: '2-digit' });

  let currency = 'EUR';
  const cur = (v) => `${fmtPrice.format(v)} ${currency === 'EUR' ? '€' : currency}`;
  const pct = (v) => `${fmtPct.format(v)}%`;
  const toDate = (iso) => new Date(iso + 'T12:00:00');
  const dLong = (iso) => fmtDateLong.format(toDate(iso));
  const dShort = (iso) => fmtDateShort.format(toDate(iso));

  // ---------- DOM ----------
  const $ = (id) => document.getElementById(id);
  const el = {
    statusDot: $('status-dot'), statusText: $('status-text'), banner: $('banner'),
    price: $('t-price'), delta: $('t-delta'), open: $('t-open'), openNote: $('t-open-note'),
    range: $('t-range'), rangeNote: $('t-range-note'), volume: $('t-volume'), volumeNote: $('t-volume-note'),
    summary: $('summary'), chartPrice: $('chart-price'), chartPriceSub: $('chart-price-sub'),
    chartChange: $('chart-change'), tableBody: document.querySelector('#table tbody'), tableSub: $('table-sub'),
    tooltip: $('tooltip'), autoRefresh: $('auto-refresh'), btnRefresh: $('btn-refresh'), btnImport: $('btn-import'),
    dialog: $('import-dialog'), importText: $('import-text'), importError: $('import-error'),
  };
  $('symbol-label').textContent = SYMBOL;
  document.title = `${SYMBOL === 'ECK.MI' ? 'Ecosuntek' : SYMBOL} Monitor`;

  // ---------- Stato ----------
  let allRows = [];          // [{date, open, high, low, close, volume}] ordinati per data crescente
  let rangeDays = Number(localStorage.getItem(RANGE_KEY)) || 66;
  let meta = { source: null, fetchedAt: null, demo: false, manual: false, livePrice: null, liveTime: null };
  let timer = null;

  // ---------- Utilità ----------
  function setStatus(kind, text) {
    el.statusDot.className = 'dot dot-' + kind;
    el.statusText.textContent = text;
  }
  function showBanner(text) {
    el.banner.textContent = text;
    el.banner.hidden = !text;
  }
  function fetchWithTimeout(url, ms) {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), ms);
    return fetch(url, { signal: ctrl.signal, cache: 'no-store' }).finally(() => clearTimeout(t));
  }

  // Converte la risposta dell'API "chart" di Yahoo in righe OHLCV pulite.
  function parseYahoo(json) {
    const res = json && json.chart && json.chart.result && json.chart.result[0];
    if (!res) {
      const err = json && json.chart && json.chart.error;
      throw new Error(err && err.description ? err.description : 'risposta non valida');
    }
    const q = res.indicators.quote[0];
    const rows = [];
    (res.timestamp || []).forEach((ts, i) => {
      const c = q.close[i];
      if (c == null) return;
      const date = new Date(ts * 1000).toLocaleDateString('sv-SE', { timeZone: 'Europe/Rome' }); // YYYY-MM-DD
      rows.push({
        date,
        open: q.open[i] ?? c, high: q.high[i] ?? c, low: q.low[i] ?? c, close: c,
        volume: q.volume[i] ?? 0,
      });
    });
    const m = res.meta || {};
    return {
      rows: dedupe(rows),
      currency: m.currency || 'EUR',
      livePrice: m.regularMarketPrice ?? null,
      liveTime: m.regularMarketTime ? new Date(m.regularMarketTime * 1000) : null,
      name: m.longName || m.shortName || null,
    };
  }

  function dedupe(rows) {
    const byDate = new Map();
    rows.forEach((r) => byDate.set(r.date, r));
    return [...byDate.values()].sort((a, b) => (a.date < b.date ? -1 : 1));
  }

  // Parser CSV tollerante (Yahoo, Borsa Italiana, export Excel con ; e virgola decimale).
  function parseCsv(text) {
    const lines = text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
    if (lines.length < 2) throw new Error('Servono almeno una riga di intestazione e una di dati.');
    const delim = [';', '\t', ','].find((d) => lines[0].split(d).length >= 5) || ',';
    const norm = (s) => s.toLowerCase().replace(/^"|"$/g, '').replace(/[^a-z]/g, '');
    const head = lines[0].split(delim).map(norm);
    const find = (...names) => head.findIndex((h) => names.some((n) => h === n || h.startsWith(n)));
    const idx = {
      date: find('date', 'data', 'giorno'),
      open: find('open', 'apertura', 'aper'),
      high: find('high', 'max', 'massimo'),
      low: find('low', 'min', 'minimo'),
      close: find('close', 'chiusura', 'ultimo', 'prezzo', 'last'),
      volume: find('volume', 'volumi', 'quantita'),
    };
    const missing = ['date', 'open', 'high', 'low', 'close'].filter((k) => idx[k] < 0);
    if (missing.length) throw new Error('Colonne non trovate: ' + missing.join(', ') + '.');
    const num = (s) => {
      if (s == null) return NaN;
      s = String(s).replace(/^"|"$/g, '').trim();
      if (delim !== ',' && /,\d+$/.test(s)) s = s.replace(/\./g, '').replace(',', '.'); // 1.234,56 -> 1234.56
      return parseFloat(s.replace(/[^\d.\-eE]/g, ''));
    };
    const parseDate = (s) => {
      s = String(s).replace(/^"|"$/g, '').trim();
      let m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
      if (m) return `${m[1]}-${m[2]}-${m[3]}`;
      m = s.match(/^(\d{1,2})[\/.\-](\d{1,2})[\/.\-](\d{2,4})/);
      if (m) {
        const y = m[3].length === 2 ? '20' + m[3] : m[3];
        return `${y}-${m[2].padStart(2, '0')}-${m[1].padStart(2, '0')}`;
      }
      return null;
    };
    const rows = [];
    for (const line of lines.slice(1)) {
      const cells = line.split(delim);
      const date = parseDate(cells[idx.date]);
      const close = num(cells[idx.close]);
      if (!date || !isFinite(close)) continue;
      const open = num(cells[idx.open]), high = num(cells[idx.high]), low = num(cells[idx.low]);
      const volume = idx.volume >= 0 ? num(cells[idx.volume]) : 0;
      rows.push({
        date, close,
        open: isFinite(open) ? open : close, high: isFinite(high) ? high : close, low: isFinite(low) ? low : close,
        volume: isFinite(volume) ? volume : 0,
      });
    }
    if (rows.length < 2) throw new Error('Nessuna riga valida riconosciuta.');
    return dedupe(rows);
  }

  // ---------- Caricamento dati ----------
  async function loadData(isManualRefresh) {
    const manual = localStorage.getItem(MANUAL_KEY);
    if (manual) {
      try {
        const saved = JSON.parse(manual);
        applyData(saved.rows, { source: 'CSV importato', manual: true, fetchedAt: new Date(saved.savedAt) });
        setStatus('warn', `Dati da CSV importato (${saved.rows.length} sedute). Aggiornamento automatico sospeso.`);
        return;
      } catch (e) { localStorage.removeItem(MANUAL_KEY); }
    }

    setStatus('busy', isManualRefresh ? 'Aggiornamento in corso…' : 'Caricamento dati…');
    document.querySelectorAll('.chart').forEach((c) => c.classList.add('is-stale'));
    const errors = [];
    for (const src of SOURCES) {
      try {
        const r = await fetchWithTimeout(src.url(), 9000);
        if (!r.ok) throw new Error('HTTP ' + r.status);
        const json = await r.json();
        const parsed = parseYahoo(json);
        if (parsed.rows.length < 2) throw new Error('troppo pochi dati');
        currency = parsed.currency;
        $('currency-label').textContent = currency;
        applyData(parsed.rows, { source: src.name, fetchedAt: new Date(), demo: false, manual: false, livePrice: parsed.livePrice, liveTime: parsed.liveTime });
        localStorage.setItem(CACHE_KEY, JSON.stringify({ rows: parsed.rows, currency, savedAt: Date.now(), source: src.name }));
        setStatus('ok', `Aggiornato alle ${fmtTime.format(new Date())} · fonte: ${src.name}`);
        showBanner('');
        return;
      } catch (e) {
        errors.push(`${src.name}: ${e.name === 'AbortError' ? 'timeout' : e.message}`);
      }
    }

    // Nessuna sorgente online: cache locale, altrimenti dati dimostrativi.
    const cached = localStorage.getItem(CACHE_KEY);
    if (cached) {
      try {
        const c = JSON.parse(cached);
        currency = c.currency || 'EUR';
        applyData(c.rows, { source: 'cache locale', fetchedAt: new Date(c.savedAt) });
        setStatus('warn', `Offline: dati salvati il ${fmtDateLong.format(new Date(c.savedAt))} alle ${fmtTime.format(new Date(c.savedAt))}`);
        showBanner('Nessuna sorgente online raggiungibile. Mostro l\'ultimo aggiornamento salvato nel browser. ' + errors.join(' · '));
        return;
      } catch (e) { localStorage.removeItem(CACHE_KEY); }
    }
    currency = 'EUR';
    applyData(window.ECK_DEMO_DATA || [], { source: 'dati dimostrativi', demo: true, fetchedAt: new Date() });
    setStatus('err', 'Nessuna sorgente raggiungibile: dati DIMOSTRATIVI');
    showBanner('Impossibile scaricare le quotazioni (blocco CORS o rete assente). I dati mostrati sono SIMULATI e non corrispondono al titolo reale. Avvia server.py oppure importa un CSV. Dettagli: ' + errors.join(' · '));
  }

  function applyData(rows, m) {
    allRows = rows;
    meta = Object.assign({ demo: false, manual: false, livePrice: null, liveTime: null }, m);
    render();
  }

  // ---------- Statistiche ----------
  function enrich(rows) {
    // aggiunge variazione % su chiusura precedente ed escursione intraday %
    return rows.map((r, i) => {
      const prev = i > 0 ? rows[i - 1].close : null;
      const change = prev ? ((r.close - prev) / prev) * 100 : null;
      const swing = r.low > 0 ? ((r.high - r.low) / r.low) * 100 : 0;
      const intraday = r.open > 0 ? ((r.close - r.open) / r.open) * 100 : 0;
      return Object.assign({}, r, { prev, change, swing, intraday });
    });
  }
  const mean = (a) => (a.length ? a.reduce((s, v) => s + v, 0) / a.length : 0);
  const stdev = (a) => { if (a.length < 2) return 0; const m = mean(a); return Math.sqrt(a.reduce((s, v) => s + (v - m) ** 2, 0) / (a.length - 1)); };

  function stats(rows) {
    const changes = rows.map((r) => r.change).filter((v) => v != null);
    const ups = changes.filter((v) => v > 0).length, downs = changes.filter((v) => v < 0).length, flats = changes.length - ups - downs;
    const best = rows.reduce((b, r) => (r.change != null && (b == null || r.change > b.change) ? r : b), null);
    const worst = rows.reduce((b, r) => (r.change != null && (b == null || r.change < b.change) ? r : b), null);
    const hi = rows.reduce((b, r) => (b == null || r.high > b.high ? r : b), null);
    const lo = rows.reduce((b, r) => (b == null || r.low < b.low ? r : b), null);
    const last = rows[rows.length - 1], first = rows[0];
    const periodChange = first && last && first.prev ? ((last.close - first.prev) / first.prev) * 100
      : first && last ? ((last.close - first.open) / first.open) * 100 : 0;
    // serie in corso (giorni consecutivi con lo stesso segno)
    let streak = 0, streakSign = 0;
    for (let i = rows.length - 1; i >= 0; i--) {
      const c = rows[i].change; if (c == null || c === 0) break;
      const s = Math.sign(c); if (streakSign === 0) streakSign = s;
      if (s !== streakSign) break; streak++;
    }
    const sma20 = rows.length >= 20 ? mean(rows.slice(-20).map((r) => r.close)) : null;
    const avgVol = mean(rows.map((r) => r.volume));
    return {
      n: changes.length, ups, downs, flats, best, worst, hi, lo, last, first, periodChange, streak, streakSign, sma20, avgVol,
      avgChange: mean(changes), vol: stdev(changes), avgSwing: mean(rows.map((r) => r.swing)),
      avgAbsChange: mean(changes.map(Math.abs)),
    };
  }

  // ---------- Render ----------
  function render() {
    const rowsAll = enrich(allRows);
    const rows = rowsAll.slice(-rangeDays);
    document.querySelectorAll('.chart').forEach((c) => c.classList.remove('is-stale'));
    if (!rows.length) return;
    const s = stats(rows);
    renderTiles(s, rowsAll);
    renderSummary(s, rows);
    renderPriceChart(rows);
    renderChangeChart(rows);
    renderTable(rows);
  }

  function signClass(v) { return v > 0 ? 'pos' : v < 0 ? 'neg' : ''; }
  function arrow(v) { return v > 0 ? '▲' : v < 0 ? '▼' : '■'; }

  function renderTiles(s, rowsAll) {
    const last = s.last;
    const price = meta.livePrice != null && !meta.manual ? meta.livePrice : last.close;
    const ref = meta.livePrice != null && !meta.manual && meta.liveTime && meta.liveTime.toISOString().slice(0, 10) > last.date ? last.close : last.prev;
    el.price.textContent = cur(price);
    if (ref) {
      const ch = ((price - ref) / ref) * 100;
      el.delta.textContent = `${arrow(ch)} ${pct(ch)} (${fmtPct.format(price - ref)}) rispetto alla chiusura precedente`;
      el.delta.className = 'tile-delta ' + signClass(ch);
    } else { el.delta.textContent = '—'; el.delta.className = 'tile-delta'; }
    el.open.textContent = cur(last.open);
    el.openNote.textContent = `Seduta del ${dLong(last.date)}`;
    el.range.textContent = `${fmtPrice.format(last.low)} – ${fmtPrice.format(last.high)}`;
    el.rangeNote.textContent = `Escursione ${fmtPctAbs.format(last.swing)}%`;
    el.volume.textContent = fmtInt.format(last.volume);
    el.volumeNote.textContent = s.avgVol > 0 ? `${fmtMult.format(last.volume / s.avgVol)}× la media del periodo` : '—';
    el.chartPriceSub.textContent = `${dShort(rowsAll.slice(-rangeDays)[0].date)} – ${dShort(last.date)} · ${rowsAll.slice(-rangeDays).length} sedute`;
  }

  function block(title, nodes, extraClass) {
    const div = document.createElement('div');
    div.className = 'summary-block' + (extraClass ? ' ' + extraClass : '');
    const h = document.createElement('h3'); h.textContent = title; div.appendChild(h);
    nodes.forEach((n) => div.appendChild(n));
    return div;
  }
  const p = (text) => { const e = document.createElement('p'); e.textContent = text; return e; };
  const ul = (items) => { const u = document.createElement('ul'); items.forEach((t) => { const li = document.createElement('li'); li.textContent = t; u.appendChild(li); }); return u; };

  function renderSummary(s, rows) {
    const last = s.last;
    const frag = document.createDocumentFragment();

    // 1. Ultima seduta
    const parts = [];
    parts.push(`Seduta del ${dLong(last.date)}: apertura a ${cur(last.open)}, chiusura a ${cur(last.close)}` +
      (last.change != null ? `, ${last.change >= 0 ? 'in rialzo' : 'in ribasso'} del ${fmtPctAbs.format(Math.abs(last.change))}% rispetto alla chiusura precedente (${cur(last.prev)}).` : '.'));
    parts.push(`Il prezzo ha oscillato tra un minimo di ${cur(last.low)} e un massimo di ${cur(last.high)}, un'escursione intraday del ${fmtPctAbs.format(last.swing)}%` +
      (s.avgSwing > 0 ? ` (media del periodo ${fmtPctAbs.format(s.avgSwing)}%).` : '.'));
    const posInRange = last.high > last.low ? ((last.close - last.low) / (last.high - last.low)) * 100 : 50;
    parts.push(posInRange >= 70 ? 'La chiusura è avvenuta nella parte alta del range di giornata.' :
      posInRange <= 30 ? 'La chiusura è avvenuta nella parte bassa del range di giornata.' : 'La chiusura è avvenuta a metà del range di giornata.');
    if (s.avgVol > 0) {
      const m = last.volume / s.avgVol;
      parts.push(`Volumi: ${fmtInt.format(last.volume)} pezzi, ${m >= 1.5 ? 'ben sopra' : m >= 1.05 ? 'sopra' : m <= 0.5 ? 'molto sotto' : m <= 0.95 ? 'sotto' : 'in linea con'} la media del periodo (${fmtInt.format(s.avgVol)}).`);
    }
    frag.appendChild(block('Ultima seduta', [p(parts.join(' '))]));

    // 2. Segnali
    const alerts = [];
    if (last.change != null && s.vol > 0 && Math.abs(last.change) > 2 * s.vol) {
      alerts.push(`Movimento anomalo: la variazione di ${pct(last.change)} supera il doppio della volatilità giornaliera del periodo (${fmtPctAbs.format(s.vol)}%).`);
    }
    if (last.swing > 2 * s.avgSwing && s.avgSwing > 0) alerts.push(`Escursione intraday doppia rispetto alla media (${fmtPctAbs.format(last.swing)}% contro ${fmtPctAbs.format(s.avgSwing)}%).`);
    if (s.avgVol > 0 && last.volume > 2 * s.avgVol) alerts.push(`Volumi più che doppi rispetto alla media del periodo.`);
    if (s.hi && last.close >= s.hi.high * 0.995) alerts.push('Chiusura sui massimi del periodo.');
    if (s.lo && last.close <= s.lo.low * 1.005) alerts.push('Chiusura sui minimi del periodo.');
    if (s.streak >= 3) alerts.push(`${s.streak} sedute consecutive ${s.streakSign > 0 ? 'in rialzo' : 'in ribasso'}.`);
    if (alerts.length) frag.appendChild(block('Segnali', [ul(alerts)], 'alert'));

    // 3. Periodo
    const n = rows.length;
    const items = [
      `Andamento: ${pct(s.periodChange)} in ${n} sedute (${s.ups} in rialzo, ${s.downs} in ribasso${s.flats ? `, ${s.flats} ${s.flats === 1 ? 'invariata' : 'invariate'}` : ''}).`,
      `Oscillazione tipica: variazione media ${pct(s.avgChange)} al giorno, ampiezza media ${fmtPctAbs.format(s.avgAbsChange)}%, volatilità (dev. standard) ${fmtPctAbs.format(s.vol)}%.`,
      `Escursione intraday media (massimo su minimo): ${fmtPctAbs.format(s.avgSwing)}%.`,
    ];
    if (s.best && s.worst) items.push(`Miglior seduta ${pct(s.best.change)} il ${dShort(s.best.date)}; peggiore ${pct(s.worst.change)} il ${dShort(s.worst.date)}.`);
    if (s.hi && s.lo) {
      const fromHi = ((last.close - s.hi.high) / s.hi.high) * 100, fromLo = ((last.close - s.lo.low) / s.lo.low) * 100;
      items.push(`Massimo di periodo ${cur(s.hi.high)} (${dShort(s.hi.date)}), minimo ${cur(s.lo.low)} (${dShort(s.lo.date)}): il prezzo attuale è a ${pct(fromHi)} dal massimo e a ${pct(fromLo)} dal minimo.`);
    }
    if (s.sma20 != null) items.push(`Chiusura ${last.close >= s.sma20 ? 'sopra' : 'sotto'} la media mobile a 20 sedute (${cur(s.sma20)}).`);
    if (s.streak > 0) items.push(`Serie in corso: ${s.streak} ${s.streak === 1 ? 'seduta' : 'sedute'} ${s.streakSign > 0 ? 'in rialzo' : 'in ribasso'}.`);
    frag.appendChild(block(`Periodo selezionato (${n} sedute)`, [ul(items)]));

    if (meta.demo) frag.appendChild(block('Attenzione', [p('Questo riassunto è calcolato su dati dimostrativi simulati, non sulle quotazioni reali.')], 'alert'));
    el.summary.replaceChildren(frag);
  }

  // ---------- Grafici (SVG) ----------
  const NS = 'http://www.w3.org/2000/svg';
  function svgEl(tag, attrs, parent) {
    const e = document.createElementNS(NS, tag);
    for (const k in attrs) e.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(e);
    return e;
  }
  function niceTicks(min, max, count) {
    const span = max - min || 1, raw = span / count, mag = 10 ** Math.floor(Math.log10(raw));
    const step = [1, 2, 2.5, 5, 10].map((m) => m * mag).find((st) => span / st <= count) || mag * 10;
    const ticks = [];
    for (let v = Math.ceil(min / step) * step; v <= max + 1e-9; v += step) ticks.push(+v.toFixed(6));
    return ticks;
  }
  function dateTickIndexes(rows, maxTicks) {
    const step = Math.max(1, Math.ceil(rows.length / maxTicks));
    const idx = [];
    for (let i = rows.length - 1; i >= 0; i -= step) idx.unshift(i);
    return idx;
  }

  function showTooltip(x, y, dateIso, lines) {
    const t = el.tooltip;
    t.replaceChildren();
    const d = document.createElement('div'); d.className = 'tt-date'; d.textContent = dLong(dateIso); t.appendChild(d);
    lines.forEach(([label, value, keyed]) => {
      const row = document.createElement('div'); row.className = 'tt-row';
      const l = document.createElement('span');
      if (keyed) { const k = document.createElement('span'); k.className = 'tt-key'; l.appendChild(k); }
      l.appendChild(document.createTextNode(label));
      const v = document.createElement('strong'); v.textContent = value;
      row.appendChild(v); row.appendChild(l); t.appendChild(row);
    });
    t.hidden = false;
    const w = t.offsetWidth, h = t.offsetHeight;
    let left = x + 14, top = y + 14;
    if (left + w > window.innerWidth - 8) left = x - w - 14;
    if (top + h > window.innerHeight - 8) top = y - h - 14;
    t.style.left = left + 'px'; t.style.top = top + 'px';
  }
  function hideTooltip() { el.tooltip.hidden = true; }

  function renderPriceChart(rows) {
    const W = 720, H = 300, m = { t: 16, r: 64, b: 28, l: 12 };
    const iw = W - m.l - m.r, ih = H - m.t - m.b;
    const closes = rows.map((r) => r.close);
    let lo = Math.min(...rows.map((r) => r.low)), hi = Math.max(...rows.map((r) => r.high));
    const pad = (hi - lo) * 0.08 || lo * 0.05; lo -= pad; hi += pad;
    const x = (i) => m.l + (rows.length === 1 ? iw / 2 : (i / (rows.length - 1)) * iw);
    const y = (v) => m.t + ih - ((v - lo) / (hi - lo)) * ih;

    const svg = svgEl('svg', { viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': 'Grafico del prezzo di chiusura' });
    const grid = svgEl('g', { class: 'grid' }, svg);
    niceTicks(lo, hi, 5).forEach((v) => {
      svgEl('line', { x1: m.l, x2: m.l + iw, y1: y(v), y2: y(v) }, grid);
      const t = svgEl('text', { x: m.l + iw + 6, y: y(v) + 4 }, svg); t.textContent = fmtPrice.format(v);
    });
    const axis = svgEl('g', { class: 'axis' }, svg);
    svgEl('line', { x1: m.l, x2: m.l + iw, y1: m.t + ih, y2: m.t + ih }, axis);
    dateTickIndexes(rows, 6).forEach((i) => {
      const t = svgEl('text', { x: x(i), y: H - 8, 'text-anchor': i === 0 ? 'start' : i === rows.length - 1 ? 'end' : 'middle' }, svg);
      t.textContent = dShort(rows[i].date);
    });
    const pts = closes.map((c, i) => `${x(i).toFixed(1)},${y(c).toFixed(1)}`);
    svgEl('path', { class: 'area', d: `M${x(0)},${m.t + ih} L${pts.join(' L')} L${x(rows.length - 1)},${m.t + ih} Z` }, svg);
    svgEl('path', { class: 'line', d: 'M' + pts.join(' L') }, svg);
    // etichetta di fine serie
    const lastI = rows.length - 1;
    svgEl('circle', { cx: x(lastI), cy: y(closes[lastI]), r: 4, fill: 'var(--accent)', stroke: 'var(--surface)', 'stroke-width': 2 }, svg);
    const endLabel = svgEl('text', { class: 'end-label', x: m.l + iw + 6, y: y(closes[lastI]) - 8 }, svg);
    endLabel.textContent = fmtPrice.format(closes[lastI]);
    // livello hover
    const cross = svgEl('line', { class: 'crosshair', y1: m.t, y2: m.t + ih, x1: 0, x2: 0 }, svg);
    const marker = svgEl('circle', { class: 'marker', r: 5 }, svg);
    const hit = svgEl('rect', { x: m.l, y: m.t, width: iw, height: ih, fill: 'transparent' }, svg);
    const onMove = (ev) => {
      const rect = svg.getBoundingClientRect();
      const px = ((ev.clientX - rect.left) / rect.width) * W;
      const i = Math.max(0, Math.min(lastI, Math.round(((px - m.l) / iw) * lastI)));
      cross.setAttribute('x1', x(i)); cross.setAttribute('x2', x(i)); cross.style.opacity = 1;
      marker.setAttribute('cx', x(i)); marker.setAttribute('cy', y(closes[i])); marker.style.opacity = 1;
      const r = rows[i];
      showTooltip(ev.clientX, ev.clientY, r.date, [
        ['Chiusura', cur(r.close), true],
        ['Var. %', r.change != null ? pct(r.change) : '—'],
        ['Apertura', fmtPrice.format(r.open)],
        ['Min – max', `${fmtPrice.format(r.low)} – ${fmtPrice.format(r.high)}`],
        ['Volume', fmtInt.format(r.volume)],
      ]);
    };
    hit.addEventListener('pointermove', onMove);
    hit.addEventListener('pointerleave', () => { cross.style.opacity = 0; marker.style.opacity = 0; hideTooltip(); });
    el.chartPrice.replaceChildren(svg);
  }

  function renderChangeChart(rows) {
    const W = 480, H = 300, m = { t: 16, r: 48, b: 28, l: 12 };
    const iw = W - m.l - m.r, ih = H - m.t - m.b;
    const data = rows.filter((r) => r.change != null);
    if (!data.length) { el.chartChange.replaceChildren(); const d = document.createElement('p'); d.className = 'empty'; d.textContent = 'Dati insufficienti'; el.chartChange.appendChild(d); return; }
    const maxAbs = Math.max(0.5, ...data.map((r) => Math.abs(r.change)));
    const lo = -maxAbs * 1.1, hi = maxAbs * 1.1;
    const slot = iw / data.length;
    const bw = Math.min(24, Math.max(1, slot - 2));
    const x = (i) => m.l + slot * i + (slot - bw) / 2;
    const y = (v) => m.t + ih - ((v - lo) / (hi - lo)) * ih;

    const svg = svgEl('svg', { viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': 'Grafico delle variazioni giornaliere' });
    const grid = svgEl('g', { class: 'grid' }, svg);
    niceTicks(lo, hi, 5).forEach((v) => {
      if (Math.abs(v) < 1e-9) return;
      svgEl('line', { x1: m.l, x2: m.l + iw, y1: y(v), y2: y(v) }, grid);
      const t = svgEl('text', { x: m.l + iw + 6, y: y(v) + 4 }, svg); t.textContent = fmtPct.format(v) + '%';
    });
    const axis = svgEl('g', { class: 'axis' }, svg);
    svgEl('line', { x1: m.l, x2: m.l + iw, y1: y(0), y2: y(0) }, axis);
    const t0 = svgEl('text', { x: m.l + iw + 6, y: y(0) + 4 }, svg); t0.textContent = '0%';
    dateTickIndexes(data, 4).forEach((i) => {
      const t = svgEl('text', { x: x(i) + bw / 2, y: H - 8, 'text-anchor': i === 0 ? 'start' : i === data.length - 1 ? 'end' : 'middle' }, svg);
      t.textContent = dShort(data[i].date);
    });
    data.forEach((r, i) => {
      const v = r.change, top = Math.min(y(0), y(v)), h = Math.max(1, Math.abs(y(v) - y(0)));
      const rr = Math.min(4, bw / 2, h);
      const cls = v > 0 ? 'bar-up' : v < 0 ? 'bar-down' : 'bar-flat';
      // rettangolo con solo gli angoli lontani dalla base arrotondati
      const x0 = x(i), x1 = x0 + bw;
      const d = v >= 0
        ? `M${x0},${y(0)} V${top + rr} Q${x0},${top} ${x0 + rr},${top} H${x1 - rr} Q${x1},${top} ${x1},${top + rr} V${y(0)} Z`
        : `M${x0},${y(0)} V${y(0) + h - rr} Q${x0},${y(0) + h} ${x0 + rr},${y(0) + h} H${x1 - rr} Q${x1},${y(0) + h} ${x1},${y(0) + h - rr} V${y(0)} Z`;
      svgEl('path', { class: cls, d }, svg);
      const hitRect = svgEl('rect', { class: 'bar', x: m.l + slot * i, y: m.t, width: slot, height: ih, fill: 'transparent' }, svg);
      hitRect.addEventListener('pointermove', (ev) => showTooltip(ev.clientX, ev.clientY, r.date, [
        ['Var. %', `${arrow(v)} ${pct(v)}`],
        ['Chiusura', cur(r.close)],
        ['Precedente', cur(r.prev)],
        ['Escursione', fmtPctAbs.format(r.swing) + '%'],
      ]));
      hitRect.addEventListener('pointerleave', hideTooltip);
    });
    el.chartChange.replaceChildren(svg);
  }

  function renderTable(rows) {
    const frag = document.createDocumentFragment();
    [...rows].reverse().forEach((r) => {
      const tr = document.createElement('tr');
      const cells = [
        [fmtDateTable.format(toDate(r.date)), ''],
        [fmtPrice.format(r.open), 'num'], [fmtPrice.format(r.low), 'num'], [fmtPrice.format(r.high), 'num'], [fmtPrice.format(r.close), 'num'],
        [r.change != null ? `${arrow(r.change)} ${pct(r.change)}` : '—', 'num ' + signClass(r.change)],
        [fmtPctAbs.format(r.swing) + '%', 'num'], [fmtInt.format(r.volume), 'num'],
      ];
      cells.forEach(([text, cls]) => { const td = document.createElement('td'); td.textContent = text; if (cls) td.className = cls; tr.appendChild(td); });
      frag.appendChild(tr);
    });
    el.tableBody.replaceChildren(frag);
    el.tableSub.textContent = `${rows.length} sedute, dalla più recente`;
  }

  // ---------- Eventi ----------
  document.querySelectorAll('.range-btn').forEach((b) => {
    if (Number(b.dataset.range) === rangeDays) { document.querySelectorAll('.range-btn').forEach((x) => x.classList.remove('is-active')); b.classList.add('is-active'); }
    b.addEventListener('click', () => {
      document.querySelectorAll('.range-btn').forEach((x) => x.classList.remove('is-active'));
      b.classList.add('is-active');
      rangeDays = Number(b.dataset.range);
      localStorage.setItem(RANGE_KEY, String(rangeDays));
      render();
    });
  });
  el.btnRefresh.addEventListener('click', () => loadData(true));
  el.btnImport.addEventListener('click', () => { el.importError.hidden = true; el.dialog.showModal(); });
  $('import-cancel').addEventListener('click', () => el.dialog.close());
  $('import-ok').addEventListener('click', () => {
    try {
      const rows = parseCsv(el.importText.value);
      localStorage.setItem(MANUAL_KEY, JSON.stringify({ rows, savedAt: Date.now() }));
      el.dialog.close();
      loadData(false);
    } catch (e) { el.importError.textContent = e.message; el.importError.hidden = false; }
  });
  $('import-clear').addEventListener('click', () => { localStorage.removeItem(MANUAL_KEY); el.dialog.close(); loadData(true); });

  function schedule() {
    clearInterval(timer);
    if (el.autoRefresh.checked) timer = setInterval(() => { if (!document.hidden) loadData(true); }, REFRESH_MS);
  }
  el.autoRefresh.addEventListener('change', schedule);
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden && meta.fetchedAt && Date.now() - meta.fetchedAt.getTime() > REFRESH_MS && el.autoRefresh.checked) loadData(true);
  });
  window.addEventListener('resize', () => { if (allRows.length) render(); });

  schedule();
  loadData(false);
})();
