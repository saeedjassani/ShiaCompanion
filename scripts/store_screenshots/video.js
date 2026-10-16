'use strict';
// App preview video: real footage of the web build, scene by scene, cut
// together with captions into one 886x1920 H.264 file - the App Store's
// portrait size for 6.5" and 6.9" iPhones, and fine for a YouTube upload for
// Play's promo video.
//
// Each scene is recorded with Chrome's screencast, which hands over a frame
// whenever the page repaints. Frames are written with their own timestamps
// and resampled to a constant 30 fps by ffmpeg, so a slow repaint shows as a
// held frame instead of the clip running fast.
//
//   node video.js            record every scene, then cut
//   node video.js cut        re-cut from the scenes already recorded
const fs = require('fs');
const path = require('path');
const {execFileSync} = require('child_process');
const {launch, openApp} = require('./lib');
const {HERE, VENDOR} = require('./config');

const OUT = path.join(HERE, 'out', 'video');
const W = 886, H = 1920;
const VP = {width: 430, height: 932, dsf: W / 430};
const FPS = 30;
// The headless browser paints this app at ~12 fps. Scenes are acted out SLOW
// times slower than real time and sped back up in the cut, so motion is
// sampled finely enough for a smooth 30 fps. The cut then fits the whole
// video into TARGET seconds; the App Store allows 15 to 30.
const SLOW = 3;
const TARGET = 29.5;
const END_CARD = 2;

const tap = async (page, fx, fy, settle = 0) => {
  await page.touchscreen.tap(VP.width * fx, VP.height * fy);
  if (settle) await page.waitForTimeout(settle);
};
/**
 * A slow, even scroll: many small wheel steps rather than one jump. Each step
 * is one repaint, so in slow motion there are SLOW times as many, each
 * smaller, and [ms] is the scroll's length in the finished video's terms.
 */
async function glide(page, px, ms) {
  await page.mouse.move(VP.width / 2, VP.height * 0.55);
  const steps = Math.round(ms / 80 * SLOW);
  for (let i = 0; i < steps; i++) {
    await page.mouse.wheel(0, px / steps);
    await page.waitForTimeout(80 / SLOW);
  }
}
/** Turns the synthetic compass from [from] to [to] degrees over [ms]. */
async function swingCompass(page, from, to, ms) {
  await page.evaluate(([from, to, ms]) => {
    const start = performance.now();
    const fire = () => {
      const k = Math.min(1, (performance.now() - start) / ms);
      const a = from + (to - from) * (1 - Math.pow(1 - k, 3));
      for (const type of ['deviceorientationabsolute', 'deviceorientation']) {
        const e = new Event(type);
        Object.defineProperties(e, {
          absolute: {value: true}, alpha: {value: a}, beta: {value: 2}, gamma: {value: -1},
          webkitCompassHeading: {value: (360 - a) % 360}, webkitCompassAccuracy: {value: 10},
        });
        window.dispatchEvent(e);
      }
    };
    fire(); setInterval(fire, 60);
  }, [from, to, ms]);
}

// [name, caption, openApp options, setup before recording, what is recorded].
// Taps are viewport fractions of the phone layout (see capture.js).
const SCENES = [
  ['01-home', 'Prayer times, duas and Quran', {}, async (p) => tap(p, 0.5, 0.238, 15000),
    async (p) => { await p.waitForTimeout(1500); await glide(p, 260, 1200); await p.waitForTimeout(700); }],
  ['02-reader', 'Every dua, line by line', {route: '/dua-kumayl'}, async (p) => p.waitForTimeout(4000),
    async (p) => { await p.waitForTimeout(600); await glide(p, 1100, 3000); await p.waitForTimeout(400); }],
  ['03-listen', 'Listen along', {route: '/ziyarat-e-ameenullah', dark: true},
    async (p) => { await glide(p, 1600, 800); await p.waitForTimeout(2500); },
    async (p) => { await p.waitForTimeout(500); await tap(p, 0.318, 0.93); await p.waitForTimeout(3600); }],
  ['04-quran', 'The Quran, with your Khatm', {route: '/quran/36', dark: true}, async (p) => p.waitForTimeout(5000),
    async (p) => { await p.waitForTimeout(500); await glide(p, 700, 2200); await p.waitForTimeout(300); }],
  ['05-urdu', 'Now in Urdu, Persian, Arabic, Gujarati', {route: '/dua-kumayl', locale: 'ur'},
    async (p) => p.waitForTimeout(4000),
    async (p) => { await p.waitForTimeout(500); await glide(p, 800, 2400); await p.waitForTimeout(300); }],
  // With demo history Home gains a Continue card, so All features sits lower.
  ['06-stats', 'Keep up your daily recitation', {seed: true},
    async (p) => { await tap(p, 0.5, 0.238, 8000); await tap(p, 0.841, 0.886, 3500); },
    async (p) => { await tap(p, 0.484, 0.537); await p.waitForTimeout(2600); await glide(p, 300, 900); await p.waitForTimeout(300); }],
  ['07-qibla', 'Find the qibla anywhere', {dark: true},
    async (p) => { await tap(p, 0.5, 0.238, 8000); await tap(p, 0.612, 0.724, 5000); await swingCompass(p, 250, 250, 1); await p.waitForTimeout(1500); },
    async (p) => { await p.waitForTimeout(300); await swingCompass(p, 250, 341, 2000 * SLOW); await p.waitForTimeout(2400); }],
  ['08-tasbeeh', 'A tasbeeh that keeps count', {},
    async (p) => { await tap(p, 0.5, 0.238, 8000); await tap(p, 0.384, 0.724, 4000); },
    async (p) => { for (let i = 0; i < 12; i++) { await tap(p, 0.5, 0.54); await p.waitForTimeout(170); } await p.waitForTimeout(500); }],
];

