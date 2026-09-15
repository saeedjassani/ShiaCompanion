# Android Robo Test (Google Play Pre-Launch Report)

This document describes ShiaCompanion's use of **Robo test**, Google's
autonomous Android UI crawler, via the **Google Play Console Pre-launch
Report**. There is no CI-triggered Robo test in this repo — see
[`docs/SMOKE_TESTS.md`](SMOKE_TESTS.md) for the CI-triggerable,
cross-platform crawler that covers both Android and iOS instead. The two are
complementary: Robo test's autonomous exploration is real device-farm
coverage that costs nothing to keep running (it fires on every upload,
without needing any of this repo's CI), while the smoke crawler is a fixed,
scripted set of assertions you actually control the extent of.

---

## 1. What is a Robo Test?

A **Robo test** is an automated testing service that explores your Android
application without requiring handwritten test cases. It analyzes the UI
hierarchy and simulates user interactions (taps, swipes, text typing, back
navigation) systematically.

### What it catches
- **Startup crashes and native crashes** across different Android OS versions and device form factors.
- **Application Not Responding (ANR)** freezes.
- **Layout and rendering glitches** on different screen sizes and densities.
- **Memory leaks and resource consumption** spikes.

---

## 2. Flutter & Robo Tests: Semantics

Flutter draws UI on a canvas rather than using native Android `View` widgets.
Robo relies on the Android `AccessibilityNodeInfo` tree to discover and
interact with UI elements. On real devices in Google Play's Pre-launch
report, Google's accessibility crawler automatically triggers Flutter's
`AccessibilityBridge` on whatever release build you upload — no build-time
flag or app-code change is needed for this to work.

---

## 3. Robo Script (`android/robo_script.json`)

To prevent the crawler from getting stuck on modal dialogs (like the
one-time Azan opt-in dialog or Android runtime permissions), we provide a
guided **Robo Script**:

- **Dismisses initial prompts**: Clicks "Not now" or "Enable azan", and handles system permission prompts ("While using the app", "Allow").
- **Explores core sections**: Sequentially visits Duas, Ziyarats, Surahs, Calendar & Prayer Times, and Preferences — these must match the home-screen labels in [`lib/navigation/home_menu.dart`](../lib/navigation/home_menu.dart) exactly, or the click step silently no-ops (`canFail: true`) instead of failing loudly.
- **`canFail: true`**: Every action is marked `canFail: true`, ensuring that if a screen is already passed or not visible, Robo doesn't abort the test; instead, the autonomous crawler takes over and continues testing.

---

## 4. Configuring Google Play Console Pre-Launch Report

Google Play automatically runs a Robo test whenever you upload an App Bundle
(`.aab`) or APK to an internal or closed testing track.

### Adding the Robo Script in Play Console:
1. Open [Google Play Console](https://play.google.com/console).
2. Navigate to **Test and release** > **Testing** > **Pre-launch report** > **Settings**.
3. Under **Robo scripts**, click **Add Robo script**.
4. Upload `android/robo_script.json`.
5. Save changes.

Subsequent app releases will now follow the guided script before exploring
autonomously.
