/**
 * Builds a reviewable uid -> audio[] map by matching the local zikr corpus
 * against duas.org's v2 JSON data.
 *
 * duas.org rebuilt their site as a JS app; content now lives at
 *   https://www.duas.org/data_v2/search_index.json   (the page list)
 *   https://www.duas.org/data_v2/<pageId>.json       (one page)
 * and each dua block carries a plain mp3 URL on mp3.duas.org.
 *
 * Nothing here writes to Firestore. The output is a candidate list that a
 * human approves first: title similarity alone produces confident-looking
 * matches that are simply wrong (their "ziyarat-imam-mahdi-short" scores 1.00
 * against our "Namaz of Imam Mahdi", which is a different act of worship).
 *
 * duas_audio_map.json is a local working file, not checked in - Firestore
 * holds whatever was applied from it. Re-running therefore starts review from
 * scratch unless a previous map is still on disk, in which case its approvals
 * are carried forward.
 *
 * Usage:
 *   node import_duas_audio.js                 # fetch, match, validate, write map
 *   node import_duas_audio.js --no-validate   # skip the HEAD check (faster)
 *   node import_duas_audio.js --offline       # reuse .cache, no network
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const ZIKR_INDEX = path.join(ROOT, 'assets', 'zikr.json');
const ZIKR_DIR = path.join(ROOT, 'assets', 'zikr');
const CACHE_DIR = path.join(__dirname, '.cache', 'duas_v2');
const OUT_FILE = path.join(__dirname, 'duas_audio_map.json');

const BASE = 'https://www.duas.org/data_v2';
// duas.org returns 403 to requests without a browser User-Agent.
const UA = 'Mozilla/5.0 (compatible; ShiaCompanion-import/1.0)';

const args = new Set(process.argv.slice(2));
const OFFLINE = args.has('--offline');
const VALIDATE = !args.has('--no-validate');

// Score above which a match is trusted without review; below MIN_SCORE it is
// dropped entirely. Everything between lands in the review tier.
const AUTO_SCORE = 0.82;
const MIN_SCORE = 0.55;

// ---------------------------------------------------------------- fetching

function cachePath(name) {
  return path.join(CACHE_DIR, `${name.replace(/[^\w.-]/g, '_')}.json`);
}

async function fetchJson(name) {
  const cached = cachePath(name);
  if (fs.existsSync(cached)) {
    return JSON.parse(fs.readFileSync(cached, 'utf8'));
  }
  if (OFFLINE) throw new Error(`--offline but ${name} is not cached`);

  const res = await fetch(`${BASE}/${name}.json`, {headers: {'User-Agent': UA}});
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${name}`);
  const body = await res.json();
  fs.mkdirSync(CACHE_DIR, {recursive: true});
  fs.writeFileSync(cached, JSON.stringify(body));
  return body;
}

async function mapLimit(items, limit, fn) {
  const out = new Array(items.length);
  let cursor = 0;
  const workers = Array.from({length: Math.min(limit, items.length)}, async () => {
    while (cursor < items.length) {
      const i = cursor++;
      out[i] = await fn(items[i], i);
    }
  });
  await Promise.all(workers);
  return out;
}

// ---------------------------------------------------------------- matching

// Words that carry no distinguishing signal: nearly every entry on both sides
// is a "dua" or a "ziyarat", so leaving them in inflates every score.
const STOPWORDS = new Set([
  'dua', 'duaa', 'dua-a', 'ziyarat', 'ziyarah', 'ziyarat-e', 'salaat', 'salat',
  'namaz', 'amaal', 'aamaal', 'munajat', 'munajaat', 'tasbeeh', 'tasbih',
  'the', 'of', 'for', 'and', 'to', 'be', 'on', 'in', 'a', 'e', 'al', 'e-',
  'recited', 'recite', 'reciting', 'after', 'before', 'imam', 'holy',
]);

// Honorifics appear inconsistently on both sides ("(as)", "a.s.", "(a.t.f.s.)").
const HONORIFICS = /\b(as|a\s*s|sawa|saww|swt|atfs|a\s*t\s*f\s*s|ajtfs|pbuh|ra)\b/g;

function normalize(text) {
  return `${text || ''}`
    .toLowerCase()
    .replace(/\(.*?\)/g, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(HONORIFICS, ' ')
    .split(/\s+/)
    .filter((w) => w && !STOPWORDS.has(w))
    .join(' ')
    .trim();
}

/** Dice coefficient over character bigrams - tolerant of the heavy
 * transliteration spelling drift between the two corpora
 * ("Nudba"/"Nudbah", "Jawshan"/"Jaushan"). */
