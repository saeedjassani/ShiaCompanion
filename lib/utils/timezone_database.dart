import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

bool _isInitialized = false;

/// Loads the IANA time zone database once per process.
///
/// Prayer notifications only need this on mobile, but flight planning converts
/// between the origin and destination zones on every platform, so this is safe
/// to call from anywhere including web.
void ensureTimeZoneDatabaseInitialized() {
  if (_isInitialized) return;
  tz_data.initializeTimeZones();
  _isInitialized = true;
}

/// Resolves an IANA identifier such as `Europe/Istanbul` to a location.
///
/// Returns `null` instead of throwing when the identifier is unknown, so a
/// stale saved flight can degrade gracefully rather than crash the page.
tz.Location? tryGetLocation(String timeZoneId) {
  ensureTimeZoneDatabaseInitialized();
  try {
    return tz.getLocation(timeZoneId);
  } catch (e) {
    debugPrint('Unknown time zone "$timeZoneId": $e');
    return null;
  }
}

/// Short zone abbreviation (e.g. `PDT`, `+03`) for [instant] in [location].
String timeZoneAbbreviation(tz.Location location, DateTime instant) {
  return tz.TZDateTime.from(instant, location).timeZoneName;
}

/// UTC offset label such as `UTC-7` or `UTC+5:30` for [instant] in [location].
String utcOffsetLabel(tz.Location location, DateTime instant) {
  final offset = tz.TZDateTime.from(instant, location).timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final totalMinutes = offset.inMinutes.abs();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return minutes == 0
      ? 'UTC$sign$hours'
      : 'UTC$sign$hours:${minutes.toString().padLeft(2, '0')}';
}
