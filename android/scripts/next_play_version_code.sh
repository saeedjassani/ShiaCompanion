#!/usr/bin/env bash
#
# Prints the version code the next Google Play upload should use, for the
# phone app or the Wear OS app.
#
#   next_play_version_code.sh phone <pubspec build number>
#   next_play_version_code.sh wear  <pubspec build number>
#
# Play keys version codes by package, across every track and form factor,
# and the phone and watch apps share one package. So each gets its own
# range and only looks at its own tracks:
#
#   phone  pubspec's build number and up (137, 138, ...), on the phone tracks
#          (internal, alpha, beta, production and any custom closed track)
#   wear   100000 + pubspec's build number and up, on the wear:* tracks
#
# The next code is one above the highest already on those tracks, or the
# range's floor if that is higher. Reading every track would let the first
# watch upload's 100000-range code drag the phone's numbering up with it.
#
# Needs GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS, PACKAGE_NAME, the Codemagic
# CLI (google-play) and jq.
set -euo pipefail

app="${1:?phone or wear}"
pubspec_build="${2:?pubspec build number}"
wear_offset=100000

case "$app" in
  phone)
    floor=$pubspec_build
    select='select(.track | startswith("wear:") | not)'
    ;;
  wear)
    floor=$(( wear_offset + pubspec_build ))
    select='select(.track | startswith("wear:"))'
    ;;
  *)
    echo "Unknown app '$app': expected phone or wear." >&2
    exit 2
    ;;
esac

tracks=$(google-play tracks list --package-name "$PACKAGE_NAME" --json)
latest=$(jq -r "[.[] | $select | .releases[]? | .versionCodes[]? | tonumber] | max // 0" <<<"$tracks")

next=$(( latest + 1 ))
(( next > floor )) || next=$floor

if [[ "$app" == phone ]] && (( next >= wear_offset )); then
  echo "Phone version code $next has reached the watch's range ($wear_offset+)." >&2
  exit 1
fi

echo "Latest $app version code on Play: ${latest/#0/none}; next: $next." >&2
echo "$next"
