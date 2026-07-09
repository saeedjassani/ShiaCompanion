const fs = require('fs');
const path = require('path');
const readline = require('readline');
const axios = require('axios');

const {
  fetchHtml,
  extractTitle,
  extractPaneOne,
  extractTriplets,
  buildDocument,
  storeDocument,
  normalizeSlug,
} = require('./import_dua_from_url');

const ASSETS = path.join(__dirname, '..', 'assets');
const ITEMS_PATH = path.join(ASSETS, 'items.json');
const ZIKR_PATH = path.join(ASSETS, 'zikr.json');

const DEFAULT_SEEDS = [
  'https://duas.org/',
  'https://duas.org/enemy.htm',
  'https://duas.org/muharramlinks.htm',
  'https://duas.org/daily.htm',
  'https://duas.org/misc.htm',
  'https://duas.org/ImamAli.htm',
];

function decodeEntities(s) {
  return `${s ?? ''}`
    .replace(/&amp;/gi, '&')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&[a-z]+;/gi, ' ');
}

// The parser expects the /mobile/ page layout (id="one" tab with Ara/Trl/Tra).
function toMobile(url) {
  try {
    const u = new URL(url);
    if (/mobile/i.test(u.pathname)) return url;
    const base = path.basename(u.pathname).replace(/\.html?$/i, '');
    return `https://duas.org/mobile/${base}.html`;
  } catch {
    return url;
  }
}

// ---------------------------------------------------------------------------
// Web search: find the best duas.org page for a given title.
// Default backend is DuckDuckGo's HTML endpoint (reliable, scrapable). If a
// Google Custom Search API key + CX are provided via env, `engine=google` uses
// the official API instead. Results are filtered to the duas.org domain.
// ---------------------------------------------------------------------------
async function searchDuckDuckGo(query) {
  const url = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`;
  const html = await fetchHtml(url);
  const out = [];
  const re = /href="[^"]*uddg=([^"&]+)/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    let decoded;
    try {
      decoded = decodeURIComponent(m[1]);
    } catch {
      continue;
    }
    try {
      const u = new URL(decoded);
      if (/duas\.org$/i.test(u.hostname)) out.push(u.toString());
    } catch {
      /* ignore */
    }
  }
  return [...new Set(out)];
}

async function searchGoogleCSE(query) {
  const key = process.env.GOOGLE_CSE_API_KEY;
  const cx = process.env.GOOGLE_CSE_CX;
  const url =
    `https://www.googleapis.com/customsearch/v1?key=${key}&cx=${cx}` +
    `&q=${encodeURIComponent(query)}`;
  const res = await axios.get(url, { timeout: 30000 });
  const items = res.data?.items ?? [];
  return [
    ...new Set(
      items
        .map((it) => it.link)
        .filter((link) => {
          try {
            return /duas\.org$/i.test(new URL(link).hostname);
          } catch {
            return false;
          }
        }),
    ),
  ];
}

async function searchWeb(query, { engine = 'ddg' } = {}) {
  if (engine === 'google' && process.env.GOOGLE_CSE_API_KEY && process.env.GOOGLE_CSE_CX) {
    return searchGoogleCSE(query);
  }
  return searchDuckDuckGo(query);
}

function loadJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function computeMissing() {
  const items = loadJson(ITEMS_PATH);
  const zikr = loadJson(ZIKR_PATH);
  const have = new Set(Object.keys(zikr));
  const missing = [];
  let skippedAggregators = 0;
  for (const [uid, value] of Object.entries(items)) {
    // `~` = parent/list aggregator, `|` = special composite. These never hold
    // their own 3-line content (the build pipeline prunes them), so they are
    // not individual zikrs to populate.
    if (uid.includes('~') || uid.includes('|')) {
      skippedAggregators += 1;
      continue;
    }
    if (have.has(uid)) continue;
    const title = typeof value === 'string' ? value : `${value?.title ?? ''}`;
    missing.push({ uid, title });
  }
  missing.sort((a, b) => a.uid.localeCompare(b.uid));
  missing._skippedAggregators = skippedAggregators;
  return missing;
}

