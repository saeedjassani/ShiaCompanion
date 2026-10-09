import '../constants.dart';
import '../l10n/l10n.dart';
import '../models/zikr_reminder.dart';
import 'prayer_time_entries.dart';
import 'zikr_occasions.dart';

/// A clock time the way the prayer card shows one: "7:00 am".
String clockLabel(int hour, int minute) =>
    localizeDigits(formatPrayerDateTime12(DateTime(2000, 1, 1, hour, minute))
        .replaceFirst(RegExp(r'^0(?=\d)'), ''));

/// [days] (`DateTime.monday` 1 ... `DateTime.sunday` 7) starting from
/// [firstDayOfWeek] (0 = Sunday, as `MaterialLocalizations` counts).
List<int> orderedWeekdays(Iterable<int> days, int firstDayOfWeek) {
  int position(int day) => (day % 7 - firstDayOfWeek) % 7;
  return days.toList()..sort((a, b) => position(a) - position(b));
}

/// The days a reminder repeats on, in words: "Every day", "Thursdays",
/// "Tuesdays and Fridays" - or, past two days and unless [long], "Mon, Wed,
/// Fri", which fits a list row.
String reminderDaysLabel(
  Set<int> days,
  AppLocalizations l10n, {
  required int firstDayOfWeek,
  bool long = false,
}) {
  if (days.length == 7) return l10n.occasionEveryDay;
  final ordered = orderedWeekdays(days, firstDayOfWeek);
  if (days.length <= 2 || long) {
    return joinList([
      for (final day in ordered) l10n.occasionWeekly(weekdayName(day % 7)),
    ], l10n);
  }
  return ordered.map((day) => shortWeekdayName(day, l10n)).join(', ');
}

/// When on those days, short, for a list row: "7:00 am", "15 min after
/// Maghrib".
String reminderWhenLabel(ZikrReminder reminder) =>
    reminder.mode == ZikrReminderTimeMode.fixedTime
        ? clockLabel(reminder.hour, reminder.minute)
        : reminder.timeLabel;

/// What a reminder will do, in a sentence: "Thursdays, 15 minutes after
/// Maghrib (about 6:56 pm this week)". The time a prayer-relative one will
/// next fire is only there once the prayer times can be worked out.
String reminderSummary({
  required Set<int> days,
  required ZikrReminderTimeMode mode,
  required int hour,
  required int minute,
  required String prayerName,
  required int offsetMinutes,
  required AppLocalizations l10n,
  required int firstDayOfWeek,
  DateTime? now,
}) {
  final daysText =
      reminderDaysLabel(days, l10n, firstDayOfWeek: firstDayOfWeek, long: true);
  if (mode == ZikrReminderTimeMode.fixedTime) {
    return l10n.reminderSummary(
        daysText, l10n.reminderAtTime(clockLabel(hour, minute)));
  }

  final prayer = localizedPrayerName(prayerName, l10n);
  final when = offsetMinutes == 0
      ? l10n.reminderAtPrayerLong(prayer)
      : offsetMinutes > 0
          ? l10n.reminderMinutesAfterLong(offsetMinutes, prayer)
          : l10n.reminderMinutesBeforeLong(-offsetMinutes, prayer);
  final summary = l10n.reminderSummary(daysText, when);
  final next = _nextPrayerRelativeTime(
    days: days,
    prayerName: prayerName,
    offsetMinutes: offsetMinutes,
    now: now ?? DateTime.now(),
  );
  if (next == null) return summary;
  return l10n.reminderAboutThisWeek(
      summary, clockLabel(next.hour, next.minute));
}

/// The next time a prayer-relative reminder would fire, within a week; null
/// without a location, or on no selected day.
DateTime? _nextPrayerRelativeTime({
  required Set<int> days,
  required String prayerName,
  required int offsetMinutes,
  required DateTime now,
}) {
  final latitude = lat;
  final longitude = long;
  if (latitude == null || longitude == null || days.isEmpty) return null;
  try {
    for (var i = 0; i < 8; i++) {
      final date = DateTime(now.year, now.month, now.day + i);
      if (!days.contains(date.weekday)) continue;
      final entries = buildPrayerNotificationEntriesForDay(
        prayerTime: getPrayerTimeObject(),
        date: date,
        latitude: latitude,
        longitude: longitude,
      );
      for (final entry in entries) {
        if (entry.name != prayerName) continue;
        final at = entry.dateTime.add(Duration(minutes: offsetMinutes));
        if (at.isAfter(now)) return at;
      }
    }
  } catch (_) {
    // Without prayer times there is nothing to estimate from.
  }
  return null;
}
