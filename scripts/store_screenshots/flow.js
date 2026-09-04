'use strict';
// Drives the app to each screen worth showing and saves a raw capture.
// Flutter paints to a canvas, so every step is a coordinate tap expressed as a
// fraction of the viewport; that survives a change of device size, which a
// pixel offset would not.
const fs = require('fs');
const {launch, openApp} = require('./lib');
const {RAW_DIR} = require('./config');

const OUT = RAW_DIR;

async function tapF(page, fx, fy, settle = 2600) {
  const vp = page.viewportSize();
  await page.touchscreen.tap(Math.round(vp.width * fx), Math.round(vp.height * fy));
  await page.waitForTimeout(settle);
}

async function shot(page, name) {
  fs.mkdirSync(OUT, {recursive: true});
  await page.screenshot({path: `${OUT}/${name}.png`});
  console.log('captured', name);
}

// The location card is an empty state until a fix is resolved; tapping it
// raises the app's own rationale dialog before the browser prompt.
async function enableLocation(page) {
  await tapF(page, 0.5, 0.351, 2500);       // location card
  await tapF(page, 0.73, 0.599, 12000);     // "Continue" in the rationale dialog
}

module.exports = {launch, openApp, tapF, shot, enableLocation, OUT};
