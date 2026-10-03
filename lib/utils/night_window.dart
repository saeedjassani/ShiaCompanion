import 'package:shia_companion/utils/lunar_date_matcher.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/prayer_times.dart';

/// Without a location (or when the prayer times can't be worked out for it),
/// the night window falls back to these local clock times, so night aamal
/// still show up for someone who hasn't granted location access. They're
/// deliberately generous - earlier than Maghrib and later than Fajr almost
/// anywhere - so the evening's aamal are visible ahead of time and stay up
/// through the morning, rather than missed at a boundary we can't place.
const int fallbackFajrHour = 8;
const int fallbackMaghribHour = 16;

/// Resolves the day whose *night* is "in effect" for a Shab occasion right
/// now, i.e. anywhere from Maghrib tonight through Fajr tomorrow
/// morning - or `null` when it's currently daytime. Without a location, the
/// window is approximated as [fallbackMaghribHour] to [fallbackFajrHour].
///
/// The Islamic day begins at Maghrib, not midnight, so the evening leading
/// into the 9th (say) is already the night of the 9th, even though the
/// calendar date is still the 8th. And that night ends at dawn: once Fajr
/// breaks, it's the *day* of the 9th, not its night, even though the plain
/// calendar date hasn't changed yet. Concretely:
///   - before today's Fajr: still the tail of last night -> today's Hijri date
///   - from today's Maghrib onward: tonight is tomorrow's Hijri date already
///   - in between (daytime): no night window is open -> null
///
/// [now] should be the real wall-clock time (for Fajr/Maghrib), while
/// [hijriDateOffsetDays] is the same manual moon-sighting correction applied
/// to the app's normal (non-night) Hijri date elsewhere, so both stay in sync.
/// The result is a [LunarDay], so the night's weekday ("N*-*-5", Thursday
/// night) is that of the civil day it leads into, never the offset one.
LunarDay? resolveNightLunarDay({
  required DateTime now,
  required PrayerTime prayerTime,
  double? latitude,
  double? longitude,
  int hijriDateOffsetDays = 0,
}) {
  final todayDateOnly = now.isUtc
      ? DateTime.utc(now.year, now.month, now.day)
      : DateTime(now.year, now.month, now.day);

  DateTime? todayFajr;
  DateTime? todayMaghrib;
  if (latitude != null && longitude != null) {
    final timeZone = now.timeZoneOffset.inMinutes / 60.0;
    final todayTimes =
        prayerTime.getPrayerTimes(todayDateOnly, latitude, longitude, timeZone);
    todayFajr = dateTimeForTime24(todayDateOnly, todayTimes[prayerIndexFajr]);
    todayMaghrib =
        dateTimeForTime24(todayDateOnly, todayTimes[prayerIndexMaghrib]);
  }
  if (todayFajr == null || todayMaghrib == null) {
    todayFajr = todayDateOnly.add(const Duration(hours: fallbackFajrHour));
    todayMaghrib =
        todayDateOnly.add(const Duration(hours: fallbackMaghribHour));
  }

  if (now.isBefore(todayFajr)) {
    return LunarDay(todayDateOnly, hijriOffsetDays: hijriDateOffsetDays);
  }
  if (!now.isBefore(todayMaghrib)) {
    return LunarDay(
      todayDateOnly.add(const Duration(days: 1)),
      hijriOffsetDays: hijriDateOffsetDays,
    );
  }
  return null;
}
