const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const USERS_COLLECTION = 'users';
const FAVORITES_COLLECTION = 'favorites';
const FAVORITES_DOC_ID = 'index';
const RTDB_FAVORITES_PATH = 'new_favs';
const DRY_RUN = process.argv.includes('--dry-run');

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

function canonicalizeFavoriteUid(uid, type) {
  const trimmedUid = `${uid ?? ''}`.trim();
  if (!trimmedUid) return '';
  if (type !== 0 || !trimmedUid.includes('|')) return trimmedUid;
  return trimmedUid.split('|').pop().trim();
}

function normalizeFavoriteEntry(value) {
  if (!value || typeof value !== 'object') return null;

  const rawType = Number(value.type ?? 0);
  const type = Number.isFinite(rawType) ? rawType : 0;
  if (type !== 0 && type !== 1) return null;
  const uid = canonicalizeFavoriteUid(value.uid, type);
  if (!uid) return null;

  return {uid, type};
}

function dedupeFavorites(entries) {
  const seen = new Set();
  const favorites = [];

  for (const entry of entries) {
    if (!entry) continue;
    const key = `${entry.type}:${entry.uid}`;
    if (seen.has(key)) continue;
    seen.add(key);
    favorites.push(entry);
  }

  return favorites;
}

function parseRtdbFavorites(value) {
  if (value == null) return [];

  let parsed = value;
  if (typeof value === 'string') {
    try {
      parsed = JSON.parse(value);
    } catch (error) {
      console.warn(`Skipping malformed RTDB JSON: ${error.message}`);
      return [];
    }
  }

  if (!Array.isArray(parsed)) {
    return [];
  }

  return dedupeFavorites(parsed.map(normalizeFavoriteEntry));
}

function parseFirestoreFavorites(data) {
  if (!data || !Array.isArray(data.entries)) {
    return [];
  }

  return dedupeFavorites(data.entries.map(normalizeFavoriteEntry));
}

async function main() {
  const serviceAccountPath = getServiceAccountPath();
  if (!serviceAccountPath) {
    throw new Error(
      'Could not find serviceAccountKey.json. Set FIREBASE_SERVICE_ACCOUNT_KEY or place the file in scripts/ or repo root.',
    );
  }

  const serviceAccount = require(path.resolve(serviceAccountPath));
  const databaseURL =
    process.env.FIREBASE_DATABASE_URL ||
    `https://${serviceAccount.project_id}.firebaseio.com`;

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL,
  });

  const db = admin.firestore();
  const rtdb = admin.database();

  console.log(
    `Reading legacy favorites from RTDB path "${RTDB_FAVORITES_PATH}" using ${DRY_RUN ? 'dry-run mode' : 'write mode'}...`,
  );

  const snapshot = await rtdb.ref(RTDB_FAVORITES_PATH).once('value');
  const allUsers = snapshot.val();

  if (!allUsers || typeof allUsers !== 'object') {
    console.log('No RTDB favorites found. Nothing to migrate.');
    return;
  }

  let migratedUsers = 0;
  let skippedUsers = 0;
  let totalFavorites = 0;

  for (const [userId, rawFavorites] of Object.entries(allUsers)) {
    const legacyFavorites = parseRtdbFavorites(rawFavorites);
    if (legacyFavorites.length === 0) {
      skippedUsers++;
      continue;
    }

    const docRef = db
      .collection(USERS_COLLECTION)
      .doc(userId)
      .collection(FAVORITES_COLLECTION)
      .doc(FAVORITES_DOC_ID);

    const existingSnapshot = await docRef.get();
    const existingFavorites = parseFirestoreFavorites(existingSnapshot.data());
    const mergedFavorites = dedupeFavorites([...existingFavorites, ...legacyFavorites]);

    totalFavorites += mergedFavorites.length;

    if (DRY_RUN) {
      console.log(
        `[dry-run] ${userId}: ${legacyFavorites.length} RTDB favorites -> ${mergedFavorites.length} Firestore favorites`,
      );
      migratedUsers++;
      continue;
    }

    await docRef.set({
      version: 2,
      entries: mergedFavorites,
      migratedFromRtdbAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    console.log(
      `Migrated ${legacyFavorites.length} RTDB favorites for ${userId} -> ${mergedFavorites.length} Firestore favorites`,
    );
    migratedUsers++;
  }

  console.log('');
  console.log(`Users migrated: ${migratedUsers}`);
  console.log(`Users skipped: ${skippedUsers}`);
  console.log(`Favorites written: ${totalFavorites}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
