#!/bin/bash
set -euo pipefail

# Only meaningful on Claude Code on the web: each session there starts from a
# fresh container with no Flutter SDK installed, which is what forces every
# session to re-download Flutter before `flutter analyze`/`flutter test` can
# run at all.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Suppresses Flutter's "running as root" warning (these containers run as
# root) and keeps it out of every session's transcript.
export CI=true

FLUTTER_HOME="/opt/flutter"

installed_version=""
if [ -x "$FLUTTER_HOME/bin/flutter" ]; then
  installed_version="$("$FLUTTER_HOME/bin/flutter" --version --machine 2>/dev/null | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p')"
fi

# CI installs the latest stable Flutter (no pinned version), so match it
# here: look up the current stable release from Flutter's release manifest.
releases_json="$(mktemp)"
FLUTTER_VERSION=""
if curl -fsSL --max-time 60 -o "$releases_json" \
  "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"; then
  read -r FLUTTER_VERSION archive expected_sha256 <<EOF_PY
$(python3 -c "
import json
d = json.load(open('$releases_json'))
stable = d['current_release']['stable']
for r in d['releases']:
    if r['hash'] == stable and r.get('channel') == 'stable':
        print(r['version'], r['archive'], r['sha256'])
        break
")
EOF_PY
fi
rm -f "$releases_json"

if [ -z "${FLUTTER_VERSION:-}" ] || [ -z "${archive:-}" ]; then
  if [ -z "$installed_version" ]; then
    echo "session-start: could not find the current stable Flutter release, skipping Flutter install" >&2
    exit 0
  fi
  echo "session-start: could not look up the current stable Flutter release, using installed $installed_version" >&2
  FLUTTER_VERSION="$installed_version"
fi

if [ "$installed_version" != "$FLUTTER_VERSION" ]; then
  echo "session-start: installing Flutter $FLUTTER_VERSION (found: ${installed_version:-none})"

  tarball="$(mktemp --suffix=.tar.xz)"
  curl -fsSL --max-time 300 -o "$tarball" \
    "https://storage.googleapis.com/flutter_infra_release/releases/$archive"

  actual_sha256="$(sha256sum "$tarball" | cut -d' ' -f1)"
  if [ "$actual_sha256" != "$expected_sha256" ]; then
    echo "session-start: checksum mismatch downloading Flutter $FLUTTER_VERSION, aborting" >&2
    rm -f "$tarball"
    exit 1
  fi

  rm -rf "$FLUTTER_HOME"
  mkdir -p "$FLUTTER_HOME"
  tar -xJf "$tarball" -C "$(dirname "$FLUTTER_HOME")" --no-same-owner
  rm -f "$tarball"

  git config --global --add safe.directory "$FLUTTER_HOME"
  "$FLUTTER_HOME/bin/flutter" config --no-analytics --no-cli-animations >/dev/null
else
  echo "session-start: Flutter $FLUTTER_VERSION already installed at $FLUTTER_HOME"
fi

{
  echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\""
  echo "export CI=true"
} >> "$CLAUDE_ENV_FILE"

cd "$CLAUDE_PROJECT_DIR"

# `flutter pub get`'s own output (every resolved package, plus which ones
# have newer versions available) is routine noise that would otherwise land
# in the transcript on every single session start/resume. Only show it when
# it actually fails.
pub_get_log="$(mktemp)"
if ! "$FLUTTER_HOME/bin/flutter" pub get >"$pub_get_log" 2>&1; then
  echo "session-start: flutter pub get failed:" >&2
  cat "$pub_get_log" >&2
  rm -f "$pub_get_log"
  exit 1
fi
rm -f "$pub_get_log"
echo "session-start: dependencies resolved"
