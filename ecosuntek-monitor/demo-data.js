// Dati DIMOSTRATIVI, generati in modo deterministico: NON sono quotazioni reali di Ecosuntek.
// Vengono usati solo quando nessuna sorgente online è raggiungibile, così l'interfaccia resta consultabile.
window.ECK_DEMO_DATA = (function () {
  const rows = [];
  let seed = 20260911;
  const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
  let close = 1.28;
  const d = new Date(Date.UTC(2025, 8, 15)); // 15 settembre 2025
  const end = Date.UTC(2026, 8, 11);
  while (d.getTime() <= end) {
    const dow = d.getUTCDay();
    if (dow !== 0 && dow !== 6) {
      const drift = -0.0002, vol = 0.021;
      const g = (rnd() + rnd() + rnd() - 1.5) * 1.63; // ~ normale
      const open = +(close * (1 + (rnd() - 0.5) * 0.008)).toFixed(3);
      const next = +(close * (1 + drift + vol * g)).toFixed(3);
      const hi = +(Math.max(open, next) * (1 + rnd() * 0.018)).toFixed(3);
      const lo = +(Math.min(open, next) * (1 - rnd() * 0.018)).toFixed(3);
      const volume = Math.round(4000 + rnd() * 26000 * (1 + Math.abs(g)));
      rows.push({ date: d.toISOString().slice(0, 10), open, high: hi, low: lo, close: next, volume });
      close = next;
    }
    d.setUTCDate(d.getUTCDate() + 1);
  }
  return rows;
})();
