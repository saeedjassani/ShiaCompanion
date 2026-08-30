#!/bin/bash
# Seeds fake prayer-time data into the booted Apple Watch simulator's app-group
# preferences, so the ShiaCompanionWatchWidgets complications have something
# real to render without needing an actual paired iPhone.
#
# This writes the same keys `WatchConnectivityManager` writes when a real
# snapshot arrives from the phone (see `PrayerDataStore.swift`), directly into
# the watch app's app-group container.
#
# IMPORTANT: this writes the plist with Python's plistlib, NOT `defaults
# write`. On current macOS, `defaults write <arbitrary-container-path>` exits
# 0 but silently never persists to disk (its writes only reliably land for
# domains/paths cfprefsd already manages) — confirmed by writing, then
# checking the file never appeared even after `killall cfprefsd`. A direct
# plist write sidesteps that.
#
# This also bypasses `WidgetCenter.reloadAllTimelines()` (only the real
# WatchConnectivity path calls that), so a fresh complication only ever
# fetches on its own schedule. Rebooting the simulator forces an immediate
# fetch: `xcrun simctl shutdown <udid> && xcrun simctl boot <udid>`.
#
# Usage: ./seed_watch_prayer_times.sh [device-udid]
# With no argument, uses the first booted watchOS simulator.

set -euo pipefail

DEV="${1:-}"
if [ -z "$DEV" ]; then
  DEV=$(xcrun simctl list devices booted | grep -i "watch" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)
fi
if [ -z "$DEV" ]; then
  echo "No booted watch simulator found. Boot one or pass a device UDID." >&2
  exit 1
fi
echo "Using device: $DEV"

APP_GROUP="group.com.developer110.shiacompanion"
CONTAINER=$(xcrun simctl listapps "$DEV" 2>/dev/null \
  | grep -A1 "\"$APP_GROUP\" =" \
  | grep -oE 'AppGroup/[0-9A-F-]+' | head -1)
if [ -z "$CONTAINER" ]; then
  echo "Could not find the $APP_GROUP container. Is the watch app installed on $DEV?" >&2
  exit 1
fi

PLIST="/Users/saeedjassani/Library/Developer/CoreSimulator/Devices/$DEV/data/Containers/Shared/$CONTAINER/Library/Preferences/$APP_GROUP.plist"
echo "Writing to: $PLIST"

python3 - "$PLIST" <<'PY'
import plistlib, sys, time, datetime

plist_path = sys.argv[1]
now_ms = int(time.time() * 1000)
# A schedule of upcoming prayer times spread over the next several hours plus
# tomorrow's Fajr, in the "epochMillis|name|time|dateLabel" format
# `parsePrayerSchedule` expects, joined with ";" (see PrayerDataStore.swift).
offsets_min = [20, 90, 240, 400, 600, 1440 + 20]
names = ["Zuhr", "Asr", "Maghrib", "Isha", "Midnight", "Fajr"]
entries = []
for off, name in zip(offsets_min, names):
    t = now_ms + off * 60 * 1000
    dt = datetime.datetime.fromtimestamp(t / 1000)
    time_str = dt.strftime("%I:%M %p").lstrip("0").lower()
    entries.append(f"{t}|{name}|{time_str}|Today")
schedule = ";".join(entries)

data = {
    "sc_prayer_schedule": schedule,
    "sc_watch_updated_at": float(now_ms),
    "sc_prayer_location": "Karbala",
}
with open(plist_path, "wb") as f:
    plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)

print("Seeded schedule:")
print(f"  {schedule}")
PY

echo
echo "Done. A complication extension only fetches on its own schedule, so to"
echo "see this immediately, force a fresh fetch with either:"
echo "  1. xcrun simctl shutdown $DEV && xcrun simctl boot $DEV"
echo "  2. Long-press the watch face -> Edit -> reselect Shia Companion in its slot"