// ---------------------------------------------------------------------------
// Title normalization + similarity (used to match items.json titles to the
// crawled duas.org corpus).
// ---------------------------------------------------------------------------
function normalize(s) {
  return `${s ?? ''}`
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9\s٠-ۿ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function score(a, b) {
  const na = normalize(a);
  const nb = normalize(b);
  if (!na || !nb) return 0;
  if (na === nb) return 1;
  const ta = new Set(na.split(' ').filter(Boolean));
  const tb = new Set(nb.split(' ').filter(Boolean));
  if (ta.size === 0 || tb.size === 0) return 0;
  let inter = 0;
  for (const t of ta) if (tb.has(t)) inter += 1;
  // Jaccard, slightly biased toward the shorter (more specific) title.
  return inter / (ta.size + tb.size - inter);
}

// ---------------------------------------------------------------------------
// Crawler: build a {url, title} corpus from duas.org listing pages.
// ---------------------------------------------------------------------------
function extractLinks(html, base) {
  const out = [];
  const re = /<a\b[^>]*?href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    let href = m[1].trim();
    const anchor = decodeEntities(m[2].replace(/<[^>]+>/g, ' ')).replace(/\s+/g, ' ').trim();
    if (!href || href.startsWith('#') || href.startsWith('mailto:') || href.startsWith('javascript:')) {
      continue;
    }
    let abs;
    try {
      abs = new URL(href, base).toString();
    } catch {
      continue;
    }
    const url = new URL(abs);
    if (!/duas\.org$/i.test(url.hostname)) continue;
    if (!/\.html?$/i.test(url.pathname)) continue;
    url.search = '';
    url.hash = '';
    out.push({ url: url.toString(), title: anchor });
  }
  return out;
}

async function crawl(seeds, { maxPages = 1200, concurrency = 12, depth = 3 } = {}) {
  const byUrl = new Map();
  const queue = [];
  for (const s of seeds) queue.push({ url: s, depth: 0 });
  const seen = new Set();

  const worker = async () => {
    while (true) {
      const next = queue.shift();
      if (!next) return;
      const key = next.url;
      if (seen.has(key)) continue;
      seen.add(key);
      if (byUrl.size >= maxPages) continue;
      try {
        const html = await fetchHtml(next.url);
        const links = extractLinks(html, next.url);
        const pageTitle = decodeEntities(extractTitle(html)) || '';
        // Tag actual dua pages by checking for the Arabic block the parser
        // relies on. Individual pages may live at /mobile/ or on the desktop
        // site, so check both variants.
        let isDua = false;
        const duaChecks = [];
        if (/mobile/i.test(next.url)) {
          duaChecks.push(next.url);
        } else {
          const m = toMobile(next.url);
          if (m !== next.url) duaChecks.push(m);
          duaChecks.push(next.url);
        }
        for (const c of duaChecks) {
          try {
            if (/class="Ara"/i.test(await fetchHtml(c))) {
              isDua = true;
              break;
            }
          } catch {
            /* try next */
          }
        }
        if (!byUrl.has(key)) {
          byUrl.set(key, { url: key, title: pageTitle || links.title || '', dua: isDua });
        }
        if (next.depth < depth) {
          for (const l of links) {
            if (!seen.has(l.url) && !byUrl.has(l.url)) {
              queue.push({ url: l.url, depth: next.depth + 1 });
              byUrl.set(l.url, { url: l.url, title: l.title, dua: false });
            }
          }
        }
      } catch (err) {
        // Skip pages that fail to load.
      }
    }
  };

  const workers = Array.from({ length: concurrency }, () => worker());
  await Promise.all(workers);
  return [...byUrl.values()];
}

