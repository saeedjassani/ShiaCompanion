'use strict';
const fs = require('fs');
const path = require('path');
const {chromium} = require('playwright');
const {VENDOR, CHROME_PATH, PORT, GEO, TIMEZONE} = require('./config');
const {statsSeed, quranSeed, qazaSeed} = require('./demo_data');

const FB_OUT = path.join(VENDOR, 'firebase');
const FONT_DIR = path.join(VENDOR, 'fonts');

// The Firebase JS SDK is fetched from gstatic.com, which this environment's
// proxy blocks. Serve the identical version (12.14.0) built from npm instead,
// as one esbuild bundle with shared chunks so the firebase app singleton is
// shared across modules the way the CDN build shares it.
async function routeFirebase(context) {
  await context.route('https://www.gstatic.com/firebasejs/**', async (route) => {
    const file = path.join(FB_OUT, path.basename(new URL(route.request().url()).pathname));
    if (fs.existsSync(file)) {
      return route.fulfill({status: 200, contentType: 'text/javascript; charset=utf-8', body: fs.readFileSync(file)});
    }
    return route.fulfill({status: 200, contentType: 'text/javascript; charset=utf-8', body: 'export {};'});
  });
  // Same blocked CDN, and Roboto is the default face for every Latin string in
  // the app: without it the UI paints icons and no text at all. Serve the same
  // family from npm, picking the weight out of the Google Fonts URL.
  const ROBOTO_DIR = FONT_DIR;
  const ROBOTO_WEIGHTS = new Map([
    ['KFOmCnqEu92Fr1Me4GZLCzYlKw', '400'],
    ['KFOlCnqEu92Fr1MmEU9fBBc-', '500'],
    ['KFOlCnqEu92Fr1MmWUlfBBc-', '700'],
    ['KFOlCnqEu92Fr1MmSU5fBBc-', '300'],
  ]);
  const seenFonts = new Set();
  await context.route('https://fonts.gstatic.com/**', async (route) => {
    const url = route.request().url();
    // Flutter also pulls a Noto fallback for any script Roboto lacks — the
    // Arabic-Indic digits in the calendar are the visible case. Serving Roboto
    // for those requests is what renders them as tofu.
    let file;
    if (url.includes('notosansarabic')) {
      file = path.join(FONT_DIR, 'noto-sans-arabic-arabic-400-normal.woff2');
    } else if (url.includes('notosansgujarati')) {
      // The Gujarati UI's fallback. Without it every Gujarati string is tofu.
      file = path.join(FONT_DIR, 'noto-sans-gujarati-gujarati-400-normal.woff2');
    } else {
      const key = [...ROBOTO_WEIGHTS.keys()].find((k) => url.includes(k));
      if (!key) { seenFonts.add(url); if (process.env.DEBUG_FONTS) console.log('font?', url); }
      const weight = key ? ROBOTO_WEIGHTS.get(key) : '400';
      file = path.join(ROBOTO_DIR, `roboto-latin-${weight}-normal.woff2`);
    }
    if (!fs.existsSync(file)) return route.abort();
    return route.fulfill({status: 200, contentType: 'font/woff2', body: fs.readFileSync(file)});
  });
  context.unmatchedFontUrls = seenFonts;
  await context.route('https://accounts.google.com/**', (route) => route.abort());
  // Recitation audio streams from duas.org, which is unreachable from here.
  // Serve a local silent track of a plausible length so the player shows its
  // real loaded state - duration, scrubber, transport - instead of an error.
  await context.route('**mp3.duas.org/**', (route) => route.fulfill({
    status: 200,
    headers: {'Accept-Ranges': 'bytes', 'Content-Type': 'audio/wav'},
    body: fs.readFileSync(path.join(VENDOR, 'recitation.wav')),
  }));
}

async function launch() {
  return chromium.launch({
    executablePath: CHROME_PATH,
    args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--force-color-profile=srgb',
           '--font-render-hinting=none', '--hide-scrollbars'],
  });
}

async function openApp(browser, {width, height, dsf = 3, isMobile = true, route = '/', dark = false,
                                 locale = 'en-US', seed = false}) {
  const context = await browser.newContext({
    viewport: {width, height},
    deviceScaleFactor: dsf,
    isMobile,
    hasTouch: true,
    geolocation: GEO,
    permissions: ['geolocation'],
    // The app follows the device language until one is picked in Settings.
    locale,
    timezoneId: TIMEZONE,
    colorScheme: dark ? 'dark' : 'light',
    reducedMotion: 'reduce',
  });
  await routeFirebase(context);
  const page = await context.newPage();
  if (seed) {
    // shared_preferences on the web keeps each value JSON-encoded under a
    // `flutter.` prefix, and these two values are themselves JSON strings.
    const enc = (o) => JSON.stringify(JSON.stringify(o));
    await page.addInitScript(([stats, quran, qaza]) => {
      localStorage.setItem('flutter.activity_stats_own_v1', stats);
      localStorage.setItem('flutter.recitation_tracker_guest', quran);
      localStorage.setItem('flutter.qaza_tracker_guest', qaza);
    }, [enc(statsSeed()), enc(quranSeed()), enc(qazaSeed())]);
  }
  await page.goto(`http://127.0.0.1:${PORT}` + route, {waitUntil: 'domcontentloaded'});
  await page.waitForSelector('#app-loading', {state: 'detached', timeout: 120000});
  // First frame is not the settled frame: fonts, the hadith fetch and the
  // prayer-time calculation all land after it.
  await page.waitForTimeout(9000);
  return {context, page};
}

// Flutter paints to a canvas, so nothing inside the app is addressable as DOM.
// Taps go by fraction of the viewport, which is stable for a given layout.
async function tap(page, fx, fy, settle = 2600) {
  const vp = page.viewportSize();
  await page.mouse.click(Math.round(vp.width * fx), Math.round(vp.height * fy));
  await page.waitForTimeout(settle);
}

module.exports = {launch, openApp, tap, routeFirebase};
