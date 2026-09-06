const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const credPath = path.join(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(credPath)) {
  console.error(`Error: Service account key not found at ${credPath}`);
  process.exit(1);
}

const serviceAccount = require(credPath);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const ZIKR_DIR = path.join(__dirname, '..', 'assets', 'zikr');

async function syncSurahs() {
  console.log("Syncing all 114 Surahs to Firestore 'zikr' collection...");
  let synced = 0;

  for (let s = 1; s <= 114; s++) {
    const docId = `A${s + 4}`;
    const filePath = path.join(ZIKR_DIR, docId);
    
    if (!fs.existsSync(filePath)) {
      console.warn(`File ${filePath} does not exist, skipping.`);
      continue;
    }

    const content = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const docRef = db.collection('zikr').doc(docId);
    
    await docRef.update({
      data: content.data,
      code: content.code || '012'
    });

    synced++;
    if (synced % 10 === 0 || synced === 114) {
      console.log(`Synced ${synced}/114 Surahs (latest: ${docId} - ${content.title})`);
    }
  }

  console.log("\n============================================================");
  console.log(`SUCCESS: Synced all ${synced} Quran Surahs to Firestore!`);
  console.log("============================================================");
}

syncSurahs().catch(console.error);