// ---------------------------------------------------------------------------
// Interactive match + approve.
// ---------------------------------------------------------------------------
function ask(rl, question) {
  return new Promise((resolve) => rl.question(question, (a) => resolve(a.trim())));
}

async function tryParse(url) {
  const candidates = [url];
  if (/mobile/i.test(url)) {
    candidates.push(url.replace(/\/mobile\//i, '/'));
  } else {
    const mobile = toMobile(url);
    if (mobile !== url) candidates.push(mobile);
  }

  for (const c of [...new Set(candidates)]) {
    try {
      const html = await fetchHtml(c);
      const pane = extractPaneOne(html);
      const triplets = extractTriplets(pane);
      if (triplets.length > 0) {
        const pageTitle = extractTitle(html);
        return buildDocument({ uid: '', url: c, title: pageTitle, triplets });
      }
    } catch {
      /* try next candidate */
    }
  }
  return null;
}

function preview(doc, uid) {
  console.log('  -> would store zikr/' + uid);
  console.log('     title : ' + doc.title);
  console.log('     code  : ' + doc.code);
  if (doc.slug) console.log('     slug  : ' + doc.slug);
  console.log('     verses: ' + (doc.data.match(/\n/g)?.length ?? 0) + 1 + ' lines');
  console.log('     first : ' + doc.data.split('\n').slice(0, 3).join(' | '));
}

async function matchLoop(missing, { store, regenerate, engine, searchFn = searchWeb }) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const approved = [];
  const skipped = [];
  let storedCount = 0;

  for (const item of missing) {
    console.log('\n========================================');
    console.log(item.uid + ': ' + item.title);

    let cands = [];
    try {
      const results = await searchFn(item.title, { engine });
      cands = results.slice(0, 5);
    } catch (err) {
      console.log('  search failed: ' + err.message);
    }

    if (cands.length === 0) {
      console.log('  (no duas.org result found)');
    } else {
      cands.forEach((u, i) => console.log(`  [${i + 1}] ${u}`));
    }

    const choice = await ask(
      rl,
      '  URL to use (Enter=#1, number, "u"=paste url, "s"=skip): ',
    );
    let url = null;
    if (choice === 's' || choice === 'skip') {
      skipped.push(item.uid);
      continue;
    } else if (choice === 'u') {
      url = await ask(rl, '  paste duas.org URL: ');
    } else if (choice === '' && cands.length) {
      url = cands[0];
    } else if (/^\d+$/.test(choice) && cands[+choice - 1]) {
      url = cands[+choice - 1];
    } else if (/^https?:\/\//.test(choice)) {
      url = choice;
    }
    if (!url) {
      skipped.push(item.uid);
      continue;
    }

    let doc = null;
    try {
      doc = await tryParse(url);
    } catch (err) {
      console.log('  fetch/parse failed: ' + err.message);
    }
    if (!doc) {
      console.log('  no Arabic/transliteration/translation triplets found at that URL.');
      const again = await ask(rl, '  skip? [Enter]=yes, "u"=try another url: ');
      if (again === 'u') {
        const u2 = await ask(rl, '  paste duas.org URL: ');
        try {
          doc = await tryParse(u2);
        } catch {
          /* ignore */
        }
      }
      if (!doc) {
        skipped.push(item.uid);
        continue;
      }
    }

    preview(doc, item.uid);
    const decision = await ask(rl, '  Store to Firebase? [y/N/s]: ');
    if (decision === 'y' || decision === 'yes') {
      const finalDoc = { ...doc, title: (await ask(rl, '  title override (Enter=keep): ')) || doc.title };
      if (store) {
        await storeDocument(item.uid, finalDoc, { regenerate: false, skipConfirm: true });
        storedCount += 1;
      } else {
        approved.push({ uid: item.uid, url, doc: finalDoc });
        console.log('  (dry run) recorded; re-run with --store to write.');
      }
    } else {
      skipped.push(item.uid);
    }
  }

  rl.close();
  if (!store && approved.length) {
    fs.writeFileSync(
      path.join(__dirname, 'approved_zikrs.json'),
      JSON.stringify(approved, null, 2),
    );
    console.log(`\nWrote ${approved.length} approved (dry-run) entries to approved_zikrs.json`);
  }
  console.log(`\nStored: ${storedCount}, Skipped: ${skipped.length}`);

  if (store && regenerate && storedCount > 0) {
    console.log('Regenerating local assets via build_zikr_release.js ...');
    const { execFileSync } = require('child_process');
    execFileSync('node', [path.join(__dirname, 'build_zikr_release.js')], {
      stdio: 'inherit',
      cwd: __dirname,
    });
  }
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------
async function main() {
  const args = process.argv.slice(2);
  const cmd = args[0];
  const has = (f) => args.includes(f);
  const getArg = (f) => {
    const i = args.indexOf(f);
    return i === -1 ? null : args[i + 1];
  };

  if (cmd === 'diff') {
    const missing = computeMissing();
    console.log(`items.json: ${Object.keys(loadJson(ITEMS_PATH)).length} entries`);
    console.log(`zikr.json:  ${Object.keys(loadJson(ZIKR_PATH)).length} entries`);
    console.log(`(excluded ${missing._skippedAggregators} parent/list aggregators: '~' and '|' UIDs)`);
    console.log(`MISSING (in items.json, not in zikr.json): ${missing.length}\n`);
    for (const m of missing) console.log(`${m.uid}\t${m.title}`);
    const out = getArg('--out') || path.join(__dirname, 'missing_zikrs.json');
    fs.writeFileSync(out, JSON.stringify(missing, null, 2));
    console.log(`\nWrote missing list to ${out}`);
    return;
  }

  if (cmd === 'crawl') {
    const seedsArg = getArg('--seeds');
    const seeds = seedsArg ? JSON.parse(fs.readFileSync(seedsArg, 'utf8')) : DEFAULT_SEEDS;
    const out = getArg('--out') || path.join(__dirname, 'duas_org_index.json');
    console.log(`Crawling ${seeds.length} seed pages ...`);
    const corpus = await crawl(seeds, { maxPages: 1200, concurrency: 12, depth: 3 });
    fs.writeFileSync(out, JSON.stringify(corpus, null, 2));
    console.log(`Crawled ${corpus.length} pages -> ${out}`);
    return;
  }

  if (cmd === 'match') {
    const missing = computeMissing();
    const engine = getArg('--engine') || (has('--google') ? 'google' : 'ddg');
    console.log(`Missing zikrs: ${missing.length}. Search engine: ${engine}.`);
    console.log('For each, the top duas.org search results are shown; approve (y) to store.\n');
    await matchLoop(missing, {
      store: has('--store'),
      regenerate: has('--regenerate'),
      engine,
    });
    return;
  }

  console.log(`Usage:
  node populate_missing_zikrs.js diff                       # list missing zikrs
  node populate_missing_zikrs.js crawl [--seeds s.json]     # (optional) build a local corpus
  node populate_missing_zikrs.js match [--store] [--regenerate] [--engine ddg|google]
                                                          # interactive: search + approve each

Matching searches the web for each missing title and offers the top duas.org
results; you approve (y) each one before any Firebase write. Without --store it
records approvals to approved_zikrs.json.
  --engine ddg     DuckDuckGo HTML scrape (default, no key needed)
  --engine google  Google Custom Search (needs GOOGLE_CSE_API_KEY + GOOGLE_CSE_CX)`);
}

module.exports = {
  computeMissing,
  searchWeb,
  searchDuckDuckGo,
  searchGoogleCSE,
  tryParse,
  matchLoop,
};

if (require.main === module) {
  main().catch((error) => {
    console.error(error?.stack || error);
    process.exit(1);
  });
}
