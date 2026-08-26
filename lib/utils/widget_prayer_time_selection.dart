import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

/// Which times the home page card and home screen widgets show. Chosen once in
/// Settings and shared by the home card, the prayer times list widget and the
/// Up Next countdown, so all three agree on what "next" means.
///
/// The five prayers are the default, but a prayer offered before it becomes
/// qaza is bounded by Sunrise, Sunset or Midnight rather than by the next
/// prayer, so those markers are selectable too.
const String widgetPrayerTimesKey = 'widget_prayer_times';

/// Fewer than three leaves the list widget looking broken; more than five
/// stops the home card's row fitting a phone screen.
const int minWidgetPrayerTimes = 3;
const int maxWidgetPrayerTimes = 5;

class WidgetPrayerTime {
  const WidgetPrayerTime({
    required this.id,
    required this.name,
    this.timeIndex,
    this.offerBeforeId,
  });

  final String id;
  final String name;

  /// Index into [PrayerTime.getPrayerTimes], or null for times this app
  /// computes itself.
  final int? timeIndex;

  /// The time this one has to be offered before. Shown as the Up Next footer so
  /// the widget names the deadline, not just the start.
  final String? offerBeforeId;
}

/// Every selectable time, in the order they occur.
const List<WidgetPrayerTime> widgetPrayerTimes = <WidgetPrayerTime>[
  WidgetPrayerTime(
    id: 'fajr',
    name: 'Fajr',
    timeIndex: prayerIndexFajr,
    offerBeforeId: 'sunrise',
  ),
  WidgetPrayerTime(
    id: 'sunrise',
    name: 'Sunrise',
    timeIndex: prayerIndexSunrise,
  ),
  WidgetPrayerTime(
    id: 'zuhr',
    name: 'Zuhr',
    timeIndex: prayerIndexZuhr,
    offerBeforeId: 'sunset',
  ),
  WidgetPrayerTime(
    id: 'asr',
    name: 'Asr',
    timeIndex: prayerIndexAsr,
    offerBeforeId: 'sunset',
  ),
  WidgetPrayerTime(
    id: 'sunset',
    name: 'Sunset',
    timeIndex: prayerIndexSunset,
  ),
  WidgetPrayerTime(
    id: 'maghrib',
    name: 'Maghrib',
    timeIndex: prayerIndexMaghrib,
    offerBeforeId: 'midnight',
  ),
  WidgetPrayerTime(
    id: 'isha',
    name: 'Isha',
    timeIndex: prayerIndexIsha,
    offerBeforeId: 'midnight',
  ),
  WidgetPrayerTime(id: 'midnight', name: 'Midnight'),
];

const List<String> defaultWidgetPrayerTimeIds = <String>[
  'fajr',
  'zuhr',
  'asr',
  'maghrib',
  'isha',
];

/// A selected time resolved against the prayer engine for one day.
class WidgetPrayerTimeReading {
  const WidgetPrayerTimeReading({
    required this.time,
    required this.dateTime,
    required this.displayTime,
  });

  final WidgetPrayerTime time;

  /// Absolute instant, for countdowns and timeline transitions.
  final DateTime dateTime;

  /// 12-hour label, as the widgets render it.
  final String displayTime;
}

/// The stored selection, de-duplicated and back in chronological order. Falls
/// back to the five prayers whenever what is stored no longer resolves to a
/// usable selection, so a widget never renders empty.
List<WidgetPrayerTime> selectedWidgetPrayerTimes() {
  final stored = SP.isInitialized
      ? SP.prefs.getStringList(widgetPrayerTimesKey)
      : null;
  return resolveWidgetPrayerTimes(stored);
}

List<WidgetPrayerTime> resolveWidgetPrayerTimes(List<String>? ids) {
  final wanted = <String>{...?ids};
  final resolved = widgetPrayerTimes
      .where((time) => wanted.contains(time.id))
      .toList(growable: false);
  if (resolved.length < minWidgetPrayerTimes ||
      resolved.length > maxWidgetPrayerTimes) {
    return defaultWidgetPrayerTimeSelection;
  }
  return resolved;
}

List<WidgetPrayerTime> get defaultWidgetPrayerTimeSelection => widgetPrayerTimes
    .where((time) => defaultWidgetPrayerTimeIds.contains(time.id))
    .toList(growable: false);

