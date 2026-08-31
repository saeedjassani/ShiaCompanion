/**
 * Writes the approved rows of duas_audio_map.json onto the Firestore zikr
 * docs as an `audio` array. Run import_duas_audio.js first, review the map,
 * flip `"approved": true` on the rows you accept, then run this.
 *
 * Firestore is the source of truth; build_zikr_release.js is what bakes the
 * field into assets/zikr/<uid> afterwards.
 *
 * Usage:
 *   node apply_duas_audio.js                    # dry run, prints the diff
 *   node apply_duas_audio.js --store            # write to Firestore
 *   node apply_duas_audio.js --only G4 --store  # write one zikr only
 *   node apply_duas_audio.js --clear            # remove the audio field
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const ZIKR_COLLECTION = 'zikr';
const MAP_FILE = path.join(__dirname, 'duas_audio_map.json');

const argv = process.argv.slice(2);
const args = new Set(argv);
const STORE = args.has('--store');
const CLEAR = args.has('--clear');

/** Restricts the write to specific uids, for rolling one zikr out at a time. */
const ONLY = (() => {
  const at = argv.indexOf('--only');
  if (at === -1) return null;
  const uids = argv.slice(at + 1).filter((a) => !a.startsWith('--'));
  if (!uids.length) throw new Error('--only needs at least one uid, e.g. --only G4');
  return new Set(uids);
})();

function getServiceAccount() {
  const envJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (envJson) return JSON.parse(envJson);

  const envB64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (envB64) return JSON.parse(Buffer.from(envB64, 'base64').toString('utf8'));

  const candidates = [
    path.join(__dirname, 'serviceAccountKey.json'),
    path.join(__dirname, '..', 'serviceAccountKey.json'),
  ];
  const found = candidates.find((c) => fs.existsSync(c));
  if (!found) {
    throw new Error(
      'No service account found. Set FIREBASE_SERVICE_ACCOUNT_JSON/BASE64 or '
      + 'place serviceAccountKey.json.',
    );
  }
  return require(path.resolve(found));
}

/** Several approved pages can point at one zikr, so tracks are merged and
 * de-duplicated by URL rather than the last page winning. */
function buildAudioByUid(rows) {
  const byUid = new Map();
  for (const row of rows) {
    if (row.approved !== true || !row.uid) continue;
    if (ONLY && !ONLY.has(row.uid)) continue;
    const list = byUid.get(row.uid) || [];
    for (const track of row.tracks || []) {
      const url = `${track?.url ?? ''}`.trim();
      if (!url.startsWith('https://')) continue;
      if (list.some((t) => t.url === url)) continue;
      const entry = {url};
      const label = `${track?.label ?? ''}`.trim();
      if (label) entry.label = label;
      list.push(entry);
    }
    if (list.length) byUid.set(row.uid, list);
  }
  return byUid;
}

async function main() {
  if (!fs.existsSync(MAP_FILE)) {
    throw new Error(`${path.basename(MAP_FILE)} not found. Run import_duas_audio.js first.`);
  }
  const map = JSON.parse(fs.readFileSync(MAP_FILE, 'utf8'));
  const rows = map.rows || [];

  admin.initializeApp({credential: admin.credential.cert(getServiceAccount())});
  const db = admin.firestore();

  if (CLEAR) {
    const snap = await db.collection(ZIKR_COLLECTION).get();
    const targets = [];
    snap.forEach((doc) => {
      if (doc.data()?.audio !== undefined) targets.push(doc.id);
    });
    console.log(`${targets.length} docs carry an audio field`);
    if (!STORE) {
      console.log('Dry run. Re-run with --store --clear to remove.');
      return;
    }
    for (const uid of targets) {
      await db.collection(ZIKR_COLLECTION).doc(uid).update({
        audio: admin.firestore.FieldValue.delete(),
      });
    }
    console.log(`Cleared audio from ${targets.length} docs`);
    return;
  }

  const byUid = buildAudioByUid(rows);
  const approvedRows = rows.filter((r) => r.approved === true && r.uid);
  console.log(`Approved rows: ${approvedRows.length} -> ${byUid.size} zikrs, `
    + `${[...byUid.values()].reduce((n, l) => n + l.length, 0)} tracks`);

  if (!byUid.size) {
    console.log('Nothing approved. Set "approved": true on rows you accept.');
    return;
  }

  // Verify every target exists before writing, so a stale uid in the map
  // surfaces as an error rather than creating a junk document.
  const missing = [];
  for (const uid of byUid.keys()) {
    const doc = await db.collection(ZIKR_COLLECTION).doc(uid).get();
    if (!doc.exists) missing.push(uid);
  }
  if (missing.length) {
    throw new Error(`These uids are not in Firestore: ${missing.join(', ')}`);
  }

  for (const [uid, tracks] of byUid) {
    console.log(`  ${uid}: ${tracks.length} track(s)`);
    for (const t of tracks) console.log(`      ${t.label || '(untitled)'} - ${t.url}`);
  }

  if (!STORE) {
    console.log('\nDry run. Re-run with --store to write to Firestore.');
    return;
  }

  let written = 0;
  for (const [uid, tracks] of byUid) {
    await db.collection(ZIKR_COLLECTION).doc(uid).update({audio: tracks});
    written += 1;
  }
  console.log(`\nWrote audio to ${written} zikr docs.`);
  console.log('Next: node build_zikr_release.js to bake it into assets.');
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e.message || e);
    process.exit(1);
  });
