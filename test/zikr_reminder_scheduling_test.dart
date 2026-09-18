import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/zikr_reminder_scheduling.dart';

void main() {
  group('zikrReminderNotificationId', () {
    test('is stable and distinct per weekday/occurrence within a reminder', () {
      final tuesdayFirst = zikrReminderNotificationId(
        baseId: 40000,
        weekday: DateTime.tuesday,
        occurrenceIndex: 0,
      );
      final tuesdaySecond = zikrReminderNotificationId(
        baseId: 40000,
        weekday: DateTime.tuesday,
        occurrenceIndex: 1,
      );
      final friday = zikrReminderNotificationId(
        baseId: 40000,
        weekday: DateTime.friday,
        occurrenceIndex: 0,
      );

      expect(tuesdayFirst, 40000 + 2 * 10);
      expect({tuesdayFirst, tuesdaySecond, friday}, hasLength(3));
    });

    test('never collides between two reminders across the reserved id block',
        () {
      // 7 days * up to 10 occurrence slots = 70, which must stay under the
      // per-reminder id block so two reminders' ids never overlap.
      final idsForOneReminder = <int>{
        for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
          for (var occurrence = 0; occurrence < 10; occurrence++)
            zikrReminderNotificationId(
              baseId: 40000,
              weekday: weekday,
              occurrenceIndex: occurrence,
            ),
      };
      expect(idsForOneReminder.every((id) => id < 40100), isTrue);
      expect(idsForOneReminder.every((id) => id >= 40000), isTrue);
    });
  });

  group('nextInstanceOfWeekdayAndTime', () {
    test('returns later today when that time has not passed yet', () {
      final now = DateTime(2024, 6, 18, 10, 0); // a Tuesday
      final scheduled =
          nextInstanceOfWeekdayAndTime(now, DateTime.tuesday, 21, 0);

      expect(scheduled, DateTime(2024, 6, 18, 21, 0));
    });

    test('rolls to next week when today\'s time has already passed', () {
      final now = DateTime(2024, 6, 18, 22, 0); // Tuesday, past 9pm
      final scheduled =
          nextInstanceOfWeekdayAndTime(now, DateTime.tuesday, 21, 0);

      expect(scheduled, DateTime(2024, 6, 25, 21, 0));
    });

    test('finds the correct day when it is not today', () {
      final now = DateTime(2024, 6, 18, 10, 0); // Tuesday
      final scheduled =
          nextInstanceOfWeekdayAndTime(now, DateTime.friday, 20, 30);

      expect(scheduled, DateTime(2024, 6, 21, 20, 30));
      expect(scheduled.weekday, DateTime.friday);
    });
  });

  group('upcomingPrayerRelativeOccurrences', () {
    test('returns the requested count, all on the target weekday and after now',
        () {
      final prayerTime = getPrayerTimeObject();
      final now = DateTime(2024, 6, 18, 10, 0); // Tuesday

      final occurrences = upcomingPrayerRelativeOccurrences(
        prayerTime: prayerTime,
        now: now,
        weekday: DateTime.thursday,
        prayerName: 'Maghrib',
        offsetMinutes: 30,
        latitude: 21.4225,
        longitude: 39.8262,
        count: 4,
      );

      expect(occurrences, hasLength(4));
      for (final occurrence in occurrences) {
        expect(occurrence.weekday, DateTime.thursday);
        expect(occurrence.isAfter(now), isTrue);
      }
      // Successive occurrences should be roughly a week apart.
      for (var index = 1; index < occurrences.length; index++) {
        final gap = occurrences[index].difference(occurrences[index - 1]);
        expect(gap.inDays, inInclusiveRange(6, 8));
      }
    });

    test('applies a negative offset to fire before the prayer', () {
      final prayerTime = getPrayerTimeObject();
      final now = DateTime(2024, 6, 18, 10, 0);

      final withOffset = upcomingPrayerRelativeOccurrences(
        prayerTime: prayerTime,
        now: now,
        weekday: DateTime.thursday,
        prayerName: 'Fajr',
        offsetMinutes: -15,
        latitude: 21.4225,
        longitude: 39.8262,
        count: 1,
      );
      final atPrayerTime = upcomingPrayerRelativeOccurrences(
        prayerTime: prayerTime,
        now: now,
        weekday: DateTime.thursday,
        prayerName: 'Fajr',
        offsetMinutes: 0,
        latitude: 21.4225,
        longitude: 39.8262,
        count: 1,
      );

      expect(withOffset, hasLength(1));
      expect(atPrayerTime, hasLength(1));
      expect(
        atPrayerTime.single.difference(withOffset.single).inMinutes,
        15,
      );
    });
  });
}
