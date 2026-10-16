'use strict';
// Store screenshot compositor. Each slide is one of a few layouts:
//
//   fan   - two devices fanned out, e.g. the same screen in light and dark
//   fan3  - three devices, the middle one in front
//   row   - three devices side by side, nothing hidden, the middle one raised
//   peek  - one device in full, the other two behind it, their outer halves
//           showing at either side
//   tilt  - one device turned in 3D, with feature callouts beside it
//
// Slides are laid out on a design canvas DW px wide (1320 for phones, 2064 for
// tablets) whose height follows the target's aspect ratio, then rendered at
// the target's exact pixel size through deviceScaleFactor, so one layout
// serves every store size. Status bar colours are sampled from each capture
// (bar-colours.js) so the strip sits on the app bar's own colour.
const fs = require('fs');
const path = require('path');
const {chromium} = require('playwright');
const {VENDOR, CHROME_PATH, RAW_DIR} = require('./config');
const {sampleBarColours} = require('./bar-colours');

const BARS = sampleBarColours(RAW_DIR);

function fontFace(weight) {
  const file = path.join(VENDOR, 'fonts', `roboto-latin-${weight}-normal.woff2`);
  return `@font-face{font-family:Roboto;font-weight:${weight};
    src:url(data:font/woff2;base64,${fs.readFileSync(file).toString('base64')}) format('woff2')}`;
}
const FONTS = [400, 500, 700].map(fontFace).join('\n');

function pngSize(file) {
  const b = fs.readFileSync(file, {start: 0, end: 32});
  return {w: b.readUInt32BE(16), h: b.readUInt32BE(20)};
}

