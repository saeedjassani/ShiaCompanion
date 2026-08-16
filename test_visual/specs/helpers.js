'use strict';

const fs = require('fs');
const path = require('path');

const BUILD_DIR = path.resolve(
  __dirname,
  '..',
  process.env.WEB_BUILD_DIR || '../build/web',
);

// Console noise that says nothing about our UI: third-party SDK chatter and
// network conditions on the runner. Anything not listed here fails the test.
const IGNORED_CONSOLE_PATTERNS = [
  /favicon/i,
  /net::ERR_INTERNET_DISCONNECTED/i,
  /net::ERR_NAME_NOT_RESOLVED/i,
  /Failed to load resource.*firebase/i,
  /Failed to load resource.*googleapis/i,
  /Failed to load resource.*google-analytics/i,
  /Failed to load resource.*gstatic/i,
  /\[Firebase\/Analytics\]/i,
  /installations\/request-failed/i,
  /Access to (XMLHttpRequest|fetch) at/i,
  /Cross-Origin-Embedder-Policy/i,
];

function isIgnorable(text) {
  return IGNORED_CONSOLE_PATTERNS.some((pattern) => pattern.test(text));
}

/**
 * Starts collecting the failures that mean "the UI is broken":
 * uncaught exceptions, console errors, and same-origin assets that 404.
 * Third-party/network failures are ignored so the suite stays trustworthy.
 */
function watchForFailures(page, baseURL) {
  const failures = [];

  page.on('pageerror', (error) => {
    failures.push(`Uncaught exception: ${error.message}`);
  });

  page.on('console', (message) => {
    if (message.type() !== 'error') return;
    const text = message.text();
    if (!isIgnorable(text)) failures.push(`Console error: ${text}`);
  });

  page.on('response', (response) => {
    const url = response.url();
    if (!url.startsWith(baseURL)) return;
    if (response.status() >= 400) {
      failures.push(`Asset ${response.status()}: ${url}`);
    }
  });

  page.on('requestfailed', (request) => {
    const url = request.url();
    if (!url.startsWith(baseURL)) return;
    const error = request.failure()?.errorText ?? 'unknown';
    // A cancelled request is not a broken asset. Flutter abandons font fetches
    // it decides it no longer needs, and anything still in flight when the test
    // ends aborts too — neither says the file is missing. A genuinely absent
    // asset answers with a 404, which the response handler above catches.
    if (error.includes('ERR_ABORTED')) return;
    failures.push(`Request failed: ${url} (${error})`);
  });

  return failures;
}

/**
 * Loads a route and waits for Flutter to paint. web/index.html removes
 * #app-loading on the `flutter-first-frame` event, so the shell disappearing
 * is a direct signal that the engine booted and produced a frame — the exact
 * failure mode a blank white page represents.
 */
async function bootFlutterApp(page, route) {
  await page.goto(route, {waitUntil: 'domcontentloaded'});
  await page.waitForSelector('#app-loading', {state: 'detached', timeout: 60000});
  await page.waitForSelector('flutter-view, flt-glass-pane', {timeout: 30000});
  // Let the first layout settle before any screenshot comparison.
  await page.waitForTimeout(1500);
}

function assertNoFailures(failures) {
  if (failures.length > 0) {
    throw new Error(
      `Page reported ${failures.length} failure(s):\n  - ${failures.join('\n  - ')}`,
    );
  }
}

/** A stable, alphabetical sample of the generated zikr SEO pages. */
function sampleGeneratedZikrPages(limit = 5) {
  const zikrDir = path.join(BUILD_DIR, 'zikr');
  if (!fs.existsSync(zikrDir)) return [];
  return fs
    .readdirSync(zikrDir, {withFileTypes: true})
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .filter((slug) =>
      fs.existsSync(path.join(zikrDir, slug, 'index.html')),
    )
    .sort()
    .slice(0, limit);
}

/**
 * Compares against a committed baseline when one exists, and seeds it when one
 * does not.
 *
 * A first run on a machine with no baselines must not fail — there is nothing
 * to regress against yet. Seeded baselines are uploaded as a CI artifact;
 * commit them under test_visual/specs/__screenshots__/ and every later run
 * enforces them.
 */
async function expectScreenshot(page, expect, testInfo, name, options = {}) {
  const baseline = testInfo.snapshotPath(name);

  if (fs.existsSync(baseline)) {
    await expect(page).toHaveScreenshot(name, options);
    return;
  }

  // Seed it either way, and attach it, so the image is downloadable from the
  // run that needed it — a linux baseline cannot be produced on a developer's
  // macOS machine, so the CI artifact is the only way to obtain one.
  fs.mkdirSync(path.dirname(baseline), {recursive: true});
  fs.writeFileSync(baseline, await page.screenshot(options));
  await testInfo.attach(`seeded baseline: ${name}`, {
    path: baseline,
    contentType: 'image/png',
  });

  // On CI a missing baseline has to fail. Seeding and passing is right the
  // first time, when there is nothing to compare against, but left in place it
  // means any screenshot added later is quietly never checked: the run seeds
  // it, goes green, and nobody learns the assertion is inert.
  if (process.env.CI) {
    throw new Error(
      `No committed baseline for ${name}.\n` +
        `Expected: ${path.relative(process.cwd(), baseline)}\n` +
        'It has been seeded and attached to this run — download the ' +
        'playwright-web artifact, commit the file, and this becomes an ' +
        'enforced comparison.',
    );
  }

  console.warn(
    `[visual] seeded new baseline ${path.relative(process.cwd(), baseline)} — ` +
      'commit it to enforce this screenshot on future runs.',
  );
}

module.exports = {
  BUILD_DIR,
  assertNoFailures,
  bootFlutterApp,
  expectScreenshot,
  sampleGeneratedZikrPages,
  watchForFailures,
};
