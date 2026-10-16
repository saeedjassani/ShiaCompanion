// Records a live interaction with the Flutter web build as a frame sequence.
// usage: node rec.js <outDir> <clipsJson>
//   clip: {name, path, seed?, actions:[...]} (seed: demo Quran reading history), action one of
//     {wait:ms} {reload:settleMs, url} {tap:[x,y]} {wheel:dy, ms} {drag:[x1,y1,x2,y2], ms} {move:[x,y]}
// Each clip runs in a fresh browser context, so app preferences start at defaults.
// Output: <outDir>/<name>/raw_NNNN.jpg + frames.txt (ffconcat timings) + taps.json ({t, x, y} in seconds / logical px).
const path = require('path');
const fs = require('fs');
const { chromium } = require(path.join(__dirname, '../../test_visual/node_modules/playwright'));
const FPS = 30;
const [,, outDir, clipsJson] = process.argv;
const clips = JSON.parse(fs.readFileSync(clipsJson, 'utf8'));
const sleep = ms => new Promise(r => setTimeout(r, ms));
// Headless Chromium repaints Flutter at ~8-12 fps, too few for smooth motion.
// So the app's clock is slowed SLOW times while a clip records: performance.now,
// Date.now, rAF timestamps and timers all run slow, every animation plays in
// slow motion and gets SLOW times as many frames, and the clip is written back
// at real speed. The actions' waits and glides are stretched to match.
const GRAB = `(() => {
  let c = window.__cv;
  if (!c || !c.isConnected) {
    const walk = root => root.querySelectorAll('*').forEach(e => { if (e.tagName === 'CANVAS' && !c) c = e; if (e.shadowRoot) walk(e.shadowRoot); });
    c = null; walk(document); window.__cv = c;
  }
  return c.toDataURL('image/jpeg', 0.93).split(',')[1];
})()`;
const SLOW = Number(process.env.SLOW || 6);
const GAP = Number(process.env.GAP || 0);   // ms between captures, so the app gets time to paint
const WARP = `(() => {
  const pn = performance.now.bind(performance), dn = Date.now, st = setTimeout, si = setInterval, raf = requestAnimationFrame;
  let k = 1, r0 = pn(), v0 = r0;
  const virt = r => v0 + (r - r0) * k;
  window.__warp = nk => { const r = pn(); v0 = virt(r); r0 = r; k = nk; };
  const d0 = dn() - pn();
  performance.now = () => virt(pn());
  Date.now = () => Math.round(d0 + virt(pn()));
  window.requestAnimationFrame = cb => raf(ts => cb(virt(ts)));
  window.setTimeout = (f, d, ...a) => st(f, (d || 0) / k, ...a);
  window.setInterval = (f, d, ...a) => si(f, (d || 0) / k, ...a);
})();`;

