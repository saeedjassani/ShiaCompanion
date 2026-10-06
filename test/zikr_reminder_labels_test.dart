import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/l10n/l10n.dart';
import 'package:shia_companion/models/zikr_reminder.dart';
import 'package:shia_companion/utils/zikr_reminder_labels.dart';

void main() {
  final l10n = L10n.current;
  const sunday = 0;

  test('clockLabel drops the leading zero, as the prayer card does', () {
    expect(clockLabel(7, 0), '7:00 am');
    expect(clockLabel(21, 5), '9:05 pm');
    expect(clockLabel(0, 0), '12:00 am');
  });

  group('reminderDaysLabel', () {
    String days(Set<int> days, {bool long = false}) =>
        reminderDaysLabel(days, l10n, firstDayOfWeek: sunday, long: long);

    test('every day, one or two days by name, more as short names', () {
      expect(days({1, 2, 3, 4, 5, 6, 7}), 'Every day');
      expect(days({DateTime.thursday}), 'Thursdays');
      expect(days({DateTime.friday, DateTime.tuesday}), 'Tuesdays and Fridays');
      expect(days({DateTime.monday, DateTime.wednesday, DateTime.friday}),
          'Mon, Wed, Fri');
      expect(
        days({DateTime.monday, DateTime.wednesday, DateTime.friday},
            long: true),
        'Mondays, Wednesdays and Fridays',
      );
    });

    test('starts the week where the locale does', () {
      expect(days({DateTime.sunday, DateTime.saturday}),
          'Sundays and Saturdays');
      expect(
        reminderDaysLabel({DateTime.sunday, DateTime.saturday}, l10n,
            firstDayOfWeek: 1),
        'Saturdays and Sundays',
      );
    });
  });

  group('reminderSummary', () {
    late double? originalLat;
    late double? originalLong;
    setUp(() {
      originalLat = lat;
      originalLong = long;
    });
    tearDown(() {
      lat = originalLat;
      long = originalLong;
    });

    String summary({
      required ZikrReminderTimeMode mode,
      int offsetMinutes = 0,
    }) =>
        reminderSummary(
          days: {DateTime.thursday},
          mode: mode,
          hour: 21,
          minute: 0,
          prayerName: 'Maghrib',
          offsetMinutes: offsetMinutes,
          l10n: l10n,
          firstDayOfWeek: sunday,
        );

    test('a set time', () {
      expect(summary(mode: ZikrReminderTimeMode.fixedTime),
          'Thursdays, at 9:00 pm');
    });

    test('around a prayer, without a location to estimate from', () {
      lat = null;
      long = null;
      const around = ZikrReminderTimeMode.relativeToPrayer;
      expect(summary(mode: around, offsetMinutes: 15),
          'Thursdays, 15 minutes after Maghrib');
      expect(summary(mode: around, offsetMinutes: -1),
          'Thursdays, 1 minute before Maghrib');
      expect(summary(mode: around), 'Thursdays, at Maghrib');
    });

    test('around a prayer, with the time it will next fire', () {
      lat = 51.5;
      long = -0.12;
      expect(
        summary(
            mode: ZikrReminderTimeMode.relativeToPrayer, offsetMinutes: 15),
        matches(RegExp(r'^Thursdays, 15 minutes after Maghrib '
            r'\(about \d{1,2}:\d\d [ap]m this week\)$')),
      );
    });
  });
}
