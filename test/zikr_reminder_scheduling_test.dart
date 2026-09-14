import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/models/zikr_reminder.dart';
import 'package:shia_companion/utils/zikr_reminder_scheduling.dart';

ZikrReminder _fixed(int id, Set<int> days) => ZikrReminder(
      id: 'r$id',
      notificationBaseId: 40000 + id * 100,
      title: 'Reminder $id',
      daysOfWeek: days,
      mode: ZikrReminderTimeMode.fixedTime,
    );

ZikrReminder _relative(int id, Set<int> days, {bool enabled = true}) =>
    ZikrReminder(
      id: 'r$id',
      notificationBaseId: 40000 + id * 100,
      title: 'Reminder $id',
      daysOfWeek: days,
      mode: ZikrReminderTimeMode.relativeToPrayer,
      enabled: enabled,
    );

void main() {
  group('zikrReminderIdealNotificationDemand', () {
    test('is zero with no reminders', () {
      expect(zikrReminderIdealNotificationDemand(const []), 0);
    });

    test('counts one id per selected day for a fixed-time reminder', () {
      final reminders = [_fixed(1, {DateTime.tuesday, DateTime.friday})];
      expect(zikrReminderIdealNotificationDemand(reminders), 2);
    });

    test(
        'counts zikrReminderRelativeOccurrenceCount ids per selected day for a '
        'prayer-relative reminder', () {
      final reminders = [
        _relative(1, {DateTime.thursday}),
      ];
      expect(
        zikrReminderIdealNotificationDemand(reminders),
        zikrReminderRelativeOccurrenceCount,
      );
    });

    test('ignores disabled reminders and reminders with no selected days', () {
      final reminders = [
        _relative(1, {DateTime.thursday}, enabled: false),
        _fixed(2, {}),
      ];
      expect(zikrReminderIdealNotificationDemand(reminders), 0);
    });

    test('sums demand across several reminders', () {
      final reminders = [
        _fixed(1, {DateTime.tuesday}), // 1
        _relative(2, {DateTime.thursday, DateTime.friday}), // 2 * 5 = 10
      ];
      expect(
        zikrReminderIdealNotificationDemand(reminders),
        1 + 2 * zikrReminderRelativeOccurrenceCount,
      );
    });
  });

  group('zikrReminderRelativeOccurrenceCountFor', () {
    test('uses the full count when demand is well within budget', () {
      final reminders = [_relative(1, {DateTime.thursday})];
      expect(
        zikrReminderRelativeOccurrenceCountFor(
          reminders: reminders,
          budget: zikrReminderMaxIosNotificationBudget,
        ),
        zikrReminderRelativeOccurrenceCount,
      );
    });

    test('trims proportionally to fit a tight budget', () {
      // 4 reminder-days want the full 5 occurrences each (20 ideal); a
      // budget of 8 only fits 2 each.
      final reminders = [
        _relative(1, {DateTime.monday, DateTime.tuesday}),
        _relative(2, {DateTime.thursday, DateTime.friday}),
      ];
      expect(
        zikrReminderRelativeOccurrenceCountFor(reminders: reminders, budget: 8),
        2,
      );
    });

    test('never trims below 1, even under an impossibly tight budget', () {
      final reminders = [
        _relative(1, {DateTime.monday, DateTime.tuesday, DateTime.wednesday}),
      ];
      expect(
        zikrReminderRelativeOccurrenceCountFor(reminders: reminders, budget: 0),
        1,
      );
    });

    test('gives fixed-time reminders their full share before trimming the '
        'relative ones', () {
      final reminders = [
        _fixed(1, {DateTime.monday, DateTime.tuesday, DateTime.wednesday}),
        _relative(2, {DateTime.thursday}),
      ];
      // Budget 8: fixed-time claims 3 (always honoured in full), leaving 5
      // for the one relative reminder-day — its full uncapped count.
      expect(
        zikrReminderRelativeOccurrenceCountFor(reminders: reminders, budget: 8),
        5,
      );
    });

    test('is unaffected by fixed-time reminders when there are no '
        'prayer-relative ones', () {
      final reminders = [_fixed(1, {DateTime.monday})];
      expect(
        zikrReminderRelativeOccurrenceCountFor(reminders: reminders, budget: 0),
        zikrReminderRelativeOccurrenceCount,
      );
    });
  });

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