Future<void> saveWidgetPrayerTimes(List<String> ids) async {
  final resolved = resolveWidgetPrayerTimes(ids)
      .map((time) => time.id)
      .toList(growable: false);
  await SP.prefs.setStringList(widgetPrayerTimesKey, resolved);
}

/// Resolves [times] for [date]. Times the engine cannot produce for the day —
/// Midnight above the polar circles, for instance — are dropped rather than
/// reported as an invalid string.
List<WidgetPrayerTimeReading> readWidgetPrayerTimes({
  required PrayerTime prayerTime,
  required DateTime date,
  required double latitude,
  required double longitude,
  required double timeZone,
  required List<WidgetPrayerTime> times,
}) {
  final originalFormat = prayerTime.getTimeFormat();
  try {
    prayerTime.setTimeFormat(prayerTime.getTime24());
    final times24 = prayerTime.getPrayerTimes(
      date,
      latitude,
      longitude,
      timeZone,
    );

    prayerTime.setTimeFormat(prayerTime.getTime12());
    final displayTimes = prayerTime.getPrayerTimes(
      date,
      latitude,
      longitude,
      timeZone,
    );

    final midnight = shiaMidnightForDate(
      prayerTime: prayerTime,
      date: date,
      latitude: latitude,
      longitude: longitude,
    );

    final readings = <WidgetPrayerTimeReading>[];
    for (final time in times) {
      final index = time.timeIndex;
      if (index == null) {
        if (midnight == null) continue;
        readings.add(WidgetPrayerTimeReading(
          time: time,
          dateTime: midnight,
          displayTime: formatPrayerDateTime12(midnight),
        ));
        continue;
      }

      final dateTime = dateTimeForTime24(date, times24[index]);
      if (dateTime == null) continue;
      readings.add(WidgetPrayerTimeReading(
        time: time,
        dateTime: dateTime,
        displayTime: displayTimes[index],
      ));
    }

    return readings;
  } finally {
    prayerTime.setTimeFormat(originalFormat);
  }
}

/// [start] advanced by [dayOffset] whole calendar days.
///
/// Not `add(Duration(days: n))`: that moves a fixed number of hours, so the
/// 25-hour day a DST fall-back creates lands back on the date it started from
/// and the 23-hour spring-forward day overshoots into the small hours. Both
/// produce a date whose prayer times are not the ones being asked for. Dart
/// normalises an out-of-range day field, so arithmetic on the components
/// lands on the intended calendar date in every zone.
DateTime calendarDayFrom(DateTime start, int dayOffset) {
  return start.isUtc
      ? DateTime.utc(start.year, start.month, start.day + dayOffset)
      : DateTime(start.year, start.month, start.day + dayOffset);
}

/// The next [count] occurrences of [times], soonest first, starting from
/// [now]. Looks at most one day past [now]'s date — enough to roll from
/// today's last selected time into tomorrow's first, since a selection is at
/// most [maxWidgetPrayerTimes] long and every unclaimed slot on day one is
/// guaranteed to be filled by day two's full selection.
List<WidgetPrayerTimeReading> nextWidgetPrayerTimeReadings({
  required PrayerTime prayerTime,
  required double latitude,
  required double longitude,
  required int count,
  DateTime? now,
  List<WidgetPrayerTime>? times,
}) {
  final selected = times ?? selectedWidgetPrayerTimes();
  final moment = now ?? DateTime.now();
  // Preserve whether the caller is working in UTC or local time: building a
  // local midnight from a UTC moment (or vice versa) would silently swap in
  // the wrong timezone offset for every reading computed below.
  final startOfToday = moment.isUtc
      ? DateTime.utc(moment.year, moment.month, moment.day)
      : DateTime(moment.year, moment.month, moment.day);

  final upcoming = <WidgetPrayerTimeReading>[];
  for (var dayOffset = 0; dayOffset < 2 && upcoming.length < count; dayOffset++) {
    final date = calendarDayFrom(startOfToday, dayOffset);
    final readings = readWidgetPrayerTimes(
      prayerTime: prayerTime,
      date: date,
      latitude: latitude,
      longitude: longitude,
      timeZone: date.timeZoneOffset.inMinutes / 60.0,
      times: selected,
    );
    upcoming.addAll(readings.where((reading) => reading.dateTime.isAfter(moment)));
  }

  upcoming.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return upcoming.take(count).toList(growable: false);
}
