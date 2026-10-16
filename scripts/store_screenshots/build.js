'use strict';
// Frames the raw captures into every store's screenshot sizes.
const {render, renderFeatureGraphic, launchBrowser} = require('./compose');
const {OUT_DIR} = require('./config');

// Ordered by what earns the install: what the app is, its core content, what
// 4.0 adds, then the tools. Shots name raw captures without the p-/t- prefix.
const PHONE = [
  {name: '01-light-dark', layout: 'fan', shots: ['home-l', 'home-d'], badge: 'New in 4.0',
   caption: 'Prayer times, duas\nand Quran in one app'},
  {name: '02-reader', layout: 'tilt', shots: ['read-l'],
   caption: 'Read and understand\nevery dua',
   callouts: [['Arabic + translation', 'Line by line'], ['Bookmark a line', 'Pick up where you left off'],
              ['Auto-scroll', 'Hands-free reading']]},
  {name: '03-languages', layout: 'peek', shots: ['home-gu', 'home-ur', 'home-ar'],
   caption: 'Now in Urdu, Persian,\nArabic and Gujarati'},
  {name: '04-quran', layout: 'tilt', shots: ['quran-d'],
   caption: 'The Quran, with\nyour own Khatm',
   callouts: [['Translated', 'English, Urdu, Persian, Gujarati'], ['Notes on any verse', null],
              ['Track every Khatm', 'Pick up where you left off']]},
  {name: '05-listen', layout: 'fan', shots: ['playlists-l', 'player-d'],
   caption: 'Listen to duas,\nor a whole playlist'},
  {name: '06-stats', layout: 'tilt', shots: ['stats-l'],
   caption: 'Keep up your\ndaily recitation',
   callouts: [['Daily streaks', null], ['Zikrs, verses, qaza', 'Week, month, all time']]},
  {name: '07-calendar', layout: 'tilt', shots: ['calendar-d'],
   caption: 'Hijri dates from the\nmoon where you are',
   callouts: [['Islamic events', null], ['Prayer times', 'For any day, any city']]},
  {name: '08-tools', layout: 'peek', shots: ['qaza-d', 'tasbeeh-l', 'qibla-d'],
   caption: 'Qibla, tasbeeh and\nqaza tracker'},
];
// The App Store takes ten; Play stops at eight.
const PHONE_EXTRA = [
  {name: '09-urdu-duas', layout: 'tilt', shots: ['read-ur-d'],
   caption: 'Famous duas,\ntranslated',
   callouts: [['Kumayl, Nudba, Tawassul', 'Ziyarat Ashura, Hadith al-Kisa…'], ['Gujarati too', 'Dua Kumayl'],
              ['Missing one?', 'Request its translation in the app']]},
  {name: '10-library', layout: 'tilt', shots: ['library-l'],
   caption: 'A library of over\na thousand books',
   callouts: [['1,162 books', 'Read them in the app'], ['Request a book', 'Missing one? Ask for it']]},
];

// Tablets have no Home slide: on the web build Home carries a "Get the app"
// card with store badges, which has no place in a store listing.
const TABLET = [
  {name: '01-reader', layout: 'fan', shots: ['read-l', 'read-ur-d'], badge: 'New in 4.0',
   caption: 'Duas, ziyarats and Quran,\nin light and dark'},
  {name: '02-quran', layout: 'tilt', shots: ['quran-d'], caption: 'The Quran, with\nyour own Khatm',
   callouts: [['Translated', 'English, Urdu, Persian, Gujarati'], ['Notes on any verse', null],
              ['Track every Khatm', null]]},
  {name: '03-calendar', layout: 'tilt', shots: ['calendar-d'], caption: 'Hijri dates from the\nmoon where you are',
   callouts: [['Islamic events', null], ['Prayer times', 'For any day, any city']]},
  {name: '04-stats', layout: 'tilt', shots: ['stats-l'], caption: 'Keep up your\ndaily recitation',
   callouts: [['Daily streaks', null], ['Zikrs, verses, qaza', null]]},
  {name: '05-listen', layout: 'tilt', shots: ['playlists-l'], caption: 'Listen to duas,\nor a whole playlist',
   callouts: [['Ready-made playlists', 'Morning, Thursday night, Ramazan'], ['Or make your own', null]]},
  {name: '06-tools', layout: 'fan', shots: ['qibla-d', 'tasbeeh-l'], caption: 'Qibla and tasbeeh,\nalways at hand'},
];

const TARGETS = [
  {dir: 'appstore/iphone-6.9', W: 1320, H: 2868, kind: 'iphone', set: [...PHONE, ...PHONE_EXTRA]},
  {dir: 'appstore/iphone-6.5', W: 1242, H: 2688, kind: 'iphone', set: [...PHONE, ...PHONE_EXTRA]},
  {dir: 'appstore/ipad-13', W: 2064, H: 2752, kind: 'tablet', set: TABLET},
  {dir: 'play/phone', W: 1080, H: 1920, kind: 'android', set: PHONE},
  {dir: 'play/tablet-7', W: 1200, H: 1920, kind: 'tablet', set: TABLET},
  {dir: 'play/tablet-10', W: 1600, H: 2560, kind: 'tablet', set: TABLET},
];

(async () => {
  const only = process.argv[2];
  const b = await launchBrowser();
  for (const t of TARGETS.filter((t) => !only || t.dir.includes(only))) {
    const pick = process.argv[3] ? process.argv[3].split(',') : null;
    for (const slide of t.set.filter((s) => !pick || pick.some((n) => s.name.startsWith(n)))) await render(b, slide, t, `${OUT_DIR}/${t.dir}/${slide.name}.png`);
  }
  if (!only || only === 'feature') await renderFeatureGraphic(b, `${OUT_DIR}/play/feature-graphic.png`);
  await b.close();
})();
