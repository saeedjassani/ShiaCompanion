// Thursday Home take — rec.js logic on Playwright's own Chromium.
const path = require('path');
const fs = require('fs');
const { chromium } = require('/home/hatch/workspace/promo325/capture/node_modules/playwright');
const FPS = 30;
const sleep = ms => new Promise(r => setTimeout(r, ms));
const SLOW = Number(process.env.SLOW || 6);
const GAP = Number(process.env.GAP || 0);
const TARGET = Date.UTC(2026, 9, 15, 19, 30, 0); // Thu Oct 15 2026, 20:30 London (BST)
const GRAB = `(() => {
  let c = window.__cv;
  if (!c || !c.isConnected) {
    const walk = root => root.querySelectorAll('*').forEach(e => { if (e.tagName === 'CANVAS' && !c) c = e; if (e.shadowRoot) walk(e.shadowRoot); });
    c = null; walk(document); window.__cv = c;
  }
  return c ? c.toDataURL('image/jpeg', 0.93).split(',')[1] : null;
})()`;
const WARP = `(() => {
  const pn = performance.now.bind(performance), dn = Date.now, st = setTimeout, si = setInterval, raf = requestAnimationFrame;
  const SHIFT = ${TARGET} - dn();
  let k = 1, r0 = pn(), v0 = r0;
  const virt = r => v0 + (r - r0) * k;
  window.__warp = nk => { const r = pn(); v0 = virt(r); r0 = r; k = nk; };
  const d0 = dn() - pn();
  performance.now = () => virt(pn());
  Date.now = () => Math.round(d0 + virt(pn())) + SHIFT;
  const RD = Date;
  function FakeDate(...a) { return a.length ? new RD(...a) : new RD(RD.now() + SHIFT); }
  FakeDate.now = Date.now; FakeDate.parse = RD.parse; FakeDate.UTC = RD.UTC;
  FakeDate.prototype = RD.prototype;
  window.Date = FakeDate;
  window.requestAnimationFrame = cb => raf(ts => cb(virt(ts)));
  window.setTimeout = (f, d, ...a) => st(f, (d || 0) / k, ...a);
  window.setInterval = (f, d, ...a) => si(f, (d || 0) / k, ...a);
})();`;
const ACTIONS = [
  { wait: 8500 }, { wheel: 750, ms: 1500 }, { wait: 2400 }, { wheel: -750, ms: 1200 },
  { wait: 300 }, { tap: [130, 440] }, { wait: 2100 }, { tap: [195, 300] }, { wait: 1600 },
];
async function run(p, a, K, onTap) {
  if (a.wait) return sleep(a.wait * K);
  if (a.tap) {
    onTap(...a.tap);
    await p.mouse.move(a.tap[0], a.tap[1]);
    await p.mouse.down(); await sleep(70 * K); await p.mouse.up();
    return;
  }
  if (a.type) { await p.keyboard.type(a.type, { delay: 150 }); return; }
  if (a.wheel !== undefined) {
    await p.mouse.move(195, 500);
    const steps = Math.max(1, Math.round((a.ms || 1000) / 16));
    for (let i = 0; i < steps; i++) {
      const f = x => 0.5 - Math.cos(Math.PI * x) / 2;
      await p.mouse.wheel(0, (f((i + 1) / steps) - f(i / steps)) * a.wheel);
      await sleep(16 * K);
    }
  }
}
(async () => {
  const b = await chromium.launch({ args: ['--ignore-certificate-errors', '--enable-unsafe-swiftshader'] });
  const ctx = await b.newContext({ ignoreHTTPSErrors: true, viewport: { width: 390, height: 844 }, deviceScaleFactor: 2.3,
    geolocation: { latitude: 51.5072, longitude: -0.1276 }, permissions: ['geolocation'], timezoneId: 'Europe/London' });

  const fsx = require('fs'), pathx = require('path');
  const { execFile } = require('child_process');
  const EXT = '/home/hatch/workspace/promo325/webbuild_ext';
  const mirror = async (route, urlStr) => {
    const u = new URL(urlStr);
    const local = pathx.join(EXT, u.hostname, decodeURIComponent(u.pathname));
    if (!fsx.existsSync(local)) {
      fsx.mkdirSync(pathx.dirname(local), { recursive: true });
      await new Promise(res => execFile('curl', ['-sf', '-o', local, urlStr], () => res()));
    }
    if (fsx.existsSync(local)) {
      const ct = local.endsWith('.wasm') ? 'application/wasm' : local.endsWith('.js') ? 'application/javascript'
        : local.endsWith('.woff2') ? 'font/woff2' : local.endsWith('.json') ? 'application/json' : 'application/octet-stream';
      await route.fulfill({ status: 200, contentType: ct, body: fsx.readFileSync(local) });
    } else await route.continue();
  };
  const CK = '/home/hatch/workspace/promo325/webbuild/canvaskit';
  await ctx.route('**://www.gstatic.com/flutter-canvaskit/**', route => {
    const u = new URL(route.request().url());
    const rest = decodeURIComponent(u.pathname.split('/').slice(3).join('/'));
    const local = pathx.join(CK, rest);
    if (fsx.existsSync(local)) {
      route.fulfill({ status: 200, contentType: rest.endsWith('.wasm') ? 'application/wasm' : 'application/javascript', body: fsx.readFileSync(local) });
    } else mirror(route, route.request().url());
  });
  await ctx.route('**://www.gstatic.com/firebasejs/**', r => mirror(r, r.request().url()));
  await ctx.route('**://fonts.gstatic.com/**', r => mirror(r, r.request().url()));
  await ctx.route('**://fonts.googleapis.com/**', r => mirror(r, r.request().url()));
  await ctx.route('**://accounts.google.com/gsi/**', r => mirror(r, r.request().url()));
  const p = await ctx.newPage();
  await p.addInitScript(WARP);
  await p.addInitScript(es => es.forEach(([k, v]) => localStorage.setItem(k, v)), require('/home/hatch/workspace/promo325/demo_data.js').seedEntries(['quran', 'book']));
  await p.emulateMedia({ colorScheme: 'dark' });
  await p.goto('http://127.0.0.1:4173/');
  await p.waitForSelector('#app-loading', { state: 'detached', timeout: 60000 }).catch(() => {});
  await sleep(7000);
  await p.evaluate(k => window.__warp(k), 1 / SLOW);
  await sleep(400 * SLOW);
  const CITY_SETUP = [
    { tap: [195, 242] }, { wait: 3000 },
    { tap: [152, 79] }, { wait: 3000 },
    { tap: [195, 157] }, { wait: 1500 },
    { type: 'Toronto' }, { wait: 3000 },
    { tap: [150, 296] }, { wait: 4000 },
    { tap: [195, 524] }, { wait: 4000 },
  ];
  for (const a of CITY_SETUP) await run(p, a, SLOW, () => {});
  await p.mouse.move(170, 28);
  await sleep(1200);
  const frames = [];
  let recording = true;
  const grabber = (async () => {
    while (recording) {
      const ts = Date.now() / 1000;
      const data = await p.evaluate(GRAB).catch(() => null);
      if (data) frames.push({ ts: (ts + Date.now() / 1000) / 2, data });
      await sleep(GAP);
    }
  })();
  await p.evaluate(k => window.__warp(k), 1 / SLOW);
  await sleep(400 * SLOW);
  const t0 = Date.now() / 1000;
  const taps = [];
  for (const a of ACTIONS) await run(p, a, SLOW, (x, y) => taps.push({ t: Date.now() / 1000 - t0, x, y }));
  const t1 = Date.now() / 1000;
  recording = false;
  await grabber;
  const w = t => t0 + (t - t0) / SLOW;
  frames.forEach(f => { f.ts = w(f.ts); });
  taps.forEach(tp => { tp.t /= SLOW; });
  const t1w = w(t1);
  const dir = '/home/hatch/workspace/promo325/clips2/home_toronto';
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
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
  fs.writeFileSync(path.join(dir, 'taps.json'), JSON.stringify({ frames: Math.round((t1w - t0) * FPS), captured: frames.length, taps }, null, 1));
  console.log('home-thu take seconds', (t1w - t0).toFixed(2), 'captured', frames.length, 'kept', kept.length, 'taps', JSON.stringify(taps));
  await b.close();
})().catch(e => { console.error('FAIL', e.message); process.exit(1); });
