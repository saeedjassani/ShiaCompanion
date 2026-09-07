// One-off migration: nine of the eighteen zikrs added in 4c29a341 ("add
// missing zikrs") carry a `merits` field that's just a one- or two-sentence
// citation blurb - too short to earn its own "Merits" bottom sheet in the
// app. This folds each one into `data` as an intro/closing note (matching
// how longer-standing entries like A4 already carry their attribution
// inline) and clears the `merits` field in Firestore.
//
// Usage:
//   node scripts/fold_short_merits_into_data.js [--dry-run]
//
// Verifies each doc's current `data`/`merits` against what's in
// assets/zikr/<uid> before writing, so a concurrent edit to Firestore since
// the last `build_zikr_release.js` pull aborts the run instead of silently
// clobbering it. Run `node scripts/build_zikr_release.js` afterward to pull
// the result back down to local assets.

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const DRY_RUN = process.argv.includes('--dry-run');

// 'prepend': merits text becomes the new first line of `data`, ahead of the
//   Bismillah/dua triplets - the same slot A4's intro paragraph occupies.
// 'append': merits text becomes a new closing paragraph - used for the two
//   entries (E152, E79) whose `data` already opens with narrative English
//   prose, where a citation reads more naturally as a footnote at the end.
const PLAN = {
  AA14: 'prepend',
  E45: 'prepend',
  E96: 'prepend',
  E84: 'prepend',
  E41: 'prepend',
  E63: 'prepend',
  E42: 'prepend',
  E152: 'append',
  E79: 'append',
};

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
  const serviceAccountPath = getServiceAccountPath();
  if (!serviceAccountPath) throw new Error('serviceAccountKey.json not found.');
  admin.initializeApp({
    credential: admin.credential.cert(require(path.resolve(serviceAccountPath))),
  });
  const db = admin.firestore();

  for (const [uid, mode] of Object.entries(PLAN)) {
    const localPath = path.join(__dirname, '..', 'assets', 'zikr', uid);
    const local = JSON.parse(fs.readFileSync(localPath, 'utf8'));

    const docRef = db.collection('zikr').doc(uid);
    const snap = await docRef.get();
    if (!snap.exists) throw new Error(`${uid}: no such Firestore doc`);
    const remote = snap.data();

    if ((remote.data || '') !== local.data) {
      throw new Error(`${uid}: Firestore 'data' has drifted from assets/zikr/${uid} - aborting, re-run build_zikr_release.js first`);
    }
    if ((remote.merits || '') !== (local.merits || '')) {
      throw new Error(`${uid}: Firestore 'merits' has drifted from assets/zikr/${uid} - aborting`);
    }
    if (!remote.merits || !remote.merits.trim()) {
      throw new Error(`${uid}: no merits field to fold`);
    }

    const merits = remote.merits.trim();
    const newData = mode === 'prepend'
      ? `${merits}\n${remote.data}`
      : `${remote.data}\n\n${merits}`;

    console.log(`${uid} (${mode}): merits ${merits.length} chars -> folded into data`);

    if (!DRY_RUN) {
      await docRef.update({
        data: newData,
        merits: admin.firestore.FieldValue.delete(),
      });
    }
  }

  console.log(DRY_RUN ? '\nDry run only - no writes made.' : '\nDone. Now run: node scripts/build_zikr_release.js');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