async function record(browser, [name, , opts, setup, act]) {
  const {context, page} = await openApp(browser, {...VP, ...opts});
  await setup(page);
  const dir = path.join(OUT, 'frames', name);
  fs.rmSync(dir, {recursive: true, force: true});
  fs.mkdirSync(dir, {recursive: true});
  const cdp = await context.newCDPSession(page);
  const frames = [];
  cdp.on('Page.screencastFrame', async (f) => {
    frames.push({t: f.metadata.timestamp, data: f.data});
    await cdp.send('Page.screencastFrameAck', {sessionId: f.sessionId}).catch(() => {});
  });
  await cdp.send('Page.startScreencast', {format: 'jpeg', quality: 95, maxWidth: W, maxHeight: H});
  const t0 = Date.now() / 1000;
  // Every wait in the act, the glides' steps included, runs SLOW times longer.
  const wait = page.waitForTimeout.bind(page);
  page.waitForTimeout = (ms) => wait(ms * SLOW);
  await act(page);
  const t1 = Date.now() / 1000;
  await cdp.send('Page.stopScreencast');
  await context.close();
  // An ffconcat list: each frame held until the next one arrived.
  const list = ['ffconcat version 1.0'];
  const kept = frames.filter((f) => f.t >= t0 - 0.05);
  if (!kept.length && frames.length) kept.push({...frames[frames.length - 1], t: t0});
  kept.forEach((f, i) => {
    const file = `${String(i).padStart(5, '0')}.jpg`;
    fs.writeFileSync(path.join(dir, file), Buffer.from(f.data, 'base64'));
    const next = i + 1 < kept.length ? kept[i + 1].t : t1;
    list.push(`file ${file}`, `duration ${Math.max(0.001, next - Math.max(f.t, t0)).toFixed(4)}`);
  });
  list.push(`file ${String(kept.length - 1).padStart(5, '0')}.jpg`);
  fs.writeFileSync(path.join(dir, 'list.txt'), list.join('\n'));
  console.log('recorded', name, `${kept.length} frames over ${(t1 - t0).toFixed(1)}s`);
}

/** A caption pill as a transparent PNG, drawn by Chromium with Roboto. */
async function captionPng(browser, text, file) {
  const font = fs.readFileSync(path.join(VENDOR, 'fonts', 'roboto-latin-700-normal.woff2')).toString('base64');
  const ctx = await browser.newContext({viewport: {width: W, height: 200}});
  const p = await ctx.newPage();
  await p.setContent(`<style>@font-face{font-family:R;src:url(data:font/woff2;base64,${font})}
    body{margin:0;display:flex;justify-content:center;align-items:center;height:200px;background:transparent}
    div{font:700 44px R;color:#fff;background:rgba(58,34,26,.88);padding:26px 40px;border-radius:60px;
        box-shadow:0 10px 30px rgba(0,0,0,.3);max-width:780px;text-align:center}</style><div>${text}</div>`);
  await p.screenshot({path: file, omitBackground: true});
  await ctx.close();
}

/** Seconds of real time a recorded scene spans, from its ffconcat list. */
function recordedSeconds(name) {
  const list = fs.readFileSync(path.join(OUT, 'frames', name, 'list.txt'), 'utf8');
  return [...list.matchAll(/^duration (.+)$/gm)].reduce((a, m) => a + Number(m[1]), 0);
}

