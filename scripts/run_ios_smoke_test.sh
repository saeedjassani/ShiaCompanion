#!/usr/bin/env bash
# ==============================================================================
# run_ios_smoke_test.sh
# Runs the automated Flutter Integration Smoke Crawler on an iOS Simulator/Device.
# ==============================================================================
set -euo pipefail

TEST_TARGET="integration_test/smoke_crawler_test.dart"
DEVICE_ID=""
DRY_RUN=false

show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Runs the automated Flutter smoke crawler on an iOS Simulator or connected device.

Options:
  -d, --device <ID/Name>   Target iOS Simulator/Device name or UDID
      --dry-run            Print the execution command without running
  -h, --help               Show this help message

Examples:
  $(basename "$0")                     # Automatically finds or boots an iOS Simulator
  $(basename "$0") -d "iPhone 16"      # Runs on iPhone 16 simulator
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device)
      DEVICE_ID="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_help
      exit 1
      ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Ensure macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: iOS tests require macOS with Xcode installed." >&2
  exit 1
fi

# Detect device if not explicitly provided
if [[ -z "$DEVICE_ID" ]]; then
  # Check if an iOS simulator is already booted
  BOOTED_SIM="$(xcrun simctl list devices 2>/dev/null | grep -i '(Booted)' | head -n 1 | sed -E 's/^[[:space:]]*([^(]+)[[:space:]]*\(([^)]+)\).*/\1/' || true)"
  if [[ -n "$BOOTED_SIM" ]]; then
    DEVICE_ID="$(echo "$BOOTED_SIM" | xargs)"
    echo "==> Using currently booted simulator: ${DEVICE_ID}"
  else
    # Fallback to default iOS Simulator emulator id
    DEVICE_ID="apple_ios_simulator"
    echo "==> No simulator booted; defaulting to: ${DEVICE_ID}"
  fi
fi

CMD=(
  flutter test
  "$TEST_TARGET"
  -d "$DEVICE_ID"
)

echo "==> Executing iOS Smoke Crawler test:"
printf ' %q' "${CMD[@]}"
echo ""

if [[ "$DRY_RUN" == true ]]; then
  echo "[Dry Run] Command not executed."
  exit 0
fi

"${CMD[@]}"
