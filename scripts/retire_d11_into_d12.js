// One-off migration: D11 ("Taqeebaat e Namaz e Isha (2)") and D12 ("Dua
// After Namaz For Seeking Sustenance") are the same dua, restored
// independently during the missing-zikr recovery effort (see
// scripts/RESTORING_MISSING_ZIKRS.md) - D12's version cuts off one triplet
// early. This:
//   1. Extends D12's final triplet ("O the Living, O the Everlasting.") to
//      the fuller ending D11 has, in D12's own orthography (Farsi yeh), and
//      adds the closing "by Your mercy..." triplet D12 was missing.
//   2. Deletes the D11 Firestore doc - it's retired. Anyone with it
//      favorited or deep-linked now gets redirected to D12 by the
//      retiredZikrRedirects map (lib/data/retired_zikr_redirects.dart),
//      the same mechanism covering the 9 other pending duplicate UIDs.
//
// The splice below is anchored entirely on the ASCII transliteration text
// (safe to hand-type) rather than the Arabic itself, and pulls every
// Arabic line straight out of the source strings - hand-retyping the
// diacritics directly corrupted a shadda/damma on the first attempt at
// this script.
//
// Usage:
//   node scripts/retire_d11_into_d12.js [--dry-run]

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const DRY_RUN = process.argv.includes('--dry-run');

function getServiceAccountPath() {
  const envPath = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
  if (envPath && fs.existsSync(envPath)) return envPath;
  const candidates = [
    path.join(__dirname, 'serviceAccountKey.json'),
    path.join(__dirname, '..', 'serviceAccountKey.json'),
  ];
  return candidates.find((c) => fs.existsSync(c));
}

// Arabic Yeh (U+064A) -> Farsi Yeh (U+06CC), matching the substitution
// already present throughout the rest of D12's text.
function toFarsiYeh(s) {
  return s.replace(/ي/g, 'ی');
}

function buildNewD12Data(d11Data, d12Data) {
  const d11Lines = d11Data.split('\n');
  const d12Lines = d12Data.split('\n');

  const i11 = d11Lines.indexOf(
    'YAA HAYYO YAA QAYYOOMO YAA QAWIYYO YAA GHANIYYO YAA MALIYYO YAA WAFIYYO',
  );
  const j11 = d11Lines.indexOf('BERAHMATEKA YAA ARHAMAR RAAHIMEEN');
  if (i11 === -1 || j11 !== i11 + 3 || j11 + 1 !== d11Lines.length - 1) {
    throw new Error('D11: expected closing triplets not found in the expected shape');
  }

  const newEnding = [
    `${toFarsiYeh(d11Lines[i11 - 1])} `,
    d11Lines[i11],
    'O the Living, O the Self-Subsisting, O the Strong, O the Self-Sufficient, O the Wealthy, O the Faithful,',
    `${toFarsiYeh(d11Lines[j11 - 1])} `,
    d11Lines[j11],
    d11Lines[j11 + 1],
  ].join('\n');

  const i12 = d12Lines.indexOf('YAA HAYYO YAA QAYYOOMO');
  if (i12 === -1 || i12 !== d12Lines.length - 2) {
    throw new Error('D12: expected final triplet not found in the expected shape');
  }
  const oldEnding = d12Lines.slice(i12 - 1).join('\n');
  if (!d12Data.endsWith(oldEnding)) {
    throw new Error('D12: computed old ending does not match the tail of data');
  }

  return d12Data.slice(0, -oldEnding.length) + newEnding;
}

async function main() {
  const serviceAccountPath = getServiceAccountPath();
  if (!serviceAccountPath) throw new Error('serviceAccountKey.json not found.');
  admin.initializeApp({
    credential: admin.credential.cert(require(path.resolve(serviceAccountPath))),
  });
  const db = admin.firestore();

  const d12LocalPath = path.join(__dirname, '..', 'assets', 'zikr', 'D12');
  const d12Local = JSON.parse(fs.readFileSync(d12LocalPath, 'utf8'));
  const d11LocalPath = path.join(__dirname, '..', 'assets', 'zikr', 'D11');
  const d11Local = JSON.parse(fs.readFileSync(d11LocalPath, 'utf8'));

  const d12Ref = db.collection('zikr').doc('D12');
  const d12Snap = await d12Ref.get();
  if (!d12Snap.exists) throw new Error('D12: no such Firestore doc');
  const d12Remote = d12Snap.data();
  if ((d12Remote.data || '') !== d12Local.data) {
    throw new Error("D12: Firestore 'data' has drifted from assets/zikr/D12 - aborting, re-run build_zikr_release.js first");
  }

  const d11Ref = db.collection('zikr').doc('D11');
  const d11Snap = await d11Ref.get();
  if (!d11Snap.exists) throw new Error('D11: no such Firestore doc');
  const d11Remote = d11Snap.data();
  if ((d11Remote.data || '') !== d11Local.data) {
    throw new Error("D11: Firestore 'data' has drifted from assets/zikr/D11 - aborting");
  }

  const newD12Data = buildNewD12Data(d11Remote.data, d12Remote.data);
  console.log('D12: extending final triplet + adding closing triplet. New ending:');
  console.log(newD12Data.slice(-500));
  console.log('\nD11: deleting Firestore doc (retired -> redirects to D12)');

  if (!DRY_RUN) {
    await d12Ref.update({data: newD12Data});
    await d11Ref.delete();
  }

  console.log(DRY_RUN ? '\nDry run only - no writes made.' : '\nDone. Now run: node scripts/build_zikr_release.js');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
