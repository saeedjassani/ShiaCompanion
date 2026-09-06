#!/usr/bin/env bash
#
# Upload every dSYM produced by an iOS release build to Firebase Crashlytics,
# synchronously, failing loudly if anything goes wrong.
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
# Run this AFTER the archive step instead. It uploads in the foreground and
# returns non-zero if the upload fails.
#
# USAGE (from the repo root)
#   ios/scripts/upload_dsyms_to_crashlytics.sh [path/to/Runner.xcarchive | path/to/dSYMs]
#
# With no argument it looks for the archive that `flutter build ipa` produces at
# build/ios/archive/*.xcarchive. On Codemagic add it as a post-build script:
#   sh "$CM_BUILD_DIR/ios/scripts/upload_dsyms_to_crashlytics.sh"

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
UPLOAD_SYMBOLS="${UPLOAD_SYMBOLS:-$REPO_ROOT/ios/Pods/FirebaseCrashlytics/upload-symbols}"
GOOGLE_SERVICE_PLIST="${GOOGLE_SERVICE_PLIST:-$REPO_ROOT/ios/Runner/GoogleService-Info.plist}"

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

echo "==> Uploading to Crashlytics (synchronous)..."
"$UPLOAD_SYMBOLS" \
  --google-service-plist "$GOOGLE_SERVICE_PLIST" \
  --platform ios \
  -- "${DSYMS[@]}"

echo "==> Crashlytics dSYM upload finished for ${#DSYMS[@]} bundle(s)."
