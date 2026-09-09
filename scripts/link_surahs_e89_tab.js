// One-off migration: E89's "Surah al-Tawhid Before Sleep" tab mentions
// Surah al-Tawhid (twice) and Surah al-Kafirun by name but never linked
// them, unlike E79's data, which already uses the [label](uid) markdown
// link convention for its own surah references. Links all three mentions
// here to their zikr uids (A116 = Surah al-Ikhlaas / al-Tawhid, A113 =
// Surah al-Kafirun) and renames the tab's header line from "Surah al-Tawhid
// Before Sleep" to "Surahs before sleep", since the tab covers both surahs.
//
// Usage:
//   node scripts/link_surahs_e89_tab.js [--dry-run]

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const DRY_RUN = process.argv.includes('--dry-run');
const UID = 'E89';

const OLD_HEADER = 'Surah al-Tawhid Before Sleep';
const NEW_HEADER = 'Surahs before sleep';
const OLD_BODY =
  "Imam al-Sadiq (a.s.) said that whoever repeats Surah al-Tawhid one hundred times before sleep, Allah will forgive him the sins of fifty years; and that whoever recites Surah al-Kafirun and Surah al-Tawhid before sleep [is likewise rewarded].";
const NEW_BODY =
  "Imam al-Sadiq (a.s.) said that whoever repeats [Surah al-Tawhid](A116) one hundred times before sleep, Allah will forgive him the sins of fifty years; and that whoever recites [Surah al-Kafirun](A113) and [Surah al-Tawhid](A116) before sleep [is likewise rewarded].";

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

  const localPath = path.join(__dirname, '..', 'assets', 'zikr', UID);
  const local = JSON.parse(fs.readFileSync(localPath, 'utf8'));
  const oldTab = `${OLD_HEADER}\n${OLD_BODY}`;
  const tabIndex = (local.tabs || []).indexOf(oldTab);
  if (tabIndex === -1) {
    throw new Error(`${UID}: expected tab not found in assets/zikr/${UID} - it may have already changed`);
  }

  const docRef = db.collection('zikr').doc(UID);
  const snap = await docRef.get();
  if (!snap.exists) throw new Error(`${UID}: no such Firestore doc`);
  const remote = snap.data();
  const remoteTabs = remote.tabs || [];

  if (JSON.stringify(remoteTabs) !== JSON.stringify(local.tabs)) {
    throw new Error(`${UID}: Firestore 'tabs' has drifted from assets/zikr/${UID} - aborting, re-run build_zikr_release.js first`);
  }

  const newTabs = [...remoteTabs];
  newTabs[tabIndex] = `${NEW_HEADER}\n${NEW_BODY}`;

  console.log(`${UID}: tab ${tabIndex} header "${OLD_HEADER}" -> "${NEW_HEADER}"`);
  console.log(`New body:\n${NEW_BODY}`);

  if (!DRY_RUN) {
    await docRef.update({tabs: newTabs});
  }

  console.log(DRY_RUN ? '\nDry run only - no writes made.' : '\nDone. Now run: node scripts/build_zikr_release.js');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
