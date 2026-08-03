import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

/// Which times the home screen widgets show. Chosen once in Settings and shared
/// by the prayer times list widget and the Up Next countdown, so both agree on
/// what "next" means.
///
/// The five prayers are the default, but a prayer offered before it becomes
/// qaza is bounded by Sunrise, Sunset or Midnight rather than by the next
/// prayer, so those markers are selectable too.
const String widgetPrayerTimesKey = 'widget_prayer_times';

/// Fewer than three leaves the list widget looking broken; more than six stops
/// the columns fitting a medium widget.
const int minWidgetPrayerTimes = 3;
const int maxWidgetPrayerTimes = 6;

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
