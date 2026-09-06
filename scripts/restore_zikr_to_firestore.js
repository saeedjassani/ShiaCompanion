// Writes a restored zikr document to Firestore (the `zikr` collection is the
// source of truth that build_zikr_release.js regenerates assets/zikr.json
// and assets/zikr/<uid> from). Use this after hand-restoring a UID's content
// from its old assets/items/<uid> history — see
// scripts/RESTORING_MISSING_ZIKRS.md for the full process.
//
// Usage:
//   node scripts/restore_zikr_to_firestore.js <uid> <path-to-draft.json> [--regenerate]
//
// The draft JSON must have the shape:
//   { "title": "...", "code": "012", "data": "...", "merits": "...", "slug": "..." }
// (merits and slug are optional)
//
// --regenerate runs build_zikr_release.js afterward to refresh the local
// assets/zikr.json + assets/zikr/<uid> bundled files from Firestore, so you
// can confirm the write took and see the pipeline's own normalization applied.

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const admin = require('firebase-admin');

function getServiceAccountPath() {
  const envPath = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
  if (envPath && fs.existsSync(envPath)) return envPath;
  const candidates = [
    path.join(__dirname, 'serviceAccountKey.json'),
    path.join(__dirname, '..', 'serviceAccountKey.json'),
  ];
  return candidates.find((c) => fs.existsSync(c));
}

async function main() {
  const [uid, draftPath, ...rest] = process.argv.slice(2);
  if (!uid || !draftPath) {
    console.log('Usage: node scripts/restore_zikr_to_firestore.js <uid> <path-to-draft.json> [--regenerate]');
    process.exit(1);
  }
  const regenerate = rest.includes('--regenerate');

  const draft = JSON.parse(fs.readFileSync(path.resolve(draftPath), 'utf8'));
  if (!draft.title || !draft.data) {
    throw new Error('Draft must have at least "title" and "data" fields.');
  }

  const doc = {
    title: draft.title,
    code: draft.code || '012',
  };
  if (draft.data) doc.data = draft.data;
  if (draft.merits) doc.merits = draft.merits;
  if (draft.slug) doc.slug = draft.slug;

  const serviceAccountPath = getServiceAccountPath();
  if (!serviceAccountPath) {
    throw new Error('Could not find serviceAccountKey.json (checked scripts/ and repo root).');
  }
  const serviceAccount = require(path.resolve(serviceAccountPath));
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const db = admin.firestore();

  await db.collection('zikr').doc(uid).set(doc);
  console.log(`Stored zikr/${uid} to Firestore.`);
  console.log('title:', doc.title);
  console.log('slug:', doc.slug || '(none)');
  console.log('data lines:', doc.data.split('\n').length);

  if (regenerate) {
    console.log('\nRegenerating local assets via build_zikr_release.js ...');
    execFileSync('node', [path.join(__dirname, 'build_zikr_release.js')], {
      stdio: 'inherit',
      cwd: __dirname,
    });
  } else {
    console.log('\nRun `node scripts/build_zikr_release.js` to refresh local assets from Firestore.');
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
