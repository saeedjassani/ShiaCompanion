# Wear OS app

`android/wear` is the Wear OS counterpart of the watchOS app in
`ios/ShiaCompanion Watch App`. It shows the next prayer and the five daily prayer times
for the location saved in the phone app, plus a tile and a watch face complication.

## Why it is a separate Gradle build

`flutter build apk` runs unqualified `assemble*` tasks, so every module in
`android/settings.gradle` is built on every phone build. A wear module included there
would be assembled each time, and a compile error in it would block phone releases —
for an APK that ships on its own schedule. So `android/wear` has its own
`settings.gradle` and is never included in the Flutter build.

```bash
gradle -p android/wear test              # unit tests
gradle -p android/wear assembleRelease   # android/wear/app/build/outputs/apk/release/
```

The `wear` job in `ci.yml` runs both on every PR.

The watch APK shares the phone's `applicationId` (`com.developer110.shiacompanion`) and
signing key — the data layer only connects apps that match on both, and Play uses the
same pair to offer the watch app on a paired device. It reads `android/key.properties`,
the same file the phone app signs with, and takes its version from `pubspec.yaml`
(`versionCode` offset by 100000, since two APKs in one listing cannot share a version
code).

## How prayer data gets to the watch

A Wear OS app has its own storage on the watch: nothing the phone writes to
`shia_companion_widgets` is visible there. The data layer is the only route, and it is
the same shape as the watchOS `WCSession` bridge:

| watchOS | Wear OS |
| --- | --- |
| `updateApplicationContext` | data item at `/shia_companion/prayer_snapshot` |
| `sendMessage(request: snapshot)` | message to `/shia_companion/request_snapshot` |
| `receivedApplicationContext` replay on launch | `DataClient.getDataItems()` on launch |
| `transferCurrentComplicationUserInfo` | not needed — data items wake the listener service |

1. Dart's `HomeScreenWidgetService` publishes the same `sc_*` keys it already publishes
   for the home screen widgets, over the `shia_companion/home_widgets` channel.
2. `WearSnapshotPublisher` (phone) reads those keys back out of the widget preferences
   and puts them in a data item. Unchanged content is skipped, so the phone does not wake
   the watch for nothing.
3. `PrayerSyncListenerService` (watch) receives the data item — with or without the watch
   app running — and writes it to the watch's own preferences, then refreshes the tile and
   the complication.
4. `MainActivity` (watch) replays whatever has already synced on every resume, so it
   renders instantly, and asks the phone for anything newer.
5. `PhoneWearListenerService` (phone) answers that request, which is what lets the watch
   pull a snapshot without the user opening the phone app.

Play services replicates data items whenever the two devices come back into range, so a
snapshot published while the watch is off still lands.

## Working without the phone

The snapshot carries eight days of prayer times, both as the `sc_prayer_schedule`
timeline and as the `sc_daily_prayer_schedule` day-by-day list. Everything on the watch
derives "next prayer" and "today's prayers" from those with the watch's own clock:

* the app re-derives them on a 30 second tick while it is open,
* the tile's timeline carries one entry per upcoming prayer, each valid until that prayer
  starts,
* the complication counts down with `TimeDifferenceComplicationText`, which the watch face
  ticks itself,
* `PrayerSurfaces` sets an exact alarm at each prayer time to roll the tile and the
  complication over.

So a watch that is out of range for days keeps showing the right prayer.

## Tests

`gradle -p android/wear test` runs both layers, and the `wear` CI job runs it on every PR.

### 1. Logic — `PrayerScheduleTest`, `PrayerDataStoreTest`, `PrayerUiStateTest`, `NextPrayerTileWindowsTest`, `ComplicationFieldsTest`

Plain JVM tests over the parts that decide what the watch shows: decoding the phone's
schedule records and day-by-day JSON, the three sync states, the roll-over from one prayer
to the next, the tile's timeline slicing, and the text each complication slot gets.

These are deliberately free of Android and Compose types — which is why `uiState`,
`tileWindows` and `complicationFields` live in files of their own rather than inside the
composables and services that use them.

### 2. Render — `PrayerScreenRenderTest`, `NextPrayerTileServiceTest`, `NextPrayerComplicationServiceTest`

Robolectric. The Wear counterpart of `test/ui/page_render_test.dart`: the screen is
rendered in each state the phone can leave it in, on small round, large round and square
watches, and anything raised while laying it out fails the test. The tile and the
complication are built from their real services, so a layout the renderer would reject
fails here too. No golden files.

`PrayerScreenRenderTest` renders `PrayerScreen`, not `PrayerApp` — the latter owns the
store, the data layer and a 30 second tick that never completes, and a Compose test clock
left on auto would wait on it forever.

### Not covered

Nothing runs against a real watch. The Playwright suite in `test_visual/` has no Wear
equivalent here: that would mean an instrumented test on a Wear emulator, which is minutes
of CI per run and flakier than everything above it. Pixel-level regressions on the watch,
and anything that only breaks on a real Play services connection — the data layer round
trip most of all — are found by hand.

## Keys

`WearDataKeys` (watch) and `WearSnapshot` (phone) both list the `sc_*` keys, and both
have to match what `HomeScreenWidgetService` publishes from Dart. There is no shared
module to hang them on — the same arrangement the watchOS app uses, for the same reason.
Adding a key means touching all three.
