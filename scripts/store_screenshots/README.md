# Store screenshots

Captures every App Store and Play screenshot from the Flutter **web** build and
composes them into slides on the brand background (`compose.js`): two phones
fanned out (`fan`, e.g. light and dark), three (`fan3`), or one turned in 3D
with feature callouts (`tilt`). App Store slides get an iPhone with a Dynamic
Island and iOS status bar; Play slides a plain punch-hole phone with an Android
one. It also renders Play's feature graphic and the app preview video.

There is no iOS simulator or Android emulator in the loop. The web build runs
in Chromium, which is why this works on Linux and in CI, and it is also the
main caveat — see [Fidelity](#fidelity).

## Running it

```bash
cd scripts/store_screenshots
npm install
npx playwright install chromium   # skip if CHROME_PATH is set
npm run setup                     # vendors fonts, the Firebase SDK and a silent track

# from the repo root - the flag matters, see below
flutter build web --release --no-web-resources-cdn

npm run all                       # serve + capture + frame
npm run video                     # app preview video (needs the server: node ../../test_visual/serve.js)
```

Output lands in `out/store/<store>/<slot>/`, already at each slot's exact
required pixel size:

| Directory | Size | Shots |
| --- | --- | --- |
| `play/phone` | 1080x1920 | 8 |
| `play/tablet-7` | 1200x1920 | 6 |
| `play/tablet-10` | 1600x2560 | 6 |
| `play/feature-graphic.png` | 1024x500 | 1 |
| `appstore/iphone-6.9` | 1320x2868 | 9 |
| `appstore/iphone-6.5` | 1242x2688 | 9 |
| `appstore/ipad-13` | 2064x2752 | 6 |

Play caps at eight phone screenshots; 09 exists only for the App Store, which
takes ten (the tenth slot is free for widgets or the Watch). Tablets have no
Home slide: on the web, Home carries a "Get the app" card with store badges.
`npm run capture` and `npm run frame` run the two halves separately when
iterating on captions or framing without re-driving the app. Both take an
optional filter: `node capture.js p stats-l,qaza-d` recaptures two phone
shots, `node build.js iphone-6.9 02,04` re-renders two slides.

**Demo data.** `demo_data.js` seeds a few weeks of history into the app's own
storage before it starts (`seed: true` in `openApp`): a reading streak for My
Stats, a Khatm partway into Aal-e-Imran, and qaza being made up. Home then
shows a Continue card, which moves its grid down - hence `allFeaturesSeeded`.

**Languages.** The app follows the browser language until one is picked, so
`openApp`'s `locale` is all a translated capture needs. Gujarati needs Noto
Sans Gujarati, served the same way as the Arabic fallback.

## App preview video

`video.js` records each scene of the real app with Chrome's screencast, adds a
caption to each, cross-fades them, adds a brand end card and a silent stereo
AAC track (the App Store wants one), and writes
`out/video/app-preview-886x1920.mp4`: H.264, 30 fps, at most 30 seconds - the
App Store's portrait preview size for 6.5" and 6.9" iPhones. For Play, upload
the same file to YouTube and paste its link as the promo video.

The headless browser paints at about 12 fps, so scenes are acted out three
times slower than real time and sped up in the cut; scrolling comes out
smooth. `node video.js cut` re-cuts without re-recording, and
`node video.js stats` re-records one scene.

Env overrides: `CHROME_PATH`, `WEB_BUILD_DIR`, `PORT`, `RAW_DIR`, `OUT_DIR`,
`TZ_OVERRIDE`. Location and timezone are pinned in `config.js` so prayer times
resolve to stable values instead of wherever CI happens to think it is.

## Why the build needs `--no-web-resources-cdn`

A default release build fetches CanvasKit from `gstatic.com`. Where that host is
unreachable the app paints nothing at all — no error, just a blank canvas — and
the flag makes the build use the copy already in `build/web/canvaskit`.

Three more CDN dependencies are handled by request interception in `lib.js`,
because they cannot be fixed with a build flag:

- **The Firebase JS SDK** (`gstatic.com/firebasejs/...`). `Firebase.initializeApp`
  awaits a dynamic import of it, so when the fetch fails `main()` never reaches
  `runApp` and the engine bootstraps without ever rendering a frame.
  `setup.js` bundles the same version from npm and `lib.js` serves it.
- **Roboto** (`fonts.gstatic.com`). Without it the UI paints icons and layout
  with *no text whatsoever*, which is easy to mistake for a rendering bug.
- **A Noto Arabic fallback**, requested separately for glyphs Roboto lacks.
  Serving Roboto for that request is what turns the calendar's Arabic-Indic
  day numbers into tofu boxes.

`recitation.wav` covers a fourth: recitation audio streams from `mp3.duas.org`,
and where that is blocked the player shows an error rather than its loaded
state. The silent track is 11:12 long so the duration and scrubber look real.
The player state on screen is genuine; only the audio content is a placeholder.

## Notes for whoever changes this next

**Everything inside the app is a coordinate tap.** Flutter paints to a canvas,
so no widget is addressable as DOM — `capture.js` taps viewport *fractions*,
which survive a change of device size where pixel offsets would not. Change a
layout and the fractions in `P` and `T` need rechecking; a tap that misses
usually shows up as a screenshot of the wrong screen rather than an error.

**Release builds hide exceptions behind a grey box.** Flutter's release
`ErrorWidget` is a plain grey rectangle, so a page that throws during build
looks like an empty screen. When a capture comes back grey, rebuild with
`--profile` and read the console: that is how the
`getFirestore is not a function` bug in the vendored bundle was found.

**Reaching a zikr.** Lists work, but deep links (`/<slug>`, e.g. `/dua-kumayl`,
and `/quran/36`) are more robust and skip several taps. Slugs are in
`assets/zikr.json`. The static server answers `/zikr/<slug>` with a 404 page.

**The Qibla screen needs a compass.** Desktop Chromium has no magnetometer, so
the app correctly falls back to a north-up dial with a "No compass on this
device" note. `capture.js` dispatches synthetic `deviceorientation` events —
the same ones an Android magnetometer produces — and the app's own maths does
the rest: bearing, distance and the turn instruction are all real.

**Status bar colours are sampled, not hardcoded** (`bar-colours.js`, a small
dependency-free PNG reader). The strip takes the app bar's own colour and the
frame's screen background takes the capture's bottom row, which is what lets
one framing pass serve light and dark captures alike.

## Fidelity

These are captures of the real app, but of its **web** build. Layout, palette,
fonts and content are the shipped thing; CanvasKit on desktop rasterises text a
little differently from iOS. That is fine for Play. For the App Store the
output is complete and uploadable, but if you want strict device-native text
rendering, recapture the same screens in the iOS simulator — the shot list and
ordering are designed to drop straight in.

Not included: **Qibla is captured** (see above), but nothing that needs
notifications, and no Apple Watch screens — the watch app is native SwiftUI and
needs a watchOS simulator.
