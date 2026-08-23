#!/usr/bin/env node
// Restore the `zikr` collection from a snapshot written by backup.js.
// This is the revert path — NOT `git checkout` on assets/zikr, which are a
// lossy projection of the Firestore documents (slug is computed at build time,
// and only title/code/data/merits/tabs are copied out).
//
//   node scripts/zikr_arabic/restore.js .zikr-backups/zikr-<stamp>.json --dry-run
//   node scripts/zikr_arabic/restore.js .zikr-backups/zikr-<stamp>.json
//   …             --only AA9,AA13        restore just these documents
//
// Only writes documents whose content actually differs from what is live, and
// prints which fields differ. Takes a fresh backup of current state first, so
// a restore is itself revertible.

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const DRY_RUN = process.argv.includes('--dry-run');
const snapFile = process.argv[2];
const onlyArg = process.argv.indexOf('--only');
const only = onlyArg > -1 ? new Set(process.argv[onlyArg + 1].split(',')) : null;

function serviceAccountPath() {
  const env = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
  if (env && fs.existsSync(env)) return env;
  return [
    path.join(__dirname, '..', 'serviceAccountKey.json'),
    path.join(__dirname, '..', '..', 'serviceAccountKey.json'),
  ].find((p) => fs.existsSync(p));
}

const stable = (v) => JSON.stringify(v, Object.keys(v || {}).sort());

async function main() {
  if (!snapFile) throw new Error('usage: restore.js <snapshot.json> [--dry-run] [--only a,b]');
  const snap = JSON.parse(fs.readFileSync(snapFile, 'utf8'));

  const key = serviceAccountPath();
  if (!key) throw new Error('No serviceAccountKey.json found.');
  admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(key))) });
  const db = admin.firestore();

  if (!DRY_RUN) {
    const dir = path.join(__dirname, '..', '..', '.zikr-backups');
    fs.mkdirSync(dir, { recursive: true });
    const live = await db.collection('zikr').get();
    const out = {};
    live.forEach((d) => { out[d.id] = d.data(); });
    const f = path.join(dir, `pre-restore-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
    fs.writeFileSync(f, JSON.stringify(out, null, 1));
    console.log(`current state saved to ${f}\n`);
  }

  let changed = 0, same = 0;
  let batch = db.batch(), pending = 0;

  for (const [uid, doc] of Object.entries(snap)) {
    if (only && !only.has(uid)) continue;
    const ref = db.collection('zikr').doc(uid);
    const live = await ref.get();
    const cur = live.exists ? live.data() : null;

    if (cur && stable(cur) === stable(doc)) { same++; continue; }

    const fields = [...new Set([...Object.keys(doc), ...Object.keys(cur || {})])]
      .filter((k) => JSON.stringify(doc[k]) !== JSON.stringify((cur || {})[k]));
    console.log(`  ${DRY_RUN ? '[dry-run] ' : ''}${uid}: ${fields.join(', ') || '(new)'}`);
    changed++;
    if (DRY_RUN) continue;

    batch.set(ref, doc);
    if (++pending >= 400) { await batch.commit(); batch = db.batch(); pending = 0; }
  }

  if (!DRY_RUN && pending) await batch.commit();
  console.log(`\n${DRY_RUN ? '[dry-run] ' : ''}${changed} restored, ${same} already identical`);
  if (!DRY_RUN && changed) console.log('Now rebuild assets: node scripts/build_zikr_release.js');
}

main().then(() => process.exit(0)).catch((e) => { console.error(e.message); process.exit(1); });
