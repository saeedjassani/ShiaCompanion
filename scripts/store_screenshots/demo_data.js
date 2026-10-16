'use strict';
// Demo history seeded into the app's own storage before it starts, so My Stats
// and the Khatm show a reader a few weeks in rather than an empty first run.
// Plausible demo history for My Stats: a 16-day current streak, some gaps before.
function statsSeed(today = new Date()) {
  const days = {};
  const pad = (n) => String(n).padStart(2, '0');
  for (let i = 0; i < 60; i++) {
    const d = new Date(today); d.setDate(d.getDate() - i);
    if (i > 15 && (i % 5 === 0 || i % 7 === 3)) continue;
    const z = 1 + ((i * 7 + 3) % 4);
    const q = i % 3 === 0 ? 2 + (i % 4) : 0;
    days[`${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`] = q ? {z, q} : {z};
  }
  return {v: 1, days, zikrs: {E31: 9, G4: 14, E24: 11, E18: 21, A40: 8, E14: 6, E34: 4},
          archived: {}, archivedDays: 0, best: 23};
}
module.exports = {statsSeed};
// Quran reading on the default track: Al-Fatihah, all of Al-Baqarah and part of
// Aal-e-Imran, a chunk a day, so the khatm ring and verse totals are non-zero.
function quranSeed(today = new Date()) {
  const entries = {};
  const chunks = [[1, 1, 7]];
  for (let a = 1; a <= 286; a += 26) chunks.push([2, a, Math.min(286, a + 25)]);
  for (let a = 1; a <= 120; a += 30) chunks.push([3, a, a + 29]);
  chunks.forEach(([surah, fromAyah, toAyah], i) => {
    const d = new Date(today); d.setDate(d.getDate() - (chunks.length - 1 - i)); d.setHours(6, 10);
    const id = `seed${i}`;
    entries[id] = {id, label: 'Unlabeled', recitedAt: d.toISOString(), surah, fromAyah, toAyah};
  });
  return {entries, labels: []};
}
module.exports.quranSeed = quranSeed;

// A qaza tracker partway through making up a few years of prayers.
function qazaSeed() {
  const e = (remaining, completed) => ({remaining, completed});
  return {fajr: e(212, 38), dhuhr: e(181, 69), asr: e(181, 69), maghrib: e(176, 74),
          isha: e(177, 73), namaz_e_ayat: e(3, 1), other: e(0, 0), fast: e(28, 2)};
}
module.exports.qazaSeed = qazaSeed;
