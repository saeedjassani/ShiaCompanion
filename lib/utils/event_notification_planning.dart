import 'package:flutter/foundation.dart';

import 'hijri_date.dart';
import 'islamic_calendar_widget_data.dart';
import 'widget_prayer_time_selection.dart';

/// Which events.json days a reader can ask to be told about. events.json
/// colours a joyful day (a wiladat, an Eid) 1 and a day of mourning (a
/// shahadat, a death) 0; anything else is [other] (a battle, the start of
/// Ramazan, a Night of Qadr).
enum EventNotificationKind {
  celebration,
  mourning,
  other;

  static EventNotificationKind ofColor(Object? color) => switch (color) {
        1 => celebration,
        0 => mourning,
        _ => other,
      };
}

/// One event the planner picked, and when to tell the reader about it.
@immutable
class PlannedEventNotification {
  const PlannedEventNotification({
    required this.fireAt,
    required this.eventDate,
    required this.hijriDay,
    required this.hijriMonth,
    required this.hijriYear,
    required this.event,
    required this.kind,
    required this.major,
  });

  /// When the notification goes off, on the local clock.
  final DateTime fireAt;

  /// Local midnight of the civil day the event falls on.
  final DateTime eventDate;

  final int hijriDay;
  final int hijriMonth;
  final int hijriYear;

  /// The Hijri month it falls in, counted from the start of the era, so this
  /// Rajab and next year's are told apart.
  int get monthIndex => hijriYear * 12 + hijriMonth;

  /// The events.json entry, in the app language.
  final Map<dynamic, dynamic> event;
  final EventNotificationKind kind;

  /// events.json's `major`: a day nobody would want to miss (an Imam's birth
  /// or martyrdom, an Eid, Ashura, Ghadir).
  final bool major;

  @override
  String toString() =>
      'PlannedEventNotification($hijriDay/$hijriMonth at $fireAt)';
}

/// How far ahead events are planned: just short of a Hijri year (354 or 355
/// days), so no events.json day comes round twice in one plan.
const int eventNotificationHorizonDays = 350;

/// How many of the soonest events are always kept, whatever the budget, so
/// the reader who opens the app now and then never misses what is next.
const int eventNotificationSoonestKept = 2;

/// Picks which of the coming year's events to schedule, at most [budget] of
/// them, soonest first.
///
/// A plain "the next [budget] events" would spend everything on the busy
/// months - Rajab alone has fifteen events, Sha'ban seven - and fall silent
/// after them, so someone who doesn't open the app for a while would hear
/// nothing through the quiet months (Rabi' al-Thani has two). Instead:
///
/// 1. the next [eventNotificationSoonestKept] events, always;
/// 2. then one event for every Hijri month still ahead - its first major day,
///    or its first day when it has none - so however long the app stays
///    closed, each month still brings at least one, for as many months as
///    the budget stretches;
/// 3. then whatever budget is left, soonest first.
///
/// Rescheduling on every launch keeps the near weeks complete for anyone who
/// does open the app.
///
/// [now] is the local time; an event whose notification time has passed is
/// left out. [dayBefore] tells the reader the evening before (the Islamic day
/// begins at Maghrib), at [hour]:[minute], instead of on the day itself.
List<PlannedEventNotification> planEventNotifications({
  required DateTime now,
  required Map<String, dynamic> events,
  required int offsetDays,
  required Set<EventNotificationKind> kinds,
  required bool dayBefore,
  required int hour,
  required int minute,
  required int budget,
  int horizonDays = eventNotificationHorizonDays,
}) {
  if (budget <= 0 || kinds.isEmpty || events.isEmpty) return const [];

  final candidates = <PlannedEventNotification>[];
  final startOfToday = DateTime(now.year, now.month, now.day);
  for (var dayOffset = 0; dayOffset <= horizonDays; dayOffset++) {
    final date = calendarDayFrom(startOfToday, dayOffset);
    final hijri = hijriForCivilDate(date, offsetDays: offsetDays);
    final event = events[hijriEventKey(hijri)];
    if (event is! Map || eventHeadline(event).isEmpty) continue;
    final kind = EventNotificationKind.ofColor(event['color']);
    if (!kinds.contains(kind)) continue;
    // By calendar day, on the event day's own clock: a clock change between
    // the two must not move the notification an hour.
    final fireAt = dateTimeOfDay(
      calendarDayFrom(date, dayBefore ? -1 : 0),
      hour,
      minute,
    );
    if (!fireAt.isAfter(now)) continue;
    candidates.add(PlannedEventNotification(
      fireAt: fireAt,
      eventDate: date,
      hijriDay: hijri.hDay,
      hijriMonth: hijri.hMonth,
      hijriYear: hijri.hYear,
      event: event,
      kind: kind,
      major: event['major'] == true,
    ));
  }
  if (candidates.length <= budget) return candidates;

  final chosen = <int>{};
  void take(int index) {
    if (chosen.length < budget) chosen.add(index);
  }

  // 1. What is next.
  for (var i = 0;
      i < candidates.length && i < eventNotificationSoonestKept;
      i++) {
    take(i);
  }

  // 2. One per month ahead: its first major day, else its first day.
  final monthPick = <int, int>{};
  for (var i = 0; i < candidates.length; i++) {
    final month = candidates[i].monthIndex;
    final picked = monthPick[month];
    if (picked == null || (!candidates[picked].major && candidates[i].major)) {
      monthPick[month] = i;
    }
  }
  final heardFrom = {for (final i in chosen) candidates[i].monthIndex};
  for (final entry in monthPick.entries) {
    // A month step 1 already told the reader about needs nothing more.
    if (!heardFrom.contains(entry.key)) take(entry.value);
  }

  // 3. The rest, soonest first.
  for (var i = 0; i < candidates.length; i++) {
    take(i);
  }

  return [
    for (final index in chosen.toList()..sort()) candidates[index],
  ];
}

/// [day]'s date at [hour]:[minute], on [day]'s own clock.
@visibleForTesting
DateTime dateTimeOfDay(DateTime day, int hour, int minute) =>
    DateTime(day.year, day.month, day.day, hour, minute);
