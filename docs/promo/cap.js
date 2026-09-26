const { chromium } = require(require('path').join(__dirname, '../../test_visual/node_modules/playwright'));
const out = process.argv[2];
const plan = JSON.parse(process.argv[3]);   // [{name, path, taps:[[x,y],..], scroll, wait}]
(async () => {
  const b = await chromium.launch({executablePath: process.env.CHROMIUM_PATH || undefined, args:['--ignore-certificate-errors']});
  const ctx = await b.newContext({ ignoreHTTPSErrors: true, viewport: { width: 390, height: 844 }, deviceScaleFactor: 2,
    geolocation: { latitude: 51.5072, longitude: -0.1276 }, permissions: ['geolocation'], timezoneId: 'Europe/London' });
  for (const s of plan) {
    const p = await ctx.newPage();
    await p.goto('http://127.0.0.1:4173' + (s.path || '/'));
    await p.waitForSelector('#app-loading', {state:'detached', timeout: 60000}).catch(()=>{});
    await p.waitForTimeout(s.wait || 5000);
    for (const t of (s.taps || [])) {
      if (t[0] === 'scroll') { await p.mouse.move(195, 600); await p.mouse.wheel(0, t[1]); }
      else if (t[0] === 'key') { await p.keyboard.type(t[1]); }
      else await p.mouse.click(t[0], t[1]);
      await p.waitForTimeout(t[2] || 2500);
    }
    await p.mouse.move(170, 28); await p.waitForTimeout(1800);
    await p.screenshot({ path: `${out}/${s.name}.png` });
    await p.close();
  }
  await b.close();
})();
