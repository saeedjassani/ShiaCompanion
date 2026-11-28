import 'package:flutter/foundation.dart';

import '../constants.dart' show buildPrayerNotificationEntriesForDay;
import 'prayer_times.dart';
import 'widget_prayer_time_selection.dart';

/// How long each prayer time's calendar event lasts. A time is a moment, but
/// a calendar draws a zero-length event as a sliver some apps hide; a
/// quarter of an hour reads as "at this time" in every day view. The events
/// are marked free, so the length blocks nothing.
const Duration prayerCalendarEventLength = Duration(minutes: 15);

/// How many days ahead the calendar can be filled, the choices offered.
/// Opening the app tops it back up, so the range only matters to someone
/// who doesn't open it for a while; a month is 150 events for five prayers,
/// which a phone writes in a few seconds.
const List<int> prayerCalendarDayChoices = <int>[7, 14, 30];
const int defaultPrayerCalendarDays = 30;

/// The five prayers: what someone adding prayer times to a calendar
/// expects, without Sunrise, Sunset and Midnight crowding each day.
const List<String> defaultPrayerCalendarTimeIds = <String>[
  'fajr',
  'zuhr',
  'asr',
  'maghrib',
  'isha',
];

/// Events added before today, and older than this, are taken out again when
/// the calendar is next brought up to date, so a calendar keeps a week of
/// past times and never collects years of them.
const int prayerCalendarDaysKept = 7;

/// One prayer time as a calendar event: [name] is the engine's ('Fajr').
@immutable
class PlannedPrayerEvent {
  const PlannedPrayerEvent({
    required this.name,
    required this.title,
    required this.start,
  });

  final String name;
  final String title;
  final DateTime start;

  DateTime get end => start.add(prayerCalendarEventLength);

  String get key => prayerCalendarEventKey(start, title);
}

/// An event this app put in the calendar, as it remembers it.
@immutable
class TrackedPrayerEvent {
  const TrackedPrayerEvent({
    required this.id,
    required this.start,
    required this.title,
  });

  final String id;
  final DateTime start;
  final String title;

  String get key => prayerCalendarEventKey(start, title);

  Map<String, Object> toJson() => {
    'id': id,
    'start': start.millisecondsSinceEpoch,
    'title': title,
  };

  static TrackedPrayerEvent? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], start = json['start'], title = json['title'];
    if (id is! String || start is! int || title is! String) return null;
    return TrackedPrayerEvent(
      id: id,
      start: DateTime.fromMillisecondsSinceEpoch(start),
      title: title,
    );
  }
}

/// Two events are the same when they start in the same minute under the same
/// title: then the one in the calendar is still right.
String prayerCalendarEventKey(DateTime start, String title) =>
    '${start.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute}|$title';

/// The times [timeIds] (ids of [widgetPrayerTimes]) on each of the [days]
/// days from [firstDay], soonest first, titled by [titleFor]. A time the
/// engine can't work out for a day (Midnight above the polar circles) is
/// left out of that day.
List<PlannedPrayerEvent> planPrayerCalendarEvents({
  required PrayerTime prayerTime,
  required DateTime firstDay,
  required int days,
  required Set<String> timeIds,
  required double latitude,
  required double longitude,
  required String Function(String name) titleFor,
}) {
  final names = {
    for (final time in widgetPrayerTimes)
      if (timeIds.contains(time.id)) time.name,
  };
  final planned = <PlannedPrayerEvent>[];
  for (var i = 0; i < days; i++) {
    final date = calendarDayFrom(firstDay, i);
    for (final entry in buildPrayerNotificationEntriesForDay(
      prayerTime: prayerTime,
      date: date,
      latitude: latitude,
      longitude: longitude,
    )) {
      if (!names.contains(entry.name)) continue;
      planned.add(
        PlannedPrayerEvent(
          name: entry.name,
          title: titleFor(entry.name),
          start: entry.dateTime,
        ),
      );
    }
  }
  planned.sort((a, b) => a.start.compareTo(b.start));
  return planned;
}

/// What to change in the calendar to bring [tracked] in line with [planned],
/// the times from [today] on.
@immutable
class PrayerCalendarChanges {
  const PrayerCalendarChanges({
    required this.delete,
    required this.create,
    required this.keep,
  });

  /// In the calendar, no longer wanted: a time that moved (a new city or
  /// method), one unticked, or one more than [prayerCalendarDaysKept] days
  /// old.
  final List<TrackedPrayerEvent> delete;

  /// Wanted, not yet in the calendar.
  final List<PlannedPrayerEvent> create;

  /// In the calendar and still right, past ones included.
  final List<TrackedPrayerEvent> keep;

  bool get isEmpty => delete.isEmpty && create.isEmpty;
}

/// Compares what is in the calendar with what should be.
///
/// Only the times from [today] on are planned again; a past one is kept as
/// it was written, whatever has changed since, until it is more than
/// [prayerCalendarDaysKept] days old. [planned] must start at [today].
PrayerCalendarChanges diffPrayerCalendar({
  required List<TrackedPrayerEvent> tracked,
  required List<PlannedPrayerEvent> planned,
  required DateTime today,
}) {
  final oldest = calendarDayFrom(today, -prayerCalendarDaysKept);
  final wanted = {for (final event in planned) event.key: event};
  final delete = <TrackedPrayerEvent>[];
  final keep = <TrackedPrayerEvent>[];
  final kept = <String>{};
  for (final event in tracked) {
    if (event.start.isBefore(oldest)) {
      delete.add(event);
    } else if (event.start.isBefore(today)) {
      keep.add(event);
    } else if (wanted.containsKey(event.key) && kept.add(event.key)) {
      keep.add(event);
    } else {
      // Moved, unticked, or a second copy of one already kept.
      delete.add(event);
    }
  }
  return PrayerCalendarChanges(
    delete: delete,
    create: [
      for (final event in planned)
        if (!kept.contains(event.key)) event,
    ],
    keep: keep,
  );
}
