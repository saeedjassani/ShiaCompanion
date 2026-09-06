# iOS "Missing dSYM" fix

## Root cause (confirmed)

Crashlytics reported a missing dSYM for *every* iOS release for 5+ months
(builds 57 through 104, April–Sept 2026) — not an occasional miss. That
ruled out flaky causes and pointed at the CI pipeline itself.

Confirmed locally with `xcodebuild -showBuildSettings` (Runner scheme,
Release config):

```
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym   # dSYMs ARE generated, not the problem
ENABLE_USER_SCRIPT_SANDBOXING = NO           # script sandboxing NOT the cause either
```

So the dSYM exists on disk after every archive. The problem is the upload.
The Crashlytics-installed build phase runs `${PODS_ROOT}/FirebaseCrashlytics/run`,
whose last line is:

```sh
eval $COMMAND_PATH$UPLOAD_ARGUMENTS > /dev/null 2>&1 &
```

The `&` forks the actual `upload-symbols` call into the background with its
output discarded, and the *build phase itself returns immediately* without
waiting for it. On a developer Mac that's invisible because the process
outlives the build. On CI (Codemagic), `xcodebuild archive` returns and the
build container is torn down within seconds — killing the orphaned uploader
mid-flight. Nothing gets uploaded and nothing gets logged, which is exactly
"Missing dSYM" arriving for every single release.

## Fix

`ios/Runner.xcodeproj/project.pbxproj` — the "Upload Crashlytics dSYMs"
run-script phase (was an unnamed `ShellScript` phase) no longer calls
`FirebaseCrashlytics/run`. It calls `upload-symbols --build-phase` directly,
in the foreground, so the phase — and therefore the CI job — actually waits
for the upload to finish before the container goes away. It also:
- runs `--validate` first (fast, catches misconfiguration without adding to
  build time on every build),
- skips Debug builds (no dSYM to send there),
- marked `alwaysOutOfDate = 1` so Xcode's build system can't decide to skip
  it on an incremental/cached build (it previously declared no inputs or
  outputs, which is exactly the condition that lets the new build system
  treat a script phase as already-satisfied and skip it).

`ios/scripts/upload_dsyms_to_crashlytics.sh` — a standalone fallback that
finds the dSYMs in a built `.xcarchive` and uploads them synchronously,
logging the UUID of each one uploaded (diff that against the UUID Crashlytics
names in its alert email). Use it as a post-build/post-archive step on
Codemagic if the in-Xcode phase above ever gets skipped for some other CI
reason, e.g.:

```yaml
- name: Upload dSYMs to Crashlytics
  script: sh "$CM_BUILD_DIR/ios/scripts/upload_dsyms_to_crashlytics.sh"
```

## Follow-up: this phase must not run on a plain (non-archive) build

Confirmed against real CI: `ACTION` is what distinguishes the two. `xcodebuild
archive` runs script phases with `ACTION=install`; a plain `xcodebuild build`
(what `flutter build ios` invokes, and what GitHub Actions' CI "iOS build" job
runs as a build-only sanity check, with no archive after it) runs them with
`ACTION=build`. The build phase now exits immediately unless `ACTION=install`.

Without this guard, GitHub Actions' `flutter build ios --release --no-codesign`
step hit the build phase too (Release config, not Debug) and tried to run
`upload-symbols --build-phase` in the foreground against this repo's live
GoogleService-Info.plist - a real network call to Firebase from a runner that
never needed one. `upload-symbols` has no timeout of its own, and that runner
apparently has no usable path to the Crashlytics upload endpoint, so the step
hung indefinitely (observed: 40+ minutes with zero output before being
cancelled, vs. ~15-25 minutes for the same step end-to-end before this PR).
Every other job in the same CI run (Analyze/test, Android, Web) passed in
minutes, which is what pointed at this phase specifically rather than
something wrong with the build itself.

## Nothing to change on Codemagic itself

This was purely an in-repo build-phase bug, not a Codemagic setting. No
Codemagic UI change is required for the primary fix. The standalone script
above is an optional extra safety net you can wire in if you want a second,
independent upload path.

## Verification performed

- `xcodebuild -showBuildSettings` confirmed dSYM generation and script
  sandboxing were both already fine (see above) — narrowing this to the
  upload step.
- `bash -n ios/scripts/upload_dsyms_to_crashlytics.sh` — syntax OK.
- `ios/Pods/FirebaseCrashlytics/upload-symbols --help` — confirms
  `--build-phase`, `--validate`, `--google-service-plist`, `--platform` are
  real, current flags for the pod version vendored in this repo (matches
  what both the build phase and the standalone script call).
- Not verified: an actual end-to-end archive + real upload to Firebase (that
  needs network credentials and a real Firebase project context this
  environment doesn't have). The next TestFlight build is the real test —
  watch for whether the "Missing dSYM" email stops arriving for the version
  after this fix ships.
