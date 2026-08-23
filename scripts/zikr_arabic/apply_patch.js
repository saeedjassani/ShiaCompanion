#!/usr/bin/env node
// Apply a patch produced by scripts/zikr_arabic/*.py to Firestore.
//
// Patch shape:  { "<uid>": [ { "path": ["data"], "before": "...", "after": "..." } ] }
// `path` is the JSON path inside the document, as emitted by corpus.iter_strings.
//
//   node scripts/zikr_arabic/apply_patch.js patch.json --dry-run
//   node scripts/zikr_arabic/apply_patch.js patch.json
//
// Refuses to run without --dry-run unless a backup exists in .zikr-backups/.
// Every edit is verified against `before`: if the stored text has drifted the
// document is skipped and reported, never overwritten.

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const DRY_RUN = process.argv.includes('--dry-run');
const patchFile = process.argv[2];

function serviceAccountPath() {
  const env = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
  if (env && fs.existsSync(env)) return env;
  return [
    path.join(__dirname, '..', 'serviceAccountKey.json'),
    path.join(__dirname, '..', '..', 'serviceAccountKey.json'),
  ].find((p) => fs.existsSync(p));
}

function getIn(obj, keys) {
  return keys.reduce((o, k) => (o == null ? o : o[k]), obj);
}
function setIn(obj, keys, value) {
  const last = keys[keys.length - 1];
  const parent = keys.slice(0, -1).reduce((o, k) => o[k], obj);
  parent[last] = value;
}

async function main() {
  if (!patchFile) throw new Error('usage: apply_patch.js <patch.json> [--dry-run]');
  const patch = JSON.parse(fs.readFileSync(patchFile, 'utf8'));

  if (!DRY_RUN) {
    const dir = path.join(__dirname, '..', '..', '.zikr-backups');
    const has = fs.existsSync(dir) && fs.readdirSync(dir).some((f) => f.endsWith('.json'));
    if (!has) throw new Error('No backup in .zikr-backups/. Run scripts/zikr_arabic/backup.js first.');
  }

  const key = serviceAccountPath();
  if (!key) throw new Error('No serviceAccountKey.json found.');
  admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(key))) });
  const db = admin.firestore();

  let edits = 0, skipped = 0, docs = 0;
  let batch = db.batch(), pending = 0;

  for (const [uid, changes] of Object.entries(patch)) {
    const ref = db.collection('zikr').doc(uid);
    const snap = await ref.get();
    if (!snap.exists) { console.warn(`  ${uid}: no such document, skipped`); skipped++; continue; }

    const data = snap.data();
    const update = {};
    let ok = true;

    for (const c of changes) {
      const current = getIn(data, c.path);
      if (current !== c.before) {
        console.warn(`  ${uid}: ${c.path.join('.')} has drifted since the patch was built, skipped`);
        ok = false; break;
      }
      setIn(data, c.path, c.after);
      update[c.path[0]] = data[c.path[0]];
      edits++;
    }
    if (!ok) { skipped++; continue; }

    docs++;
    if (DRY_RUN) {
      console.log(`  [dry-run] ${uid}: ${Object.keys(update).join(', ')} (${changes.length} edits)`);
      continue;
    }
    batch.update(ref, update);
    if (++pending >= 400) { await batch.commit(); batch = db.batch(); pending = 0; }
  }

  if (!DRY_RUN && pending) await batch.commit();

  // Refresh the snapshot: plan/report read from it, so leaving it stale makes
  // the next batch rebuild patches the cloud has already applied.
  if (!DRY_RUN && docs) {
    const dir = path.join(__dirname, '..', '..', '.zikr-backups');
    const fresh = await db.collection('zikr').get();
    const out = {};
    fresh.forEach((d) => { out[d.id] = d.data(); });
    const f = path.join(dir, `zikr-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
    fs.writeFileSync(f, JSON.stringify(out, null, 1));
    console.log(`snapshot refreshed: ${path.basename(f)}`);
  }
  console.log(`\n${DRY_RUN ? '[dry-run] ' : ''}${edits} edits across ${docs} documents` +
              (skipped ? `, ${skipped} skipped` : ''));
  if (!DRY_RUN) console.log('Now rebuild assets: node scripts/build_zikr_release.js');
}

main().then(() => process.exit(0)).catch((e) => { console.error(e.message); process.exit(1); });
