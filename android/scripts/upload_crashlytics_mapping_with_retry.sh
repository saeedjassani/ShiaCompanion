#!/usr/bin/env bash
#
# Upload the release R8/ProGuard mapping file to Firebase Crashlytics,
# retrying on failure, so a transient error from Crashlytics' ingest
# endpoint doesn't take the whole CI build down with it.
#
# WHY THIS EXISTS
# ----------------
# android/app/build.gradle turns minifyEnabled/shrinkResources on for the
# release build, so crash reports need a mapping-file upload to stay
# readable. The Crashlytics Gradle plugin's mappingFileUploadEnabled flag
# would wire uploadCrashlyticsMappingFileRelease as a dependency of
# assembleRelease/bundleRelease, so any hiccup talking to Crashlytics fails
# the whole release build - which is what happened on Codemagic:
#
#   Execution failed for task ':app:uploadCrashlyticsMappingFileRelease'.
#   > java.io.IOException: Unknown error while sending file, check network
#     [.../mapping-tmp/....gz; response: 503 HTTP/1.1 503 Service Unavailable]
#
# That 503 is Crashlytics' server, not this build: the same commit that
# turned minification on has had this exact task succeed repeatedly on
# GitHub Actions' CI, so the fix is not to change what gets uploaded but to
# stop a flaky upload from blocking the build that produces the APK/AAB.
#
# mappingFileUploadEnabled is now false, which only stops AGP from wiring
# the task in automatically - uploadCrashlyticsMappingFileRelease is still
# registered and can be run on its own. This script runs it after the app
# has already built successfully, with retries, so an occasional 503 costs
# a few extra seconds instead of a failed build.
#
# USAGE (from the repo root)
#   android/scripts/upload_crashlytics_mapping_with_retry.sh
#
# This project configures Codemagic through the Workflow Editor UI rather
# than a codemagic.yaml, so add this as a Script step in the Android
# workflow, directly after the existing build step:
#   Name:   Upload Crashlytics mapping file
#   Script: sh "$CM_BUILD_DIR/android/scripts/upload_crashlytics_mapping_with_retry.sh"

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
MAX_ATTEMPTS="${MAX_ATTEMPTS:-4}"
INITIAL_DELAY_SECONDS="${INITIAL_DELAY_SECONDS:-10}"

if [[ ! -f "$REPO_ROOT/android/gradlew" ]]; then
  echo "error: $REPO_ROOT/android/gradlew not found." >&2
  exit 1
fi

cd "$REPO_ROOT/android"

delay="$INITIAL_DELAY_SECONDS"
attempt=1
while true; do
  echo "==> Uploading Crashlytics mapping file (attempt $attempt/$MAX_ATTEMPTS)..."
  if ./gradlew uploadCrashlyticsMappingFileRelease; then
    echo "==> Crashlytics mapping file uploaded."
    exit 0
  fi

  if [[ "$attempt" -ge "$MAX_ATTEMPTS" ]]; then
    echo "error: mapping file upload failed after $MAX_ATTEMPTS attempts." >&2
    echo "       Release crash reports will show obfuscated frames until this" >&2
    echo "       is uploaded (re-run this script, or 'cd android && ./gradlew" >&2
    echo "       uploadCrashlyticsMappingFileRelease' manually)." >&2
    exit 1
  fi

  echo "==> Upload failed, retrying in ${delay}s..."
  sleep "$delay"
  delay=$((delay * 2))
  attempt=$((attempt + 1))
done
