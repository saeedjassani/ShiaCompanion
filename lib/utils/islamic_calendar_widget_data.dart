import 'package:hijri/hijri_calendar.dart';

import 'widget_prayer_time_selection.dart';

/// How far ahead the calendar widgets can run without the app being opened.
/// Each day is its own entry, so the widget rolls over at midnight by itself
/// and only falls back to "Open app" once this many days have gone by.
const int calendarWidgetDayCount = 60;

/// How far ahead the "upcoming events" lists look, and how many they keep.
/// A year covers every event in events.json once; the cap keeps the payload
/// small enough for the watch's complication transfer.
const int calendarWidgetEventHorizonDays = 365;
const int calendarWidgetEventLimit = 30;

/// Compact month names for the watch's circular complication, where the
/// hijri package's own short forms ("Rab1", "DhuQ") read as codes.
const Map<int, String> _shortHijriMonthNames = {
  1: 'Muh',
  2: 'Saf',
  3: 'Rab I',
  4: 'Rab II',
  5: 'Jum I',
  6: 'Jum II',
  7: 'Raj',
  8: 'Sha',
  9: 'Ram',
  10: 'Shaw',
  11: 'Dhul Q',
  12: 'Dhul H',
};

/// The hijri date the Calendar page shows for [day], moon-sighting
/// adjustment included. Built the same way as `_hijriDateFor` there so the
/// widget and the page can never disagree about what day it is.
HijriCalendar hijriDateForCalendarDay(DateTime day, {required int offsetDays}) {
  return HijriCalendar.fromDate(
    DateTime(day.year, day.month, day.day).add(Duration(days: offsetDays)),
  );
}

/// The key events.json files an event under: `<hijri day>-<hijri month>`.
String hijriEventKey(HijriCalendar date) => '${date.hDay}-${date.hMonth}';

/// A one-line version of an events.json `content`, for a widget row.
///
/// Content is written for the Calendar page: several events on one day are
/// separate paragraphs, a paragraph can carry a follow-on line (a supplication,
/// an explanation), and most end in the year it happened. A widget row has
/// room for none of that, so each paragraph keeps only its first line minus a
/// trailing "– (57 A.H.)", and paragraphs are joined with a middle dot.
String widgetEventTitle(String content) {
  final paragraphs = content.split(RegExp(r'\n\s*\n'));
  final titles = <String>[];
  for (final paragraph in paragraphs) {
    final firstLine = paragraph
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    final title = firstLine
        .replaceFirst(_trailingHijriYear, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (title.isNotEmpty) titles.add(title);
  }
  return titles.join(' · ');
}

/// " – (57 A.H.)", " ‐ (36‐37 A.H.)", " - 9 A.H." at the end of a line.
final RegExp _trailingHijriYear =
    RegExp(r'\s*[-–‐]\s*(?:\([^()]*A\.H\.?\)|[^()\-–‐]*A\.H\.?)\s*$');

/// events.json colours an event 0 or 1 (see `_eventColor` on the Calendar
/// page); anything else is an event with no colour of its own, published as
/// -1 so the native side never has to tell "missing" from "zero".
int _eventColorCode(Object? value) {
  if (value == 0 || value == 1) return value as int;
  return -1;
}

Map<String, Object>? _eventFor(
  Map<String, dynamic> events,
  HijriCalendar date,
) {
  final event = events[hijriEventKey(date)];
  if (event is! Map) return null;
  final title = widgetEventTitle(event['content']?.toString() ?? '');
  if (title.isEmpty) return null;
  return {
    'title': title,
    'color': _eventColorCode(event['color']),
  };
}

/// One entry per day from [now]'s date: the hijri date and that day's event.
///
/// `start` is local midnight; the native widgets show the last entry that has
/// started, so they turn the page at midnight without the app running.
List<Map<String, Object>> buildCalendarWidgetDays({
  required DateTime now,
  required Map<String, dynamic> events,
  required int offsetDays,
  int dayCount = calendarWidgetDayCount,
}) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  return List.generate(dayCount, (dayOffset) {
    final date = calendarDayFrom(startOfToday, dayOffset);
    final hijri = hijriDateForCalendarDay(date, offsetDays: offsetDays);
    final event = _eventFor(events, hijri);
    return {
      'start': date.millisecondsSinceEpoch,
      'day': hijri.hDay,
      'month': hijri.longMonthName,
      'monthShort': _shortHijriMonthNames[hijri.hMonth] ?? hijri.shortMonthName,
      'year': hijri.hYear,
      'event': event?['title'] ?? '',
      'color': event?['color'] ?? -1,
    };
  });
}

/// The events coming up from [now]'s date onwards, soonest first — today's
/// included, so the native side can call it out as "Today" until midnight.
List<Map<String, Object>> buildUpcomingCalendarWidgetEvents({
  required DateTime now,
  required Map<String, dynamic> events,
  required int offsetDays,
  int horizonDays = calendarWidgetEventHorizonDays,
  int limit = calendarWidgetEventLimit,
}) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  final upcoming = <Map<String, Object>>[];
  for (var dayOffset = 0;
      dayOffset < horizonDays && upcoming.length < limit;
      dayOffset++) {
    final date = calendarDayFrom(startOfToday, dayOffset);
    final hijri = hijriDateForCalendarDay(date, offsetDays: offsetDays);
    final event = _eventFor(events, hijri);
    if (event == null) continue;
    upcoming.add({
      'start': date.millisecondsSinceEpoch,
      'hijri': '${hijri.hDay} ${hijri.longMonthName}',
      'title': event['title']!,
      'color': event['color']!,
    });
  }
  return upcoming;
}
