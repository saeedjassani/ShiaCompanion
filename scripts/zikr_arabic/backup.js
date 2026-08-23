#!/usr/bin/env node
// Snapshot the whole `zikr` Firestore collection to a timestamped JSON file.
// Firestore has no revision history for this collection, so nothing in
// scripts/zikr_arabic may write without a fresh snapshot on disk first.
//
//   node scripts/zikr_arabic/backup.js [outdir]     (default: .zikr-backups/)

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function serviceAccountPath() {
  const env = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
  if (env && fs.existsSync(env)) return env;
  return [
    path.join(__dirname, '..', 'serviceAccountKey.json'),
    path.join(__dirname, '..', '..', 'serviceAccountKey.json'),
  ].find((p) => fs.existsSync(p));
}

async function main() {
  const key = serviceAccountPath();
  if (!key) throw new Error('No serviceAccountKey.json found (see scripts/build_zikr_release.js).');
  admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(key))) });

  const outdir = process.argv[2] || path.join(__dirname, '..', '..', '.zikr-backups');
  fs.mkdirSync(outdir, { recursive: true });

  const snap = await admin.firestore().collection('zikr').get();
  const out = {};
  snap.forEach((doc) => { out[doc.id] = doc.data(); });

  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const file = path.join(outdir, `zikr-${stamp}.json`);
  fs.writeFileSync(file, JSON.stringify(out, null, 1));
  console.log(`${snap.size} documents -> ${file}`);
}

main().then(() => process.exit(0)).catch((e) => { console.error(e.message); process.exit(1); });
