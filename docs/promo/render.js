const { chromium } = require(require('path').join(__dirname, '../../test_visual/node_modules/playwright'));
const { spawn } = require('child_process');
const [,, html, mode, arg] = process.argv;   // mode: stills "1,5,9" | video out.mp4
const FPS = 30;
(async () => {
  const b = await chromium.launch({executablePath: process.env.CHROMIUM_PATH || undefined, args:['--ignore-certificate-errors']});
  const p = await b.newPage({ ignoreHTTPSErrors: true, viewport: { width: 1080, height: 1920 } });
  await p.goto('file://' + html);
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(1500);
  const stage = await p.$('#stage');
  if (mode === 'stills') {
    for (const t of arg.split(',')) {
      await p.evaluate(t => render(t), Number(t));
      await stage.screenshot({ path: `${require('path').dirname(html)}/still_${t}.png` });
    }
  } else {
    const dur = await p.evaluate(() => DURATION);
    const ff = spawn(process.env.FFMPEG || 'ffmpeg', ['-y', '-f', 'image2pipe', '-framerate', String(FPS), '-i', '-',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '18', '-preset', 'slow', '-movflags', '+faststart', arg],
      { stdio: ['pipe', 'ignore', 'inherit'] });
    const n = Math.round(dur * FPS);
    for (let f = 0; f < n; f++) {
      await p.evaluate(t => render(t), f / FPS);
      const buf = await stage.screenshot({ type: 'jpeg', quality: 95 });
      if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
      if (f % 150 === 0) console.log('frame', f, '/', n);
    }
    ff.stdin.end();
    await new Promise(r => ff.on('close', r));
  }
  await b.close();
})();
