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
finds the dSYMs in a built `.xcarchive` and uploads them synchronously with
retries (exponential backoff, 4 attempts by default), logging the UUID of
each one uploaded (diff that against the UUID Crashlytics names in its alert
email). See "Codemagic change needed" below for wiring it in.

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

## Nothing to change on Codemagic itself for the timeout fix

The timeout guard and the `ACTION=install` guard were both purely in-repo
build-phase bugs, not Codemagic settings — no Codemagic UI change is
required to stop the CI job from hanging. But stopping the hang isn't the
same as guaranteeing the dSYM actually reaches Crashlytics; see "Codemagic
change needed" below for that.

## Follow-up: the same missing timeout then hung a real Codemagic archive

The `ACTION=install` guard above was correct but incomplete: it only skips
the *non-archive* case. Codemagic's `flutter build ipa` does run a real
archive (`xcodebuild archive`, `ACTION=install`), so the guard deliberately
lets this phase through there — and it hit the exact same underlying bug:
`upload-symbols` has no timeout of its own. On Codemagic the build log
showed `Running Xcode build...` and then nothing else until the whole CI
job was cancelled for exceeding its time limit, with no indication of which
build phase was actually stuck.

Fix: both `upload-symbols` invocations (`--build-phase --validate` and
`--build-phase`) are now wrapped in a small `run_with_timeout` helper (POSIX
`sh`, no dependency on GNU `timeout`/`gtimeout` which isn't guaranteed to be
on a macOS runner) that backgrounds the call and force-kills it after
`UPLOAD_SYMBOLS_TIMEOUT` (180s) if it hasn't returned. A kill shows up as
exit status 137 (128 + SIGKILL); the validate step treats that specifically
as "network problem, not a config problem" and warns + skips the upload
rather than failing the whole archive, while a genuine (non-timeout)
validate failure still fails the build as before. The real upload call was
already non-fatal on failure and stays that way — a timeout there now just
falls into the same "warning, use the fallback script" branch instead of
hanging forever.

The timeout guard only bounds *how long the archive waits*. It does not
guarantee the upload actually succeeds — if `upload-symbols` keeps failing
or timing out against Crashlytics from Codemagic, the archive now finishes
green but the dSYM is still missing, same as before this whole fix existed,
just without a stuck build. That's what the fallback script + Codemagic
step below is for: a second, independent attempt with retries, after the
archive has already produced its dSYMs on disk regardless of whether the
in-archive upload succeeded.

## Codemagic change needed (not made here)

`ios/scripts/upload_dsyms_to_crashlytics.sh` isn't wired into Codemagic's
build automatically. This project configures its workflow through
Codemagic's Workflow Editor UI, not a `codemagic.yaml` in the repo (see the
badge in `README.md` for the app itself). In the Workflow Editor, on the iOS
workflow, add a **Script** step directly **after** the existing
`flutter build ipa` step:

- **Name**: `Upload dSYMs to Crashlytics`
- **Script**:
  ```sh
  sh "$CM_BUILD_DIR/ios/scripts/upload_dsyms_to_crashlytics.sh"
  ```

It only needs the archive to already exist on disk - it doesn't depend on
signing or publishing having run first, so it's safe to place right after
the build step regardless of what comes later in the workflow (e.g. before
or after the "Publish" stage that ships the IPA to App Store Connect).

Until that step is added, a Codemagic release build will still produce a
valid, signed IPA even if the in-archive upload times out or fails - but
crash reports for that build will keep showing as "Missing dSYM" in
Crashlytics until someone runs this script (or the in-archive attempt
happens to succeed) for that build's dSYMs.

## Verification performed

- `xcodebuild -showBuildSettings` confirmed dSYM generation and script
  sandboxing were both already fine (see above) — narrowing this to the
  upload step.
- `bash -n ios/scripts/upload_dsyms_to_crashlytics.sh` — syntax OK.
- `ios/Pods/FirebaseCrashlytics/upload-symbols --help` — confirms
  `--build-phase`, `--validate`, `--google-service-plist`, `--platform` are
  real, current flags for the pod version vendored in this repo (matches
  what both the build phase and the standalone script call).
- `run_with_timeout` isolated in a standalone test: a fast successful command
  returns 0, a fast failing command preserves its real exit code, and a
  hanging command gets killed at the timeout boundary with status 137 - all
  as expected.
- Not verified: an actual end-to-end archive + real upload to Firebase (that
  needs network credentials and a real Firebase project context this
  environment doesn't have). The next TestFlight build is the real test —
  watch for whether the "Missing dSYM" email stops arriving for the version
  after this fix ships, and whether the Codemagic log shows the in-archive
  phase succeeding, warning, or timing out.
- The "Codemagic change needed" step above has not been added to the
  Workflow Editor by this fix - that's a manual step in Codemagic's
  dashboard, outside this repo. Until it's added, the retry script exists
  in-repo but isn't running on Codemagic yet.
