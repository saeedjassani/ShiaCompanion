import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/prayer_times.dart';

/// Resolves the Hijri date that's "in effect" for a Shab (night) occasion
/// right now, i.e. anywhere from Maghrib tonight through Fajr tomorrow
/// morning - or `null` when it's currently daytime (or we don't have enough
/// information - a location - to tell).
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
HijriCalendar? resolveNightAdjustedHijriDate({
  required DateTime now,
  required PrayerTime prayerTime,
  double? latitude,
  double? longitude,
  int hijriDateOffsetDays = 0,
}) {
  if (latitude == null || longitude == null) return null;

  final todayDateOnly = now.isUtc
      ? DateTime.utc(now.year, now.month, now.day)
      : DateTime(now.year, now.month, now.day);
  final timeZone = now.timeZoneOffset.inMinutes / 60.0;

  final todayTimes =
      prayerTime.getPrayerTimes(todayDateOnly, latitude, longitude, timeZone);
  final todayFajr =
      dateTimeForTime24(todayDateOnly, todayTimes[prayerIndexFajr]);
  final todayMaghrib =
      dateTimeForTime24(todayDateOnly, todayTimes[prayerIndexMaghrib]);
  if (todayFajr == null || todayMaghrib == null) return null;

  final offset = Duration(days: hijriDateOffsetDays);

  if (now.isBefore(todayFajr)) {
    return HijriCalendar.fromDate(todayDateOnly.add(offset));
  }
  if (!now.isBefore(todayMaghrib)) {
    return HijriCalendar.fromDate(
      todayDateOnly.add(const Duration(days: 1)).add(offset),
    );
  }
  return null;
}
