'use strict';

const fs = require('fs');
const path = require('path');
const {test, expect} = require('@playwright/test');
const {BUILD_DIR, sampleGeneratedZikrPages} = require('./helpers');

// The origin baked into the generated sitemap. Matches the default in
// scripts/generate_zikr_seo_pages.js and the site-origin input on the
// build-web action.
const SITE_ORIGIN = (process.env.SITE_ORIGIN || 'https://shia-companion.web.app')
  .replace(/\/+$/, '');

// These checks run against the built bundle, not the rendered app, so one
// project is enough — the other would assert identical bytes.
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name !== 'desktop');
});

function locsFrom(xml) {
  return [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1]);
}

/**
 * Resolves a sitemap path the way Firebase Hosting does when it looks for a
 * real file: exact match first, then <path>/index.html. Returns null when only
 * the "**" rewrite could serve it.
 */
function resolveBundleFile(urlPath) {
  const relative = urlPath.replace(/^\/+/, '');
  const candidates = relative === ''
    ? ['index.html']
    : [relative, path.join(relative, 'index.html')];

  for (const candidate of candidates) {
    const filePath = path.join(BUILD_DIR, candidate);
    if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
      return filePath;
    }
  }
  return null;
}

test.describe('sitemap.xml', () => {
  test('is served as parseable XML rather than the app shell', async ({request}) => {
    const response = await request.get('/sitemap.xml');
    expect(response.status()).toBe(200);

    const contentType = response.headers()['content-type'] ?? '';
    expect(contentType, 'firebase.json pins this to application/xml').toContain('xml');

    const body = await response.text();
    // The failure this guards: sitemap.xml missing from build/web, so the
    // rewrite returns index.html under an XML content type. Search Console
    // reports that as "Couldn't fetch", which reads like a network problem and
    // is not one.
    expect(
      body.toLowerCase(),
      'sitemap.xml is serving the Flutter app shell — it is missing from the bundle',
    ).not.toContain('<!doctype html');
    expect(body.trimStart()).toMatch(/^<\?xml version="1\.0" encoding="UTF-8"\?>/);
    expect(body).toContain('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
    expect(body.trimEnd().endsWith('</urlset>')).toBe(true);
  });

  test('lists every generated zikr page exactly once', async ({request}) => {
    const locs = locsFrom(await (await request.get('/sitemap.xml')).text());

    expect(new Set(locs).size, 'duplicate <loc> entries').toBe(locs.length);
    expect(locs.length).toBeLessThanOrEqual(50000);
    for (const loc of locs) {
      expect(loc, 'every <loc> must be absolute and on the production origin')
        .toMatch(new RegExp(`^${SITE_ORIGIN}/`));
    }

    const generated = sampleGeneratedZikrPages(Number.MAX_SAFE_INTEGER);
    expect(
      generated.length,
      'no pre-rendered zikr pages in the bundle — the generator did not target build/web',
    ).toBeGreaterThan(0);

    // Compare on canonical URL rather than directory name. Alias directories
    // are deliberately absent from the sitemap: each one self-canonicalises to
    // the slug it duplicates, so listing it would submit the same page twice.
    for (const slug of generated) {
      const html = fs.readFileSync(
        path.join(BUILD_DIR, 'zikr', slug, 'index.html'),
        'utf8',
      );
      const canonical = html.match(/<link rel="canonical" href="([^"]+)">/)?.[1];
      expect(canonical, `zikr/${slug} has no canonical link`).toBeTruthy();
      expect(locs, `zikr/${slug} canonicalises to a URL missing from the sitemap`)
        .toContain(canonical);
    }

    expect(locs).toContain(`${SITE_ORIGIN}/`);
    expect(locs).toContain(`${SITE_ORIGIN}/privacy.html`);
    expect(locs).toContain(`${SITE_ORIGIN}/delete_account.html`);
  });

  test('points only at paths backed by a real file in the bundle', async ({request}) => {
    const locs = locsFrom(await (await request.get('/sitemap.xml')).text());

    const rewriteOnly = locs
      .map((loc) => loc.slice(SITE_ORIGIN.length) || '/')
      .filter((urlPath) => resolveBundleFile(urlPath) === null);

    // A path served only by the "**" rewrite returns the app shell: identical
    // bytes for every such URL, which Google folds into the home page instead
    // of indexing.
    expect(
      rewriteOnly,
      'these sitemap URLs have no file in the bundle and resolve to the app shell',
    ).toEqual([]);
  });

  test('serves every listed URL directly, with no redirect', async ({request}) => {
    const locs = locsFrom(await (await request.get('/sitemap.xml')).text());

    // Checking the filesystem is not enough: the file can exist and the URL
    // still 301 elsewhere. Hosting serves <dir>/index.html at /<dir> or at
    // /<dir>/ depending on trailingSlash, and the generated pages name the
    // slash-less form as their canonical. When the sitemap URL redirects,
    // Google indexes the target while the target's rel=canonical points back
    // at the URL it just came from.
    const redirected = [];
    for (const loc of locs.slice(0, 40)) {
      const urlPath = loc.slice(SITE_ORIGIN.length) || '/';
      const response = await request.get(urlPath, {maxRedirects: 0});
      if (response.status() !== 200) {
        redirected.push(
          `${urlPath} -> ${response.status()} ${response.headers()['location'] ?? ''}`.trim(),
        );
      }
    }

    expect(
      redirected,
      'sitemap URLs must be the final URL, not one that redirects',
    ).toEqual([]);
  });
});

