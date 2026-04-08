const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const {
  normalizeZikrText,
  normalizeZikrTextList,
} = require('./zikr_text_normalization');

const ZIKR_COLLECTION = 'zikr';
const DRY_RUN = process.argv.includes('--dry-run');
const INCLUDE_TITLE = process.argv.includes('--include-title');
const BATCH_LIMIT = 400;

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

function normalizeField(value) {
  const normalized = normalizeZikrText(value);
  return normalized === `${value ?? ''}` ? null : normalized;
}

function normalizeTabsField(value) {
  if (!Array.isArray(value)) return null;

  const normalized = normalizeZikrTextList(value);
  const didChange = normalized.some(
    (entry, index) => entry !== `${value[index] ?? ''}`,
  );
  return didChange ? normalized : null;
}

async function commitBatch(batchState) {
  if (DRY_RUN || batchState.count === 0) {
    return;
  }

  await batchState.batch.commit();
  batchState.batch = admin.firestore().batch();
  batchState.count = 0;
}

async function main() {
  const serviceAccountPath = getServiceAccountPath();
  if (!serviceAccountPath) {
    throw new Error(
      'Could not find serviceAccountKey.json. Set FIREBASE_SERVICE_ACCOUNT_KEY or place the file in scripts/ or repo root.',
    );
  }

  const serviceAccount = require(path.resolve(serviceAccountPath));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  const db = admin.firestore();
  const snapshot = await db.collection(ZIKR_COLLECTION).get();
  const batchState = {
    batch: db.batch(),
    count: 0,
  };

  let changedDocs = 0;
  let updatedFields = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const update = {};

    const normalizedData = normalizeField(data.data);
    if (normalizedData != null) {
      update.data = normalizedData;
    }

    const normalizedMerits = normalizeField(data.merits);
    if (normalizedMerits != null) {
      update.merits = normalizedMerits;
    }

    const normalizedTabs = normalizeTabsField(data.tabs);
    if (normalizedTabs != null) {
      update.tabs = normalizedTabs;
    }

    if (INCLUDE_TITLE) {
      const normalizedTitle = normalizeField(data.title);
      if (normalizedTitle != null) {
        update.title = normalizedTitle;
      }
    }

    const fieldNames = Object.keys(update);
    if (fieldNames.length === 0) {
      continue;
    }

    changedDocs++;
    updatedFields += fieldNames.length;

    if (DRY_RUN) {
      console.log(`[dry-run] ${doc.id}: ${fieldNames.join(', ')}`);
      continue;
    }

    batchState.batch.update(doc.ref, update);
    batchState.count++;

    if (batchState.count >= BATCH_LIMIT) {
      await commitBatch(batchState);
    }
  }

  await commitBatch(batchState);

  console.log(
    `${DRY_RUN ? 'Would update' : 'Updated'} ${changedDocs} zikr documents across ${updatedFields} fields.`,
  );
  if (INCLUDE_TITLE) {
    console.log('Title normalization was enabled.');
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
