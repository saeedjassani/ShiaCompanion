'use strict';

const {defineConfig, devices} = require('@playwright/test');

const PORT = Number(process.env.PORT || 4173);

module.exports = defineConfig({
  testDir: './specs',
  // One reviewable directory of committed baselines, split per viewport.
  snapshotPathTemplate: '{testDir}/__screenshots__/{projectName}/{arg}{ext}',
  // The web app is one canvas; a hung frame fails slowly, so give it room.
  timeout: 90 * 1000,
  expect: {
    timeout: 30 * 1000,
    toHaveScreenshot: {
      // Canvas text rendering is never bit-identical across runs. Allow a
      // small fraction of pixels to differ so real layout breakage stands out
      // from antialiasing noise.
      maxDiffPixelRatio: 0.02,
      threshold: 0.25,
      animations: 'disabled',
    },
  },
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 2 : undefined,
  reporter: process.env.CI
    ? [['github'], ['html', {outputFolder: 'report', open: 'never'}]]
    : [['list']],
  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'desktop',
      use: {...devices['Desktop Chrome'], viewport: {width: 1280, height: 800}},
    },
    {
      name: 'mobile',
      // Plain Chromium at a phone viewport rather than a device descriptor:
      // the index.html download banner only renders for mobile user agents and
      // would make every screenshot flaky on a timer.
      use: {...devices['Desktop Chrome'], viewport: {width: 390, height: 844}},
    },
  ],
  webServer: {
    command: 'node serve.js',
    url: `http://127.0.0.1:${PORT}`,
    reuseExistingServer: !process.env.CI,
    timeout: 60 * 1000,
    env: {
      WEB_BUILD_DIR: process.env.WEB_BUILD_DIR || '../build/web',
      PORT: String(PORT),
    },
  },
});
