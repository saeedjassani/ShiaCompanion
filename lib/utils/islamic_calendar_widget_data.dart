import 'package:hijri/hijri_calendar.dart';

import 'widget_prayer_time_selection.dart';
import '../l10n/hijri_l10n.dart';

/// How far ahead the calendar widgets can run without the app being opened.
/// Each day is its own entry, so the widget rolls over at midnight by itself
/// and only falls back to "Open app" once this many days have gone by.
const int calendarWidgetDayCount = 60;

/// How far ahead the "upcoming events" lists look, and how many they keep.
/// A year covers every event in events.json once; the cap keeps the payload
/// small enough for the watch's complication transfer.
const int calendarWidgetEventHorizonDays = 365;
const int calendarWidgetEventLimit = 30;

/// Compact month names for the watch complications and the widgets' date
/// column, where the hijri package's own short forms ("Rab1", "DhuQ") read
/// as codes.

/// The hijri package's month name in the house style: "Rabi' al-Thani", not
/// "Rabi' Al-Thani".
String _monthName(HijriCalendar date) =>
    hijriMonthName(date.hMonth).replaceAll(' Al-', ' al-');

String _monthShort(HijriCalendar date) =>
    hijriMonthShortName(date.hMonth);

/// The hijri date the Calendar page shows for [day], moon-sighting
/// adjustment included. Built the same way as `_hijriDateFor` there so the
/// widget and the page can never disagree about what day it is.
HijriCalendar hijriDateForCalendarDay(DateTime day, {required int offsetDays}) {
  return HijriCalendar.fromDate(
    DateTime(day.year, day.month, day.day).add(Duration(days: offsetDays)),
  );
}

/// The key events.json files an event under: "MM-DD", the same fixed-date
/// format as a zikr's `day` pattern (see lunar_date_matcher.dart).
String hijriEventKey(HijriCalendar date) =>
    '${date.hMonth.toString().padLeft(2, '0')}-'
    '${date.hDay.toString().padLeft(2, '0')}';

/// An events.json event, split the way the widgets show it: who it is about
/// ([name]) apart from what happened ([kind]), so a row can lead with the name
/// instead of every row starting "Birth of…" and being cut off before it.
class WidgetEventText {
  const WidgetEventText({
    required this.name,
    required this.shortName,
    required this.kind,
  });

  /// "Hazrat Fatima Zahra (s.a.)", "Battle of Jamal".
  final String name;

  /// [name] with a leading "Hazrat"/"Imam" cut to "H."/"I.", for the small
  /// widgets. Only for an event with a [kind]; anything else is unchanged.
  final String shortName;

  /// "Birth", "Martyrdom", "Death", or empty for an event that is not about
  /// one person (a battle, an Eid).
  final String kind;

  bool get isEmpty => name.isEmpty;
}

/// Splits an events.json `content` into a [WidgetEventText].
///
/// Content is written for the Calendar page: several events on one day are
/// separate paragraphs, a paragraph can carry a follow-on line (a supplication,
/// an explanation), and most end in the year it happened and an epithet ("– the
/// 4th Holy Imam"). A widget row has room for none of that, so each paragraph
/// keeps only its first line, cleaned of those. Paragraphs of the same kind
/// (17 Rabi' al-Awwal: two births) share it and join their names with a middle
/// dot; paragraphs of different kinds keep their own wording and no kind.
WidgetEventText widgetEventText(String content) {
  final parts = <(String, String)>[];
  for (final paragraph in content.split(RegExp(r'\n\s*\n'))) {
    final firstLine = paragraph
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    final part = _splitKind(_cleanEventLine(firstLine));
    if (part.$2.isNotEmpty) parts.add(part);
  }
  if (parts.isEmpty) {
    return const WidgetEventText(name: '', shortName: '', kind: '');
  }

  final kinds = parts.map((part) => part.$1).toSet();
  final sharedKind = kinds.length == 1 ? kinds.single : '';
  final names = [
    for (final (kind, name) in parts)
      sharedKind.isNotEmpty || kind.isEmpty ? name : '$kind of $name',
  ];
  return WidgetEventText(
    name: names.join(' · '),
    // Only a name is abbreviated: an event with no kind is a sentence
    // ("Imam Ali (a.s.) injured by…", "Battle of Jamal") and reads wrong cut.
    shortName: sharedKind.isEmpty
        ? names.join(' · ')
        : names.map(_shortenHonorific).join(' · '),
    kind: sharedKind,
  );
}

String _cleanEventLine(String line) {
  var text = line
      .replaceAll('\u2010', '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(RegExp(r'(\w)\('), (m) => '${m[1]} (');
  // Each strip can uncover the next ("– the 1st Holy Imam - (30 Aamul Feel)"),
  // so run them until nothing changes.
  while (true) {
    final stripped = text
        .replaceFirst(_trailingHijriYear, '')
        .replaceFirst(_trailingParenthetical, '')
        .replaceFirst(_trailingEpithet, '')
        .trim();
    if (stripped == text) return text;
    text = stripped;
  }
}

/// " – (57 A.H.)", " - (36-37 A.H.)", " - 9 A.H." at the end of a line.
final RegExp _trailingHijriYear =
    RegExp(r'\s*[-–]\s*(?:\([^()]*A\.H\.?\)|[^()\-–]*A\.H\.?)\s*$');

/// " - (30 Aamul Feel)", " – (53 years before Hijra)".
final RegExp _trailingParenthetical = RegExp(r'\s*[-–]\s*\([^()]*\)\s*$');

/// " – the 5th Holy Imam", " – Mother of Hazrat Abbas (a.s.)".
final RegExp _trailingEpithet = RegExp(
  r'\s*[-–]\s*(?:the\s+\d+\w*\s+Holy\s+Imam|(?:mother|uncle|grand\s*father|wife)\s+of\b.*)$',
  caseSensitive: false,
);

final List<(RegExp, String)> _kindPrefixes = [
  (RegExp(r'^(?:Birth|Wiladat)\s+of\s+|^Wiladat\s+e\s+'), 'Birth'),
  (
    RegExp(r'^Martyrdom(?:\s+of\s+|:\s*)|^Shahadate?\s+(?:of\s+)?'),
    'Martyrdom'
  ),
  (RegExp(r'^(?:Death|Wafat)\s+of\s+'), 'Death'),
];

(String, String) _splitKind(String line) {
  for (final (prefix, kind) in _kindPrefixes) {
    final match = prefix.firstMatch(line);
    if (match != null) return (kind, line.substring(match.end).trim());
  }
  return ('', line);
}

String _shortenHonorific(String name) {
  if (name.startsWith('Hazrat ')) return 'H. ${name.substring(7)}';
  if (name.startsWith('Imam ')) return 'I. ${name.substring(5)}';
  return name;
}

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
  final text = widgetEventText(event['content']?.toString() ?? '');
  if (text.isEmpty) return null;
  return {
    'title': text.name,
    'short': text.shortName,
    'kind': text.kind,
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
      'month': _monthName(hijri),
      'monthShort': _monthShort(hijri),
      'year': hijri.hYear,
      'event': event?['title'] ?? '',
      'eventShort': event?['short'] ?? '',
      'kind': event?['kind'] ?? '',
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
      'day': hijri.hDay,
      'month': _monthName(hijri),
      'monthShort': _monthShort(hijri),
      'hijri': '${hijri.hDay} ${_monthName(hijri)}',
      'title': event['title']!,
      'short': event['short']!,
      'kind': event['kind']!,
      'color': event['color']!,
    });
  }
  return upcoming;
}
