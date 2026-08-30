// One-off helper to push the "day" (lunar date) field for a curated set of
// Dua (E-prefixed) and Ziyarat (G-prefixed) zikrs into Firestore.
//
// assets/zikr.json is the app's bundled index and is what would normally
// need these same "day" values, but that file is *generated from* Firestore
// by build_zikr_release.js. Editing it by hand would just get overwritten by
// the next regeneration, so this script writes to Firestore directly instead
// - the actual source of truth - and leaves assets/zikr.json alone.
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

const LUNAR_DATES = {
  // --- Duas ---
  E8: '01-10', // Dua Alqamah - 10th Muharram (Ashura)
  E26: '*-*-5', // Dua Simat - every Friday
  E27: '07-27', // Dua Mashlool - 27th Rajab
  E28: ['09-13', '09-14', '09-15'], // Dua Mujeer - Ayyam al-Beedh of Ramazan
  E29: ['09-01', '09-19', '09-21', '09-23', '*-*-5'], // Dua Jawshan al-Kabeer
  E31: ['08-15', '*-*-4'], // Dua Kumayl - 15th Sha'ban + every Thursday
  E34: ['10-01', '12-10', '12-18', '*-*-5'], // Dua e Nudbah - 3 Eids + Friday
  E144: '*-*-5', // Salawat Abul Hasan al-Zarrab al-Isfahani - every Friday
  E154: '*-*-5', // Dua-e-Ehtejaab - every Friday

  // --- Ziyarats ---
  // Dates below are taken from assets/events.json (the app's own Hijri
  // calendar of anniversaries), converted from its "day-month" keys to
  // "MM-DD". G4 (Ziyarat-e-Ashoora) and G6 (Ziyarat e Waaresa) are skipped
  // since they're already hardcoded into Today's Recitation every day.
  //
  // Two of events.json's own G-links are stale (numbering drifted since it
  // was written) and were corrected here instead of copied as-is:
  //   - "8-3"/"8-4" (Imam Hasan Askari's dates) point to G22, which no
  //     longer exists; redirected to G71, the current Imam Hasan Askari
  //     ziyarat.
  //   - "17-3" (the Prophet's birth) points to G15, which is actually
  //     "Ziyarat of Saturday" - unrelated. Redirected to G50, "Ziyarat e
  //     Hazrat Rasul e Khuda" (Ziyarat of the Messenger of Allah), the only
  //     ziyarat for the Prophet himself. G15 is left untouched.
  G50: '03-17', // Ziyarat e Hazrat Rasul e Khuda - Prophet's birth, 17 Rabi al-Awwal (redirected from stale G15 link)
  G51: ['07-13', '09-21'], // Imam Ali - birth 13 Rajab, martyrdom 21 Ramazan
  G52: ['05-13', '06-03', '06-20'], // Janab-e-Fatima Zahra - death (2 riwayat) + birth
  G53: ['02-28', '09-15'], // Imam Hasan - martyrdom 28 Safar, birth 15 Ramazan
  G54: '08-03', // Imam Husain - birth 3 Sha'ban
  G55: '08-11', // Ali Akbar - birth 11 Sha'ban
  G56: '08-07', // Shohadaa-e-Karbala (collective) - linked from Qasim ibn-e-Hasan's birth, 7 Sha'ban; no dedicated Qasim ziyarat exists
  G57: '08-04', // Hazrat Abbas - birth 4 Sha'ban
  G64: ['01-25', '05-15', '08-05'], // Imam Zainul Abideen - martyrdom 25 Muharram, birth (2 riwayat)
  G65: ['07-01', '12-07'], // Imam Mohammad Baqir - birth 1 Rajab, martyrdom 7 Zilhajj
  G66: '10-25', // Imam Jafar Sadiq - martyrdom 25 Shawwal
  G67: ['02-07', '07-25'], // Imam Musa Kazim - birth 7 Safar, martyrdom 25 Rajab
  G68: ['02-17', '02-29', '11-11', '11-23'], // Imam Ali Raza - martyrdom (2 riwayat) + birth/martyrdom in Zilqad
  G69: ['07-10', '11-29'], // Imam Mohammad Taqi - birth 10 Rajab, martyrdom 29 Zilqad
  G70: ['07-02', '07-03', '07-05', '12-15'], // Imam Ali Naqi - birth (x2), martyrdom (Rajab), birth (Zilhajj riwayat)
  G71: ['03-08', '04-08'], // Imam Hasan Askari - martyrdom 8 Rabi I, birth 8 Rabi II (redirected from stale G22 link)
  G72: '08-15', // Imam Mahdi (a.t.f.s.) - birth 15 Sha'ban
  G73: ['05-05', '07-15', '08-01'], // Janab-e-Zainab - death 15 Rajab, birth (2 riwayat)
  G75: '12-09', // Ziyarat of Imam Husain on the Day of Arafah - 9th Zilhajj (from its own title, not in events.json)
  G78: ['03-04', '04-10', '11-01'], // Hazrat Masooma-e-Qum - birth 1 Zilqad, death (2 riwayat)
  G79: ['03-25', '07-26', '09-07'], // Hazrat Abu Talib - death (3 riwayat)
  G80: '03-10', // Hazrat Abdul Muttalib - death 10 Rabi I
  G81: '06-13', // Janab-e-Ummul Baneen - death 13 Jamadi II
  G82: ['02-10', '07-20'], // Janab-e-Sakina - martyrdom 10 Safar, birth 20 Rajab
  G83: '01-10', // Ziyaarat-e-Aashoora Ghair Ma'roofah - 10th Muharram (Ashura, from its own title)
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
