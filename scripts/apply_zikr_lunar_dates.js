// One-off helper to push the "day" (lunar date) field for a curated set of
// Dua (E-prefixed) zikrs into Firestore.
//
// assets/zikr.json already carries these same "day" values so the app's
// bundled index has them for the next release, but that file is normally
// *generated from* Firestore by build_zikr_release.js. Without also writing
// these values to Firestore, a future run of that script (or the in-app
// "Publish Index" action) would wipe the day field back out.
//
// Usage:
//   node scripts/apply_zikr_lunar_dates.js --dry-run   # preview only
//   node scripts/apply_zikr_lunar_dates.js --yes       # write to Firestore
//
// Afterwards, as an admin in the app, use Home > "Publish Index" so other
// admins pick up the change immediately, and re-run
// `node scripts/build_zikr_release.js` before the next release so the
// generated assets stay in sync with Firestore.
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const ZIKR_COLLECTION = 'zikr';

// Keep this in sync with the "day" values hand-added to assets/zikr.json.
const LUNAR_DATES = {
  E8: '01-10', // Dua Alqamah - 10th Muharram (Ashura)
  E26: '*-*-5', // Dua Simat - every Friday
  E27: '07-27', // Dua Mashlool - 27th Rajab
  E28: ['09-13', '09-14', '09-15'], // Dua Mujeer - Ayyam al-Beedh of Ramazan
  E29: ['09-01', '09-19', '09-21', '09-23', '*-*-5'], // Dua Jawshan al-Kabeer
  E31: ['08-15', '*-*-4'], // Dua Kumayl - 15th Sha'ban + every Thursday
  E34: ['10-01', '12-10', '12-18', '*-*-5'], // Dua e Nudbah - 3 Eids + Friday
  E144: '*-*-5', // Salawat Abul Hasan al-Zarrab al-Isfahani - every Friday
  E154: '*-*-5', // Dua-e-Ehtejaab - every Friday
};

const DRY_RUN = process.argv.includes('--dry-run');
const CONFIRMED = process.argv.includes('--yes');

function getServiceAccountPath() {
  const envPath = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
  if (envPath && fs.existsSync(envPath)) {
    return envPath;
  }

  const candidates = [
    path.join(__dirname, 'serviceAccountKey.json'),
    path.join(__dirname, '..', 'serviceAccountKey.json'),
  ];

  return candidates.find((candidate) => fs.existsSync(candidate));
}

function getServiceAccountFromEnv() {
  const rawJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (rawJson) {
    return JSON.parse(rawJson);
  }

  const base64Json = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (base64Json) {
    return JSON.parse(Buffer.from(base64Json, 'base64').toString('utf8'));
  }

  return null;
}

function getServiceAccount() {
  const envServiceAccount = getServiceAccountFromEnv();
  if (envServiceAccount) {
    return envServiceAccount;
  }

  const serviceAccountPath = getServiceAccountPath();
  if (!serviceAccountPath) {
    throw new Error(
      'Could not find service account credentials. Set FIREBASE_SERVICE_ACCOUNT_JSON, FIREBASE_SERVICE_ACCOUNT_BASE64, FIREBASE_SERVICE_ACCOUNT_KEY, or place serviceAccountKey.json in scripts/ or repo root.',
    );
  }

  return require(path.resolve(serviceAccountPath));
}

function dayValuesEqual(a, b) {
  const normalize = (value) =>
    (Array.isArray(value) ? value : [value]).map((v) => `${v}`.trim());
  const left = normalize(a ?? []);
  const right = normalize(b ?? []);
  return (
    left.length === right.length && left.every((v, i) => v === right[i])
  );
}

async function main() {
  if (!DRY_RUN && !CONFIRMED) {
    console.log('Preview only (pass --yes to write, or --dry-run to just preview):\n');
  }

  const admin_ = admin;
  admin_.initializeApp({ credential: admin_.credential.cert(getServiceAccount()) });
  const db = admin_.firestore();

  let changed = 0;
  let unchanged = 0;
  let missing = 0;

  for (const uid of Object.keys(LUNAR_DATES).sort()) {
    const day = LUNAR_DATES[uid];
    const ref = db.collection(ZIKR_COLLECTION).doc(uid);
    const snapshot = await ref.get();

    if (!snapshot.exists) {
      console.log(`⚠️  ${uid}: no such document in Firestore, skipping`);
      missing += 1;
      continue;
    }

    const current = snapshot.data()?.day;
    if (dayValuesEqual(current, day)) {
      console.log(`•  ${uid}: already set to ${JSON.stringify(day)}`);
      unchanged += 1;
      continue;
    }

    console.log(
      `${DRY_RUN || !CONFIRMED ? '→' : '✅'} ${uid}: ${JSON.stringify(current ?? null)} -> ${JSON.stringify(day)}`,
    );

    if (CONFIRMED && !DRY_RUN) {
      await ref.update({ day });
    }
    changed += 1;
  }

  console.log(
    `\n${changed} to change, ${unchanged} already correct, ${missing} missing.`,
  );
  if (!CONFIRMED || DRY_RUN) {
    console.log('Nothing was written. Re-run with --yes to apply.');
  } else {
    console.log(
      'Done. Now use the app\'s admin "Publish Index" action, and re-run ' +
        'node scripts/build_zikr_release.js before the next release.',
    );
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
