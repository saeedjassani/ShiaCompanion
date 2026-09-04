'use strict';
// Store screenshot compositor, second pass: a real device mockup rather than a
// rounded rectangle. Titanium rail, black bezel, Dynamic Island, side buttons,
// and an iOS status bar drawn on the app bar's own colour, which is sampled
// from each capture so the strip never looks pasted on.
const fs = require('fs');
const path = require('path');
const {chromium} = require('playwright');
const {VENDOR, CHROME_PATH, RAW_DIR} = require('./config');
const {sampleBarColours} = require('./bar-colours');

const CHROME = CHROME_PATH;
const ROBOTO = path.join(VENDOR, 'fonts');
const BARCOLORS = sampleBarColours(RAW_DIR);

function fontFace(weight, file) {
  const b64 = fs.readFileSync(path.join(ROBOTO, file)).toString('base64');
  return `@font-face{font-family:Roboto;font-style:normal;font-weight:${weight};
    src:url(data:font/woff2;base64,${b64}) format('woff2');}`;
}
const FONTS = [fontFace(400, 'roboto-latin-400-normal.woff2'),
               fontFace(500, 'roboto-latin-500-normal.woff2'),
               fontFace(700, 'roboto-latin-700-normal.woff2')].join('\n');

function pngSize(file) {
  const b = fs.readFileSync(file, {start: 0, end: 32});
  return {w: b.readUInt32BE(16), h: b.readUInt32BE(20)};
}

