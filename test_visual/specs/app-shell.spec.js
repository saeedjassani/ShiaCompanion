'use strict';

const {test, expect} = require('@playwright/test');
const {
  assertNoFailures,
  bootFlutterApp,
  watchForFailures,
} = require('./helpers');

// Routes the Flutter app itself has to render. Everything reachable only by
// tapping inside the canvas is covered by the render tests in
// test/ui/page_render_test.dart — Playwright cannot address widgets inside a
// canvas reliably.
//
// These deliberately do not compare screenshots. The home screen shows a
// randomly chosen hadith, so its height changes between loads and shifts
// everything below it; a baseline would fail on the next run for reasons that
// have nothing to do with the UI being broken. What is asserted instead — the
// engine reaching first frame, a laid-out canvas, no console errors and no
// same-origin 4xx — is deterministic and catches the failure that matters,
// which is the page not rendering at all. Pixel comparison is kept for the
// static HTML pages, which are stable.
const APP_ROUTES = [
  {name: 'home', path: '/'},
  {name: 'delete-account', path: '/delete-account'},
];

for (const route of APP_ROUTES) {
  test(`${route.name} boots and paints a frame`, async ({page, baseURL}) => {
    const failures = watchForFailures(page, baseURL);

    await bootFlutterApp(page, route.path);

    // #app-loading is gone, so Flutter reached first frame. Confirm the canvas
    // is actually on screen rather than a zero-sized element.
    const canvasBox = await page
      .locator('flutter-view, flt-glass-pane')
      .first()
      .boundingBox();
    expect(canvasBox, 'Flutter view has no layout box').not.toBeNull();
    expect(canvasBox.width).toBeGreaterThan(100);
    expect(canvasBox.height).toBeGreaterThan(100);

    assertNoFailures(failures);
  });
}

test('unknown deep links fall back to the app instead of a 404', async ({
  page,
  baseURL,
}) => {
  const failures = watchForFailures(page, baseURL);

  const response = await page.goto('/definitely-not-a-real-route');
  expect(response?.status()).toBe(200);

  await page.waitForSelector('#app-loading', {state: 'detached', timeout: 60000});
  assertNoFailures(failures);
});

test('hosting serves the app association files as JSON', async ({request}) => {
  for (const route of [
    '/apple-app-site-association',
    '/.well-known/apple-app-site-association',
    '/.well-known/assetlinks.json',
  ]) {
    const response = await request.get(route);
    expect(response.status(), `${route} status`).toBe(200);
    expect(response.headers()['content-type'], `${route} content-type`).toContain(
      'application/json',
    );
    // Must parse — a rewrite regression would serve index.html here instead.
    const body = await response.text();
    expect(() => JSON.parse(body), `${route} is valid JSON`).not.toThrow();
  }
});
