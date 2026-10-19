const { chromium } = require('/home/hatch/workspace/v7/pr325x/ShiaCompanion-claude-stoic-cannon-63w6pp/test_visual/node_modules/playwright');
const { spawn } = require('child_process');
const [,, html, t0s, t1s, out] = process.argv;
const T0 = parseFloat(t0s), T1 = parseFloat(t1s), FPS = 30;
(async () => {
  const b = await chromium.launch({ args: ['--ignore-certificate-errors', '--allow-file-access-from-files'] });
  const p = await b.newPage({ ignoreHTTPSErrors: true, viewport: { width: 1080, height: 1920 } });
  await p.goto('file://' + html);
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(1500);
  const stage = await p.$('#stage');
  const ff = spawn('ffmpeg', ['-y', '-f', 'image2pipe', '-framerate', String(FPS), '-i', '-',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '16', '-preset', 'medium', '-movflags', '+faststart', out],
    { stdio: ['pipe', 'ignore', 'inherit'] });
  const n = Math.round((T1 - T0) * FPS);
  for (let f = 0; f < n; f++) {
    await p.evaluate(t => render(t), T0 + f / FPS);
    const buf = await stage.screenshot({ type: 'jpeg', quality: 95 });
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
  }
  ff.stdin.end();
  await new Promise(r => ff.on('close', r));
  await b.close();
  console.log('rendered', n, 'frames ->', out);
})();
