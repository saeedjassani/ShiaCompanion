import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/l10n.dart';

/// `7:55 pm`, in the app language's digits and am/pm.
String formatClock12(DateTime value) {
  final suffix = value.hour >= 12 ? 'pm' : 'am';
  final hour = ((value.hour + 11) % 12) + 1;
  return localizeClockTime(
      '$hour:${value.minute.toString().padLeft(2, '0')} $suffix');
}

/// `Thu 30 Jul`, in the app language.
String formatShortDate(DateTime value) => DateFormat('EEE d MMM').format(value);

/// `Thu 30 Jul, 7:55 pm`
String formatWallClock(DateTime value) {
  return '${formatShortDate(value)}, ${formatClock12(value)}';
}

/// `13 h 10 min`, `7 h`, or `45 min` for anything under an hour.
String formatFlightDuration(Duration duration, [AppLocalizations? l10n]) {
  final strings = l10n ?? L10n.current;
  final totalMinutes = duration.inMinutes.abs();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return strings.durationMinutes(minutes);
  return minutes == 0
      ? strings.flightDurationHours(hours)
      : strings.flightDurationHoursMinutes(hours, minutes);
}

/// Converts a UTC instant into wall-clock time in [location].
DateTime toZone(DateTime instantUtc, tz.Location location) {
  return tz.TZDateTime.from(instantUtc, location);
}

/// `10,766 km` with thousands separators, in the app language.
String formatDistanceKm(double distanceKm) => L10n.current
    .distanceKm(NumberFormat.decimalPattern().format(distanceKm.round()));

/// Describes a day offset relative to a reference date, e.g. `+1 day` when a
/// prayer lands on the calendar day after departure in that time zone.
String? formatDayOffset(DateTime reference, DateTime value) {
  final referenceDay = DateTime(reference.year, reference.month, reference.day);
  final valueDay = DateTime(value.year, value.month, value.day);
  final days = valueDay.difference(referenceDay).inDays;
  if (days == 0) return null;
  final magnitude = days.abs();
  return days > 0
      ? L10n.current.dayOffsetLater(magnitude)
      : L10n.current.dayOffsetEarlier(magnitude);
}