/** Whether status bar glyphs on [hex] should be light. */
function isDark(hex) {
  const n = parseInt(hex.slice(1), 16);
  const [r, g, b] = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => {
    const s = v / 255;
    return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.42;
}

const BG = `linear-gradient(158deg,#a9755c 0%,#8a5a49 34%,#6b4238 68%,#4a2c24 100%)`;
const GLOW = `radial-gradient(78% 40% at 50% 0%, rgba(255,231,214,.32) 0%, rgba(255,231,214,0) 70%),
  radial-gradient(120% 70% at 50% 110%, rgba(28,14,9,.45) 0%, rgba(28,14,9,0) 62%)`;

/** Signal, wifi and battery, drawn at [h] px tall in [fg]. */
function statusIcons(h, fg, android) {
  const signal = android
    ? `<svg height="${h}" viewBox="0 0 18 18" fill="${fg}"><path d="M17 1v16H1z"/></svg>`
    : `<svg height="${h}" viewBox="0 0 22 18" fill="${fg}"><rect x="0" y="12" width="3.4" height="6" rx="1.1"/>
       <rect x="5.3" y="8.4" width="3.4" height="9.6" rx="1.1"/><rect x="10.6" y="4.6" width="3.4" height="13.4" rx="1.1"/>
       <rect x="15.9" y="0.8" width="3.4" height="17.2" rx="1.1"/></svg>`;
  const wifi = `<svg height="${h}" viewBox="0 0 20 15" fill="none"><path d="M10 13.6l2.2-2.6a3.1 3.1 0 0 0-4.4 0L10 13.6z" fill="${fg}"/>
    <path d="M4.6 7.6a8.2 8.2 0 0 1 10.8 0" stroke="${fg}" stroke-width="2.1" stroke-linecap="round"/>
    <path d="M1.5 4.2a12.9 12.9 0 0 1 17 0" stroke="${fg}" stroke-width="2.1" stroke-linecap="round"/></svg>`;
  const battery = android
    ? `<svg height="${h}" viewBox="0 0 10 18" fill="${fg}"><rect x="3" y="0" width="4" height="2" rx=".5"/><rect x="0" y="2" width="10" height="16" rx="1.6"/></svg>`
    : `<svg height="${h}" viewBox="0 0 28 15" fill="none"><rect x="0.9" y="0.9" width="23" height="13.2" rx="4" stroke="${fg}" stroke-opacity=".42" stroke-width="1.8"/>
       <rect x="3" y="3" width="15.4" height="9" rx="2.4" fill="${fg}"/><path d="M26.1 5.2v4.6c1.2-.4 1.9-1.2 1.9-2.3s-.7-1.9-1.9-2.3z" fill="${fg}" fill-opacity=".42"/></svg>`;
  return android ? wifi + signal + battery : signal + wifi + battery;
}

/**
 * One device, [w] px wide, showing capture [key]. [kind] is iphone, android or
 * tablet. Returns {html, h}: the device's outer height, for placing callouts.
 */
function device(key, w, kind, style = '') {
  const src = path.join(RAW_DIR, `${key}.png`);
  const shot = pngSize(src);
  const bar = (BARS[key] || {}).top || '#f8efe9';
  const fg = isDark(bar) ? '#ffffff' : '#1c1c1e';
  const tablet = kind === 'tablet';
  const android = kind === 'android';
  const rail = w * (tablet ? 0.012 : 0.022);
  const bezel = w * (tablet ? 0.018 : 0.012);
  const r = w * (tablet ? 0.05 : 0.14);
  const inner = w - 2 * (rail + bezel);
  const sbH = inner * (tablet ? 0.032 : 0.125);
  const screenH = inner * shot.h / shot.w + sbH;
  const h = screenH + 2 * (rail + bezel);
  const clock = android ? '12:30' : '9:41';
  const camera = tablet ? '' : android
    ? `<div style="position:absolute;top:${inner * 0.032}px;left:50%;transform:translateX(-50%);
         width:${inner * 0.045}px;height:${inner * 0.045}px;border-radius:50%;background:#050505"></div>`
    : `<div style="position:absolute;top:${inner * 0.028}px;left:50%;transform:translateX(-50%);
         width:${inner * 0.31}px;height:${inner * 0.09}px;border-radius:99px;background:#000"></div>`;
  const sbPad = inner * (tablet ? 0.03 : android ? 0.07 : 0.085);
  const html = `<div class="dev" style="width:${w}px;height:${h}px;border-radius:${r}px;padding:${rail}px;${style}">
    <div style="width:100%;height:100%;background:#070504;border-radius:${r - rail}px;padding:${bezel}px">
     <div style="position:relative;width:100%;height:100%;border-radius:${r - rail - bezel}px;overflow:hidden;background:${bar}">
      ${camera}
      <div style="height:${sbH}px;display:flex;align-items:center;justify-content:space-between;padding:0 ${sbPad}px;
           color:${fg};font-weight:600;font-size:${sbH * (tablet ? 0.42 : android ? 0.3 : 0.34)}px">
        <span>${clock}</span>
        <span style="display:flex;align-items:center;gap:${sbH * 0.1}px">${statusIcons(sbH * (tablet ? 0.32 : 0.26), fg, android)}</span>
      </div>
      <img src="data:image/png;base64,${fs.readFileSync(src).toString('base64')}" style="width:100%;display:block">
     </div>
    </div>
  </div>`;
  return {html, h};
}

function page(slide, t) {
  const {DW, DH, kind} = t;
  const tablet = kind === 'tablet';
  const u = DW / 100;
  const capTop = DH * (tablet ? 0.045 : 0.05);
  const h1 = u * (tablet ? 5.6 : 7.3);
  const lines = slide.caption.split('\n').length;
  const badgeH = slide.badge ? h1 * 0.95 : 0;
  const stageTop = capTop + badgeH + h1 * 1.1 * lines + DH * (tablet ? 0.035 : 0.045);
  const avail = DH - stageTop;
  const pre = (i) => `${tablet ? 't' : 'p'}-${slide.shots[i]}`;
  let devices = '';
  let callouts = '';
  // Top edge that centres a [h] px tall group in the space under the caption,
  // never above it.
  const centre = (h) => stageTop + Math.max(0, (avail - h) / 2);
  const tall = (i, w) => device(pre(i), w, kind).h;

  if (slide.layout === 'fan') {
    const w = Math.min(DW * (tablet ? 0.66 : 0.64), avail * (tablet ? 0.62 : 0.5));
    const top = centre(tall(0, w) + avail * 0.04);
    const a = device(pre(0), w, kind, `left:${DW * 0.03}px;top:${top}px;transform:rotate(-8deg)`);
    const b = device(pre(1), w, kind, `right:${DW * 0.03}px;top:${top + avail * 0.04}px;transform:rotate(7deg)`);
    devices = a.html + b.html;
  } else if (slide.layout === 'fan3') {
    const w = Math.min(DW * (tablet ? 0.46 : 0.52), avail * (tablet ? 0.5 : 0.42));
    const side = w * 0.9;
    const top = centre(tall(1, w) + avail * 0.03);
    const mid = device(pre(1), w, kind, `left:${(DW - w) / 2}px;top:${top + avail * 0.03}px;z-index:2`);
    const l = device(pre(0), side, kind, `left:${DW * 0.005}px;top:${top}px;transform:rotate(-9deg)`);
    const r = device(pre(2), side, kind, `right:${DW * 0.005}px;top:${top}px;transform:rotate(9deg)`);
    devices = l.html + r.html + mid.html;
  } else if (slide.layout === 'row') {
    // Each device can carry a label pill above it (slide.labels).
    const gap = DW * 0.02;
    const w = Math.min((DW - gap * 4) / 3, avail * (tablet ? 0.32 : 0.42));
    const lift = avail * 0.09;
    const label = slide.labels ? u * (tablet ? 5 : 8) : 0;
    const top = centre(tall(0, w) + lift + label) + label;
    const x0 = (DW - (w * 3 + gap * 2)) / 2;
    devices = [0, 1, 2].map((i) => {
      const y = top + (i === 1 ? 0 : lift);
      const tag = slide.labels ? `<div class="tag" style="left:${x0 + i * (w + gap)}px;width:${w}px;
        top:${y - label}px;height:${label}px">${slide.labels[i]}</div>` : '';
      return tag + device(pre(i), w, kind, `left:${x0 + i * (w + gap)}px;top:${y}px`).html;
    }).join('');
  } else if (slide.layout === 'peek') {
    // The side devices are slightly smaller and centred on the same line, so
    // the three read as one row; each shows its outer half past the middle one.
    const w = Math.min(DW * (tablet ? 0.5 : 0.56), avail * (tablet ? 0.6 : 0.47));
    const side = w * 0.86;
    const midH = tall(1, w);
    const top = centre(midH);
    const sideTop = top + (midH - tall(0, side)) / 2;
    const mx = (DW - w) / 2;
    // Half of each side device, or as much as fits inside the canvas edge.
    const visible = Math.min(side * 0.5, mx - DW * 0.03);
    const l = device(pre(0), side, kind, `left:${mx - visible}px;top:${sideTop}px;filter:brightness(.9)`);
    const r = device(pre(2), side, kind, `left:${mx + w - side + visible}px;top:${sideTop}px;filter:brightness(.9)`);
    const mid = device(pre(1), w, kind, `left:${mx}px;top:${top}px;z-index:2`);
    devices = l.html + r.html + mid.html;
  } else if (slide.layout === 'tilt') {
    const w = Math.min(DW * (tablet ? 0.8 : 0.7), avail * (tablet ? 0.68 : 0.5));
    const left = (DW - w) / 2 + DW * 0.05;
    const top = centre(tall(0, w));
    const d = device(pre(0), w, kind,
      `left:${left}px;top:${top}px;transform:rotateY(-20deg) rotateX(5deg) rotateZ(-3deg)`);
    devices = d.html;
    callouts = (slide.callouts || []).map(([text, sub], i) => {
      const y = top + d.h * (0.22 + i * (0.56 / Math.max(1, slide.callouts.length - 1)));
      const pos = i % 2 ? `right:${DW * 0.045}px` : `left:${DW * 0.045}px`;
      return `<div class="pill" style="${pos};top:${y}px">${text}${sub ? `<small>${sub}</small>` : ''}</div>`;
    }).join('');
  }

  return `<!doctype html><html><head><meta charset="utf-8"><style>
  ${FONTS}
  *{margin:0;padding:0;box-sizing:border-box}
  html,body{width:${DW}px;height:${DH}px;overflow:hidden}
  body{font-family:Roboto,sans-serif;background:${BG};position:relative;perspective:${DW * 2}px}
  .glow{position:absolute;inset:0;background:${GLOW}}
  .cap{position:absolute;left:0;right:0;top:${capTop}px;text-align:center;padding:0 ${u * 6}px;color:#fff;z-index:5}
  .badge{display:inline-block;font-size:${h1 * 0.36}px;font-weight:700;letter-spacing:.15em;
         background:rgba(255,255,255,.18);padding:${h1 * 0.14}px ${h1 * 0.36}px;border-radius:99px;margin-bottom:${h1 * 0.3}px}
  h1{font-size:${h1}px;line-height:1.1;font-weight:700;letter-spacing:-.02em;
     text-shadow:0 ${u * 0.3}px ${u * 1.2}px rgba(0,0,0,.18)}
  .dev{position:absolute;background:linear-gradient(145deg,#5c5c60 0%,#37373a 17%,#1d1d20 42%,#4e4e53 60%,#2a2a2d 80%,#141416 100%);
       box-shadow:0 ${u * 4}px ${u * 9}px rgba(20,10,6,.42),0 ${u * 0.7}px ${u * 1.6}px rgba(20,10,6,.25)}
  .pill{position:absolute;z-index:4;background:rgba(255,255,255,.95);color:#4a2c22;border-radius:${u * 2.6}px;
        padding:${u * 2}px ${u * 2.8}px;font-size:${u * (tablet ? 2.3 : 3.7)}px;font-weight:700;
        box-shadow:0 ${u * 1.6}px ${u * 4.2}px rgba(0,0,0,.28);max-width:${u * 56}px}
  .tag{position:absolute;display:flex;align-items:center;justify-content:center;color:#fff;
       font-size:${u * (tablet ? 2.4 : 3.8)}px;font-weight:700;letter-spacing:.01em}
  .pill small{display:block;font-size:.72em;font-weight:400;color:#8a6a5c;margin-top:${u * 0.4}px}
  </style></head><body>
  <div class="glow"></div>
  <div class="cap">${slide.badge ? `<div class="badge">${slide.badge}</div>` : ''}<h1>${slide.caption.replace(/\n/g, '<br>')}</h1></div>
  ${devices}${callouts}
  </body></html>`;
}

/** Renders [slide] for target [t] ({W, H, kind}) to [out]. */
async function render(browser, slide, t, out) {
  const DW = t.kind === 'tablet' ? 2064 : 1320;
  const DH = Math.round(DW * t.H / t.W);
  const ctx = await browser.newContext({viewport: {width: DW, height: DH}, deviceScaleFactor: t.W / DW});
  const p = await ctx.newPage();
  await p.setContent(page(slide, {...t, DW, DH}), {waitUntil: 'load'});
  await p.waitForTimeout(250);
  fs.mkdirSync(path.dirname(out), {recursive: true});
  await p.screenshot({path: out});
  await ctx.close();
  console.log('framed', path.relative(process.cwd(), out));
}

/** Play's 1024x500 feature graphic: name and tagline beside two phones. */
async function renderFeatureGraphic(browser, out) {
  const DW = 2048, DH = 1000;
  const logo = fs.readFileSync(path.join(__dirname, '..', '..', 'assets', 'logo.png')).toString('base64');
  const a = device('p-home-l', 560, 'android', 'left:1250px;top:120px;transform:rotate(-8deg)');
  const b = device('p-read-ur-d', 560, 'android', 'left:1560px;top:210px;transform:rotate(7deg)');
  const html = `<!doctype html><html><head><meta charset="utf-8"><style>${FONTS}
    *{margin:0;padding:0;box-sizing:border-box}
    body{width:${DW}px;height:${DH}px;overflow:hidden;position:relative;font-family:Roboto,sans-serif;background:${BG}}
    .glow{position:absolute;inset:0;background:${GLOW}}
    .dev{position:absolute;background:linear-gradient(145deg,#5c5c60,#1d1d20 42%,#4e4e53 60%,#141416);
         box-shadow:0 40px 90px rgba(20,10,6,.45)}
    .t{position:absolute;left:120px;top:0;bottom:0;display:flex;flex-direction:column;justify-content:center;color:#fff;width:1050px}
    img.logo{width:170px;border-radius:38px;box-shadow:0 18px 40px rgba(0,0,0,.3);margin-bottom:48px}
    h1{font-size:112px;font-weight:700;letter-spacing:-.02em;line-height:1}
    p{font-size:50px;margin-top:30px;opacity:.9;line-height:1.3}
    </style></head><body><div class="glow"></div>
    <div class="t"><img class="logo" src="data:image/png;base64,${logo}"><h1>Shia Companion</h1>
    <p>Duas, ziyarats, Quran and prayer times, now in five languages</p></div>
    ${a.html}${b.html}</body></html>`;
  const ctx = await browser.newContext({viewport: {width: DW, height: DH}, deviceScaleFactor: 0.5});
  const p = await ctx.newPage();
  await p.setContent(html, {waitUntil: 'load'});
  await p.waitForTimeout(250);
  fs.mkdirSync(path.dirname(out), {recursive: true});
  await p.screenshot({path: out});
  await ctx.close();
  console.log('framed', path.relative(process.cwd(), out));
}

function launchBrowser() {
  return chromium.launch({executablePath: CHROME_PATH});
}

module.exports = {render, renderFeatureGraphic, launchBrowser};
