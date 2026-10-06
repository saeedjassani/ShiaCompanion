import 'package:timezone/timezone.dart' as tz;

import '../l10n/l10n.dart';

const List<String> _weekdayNames = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
];

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `7:55 pm`
String formatClock12(DateTime value) {
  final suffix = value.hour >= 12 ? 'pm' : 'am';
  final hour = ((value.hour + 11) % 12) + 1;
  return '$hour:${value.minute.toString().padLeft(2, '0')} $suffix';
}

/// `Thu 30 Jul`
String formatShortDate(DateTime value) {
  return '${_weekdayNames[value.weekday - 1]} ${value.day} '
      '${_monthNames[value.month - 1]}';
}

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

/// `10,766 km` with thousands separators.
String formatDistanceKm(double distanceKm) {
  final rounded = distanceKm.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index++) {
    if (index > 0 && (rounded.length - index) % 3 == 0) buffer.write(',');
    buffer.write(rounded[index]);
  }
  return '$buffer km';
}

/// Describes a day offset relative to a reference date, e.g. `+1 day` when a
/// prayer lands on the calendar day after departure in that time zone.
String? formatDayOffset(DateTime reference, DateTime value) {
  final referenceDay = DateTime(reference.year, reference.month, reference.day);
  final valueDay = DateTime(value.year, value.month, value.day);
  final days = valueDay.difference(referenceDay).inDays;
  if (days == 0) return null;
  final magnitude = days.abs();
  final unit = magnitude == 1 ? 'day' : 'days';
  return days > 0 ? '+$magnitude $unit' : '-$magnitude $unit';
}
