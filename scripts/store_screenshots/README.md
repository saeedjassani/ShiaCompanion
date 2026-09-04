# Store screenshots

Captures every App Store and Play screenshot from the Flutter **web** build and
frames them: brand background, caption, black titanium device mockup with a
Dynamic Island and an iOS status bar.

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
```

Output lands in `out/store/<store>/<slot>/`, already at each slot's exact
required pixel size:

| Directory | Size | Shots |
| --- | --- | --- |
| `play/phone` | 1080x1920 | 8 |
| `play/tablet-7` | 1200x1920 | 8 |
| `play/tablet-10` | 1600x2560 | 8 |
| `appstore/iphone-6.9` | 1320x2868 | 10 |
| `appstore/iphone-6.5` | 1242x2688 | 10 |
| `appstore/ipad-13` | 2064x2752 | 10 |

Play caps at eight screenshots; 09 and 10 exist only for the App Store, which
takes ten. `npm run capture` and `npm run frame` run the two halves separately
when iterating on captions or framing without re-driving the app.

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

**Reaching a zikr.** Lists work, but `/zikr/<slug>` deep links are more robust
and skip several taps. Slugs are in `assets/zikr.json`.

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
