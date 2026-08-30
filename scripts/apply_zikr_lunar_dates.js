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

  // --- Aamaal ---
  // R/S/X/Y/AA/AB/AC are Mafatih al-Jinan's month-by-month Aamaal chapters
  // (Muharram/Safar/Rajab/Sha'ban/Ramazan/Zilqad/Zilhajj respectively - the
  // months that traditionally have a dedicated Aamaal section). Dates below
  // come straight from each item's own title, cross-checked against
  // assets/events.json where it also links here. Whole-month items (no
  // single date) use the new "MM-*" pattern instead of being left unset, so
  // e.g. Dua-e-Iftetaah surfaces every night of Ramazan.
  //
  // Left out entirely: the location-based shrine ziyarats (AL/AI/AH/AG/AK/
  // AN/AJ/AE prefixes - Samarra/Kufa/Kazimayn/Karbala/Najaf/etc.), which
  // aren't tied to a calendar date at all; and a handful of ambiguous items
  // (X6 "first Friday of Rajab" - an ordinal weekday this format can't
  // express; AA1, AA9, AA21 - no single clear occasion). Also genuinely
  // missing from the corpus: events.json links "27-7"/"14-8"/three Ramazan
  // dates/"27-9" to X18/Y9/AA28/AA39, none of which exist any more (unlike
  // the G22/G15 cases above, there's no surviving item to redirect to -
  // this looks like deleted content, e.g. a dedicated Shab-e-Qadr Aamaal
  // page, rather than a renumbering).
  //
  // Items whose title is specifically the *night* of a date (not the date
  // itself) use the "N" prefix (see lib/utils/lunar_date_matcher.dart and
  // lib/utils/night_window.dart) - it only matches from that date's actual
  // Maghrib through the next Fajr, not the whole civil day, so e.g. Aamaal
  // of the Night of Arafah stops surfacing once the Day of Arafah's dawn
  // breaks. This replaced two conflicting ad hoc values already in
  // production - AC10 was "12-08" (the day *before*, i.e. an approximation
  // of "that night") and AC17 was "12-17" (same idea), while AC14 was
  // already "12-10" (the day itself, no adjustment) - all three now use the
  // same real mechanism instead of three different guesses.
  R1: '01-01', // 1st Night and Day of Moharram
  R4: '01-03', // The Third of Moharram
  R5: '01-09', // The Ninth of Moharram
  R6: 'N01-10', // The 10th Night of Moharram (Maghrib on the 9th through Fajr on the 10th)
  R7: '01-10', // The 10th of Moharram
  R9: '01-10', // Aamal of Ashoora
  S1: '02-*', // The Month of Safar
  S5: '02-20', // Arbaeen
  S7: '02-20', // Ziyarah on the day of Arbaeen
  X1: '07-*', // Importance of the month of Rajab and its Aamaal
  X2: '07-*', // General Aamaal in Rajab
  X3: '07-*', // Daily supplications of Rajab
  X4: '07-*', // Ziyarah Rajabiyah - recited throughout Rajab
  X5: '07-*', // Miscellaneous Aamaal for the Month of Rajab
  X7: 'N07-01', // First Night of Rajab (Maghrib on the last day of Jamadi II through Fajr on the 1st)
  Y3: '08-*', // Daily Salawat of Shaban
  Y4: '08-*', // Munajaat al Shabaniyyah - recited throughout Sha'ban
  AA2: '09-*', // Recitation of the Holy Qur'an in Ramazan
  AA3: '09-*', // Aamal to be performed only during (Ramazan) Night
  AA4: '09-*', // One Thousand Unit Prayers (spread across Ramazan)
  AA5: '09-*', // Duas after every obligatory Prayer, in Ramazan
  AA10: '09-*', // Dua-e-Iftetaah - every night of Ramazan
  AA11: '09-*', // Dua Baha - Ramadan Suhoor Dawn
  AA12: '09-*', // Dua-e-Abu Hamzah Sumali - Ramazan Suhoor
  AA13: '09-*', // Ya Uddati - Ramadan
  AA16: '09-*', // Aamal-e-Sahar in the Holy Month of Ramazan
  AB1: '11-*-0', // Zilqad - Sunday Namaz (Sunday=0)
  AB2: ['11-11', '11-15', '11-23'], // 11th, 15th & 23rd of Zilqad
  AB3: ['N11-25', '11-25'], // Night & Day of 25th Zilqad (The Spreading of the Earth)
  AB4: ['11-29', '11-30'], // The Last Day of Zilqad (29 or 30, depending on the year)
  AC1: '12-18', // Ziyarah on the Day of Ghadeer
  AC2: '12-18', // Another Ziyarah on the Day of Ghadeer
  AC3: ['10-01', '12-10'], // Ziyarah on the Id al-Fitr and Id al-Azha days
  AC4: '12-09', // Ziyarah on the day of Arafat
  AC5: [
    '12-01', '12-02', '12-03', '12-04', '12-05',
    '12-06', '12-07', '12-08', '12-09', '12-10',
  ], // First ten days of Zilhajj
  AC7: '12-01', // 1st Day of Zilhajj
  AC10: 'N12-09', // Aamaal of the Night of Arafah (Maghrib on the 8th through Fajr on the 9th)
  AC11: '12-09', // Aamaal of the Day of Arafah (9th Zilhajj)
  AC12: '12-09', // Dua of Imam Husayn (a.s.) on the Day of Arafah
  AC13: '12-09', // Comprehensive Ziyarat especially on the Day of Arafah
  AC14: 'N12-10', // The Night of Eid al-Azhaa (Qurban) (Maghrib on the 9th through Fajr on the 10th)
  AC15: '12-10', // The Day of Eid al-Azhaa (Qurban)
  AC16: '12-15', // The Fifteenth of Zilhajj
  AC17: 'N12-18', // Aamaal of the Night of Eid-e-Ghadeer (Maghrib on the 17th through Fajr on the 18th)
  AC18: '12-18', // Aamaal of the Day of Eid-e-Ghadeer
  AC20: '12-18', // Seegah of Brotherhood (Ukhuwwat) on the Day of Ghadeer
  AC21: '12-24', // The Day of Mubaahelah
  AC22: '12-25', // The Twenty-Fifth of Zilhajj
  AC23: ['12-29', '12-30'], // The Last Day of Zilhajj (29 or 30, depending on the year)
  AD4: ['10-01', '12-10'], // Eid Prayer - Eid al-Fitr and Eid al-Azha
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
