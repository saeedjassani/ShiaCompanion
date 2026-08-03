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

  test('the prayer times widget shows the saved selection, in order', () async {
    await saveWidgetPrayerTimes(
      ['maghrib', 'fajr', 'sunset', 'sunrise', 'zuhr', 'asr'],
    );

    final snapshot = HomeScreenWidgetService.instance
        .buildDailyPrayerTimesSnapshot(now: DateTime(2024, 6, 16));

    expect(
      namesFrom(snapshot),
      ['Fajr', 'Sunrise', 'Zuhr', 'Asr', 'Sunset', 'Maghrib'],
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
      namesFrom(snapshot),
      ['Fajr', 'Zuhr', 'Asr', 'Maghrib', 'Isha'],
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
}
