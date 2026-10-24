const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.join(__dirname, '..');
const ZIKR_INDEX_PATH = path.join(REPO_ROOT, 'assets', 'zikr.json');
const ZIKR_CONTENT_DIR = path.join(REPO_ROOT, 'assets', 'zikr');
const BUILD_WEB_DIR = process.env.WEB_BUILD_DIR
  ? path.resolve(process.env.WEB_BUILD_DIR)
  : path.join(REPO_ROOT, 'web');
const FLUTTER_INDEX_PATH = path.join(BUILD_WEB_DIR, 'index.html');
const GENERATED_ZIKR_DIR = path.join(BUILD_WEB_DIR, 'zikr');
// Matches zikrDeepLinkType (0) in lib/utils/deep_links.dart: the numeric
// fallback path the app shares when it doesn't yet know an item's slug.
const GENERATED_UID_REDIRECT_DIR = path.join(BUILD_WEB_DIR, '0');
// The Quran's structure - ayah counts, juz boundaries and which zikr document
// holds which surah - is read from the Dart source the app itself uses, so the
// pages cannot drift from what the reader opens at the same URL.
const QURAN_INDEX_DART_PATH = path.join(REPO_ROOT, 'lib', 'utils', 'quran_index.dart');
const GENERATED_QURAN_DIR = path.join(BUILD_WEB_DIR, 'quran');
const QURAN_SECTION = {name: 'Quran', path: '/quran'};
// The library's books live in another repo (shiavault-library). The build
// condenses their metadata into one JSON file with
// scripts/library_seo_index.dart and names it here; without it the /library
// pages are skipped, which is what an offline local run gets.
const LIBRARY_INDEX_PATH = process.env.LIBRARY_INDEX
  ? path.resolve(process.env.LIBRARY_INDEX)
  : null;
const BOOKS_PATH = path.join(REPO_ROOT, 'assets', 'books.json');
const RETIRED_BOOK_SLUGS_PATH = path.join(REPO_ROOT, 'assets', 'retired_slugs.json');
const GENERATED_LIBRARY_DIR = path.join(BUILD_WEB_DIR, 'library');
const LIBRARY_SECTION = {name: 'Library', path: '/library'};
const SITE_ORIGIN = (process.env.SITE_ORIGIN || 'https://shiacompanion.app')
  .replace(/\/+$/, '');
// Title tags longer than this get truncated in results. Search engines show
// the site name separately, so long titles drop the " | Shia Companion" suffix
// rather than losing the words people actually search for.
const MAX_TITLE_TAG_LENGTH = 60;
const TITLE_SUFFIX = ' | Shia Companion';
const ARABIC_SCRIPT = /[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]/;

// Search Console pins a "Couldn't fetch" verdict to a sitemap URL and will not
// clear it on resubmission, even after the URL serves valid XML again — and it
// does: status, content-type, XML validity, Googlebot UA, IPv6, TLS 1.2 and
// HTTP/1.1 all check out, and URL Inspection reports "URL is available to
// Google". Publishing the identical sitemap at a second path gives Search
// Console a URL carrying no cached verdict. Both files are written from one
// string, so they cannot drift. Drop the second path once /sitemap.xml reports
// Success.
const SITEMAP_FILENAMES = ['sitemap.xml', 'sitemap-all.xml'];

// Pairs of slugs that serve the same content (a `|`-alias and its target,
// under different titles, so each kept its own slug). Two indexable URLs for
// one text split ranking between them. The key slug becomes a redirect page to
// the value slug and leaves the sitemap and the /zikr index; the app keeps
// resolving both, so no shared link breaks.
const MERGED_ZIKR_SLUGS = {
  'dua-alqamah': 'dua-alqama',
  'ziyaarat-e-ashoora': 'ziyarat-e-ashura',
  'ziyaarat-e-aashoora-gair-ma-roofah': 'ziyaarat-e-ashoora-ghair-ma-roofah',
  'namaz-of-jafar-e-tayyaar': 'namaz-of-jafar-e-tayyar',
  'ziyaarat-al-haqq-al-jadeed': 'ziyarat-al-haqq-al-jadeed',
  'friday-ziyarah-of-imam-al-mahdi-a-t-f-s': 'ziyarat-on-friday',
  'ziyarah-on-the-day-of-arafat': 'ziyarat-e-imam-husain-a-s-on-the-day-of-arafah',
  'ziyarah-on-the-day-of-arbaeen-the-twentieth-of-safar': 'ziyarat-e-arbaeen-the-20th-of-safar',
  'ziyaarat-e-aal-e-yaaseen': 'ziyarat-e-aale-yaseen',
  'ziyarah-on-saturday': 'ziyarat-of-saturday',
  'salawaat-abul-hasan-al-zarraab-al-isfahani': 'salawat-abul-hasan-al-zarrab-al-isfahani',
};

// Hand-written pages that ship from web/ rather than being generated here.
// This file replaces the checked-in sitemap wholesale, so anything left out
// disappears from the sitemap the moment the generator runs. Only real files
// belong here: a path that exists solely through the "**" rewrite in
// firebase.json resolves to the app shell, which Google sees as a duplicate of
// the home page and drops.
const STATIC_PAGE_PATHS = ['/privacy.html', '/delete_account.html'];

function escapeHtml(value) {
  return `${value ?? ''}`
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function escapeXml(value) {
  return escapeHtml(value);
}

function escapeScriptJson(value) {
  return JSON.stringify(value, null, 2).replace(/<\/script/gi, '<\\/script');
}

function normalizeWhitespace(value) {
  return `${value ?? ''}`.replace(/\s+/g, ' ').trim();
}

function stripInlineMarkers(value) {
  return `${value ?? ''}`
    .replace(/--/g, ' ')
    .replace(/\t+/g, ' ')
    .trim();
}

function titleCaseWord(word) {
  const lower = word.toLowerCase();
  if (['a', 'an', 'al', 'as', 'at', 'az', 'e', 'ibn', 'of', 'the'].includes(lower)) {
    return lower;
  }
  return lower.charAt(0).toUpperCase() + lower.slice(1);
}

function humanizeSlug(slug) {
  const words = `${slug ?? ''}`
    .split('-')
    .map((word) => word.trim())
    .filter(Boolean);

  if (words.length === 0) return '';
  return words.map(titleCaseWord).join(' ');
}

function sameNormalizedTitle(a, b) {
  const normalize = (value) => `${value ?? ''}`
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '');
  return normalize(a) === normalize(b);
}