(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: ['--ignore-certificate-errors'] });
  for (const clip of clips) {
    const ctx = await b.newContext({ ignoreHTTPSErrors: true, viewport: { width: 390, height: 844 }, deviceScaleFactor: 2.3,
      geolocation: { latitude: 51.5072, longitude: -0.1276 }, permissions: ['geolocation'], timezoneId: 'Europe/London' });
    const p = await ctx.newPage();
    await p.addInitScript(WARP);
    // shared_preferences on the web keeps each value JSON-encoded under a
    // `flutter.` prefix, and this value is itself a JSON string.
    if (clip.seed) await p.addInitScript(v => localStorage.setItem('flutter.recitation_tracker_guest', v),
      JSON.stringify(JSON.stringify(require('./demo_data').quranSeed())));
    await p.goto('http://127.0.0.1:4173' + (clip.path || '/'));
    await p.waitForSelector('#app-loading', { state: 'detached', timeout: 60000 }).catch(() => {});
    await sleep(clip.settle || 7000);
    for (const a of clip.setup || []) await run(p, a, 1, () => {});
    await p.mouse.move(170, 28);
    await sleep(1200);

    // Read Flutter's own canvas back to back while the actions run: it is already
    // at full resolution (DPR 2.3, 897x1941) and takes ~30 ms. Browser screenshots
    // either come back at CSS pixels (390 wide) or stall the app's painting.
    const frames = [];
    let recording = true;
    const grabber = (async () => {
      while (recording) {
        const ts = Date.now() / 1000;
        const data = await p.evaluate(GRAB);
        frames.push({ ts: (ts + Date.now() / 1000) / 2, data });
        await sleep(GAP);
      }
    })();
    await p.evaluate(k => window.__warp(k), 1 / SLOW);
    await sleep(400 * SLOW);
    const t0 = Date.now() / 1000;
    const taps = [];
    for (const a of clip.actions) await run(p, a, SLOW, (x, y) => taps.push({ t: Date.now() / 1000 - t0, x, y }));
    const t1 = Date.now() / 1000;
    recording = false;
    await grabber;
    // back to real time: everything below is in app (slowed) seconds
    const w = t => t0 + (t - t0) / SLOW;
    frames.forEach(f => { f.ts = w(f.ts); });
    taps.forEach(tp => { tp.t /= SLOW; });
    const t1w = w(t1);

    const dir = path.join(outDir, clip.name);
    fs.rmSync(dir, { recursive: true, force: true });
    fs.mkdirSync(dir, { recursive: true });
    // Keep every captured frame with how long it stayed on screen; interp.py then
    // motion-interpolates them to a constant 30 fps (headless Flutter animates at ~12-25 fps).
    const n = Math.round((t1w - t0) * FPS);
    const before = frames.filter(f => f.ts <= t0);
    const kept = [before.length ? before[before.length - 1] : frames[0], ...frames.filter(f => f.ts > t0 && f.ts < t1w)];
    const list = [];
    kept.forEach((f, i) => {
      const name = 'raw_' + String(i).padStart(4, '0') + '.jpg';
      fs.writeFileSync(path.join(dir, name), Buffer.from(f.data, 'base64'));
      const start = i === 0 ? t0 : f.ts;
      const end = i + 1 < kept.length ? kept[i + 1].ts : t1w;
      list.push(`file '${name}'\nduration ${Math.max(0.001, end - start).toFixed(4)}`);
    });
    list.push(`file 'raw_${String(kept.length - 1).padStart(4, '0')}.jpg'`);
    fs.writeFileSync(path.join(dir, 'frames.txt'), list.join('\n') + '\n');
    fs.writeFileSync(path.join(dir, 'taps.json'), JSON.stringify({ frames: n, captured: frames.length, taps }, null, 1));
    console.log(clip.name, 'frames', n, 'captured', frames.length, 'taps', taps.length);
    await ctx.close();
  }
  await b.close();
})();

async function run(p, a, K, onTap) {
  if (a.reload && !a.url) a.url = p.url();
  if (a.wait) return sleep(a.wait * K);
  if (a.reload) {
    await p.goto(a.url);
    await p.waitForSelector('#app-loading', { state: 'detached', timeout: 60000 }).catch(() => {});
    return sleep(a.reload);
  }
  if (a.move) return p.mouse.move(...a.move);
  if (a.tap) {
    onTap(...a.tap);
    await p.mouse.move(...a.tap);
    await p.mouse.down(); await sleep(70 * K); await p.mouse.up();
    return;
  }
  if (a.wheel !== undefined) {
    await p.mouse.move(195, 500);
    const steps = Math.max(1, Math.round((a.ms || 1000) / 16));
    const dt = 16 * K;
    for (let i = 0; i < steps; i++) {
      // ease-in-out distribution of the scroll distance
      const f = x => 0.5 - Math.cos(Math.PI * x) / 2;
      const d = (f((i + 1) / steps) - f(i / steps)) * a.wheel;
      await p.mouse.wheel(0, d);
      await sleep(dt);
    }
    return;
  }
  if (a.drag) {
    const [x1, y1, x2, y2] = a.drag;
    onTap(x1, y1);
    await p.mouse.move(x1, y1); await p.mouse.down();
    const steps = Math.max(1, Math.round((a.ms || 600) / 16));
    for (let i = 1; i <= steps; i++) {
      const f = 0.5 - Math.cos(Math.PI * i / steps) / 2;
      await p.mouse.move(x1 + (x2 - x1) * f, y1 + (y2 - y1) * f);
      await sleep(16 * K);
    }
    await p.mouse.up();
  }
}
