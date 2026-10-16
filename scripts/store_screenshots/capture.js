'use strict';
// Drives the web build to every screen the 4.0 store listing shows and saves
// raw captures to RAW_DIR as `<device>-<name>.png` (p = phone, t = tablet).
// `node capture.js p` or `node capture.js t` captures one device only, and a
// comma-separated list after it (`node capture.js p stats-l,qaza-d`) only those.
const {launch, openApp, tapF: tapAt, shot} = require('./flow');

const PHONE = {width: 430, height: 932};
const TABLET = {width: 1024, height: 1366, dsf: 2, isMobile: false};

// Tap targets as viewport fractions, per layout. Home's own grid on the phone,
// All features' grid for what Home does not show.
const P = {
  useLocation: [0.5, 0.238], quranTab: [0.415, 0.943], allFeatures: [0.837, 0.724],
  // With demo history, Home gains a Continue card and its grid moves down.
  allFeaturesSeeded: [0.841, 0.886],
  feature: {
    playlists: [0.205, 0.537], stats: [0.484, 0.537], qibla: [0.75, 0.537],
    tasbeeh: [0.205, 0.64], qaza: [0.484, 0.64], calendar: [0.75, 0.33],
    library: [0.205, 0.433], flight: [0.849, 0.64],
  },
  playFirstPlaylist: [0.124, 0.243], listen: [0.318, 0.93], counterTap: [0.5, 0.54],
};
// The tablet's Home grid already holds every feature, so there is no All
// features step (allFeatures: null).
const T = {
  useLocation: [0.273, 0.178], quranTab: [0.463, 0.958], allFeatures: null, allFeaturesSeeded: null,
  feature: {
    playlists: [0.603, 0.268], stats: [0.81, 0.268], qibla: [0.81, 0.205],
    tasbeeh: [0.706, 0.205], qaza: [0.915, 0.205], calendar: [0.603, 0.205],
  },
  playFirstPlaylist: [0.06, 0.2], listen: [0.4, 0.955], counterTap: [0.5, 0.5],
};
if (process.env.TABLET_TAPS) Object.assign(T, JSON.parse(process.env.TABLET_TAPS));

// Synthetic DeviceOrientation events: exactly what an Android magnetometer
// emits. The bearing, distance and turn instruction are the app's own maths.
async function driveCompass(page, alpha = 341) {
  await page.evaluate((a) => {
    window.__t && clearInterval(window.__t);
    const fire = () => {
      for (const type of ['deviceorientationabsolute', 'deviceorientation']) {
        const e = new Event(type);
        Object.defineProperties(e, {
          absolute: {value: true}, alpha: {value: a}, beta: {value: 2}, gamma: {value: -1},
          webkitCompassHeading: {value: (360 - a) % 360}, webkitCompassAccuracy: {value: 10},
        });
        window.dispatchEvent(e);
      }
    };
    fire(); window.__t = setInterval(fire, 120);
  }, alpha);
  await page.waitForTimeout(2600);
}

async function scrollReader(page, vp, down) {
  await page.mouse.move(vp.width / 2, vp.height * 0.55);
  await page.mouse.wheel(0, down); await page.waitForTimeout(1500);
  await page.mouse.wheel(0, -240); await page.waitForTimeout(2600);
}

// STORE_LANG=ur (or ar, fa, gu) captures a localized set into RAW_DIR: the
// app in that language, with Arabic-script layouts mirrored, so every tap's x
// is mirrored too. The English-only shots are skipped.
const LANG = process.env.STORE_LANG;
const RTL = ['ar', 'ur', 'fa'].includes(LANG);
const LOCALIZED = ['home-l', 'home-d', 'read-l', 'read-d', 'ashura-d', 'player-d', 'quran-d',
                   'playlists-l', 'stats-l', 'calendar-d', 'qibla-d', 'tasbeeh-l', 'qaza-d'];

async function run(b, vp, k, p, shots) {
  const tapF = (page, fx, fy, settle) => tapAt(page, RTL ? 1 - fx : fx, fy, settle);
  const go = async (name, opts, steps) => {
    if (shots && !shots.includes(name)) return;
    if (LANG && !LOCALIZED.includes(name)) return;
    const {context, page} = await openApp(b, {...vp, seed: true, ...(LANG && {locale: LANG}), ...opts});
    await steps(page);
    await shot(page, `${p}-${name}`);
    await context.close();
  };
  // Home with a location fix, in both themes and in every UI language.
  for (const [name, opts] of [
    ['home-l', {}], ['home-d', {dark: true}],
    ['home-ur', {locale: 'ur'}], ['home-fa', {locale: 'fa'}],
    ['home-ar', {locale: 'ar'}], ['home-gu', {locale: 'gu'}],
  ]) {
    await go(name, opts, (page) => tapF(page, ...k.useLocation, 9000));
  }
  // The reader, scrolled well into the verses.
  await go('read-l', {route: '/dua-kumayl'}, (page) => scrollReader(page, vp, 2600));
  await go('read-ur-d', {route: '/dua-kumayl', locale: 'ur', dark: true},
    (page) => scrollReader(page, vp, 2600));
  // Localized sets only: Kumayl in dark, and Ziyarat Ashura for the languages
  // with no dua translations.
  await go('read-d', {route: '/dua-kumayl', dark: true}, (page) => scrollReader(page, vp, 2600));
  await go('ashura-d', {route: '/ziyarat-e-ashura', dark: true}, (page) => scrollReader(page, vp, 1400));
  // The audio player, mid-playback.
  await go('player-d', {route: '/ziyarat-e-ameenullah', dark: true}, async (page) => {
    await scrollReader(page, vp, 2200);
    await tapF(page, ...k.listen, 9000);
  });
  await go('quran-d', {route: '/quran/36', dark: true}, (page) => page.waitForTimeout(5000));
  await go('qurantab-l', {}, async (page) => {
    await tapF(page, ...k.useLocation, 8000);
    await tapF(page, ...k.quranTab, 5000);
  });
  // Everything else is reached from All features. Only My Stats needs the
  // demo history; the rest open from a plain Home.
  const feature = (name, opts, after) => go(name, {seed: false, ...opts}, async (page) => {
    await tapF(page, ...k.useLocation, 8000);
    const all = opts.seed ? k.allFeaturesSeeded : k.allFeatures;
    if (all) await tapF(page, ...all, 3500);
    await tapF(page, ...k.feature[name.split('-')[0]], 6000);
    if (after) await after(page);
  });
  await feature('playlists-l', {}, (page) => tapF(page, ...k.playFirstPlaylist, 8000));
  await feature('stats-l', {seed: true});
  await feature('calendar-d', {dark: true});
  await feature('qibla-d', {dark: true}, driveCompass);
  await feature('tasbeeh-l', {}, async (page) => {
    for (let i = 0; i < 33; i++) {
      await page.touchscreen.tap(vp.width * k.counterTap[0], vp.height * k.counterTap[1]);
    }
    await page.waitForTimeout(2500);
  });
  await feature('qaza-d', {dark: true, seed: true});
  if (k.feature.library) await feature('library-l', {});
  if (k.feature.flight) await feature('flight-l', {});
}

(async () => {
  const only = process.argv[2];
  const b = await launch();
  const shots = process.argv[3] ? process.argv[3].split(',') : null;
  if (!only || only === 'p') await run(b, PHONE, P, 'p', shots);
  if (!only || only === 't') await run(b, TABLET, T, 't', shots);
  await b.close();
})();
