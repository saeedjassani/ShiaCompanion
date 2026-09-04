'use strict';
// Every path the screenshot pipeline needs, resolved once. Overridable by env
// so this runs the same on a laptop as on a throwaway container.
const path = require('path');
const REPO = path.resolve(__dirname, '..', '..');
const HERE = __dirname;

module.exports = {
  REPO,
  HERE,
  // The built Flutter web bundle the captures run against.
  WEB_BUILD_DIR: process.env.WEB_BUILD_DIR || path.join(REPO, 'build', 'web'),
  PORT: Number(process.env.PORT || 4173),
  // Playwright's own Chromium unless a path is given. On the CI image the
  // browser is pre-installed and must not be re-downloaded.
  CHROME_PATH: process.env.CHROME_PATH || undefined,
  VENDOR: path.join(HERE, 'vendor'),
  RAW_DIR: process.env.RAW_DIR || path.join(HERE, 'out', 'raw'),
  OUT_DIR: process.env.OUT_DIR || path.join(HERE, 'out', 'store'),
  // Where the location fix is pinned, so prayer times resolve to real values.
  GEO: {latitude: 37.5485, longitude: -121.9886},
  TIMEZONE: process.env.TZ_OVERRIDE || 'America/Los_Angeles',
};
