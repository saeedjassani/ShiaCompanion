# Wear OS app

A watch app for Android watches, the counterpart of the Apple Watch app in
`ios/ShiaCompanion Watch App`. **It is merged but not shipped**: nothing builds,
signs or uploads it except by hand, and the phone app's side of it does nothing
until the watch app exists on a watch. "Shipping it" below lists every step
left.

## What it does

The same three things as the Apple Watch app, plus a tile:

| Surface | What it shows |
| --- | --- |
| App, home | The next prayer large, with how long until it, the times after it in the phone's rolling window, today's hijri date and next event, the tasbeeh counter, and when it last synced |
| App, calendar | Today's hijri date and event, and the next twelve events |
| App, tasbeeh | A counter: tap anywhere or turn the crown/bezel, a ring filling to the target (33, 34, 100, 1000 or none), laps, minus, reset. A tick per count and a stronger buzz at each target |
| Tile | Next prayer and the two after it; the hijri date on the edge button opens the calendar. One timeline entry per prayer, so it moves on with the app closed |
| Complications | Next prayer (short and long text), hijri date (short and long), tasbeeh count (short text, and a ring) |

Prayer names, times, the location, hijri months and event names arrive from
the phone already in the phone's language. The screens' own words are in
`android/wear/app/src/main/res/values*/strings.xml`, in English, Urdu, Persian,
Arabic and Gujarati - keep the five in step when adding one.

## How it is built

`android/wear` is a plain Gradle build of its own (Kotlin, Compose for Wear OS
Material 3, Tiles, Complications), **not a module of the phone app's
`android/` build**. Flutter runs `assembleRelease`/`bundleRelease` across every
project in `android/settings.gradle`, so including it there would build and
sign the watch app on every phone build. Kept apart, `flutter build`, `ci.yml`
and `internal-testing.yml` cannot pick it up.

It shares the phone app's package name (`com.developer110.shiacompanion`,
`.debug` for debug builds on both), version (read from `pubspec.yaml`) and
upload key (`android/key.properties`). The Data Layer only connects apps with
the same package name and signing certificate.

```bash
cd android/wear
./gradlew :app:assembleDebug           # app/build/outputs/apk/debug/
./gradlew :app:testDebugUnitTest       # logic tests
./gradlew :app:recordRoborazziDebug    # screenshots -> app/build/outputs/roborazzi/
```

Library versions are the newest that build with the phone app's toolchain (AGP
8.13, compileSdk 36). Wear Compose 1.7 needs AGP 9.1 and compileSdk 37; move
both builds up together.

### Phone to watch

The phone already writes everything the watch needs: the home-screen widgets'
snapshot (`HomeScreenWidgetService`, saved by `MainActivity`'s
`saveWidgetData`). After every widget refresh `WearSync`
(`android/app/.../shiacompanion/wear/`) puts the same keys the Apple Watch
gets into one Data Layer item, `/shia_companion/snapshot`.

- **Dormant without the watch app.** `WearSync` first asks whether any paired
  watch advertises `shia_companion_wear_app`. Only the watch app does, so until
  it is installed somewhere nothing is written. On a phone without the Wear OS
  companion app the lookup fails and is ignored.
- The watch keeps the last snapshot, so the app, tile and complications all
  work with the phone out of reach. The schedule covers eight days, the
  calendar thirty.
- On opening, the watch reads any snapshot already synced and sends
  `/shia_companion/request_snapshot`; `PhoneWearListenerService` answers by
  re-sending, even with the phone app closed. It also sends one when the watch
  app first appears on a watch.
- The phone advertises `shia_companion_phone_app`, so the watch can say
  "install the phone app" rather than "phone out of reach".

The keys and paths are written out on both sides (`WearSync.kt`,
`WearProtocol.kt`, `WatchSnapshot.kt`); change them together.

## Testing without a watch

- **Screenshots.** The `Wear OS` workflow (`.github/workflows/wear.yml`) runs on
  every PR touching the watch app and uploads a `wear-screenshots` artifact:
  every screen on a small (192dp) and a large (227dp) round watch, and in Urdu
  to check right-to-left. Scrolled captures show the bottom of each list.
- **Emulator.** Android Studio -> Device Manager -> Create device -> Wear OS
  -> "Wear OS Large Round" (API 34 or later). Install with
  `./gradlew :app:installDebug`. To get real data, pair it with a phone
  emulator that has Google Play and the phone app's debug build: Device
  Manager's "Pair Wearable" on the phone emulator, then the Wear OS app on the
  phone. Without a phone the watch app shows "Waiting for phone", which is
  itself worth checking.
- **A real watch**, before shipping: anyone with a Wear OS 3+ watch (Pixel
  Watch, Galaxy Watch 4 or later) in the Play internal-testing group, once the
  Wear track exists (below).

## Still to check on a device

Things a screenshot cannot show:

- [ ] Crown/bezel counting speed: `ROTARY_PIXELS_PER_COUNT` in
      `CounterScreen.kt` is a first guess. One click of a Galaxy bezel should
      be one count.
- [ ] Haptics feel right (tick per count, stronger at each target).
- [ ] Sync on first install, after a location change on the phone, and after
      the phone app's language changes.
- [ ] The tile and the complications roll over at a prayer time with the app
      closed, and update after a sync.
- [ ] Tapping each complication and the tile's edge button opens the right
      screen, and swiping back reaches home.
- [ ] Battery: the app keeps no service running; the tile and complications
      use timelines. Check nothing wakes more than expected.

## Shipping it

1. **Device checks above.**
2. **Play Console, once:** Setup -> Advanced settings -> Form factors -> add
   **Wear OS**. That creates Wear OS tracks next to the phone's; a Wear OS
   build only ever goes to those.
3. **Version codes.** Play keys version codes by package, across form
   factors, so the watch build can never reuse one the phone used. The watch
   build adds `100000` to `pubspec.yaml`'s build number
   (`wearVersionCodeOffset` in `app/build.gradle.kts`). `internal-testing.yml`
   picks the phone's next code as "the highest on any track, plus one", which
   would then jump to the watch's 100000-range: before the first watch
   upload, make it read only the phone tracks, or pick a different scheme.
4. **An upload workflow.** Mirror the Android job of `internal-testing.yml`
   for `cd android/wear && ./gradlew :app:bundleRelease`, uploading to the Wear
   OS internal-testing track (`--track wear:internal`). Same key and
   `key.properties` as the phone job.
5. **Store listing:** Wear OS screenshots (from the artifact, or the
   emulator), and the Wear OS quality checklist (dark, round-friendly, works
   offline, tile and complication previews). The tile's picker preview
   (`res/drawable/tile_preview.xml`) is still the Maghrib glyph; replace it
   with a screenshot of the tile from a device.
6. Promote from the Wear OS internal track when ready.

The phone side needs no release step: it ships dormant in every phone build
from this change on, and starts syncing the moment a watch has the app.
