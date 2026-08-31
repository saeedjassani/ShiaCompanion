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
const ALLOW_STALE_ON_ERROR = process.argv.includes('--allow-stale-on-error');

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
    try {
      return JSON.parse(rawJson);
    } catch (error) {
      throw new Error(`FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON: ${error.message}`);
    }
  }

  const base64Json = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (base64Json) {
    try {
      return JSON.parse(Buffer.from(base64Json, 'base64').toString('utf8'));
    } catch (error) {
      throw new Error(`FIREBASE_SERVICE_ACCOUNT_BASE64 is not valid JSON: ${error.message}`);
    }
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

function normalizeSlug(value) {
  return `${value ?? ''}`
    .toLowerCase()
    .replace(/[^\w\s-]/g, ' ')
    .replace(/[_\s]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

function slugifyTitle(title) {
  return normalizeSlug(title);
}

function slugifyUid(uid) {
  return `${uid ?? ''}`
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

function buildSlugSeed({uid, title, rawSlug}) {
  const preferredSlug = normalizeSlug(rawSlug);
  if (preferredSlug) return preferredSlug;

  const titleSlug = slugifyTitle(title);
  if (titleSlug) return titleSlug;

  return slugifyUid(uid);
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

function isSlugAvailable(slugOwners, slug, currentUid) {
  const owner = slugOwners.get(slug);
  return owner == null || owner === currentUid;
}

function makeUniqueSlug(slugOwners, baseSlug, currentUid) {
  const normalizedBase = normalizeSlug(baseSlug);
  const fallbackBase = normalizedBase || (currentUid == null ? 'zikr' : slugifyUid(currentUid));

  if (isSlugAvailable(slugOwners, fallbackBase, currentUid)) {
    return fallbackBase;
  }

  let suffix = 2;
  while (true) {
    const candidate = `${fallbackBase}-${suffix}`;
    if (isSlugAvailable(slugOwners, candidate, currentUid)) {
      return candidate;
    }
    suffix += 1;
  }
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

function buildIndexEntry(data, resolvedSlugData) {
  const entry = {
    title: `${data?.title ?? ''}`.trim(),
  };

  if (typeof data?.order === 'number' && Number.isFinite(data.order)) {
    entry.order = data.order;
  }

  const slug = resolvedSlugData.slug;
  if (slug) {
    entry.slug = slug;
  }

  const slugAliases = resolvedSlugData.slugAliases;
  if (slugAliases.length > 0) {
    entry.slugAliases = slugAliases;
  }

  const day = normalizeDayPatterns(data?.day);
  if (day != null) {
    entry.day = day;
  }

  return entry;
}

function normalizeDayPatterns(value) {
  if (typeof value === 'string') {
    const pattern = value.trim();
    return pattern || null;
  }

  if (Array.isArray(value)) {
    const patterns = value
      .map((pattern) => `${pattern ?? ''}`.trim())
      .filter((pattern) => pattern.length > 0);
    return patterns.length > 0 ? patterns : null;
  }

  return null;
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

  const audio = buildAudioPayload(data?.audio);
  if (audio.length > 0) {
    payload.audio = audio;
  }

  return payload;
}

/**
 * Recitation tracks hosted by duas.org, hot-linked rather than mirrored, so
 * what ships is a URL and a label. Only https is accepted: the app is served
 * over https on web and iOS blocks cleartext, so an http URL would fail at
 * play time on every platform rather than only some.
 */
function buildAudioPayload(rawAudio) {
  if (!Array.isArray(rawAudio)) return [];

  const seen = new Set();
  const tracks = [];
  for (const entry of rawAudio) {
    const url = `${entry?.url ?? ''}`.trim();
    if (!url || !url.startsWith('https://')) continue;
    if (seen.has(url)) continue;
    seen.add(url);

    const track = {url};
    const label = `${entry?.label ?? ''}`.trim();
    if (label) track.label = label;
    tracks.push(track);
  }
  return tracks;
}

function buildResolvedSlugData(includedUids, allDocs) {
  const slugOwners = new Map();
  const resolvedByUid = new Map();

  for (const uid of [...includedUids].sort()) {
    const data = allDocs.get(uid);
    const explicitSlug = normalizeSlug(data?.slug);
    const explicitAliases = normalizeSlugAliases(data?.slugAliases, explicitSlug);

    if (explicitSlug) {
      slugOwners.set(explicitSlug, uid);
    }
    for (const alias of explicitAliases) {
      if (!slugOwners.has(alias)) {
        slugOwners.set(alias, uid);
      }
    }

    resolvedByUid.set(uid, {
      slug: explicitSlug,
      slugAliases: explicitAliases,
    });
  }

  for (const uid of [...includedUids].sort()) {
    const data = allDocs.get(uid);
    const resolved = resolvedByUid.get(uid);
    if (resolved?.slug) continue;

    const generatedSlug = makeUniqueSlug(
      slugOwners,
      buildSlugSeed({
        uid,
        title: `${data?.title ?? ''}`.trim(),
        rawSlug: data?.slug,
      }),
      uid,
    );

    slugOwners.set(generatedSlug, uid);
    resolvedByUid.set(uid, {
      slug: generatedSlug,
      slugAliases: resolved?.slugAliases ?? [],
    });
  }

  return resolvedByUid;
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
  const serviceAccount = getServiceAccount();
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

  const resolvedSlugData = buildResolvedSlugData(includedUids, allDocs);
  const index = {};
  const contentFiles = new Map();
  for (const uid of [...includedUids].sort()) {
    const data = allDocs.get(uid);
    index[uid] = buildIndexEntry(data, resolvedSlugData.get(uid) ?? {
      slug: '',
      slugAliases: [],
    });

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
  if (ALLOW_STALE_ON_ERROR) {
    console.warn('Unable to refresh zikr release assets from Firestore.');
    console.warn('Continuing with committed assets so the web build and deploy can proceed.');
    console.warn(error?.stack || error);
    process.exit(0);
  }

  console.error(error);
  process.exit(1);
});
