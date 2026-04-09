const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const {
  normalizeZikrText,
  normalizeZikrTextList,
} = require('./zikr_text_normalization');

const ZIKR_COLLECTION = 'zikr';
const INDEX_OUTPUT_PATH = path.join(__dirname, '..', 'assets', 'zikr.json');
const CONTENT_OUTPUT_DIR = path.join(__dirname, '..', 'assets', 'zikr');
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

function normalizeSlug(value) {
  return `${value ?? ''}`
    .toLowerCase()
    .replace(/[^\w\s-]/g, ' ')
    .replace(/[_\s]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

function normalizeSlugAliases(values, exclude = '') {
  if (!Array.isArray(values)) return [];

  const aliases = [];
  const seen = new Set();
  for (const value of values) {
    const alias = normalizeSlug(value);
    if (!alias || alias === exclude || seen.has(alias)) {
      continue;
    }
    seen.add(alias);
    aliases.push(alias);
  }
  return aliases;
}

function hasPrimaryData(data) {
  return `${data?.data ?? ''}`.trim().length > 0;
}

function hasTabData(data) {
  return Array.isArray(data?.tabs) &&
    data.tabs.some((tab) => `${tab ?? ''}`.trim().length > 0);
}

function hasRenderableContent(data) {
  return hasPrimaryData(data) || hasTabData(data);
}

function shouldIncludeInIndex(uid, data, allDocs) {
  const title = `${data?.title ?? ''}`.trim();
  if (!title) return false;

  if (uid.includes('|')) {
    const canonicalUid = uid.split('|').pop().trim();
    const canonicalDoc = allDocs.get(canonicalUid);
    if (!canonicalDoc || !hasRenderableContent(canonicalDoc)) {
      return false;
    }
  }

  return hasRenderableContent(data) || uid.includes('~') || uid.includes('|');
}

function getListTableName(itemUid) {
  let tableName = `${itemUid ?? ''}`.trim();
  if (tableName === 'D1') tableName = 'D';

  tableName = tableName
    .replace(/[0-9].*/, '')
    .replace(/[A-Z].*~/, '');

  if (tableName.includes('|')) {
    tableName = tableName
      .split('|')[0]
      .replace(/[0-9].*/, '');
  }

  return tableName;
}

function parentHasVisibleChildren(uid, includedUids) {
  if (!uid.includes('~')) return true;

  const childSeed = uid.split('~')[1]?.trim();
  const tableName = getListTableName(childSeed);
  if (!tableName) return false;

  for (const candidateUid of includedUids) {
    if (candidateUid === uid) continue;

    if (
      tableName === candidateUid.split('~')[0] ||
      tableName === candidateUid.replace(/[0-9].*/, '')
    ) {
      return true;
    }
  }

  return false;
}

function buildIndexEntry(data) {
  const entry = {
    title: `${data?.title ?? ''}`.trim(),
  };

  if (typeof data?.order === 'number' && Number.isFinite(data.order)) {
    entry.order = data.order;
  }

  const slug = normalizeSlug(data?.slug);
  if (slug) {
    entry.slug = slug;
  }

  const slugAliases = normalizeSlugAliases(data?.slugAliases, slug);
  if (slugAliases.length > 0) {
    entry.slugAliases = slugAliases;
  }

  return entry;
}

function shouldWriteContentFile(uid, data) {
  return !uid.includes('~') && !uid.includes('|') && hasRenderableContent(data);
}

function buildContentPayload(data) {
  const payload = {
    title: `${data?.title ?? ''}`.trim(),
  };

  const code = `${data?.code ?? ''}`;
  if (code.trim()) {
    payload.code = code;
  }

  const zikrData = normalizeZikrText(data?.data);
  if (zikrData.trim()) {
    payload.data = zikrData;
  }

  const merits = normalizeZikrText(data?.merits);
  if (merits.trim()) {
    payload.merits = merits;
  }

  if (Array.isArray(data?.tabs)) {
    const tabs = normalizeZikrTextList(data.tabs)
      .filter((tab) => tab.trim().length > 0);
    if (tabs.length > 0) {
      payload.tabs = tabs;
    }
  }

  return payload;
}

function sortObjectByKey(input) {
  const output = {};
  for (const key of Object.keys(input).sort()) {
    output[key] = input[key];
  }
  return output;
}

function listGeneratedFiles(directoryPath) {
  if (!fs.existsSync(directoryPath)) return [];

  return fs.readdirSync(directoryPath).filter((fileName) => {
    if (fileName.startsWith('.')) return false;
    return fs.statSync(path.join(directoryPath, fileName)).isFile();
  });
}

function removeStaleFiles(contentIds) {
  if (!fs.existsSync(CONTENT_OUTPUT_DIR)) return;

  const expected = new Set(contentIds);
  for (const fileName of listGeneratedFiles(CONTENT_OUTPUT_DIR)) {
    if (expected.has(fileName)) continue;
    fs.rmSync(path.join(CONTENT_OUTPUT_DIR, fileName), {force: true});
  }
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

  const allDocs = new Map();
  snapshot.forEach((doc) => {
    allDocs.set(doc.id, doc.data());
  });

  const includedUids = new Set();
  for (const uid of [...allDocs.keys()].sort()) {
    const data = allDocs.get(uid);
    if (shouldIncludeInIndex(uid, data, allDocs)) {
      includedUids.add(uid);
    }
  }

  let prunedParentCount = 0;
  let removedParentInPass = true;
  while (removedParentInPass) {
    removedParentInPass = false;

    for (const uid of [...includedUids]) {
      if (!uid.includes('~')) continue;
      if (parentHasVisibleChildren(uid, includedUids)) continue;

      includedUids.delete(uid);
      prunedParentCount += 1;
      removedParentInPass = true;
    }
  }

  const index = {};
  const contentFiles = new Map();
  for (const uid of [...includedUids].sort()) {
    const data = allDocs.get(uid);
    index[uid] = buildIndexEntry(data);

    if (shouldWriteContentFile(uid, data)) {
      contentFiles.set(uid, buildContentPayload(data));
    }
  }

  if (DRY_RUN) {
    console.log(
      JSON.stringify(
        {
          indexCount: Object.keys(index).length,
          contentFileCount: contentFiles.size,
          prunedParentCount,
          indexOutputPath: INDEX_OUTPUT_PATH,
          contentOutputDir: CONTENT_OUTPUT_DIR,
        },
        null,
        2,
      ),
    );
    return;
  }

  fs.mkdirSync(CONTENT_OUTPUT_DIR, {recursive: true});
  removeStaleFiles(contentFiles.keys());
  fs.writeFileSync(
    INDEX_OUTPUT_PATH,
    `${JSON.stringify(sortObjectByKey(index), null, 2)}\n`,
    'utf8',
  );

  for (const [uid, payload] of contentFiles.entries()) {
    fs.writeFileSync(
      path.join(CONTENT_OUTPUT_DIR, uid),
      `${JSON.stringify(payload, null, 2)}\n`,
      'utf8',
    );
  }

  console.log(`Wrote ${Object.keys(index).length} index entries to ${INDEX_OUTPUT_PATH}`);
  console.log(`Wrote ${contentFiles.size} zikr files to ${CONTENT_OUTPUT_DIR}`);
  console.log(`Pruned ${prunedParentCount} empty parent index entries`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