function diceSimilarity(a, b) {
  if (!a || !b) return 0;
  if (a === b) return 1;
  const bigrams = (s) => {
    const out = new Map();
    for (let i = 0; i < s.length - 1; i++) {
      const g = s.slice(i, i + 2);
      out.set(g, (out.get(g) || 0) + 1);
    }
    return out;
  };
  const ba = bigrams(a);
  const bb = bigrams(b);
  if (!ba.size || !bb.size) return 0;
  let overlap = 0;
  let total = 0;
  for (const n of ba.values()) total += n;
  for (const [g, n] of bb) {
    total += n;
    overlap += Math.min(n, ba.get(g) || 0);
  }
  return (2 * overlap) / total;
}

/** Their page ids are slug-shaped ("dua-kumayl") and our index carries slugs
 * too, so this is a second, independent signal alongside the title. */
function slugSimilarity(ourSlug, theirId) {
  return diceSimilarity(normalize(ourSlug), normalize(theirId));
}

/**
 * duas.org files the daily Ramadan/Muharram amaal as one page per day, each
 * bundling five to seven recordings labelled by position within the day's
 * rites ("Short Dua for Day", "Book of companions") rather than by dua name.
 * Our corpus has no day-bundle entries for these to attach to, so they are
 * excluded rather than force-matched onto an unrelated zikr.
 */
const DAILY_AMAAL = /(\d+(st|nd|rd|th)\s+of\s+the\s+month|\b(night|day)\s+\d+\b)/i;

function isDailyAmaal(page) {
  return DAILY_AMAAL.test(`${page.title || ''}`) || DAILY_AMAAL.test(`${page.id || ''}`);
}

// ---------------------------------------------------------------- corpus

function loadLocalCorpus() {
  const index = JSON.parse(fs.readFileSync(ZIKR_INDEX, 'utf8'));
  const entries = [];
  for (const [uid, meta] of Object.entries(index)) {
    // Aliases ("G12|G1") and grouping uids ("B~AR9") have no content of their
    // own - they point at a parent, which is where audio belongs.
    if (uid.includes('|') || uid.includes('~')) continue;

    const contentPath = path.join(ZIKR_DIR, uid);
    if (!fs.existsSync(contentPath)) continue;

    let doc;
    try {
      doc = JSON.parse(fs.readFileSync(contentPath, 'utf8'));
    } catch {
      continue;
    }
    const hasData = `${doc.data || ''}`.trim().length > 0;
    const hasTabs = Array.isArray(doc.tabs) && doc.tabs.some((t) => `${t || ''}`.trim());
    if (!hasData && !hasTabs) continue;

    const title = `${meta?.title || doc.title || ''}`.trim();
    entries.push({
      uid,
      title,
      slug: `${meta?.slug || ''}`,
      normTitle: normalize(title),
      tabCount: hasTabs ? doc.tabs.length : 0,
    });
  }
  return entries;
}

/** Flattens duas.org pages into one row per page, carrying every audio track
 * on it. A page routinely holds several (the 15-Shaban amaal has six). */
function extractAudio(page) {
  const tracks = [];
  for (const block of page.duas || []) {
    const url = typeof block.audio === 'string' ? block.audio.trim() : '';
    if (!url) continue;
    tracks.push({
      url,
      label: `${block.title || page.title || ''}`.trim(),
      segments: Array.isArray(block.segments) ? block.segments.length : 0,
    });
  }
  return tracks;
}

// ---------------------------------------------------------------- validation

async function headCheck(url) {
  try {
    const res = await fetch(url, {method: 'HEAD', headers: {'User-Agent': UA}, redirect: 'follow'});
    const len = Number(res.headers.get('content-length') || 0);
    return {ok: res.ok && len > 0, status: res.status, bytes: len};
  } catch (e) {
    return {ok: false, status: 0, bytes: 0, error: e.message};
  }
}

// ---------------------------------------------------------------- main

