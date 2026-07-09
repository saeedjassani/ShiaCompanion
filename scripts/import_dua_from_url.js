const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const admin = require('firebase-admin');
const axios = require('axios');

const ZIKR_COLLECTION = 'zikr';

function printUsage() {
  console.log(`Usage:
  node import_dua_from_url.js --url <duas.org url> --uid <uid> [options]

  Modes:
    (default)            Dry run. Parse the page and print the document that
                         would be stored. Nothing is written.
    --store             Write the parsed document to Firestore (zikr/<uid>).

  Options:
    --url <url>         Source page URL (duas.org mobile page).
    --uid <uid>         Firestore document id, e.g. D13.
    --title <title>     Override the dua title (defaults to cleaned page title).
    --slug <slug>       Override the URL slug (defaults to slugified title).
    --merits <text>     Optional merits/notes text.
    --regenerate        After storing, regenerate local assets (assets/zikr.*)
                        by running build_zikr_release.js. Implies --store.
    --yes               Skip the confirmation prompt when storing.
`);
}

function getServiceAccount() {
  const envJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (envJson) return JSON.parse(envJson);

  const envB64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (envB64) return JSON.parse(Buffer.from(envB64, 'base64').toString('utf8'));

  const candidates = [
    path.join(__dirname, 'serviceAccountKey.json'),
    path.join(__dirname, '..', 'serviceAccountKey.json'),
  ];
  const found = candidates.find((c) => fs.existsSync(c));
  if (!found) {
    throw new Error(
      'No service account found. Set FIREBASE_SERVICE_ACCOUNT_JSON/BASE64 or place serviceAccountKey.json.',
    );
  }
  return require(path.resolve(found));
}

function normalizeSlug(value) {
  return `${value ?? ''}`
    .toLowerCase()
    .replace(/[^\w\s-]/g, ' ')
    .replace(/[_\s]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

function stripHtmlTags(value) {
  return `${value ?? ''}`
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

function cleanTitle(rawTitle) {
  return `${rawTitle ?? ''}`
    .replace(/Imam Mahdi \(ajtfs\)/gi, '')
    .replace(/Duas?\.org/gi, '')
    .replace(/\s*[-–—]\s*Imam Mahdi.*$/i, '')
    .replace(/\s+/g, ' ')
    .replace(/\s*[-–—]\s*$/, '')
    .trim();
}

async function fetchHtml(url) {
  try {
    const response = await axios.get(url, {
      responseType: 'text',
      timeout: 30000,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
          '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
        Accept: 'text/html,application/xhtml+xml',
      },
    });
    if (response.status < 200 || response.status >= 300) {
      throw new Error(`Request failed with HTTP ${response.status}`);
    }
    return response.data;
  } catch (error) {
    if (error.response) {
      throw new Error(`Failed to fetch ${url}: HTTP ${error.response.status}`);
    }
    throw new Error(`Failed to fetch ${url}: ${error.message}`);
  }
}

function extractTitle(html) {
  const match = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  if (match) return cleanTitle(stripHtmlTags(match[1]));
  return '';
}

function extractPaneOne(html) {
  const startMatch = html.match(
    /<div class="tab-pane[^"]*" id="one"[\s\S]*?(?=<div class="tab-pane)/i,
  );
  if (startMatch) return startMatch[0];

  // Fallback: no tabbed layout, scan whole document.
  return html;
}

function grabByClass(paneHtml, cls) {
  const out = [];
  const pattern = new RegExp(`<div class="${cls}"[^>]*>([\\s\\S]*?)<\\/div>`, 'gi');
  let match;
  while ((match = pattern.exec(paneHtml)) !== null) {
    const text = stripHtmlTags(match[1]);
    if (text) out.push(text);
  }
  return out;
}

function extractTriplets(paneHtml) {
  const arabic = grabByClass(paneHtml, 'Ara');
  const transliteration = grabByClass(paneHtml, 'Trl');
  const translation = grabByClass(paneHtml, 'Tra');

  const count = Math.min(arabic.length, transliteration.length, translation.length);
  if (count < arabic.length || count < transliteration.length || count < translation.length) {
    console.warn(
      `⚠️  Class counts differ (Ara=${arabic.length}, Trl=${transliteration.length}, ` +
        `Tra=${translation.length}). Using the first ${count} aligned triplets.`,
    );
  }

  const triplets = [];
  for (let i = 0; i < count; i += 1) {
    triplets.push({
      arabic: arabic[i],
      transliteration: transliteration[i],
      translation: translation[i],
    });
  }

  return triplets;
}

