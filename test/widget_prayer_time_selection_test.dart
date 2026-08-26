import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/services/home_screen_widget_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/widget_prayer_time_selection.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    city = 'Mecca';
    lat = 21.4225;
    long = 39.8262;
  });

  List<String> namesFrom(Map<String, String> snapshot) {
    return [
      for (final key in HomeScreenWidgetService.dailyPrayerNameKeys)
        if ((snapshot[key] ?? '').isNotEmpty) snapshot[key]!,
    ];
  }

  Set<String> scheduledNamesFrom(Map<String, String> snapshot) {
    return (snapshot[HomeScreenWidgetService.prayerScheduleKey] ?? '')
        .split(';')
        .map((entry) => entry.split('|'))
        .where((parts) => parts.length == 6)
        .map((parts) => parts[1])
        .toSet();
  }

  test('the prayer times widget shows the saved selection', () async {
    await saveWidgetPrayerTimes(
      ['maghrib', 'fajr', 'sunset', 'sunrise', 'zuhr'],
    );

    final snapshot = HomeScreenWidgetService.instance
        .buildDailyPrayerTimesSnapshot(now: DateTime(2024, 6, 16));

    // The selection decides *which* prayers appear; the clock decides the
    // order, because the widget now leads with the next one up the way the
    // card does. Asserting the set keeps this test about the selection and
    // stops it depending on the timezone the suite happens to run in.
    expect(
      namesFrom(snapshot).toSet(),
      {'Fajr', 'Sunrise', 'Zuhr', 'Sunset', 'Maghrib'},
    );
    expect(
      snapshot[HomeScreenWidgetService.dailyPrayerTimeKeys[1]],
      matches(RegExp(r'^\d{1,2}:\d{2} (am|pm)$')),
    );
  });

  test('an unset selection falls back to the five prayers', () {
    final snapshot = HomeScreenWidgetService.instance
        .buildDailyPrayerTimesSnapshot(now: DateTime(2024, 6, 16));

    expect(
      namesFrom(snapshot).toSet(),
      {'Fajr', 'Zuhr', 'Asr', 'Maghrib', 'Isha'},
    );
  });

  test('Up Next counts down to the selected times only', () async {
    await saveWidgetPrayerTimes(['fajr', 'sunrise', 'sunset']);

    final scheduled = scheduledNamesFrom(
      HomeScreenWidgetService.instance.buildUpcomingPrayerSnapshot(),
    );

    expect(scheduled, {'Fajr', 'Sunrise', 'Sunset'});
  });

  test('a prayer still names its deadline when that marker is hidden',
      () async {
    await saveWidgetPrayerTimes(defaultWidgetPrayerTimeIds);

    final schedule = (HomeScreenWidgetService.instance
                .buildUpcomingPrayerSnapshot()[
            HomeScreenWidgetService.prayerScheduleKey] ??
        '');
    final footers = {
      for (final parts in schedule
          .split(';')
          .map((entry) => entry.split('|'))
          .where((parts) => parts.length == 6))
        parts[1]: parts[4],
    };

    expect(footers['Fajr'], 'Sunrise');
    expect(footers['Zuhr'], 'Sunset');
    expect(footers['Asr'], 'Sunset');
    expect(footers['Maghrib'], 'Midnight');
    expect(footers['Isha'], 'Midnight');
  });

  test('a daylight marker has no deadline of its own', () async {
    await saveWidgetPrayerTimes(['sunrise', 'sunset', 'midnight']);

    final schedule = (HomeScreenWidgetService.instance
                .buildUpcomingPrayerSnapshot()[
            HomeScreenWidgetService.prayerScheduleKey] ??
        '');

    for (final parts in schedule
        .split(';')
        .map((entry) => entry.split('|'))
        .where((parts) => parts.length == 6)) {
      expect(parts[4], isEmpty, reason: '${parts[1]} must not carry a footer');
      expect(parts[5], isEmpty);
    }
  });

  test('the widget never asks for more slots than it has', () {
    expect(
      HomeScreenWidgetService.dailyPrayerNameKeys.length,
      maxWidgetPrayerTimes,
    );
    expect(
      HomeScreenWidgetService.dailyPrayerTimeKeys.length,
      maxWidgetPrayerTimes,
    );
  });

  group('nextWidgetPrayerTimeReadings', () {
    test('shows every selected time for today when none have passed yet',
        () async {
      await saveWidgetPrayerTimes(defaultWidgetPrayerTimeIds);
      final prayerTime = getPrayerTimeObject();
      // UTC, so the reading order below doesn't depend on the host machine's
      // timezone (an offset far from Mecca's own can otherwise wrap Fajr's
      // computed hour past midnight and into "yesterday").
      final date = DateTime.utc(2024, 6, 16);

      final readings = nextWidgetPrayerTimeReadings(
        prayerTime: prayerTime,
        latitude: lat!,
        longitude: long!,
        count: selectedWidgetPrayerTimes().length,
        now: date, // midnight: before every prayer that day
      );

      expect(
        readings.map((r) => r.time.name),
        ['Fajr', 'Zuhr', 'Asr', 'Maghrib', 'Isha'],
      );
      expect(readings.every((r) => r.dateTime.day == date.day), isTrue);
    });

    test('rolls entirely into tomorrow once today is spent', () async {
      await saveWidgetPrayerTimes(defaultWidgetPrayerTimeIds);
      final prayerTime = getPrayerTimeObject();
      final date = DateTime.utc(2024, 6, 16, 23, 59);

      final readings = nextWidgetPrayerTimeReadings(
        prayerTime: prayerTime,
        latitude: lat!,
        longitude: long!,
        count: selectedWidgetPrayerTimes().length,
        now: date,
      );

      expect(readings.length, 5);
      expect(readings.every((r) => r.dateTime.day == date.day + 1), isTrue);
    });

    test('fills the tail from tomorrow once today only has a few left',
        () async {
      await saveWidgetPrayerTimes(defaultWidgetPrayerTimeIds);
      final prayerTime = getPrayerTimeObject();
      final date = DateTime.utc(2024, 6, 16);
      final todaysZuhr = readWidgetPrayerTimes(
        prayerTime: prayerTime,
        date: date,
        latitude: lat!,
        longitude: long!,
        timeZone: date.timeZoneOffset.inMinutes / 60.0,
        times: selectedWidgetPrayerTimes(),
      ).firstWhere((r) => r.time.id == 'zuhr').dateTime;

      final readings = nextWidgetPrayerTimeReadings(
        prayerTime: prayerTime,
        latitude: lat!,
        longitude: long!,
        count: selectedWidgetPrayerTimes().length,
        now: todaysZuhr.add(const Duration(minutes: 1)),
      );

      expect(
        readings.map((r) => r.time.name),
        ['Asr', 'Maghrib', 'Isha', 'Fajr', 'Zuhr'],
      );
      expect(
        readings.take(3).every((r) => r.dateTime.day == date.day),
        isTrue,
      );
      expect(
        readings.skip(3).every((r) => r.dateTime.day == date.day + 1),
        isTrue,
      );
    });

    /// The DST fall-back day used to blank the card out.
    ///
    /// Stepping to "tomorrow" with `add(Duration(days: 1))` moves 24 elapsed
    /// hours, which on a 25-hour day lands back on today at 23:00. Day two then
    /// re-read today at the other UTC offset: duplicate prayers an hour apart
    /// earlier on, and from the evening onwards nothing upcoming at all.
    ///
    /// Local time is the whole point here, so the test finds a fall-back day in
    /// whatever zone it is running in and skips where there is none.
    test('reads tomorrow across a DST fall-back day', () async {
      DateTime? fallBackDay;
      for (var day = DateTime(2024, 1, 1);
          day.year == 2024;
          day = DateTime(day.year, day.month, day.day + 1)) {
        // The 25-hour day is exactly the one where 24 hours does not reach the
        // next date.
        if (day.add(const Duration(days: 1)).day == day.day) {
          fallBackDay = day;
          break;
        }
      }
      if (fallBackDay == null) {
        markTestSkipped('Local zone has no DST fall-back day in 2024.');
        return;
      }

      await saveWidgetPrayerTimes(defaultWidgetPrayerTimeIds);
      final prayerTime = getPrayerTimeObject();
      final count = selectedWidgetPrayerTimes().length;

      // Late enough that every one of today's prayers has passed, so the row
      // can only be filled from tomorrow.
      final evening = DateTime(
          fallBackDay.year, fallBackDay.month, fallBackDay.day, 23);
      final readings = nextWidgetPrayerTimeReadings(
        prayerTime: prayerTime,
        latitude: lat!,
        longitude: long!,
        count: count,
        now: evening,
      );

      expect(readings.length, count,
          reason: 'the card must not empty out on the fall-back evening');
      expect(readings.every((r) => r.dateTime.isAfter(evening)), isTrue);
      expect(readings.map((r) => r.time.id).toSet().length, readings.length,
          reason: 'the same prayer must not appear twice at two DST offsets');
      expect(readings.every((r) => r.dateTime.day != fallBackDay!.day), isTrue,
          reason: 'every reading this late belongs to the next day');
    });

    /// The widget published a day at a time while the card showed the next few
    /// prayers, so in the evening the two disagreed completely: the widget
    /// still listed prayers that had already happened, the card had moved on to
    /// tomorrow. They read through the same function now, and this pins them
    /// together at the times of day where they used to differ.
    test('the home screen widget shows what the card shows', () async {
      await saveWidgetPrayerTimes(defaultWidgetPrayerTimeIds);
      final prayerTime = getPrayerTimeObject();
      final selected = selectedWidgetPrayerTimes();

      for (final hour in [0, 6, 13, 19, 22, 23]) {
        final now = DateTime(2024, 6, 16, hour);
        final cardReadings = nextWidgetPrayerTimeReadings(
          prayerTime: prayerTime,
          latitude: lat!,
          longitude: long!,
          count: selected.length,
          now: now,
          times: selected,
        );
        final snapshot =
            HomeScreenWidgetService.instance.buildDailyPrayerTimesSnapshot(
          now: now,
        );

        expect(namesFrom(snapshot), cardReadings.map((r) => r.time.name),
            reason: 'widget and card disagree at ${hour}:00');
        expect(
          [
            for (final key in HomeScreenWidgetService.dailyPrayerTimeKeys)
              if ((snapshot[key] ?? '').isNotEmpty) snapshot[key]!,
          ],
          cardReadings.map((r) => r.displayTime),
          reason: 'widget and card show different times at ${hour}:00',
        );
      }
    });
  });
}