async function main() {
  const corpus = loadLocalCorpus();
  console.log(`Local corpus: ${corpus.length} zikrs with content`);

  const searchIndex = await fetchJson('search_index');
  // The index lists a page once per tag/date it is filed under, so ids repeat
  // heavily (735 entries, 147 distinct). Without this the same page is fetched
  // and matched many times over, and every uid looks like a conflict.
  const pageIds = [...new Set(searchIndex.map((e) => e.id))];
  console.log(`duas.org index: ${searchIndex.length} entries, ${pageIds.length} distinct pages`);

  const pages = await mapLimit(pageIds, 6, async (id) => {
    try {
      return await fetchJson(id);
    } catch (e) {
      console.warn(`  ! ${id}: ${e.message}`);
      return null;
    }
  });

  const audioPages = [];
  for (const page of pages) {
    if (!page) continue;
    const tracks = extractAudio(page);
    if (tracks.length) audioPages.push({id: page.id, title: page.title, tracks});
  }
  const trackCount = audioPages.reduce((n, p) => n + p.tracks.length, 0);
  console.log(`Pages with audio: ${audioPages.length} (${trackCount} tracks)`);

  // Validate every distinct URL once; several pages reuse the same file.
  const urlStatus = new Map();
  if (VALIDATE) {
    const urls = [...new Set(audioPages.flatMap((p) => p.tracks.map((t) => t.url)))];
    console.log(`Validating ${urls.length} distinct URLs...`);
    const results = await mapLimit(urls, 8, headCheck);
    urls.forEach((u, i) => urlStatus.set(u, results[i]));
    const dead = urls.filter((u) => !urlStatus.get(u).ok);
    console.log(`  ${urls.length - dead.length} ok, ${dead.length} dead`);
    dead.forEach((u) => console.log(`  DEAD ${u}`));
  }

  // Best local match per duas.org page.
  const rows = [];
  let skippedDaily = 0;
  let droppedDead = 0;
  for (const page of audioPages) {
    // A URL that does not resolve today will not resolve on a user's device
    // either, so it never reaches the review list.
    const tracks = page.tracks.filter((t) => {
      if (!urlStatus.has(t.url)) return true;
      if (urlStatus.get(t.url).ok) return true;
      droppedDead += 1;
      return false;
    }).map((t) => ({
      ...t,
      ...(urlStatus.has(t.url) ? {bytes: urlStatus.get(t.url).bytes} : {}),
    }));
    if (!tracks.length) continue;

    if (isDailyAmaal(page)) {
      skippedDaily += 1;
      rows.push({tier: 'skipped-daily', reason: 'daily amaal bundle, no counterpart zikr',
                 uid: null, score: 0, pageId: page.id, theirTitle: page.title, tracks});
      continue;
    }

    let best = null;
    for (const item of corpus) {
      const score = Math.max(
        diceSimilarity(normalize(page.title), item.normTitle),
        slugSimilarity(item.slug, page.id),
      );
      if (!best || score > best.score) best = {score, item};
    }
    if (!best || best.score < MIN_SCORE) {
      rows.push({tier: 'unmatched', score: Number((best?.score || 0).toFixed(3)),
                 uid: null, ourTitle: null, pageId: page.id, theirTitle: page.title,
                 tracks});
      continue;
    }
    rows.push({
      tier: best.score >= AUTO_SCORE ? 'auto' : 'review',
      // "auto" rows start approved; "review" rows must be flipped by hand.
      approved: best.score >= AUTO_SCORE,
      score: Number(best.score.toFixed(3)),
      uid: best.item.uid,
      ourTitle: best.item.title,
      ourTabCount: best.item.tabCount,
      pageId: page.id,
      theirTitle: page.title,
      tracks,
    });
  }
  console.log(`Skipped ${skippedDaily} daily-amaal pages; dropped ${droppedDead} dead tracks`);

  rows.sort((a, b) => b.score - a.score);

  // One local zikr matching several pages is a signal the match is wrong, so
  // flag it rather than silently picking one.
  const byUid = new Map();
  for (const r of rows) {
    if (!r.uid) continue;
    byUid.set(r.uid, (byUid.get(r.uid) || 0) + 1);
  }
  for (const r of rows) {
    if (r.uid && byUid.get(r.uid) > 1) {
      r.conflict = true;
      if (r.tier === 'auto') {
        r.tier = 'review';
        r.approved = false;
      }
    }
  }

  // Re-running must never silently discard review work, so any hand-set uid or
  // approval on the previous map is carried forward onto the matching page.
  if (fs.existsSync(OUT_FILE)) {
    try {
      const prior = JSON.parse(fs.readFileSync(OUT_FILE, 'utf8'));
      const byPage = new Map((prior.rows || []).map((r) => [r.pageId, r]));
      let carried = 0;
      for (const r of rows) {
        const was = byPage.get(r.pageId);
        if (!was) continue;
        if (was.uid && was.uid !== r.uid) {
          r.uid = was.uid;
          r.overriddenByHand = true;
        }
        if (was.approved === true && !r.approved) {
          r.approved = true;
          carried += 1;
        }
      }
      if (carried) console.log(`Carried forward ${carried} prior approvals`);
    } catch (e) {
      console.warn(`Could not merge prior approvals: ${e.message}`);
    }
  }

  const counts = rows.reduce((acc, r) => ({...acc, [r.tier]: (acc[r.tier] || 0) + 1}), {});
  fs.writeFileSync(OUT_FILE, JSON.stringify({
    generatedAt: new Date().toISOString(),
    source: 'duas.org data_v2',
    note: 'Review "review" and "unmatched" rows by hand before applying. Set '
        + '"approved": true on a row to accept it.',
    counts,
    rows,
  }, null, 2));

  console.log('\nTiers:', counts);
  console.log(`Conflicts (one uid, several pages): ${rows.filter((r) => r.conflict).length}`);
  console.log(`Wrote ${path.relative(ROOT, OUT_FILE)}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
