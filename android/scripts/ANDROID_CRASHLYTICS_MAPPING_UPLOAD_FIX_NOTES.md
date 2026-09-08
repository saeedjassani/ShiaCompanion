# Android Crashlytics mapping upload failing the release build

## The failure

Codemagic Android release build failed with:

```
FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:uploadCrashlyticsMappingFileRelease'.
> java.io.IOException: Unknown error while sending file, check network
  [/Users/builder/clone/build/app/crashlytics/release/.crashlytics-mappings-tmp/88b64df54366444cbe55f458fd245b35.gz;
  response: 503 HTTP/1.1 503 Service Unavailable]
```

## Root cause

Commit 32c21f5 ("Turn R8 and resource shrinking on for the Android release
build") turned `minifyEnabled`/`shrinkResources` on and set
`firebaseCrashlytics { mappingFileUploadEnabled true }` so release crash
reports stay symbolicated. That flag wires
`uploadCrashlyticsMappingFileRelease` as a dependency of
`assembleRelease`/`bundleRelease` - before that commit `minifyEnabled` was
`false`, so there was no real mapping file and this task had nothing
meaningful to upload.

So the app-size commit is why this task now does a real network upload on
every release build - but the 503 itself is Crashlytics' ingest endpoint
(or the Codemagic macOS builder's path to it, per the `/Users/builder/...`
path in the log), not a bug in the build config: GitHub Actions' CI runs
the identical `flutter build apk --release` (same `google-services.json`,
same Gradle config) and this exact task has succeeded repeatedly there
since 32c21f5 landed. A one-off 503 from a third-party upload endpoint is
plausible on either CI, and simply retrying the Codemagic build would
likely have gone green.

## Fix

Rather than rely on remembering to retry a failed Codemagic build by hand,
decoupled the mapping upload from the task graph that produces the
APK/AAB:

- `android/app/build.gradle`: `mappingFileUploadEnabled` is now `false`.
  This only stops AGP from auto-wiring `uploadCrashlyticsMappingFileRelease`
  into `assembleRelease`/`bundleRelease` - the task itself is still
  registered and runnable on its own.
- `android/scripts/upload_crashlytics_mapping_with_retry.sh`: runs
  `./gradlew uploadCrashlyticsMappingFileRelease` after the app has already
  built, retrying with backoff (4 attempts, 10s/20s/40s) before failing.

This means an occasional 503 no longer fails the build that produces the
release artifact; it only delays (and, on the flaky-only case, eventually
resolves) the separate mapping upload.

## Codemagic change still needed (not made here)

This script isn't wired into Codemagic's build automatically - Codemagic's
build steps live in its own dashboard config, not in this repo (there's no
`codemagic.yaml` here; see the badge in `README.md` for the app itself).
Add a step **after** the existing Android build step:

```yaml
- name: Upload Crashlytics mapping file
  script: sh "$CM_BUILD_DIR/android/scripts/upload_crashlytics_mapping_with_retry.sh"
```

Until that step is added, release builds on Codemagic will produce a valid
APK/AAB but won't upload the mapping file at all, so crash reports for
those releases will show obfuscated frames.

## Verification performed

- `bash -n android/scripts/upload_crashlytics_mapping_with_retry.sh` -
  syntax OK.
- Confirmed via GitHub Actions run history that
  `uploadCrashlyticsMappingFileRelease` has succeeded on every CI run since
  32c21f5, using the same `google-services.json` and Gradle config as
  Codemagic - supporting a transient/CI-environment cause over a config bug.
- Not verified: an actual end-to-end retry against a live 503 from
  Crashlytics (needs the failure to reproduce with network credentials this
  environment doesn't have). The next Codemagic release build - and whether
  the mapping-upload step is added there - is the real test.