/** Relative luminance, to decide whether status bar glyphs go light or dark. */
function isDark(hex) {
  const n = parseInt(hex.slice(1), 16);
  const [r, g, b] = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => {
    const s = v / 255;
    return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.42;
}

const THEMES = {
  brand: {
    bg: `linear-gradient(158deg,#a9755c 0%,#8a5a49 34%,#6b4238 68%,#4a2c24 100%)`,
    glow: `radial-gradient(78% 46% at 50% 2%, rgba(255,231,214,.34) 0%, rgba(255,231,214,0) 68%),
           radial-gradient(120% 90% at 50% 108%, rgba(28,14,9,.42) 0%, rgba(28,14,9,0) 62%)`,
    ink: '#ffffff', badgeBg: 'rgba(255,255,255,.16)', badgeInk: '#fff',
  },
  blue: {
    bg: `linear-gradient(163deg,#63b3f7 0%,#5a92f1 44%,#6d6ce9 78%,#6a5ce0 100%)`,
    glow: `radial-gradient(78% 46% at 50% 2%, rgba(255,255,255,.30) 0%, rgba(255,255,255,0) 66%),
           radial-gradient(120% 90% at 50% 108%, rgba(24,20,80,.30) 0%, rgba(24,20,80,0) 62%)`,
    ink: '#ffffff', badgeBg: 'rgba(255,255,255,.20)', badgeInk: '#fff',
  },
  cream: {
    bg: `linear-gradient(168deg,#fdf3ef 0%,#f6ded4 48%,#eccebf 100%)`,
    glow: `radial-gradient(90% 55% at 50% 0%, rgba(255,255,255,.75) 0%, rgba(255,255,255,0) 70%)`,
    ink: '#4a2c22', badgeBg: '#7a5548', badgeInk: '#fff',
  },
};

/** iOS status bar: time on the left, cellular/wifi/battery on the right. */
function statusBar(h, w, fg, clock) {
  const fs_ = Math.round(h * 0.315);
  const icon = Math.round(h * 0.30);
  return `
  <div class="sb" style="height:${h}px;padding:0 ${Math.round(w*0.075)}px">
    <div class="sb-t" style="font-size:${fs_}px;color:${fg}">${clock}</div>
    <div class="sb-i" style="gap:${Math.round(h*0.13)}px">
      <svg width="${Math.round(icon*1.22)}" height="${icon}" viewBox="0 0 22 18" fill="${fg}">
        <rect x="0"  y="12" width="3.4" height="6"  rx="1.1"/>
        <rect x="5.3" y="8.4" width="3.4" height="9.6" rx="1.1"/>
        <rect x="10.6" y="4.6" width="3.4" height="13.4" rx="1.1"/>
        <rect x="15.9" y="0.8" width="3.4" height="17.2" rx="1.1"/>
      </svg>
      <svg width="${Math.round(icon*1.15)}" height="${icon}" viewBox="0 0 20 15" fill="none">
        <path d="M10 13.6l2.2-2.6a3.1 3.1 0 0 0-4.4 0L10 13.6z" fill="${fg}"/>
        <path d="M4.6 7.6a8.2 8.2 0 0 1 10.8 0" stroke="${fg}" stroke-width="2.1" stroke-linecap="round"/>
        <path d="M1.5 4.2a12.9 12.9 0 0 1 17 0" stroke="${fg}" stroke-width="2.1" stroke-linecap="round"/>
      </svg>
      <svg width="${Math.round(icon*1.85)}" height="${icon}" viewBox="0 0 28 15" fill="none">
        <rect x="0.9" y="0.9" width="23" height="13.2" rx="4" stroke="${fg}" stroke-opacity=".42" stroke-width="1.8"/>
        <rect x="3" y="3" width="15.4" height="9" rx="2.4" fill="${fg}"/>
        <path d="M26.1 5.2v4.6c1.2-.4 1.9-1.2 1.9-2.3s-.7-1.9-1.9-2.3z" fill="${fg}" fill-opacity=".42"/>
      </svg>
    </div>
  </div>`;
}

function page(o) {
  const {shotB64, caption, badge, W, H, device, shot, barColor, bottomColor, theme, clock} = o;
  const isTablet = device === 'tablet';
  const t = THEMES[theme];
  const fg = isDark(barColor) ? '#ffffff' : '#1c1c1e';

  const capTop   = Math.round(H * (isTablet ? 0.046 : 0.055));
  const capSize  = Math.round(W * (isTablet ? 0.046 : 0.067));
  const badgeSz  = Math.round(capSize * 0.44);
  const capBand  = Math.round(H * (isTablet ? 0.155 : 0.20));
  const sidePad  = Math.round(W * (isTablet ? 0.085 : 0.105));
  // The whole device sits inside the canvas, with breathing room under it to
  // match the space above the caption.
  const bottomPad = Math.round(H * (isTablet ? 0.050 : 0.058));
  const availH    = H - capBand - bottomPad;
  const availW    = W - sidePad * 2;

  // Status bar height as a fraction of screen width, per iOS proportions.
  const sbH = shot.w * (isTablet ? 0.033 : 0.150);
  const hiH = 0;
  const totalShotH = shot.h + sbH + hiH;

  const rail   = Math.max(2, Math.round(W * (isTablet ? 0.0075 : 0.0115)));
  const bezel  = Math.max(2, Math.round(W * (isTablet ? 0.0055 : 0.0085)));
  const chrome = (rail + bezel) * 2;
  let screenW = Math.min(availW - chrome, (availH - chrome) * (shot.w / totalShotH));
  const scale = screenW / shot.w;
  const screenH = Math.round(totalShotH * scale);
  screenW = Math.round(screenW);

  const outerR  = Math.round(screenW * (isTablet ? 0.052 : 0.135));
  const screenR = Math.round(outerR - rail - bezel);
  const sbPx    = Math.round(sbH * scale);
  const hiPx    = Math.round(hiH * scale);

  // Dynamic Island, at iPhone 15/16 Pro proportions relative to screen width.
  const diW = Math.round(screenW * 0.318);
  const diH = Math.round(screenW * 0.094);
  const diTop = Math.round(screenW * 0.028);

  const btnW = Math.max(2, Math.round(rail * 0.45));
  return `<!doctype html><html><head><meta charset="utf-8"><style>
  ${FONTS}
  *{margin:0;padding:0;box-sizing:border-box}
  html,body{width:${W}px;height:${H}px;overflow:hidden}
  body{font-family:Roboto,'Liberation Sans',sans-serif;background:${t.bg}}
  .glow{position:absolute;inset:0;background:${t.glow};pointer-events:none}
  .wrap{position:relative;width:100%;height:100%;display:flex;flex-direction:column;align-items:center}
  .cap{height:${capBand}px;padding:${capTop}px ${Math.round(W*0.07)}px 0;text-align:center;
       display:flex;flex-direction:column;align-items:center}
  .badge{font-size:${badgeSz}px;font-weight:700;letter-spacing:.15em;color:${t.badgeInk};
         background:${t.badgeBg};padding:${Math.round(badgeSz*0.44)}px ${Math.round(badgeSz*1.0)}px;
         border-radius:999px;margin-bottom:${Math.round(capSize*0.40)}px;text-transform:uppercase;
         backdrop-filter:blur(2px)}
  h1{font-size:${capSize}px;line-height:1.12;font-weight:700;color:${t.ink};
     letter-spacing:-0.02em;text-wrap:balance;
     text-shadow:0 ${Math.round(W*0.003)}px ${Math.round(W*0.012)}px rgba(0,0,0,.18)}
  .stage{flex:1;width:100%;display:flex;align-items:center;justify-content:center;
         padding-bottom:${bottomPad}px}

  /* Titanium rail, black bezel, screen. */
  .rail{position:relative;width:${screenW + chrome}px;height:${screenH + chrome}px;
        border-radius:${outerR}px;padding:${rail}px;
        background:linear-gradient(145deg,#5c5c60 0%,#37373a 17%,#1d1d20 42%,
                   #4e4e53 60%,#2a2a2d 80%,#141416 100%);
        box-shadow:0 ${Math.round(W*0.035)}px ${Math.round(W*0.075)}px rgba(20,10,6,.34),
                   0 ${Math.round(W*0.006)}px ${Math.round(W*0.014)}px rgba(20,10,6,.22),
                   inset 0 0 ${Math.round(rail*1.2)}px rgba(255,255,255,.16)}
  .bezel{width:100%;height:100%;background:#070504;border-radius:${outerR - rail}px;
         padding:${bezel}px}
  .screen{position:relative;width:100%;height:100%;border-radius:${screenR}px;
          overflow:hidden;background:${barColor}}
  .sb{width:100%;display:flex;align-items:center;justify-content:space-between;
      background:${barColor}}
  .sb-t{font-weight:600;letter-spacing:.01em;font-variant-numeric:tabular-nums}
  .sb-i{display:flex;align-items:center}
  .shot{width:100%;display:block}
  .hi{width:100%;display:flex;align-items:center;justify-content:center;
      background:${bottomColor}}
  .hi span{width:${Math.round(screenW*0.354)}px;height:${Math.max(2,Math.round(screenW*0.0125))}px;
           border-radius:999px;background:${isDark(bottomColor) ? 'rgba(255,255,255,.92)' : 'rgba(0,0,0,.82)'}}
  .di{position:absolute;top:${diTop}px;left:50%;transform:translateX(-50%);
      width:${diW}px;height:${diH}px;border-radius:999px;background:#000;z-index:3}

  /* Side buttons, sitting on the rail. */
  .btn{position:absolute;background:linear-gradient(180deg,#4a4a4e,#232326);border-radius:${btnW}px;box-shadow:inset 0 0 1px rgba(0,0,0,.55)}
  .b-mute{left:-${btnW}px;top:${Math.round(screenH*0.148)}px;width:${btnW}px;height:${Math.round(screenH*0.034)}px}
  .b-up{left:-${btnW}px;top:${Math.round(screenH*0.212)}px;width:${btnW}px;height:${Math.round(screenH*0.062)}px}
  .b-dn{left:-${btnW}px;top:${Math.round(screenH*0.288)}px;width:${btnW}px;height:${Math.round(screenH*0.062)}px}
  .b-pw{right:-${btnW}px;top:${Math.round(screenH*0.232)}px;width:${btnW}px;height:${Math.round(screenH*0.096)}px}
  </style></head><body>
  <div class="glow"></div>
  <div class="wrap">
    <div class="cap">${badge ? `<div class="badge">${badge}</div>` : ''}<h1>${caption}</h1></div>
    <div class="stage">
      <div class="rail">
        ${isTablet ? '' : `<div class="btn b-mute"></div><div class="btn b-up"></div>
          <div class="btn b-dn"></div><div class="btn b-pw"></div>`}
        <div class="bezel"><div class="screen">
          ${isTablet ? '' : `<div class="di"></div>`}
          ${statusBar(sbPx, screenW, fg, clock)}
          <img class="shot" src="data:image/png;base64,${shotB64}">
        </div></div>
      </div>
    </div>
  </div></body></html>`;
}

async function render(browser, o) {
  const {src, out, W, H} = o;
  const shotB64 = fs.readFileSync(src).toString('base64');
  const shot = pngSize(src);
  const key = path.basename(src, '.png');
  const ctx = await browser.newContext({viewport: {width: W, height: H}, deviceScaleFactor: 1});
  const p = await ctx.newPage();
  await p.setContent(page({
    ...o, shotB64, shot,
    barColor: (BARCOLORS[key] || {}).top || '#795548',
    bottomColor: (BARCOLORS[key] || {}).bottom || '#fff8f6',
    theme: o.theme || 'brand',
    clock: o.clock || '9:41',
  }), {waitUntil: 'load'});
  await p.waitForTimeout(320);
  fs.mkdirSync(path.dirname(out), {recursive: true});
  await p.screenshot({path: out});
  await ctx.close();
  console.log('framed', path.relative(process.cwd(), out));
}

module.exports = {render, chromium, CHROME};
