# Cross-Platform Smoke Crawler Tests Guide

This document describes how automated smoke crawling is set up for
**iOS and Android** in ShiaCompanion using Flutter's built-in `integration_test`
framework. One test file drives both platforms — there is no separate
Android-specific test to maintain.

---

## 1. Why a Smoke Crawler?

Neither platform has a zero-configuration automated crawler that plugs
straight into this repo's CI: Apple provides nothing equivalent, and
Firebase Test Lab's Robo test (still used for the Google Play Pre-launch
report — see [`docs/ROBO_TESTS.md`](ROBO_TESTS.md)) is Android-only and
scripted separately from CI.

To get the same kind of automated exploration and crash detection on
**both** platforms from one CI-triggerable test, we use an **Automated
Smoke Crawler** (`integration_test/smoke_crawler_test.dart`), driven through
Flutter's own widget tree rather than either platform's native accessibility
layer.

### What it catches
- **Startup crashes & unhandled exceptions** on iOS and Android.
- **Broken native platform channels** (e.g. SQLite, audio background player,
  compass, keychain/credentials).
- **Layout & rendering exceptions** during real transitions and animations.
- **Search bar and navigation regressions**.

### What it does not replace
This is a scripted crawl of a fixed list of home-screen sections — it only
ever visits what `sectionsToCrawl` in the test names, verbatim. It does not
autonomously explore screens the way Firebase Test Lab's Robo test does on
Android; that value still comes from the Play Console Pre-launch report
described in [`docs/ROBO_TESTS.md`](ROBO_TESTS.md).

---

## 2. How the Smoke Crawler Works

1. **Launches the App**: Initializes `IntegrationTestWidgetsFlutterBinding`
   with live frame execution and runs the full app entry point (`app.main()`).
2. **Handles Initial Popups**: Automatically detects and dismisses the
   first-run Azan opt-in dialog ("Not now").
3. **Explores every home-grid section**:
   - The crawl list is `visibleHomeMenuItems.map((item) => item.label)` —
     read straight from [`lib/navigation/home_menu.dart`](../lib/navigation/home_menu.dart),
     the same source the home grid itself renders from, rather than a
     separately maintained copy. This mirrors the precedent already set by
     `test/ui/page_render_test.dart` (see [`docs/CI.md`](CI.md)): a new menu
     entry is covered by the crawler the day it is added, with nothing to
     update here. It currently covers all ~17 entries — Favorites, Today's
     Recitations, Taqeebat e Namaz, Namaz, Duas, Ziyarats, Surahs, Aamaal,
     Calendar & Prayer Times, Library, Munajaat, Baaqeyaat As Saalehaat,
     Qibla Finder, Tasbeeh Counter, Qaza Tracker, Rakaat Counter (mobile
     only), and Prayer Times in Flight.
   - Scrolls further down the grid, a bit at a time, until each label comes
     into view (bounded to a few attempts, so a section that is genuinely
     missing — a renamed label, say — is skipped and logged rather than
     looping).
   - Tests page rendering and gentle scrolling.
   - Verifies that `tester.takeException()` is `null` on each step.
   - Navigates back to the home screen.
4. **Tests Search**: Opens search, types a query, and verifies result
   rendering without crash.
5. **Bounded Frame Drainage**: Uses `settleBounded()` instead of unbounded
   `pumpAndSettle()` to avoid timeouts from repeating background timers
   (such as prayer countdowns or audio players).

None of the crawled screens show a permission dialog just from being opened
— confirmed by reading each one rather than assumed, since a native OS
dialog sits outside the Flutter widget tree and would stall every step after
it with no exception for `tester.takeException()` to catch. Qibla Finder in
particular deliberately defers its location/compass permission prompt until
the user taps something in-screen (see the comment on `_start()` in
[`qibla_finder.dart`](../lib/pages/qibla_finder.dart)); the crawler never
taps that, so it never triggers. If a future screen requests a permission
eagerly in `initState`, the crawler will hang on it — that is a real gap,
worth catching in review rather than pre-solving here for screens that don't
need it yet.

---

## 3. Running Locally on iOS Simulator

We provide a runner script at
[`scripts/run_ios_smoke_test.sh`](../scripts/run_ios_smoke_test.sh).

### Run on Default / Booted Simulator:
```bash
./scripts/run_ios_smoke_test.sh
```

### Run on a Specific Simulator:
```bash
./scripts/run_ios_smoke_test.sh -d "iPhone 16"
```

### Inspect the Command (Dry-run):
```bash
./scripts/run_ios_smoke_test.sh --dry-run
```

---

## 4. Running Locally on Android Emulator / Device

No wrapper script is needed here — start an emulator (or connect a device),
then run the same test target directly:

```bash
flutter emulators --launch <emulator_id>   # or connect a physical device
flutter devices                            # confirm the device id, e.g. emulator-5554
flutter test integration_test/smoke_crawler_test.dart -d <device_id>
```

No `--dart-define` flags are required — unlike Firebase Test Lab's Robo test,
`integration_test` drives the Flutter widget tree directly rather than going
through the platform accessibility layer, so there is no semantics tree to
force on separately.

---

## 5. Running via GitHub Actions CI

A single workflow is available at
[`.github/workflows/smoke-test.yml`](../.github/workflows/smoke-test.yml),
with a gate job followed by one job per platform:

- **`gate`** — `ubuntu-latest`, diffs the `version:` line in `pubspec.yaml`
  against the previous commit (`git show ${{ github.event.before }}:pubspec.yaml`)
  and only lets the platform jobs run if it actually changed. This mirrors
  `web-release.yml`'s release gate, so a `pubspec.yaml` edit that isn't a
  version bump (adding a dependency, say) doesn't boot two emulators for
  nothing.
- **`ios-smoke-test`** — `macos-latest`, boots the requested iOS Simulator.
- **`android-smoke-test`** — `ubuntu-latest`, boots an Android emulator via
  [`reactivecircus/android-emulator-runner`](https://github.com/reactivecircus/android-emulator-runner)
  (KVM is enabled first, since GitHub-hosted Ubuntu runners need it explicitly
  for the emulator to run at usable speed).

### How to Trigger

**Automatically:** any push to `master` that changes the `version:` line in
`pubspec.yaml` — i.e. the same `node scripts/bump_version.js` step that cuts
a web release (see [`docs/CI.md`](CI.md)) also kicks off the smoke crawler on
both platforms.

**Manually:**
1. In GitHub, go to **Actions**.
2. Select **Cross-Platform Smoke Crawler Test** in the left sidebar.
3. Click **Run workflow** (optionally override the iOS simulator device name
   and/or the Android API level).
4. View each job's run summary and test output directly in the Actions tab.
