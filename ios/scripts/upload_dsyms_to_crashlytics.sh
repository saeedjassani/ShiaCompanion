#!/usr/bin/env bash
#
# Upload every dSYM produced by an iOS release build to Firebase Crashlytics,
# synchronously, retrying on failure, so a transient hiccup talking to
# Crashlytics doesn't leave a release permanently missing its dSYMs.
#
# WHY THIS EXISTS
# ---------------
# The Xcode build phase that ships with the FirebaseCrashlytics pod runs
# "${PODS_ROOT}/FirebaseCrashlytics/run", and the last line of that script is:
#
#     eval $COMMAND_PATH$UPLOAD_ARGUMENTS > /dev/null 2>&1 &
#
# i.e. the actual upload is forked into the BACKGROUND with stdout and stderr
# thrown away. That is fine on a developer Mac (the process outlives the build),
# but on CI the `xcodebuild archive` step returns and the build container is
# torn down seconds later, killing the upload mid-flight. Nothing is uploaded
# and nothing is logged, which is exactly the "Missing dSYM" email arriving for
# every single release.
#
# The in-archive build phase (ios/Runner.xcodeproj's "Upload Crashlytics
# dSYMs" phase) already fixes that by uploading in the foreground - but it
# has also been observed timing out against Crashlytics' endpoint from CI
# (see IOS_DSYM_FIX_NOTES.md), and it only gets one bounded attempt before
# it gives up and warns rather than failing the archive. This script is the
# second, independent attempt: run it AFTER the archive step so a dSYM that
# the in-archive phase warned about (rather than uploaded) still has a real
# chance of reaching Crashlytics, with retries this time.
#
# USAGE (from the repo root)
#   ios/scripts/upload_dsyms_to_crashlytics.sh [path/to/Runner.xcarchive | path/to/dSYMs]
#
# With no argument it looks for the archive that `flutter build ipa` produces at
# build/ios/archive/*.xcarchive.
#
# This project configures Codemagic through the Workflow Editor UI rather
# than a codemagic.yaml, so add this as a Script step in the iOS workflow,
# directly after the existing `flutter build ipa` step:
#   Name:   Upload dSYMs to Crashlytics
#   Script: sh "$CM_BUILD_DIR/ios/scripts/upload_dsyms_to_crashlytics.sh"
#
# It only needs the archive to already exist - it doesn't depend on signing
# or publishing having run first, so it's safe to place right after the
# build step regardless of what comes later in the workflow.

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
UPLOAD_SYMBOLS="${UPLOAD_SYMBOLS:-$REPO_ROOT/ios/Pods/FirebaseCrashlytics/upload-symbols}"
GOOGLE_SERVICE_PLIST="${GOOGLE_SERVICE_PLIST:-$REPO_ROOT/ios/Runner/GoogleService-Info.plist}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-4}"
INITIAL_DELAY_SECONDS="${INITIAL_DELAY_SECONDS:-10}"

if [[ ! -x "$UPLOAD_SYMBOLS" ]]; then
  echo "error: upload-symbols not found at $UPLOAD_SYMBOLS." >&2
  echo "       Run 'pod install' in ios/ before archiving." >&2
  exit 1
fi

if [[ ! -f "$GOOGLE_SERVICE_PLIST" ]]; then
  echo "error: GoogleService-Info.plist not found at $GOOGLE_SERVICE_PLIST." >&2
  exit 1
fi

# Resolve where the dSYMs live.
SEARCH_PATH="${1:-}"
if [[ -z "$SEARCH_PATH" ]]; then
  # `flutter build ipa` writes here; plain `xcodebuild archive` may too.
  for candidate in "$REPO_ROOT"/build/ios/archive/*.xcarchive; do
    if [[ -d "$candidate" ]]; then
      SEARCH_PATH="$candidate"
      break
    fi
  done
fi

if [[ -z "$SEARCH_PATH" || ! -e "$SEARCH_PATH" ]]; then
  echo "error: no .xcarchive found. Pass the archive (or dSYMs directory) as an argument." >&2
  exit 1
fi

# An .xcarchive keeps its dSYMs in a dSYMs/ subdirectory.
if [[ -d "$SEARCH_PATH/dSYMs" ]]; then
  SEARCH_PATH="$SEARCH_PATH/dSYMs"
fi

DSYMS=()
while IFS= read -r line; do
  DSYMS+=("$line")
done < <(find "$SEARCH_PATH" -name '*.dSYM' -maxdepth 3 -print | sort)

if [[ ${#DSYMS[@]} -eq 0 ]]; then
  echo "error: no .dSYM bundles under $SEARCH_PATH." >&2
  echo "       Check that DEBUG_INFORMATION_FORMAT is dwarf-with-dsym for Release." >&2
  exit 1
fi

# Print the UUIDs we are about to upload. Crashlytics' "Missing dSYM" alerts
# name a UUID, so this log line is what you diff against the alert.
echo "==> dSYMs found under $SEARCH_PATH:"
for dsym in "${DSYMS[@]}"; do
  echo "    $(basename "$dsym")"
  dwarfdump --uuid "$dsym" 2>/dev/null | sed 's/^/      /' || true
done

delay="$INITIAL_DELAY_SECONDS"
attempt=1
while true; do
  echo "==> Uploading to Crashlytics (attempt $attempt/$MAX_ATTEMPTS, synchronous)..."
  if "$UPLOAD_SYMBOLS" \
    --google-service-plist "$GOOGLE_SERVICE_PLIST" \
    --platform ios \
    -- "${DSYMS[@]}"; then
    echo "==> Crashlytics dSYM upload finished for ${#DSYMS[@]} bundle(s)."
    exit 0
  fi

  if [[ "$attempt" -ge "$MAX_ATTEMPTS" ]]; then
    echo "error: dSYM upload failed after $MAX_ATTEMPTS attempts." >&2
    echo "       Crash reports for this build will show as 'Missing dSYM' until" >&2
    echo "       this is uploaded (re-run this script once network access to" >&2
    echo "       Crashlytics is confirmed working)." >&2
    exit 1
  fi

  echo "==> Upload failed, retrying in ${delay}s..."
  sleep "$delay"
  delay=$((delay * 2))
  attempt=$((attempt + 1))
done
