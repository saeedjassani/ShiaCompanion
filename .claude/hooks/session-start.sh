#!/bin/bash
set -euo pipefail

# Only meaningful on Claude Code on the web: each session there starts from a
# fresh container with no Flutter SDK installed, which is what forces every
# session to re-download Flutter before `flutter analyze`/`flutter test` can
# run at all.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_HOME="/opt/flutter"

# Read the pinned version from .github/workflows/ci.yml instead of repeating
# it here, per that file's own comment: "Pinned so a new Flutter stable
# release can never turn CI red on its own. Bump deliberately, in this one
# place." This keeps the web session on the same Flutter version CI uses.
FLUTTER_VERSION="$(grep -m1 "FLUTTER_VERSION:" "$CLAUDE_PROJECT_DIR/.github/workflows/ci.yml" | sed -E "s/.*FLUTTER_VERSION:[[:space:]]*'?([0-9.]+)'?.*/\1/")"

if [ -z "$FLUTTER_VERSION" ]; then
  echo "session-start: could not read FLUTTER_VERSION from ci.yml, skipping Flutter install" >&2
  exit 0
fi

installed_version=""
if [ -x "$FLUTTER_HOME/bin/flutter" ]; then
  installed_version="$("$FLUTTER_HOME/bin/flutter" --version --machine 2>/dev/null | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p')"
fi

if [ "$installed_version" != "$FLUTTER_VERSION" ]; then
  echo "session-start: installing Flutter $FLUTTER_VERSION (found: ${installed_version:-none})"

  releases_json="$(mktemp)"
  curl -fsSL --max-time 60 -o "$releases_json" \
    "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"

  read -r archive expected_sha256 <<EOF_PY
$(python3 -c "
import json
d = json.load(open('$releases_json'))
for r in d['releases']:
    if r['version'] == '$FLUTTER_VERSION' and r.get('channel') == 'stable':
        print(r['archive'], r['sha256'])
        break
")
EOF_PY
  rm -f "$releases_json"

  if [ -z "${archive:-}" ]; then
    echo "session-start: Flutter $FLUTTER_VERSION not found in releases_linux.json, skipping install" >&2
    exit 0
  fi

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

echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"

cd "$CLAUDE_PROJECT_DIR"
"$FLUTTER_HOME/bin/flutter" pub get
