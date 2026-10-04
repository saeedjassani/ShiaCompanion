import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import 'shared_preferences.dart';
import 'timezone_database.dart';

/// The clock prayer times are told in.
///
/// The phone's own, unless the reader chose a city by hand in another time
/// zone: then that city's. Someone who picks Karbala while their phone still
/// keeps London time is asking when Fajr is in Karbala, and "2:41 am" (London
/// time) answers a different question. Only how a time is written, and which
/// day counts as today, change; a notification still fires at the moment of
/// Fajr wherever that is.
///
/// Everything that turns the prayer engine's "05:12" into a moment builds it
/// on the clock of the date it was given (see dateTimeOnClockOf), so starting
/// from [now] or [day] is all a caller has to do.
class PrayerClock {
  PrayerClock._();

  static const String zoneKey = 'prayer_time_zone';
  static const String placeKey = 'prayer_time_zone_place';

  static tz.Location? _zone;
  static String? _place;

  /// The chosen city's time zone, or null while times follow the phone.
  static tz.Location? get zone => _zone;

  /// Loads the clock saved by [use]. Call after [SP.init].
  static void restore() {
    if (!SP.isInitialized) return;
    final id = SP.prefs.getString(zoneKey);
    _zone = id == null || id.isEmpty ? null : tryGetLocation(id);
    _place = _zone == null ? null : SP.prefs.getString(placeKey);
  }

  /// Tells times on [timeZone]'s clock, naming it after [place] ("Karbala").
  /// An empty or unknown zone goes back to the phone's clock. Returns whether
  /// the clock changed.
  static Future<bool> use(String timeZone, {required String place}) async {
    final location = timeZone.isEmpty ? null : tryGetLocation(timeZone);
    if (location == null) return usePhoneClock();
    final changed = _zone?.name != location.name;
    _zone = location;
    _place = place;
    if (SP.isInitialized) {
      await SP.prefs.setString(zoneKey, location.name);
      await SP.prefs.setString(placeKey, place);
    }
    return changed;
  }

  /// Goes back to the phone's clock. Returns whether the clock changed.
  static Future<bool> usePhoneClock() async {
    final changed = _zone != null;
    _zone = null;
    _place = null;
    if (SP.isInitialized) {
      await SP.prefs.remove(zoneKey);
      await SP.prefs.remove(placeKey);
    }
    return changed;
  }

  /// [instant] (by default, this moment) on the prayer clock.
  static DateTime now([DateTime? instant]) {
    final moment = instant ?? DateTime.now();
    final zone = _zone;
    return zone == null ? moment : tz.TZDateTime.from(moment, zone);
  }

  /// The start of [year]-[month]-[day] on the prayer clock.
  static DateTime day(int year, int month, int day) {
    final zone = _zone;
    return zone == null
        ? DateTime(year, month, day)
        : tz.TZDateTime(zone, year, month, day);
  }

  /// "Karbala time" when the prayer clock reads differently from the phone's
  /// at [instant], so times shown on it are not mistaken for the phone's; null
  /// when the two agree, as they do for anyone who has not chosen a city
  /// abroad.
  static String? label([DateTime? instant]) {
    final zone = _zone;
    if (zone == null) return null;
    final moment = instant ?? DateTime.now();
    final offset = tz.TZDateTime.from(moment, zone).timeZoneOffset;
    if (offset == _phoneOffset(moment)) return null;
    final place = _place;
    if (place != null && place.isNotEmpty) return '$place time';
    // Asia/Baghdad -> "Baghdad time".
    return '${zone.name.split('/').last.replaceAll('_', ' ')} time';
  }

  /// [label], and how far the prayer clock is from the phone's: "Karbala
  /// time, 2 hr ahead of your phone". Null when [label] is.
  static String? describe([DateTime? instant]) {
    final name = label(instant);
    final zone = _zone;
    if (name == null || zone == null) return null;
    final moment = instant ?? DateTime.now();
    final difference =
        tz.TZDateTime.from(moment, zone).timeZoneOffset - _phoneOffset(moment);
    final minutes = difference.inMinutes.abs();
    final amount = [
      if (minutes >= 60) '${minutes ~/ 60} hr',
      if (minutes % 60 != 0) '${minutes % 60} min',
    ].join(' ');
    return difference.isNegative
        ? '$name, $amount behind your phone'
        : '$name, $amount ahead of your phone';
  }

  /// The phone's UTC offset at [instant]. Not `instant.toLocal()`: on a
  /// [tz.TZDateTime] that means the timezone package's own idea of local,
  /// which is UTC wherever nothing has set it (the web, for one).
  static Duration _phoneOffset(DateTime instant) =>
      DateTime.fromMillisecondsSinceEpoch(instant.millisecondsSinceEpoch)
          .timeZoneOffset;

  @visibleForTesting
  static void resetForTest() {
    _zone = null;
    _place = null;
  }
}