function buildDataField(triplets) {
  const lines = [];
  for (const { arabic, transliteration, translation } of triplets) {
    lines.push(arabic, transliteration, translation);
  }
  return lines.join('\n');
}

function buildDocument({ uid, url, title, slug, merits, triplets }) {
  const data = buildDataField(triplets);
  const doc = {
    title: title || '',
    code: '012',
    data,
  };
  if (merits && merits.trim()) doc.merits = merits.trim();
  const resolvedSlug = normalizeSlug(slug || title);
  if (resolvedSlug) doc.slug = resolvedSlug;
  return doc;
}

function previewDocument(doc, uid, triplets) {
  console.log('='.repeat(72));
  console.log(`Would store zikr/${uid}`);
  console.log('='.repeat(72));
  console.log(`title : ${doc.title}`);
  console.log(`code  : ${doc.code}`);
  if (doc.slug) console.log(`slug  : ${doc.slug}`);
  if (doc.merits) console.log(`merits: ${doc.merits}`);
  console.log(`verses: ${triplets.length} triplets (${triplets.length * 3} lines)`);
  console.log('-'.repeat(72));
  console.log('data (first 12 lines):');
  console.log(doc.data.split('\n').slice(0, 12).join('\n'));
  if (triplets.length * 3 > 12) console.log('...');
  console.log('-'.repeat(72));
  console.log('Full Firestore document:');
  console.log(JSON.stringify({ uid, ...doc }, null, 2));
  console.log('='.repeat(72));
}

async function storeDocument(uid, doc, { regenerate, skipConfirm }) {
  if (doc.data.trim().length === 0) {
    throw new Error('Refusing to store: parsed data is empty. Check the source URL.');
  }

  if (!skipConfirm) {
    console.log(`\nAbout to write zikr/${uid} to Firestore.`);
    console.log('Title :', doc.title);
    console.log('Verses:', (doc.data.match(/\n/g)?.length ?? 0) + 1, 'lines');
    console.log("Re-run with --yes to skip this prompt.\n");
    return false;
  }

  const serviceAccount = getServiceAccount();
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const db = admin.firestore();

  await db.collection(ZIKR_COLLECTION).doc(uid).set(doc);
  console.log(`✅ Stored zikr/${uid} (${doc.title})`);

  if (regenerate) {
    console.log('Regenerating local assets via build_zikr_release.js ...');
    execFileSync('node', [path.join(__dirname, 'build_zikr_release.js')], {
      stdio: 'inherit',
      cwd: __dirname,
    });
  } else {
    console.log('Run `node scripts/build_zikr_release.js` to refresh local assets.');
  }
  return true;
}

async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) {
    printUsage();
    return;
  }

  const getArg = (flag) => {
    const idx = args.indexOf(flag);
    return idx === -1 ? null : args[idx + 1];
  };

  const url = getArg('--url');
  const uid = getArg('--uid');
  const titleOverride = getArg('--title');
  const slugOverride = getArg('--slug');
  const merits = getArg('--merits');
  const doStore = args.includes('--store') || args.includes('--regenerate');
  const regenerate = args.includes('--regenerate');
  const skipConfirm = args.includes('--yes');

  if (!uid || !url) {
    console.error('Missing required --url and/or --uid.\n');
    printUsage();
    process.exit(1);
  }

  console.log(`Fetching ${url} ...`);
  const html = await fetchHtml(url);
  const pageTitle = extractTitle(html);
  const pane = extractPaneOne(html);
  const triplets = extractTriplets(pane);

  if (triplets.length === 0) {
    console.error('No Arabic/transliteration/translation triplets found on the page.');
    console.error('The page layout may be unsupported or the content is in another tab.');
    process.exit(1);
  }

  const title = titleOverride || pageTitle || uid;
  const doc = buildDocument({
    uid,
    url,
    title,
    slug: slugOverride,
    merits,
    triplets,
  });

  previewDocument(doc, uid, triplets);

  if (!doStore) {
    console.log('\nDry run complete. Re-run with --store to write to Firestore.');
    return;
  }

  await storeDocument(uid, doc, { regenerate, skipConfirm });
}

module.exports = {
  ZIKR_COLLECTION,
  fetchHtml,
  extractTitle,
  extractPaneOne,
  extractTriplets,
  buildDocument,
  storeDocument,
  normalizeSlug,
  stripHtmlTags,
  cleanTitle,
};

if (require.main === module) {
  main().catch((error) => {
    console.error(error?.stack || error);
    process.exit(1);
  });
}
