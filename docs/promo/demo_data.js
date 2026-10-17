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
