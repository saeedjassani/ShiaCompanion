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
  // Two more Khatms kept alongside it, so the Quran tab shows several tracks:
  // one shared with family (into Al-Kahf), one for Ramazan (through Al-An'am).
  const extra = [['Family Khatm', [[2, 1, 286], [3, 1, 200], [4, 1, 176], [5, 1, 120], [6, 1, 165], [7, 1, 206], [8, 1, 75],
                                   [9, 1, 129], [10, 1, 109], [11, 1, 123], [12, 1, 111], [13, 1, 43], [14, 1, 52],
                                   [15, 1, 99], [16, 1, 128], [17, 1, 111], [18, 1, 60]]],
                 ['Ramazan', [[1, 1, 7], [2, 1, 286], [3, 1, 200], [4, 1, 176], [5, 1, 120], [6, 1, 165]]]];
  extra.forEach(([label, ranges], k) => ranges.forEach(([surah, fromAyah, toAyah], i) => {
    const d = new Date(today); d.setDate(d.getDate() - (ranges.length - i) * 2 - k); d.setHours(21, 30);
    const id = `seed${k}x${i}`;
    entries[id] = {id, label, recitedAt: d.toISOString(), surah, fromAyah, toAyah};
  }));
  return {entries, labels: extra.map(([label]) => label)};
}
module.exports = {quranSeed};

// A qaza tracker partway through making up a few years of prayers (same source).
function qazaSeed() {
  const e = (remaining, completed) => ({remaining, completed});
  return {fajr: e(212, 38), dhuhr: e(181, 69), asr: e(181, 69), maghrib: e(176, 74),
          isha: e(177, 73), namaz_e_ayat: e(3, 1), other: e(0, 0), fast: e(28, 2)};
}
module.exports.qazaSeed = qazaSeed;

// localStorage entries for a clip's or shot's `seed` list. shared_preferences on
// the web keeps each value JSON-encoded under a `flutter.` prefix, and these
// values are themselves JSON strings.
const SEEDS = {quran: ['recitation_tracker_guest', quranSeed], qaza: ['qaza_tracker_guest', qazaSeed]};
module.exports.seedEntries = (names) => (names === true ? ['quran'] : names || [])
  .map((n) => ['flutter.' + SEEDS[n][0], JSON.stringify(JSON.stringify(SEEDS[n][1]()))]);
