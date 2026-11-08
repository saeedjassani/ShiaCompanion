import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/services/event_notification_service.dart';
import 'package:shia_companion/utils/event_notification_planning.dart';
import 'package:shia_companion/utils/hijri_date.dart';

void main() {
  final events = (json.decode(File('assets/events.json').readAsStringSync())
          as Map<String, dynamic>)
      .cast<String, dynamic>();

  setUp(() => useHijriMonthStarts(const {}));

  /// The civil date of a Hijri date, on Umm al-Qura.
  DateTime civil(int year, int month, int day) {
    final date = HijriCalendar().hijriToGregorian(year, month, day);
    return DateTime(date.year, date.month, date.day);
  }

  List<PlannedEventNotification> plan({
    required DateTime now,
    Set<EventNotificationKind>? kinds,
    bool dayBefore = false,
    int hour = 9,
    int budget = 1000,
  }) =>
      planEventNotifications(
        now: now,
        events: events,
        offsetDays: 0,
        kinds: kinds ?? EventNotificationKind.values.toSet(),
        dayBefore: dayBefore,
        hour: hour,
        minute: 0,
        budget: budget,
      );

  String key(PlannedEventNotification p) =>
      '${p.hijriMonth.toString().padLeft(2, '0')}-'
      '${p.hijriDay.toString().padLeft(2, '0')}';

  test('with room for all, plans every event of the coming year once', () {
    final now = civil(1448, 1, 1).add(const Duration(hours: 6));
    final all = plan(now: now);

    expect(all.map(key).toSet(), events.keys.toSet());
    expect(all, hasLength(events.length));
    for (var i = 1; i < all.length; i++) {
      expect(all[i].fireAt.isAfter(all[i - 1].fireAt), isTrue);
    }
    expect(all.first.fireAt, DateTime(now.year, now.month, now.day, 9));
  });

  test('leaves out an event whose time has passed', () {
    final morning = civil(1448, 1, 10).add(const Duration(hours: 8));
    expect(key(plan(now: morning).first), '01-10');

    final afternoon = morning.add(const Duration(hours: 6));
    expect(key(plan(now: afternoon).first), '01-11');
  });

  test('the day before goes off the evening before', () {
    final now = civil(1448, 1, 1).add(const Duration(hours: 6));
    final ashura = plan(now: now, dayBefore: true, hour: 20)
        .firstWhere((p) => key(p) == '01-10');
    final eve = civil(1448, 1, 9);

    expect(ashura.eventDate, civil(1448, 1, 10));
    expect(ashura.fireAt, DateTime(eve.year, eve.month, eve.day, 20));
  });

  test('keeps only the kinds asked for', () {
    final now = civil(1448, 1, 1).add(const Duration(hours: 6));
    final joyful = plan(now: now, kinds: {EventNotificationKind.celebration});

    expect(joyful, isNotEmpty);
    for (final p in joyful) {
      expect(p.event['color'], 1, reason: key(p));
    }
    expect(plan(now: now, kinds: const {}), isEmpty);
  });

  group('on a tight budget', () {
    // 1 Rajab: fifteen events in Rajab and seven in Sha'ban, so the next
    // eight events alone would all be over before Ramazan.
    final now = civil(1448, 7, 1).add(const Duration(hours: 6));
    final tight = plan(now: now, budget: 8);

    test('keeps to the budget, soonest first', () {
      expect(tight, hasLength(8));
      for (var i = 1; i < tight.length; i++) {
        expect(tight[i].fireAt.isAfter(tight[i - 1].fireAt), isTrue);
      }
    });

    test('always keeps what is next', () {
      final next = plan(now: now).take(eventNotificationSoonestKept);
      expect(tight.take(eventNotificationSoonestKept).map(key),
          next.map(key).toList());
    });

    test('reaches one event into each month ahead, not just the busy ones', () {
      final naive = plan(now: now).take(8).map((p) => p.hijriMonth).toSet();
      expect(naive, {7}, reason: 'the next eight are all in Rajab');

      // Rajab (twice, as the soonest two), then one each for Sha'ban to
      // Muharram.
      expect(
          tight.map((p) => p.hijriMonth).toList(), [7, 7, 8, 9, 10, 11, 12, 1]);
    });

    test("picks a month's major day over its first one", () {
      final shaban = tight.singleWhere((p) => p.hijriMonth == 8);
      // 1 Sha'ban (Lady Zainab) comes first; 3 Sha'ban, Imam Husayn's birth,
      // is the one to keep.
      expect(key(shaban), '08-03');
      final ramazan = tight.singleWhere((p) => p.hijriMonth == 9);
      expect(key(ramazan), '09-01');
    });

    test('a quiet month is still heard from', () {
      final fromRabiAwwal = civil(1448, 3, 20).add(const Duration(hours: 6));
      final months =
          plan(now: fromRabiAwwal, budget: 6).map((p) => p.hijriMonth).toList();
      // Rabi' al-Thani has two events, Jumada al-Awwal five.
      expect(months, containsAllInOrder([4, 5, 6, 7]));
    });

    test("tells next year's month apart from this one's", () {
      // From 20 Rajab the horizon reaches into next Rajab: that month is
      // owed its own event, not counted as heard from.
      final lateRajab = civil(1448, 7, 20).add(const Duration(hours: 6));
      final months =
          plan(now: lateRajab, budget: 14).map((p) => p.monthIndex).toSet();
      expect(months, contains(1449 * 12 + 7));
    });
  });

  test('a notification payload gives back its event date', () {
    expect(
      EventNotificationService.eventDateOfPayload(
          '${EventNotificationService.payloadPrefix}2026-12-08'),
      DateTime(2026, 12, 8),
    );
    expect(
        EventNotificationService.eventDateOfPayload('zikr_reminder:1'), isNull);
    expect(EventNotificationService.eventDateOfPayload(null), isNull);
  });
}
