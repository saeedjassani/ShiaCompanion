import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/widget_prayer_time_selection.dart';

void main() {
  test('dateTimeForTime24 parses HH:mm and rejects malformed input', () {
    final date = DateTime(2024, 6, 16);

    expect(dateTimeForTime24(date, '05:30'), DateTime(2024, 6, 16, 5, 30));
    expect(dateTimeForTime24(date, '5:30'), DateTime(2024, 6, 16, 5, 30));
    expect(dateTimeForTime24(date, 'not-a-time'), isNull);
    expect(dateTimeForTime24(date, '05:30:00'), isNull);
  });

  test('formatPrayerDateTime12 formats noon, midnight, and afternoon times', () {
    expect(formatPrayerDateTime12(DateTime(2024, 1, 1, 0, 5)), '12:05 am');
    expect(formatPrayerDateTime12(DateTime(2024, 1, 1, 12, 0)), '12:00 pm');
    expect(formatPrayerDateTime12(DateTime(2024, 1, 1, 13, 45)), '01:45 pm');
    expect(formatPrayerDateTime12(DateTime(2024, 1, 1, 23, 9)), '11:09 pm');
  });

  test('readWidgetPrayerTimes returns the default five prayers in order', () {
    final prayerTime = getPrayerTimeObject();
    final originalFormat = prayerTime.getTimeFormat();

    final readings = readWidgetPrayerTimes(
      prayerTime: prayerTime,
      date: DateTime(2024, 6, 16),
      latitude: 21.4225,
      longitude: 39.8262,
      timeZone: 3.0,
      times: defaultWidgetPrayerTimeSelection,
    );

    expect(
      readings.map((reading) => reading.time.name).toList(),
      ['Fajr', 'Zuhr', 'Asr', 'Maghrib', 'Isha'],
    );
    expect(
      readings.map((reading) => reading.dateTime).toList(),
      orderedEquals(
        List.of(readings.map((reading) => reading.dateTime))..sort(),
      ),
    );
    // The original time format must be restored after resolving times.
    expect(prayerTime.getTimeFormat(), originalFormat);
  });

  test('readWidgetPrayerTimes resolves the daylight markers chronologically',
      () {
    final readings = readWidgetPrayerTimes(
      prayerTime: getPrayerTimeObject(),
      date: DateTime(2024, 6, 16),
      latitude: 21.4225,
      longitude: 39.8262,
      timeZone: 3.0,
      times: widgetPrayerTimes,
    );

    expect(
      readings.map((reading) => reading.time.name).toList(),
      [
        'Fajr',
        'Sunrise',
        'Zuhr',
        'Asr',
        'Sunset',
        'Maghrib',
        'Isha',
        'Midnight',
      ],
    );
    for (var index = 1; index < readings.length; index++) {
      expect(
        readings[index].dateTime.isAfter(readings[index - 1].dateTime),
        isTrue,
        reason: '${readings[index].time.name} must follow '
            '${readings[index - 1].time.name}',
      );
    }
    expect(readings.every((reading) => reading.displayTime.isNotEmpty), isTrue);
  });

  test('resolveWidgetPrayerTimes falls back when the stored selection is unusable',
      () {
    expect(
      resolveWidgetPrayerTimes(['fajr', 'maghrib']).map((time) => time.id),
      defaultWidgetPrayerTimeIds,
    );
    expect(
      resolveWidgetPrayerTimes(null).map((time) => time.id),
      defaultWidgetPrayerTimeIds,
    );
    expect(
      resolveWidgetPrayerTimes(widgetPrayerTimes.map((t) => t.id).toList())
          .map((time) => time.id),
      defaultWidgetPrayerTimeIds,
    );
    expect(
      resolveWidgetPrayerTimes(['nonsense', 'fajr', 'sunrise', 'zuhr'])
          .map((time) => time.id),
      ['fajr', 'sunrise', 'zuhr'],
    );
    // Selections are stored as a set and read back in the order times occur.
    expect(
      resolveWidgetPrayerTimes(['sunset', 'fajr', 'sunrise'])
          .map((time) => time.id),
      ['fajr', 'sunrise', 'sunset'],
    );
  });

  test('buildExtendedPrayerTimeEntries includes all seven names plus a Midnight entry', () {
    final prayerTime = getPrayerTimeObject();

    final entries = buildExtendedPrayerTimeEntries(
      prayerTime: prayerTime,
      date: DateTime(2024, 6, 16),
      latitude: 21.4225,
      longitude: 39.8262,
      timeZone: 3.0,
    );

    expect(
      entries.map((e) => e.name).toList(),
      ['Fajr', 'Sunrise', 'Zuhr', 'Asr', 'Sunset', 'Maghrib', 'Isha', 'Midnight'],
    );
  });

  test('shiaMidnightForDate falls halfway between sunset and next fajr', () {
    final prayerTime = getPrayerTimeObject();
    final date = DateTime(2024, 6, 16);

    final midnight = shiaMidnightForDate(
      prayerTime: prayerTime,
      date: date,
      latitude: 21.4225,
      longitude: 39.8262,
    );

    final todayTimes = prayerTime.getPrayerTimes(date, 21.4225, 39.8262, 3.0);
    final nextDate = date.add(const Duration(days: 1));
    final nextDayTimes = prayerTime.getPrayerTimes(nextDate, 21.4225, 39.8262, 3.0);
    final sunset = dateTimeForTime24(date, todayTimes[prayerIndexSunset]);
    final nextFajr = dateTimeForTime24(nextDate, nextDayTimes[prayerIndexFajr]);

    expect(midnight, isNotNull);
    expect(midnight!.isAfter(sunset!), isTrue);
    expect(midnight.isBefore(nextFajr!), isTrue);
  });
}
