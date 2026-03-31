const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

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

  const zikrData = `${data?.data ?? ''}`;
  if (zikrData.trim()) {
    payload.data = zikrData;
  }

  const merits = `${data?.merits ?? ''}`;
  if (merits.trim()) {
    payload.merits = merits;
  }

  if (Array.isArray(data?.tabs)) {
    const tabs = data.tabs
      .map((tab) => `${tab ?? ''}`)
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

function removeStaleFiles(contentIds) {
  if (!fs.existsSync(CONTENT_OUTPUT_DIR)) return;

  const expected = new Set(contentIds);
  for (const fileName of fs.readdirSync(CONTENT_OUTPUT_DIR)) {
    if (fileName.startsWith('.')) continue;
    if (expected.has(fileName)) continue;
    fs.unlinkSync(path.join(CONTENT_OUTPUT_DIR, fileName));
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

  const index = {};
  const contentFiles = new Map();

  for (const uid of [...allDocs.keys()].sort()) {
    const data = allDocs.get(uid);
    if (!shouldIncludeInIndex(uid, data, allDocs)) {
      continue;
    }

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

  removeStaleFiles(contentFiles.keys());

  console.log(`Wrote ${Object.keys(index).length} index entries to ${INDEX_OUTPUT_PATH}`);
  console.log(`Wrote ${contentFiles.size} zikr files to ${CONTENT_OUTPUT_DIR}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
