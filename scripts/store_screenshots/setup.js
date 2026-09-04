'use strict';
// One-time vendoring. Everything here exists because the capture browser is
// offline-ish: it has no access to the CDNs the web build reaches for, so the
// pieces it needs are prepared locally and served by request interception.
const fs = require('fs');
const path = require('path');
const {execFileSync} = require('child_process');
const {VENDOR, HERE} = require('./config');

const FONTS = path.join(VENDOR, 'fonts');
const FB = path.join(VENDOR, 'firebase');

function vendorFonts() {
  fs.mkdirSync(FONTS, {recursive: true});
  const want = [
    ['@fontsource/roboto', ['roboto-latin-300-normal.woff2', 'roboto-latin-400-normal.woff2',
                            'roboto-latin-500-normal.woff2', 'roboto-latin-700-normal.woff2']],
    ['@fontsource/noto-sans-arabic', ['noto-sans-arabic-arabic-400-normal.woff2']],
  ];
  for (const [pkg, files] of want) {
    for (const f of files) {
      fs.copyFileSync(path.join(HERE, 'node_modules', pkg, 'files', f), path.join(FONTS, f));
    }
  }
  console.log('vendored fonts ->', path.relative(HERE, FONTS));
}

// The Firebase JS SDK is fetched from gstatic.com at runtime. Bundle the same
// version from npm instead, as ONE esbuild build with code splitting: the
// modules must share the firebase app singleton, and bundling each entry
// separately gives each its own copy, which breaks getApp() across modules.
//
// firebase-firestore-pipelines.js re-exports the whole firestore API on
// purpose. cloud_firestore_web imports only that file and then looks up
// getFirestore on it; a pipelines-only bundle fails with
// "getFirestore is not a function" and the app never paints.
function vendorFirebase() {
  const entries = path.join(VENDOR, 'entries');
  fs.mkdirSync(entries, {recursive: true});
  for (const m of ['app', 'firestore', 'auth', 'database', 'analytics', 'installations']) {
    fs.writeFileSync(path.join(entries, `firebase-${m}.js`), `export * from 'firebase/${m}';\n`);
  }
  fs.writeFileSync(path.join(entries, 'firebase-firestore-pipelines.js'),
    "export * from 'firebase/firestore';\nexport * from 'firebase/firestore/pipelines';\n");

  execFileSync(path.join(HERE, 'node_modules', '.bin', 'esbuild'), [
    ...fs.readdirSync(entries).map((f) => path.join(entries, f)),
    '--bundle', '--splitting', '--format=esm', `--outdir=${FB}`,
    '--platform=browser', '--define:process.env.NODE_ENV="production"', '--minify',
  ], {cwd: HERE, stdio: ['ignore', 'ignore', 'inherit']});
  console.log('vendored firebase sdk ->', path.relative(HERE, FB));
}

// Recitation audio streams from duas.org. Where that is unreachable, the
// player would sit on an error instead of showing its loaded state, so serve
// a silent track of a plausible length. Chromium plays WAV, so the .mp3 in the
// intercepted URL does not matter - the content type does.
function vendorAudio() {
  const seconds = 672, rate = 8000;
  const n = seconds * rate;
  const head = Buffer.alloc(44);
  head.write('RIFF', 0); head.writeUInt32LE(36 + n, 4); head.write('WAVE', 8);
  head.write('fmt ', 12); head.writeUInt32LE(16, 16); head.writeUInt16LE(1, 20);
  head.writeUInt16LE(1, 22); head.writeUInt32LE(rate, 24); head.writeUInt32LE(rate, 28);
  head.writeUInt16LE(1, 32); head.writeUInt16LE(8, 34);
  head.write('data', 36); head.writeUInt32LE(n, 40);
  fs.writeFileSync(path.join(VENDOR, 'recitation.wav'),
    Buffer.concat([head, Buffer.alloc(n, 0x80)]));
  console.log('vendored silent audio -> vendor/recitation.wav');
}

fs.mkdirSync(VENDOR, {recursive: true});
vendorFonts();
vendorFirebase();
vendorAudio();
console.log('\nsetup complete. Next: flutter build web --release --no-web-resources-cdn');
