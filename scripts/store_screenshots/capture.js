'use strict';
// Final capture pass: every screen in dark mode, phone and tablet.
const {launch, openApp, tapF, shot} = require('./flow');

const PHONE = {width: 430, height: 932, dark: true};
const TABLET = {width: 1024, height: 1366, dsf: 2, isMobile: false, dark: true};

// Tap targets as viewport fractions, per layout.
const P = {
  locCard: [0.5, 0.351], cont: [0.73, 0.599], calendar: [0.808, 0.777],
  library: [0.19, 0.80], qibla: [0.19, 0.938], tasbeeh: [0.5, 0.938], qaza: [0.809, 0.938],
  listen: [0.5, 0.957], counterTap: [215, 500], homeScroll: 1300,
};
const T = {
  locCard: [0.50, 0.202], cont: [0.887, 0.541], calendar: [0.693, 0.486],
  library: [0.889, 0.486], qibla: [0.49, 0.627], tasbeeh: [0.693, 0.627], qaza: [0.889, 0.627],
  listen: [0.50, 0.981], counterTap: [512, 750], homeScroll: 0,
};

// Synthetic DeviceOrientation events: exactly what an Android magnetometer
// emits. The bearing, distance and turn instruction are the app's own maths.
async function driveCompass(page, alpha = 341) {
  await page.evaluate((a) => {
    window.__t && clearInterval(window.__t);
    const fire = () => {
      for (const type of ['deviceorientationabsolute', 'deviceorientation']) {
        const e = new Event(type);
        Object.defineProperties(e, {
          absolute: {value: true}, alpha: {value: a}, beta: {value: 2}, gamma: {value: -1},
          webkitCompassHeading: {value: (360 - a) % 360}, webkitCompassAccuracy: {value: 10},
        });
        window.dispatchEvent(e);
      }
    };
    fire(); window.__t = setInterval(fire, 120);
  }, alpha);
  await page.waitForTimeout(2600);
}

async function run(b, vp, k, p) {
  // Home and calendar, with a resolved location fix.
  {
    const {context, page} = await openApp(b, vp);
    await tapF(page, ...k.locCard, 2500);
    await tapF(page, ...k.cont, 12000);
    await shot(page, `${p}-01-home`);
    await tapF(page, ...k.calendar, 6000);
    await shot(page, `${p}-05-calendar`);
    await context.close();
  }
  // Reading: a different dua from the audio shot, scrolled well into the verses.
  {
    const {context, page} = await openApp(b, {...vp, route: '/zikr/dua-kumayl'});
    await page.waitForTimeout(6000);
    await page.mouse.move(vp.width / 2, vp.height * 0.55);
    await page.mouse.wheel(0, 2800); await page.waitForTimeout(1500);
    await page.mouse.wheel(0, -240); await page.waitForTimeout(2600);
    await shot(page, `${p}-02-reading`);
    await context.close();
  }
  // Audio player, mid-playback, deep in the Arabic.
  {
    const {context, page} = await openApp(b, {...vp, route: '/zikr/ziyarat-e-ameenullah'});
    await page.waitForTimeout(6000);
    await page.mouse.move(vp.width / 2, vp.height * 0.55);
    await page.mouse.wheel(0, 2200); await page.waitForTimeout(1500);
    await page.mouse.wheel(0, -240); await page.waitForTimeout(2600);
    await tapF(page, ...k.listen, 7000);
    await page.waitForTimeout(5000);
    await shot(page, `${p}-03-player`);
    await context.close();
  }
  // Focus mode: the chrome scrolled away, no audio running.
  {
    const {context, page} = await openApp(b, {...vp, route: '/zikr/ziyarat-e-ameenullah'});
    await page.waitForTimeout(6000);
    await page.mouse.move(vp.width / 2, vp.height * 0.55);
    await page.mouse.wheel(0, 2400); await page.waitForTimeout(3200);
    await shot(page, `${p}-09-focus`);
    await context.close();
  }
  // Tabs.
  {
    const {context, page} = await openApp(b, {...vp, route: '/zikr/etiquettes-of-bedtime'});
    await page.waitForTimeout(6500);
    await shot(page, `${p}-10-tabs`);
    await context.close();
  }
  // Qibla, with the compass driven.
  {
    const {context, page} = await openApp(b, vp);
    if (k.homeScroll) { await page.mouse.move(vp.width/2, vp.height*0.65);
      await page.mouse.wheel(0, k.homeScroll); await page.waitForTimeout(2200); }
    await tapF(page, ...k.qibla, 5500);
    await driveCompass(page);
    await shot(page, `${p}-04-qibla`);
    await context.close();
  }
  // Library.
  {
    const {context, page} = await openApp(b, vp);
    if (k.homeScroll) { await page.mouse.move(vp.width/2, vp.height*0.65);
      await page.mouse.wheel(0, k.homeScroll); await page.waitForTimeout(2200); }
    await tapF(page, ...k.library, 6000);
    await shot(page, `${p}-06-library`);
    await context.close();
  }
  // Qaza tracker.
  {
    const {context, page} = await openApp(b, vp);
    if (k.homeScroll) { await page.mouse.move(vp.width/2, vp.height*0.65);
      await page.mouse.wheel(0, k.homeScroll); await page.waitForTimeout(2200); }
    await tapF(page, ...k.qaza, 6000);
    await shot(page, `${p}-07-qaza`);
    await context.close();
  }
  // Tasbeeh, with a count on the dial.
  {
    const {context, page} = await openApp(b, vp);
    if (k.homeScroll) { await page.mouse.move(vp.width/2, vp.height*0.65);
      await page.mouse.wheel(0, k.homeScroll); await page.waitForTimeout(2200); }
    await tapF(page, ...k.tasbeeh, 5000);
    for (let i = 0; i < 33; i++) await page.mouse.click(...k.counterTap);
    await page.waitForTimeout(2500);
    await shot(page, `${p}-08-tasbeeh`);
    await context.close();
  }
}

(async () => {
  const b = await launch();
  await run(b, PHONE, P, 'd');
  await run(b, TABLET, T, 'dt');
  await b.close();
})();
