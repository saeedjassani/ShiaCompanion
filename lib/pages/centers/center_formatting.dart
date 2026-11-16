import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../l10n/l10n.dart';
import '../../models/islamic_center.dart';
import '../../utils/flight_formatting.dart' show formatClock12;

/// "7:30 pm – 9:30 pm", "7:30 pm", or "All day"; and for something
/// spanning days, the end's date too.
String centerEventTimeRange(CenterEvent event, AppLocalizations l10n) {
  final o = event.occurrence;
  final start = o.localStart, end = o.localEnd;
  if (o.allDay) {
    final days = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    if (days <= 1) return l10n.centerAllDay;
    final last = end.subtract(const Duration(days: 1));
    return '${DateFormat('d MMM').format(start)} – '
        '${DateFormat('d MMM').format(last)}';
  }
  if (end == start) return formatClock12(start);
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  if (sameDay) return '${formatClock12(start)} – ${formatClock12(end)}';
  return '${formatClock12(start)} – '
      '${DateFormat('EEE d MMM').format(end)}, ${formatClock12(end)}';
}

/// "Today", "Tomorrow", or "Thursday 20 November" for [day], a local date.
String centerDayLabel(DateTime day, DateTime now, AppLocalizations l10n) {
  final days = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  if (days <= 0) return l10n.commonToday;
  if (days == 1) return l10n.commonTomorrow;
  return DateFormat(day.year == now.year ? 'EEEE d MMMM' : 'EEEE d MMMM y')
      .format(day);
}

/// "12 km" (or "800 m" under one), in the app language's digits.
String centerDistance(double km, AppLocalizations l10n) {
  if (km < 1) {
    final metres = (km * 1000 / 100).round() * 100;
    return l10n.centerDistanceMetres(metres < 100 ? 100 : metres);
  }
  return l10n.centerDistanceKm(NumberFormat(km < 10 ? '0.#' : '0').format(km));
}

/// "Updated just now", "Updated 20 minutes ago", "Updated 3 hours ago",
/// "Updated 14 Nov".
String centerUpdatedLabel(
  DateTime fetchedAt,
  DateTime now,
  AppLocalizations l10n,
) {
  final age = now.difference(fetchedAt);
  if (age.inMinutes < 1) return l10n.centerUpdatedJustNow;
  if (age.inHours < 1) return l10n.centerUpdatedMinutesAgo(age.inMinutes);
  if (age.inHours < 24) return l10n.centerUpdatedHoursAgo(age.inHours);
  return l10n.centerUpdatedOn(DateFormat('d MMM').format(fetchedAt));
}
