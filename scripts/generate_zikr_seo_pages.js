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
const SITE_ORIGIN = (process.env.SITE_ORIGIN || 'https://shia-companion.web.app')
  .replace(/\/+$/, '');
const MAX_SECTION_LINES = 80;

// Search Console pins a "Couldn't fetch" verdict to a sitemap URL and will not
// clear it on resubmission, even after the URL serves valid XML again — and it
// does: status, content-type, XML validity, Googlebot UA, IPv6, TLS 1.2 and
// HTTP/1.1 all check out, and URL Inspection reports "URL is available to
// Google". Publishing the identical sitemap at a second path gives Search
// Console a URL carrying no cached verdict. Both files are written from one
// string, so they cannot drift. Drop the second path once /sitemap.xml reports
// Success.
const SITEMAP_FILENAMES = ['sitemap.xml', 'sitemap-all.xml'];

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

function loadContent(uid) {
  const contentUid = contentUidFor(uid);
  if (!contentUid) return null;

  const filePath = contentPathFor(contentUid);
  if (!fs.existsSync(filePath)) return null;

  return readJson(filePath);
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

  return `Read ${displayTitle} with Arabic text, transliteration, English translation, and merits on Shia Companion.`;
}

function buildTitleTag(title, slug) {
  const humanSlugTitle = humanizeSlug(slug);
  if (humanSlugTitle && !sameNormalizedTitle(title, humanSlugTitle)) {
    return `${title} | ${humanSlugTitle} | Shia Companion`;
  }
  return `${title} | Shia Companion`;
}

function buildStructuredData({title, description, canonicalUrl}) {
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
          name: 'Zikr',
          item: `${SITE_ORIGIN}/zikr`,
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
  let output = html;
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
    .filter((line) => !merits.includes(line))
    .slice(0, MAX_SECTION_LINES);

  const meritsHtml = merits.length > 0
    ? [
      '      <section>',
      '        <h2>Merits</h2>',
      ...merits.map((line) => `        <p>${escapeHtml(line)}</p>`),
      '      </section>',
    ].join('\n')
    : '';

  const bodyHtml = bodyLines.length > 0
    ? [
      '      <section class="seo-lines">',
      '        <h2>Text and Translation</h2>',
      ...bodyLines.map((line) => `        <p>${escapeHtml(line)}</p>`),
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
  return html.replace(/<body([^>]*)>/i, `<body$1>\n${staticContent}`);
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

  for (const [uid, entry] of Object.entries(index)) {
    if (!entry?.slug) continue;
    const content = loadContent(uid);
    if (!content) continue;

    const slug = safeSlug(entry.slug);
    if (slugs.has(slug)) {
      throw new Error(`Duplicate zikr slug "${slug}" for ${uid} and ${slugs.get(slug)}`);
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
  fs.rmSync(GENERATED_ZIKR_DIR, {recursive: true, force: true});

  for (const page of pages) {
    writePage(path.join('zikr', page.slug), page.html);
  }

  const canonicalSlugs = new Set(pages.map((page) => page.slug));
  let aliasCount = 0;
  for (const page of pages) {
    for (const alias of page.aliases) {
      if (alias === page.slug || canonicalSlugs.has(alias)) continue;
      writePage(path.join('zikr', alias), page.html);
      aliasCount += 1;
    }
  }

  const sitemap = buildSitemap(pages.map((page) => page.canonicalPath));
  for (const filename of SITEMAP_FILENAMES) {
    fs.writeFileSync(path.join(BUILD_WEB_DIR, filename), sitemap, 'utf8');
  }
  fs.writeFileSync(
    path.join(GENERATED_ZIKR_DIR, 'index.html'),
    buildZikrIndexPage(templateHtml, pages),
    'utf8',
  );

  console.log(`Generated ${pages.length} zikr SEO pages in ${GENERATED_ZIKR_DIR}`);
  console.log(`Generated ${aliasCount} zikr alias pages`);
  console.log(
    `Generated ${SITEMAP_FILENAMES.join(', ')} with `
    + `${(sitemap.match(/<loc>/g) ?? []).length} URLs`,
  );
}

main();
