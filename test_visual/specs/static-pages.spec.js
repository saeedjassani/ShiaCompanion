'use strict';

const {test, expect} = require('@playwright/test');
const {
  assertNoFailures,
  expectScreenshot,
  sampleGeneratedZikrPages,
  watchForFailures,
} = require('./helpers');

// Hand-written pages served straight from web/. These are real DOM, so they
// are asserted on content rather than pixels alone.
const STATIC_PAGES = [
  {name: 'privacy', path: '/privacy.html'},
  {name: 'delete-account-form', path: '/delete_account.html'},
];

for (const page_ of STATIC_PAGES) {
  test(`${page_.name} renders`, async ({page, baseURL}, testInfo) => {
    const failures = watchForFailures(page, baseURL);

    const response = await page.goto(page_.path, {waitUntil: 'load'});
    expect(response?.status()).toBe(200);

    await expect(page.locator('body')).not.toBeEmpty();
    assertNoFailures(failures);

    await expectScreenshot(page, expect, testInfo, `${page_.name}.png`, {
      fullPage: true,
    });
  });
}

test.describe('generated zikr SEO pages', () => {
  const slugs = sampleGeneratedZikrPages();

  for (const slug of slugs) {
    test(`zikr/${slug} serves pre-rendered content`, async ({page, baseURL}) => {
      const failures = watchForFailures(page, baseURL);

      const response = await page.goto(`/zikr/${slug}/`, {
        waitUntil: 'domcontentloaded',
      });
      expect(response?.status()).toBe(200);

      // The crawler-visible payload must be in the HTML, not painted later by
      // Flutter — that is the entire point of these pages.
      const seoContent = page.locator('.seo-zikr-content');
      await expect(seoContent).toHaveCount(1);
      await expect(seoContent).not.toBeEmpty();

      const title = await page.title();
      expect(title.length, `zikr/${slug} has no <title>`).toBeGreaterThan(0);
      expect(title).not.toBe('Shia Companion - Dua, Ziyarat & Prayer Times');

      const description = page.locator('meta[name="description"]');
      await expect(description).toHaveCount(1);
      expect(
        (await description.getAttribute('content'))?.length ?? 0,
      ).toBeGreaterThan(0);

      assertNoFailures(failures);
    });
  }
});