function safeSlug(slug) {
  const normalized = `${slug ?? ''}`.trim();
  if (!/^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$/.test(normalized)) {
    throw new Error(`Unsafe zikr slug: ${slug}`);
  }
  return normalized;
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function contentUidFor(uid) {
  if (uid.includes('~')) return null;
  if (uid.includes('|')) {
    return uid.split('|').pop().trim();
  }
  return uid;
}

function contentPathFor(uid) {
  return path.join(ZIKR_CONTENT_DIR, uid);
}

function loadContent(uid, entry) {
  const contentUid = contentUidFor(uid);
  if (!contentUid) return null;

  const filePath = contentPathFor(contentUid);
  if (!fs.existsSync(filePath)) return null;

  return shownTabsOf(readJson(filePath), uid.includes('|') ? entry?.tabs : null);
}

// An alias whose zikr.json entry names `tabs` stands for only those tabs of
// its target - numbered from 1, as the app's reader shows them (and as a
// `?tab=` link names them; see shownZikrTabs in the app). Its page shows them
// alone, as the app does.
function shownTabsOf(content, tabs) {
  if (!Array.isArray(tabs) || tabs.length === 0) return content;

  // The tabs the reader shows: buildVisibleZikrTabContents in the app.
  const extraTabs = (content.tabs ?? []).map((tab) => `${tab ?? ''}`);
  const data = `${content.data ?? ''}`;
  const visible = [
    ...(data.trim() || extraTabs.every((tab) => !tab.trim()) ? [data] : []),
    ...extraTabs.filter((tab) => tab.trim()),
  ];
  const shown = [...new Set(tabs)]
    .filter((n) => Number.isInteger(n) && n >= 1 && n <= visible.length)
    .map((n) => visible[n - 1]);
  if (shown.length === 0) return content;
  // A lone tab has no tab strip to carry its label (its first line), so the
  // app drops that line - shownZikrTabContents.
  if (shown.length === 1 && visible.length > 1) {
    return {...content, data: shown[0].split('\n').slice(1).join('\n'), tabs: []};
  }

  return {...content, data: shown[0], tabs: shown.slice(1)};
}

function linesFromText(value) {
  return `${value ?? ''}`
    .replace(/\r/g, '')
    .split('\n')
    .map((line) => normalizeWhitespace(stripInlineMarkers(line)))
    .filter((line) => line.length > 0);
}

function collectBodyLines(content) {
  const lines = [];
  for (const value of [content?.merits, content?.data, ...(content?.tabs ?? [])]) {
    lines.push(...linesFromText(value));
  }
  return lines;
}

function buildDescription(title, slug, content) {
  const humanSlugTitle = humanizeSlug(slug);
  const displayTitle = humanSlugTitle && !sameNormalizedTitle(title, humanSlugTitle)
    ? `${title} (${humanSlugTitle})`
    : title;
  const firstMeritLine = linesFromText(content?.merits)
    .find((line) => line.length >= 50);

  if (firstMeritLine) {
    return normalizeWhitespace(firstMeritLine).slice(0, 155);
  }

  // Only promise merits when the page actually shows a Merits section.
  const hasMerits = linesFromText(content?.merits).length > 0;
  return hasMerits
    ? `Read ${displayTitle} with Arabic text, transliteration, English translation, and merits on Shia Companion.`
    : `Read the full ${displayTitle} in Arabic with transliteration and English translation on Shia Companion.`;
}

function buildTitleTag(title, slug) {
  const humanSlugTitle = humanizeSlug(slug);
  const candidates = humanSlugTitle && !sameNormalizedTitle(title, humanSlugTitle)
    ? [
      `${title} | ${humanSlugTitle}${TITLE_SUFFIX}`,
      `${title} | ${humanSlugTitle}`,
      `${title}${TITLE_SUFFIX}`,
    ]
    : [`${title}${TITLE_SUFFIX}`];
  return candidates.find((candidate) => candidate.length <= MAX_TITLE_TAG_LENGTH) ?? title;
}

// Arabic lines get lang/dir so search engines and screen readers read them as
// Arabic; the rest of the page inherits lang="en" from <html>.
function lineParagraph(line) {
  return ARABIC_SCRIPT.test(line)
    ? `        <p lang="ar" dir="rtl">${escapeHtml(line)}</p>`
    : `        <p>${escapeHtml(line)}</p>`;
}

function buildStructuredData({
  title,
  description,
  canonicalUrl,
  section = {name: 'Zikr', path: '/zikr'},
}) {
  return {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: title,
    description,
    url: canonicalUrl,
    isPartOf: {
      '@type': 'WebSite',
      name: 'Shia Companion',
      url: SITE_ORIGIN,
    },
    breadcrumb: {
      '@type': 'BreadcrumbList',
      itemListElement: [
        {
          '@type': 'ListItem',
          position: 1,
          name: 'Shia Companion',
          item: `${SITE_ORIGIN}/`,
        },
        {
          '@type': 'ListItem',
          position: 2,
          name: section.name,
          item: `${SITE_ORIGIN}${section.path}`,
        },
        {
          '@type': 'ListItem',
          position: 3,
          name: title,
          item: canonicalUrl,
        },
      ],
    },
  };
}

function replaceOrInsertHeadTag(html, pattern, tag) {
  if (pattern.test(html)) {
    return html.replace(pattern, tag);
  }
  return html.replace('</head>', `  ${tag}\n</head>`);
}

function applySeoHead(html, seo) {
  let output = html.replace(
    /\s*<!-- Home page only:[\s\S]*?-->\s*<script type="application\/ld\+json" id="home-structured-data">[\s\S]*?<\/script>/i,
    '',
  );
  output = output.replace(/<title>[\s\S]*?<\/title>/i, `<title>${escapeHtml(seo.titleTag)}</title>`);
  output = replaceOrInsertHeadTag(
    output,
    /<meta\s+name=["']description["'][^>]*>/i,
    `<meta name="description" content="${escapeHtml(seo.description)}">`,
  );
  output = replaceOrInsertHeadTag(
    output,
    /<meta\s+property=["']og:title["'][^>]*>/i,
    `<meta property="og:title" content="${escapeHtml(seo.titleTag)}">`,
  );
  output = replaceOrInsertHeadTag(
    output,
    /<meta\s+property=["']og:description["'][^>]*>/i,
    `<meta property="og:description" content="${escapeHtml(seo.description)}">`,
  );
  output = replaceOrInsertHeadTag(
    output,
    /<meta\s+property=["']og:url["'][^>]*>/i,
    `<meta property="og:url" content="${escapeHtml(seo.canonicalUrl)}">`,
  );
  output = replaceOrInsertHeadTag(
    output,
    /<meta\s+property=["']og:type["'][^>]*>/i,
    '<meta property="og:type" content="article">',
  );
  output = output.replace(/<link\s+rel=["']canonical["'][^>]*>\s*/ig, '');
  output = output.replace(
    '</head>',
    [
      `  <link rel="canonical" href="${escapeHtml(seo.canonicalUrl)}">`,
      '  <meta name="twitter:card" content="summary">',
      `  <meta name="twitter:title" content="${escapeHtml(seo.titleTag)}">`,
      `  <meta name="twitter:description" content="${escapeHtml(seo.description)}">`,
      '  <style id="zikr-seo-style">',
      '    .seo-zikr-content{max-width:860px;margin:0 auto;padding:32px 20px 72px;color:#2e2723;background:#fff;font:16px/1.7 system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;}',
      '    .seo-zikr-content h1{font-size:32px;line-height:1.2;margin:16px 0;}',
      '    .seo-zikr-content h2{font-size:22px;line-height:1.3;margin:28px 0 10px;}',
      '    .seo-zikr-content a{color:#5d4037;}',
      '    .seo-zikr-content .seo-lines p{margin:0 0 10px;}',
      '  </style>',
      `  <script type="application/ld+json">${escapeScriptJson(seo.structuredData)}</script>`,
      '</head>',
    ].join('\n'),
  );
  return output;
}

function buildStaticContent({title, description, canonicalPath, content}) {
  const merits = linesFromText(content?.merits).slice(0, 8);
  const bodyLines = collectBodyLines(content)
    .filter((line) => !merits.includes(line));

  const meritsHtml = merits.length > 0
    ? [
      '      <section>',
      '        <h2>Merits</h2>',
      ...merits.map(lineParagraph),
      '      </section>',
    ].join('\n')
    : '';

  const bodyHtml = bodyLines.length > 0
    ? [
      '      <section class="seo-lines">',
      '        <h2>Text and Translation</h2>',
      ...bodyLines.map(lineParagraph),
      '      </section>',
    ].join('\n')
    : '';

  return [
    '  <main class="seo-zikr-content">',
    '    <article>',
    '      <nav aria-label="Breadcrumb"><a href="/">Shia Companion</a> / <a href="/zikr">Zikr</a></nav>',
    `      <h1>${escapeHtml(title)}</h1>`,
    `      <p>${escapeHtml(description)}</p>`,
    `      <p><a href="${escapeHtml(canonicalPath)}">Open ${escapeHtml(title)} in Shia Companion</a></p>`,
    meritsHtml,
    bodyHtml,
    '    </article>',
    '  </main>',
  ].filter(Boolean).join('\n');
}

function insertStaticContent(html, staticContent) {
  // The shared nav carries the home page's <h1>. Generated pages have their
  // own <h1>, so demote the nav heading to keep one <h1> per page.
  return html
    .replace(
      /<h1 class="seo-home-title">([\s\S]*?)<\/h1>/i,
      '<h2 class="seo-home-title">Shia Companion</h2>',
    )
    .replace(/<body([^>]*)>/i, `<body$1>\n${staticContent}`);
}

// Old shares and any link built before the app resolved a slug use this
// numeric `/0/<uid>` form (see zikrDeepLinkType in lib/utils/deep_links.dart).
// The app already rewrites that to `/zikr/<slug>` itself once Flutter boots,
// but a crawler or a chat app's link-unfurler never runs that JS and was
// seeing the bare, title-less app shell instead. A tiny static page at the
// same path puts a real title, a canonical link, and an instant redirect in
// front of them without waiting on Flutter — see the "0/<uid>" section of
// scripts/generate_zikr_seo_pages.js's test coverage for what depends on it.
function buildRedirectPageHtml({title, canonicalPath, canonicalUrl}) {
  const safeTitle = escapeHtml(title);
  return [
    '<!doctype html>',
    '<html lang="en">',
    '<head>',
    '  <meta charset="utf-8">',
    `  <title>${safeTitle} | Shia Companion</title>`,
    `  <link rel="canonical" href="${escapeHtml(canonicalUrl)}">`,
    `  <meta http-equiv="refresh" content="0; url=${escapeHtml(canonicalPath)}">`,
    '</head>',
    '<body>',
    `  <p>Redirecting to <a href="${escapeHtml(canonicalPath)}">${safeTitle}</a>&hellip;</p>`,
    `  <script>location.replace(${JSON.stringify(canonicalPath)});</script>`,
    '</body>',
    '</html>',
    '',
  ].join('\n');
}

function writePage(relativePath, html) {
  const directoryPath = path.join(BUILD_WEB_DIR, relativePath);
  fs.mkdirSync(directoryPath, {recursive: true});
  fs.writeFileSync(path.join(directoryPath, 'index.html'), html, 'utf8');
}

function buildPageHtml(templateHtml, page) {
  const htmlWithHead = applySeoHead(templateHtml, page.seo);
  return insertStaticContent(htmlWithHead, page.staticContent);
}

function buildSitemap(paths) {
  const allPaths = ['/', '/zikr', ...STATIC_PAGE_PATHS, ...paths];
  const seen = new Set();
  for (const urlPath of allPaths) {
    if (seen.has(urlPath)) {
      throw new Error(`Duplicate sitemap path: ${urlPath}`);
    }
    seen.add(urlPath);
  }

  const urls = allPaths.map((urlPath) => `${SITE_ORIGIN}${urlPath}`);
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ...urls.map((url) => [
      '  <url>',
      `    <loc>${escapeXml(url)}</loc>`,
      '  </url>',
    ].join('\n')),
    '</urlset>',
    '',
  ].join('\n');
}

function buildZikrIndexPage(templateHtml, pages) {
  const canonicalUrl = `${SITE_ORIGIN}/zikr`;
  const titleTag = 'Zikr, Duas and Ziyarats | Shia Companion';
  const description = 'Browse Shia Companion zikr, duas, ziyarats, Quran recitations, and aamal with readable web links.';
  const links = pages
    .map((page) => `        <li><a href="${escapeHtml(page.canonicalPath)}">${escapeHtml(page.title)}</a></li>`)
    .join('\n');
  const staticContent = [
    '  <main class="seo-zikr-content">',
    '    <article>',
    '      <nav aria-label="Breadcrumb"><a href="/">Shia Companion</a></nav>',
    '      <h1>Zikr, Duas and Ziyarats</h1>',
    `      <p>${escapeHtml(description)}</p>`,
    '      <ul>',
    links,
    '      </ul>',
    '    </article>',
    '  </main>',
  ].join('\n');

  return insertStaticContent(
    applySeoHead(templateHtml, {
      titleTag,
      description,
      canonicalUrl,
      structuredData: buildStructuredData({
        title: titleTag.replace(' | Shia Companion', ''),
        description,
        canonicalUrl,
      }),
    }),
    staticContent,
  );
}

// --- Quran -----------------------------------------------------------------
//
// A surah is an ordinary zikr document, so it already has its indexed page at
// /zikr/<slug>, and that is where the app's reader puts the address bar too.
// What the zikr pages do not cover is the Quran screen itself (/quran) and the
// thirty juz (/quran/juz/<n>), which the reader assembles across surahs. Those
// get pages here. /quran/<n> - a link the app opens but never writes - gets a
// redirect page to the surah's canonical /zikr/<slug>, so it is not indexed as
// a second copy of it. Verse links (/quran/<n>/<ayah>) stay app-only.

function dartConstBody(source, pattern, name) {
  const match = source.match(pattern);
  if (!match) {
    throw new Error(`Could not find ${name} in ${QURAN_INDEX_DART_PATH}`);
  }
  return match[1];
}

function readQuranStructure() {
  const source = fs.readFileSync(QURAN_INDEX_DART_PATH, 'utf8');

  const uidOffset = Number(dartConstBody(
    source,
    /const int _surahUidOffset = (\d+);/,
    '_surahUidOffset',
  ));
  const ayahCounts = dartConstBody(
    source,
    /const List<int> surahAyahCounts = \[([\s\S]*?)\];/,
    'surahAyahCounts',
  ).match(/\d+/g).map(Number);
  const juzStarts = [...dartConstBody(
    source,
    /const List<List<int>> _juzStarts = \[([\s\S]*?)\];/,
    '_juzStarts',
  ).matchAll(/\[\s*(\d+)\s*,\s*(\d+)\s*\]/g)]
    .map((match) => ({surah: Number(match[1]), ayah: Number(match[2])}));

  if (ayahCounts.length !== 114) {
    throw new Error(`Expected 114 surah ayah counts, read ${ayahCounts.length}`);
  }
  if (juzStarts.length !== 30) {
    throw new Error(`Expected 30 juz starts, read ${juzStarts.length}`);
  }

  // Each juz ends right before the next one starts, as allJuz() derives it.
  const juz = juzStarts.map((start, i) => {
    const next = juzStarts[i + 1];
    let end;
    if (!next) {
      end = {surah: 114, ayah: ayahCounts[113]};
    } else if (next.ayah > 1) {
      end = {surah: next.surah, ayah: next.ayah - 1};
    } else {
      end = {surah: next.surah - 1, ayah: ayahCounts[next.surah - 2]};
    }
    return {number: i + 1, start, end};
  });

  return {uidOffset, ayahCounts, juz};
}

// Mirrors ZikrContentParser.isArabic: a line is Arabic when an Arabic letter
// turns up within its first 35 characters.
function isArabicLine(line) {
  return ARABIC_SCRIPT.test([...line].slice(0, 35).join(''));
}

// Mirrors ZikrContentParser.ayahNumberOf.
function ayahNumberOf(line) {
  const match = line.trim().match(/\((\d+)\)\s*$/);
  return match ? Number(match[1]) : null;
}

// A surah document as spans, one per Arabic line - the verse and the lines
// that follow it - the way spansOfParsedContent cuts it. Lines before the
// first verse (a surah's introduction) belong to no span and are dropped.
function surahSpans(content) {
  const lines = `${content?.data ?? ''}`
    .replace(/\r/g, '')
    .split('\n')
    .map((line) => line.trim());
  const arabicIndexes = lines
    .map((line, i) => (line && isArabicLine(line) ? i : -1))
    .filter((i) => i >= 0);

  return arabicIndexes.map((start, i) => ({
    ayah: ayahNumberOf(lines[start]),
    lines: lines
      .slice(start, arabicIndexes[i + 1] ?? lines.length)
      .map((line) => normalizeWhitespace(stripInlineMarkers(line)))
      .filter(Boolean),
  }));
}

function loadSurahs(index, uidOffset) {
  const surahs = [];
  for (let number = 1; number <= 114; number++) {
    const uid = `A${number + uidOffset}`;
    const entry = index[uid];
    const content = loadContent(uid, entry);
    if (!entry?.slug || !content) {
      throw new Error(`Surah ${number} (${uid}) has no slug or no document`);
    }
    const title = normalizeWhitespace(entry.title || content.title);
    // "2: Al-Baqarah البقرة" -> "Al-Baqarah"
    const name = title
      .replace(/^\s*\d+\s*:\s*/, '')
      .replace(/[؀-ۿ\s]+$/, '')
      .trim();
    surahs.push({
      number,
      uid,
      title,
      name,
      canonicalPath: `/zikr/${safeSlug(entry.slug)}`,
      spans: surahSpans(content),
    });
  }
  return surahs;
}

function juzPath(number) {
  return `/quran/juz/${number}`;
}

function juzTitle(number) {
  // The one juz widely searched for by its name rather than its number.
  return number === 30 ? 'Juz 30 (Juz Amma)' : `Juz ${number}`;
}

function verseRef({surah, ayah}) {
  return `${surah}:${ayah}`;
}

// The surahs a juz runs through, each cut to the verses inside the juz. The
// Bismillah opening a surah rides along only when the juz takes that surah
// from its first verse, as _keeps does in lib/utils/quran_portion.dart.
function juzParts(juz, surahs) {
  const parts = [];
  for (let number = juz.start.surah; number <= juz.end.surah; number++) {
    const surah = surahs[number - 1];
    const from = number === juz.start.surah ? juz.start.ayah : 1;
    const to = number === juz.end.surah
      ? juz.end.ayah
      : surah.spans.reduce((max, span) => Math.max(max, span.ayah ?? 0), 0);
    const lines = surah.spans
      .filter((span) => (span.ayah == null ? from <= 1 : span.ayah >= from && span.ayah <= to))
      .flatMap((span) => span.lines);
    parts.push({surah, from, to, lines});
  }
  return parts;
}

function buildJuzPageHtml(templateHtml, juz, surahs) {
  const title = juzTitle(juz.number);
  const canonicalPath = juzPath(juz.number);
  const canonicalUrl = `${SITE_ORIGIN}${canonicalPath}`;
  const first = surahs[juz.start.surah - 1];
  const last = surahs[juz.end.surah - 1];
  const range = `${first.name} ${verseRef(juz.start)} to ${last.name} ${verseRef(juz.end)}`;
  const description = `Read ${title} of the Holy Quran, from ${range}, in Arabic with transliteration and English translation on Shia Companion.`;
  const titleTag = [
    `${title}: Quran in Arabic and English${TITLE_SUFFIX}`,
    `${title} of the Quran${TITLE_SUFFIX}`,
  ].find((candidate) => candidate.length <= MAX_TITLE_TAG_LENGTH) ?? title;

  const previous = juz.number > 1 ? juz.number - 1 : null;
  const next = juz.number < 30 ? juz.number + 1 : null;
  const sequence = [
    previous && `<a href="${juzPath(previous)}">Previous: ${escapeHtml(juzTitle(previous))}</a>`,
    next && `<a href="${juzPath(next)}">Next: ${escapeHtml(juzTitle(next))}</a>`,
  ].filter(Boolean).join(' · ');

  const partsHtml = juzParts(juz, surahs).map(({surah, from, to, lines}) => {
    const whole = from === 1 && to === surah.spans.reduce(
      (max, span) => Math.max(max, span.ayah ?? 0),
      0,
    );
    const heading = whole ? surah.title : `${surah.title}, verses ${from}-${to}`;
    return [
      '      <section class="seo-lines">',
      `        <h2><a href="${escapeHtml(surah.canonicalPath)}">${escapeHtml(heading)}</a></h2>`,
      ...lines.map(lineParagraph),
      '      </section>',
    ].join('\n');
  });

  const staticContent = [
    '  <main class="seo-zikr-content">',
    '    <article>',
    '      <nav aria-label="Breadcrumb"><a href="/">Shia Companion</a> / <a href="/quran">Quran</a></nav>',
    `      <h1>${escapeHtml(title)}</h1>`,
    `      <p>${escapeHtml(description)}</p>`,
    `      <p><a href="${canonicalPath}">Open ${escapeHtml(title)} in Shia Companion</a></p>`,
    ...partsHtml,
    `      <p>${sequence}</p>`,
    '    </article>',
    '  </main>',
  ].join('\n');

  return buildPageHtml(templateHtml, {
    seo: {
      titleTag,
      description,
      canonicalUrl,
      structuredData: buildStructuredData({
        title,
        description,
        canonicalUrl,
        section: QURAN_SECTION,
      }),
    },
    staticContent,
  });
}

function buildQuranIndexPage(templateHtml, surahs, juzList) {
  const canonicalUrl = `${SITE_ORIGIN}/quran`;
  const title = 'The Holy Quran';
  const titleTag = `The Holy Quran: All Surahs and Juz${TITLE_SUFFIX}`;
  const description = 'Read all 114 surahs and 30 juz of the Holy Quran in Arabic with transliteration and English translation on Shia Companion.';
  const staticContent = [
    '  <main class="seo-zikr-content">',
    '    <article>',
    '      <nav aria-label="Breadcrumb"><a href="/">Shia Companion</a></nav>',
    `      <h1>${title}</h1>`,
    `      <p>${escapeHtml(description)}</p>`,
    '      <section>',
    '        <h2>Surahs</h2>',
    '        <ul>',
    ...surahs.map((surah) => `          <li><a href="${escapeHtml(surah.canonicalPath)}">${escapeHtml(surah.title)}</a></li>`),
    '        </ul>',
    '      </section>',
    '      <section>',
    '        <h2>Juz</h2>',
    '        <ul>',
    ...juzList.map((juz) => `          <li><a href="${juzPath(juz.number)}">${escapeHtml(juzTitle(juz.number))}</a></li>`),
    '        </ul>',
    '      </section>',
    '    </article>',
    '  </main>',
  ].join('\n');

  return buildPageHtml(templateHtml, {
    seo: {
      titleTag,
      description,
      canonicalUrl,
      structuredData: buildStructuredData({
        title,
        description,
        canonicalUrl,
        section: QURAN_SECTION,
      }),
    },
    staticContent,
  });
}

// Writes the Quran pages and returns the paths that belong in the sitemap.
function generateQuranPages(templateHtml, index) {
  const {uidOffset, juz: juzList} = readQuranStructure();
  const surahs = loadSurahs(index, uidOffset);

  fs.rmSync(GENERATED_QURAN_DIR, {recursive: true, force: true});

  for (const juz of juzList) {
    writePage(path.join('quran', 'juz', `${juz.number}`), buildJuzPageHtml(templateHtml, juz, surahs));
  }

  for (const surah of surahs) {
    writePage(
      path.join('quran', `${surah.number}`),
      buildRedirectPageHtml({
        title: surah.title,
        canonicalPath: surah.canonicalPath,
        canonicalUrl: `${SITE_ORIGIN}${surah.canonicalPath}`,
      }),
    );
  }

  fs.writeFileSync(
    path.join(GENERATED_QURAN_DIR, 'index.html'),
    buildQuranIndexPage(templateHtml, surahs, juzList),
    'utf8',
  );

  console.log(`Generated the /quran index and ${juzList.length} juz pages in ${GENERATED_QURAN_DIR}`);
  console.log(`Generated ${surahs.length} /quran/<n> surah redirect pages`);

  return ['/quran', ...juzList.map((juz) => juzPath(juz.number))];
}

// --- Library -----------------------------------------------------------------
//
// One page per book: what it is, who wrote and translated it, its chapter
// titles and where it was first published. Deliberately not the chapters'
// text: every book is copied from al-islam.org, alhassanain.org or
// maaref-foundation.com, and pages of text that already lives elsewhere rank
// for the original site rather than this one, and can pull the whole site's
// standing down with them. Chapter links (/library/<book>/<chapter>) stay
// app-only, so the chapter titles are listed as text rather than linked:
// each link would lead a crawler to an app shell it can only file as a copy
// of the home page.

function truncateAtWord(value, max) {
  const text = normalizeWhitespace(value);
  if (text.length <= max) return text;
  const cut = text.slice(0, max - 1);
  const lastSpace = cut.lastIndexOf(' ');
  return `${(lastSpace > max / 2 ? cut.slice(0, lastSpace) : cut).replace(/[\s,;:.]+$/, '')}…`;
}

function sourceSiteName(sourceUrl) {
  try {
    return new URL(sourceUrl).hostname.replace(/^www\./, '');
  } catch (_) {
    return null;
  }
}

// Book slugs come from the library repo and are not held to the zikr rule:
// one ends in a hyphen. Anything that is a single plain path segment is
// fine, since it is what the app opens at /library/<slug> either way.
function safeBookSlug(slug) {
  const normalized = `${slug ?? ''}`.trim();
  if (!/^[a-z0-9-]+$/.test(normalized)) {
    throw new Error(`Unsafe book slug: ${slug}`);
  }
  return normalized;
}

function libraryBookPath(slug) {
  return `/library/${slug}`;
}

function buildBookPageHtml(templateHtml, book) {
  const {title, slug, author, meta} = book;
  const canonicalPath = libraryBookPath(slug);
  const canonicalUrl = `${SITE_ORIGIN}${canonicalPath}`;
  const chapters = meta.chapters ?? [];
  const byline = author ? ` by ${author}` : '';
  const description = meta.description
    ? truncateAtWord(meta.description, 155)
    : truncateAtWord(
      `Read ${title}${byline} free in the Shia Companion library`
        + (chapters.length > 0 ? `: ${chapters.length} chapters.` : '.'),
      155,
    );
  const titleTag = [
    `${title}${TITLE_SUFFIX}`,
  ].find((candidate) => candidate.length <= MAX_TITLE_TAG_LENGTH) ?? title;

  const credits = [
    ['Subtitle', meta.subtitle],
    ['Author', author],
    ['Translator', meta.translator],
    ['Compiler', meta.compiler],
    ['Publisher', meta.publisher],
  ].filter(([, value]) => value);
  const site = sourceSiteName(meta.source_url);

  const staticContent = [
    '  <main class="seo-zikr-content">',
    '    <article>',
    '      <nav aria-label="Breadcrumb"><a href="/">Shia Companion</a> / <a href="/library">Library</a></nav>',
    `      <h1>${escapeHtml(title)}</h1>`,
    ...credits.map(([label, value]) => `      <p>${label}: ${escapeHtml(normalizeWhitespace(value))}</p>`),
    meta.description ? `      <p>${escapeHtml(normalizeWhitespace(meta.description))}</p>` : '',
    `      <p><a href="${escapeHtml(canonicalPath)}">Read ${escapeHtml(title)} in Shia Companion</a></p>`,
    chapters.length > 0
      ? [
        '      <section>',
        '        <h2>Chapters</h2>',
        '        <ol>',
        ...chapters.map((chapter) => `          <li>${escapeHtml(normalizeWhitespace(chapter))}</li>`),
        '        </ol>',
        '      </section>',
      ].join('\n')
      : '',
    site
      ? `      <p>First published on <a href="${escapeHtml(meta.source_url)}" rel="nofollow">${escapeHtml(site)}</a>.</p>`
      : '',
    '    </article>',
    '  </main>',
  ].filter(Boolean).join('\n');

  return buildPageHtml(templateHtml, {
    seo: {
      titleTag,
      description,
      canonicalUrl,
      structuredData: buildStructuredData({
        title,
        description,
        canonicalUrl,
        section: LIBRARY_SECTION,
      }),
    },
    staticContent,
  });
}

function buildLibraryIndexPage(templateHtml, books) {
  const canonicalUrl = `${SITE_ORIGIN}/library`;
  const title = 'Islamic Library';
  const titleTag = `Islamic Library: ${books.length} Shia Books${TITLE_SUFFIX}`;
  const description = `Read ${books.length} Shia Islamic books free in Shia Companion: history, theology, ethics, the lives of the Ahl al-Bayt and more.`;
  const staticContent = [
    '  <main class="seo-zikr-content">',
    '    <article>',
    '      <nav aria-label="Breadcrumb"><a href="/">Shia Companion</a></nav>',
    `      <h1>${title}</h1>`,
    `      <p>${escapeHtml(description)}</p>`,
    '      <ul>',
    ...books.map((book) => {
      const byline = book.author ? ` - ${escapeHtml(book.author)}` : '';
      return `        <li><a href="${escapeHtml(libraryBookPath(book.slug))}">${escapeHtml(book.title)}</a>${byline}</li>`;
    }),
    '      </ul>',
    '    </article>',
    '  </main>',
  ].join('\n');

  return buildPageHtml(templateHtml, {
    seo: {
      titleTag,
      description,
      canonicalUrl,
      structuredData: buildStructuredData({
        title,
        description,
        canonicalUrl,
        section: LIBRARY_SECTION,
      }),
    },
    staticContent,
  });
}

// Writes the library pages and returns the paths that belong in the sitemap.
function generateLibraryPages(templateHtml) {
  fs.rmSync(GENERATED_LIBRARY_DIR, {recursive: true, force: true});
  if (!LIBRARY_INDEX_PATH) {
    console.log('LIBRARY_INDEX not set: skipping the /library pages');
    return [];
  }
  if (!fs.existsSync(LIBRARY_INDEX_PATH)) {
    throw new Error(`LIBRARY_INDEX names a missing file: ${LIBRARY_INDEX_PATH}`);
  }

  const metadata = readJson(LIBRARY_INDEX_PATH);
  const books = readJson(BOOKS_PATH)
    .map((entry) => ({
      slug: safeBookSlug(entry.slug),
      title: normalizeWhitespace(entry.title),
      author: normalizeWhitespace(entry.author) || null,
    }))
    .filter((book) => book.title);

  const missing = books.filter((book) => !metadata[book.slug]);
  if (missing.length > 0) {
    // A book the app lists but the library repo does not have cannot be
    // opened either; better to hear about it than to ship a page for it.
    throw new Error(
      `No library metadata for ${missing.length} book(s): `
      + missing.slice(0, 5).map((book) => book.slug).join(', '),
    );
  }

  for (const book of books) {
    book.meta = metadata[book.slug];
    writePage(path.join('library', book.slug), buildBookPageHtml(templateHtml, book));
  }

  // Retired duplicates still open in the app; give a crawler the same answer.
  const bySlug = new Map(books.map((book) => [book.slug, book]));
  let retiredCount = 0;
  for (const [from, to] of Object.entries(readJson(RETIRED_BOOK_SLUGS_PATH))) {
    const target = bySlug.get(to);
    if (!target || bySlug.has(from)) continue;
    writePage(
      path.join('library', safeBookSlug(from)),
      buildRedirectPageHtml({
        title: target.title,
        canonicalPath: libraryBookPath(target.slug),
        canonicalUrl: `${SITE_ORIGIN}${libraryBookPath(target.slug)}`,
      }),
    );
    retiredCount += 1;
  }

  const sorted = [...books].sort((a, b) => a.title.localeCompare(b.title));
  fs.writeFileSync(
    path.join(GENERATED_LIBRARY_DIR, 'index.html'),
    buildLibraryIndexPage(templateHtml, sorted),
    'utf8',
  );

  console.log(`Generated the /library index and ${books.length} book pages in ${GENERATED_LIBRARY_DIR}`);
  console.log(`Generated ${retiredCount} retired book redirect pages`);

  return ['/library', ...sorted.map((book) => libraryBookPath(book.slug))];
}

function main() {
  if (!fs.existsSync(FLUTTER_INDEX_PATH)) {
    throw new Error(
      `Could not find ${FLUTTER_INDEX_PATH}. Ensure web/index.html exists before generating zikr SEO pages.`,
    );
  }

  // `flutter build web` substitutes $FLUTTER_BASE_HREF only in the root
  // index.html it emits; a copy of the template placed in a subdirectory keeps
  // the literal placeholder. That ships a page whose <base> is an invalid URL,
  // so every relative asset — flutter_bootstrap.js included — fails to load and
  // the page never boots. It only bites when the generator runs against the
  // web/ source tree, which the pre-push hook does. Pin it to the site root.
  const templateHtml = fs
    .readFileSync(FLUTTER_INDEX_PATH, 'utf8')
    .replace(/\$FLUTTER_BASE_HREF/g, '/');
  const index = readJson(ZIKR_INDEX_PATH);
  const pages = [];
  const slugs = new Map();
  const listShells = [];

  for (const [uid, entry] of Object.entries(index)) {
    if (!entry?.slug) continue;
    const content = loadContent(uid, entry);
    if (!content) {
      // List headers (`~` uids) have a slug the app opens as a list but no
      // text of their own. Hosting no longer rewrites unknown /zikr/<slug>
      // paths to the app shell, so give these a shell page of their own to
      // keep their links working. Kept out of the index: there is no text.
      listShells.push({
        slug: safeSlug(entry.slug),
        title: normalizeWhitespace(entry.title || humanizeSlug(entry.slug)),
      });
      continue;
    }

    const slug = safeSlug(entry.slug);
    if (slugs.has(slug)) {
      const existingUid = slugs.get(slug);
      // A `|`-alias deliberately reuses its canonical target's exact slug
      // when they share the same title (see uid_title_data.dart's `|`
      // convention) - contentUidFor resolves both sides to the same
      // assets/zikr/<uid> file, so this is the same page twice, not a
      // conflict. Keep whichever claimed the slug first; skip the other,
      // but carry over its slugAliases: the canonical usually holds them, and
      // Hosting 404s any /zikr/<slug> without a page of its own.
      if (contentUidFor(uid) === contentUidFor(existingUid) &&
          !index[uid].tabs && !index[existingUid].tabs) {
        const kept = pages.find((page) => page.slug === slug);
        for (const alias of Array.isArray(entry.slugAliases) ? entry.slugAliases.map(safeSlug) : []) {
          if (!kept.aliases.includes(alias)) kept.aliases.push(alias);
        }
        continue;
      }
      throw new Error(`Duplicate zikr slug "${slug}" for ${uid} and ${existingUid}`);
    }
    slugs.set(slug, uid);

    const title = normalizeWhitespace(entry.title || content.title || humanizeSlug(slug));
    const canonicalPath = `/zikr/${slug}`;
    const canonicalUrl = `${SITE_ORIGIN}${canonicalPath}`;
    const description = buildDescription(title, slug, content);
    const titleTag = buildTitleTag(title, slug);

    pages.push({
      uid,
      title,
      slug,
      canonicalPath,
      html: buildPageHtml(templateHtml, {
        seo: {
          titleTag,
          description,
          canonicalUrl,
          structuredData: buildStructuredData({title, description, canonicalUrl}),
        },
        staticContent: buildStaticContent({title, description, canonicalPath, content}),
      }),
      aliases: Array.isArray(entry.slugAliases) ? entry.slugAliases.map(safeSlug) : [],
    });
  }

  pages.sort((a, b) => a.slug.localeCompare(b.slug));

  const pagesBySlug = new Map(pages.map((page) => [page.slug, page]));
  for (const [fromSlug, toSlug] of Object.entries(MERGED_ZIKR_SLUGS)) {
    const from = pagesBySlug.get(fromSlug);
    const to = pagesBySlug.get(toSlug);
    if (!from || !to) {
      throw new Error(`MERGED_ZIKR_SLUGS names a missing page: ${fromSlug} -> ${toSlug}`);
    }
    if (contentUidFor(from.uid) !== contentUidFor(to.uid)) {
      throw new Error(`MERGED_ZIKR_SLUGS pair does not share content: ${fromSlug} -> ${toSlug}`);
    }
    from.redirectTo = to;
  }
  const indexedPages = pages.filter((page) => !page.redirectTo);

  fs.rmSync(GENERATED_ZIKR_DIR, {recursive: true, force: true});

  let mergedCount = 0;
  for (const page of pages) {
    if (page.redirectTo) {
      const redirectHtml = buildRedirectPageHtml({
        title: page.redirectTo.title,
        canonicalPath: page.redirectTo.canonicalPath,
        canonicalUrl: `${SITE_ORIGIN}${page.redirectTo.canonicalPath}`,
      });
      for (const slug of [page.slug, ...page.aliases]) {
        writePage(path.join('zikr', slug), redirectHtml);
      }
      mergedCount += 1;
      continue;
    }
    writePage(path.join('zikr', page.slug), page.html);
  }

  for (const shell of listShells) {
    if (pagesBySlug.has(shell.slug)) continue;
    const shellHtml = templateHtml
      .replace(
        /\s*<!-- Home page only:[\s\S]*?-->\s*<script type="application\/ld\+json" id="home-structured-data">[\s\S]*?<\/script>/i,
        '',
      )
      .replace(/<title>[\s\S]*?<\/title>/i, `<title>${escapeHtml(shell.title)}${TITLE_SUFFIX}</title>`)
      .replace(/<meta\s+name=["']robots["'][^>]*>/i, '<meta name="robots" content="noindex, follow">')
      .replace(/<link\s+rel=["']canonical["'][^>]*>/i, `<link rel="canonical" href="${SITE_ORIGIN}/zikr/${shell.slug}">`);
    writePage(path.join('zikr', shell.slug), shellHtml);
  }

  const canonicalSlugs = new Set(pages.map((page) => page.slug));
  let aliasCount = 0;
  for (const page of pages) {
    if (page.redirectTo) continue;
    for (const alias of page.aliases) {
      if (alias === page.slug || canonicalSlugs.has(alias)) continue;
      writePage(path.join('zikr', alias), page.html);
      aliasCount += 1;
    }
  }

  fs.rmSync(GENERATED_UID_REDIRECT_DIR, {recursive: true, force: true});
  let redirectCount = 0;
  for (const page of pages) {
    // `~` (list headers) and `|` (aliases) uids need percent-encoding in a
    // URL path segment. They're rare in shared links (the app only ever
    // shares a plain uid this way), so leave them to the app's own
    // client-side rewrite rather than risk a directory name Hosting won't
    // match byte-for-byte against the encoded request path.
    if (page.uid.includes('~') || page.uid.includes('|')) continue;

    const target = page.redirectTo ?? page;
    writePage(
      path.join('0', page.uid),
      buildRedirectPageHtml({
        title: target.title,
        canonicalPath: target.canonicalPath,
        canonicalUrl: `${SITE_ORIGIN}${target.canonicalPath}`,
      }),
    );
    redirectCount += 1;
  }

  const quranPaths = generateQuranPages(templateHtml, index);
  const libraryPaths = generateLibraryPages(templateHtml);

  const sitemap = buildSitemap([
    ...indexedPages.map((page) => page.canonicalPath),
    ...quranPaths,
    ...libraryPaths,
  ]);
  for (const filename of SITEMAP_FILENAMES) {
    fs.writeFileSync(path.join(BUILD_WEB_DIR, filename), sitemap, 'utf8');
  }
  fs.writeFileSync(
    path.join(GENERATED_ZIKR_DIR, 'index.html'),
    buildZikrIndexPage(templateHtml, indexedPages),
    'utf8',
  );

  console.log(`Generated ${pages.length} zikr SEO pages in ${GENERATED_ZIKR_DIR}`);
  console.log(`Generated ${aliasCount} zikr alias pages`);
  console.log(`Redirected ${mergedCount} duplicate zikr slugs to their merged page`);
  console.log(`Generated ${listShells.length} list shell pages`);
  console.log(
    `Generated ${redirectCount} legacy uid redirect pages in ${GENERATED_UID_REDIRECT_DIR}`,
  );
  console.log(
    `Generated ${SITEMAP_FILENAMES.join(', ')} with `
    + `${(sitemap.match(/<loc>/g) ?? []).length} URLs`,
  );
}

main();
