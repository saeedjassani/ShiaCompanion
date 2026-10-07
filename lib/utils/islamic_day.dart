import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/lunar_date_matcher.dart';
import 'package:shia_companion/utils/night_window.dart';
import 'package:shia_companion/utils/prayer_times.dart';

/// The Hijri day in effect at a moment, for showing as the date.
///
/// The Islamic day begins at Maghrib, so from Maghrib on the 15th the date
/// shown is already the 16th's, as the *eve* of it ("Eve of 5 Jumada
/// al-Awwal"); the eve lasts until Fajr, the same night window the "N" zikr
/// patterns use (see [resolveNightLunarDay]). Only where Maghrib is known: with
/// no location the date stays the civil one and turns at midnight, rather than
/// guessing when the evening starts.
class IslamicDay {
  const IslamicDay({required this.day, required this.isEve});

  /// The civil day this Hijri date belongs to, with that date
  /// (moon-sighting offset applied). From Maghrib to midnight that is
  /// tomorrow's civil day.
  final LunarDay day;

  /// From Maghrib until Fajr: the night leading into [day].
  final bool isEve;
}

/// The [IslamicDay] at [now], from the app's location and moon-sighting
/// setting unless given.
IslamicDay islamicDayAt(
  DateTime now, {
  PrayerTime? prayerTime,
  double? latitude,
  double? longitude,
  bool useAppLocation = true,
  int? hijriOffsetDays,
}) {
  final offset = hijriOffsetDays ?? hijriDate;
  final night = resolveKnownNightLunarDay(
    now: now,
    prayerTime: prayerTime ?? getPrayerTimeObject(),
    latitude: latitude ?? (useAppLocation ? lat : null),
    longitude: longitude ?? (useAppLocation ? long : null),
    hijriDateOffsetDays: offset,
  );
  if (night != null) return IslamicDay(day: night, isEve: true);
  return IslamicDay(
    day: LunarDay(now, hijriOffsetDays: offset),
    isEve: false,
  );
}
