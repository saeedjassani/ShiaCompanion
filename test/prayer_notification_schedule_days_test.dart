import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';

/// [iosPrayerNotificationScheduleDays] is the pure arithmetic behind
/// [prayerNotificationScheduleDays]'s iOS branch — split out because
/// `Platform.isIOS` can't be faked in a test run on a non-iOS host, so this
/// is the only way to actually exercise that arithmetic in CI.
void main() {
  test('defaults to 12 days when nothing is reserved', () {
    expect(iosPrayerNotificationScheduleDays(3), 12);
    expect(iosPrayerNotificationScheduleDays(5), 12);
  });

  test('falls back to the default with no prayers enabled', () {
    expect(iosPrayerNotificationScheduleDays(0), 12);
  });

  test('shrinks below the default once 63 notifications cannot fit 12 days',
      () {
    // 8 enabled "prayers" (7 salah times plus Midnight) * 12 days = 96,
    // which is well past 63.
    expect(iosPrayerNotificationScheduleDays(8), 7); // 63 ~/ 8 == 7
  });

  test('a reservation for zikr reminders shrinks the window further', () {
    expect(
      iosPrayerNotificationScheduleDays(5, reservedForOtherNotifications: 16),
      9, // (63 - 16) ~/ 5 == 9, vs 12 with nothing reserved
    );
    expect(
      iosPrayerNotificationScheduleDays(8, reservedForOtherNotifications: 16),
      5, // (63 - 16) ~/ 8 == 5, vs 7 with nothing reserved
    );
  });

  test('never drops Azan below one scheduled day, however large the reservation',
      () {
    expect(
      iosPrayerNotificationScheduleDays(8, reservedForOtherNotifications: 1000),
      1,
    );
    expect(
      iosPrayerNotificationScheduleDays(1, reservedForOtherNotifications: 1000),
      1,
    );
  });

  test('a reservation smaller than the existing slack changes nothing', () {
    // 3 prayers already caps at the 12-day default with the full 63-id
    // budget (63 ~/ 3 == 21, clamped to 12), so giving up a modest slice
    // must not shrink it below that default.
    expect(
      iosPrayerNotificationScheduleDays(3, reservedForOtherNotifications: 16),
      12,
    );
  });
}
