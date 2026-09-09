// One-off migration: E89 ("Dua at Bedtime and at the time of waking up")
// crammed 7 hadith-linked items ("First: ...", "Second: ...", ... "Seventh:
// ...") into one undifferentiated `data` string. Splits it into the `tabs`
// pattern other zikrs already use (E60, D10, R1) - a short header line per
// item that the renderer turns into a clickable tab chip and hides from the
// body (see _getTabHeader / hideHeaderLine in zikr_content_viewer.dart) -
// so a reader can jump straight to the item they want.
//
// Usage:
//   node scripts/split_e89_into_tabs.js [--dry-run]
//
// Verifies the Firestore doc's current `data` matches assets/zikr/E89
// before writing, so drift since the last build_zikr_release.js pull aborts
// the run instead of silently clobbering it.

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const DRY_RUN = process.argv.includes('--dry-run');
const UID = 'E89';

const LABELS = [
  'Before Sleep',
  "The Prophet's Bedtime Dua",
  'Eleven Refuges',
  'Surah al-Tawhid Before Sleep',
  'To Wake for Night Prayer',
  'On Waking at Night',
  'Predawn Supplication',
];

const MARKER = /^(First|Second|Third|Fourth|Fifth|Sixth|Seventh):\s*/gm;

function getServiceAccountPath() {
  const envPath = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
  if (envPath && fs.existsSync(envPath)) return envPath;
  const candidates = [
    path.join(__dirname, 'serviceAccountKey.json'),
    path.join(__dirname, '..', 'serviceAccountKey.json'),
  ];
  return candidates.find((c) => fs.existsSync(c));
}

function splitIntoLabeledSegments(data) {
  const matches = [...data.matchAll(MARKER)];
  if (matches.length !== LABELS.length) {
    throw new Error(`Expected ${LABELS.length} ordinal markers, found ${matches.length}`);
  }
  const bounds = matches.map((m) => m.index).concat([data.length]);
  return matches.map((m, i) => {
    const bodyStart = m.index + m[0].length;
    const body = data.slice(bodyStart, bounds[i + 1]).trimEnd();
    return `${LABELS[i]}\n${body}`;
  });
}

async function main() {
  const serviceAccountPath = getServiceAccountPath();
  if (!serviceAccountPath) throw new Error('serviceAccountKey.json not found.');
  admin.initializeApp({
    credential: admin.credential.cert(require(path.resolve(serviceAccountPath))),
  });
  const db = admin.firestore();

  const localPath = path.join(__dirname, '..', 'assets', 'zikr', UID);
  const local = JSON.parse(fs.readFileSync(localPath, 'utf8'));

  const docRef = db.collection('zikr').doc(UID);
  const snap = await docRef.get();
  if (!snap.exists) throw new Error(`${UID}: no such Firestore doc`);
  const remote = snap.data();

  if ((remote.data || '') !== local.data) {
    throw new Error(`${UID}: Firestore 'data' has drifted from assets/zikr/${UID} - aborting, re-run build_zikr_release.js first`);
  }

  const segments = splitIntoLabeledSegments(remote.data);
  const [newData, ...tabs] = segments;

  console.log(`${UID}: splitting into 1 data + ${tabs.length} tabs:`);
  for (const seg of segments) {
    console.log(`  - ${seg.split('\n')[0]} (${seg.length} chars)`);
  }

  if (!DRY_RUN) {
    await docRef.update({data: newData, tabs});
  }

  console.log(DRY_RUN ? '\nDry run only - no writes made.' : '\nDone. Now run: node scripts/build_zikr_release.js');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
