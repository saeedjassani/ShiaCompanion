'use strict';
const {render, chromium, CHROME} = require('./frame');
const {RAW_DIR, OUT_DIR} = require('./config');
const RAW = RAW_DIR;
const OUT = OUT_DIR;

// Ordered by what earns the install, not by what shipped most recently:
// what the app is, then its core content, then the differentiator.
const CORE = [
  ['01-home',    'Prayer times, duas and ziyarats in one app'],
  ['02-reading', 'Arabic, transliteration and translation'],
  ['03-player',  'Listen to any dua or ziyarat'],
  ['04-qibla',   'Find the qibla wherever you are'],
  ['05-calendar','Accurate prayer times and the Hijri calendar'],
  ['06-library', 'A library of Islamic books'],
  ['07-qaza',    'Track and clear your qaza prayers'],
  ['08-tasbeeh', 'A tasbeeh counter that keeps your count'],
];
// The App Store allows ten; Play caps at eight.
const EXTRA = [
  ['09-focus', 'Focus mode leaves nothing but the text'],
  ['10-tabs',  'Multi-part duas, neatly tabbed'],
];

const TARGETS = [
  {dir: 'play/phone',          W: 1080, H: 1920, pre: 'd',  device: 'phone',  set: CORE},
  {dir: 'play/tablet-7',       W: 1200, H: 1920, pre: 'dt', device: 'tablet', set: CORE},
  {dir: 'play/tablet-10',      W: 1600, H: 2560, pre: 'dt', device: 'tablet', set: CORE},
  {dir: 'appstore/iphone-6.9', W: 1320, H: 2868, pre: 'd',  device: 'phone',  set: [...CORE, ...EXTRA]},
  {dir: 'appstore/iphone-6.5', W: 1242, H: 2688, pre: 'd',  device: 'phone',  set: [...CORE, ...EXTRA]},
  {dir: 'appstore/ipad-13',    W: 2064, H: 2752, pre: 'dt', device: 'tablet', set: [...CORE, ...EXTRA]},
];

(async () => {
  const b = await chromium.launch({executablePath: CHROME});
  for (const t of TARGETS) {
    for (const [name, caption] of t.set) {
      await render(b, {
        src: `${RAW}/${t.pre}-${name}.png`,
        out: `${OUT}/${t.dir}/${name}.png`,
        caption, badge: null,
        W: t.W, H: t.H, device: t.device, theme: 'brand',
      });
    }
  }
  await b.close();
})();