async function cut(browser) {
  const parts = [];
  // One speed for every scene, chosen so the cut, fades and end card included,
  // lands on TARGET seconds.
  const X = 0.3;
  const raw = SCENES.reduce((a, [name]) => a + recordedSeconds(name), 0);
  const speed = raw / (TARGET - END_CARD + X * SCENES.length);
  console.log(`scenes span ${raw.toFixed(1)}s; playing them ${speed.toFixed(2)}x`);
  for (const scene of SCENES) {
    const [name, caption] = scene;
    const dir = path.join(OUT, 'frames', name);
    const cap = path.join(OUT, `${name}-caption.png`);
    await captionPng(browser, caption, cap);
    const part = path.join(OUT, `${name}.mp4`);
    // Constant 30 fps; the caption fades in, sits at the lower third, fades out.
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error',
      '-f', 'concat', '-safe', '0', '-i', path.join(dir, 'list.txt'), '-loop', '1', '-i', cap,
      '-filter_complex',
      `[0:v]setpts=PTS/${speed.toFixed(4)},scale=${W}:${H}:flags=lanczos,fps=${FPS},format=yuv420p[v];` +
      `[1:v]format=rgba,fade=in:st=0.15:d=0.35:alpha=1[c];` +
      `[v][c]overlay=0:H*0.70:shortest=1,format=yuv420p[o]`,
      '-map', '[o]', '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-r', String(FPS), part]);
    parts.push(part);
  }
  // Brand end card from the app icon.
  const end = path.join(OUT, '99-end.png');
  const logo = fs.readFileSync(path.join(HERE, '..', '..', 'assets', 'logo.png')).toString('base64');
  const font = fs.readFileSync(path.join(VENDOR, 'fonts', 'roboto-latin-700-normal.woff2')).toString('base64');
  const ctx = await browser.newContext({viewport: {width: W, height: H}});
  const p = await ctx.newPage();
  await p.setContent(`<style>@font-face{font-family:R;src:url(data:font/woff2;base64,${font})}
    body{margin:0;width:${W}px;height:${H}px;display:flex;flex-direction:column;align-items:center;justify-content:center;
      background:linear-gradient(158deg,#a9755c 0%,#8a5a49 34%,#6b4238 68%,#4a2c24 100%);font-family:R;color:#fff}
    img{width:300px;border-radius:66px;box-shadow:0 30px 60px rgba(0,0,0,.35)}
    h1{font-size:72px;margin:56px 0 18px}p{font-size:38px;opacity:.85;margin:0}</style>
    <img src="data:image/png;base64,${logo}"><h1>Shia Companion</h1><p>Duas · Ziyarats · Quran · Prayer times</p>`);
  await p.screenshot({path: end});
  await ctx.close();
  const endMp4 = path.join(OUT, '99-end.mp4');
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-loop', '1', '-t', String(END_CARD), '-i', end,
    '-vf', `fps=${FPS},format=yuv420p`, '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', endMp4]);
  parts.push(endMp4);

  // Cross-fade every cut, then add the silent stereo AAC track the App Store
  // requires every preview to carry.
  const durs = parts.map((f) => Number(execFileSync('ffprobe', ['-v', 'error', '-show_entries',
    'format=duration', '-of', 'csv=p=0', f]).toString().trim()));
  let filter = '';
  let last = '[0:v]';
  let offset = 0;
  for (let i = 1; i < parts.length; i++) {
    offset += durs[i - 1] - X;
    const label = i === parts.length - 1 ? '[vout]' : `[x${i}]`;
    filter += `${last}[${i}:v]xfade=transition=fade:duration=${X}:offset=${offset.toFixed(3)}${label};`;
    last = label;
  }
  const total = durs.reduce((a, b) => a + b, 0) - X * (parts.length - 1);
  const final = path.join(OUT, 'app-preview-886x1920.mp4');
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', ...parts.flatMap((f) => ['-i', f]),
    '-f', 'lavfi', '-t', total.toFixed(3), '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
    '-filter_complex', filter.slice(0, -1),
    '-map', '[vout]', '-map', `${parts.length}:a`,
    '-c:v', 'libx264', '-profile:v', 'high', '-level', '4.0', '-preset', 'slow', '-crf', '16',
    '-pix_fmt', 'yuv420p', '-r', String(FPS), '-c:a', 'aac', '-b:a', '256k', '-movflags', '+faststart', final]);
  console.log('wrote', path.relative(process.cwd(), final), `${total.toFixed(1)}s`);
}

(async () => {
  const b = await launch();
  if (process.argv[2] !== 'cut') {
    const only = process.argv[2];
    for (const s of SCENES.filter((s) => !only || s[0].includes(only))) await record(b, s);
  }
  if (!process.argv[2] || process.argv[2] === 'cut') await cut(b);
  await b.close();
})();
