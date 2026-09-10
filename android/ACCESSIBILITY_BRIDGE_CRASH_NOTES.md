# New crash in 3.4.1: `NoClassDefFoundError: Lio/flutter/view/a`

## The crash

```
Fatal Exception: java.lang.NoClassDefFoundError: Failed resolution of: Lio/flutter/view/a;
       at io.flutter.view.AccessibilityBridge.<init>(SourceFile:14)
       at io.flutter.view.AccessibilityBridge.<init>(SourceFile:1)
       at io.flutter.embedding.android.FlutterView.attachToFlutterEngine(:231)
       at io.flutter.embedding.android.FlutterActivityAndFragmentDelegate.onCreateView(:130)
       ...
Caused by java.lang.ClassNotFoundException: io.flutter.view.a
```

`io.flutter.view.a` is an R8-obfuscated class name (this app turned
`minifyEnabled`/`shrinkResources` on in commit 32c21f5, shortly before the
3.4.1 build), not a class this app or its plugins define - `AccessibilityBridge`
itself is Flutter engine code. So this fires on the very first frame
(`FlutterActivity.onCreate` -> `attachToFlutterEngine`), before any Dart code
or plugin runs.

## Root cause: upstream Flutter engine bug, not this app's ProGuard rules

This matches [flutter/flutter#192231](https://github.com/flutter/flutter/issues/192231):
`AccessibilityBridge` added a high-contrast observer lambda that implements
`UiModeManager.ContrastChangeListener`, an Android 14 (API 34) interface. The
lambda is properly guarded by an SDK_INT check, but ART's class verifier
eagerly resolves type joins while *loading* `AccessibilityBridge` - so on
pre-34 devices it tries to resolve the API-34 interface and throws
`ClassNotFoundException` before the guard is ever reached. R8 renames the
lambda's synthetic class along with everything else, which is why it shows up
as `io.flutter.view.a` here instead of its real name.

Per that issue:
- **Affected**: Flutter 3.47.0, 3.47.1, 3.47.2, 3.48.0-0.1.pre, 3.48.0-0.2.pre,
  3.48.0-0.3.pre, and `master`.
- **Not affected**: 3.44.9 and earlier (predates the offending code).
- The reporter tried app-side workarounds - additional R8 keep rules,
  disabling R8 full mode - and **none of them helped**, because the failure
  happens during class verification, before any app or ProGuard-controlled
  behavior runs. Downgrading the Flutter SDK was the only confirmed fix.
- A fix (isolating the API-34 type behind an `@RequiresApi(34)` holder class,
  the same pattern already used for `Api31Impl` in the same file) is up as
  [flutter/flutter#192502](https://github.com/flutter/flutter/pull/192502).

## Why this only showed up now

This repo's own code didn't introduce the bug and turning on R8 in 32c21f5
didn't cause it either - it only obscured the class name in the stack trace
(`AccessibilityBridge`'s own frames are still legible because the app's
`proguard-rules.pro` keeps `io.flutter.view.**`; the anonymous lambda inside
it is a different, unnamed class that keep rule can't give a meaningful name
back to).

What actually changed is the Flutter SDK version used for the release build.
GitHub Actions CI in this repo pins `FLUTTER_VERSION: '3.44.8'`
(`.github/workflows/ci.yml`), which predates the bug entirely. The Android
*release* build, however, runs on Codemagic, configured through Codemagic's
Workflow Editor UI rather than a `codemagic.yaml` in this repo (see
`android/scripts/ANDROID_CRASHLYTICS_MAPPING_UPLOAD_FIX_NOTES.md`). If that
workflow tracks the `stable` channel instead of pinning an explicit version,
it would have picked up 3.47.x/3.48.0-pre - squarely in the affected range -
for the 3.4.1 build, while local/CI builds on 3.44.8 never see it.

## What to do

There is no code change in this repository that fixes this - it needs to be
handled by which Flutter SDK version builds the release artifact:

1. In Codemagic's Workflow Editor, check what Flutter version the Android
   workflow actually resolved to for the 3.4.1 build. If it's tracking
   `stable` (or any version in the affected list above), pin it explicitly
   to a safe version instead - e.g. `3.44.8`/`3.44.9`, matching what
   `.github/workflows/ci.yml` already pins.
2. Once [flutter/flutter#192502](https://github.com/flutter/flutter/pull/192502)
   lands in a stable release, that release (or later) is safe to move back
   to.
3. Until then, avoid letting the Android release workflow float on `stable`
   unpinned - the same way `FLUTTER_VERSION` is already pinned in the GitHub
   Actions workflows, for exactly this reason (see the comment at the top of
   `.github/workflows/ci.yml`).
