import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/zikr_reminder.dart';

void main() {
  test('toJson/fromJson round-trips a fixed-time reminder', () {
    final reminder = ZikrReminder(
      id: 'abc123',
      notificationBaseId: 40000,
      title: 'Dua Tawassul',
      zikrUid: 'Z10',
      daysOfWeek: const {DateTime.tuesday},
      mode: ZikrReminderTimeMode.fixedTime,
      hour: 21,
      minute: 30,
    );

    final decoded = ZikrReminder.fromJson(reminder.toJson());

    expect(decoded, isNotNull);
    expect(decoded!.id, 'abc123');
    expect(decoded.notificationBaseId, 40000);
    expect(decoded.title, 'Dua Tawassul');
    expect(decoded.zikrUid, 'Z10');
    expect(decoded.daysOfWeek, {DateTime.tuesday});
    expect(decoded.mode, ZikrReminderTimeMode.fixedTime);
    expect(decoded.hour, 21);
    expect(decoded.minute, 30);
    expect(decoded.enabled, isTrue);
  });

  test('toJson/fromJson round-trips a prayer-relative reminder', () {
    final reminder = ZikrReminder(
      id: 'xyz789',
      notificationBaseId: 40100,
      title: 'Dua Kumail',
      daysOfWeek: const {DateTime.thursday},
      mode: ZikrReminderTimeMode.relativeToPrayer,
      prayerName: 'Maghrib',
      offsetMinutes: 30,
      enabled: false,
    );

    final decoded = ZikrReminder.fromJson(reminder.toJson());

    expect(decoded, isNotNull);
    expect(decoded!.mode, ZikrReminderTimeMode.relativeToPrayer);
    expect(decoded.prayerName, 'Maghrib');
    expect(decoded.offsetMinutes, 30);
    expect(decoded.zikrUid, isNull);
    expect(decoded.enabled, isFalse);
  });

  test('fromJson tolerates malformed entries by returning null', () {
    expect(ZikrReminder.fromJson(const {}), isNull);
    expect(ZikrReminder.fromJson(const {'id': 'a'}), isNull);
    expect(
      ZikrReminder.fromJson(const {
        'id': 'a',
        'title': 'Test',
        'notificationBaseId': 'not-an-int',
      }),
      isNull,
    );
  });

  test('listFrom rejects unparsable input entirely', () {
    expect(ZikrReminder.listFrom('not json'), isEmpty);
    expect(ZikrReminder.listFrom(null), isEmpty);
    expect(ZikrReminder.listFrom(''), isEmpty);
  });

  test('listFrom keeps valid entries and drops malformed ones from a mixed list', () {
    final reminder = ZikrReminder(
      id: 'a',
      notificationBaseId: 40000,
      title: 'Valid',
      daysOfWeek: const {DateTime.monday},
      mode: ZikrReminderTimeMode.fixedTime,
    );
    final mixed = jsonEncode([
      reminder.toJson(),
      {'id': 'bad'}, // missing title/notificationBaseId
      'not even a map',
    ]);

    final decoded = ZikrReminder.listFrom(mixed);

    expect(decoded, hasLength(1));
    expect(decoded.single.id, 'a');
  });

  test('fromJson defaults an unknown mode string to fixedTime', () {
    final decoded = ZikrReminder.fromJson({
      'id': 'a',
      'title': 'Test',
      'notificationBaseId': 1,
      'mode': 'not-a-real-mode',
      'daysOfWeek': [1, 8, 'x', 3],
    });

    expect(decoded, isNotNull);
    expect(decoded!.mode, ZikrReminderTimeMode.fixedTime);
    // 8 and 'x' are out of range / unparsable and must be dropped.
    expect(decoded.daysOfWeek, {DateTime.monday, DateTime.wednesday});
  });

  group('timeLabel', () {
    test('formats a fixed time as 12-hour with AM/PM', () {
      final reminder = ZikrReminder(
        id: 'a',
        notificationBaseId: 1,
        title: 'T',
        daysOfWeek: const {DateTime.monday},
        mode: ZikrReminderTimeMode.fixedTime,
        hour: 21,
        minute: 5,
      );
      expect(reminder.timeLabel, '9:05 PM');

      final midnight = reminder.copyWith(hour: 0, minute: 0);
      expect(midnight.timeLabel, '12:00 AM');

      final noon = reminder.copyWith(hour: 12, minute: 0);
      expect(noon.timeLabel, '12:00 PM');
    });

    test('formats a prayer-relative offset', () {
      final after = ZikrReminder(
        id: 'a',
        notificationBaseId: 1,
        title: 'T',
        daysOfWeek: const {DateTime.thursday},
        mode: ZikrReminderTimeMode.relativeToPrayer,
        prayerName: 'Maghrib',
        offsetMinutes: 30,
      );
      expect(after.timeLabel, '30 min after Maghrib');

      final before = after.copyWith(offsetMinutes: -15);
      expect(before.timeLabel, '15 min before Maghrib');

      final exact = after.copyWith(offsetMinutes: 0);
      expect(exact.timeLabel, 'At Maghrib');
    });
  });

  test('daysLabel lists selected days Monday-first regardless of insertion order', () {
    final reminder = ZikrReminder(
      id: 'a',
      notificationBaseId: 1,
      title: 'T',
      daysOfWeek: const {DateTime.friday, DateTime.tuesday},
      mode: ZikrReminderTimeMode.fixedTime,
    );
    expect(reminder.daysLabel, 'Tue, Fri');
  });

  test('copyWith can clear the linked zikr', () {
    final reminder = ZikrReminder(
      id: 'a',
      notificationBaseId: 1,
      title: 'T',
      zikrUid: 'Z1',
      daysOfWeek: const {DateTime.monday},
      mode: ZikrReminderTimeMode.fixedTime,
    );
    final cleared = reminder.copyWith(clearZikrUid: true);
    expect(cleared.zikrUid, isNull);
  });
}
