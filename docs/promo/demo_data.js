'use strict';
// Quran reading on the default track (from scripts/store_screenshots/demo_data.js
// in the 4.0 store screenshots): Al-Fatihah, all of Al-Baqarah and part of
// Aal-e-Imran, a chunk a day, so the Quran tab's Khatm card is a few weeks in.
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
module.exports = {quranSeed};
