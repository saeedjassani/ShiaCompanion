// Records a live interaction with the Flutter web build as a frame sequence.
// usage: node rec.js <outDir> <clipsJson>
//   clip: {name, path, actions:[...]}, action one of
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

(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: ['--ignore-certificate-errors'] });
  for (const clip of clips) {
    const ctx = await b.newContext({ ignoreHTTPSErrors: true, viewport: { width: 390, height: 844 }, deviceScaleFactor: 2,
      geolocation: { latitude: 51.5072, longitude: -0.1276 }, permissions: ['geolocation'], timezoneId: 'Europe/London' });
    const p = await ctx.newPage();
    await p.goto('http://127.0.0.1:4173' + (clip.path || '/'));
    await p.waitForSelector('#app-loading', { state: 'detached', timeout: 60000 }).catch(() => {});
    await sleep(clip.settle || 7000);
    for (const a of clip.setup || []) await run(p, a, () => {});
    await p.mouse.move(170, 28);
    await sleep(1200);

    // Grab full-resolution (DPR 2) screenshots back to back while the actions run.
    // The CDP screencast would be faster but only delivers CSS-pixel (390px) frames.
    const cdp = await ctx.newCDPSession(p);
    const frames = [];
    let recording = true;
    const grabber = (async () => {
      while (recording) {
        const ts = Date.now() / 1000;
        const { data } = await cdp.send('Page.captureScreenshot', { format: 'jpeg', quality: 92 });
        frames.push({ ts: (ts + Date.now() / 1000) / 2, data });
      }
    })();
    await sleep(400);
    const t0 = Date.now() / 1000;
    const taps = [];
    for (const a of clip.actions) await run(p, a, (x, y) => taps.push({ t: Date.now() / 1000 - t0, x, y }));
    const t1 = Date.now() / 1000;
    recording = false;
    await grabber;

    const dir = path.join(outDir, clip.name);
    fs.rmSync(dir, { recursive: true, force: true });
    fs.mkdirSync(dir, { recursive: true });
    // Keep every captured frame with how long it stayed on screen; interp.py then
    // motion-interpolates them to a constant 30 fps (headless Flutter animates at ~12-25 fps).
    const n = Math.round((t1 - t0) * FPS);
    const before = frames.filter(f => f.ts <= t0);
    const kept = [before.length ? before[before.length - 1] : frames[0], ...frames.filter(f => f.ts > t0 && f.ts < t1)];
    const list = [];
    kept.forEach((f, i) => {
      const name = 'raw_' + String(i).padStart(4, '0') + '.jpg';
      fs.writeFileSync(path.join(dir, name), Buffer.from(f.data, 'base64'));
      const start = i === 0 ? t0 : f.ts;
      const end = i + 1 < kept.length ? kept[i + 1].ts : t1;
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

async function run(p, a, onTap) {
  if (a.reload && !a.url) a.url = p.url();
  if (a.wait) return sleep(a.wait);
  if (a.reload) {
    await p.goto(a.url);
    await p.waitForSelector('#app-loading', { state: 'detached', timeout: 60000 }).catch(() => {});
    return sleep(a.reload);
  }
  if (a.move) return p.mouse.move(...a.move);
  if (a.tap) {
    onTap(...a.tap);
    await p.mouse.move(...a.tap);
    await p.mouse.down(); await sleep(70); await p.mouse.up();
    return;
  }
  if (a.wheel !== undefined) {
    await p.mouse.move(195, 500);
    const steps = Math.max(1, Math.round((a.ms || 1000) / 16));
    for (let i = 0; i < steps; i++) {
      // ease-in-out distribution of the scroll distance
      const f = x => 0.5 - Math.cos(Math.PI * x) / 2;
      const d = (f((i + 1) / steps) - f(i / steps)) * a.wheel;
      await p.mouse.wheel(0, d);
      await sleep(16);
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
      await sleep(16);
    }
    await p.mouse.up();
  }
}