test.describe('internal linking', () => {
  test('the home page links into the zikr pages', async ({request}) => {
    const html = await (await request.get('/')).text();
    const nav = html.match(
      /<nav class="seo-site-nav"[\s\S]*?<\/nav>/,
    )?.[0];

    // Without this the rendered DOM is one canvas and no link at all, leaving
    // the sitemap as the only route to 433 pages. Sitemap-only URLs with
    // nothing pointing at them are what Google reports as "Discovered -
    // currently not indexed".
    expect(nav, 'the home page has no crawlable nav').toBeTruthy();

    const hrefs = [...nav.matchAll(/href="([^"]+)"/g)].map((match) => match[1]);
    expect(hrefs).toContain('/zikr');

    const zikrLinks = hrefs.filter((href) => href.startsWith('/zikr/'));
    expect(
      zikrLinks.length,
      'the nav should reach individual zikr pages, not just the index',
    ).toBeGreaterThan(5);

    // Every one of these is hand-written, so a renamed or dropped slug would
    // otherwise become a 404 that only shows up in production.
    const broken = hrefs.filter((href) => resolveBundleFile(href) === null);
    expect(broken, 'nav links with no page in the bundle').toEqual([]);
  });

  test('the zikr index links to every generated page', async ({request}) => {
    const html = await (await request.get('/zikr')).text();
    const hrefs = new Set(
      [...html.matchAll(/href="(\/zikr\/[^"]+)"/g)].map((match) => match[1]),
    );

    const locs = locsFrom(await (await request.get('/sitemap.xml')).text())
      .map((loc) => loc.slice(SITE_ORIGIN.length))
      .filter((urlPath) => urlPath.startsWith('/zikr/'));

    // The index is the hub the home page points at: if a sitemap URL is
    // missing from it, that page has no inbound link anywhere on the site.
    const unlinked = locs.filter((urlPath) => !hrefs.has(urlPath));
    expect(unlinked, 'sitemap pages missing from the /zikr index').toEqual([]);
  });
});

test('robots.txt allows crawling and advertises the sitemap', async ({request}) => {
  const response = await request.get('/robots.txt');
  expect(response.status()).toBe(200);

  const body = await response.text();
  expect(body).toMatch(/^\s*User-agent:\s*\*/m);
  expect(body, 'a bare "Disallow: /" hides the whole site')
    .not.toMatch(/^\s*Disallow:\s*\/\s*$/m);
  expect(body).toContain(`Sitemap: ${SITE_ORIGIN}/sitemap.xml`);
  expect(body).toContain(`Sitemap: ${SITE_ORIGIN}/sitemap-all.xml`);
});

// A duplicate of sitemap.xml at a path Search Console has never seen, so a
// stuck "Couldn't fetch" verdict on the original can be sidestepped by
// submitting this instead. Serving one but not the other would hand Search
// Console a second broken URL, which is the whole failure being worked around.
test('sitemap-all.xml duplicates sitemap.xml exactly', async ({request}) => {
  const [canonical, duplicate] = await Promise.all([
    request.get('/sitemap.xml'),
    request.get('/sitemap-all.xml'),
  ]);

  expect(duplicate.status()).toBe(200);
  expect(
    duplicate.headers()['content-type'] ?? '',
    'firebase.json must match /sitemap*.xml, not just /sitemap.xml',
  ).toContain('xml');
  expect(await duplicate.text()).toBe(await canonical.text());
});

test('generated pages carry a substituted <base href>', () => {
  const slugs = sampleGeneratedZikrPages();
  expect(slugs.length).toBeGreaterThan(0);

  for (const slug of slugs) {
    const html = fs.readFileSync(
      path.join(BUILD_DIR, 'zikr', slug, 'index.html'),
      'utf8',
    );
    // An unsubstituted placeholder makes <base> an invalid URL, so every
    // relative asset on the page — flutter_bootstrap.js included — 404s.
    expect(html, `zikr/${slug} kept the literal $FLUTTER_BASE_HREF placeholder`)
      .not.toContain('$FLUTTER_BASE_HREF');
    // Alias directories canonicalise to the slug they duplicate, so match the
    // shape rather than the directory name.
    expect(html).toMatch(
      new RegExp(`<link rel="canonical" href="${SITE_ORIGIN}/zikr/[a-z0-9-]+">`),
    );
  }
});
