import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/models/activity_stats.dart';
import 'package:shia_companion/services/activity_stats_store.dart';
import 'package:shia_companion/services/community_stats_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

class _FakeRemote implements ActivityStatsRemote {
  String? userId;
  Map<String, DeviceActivity>? stored;
  int fetches = 0;
  int pushes = 0;
  bool failPush = false;

  @override
  String? get currentUserId => userId;

  @override
  Future<Map<String, DeviceActivity>?> fetch(String userId) async {
    fetches++;
    return stored == null ? null : Map.of(stored!);
  }

  @override
  Future<void> push(
      String userId, String deviceId, DeviceActivity activity) async {
    if (failPush) throw Exception('offline');
    pushes++;
    stored = {...?stored, deviceId: activity};
  }

  @override
  Future<void> delete(String userId) async => stored = null;
}

void main() {
  final day1 = DateTime(2026, 9, 20, 9);

  group('DeviceActivity', () {
    test('records zikrs and qaza per local day', () {
      final activity = const DeviceActivity()
          .recordZikr('E1', day1)
          .recordZikr('E1', day1)
          .recordZikr('G3', day1)
          .recordQaza(day1);

      expect(activity.days['2026-09-20'], const DayActivity(zikrs: 3, qaza: 1));
      expect(activity.zikrCounts, {'E1': 2, 'G3': 1});
    });

    test('an undo never takes a day below zero and drops an emptied day', () {
      final activity = const DeviceActivity()
          .recordQaza(day1)
          .recordQaza(day1, delta: -1)
          .recordQaza(day1, delta: -1);
      expect(activity.days, isEmpty);
    });

    test('survives a JSON round trip', () {
      final activity = const DeviceActivity()
          .recordZikr('E1', day1)
          .recordQaza(day1.add(const Duration(days: 1)));
      expect(DeviceActivity.fromJson(activity.toJson()), activity);
    });

    test('folds days past retention into the archive', () {
      final old = const DeviceActivity().recordZikr('E1', day1);
      final later = old.pruned(
        day1.add(const Duration(days: activityRetentionDays + 5)),
      );
      expect(later.days, isEmpty);
      expect(later.archived.zikrs, 1);
      expect(later.archivedActiveDays, 1);
      expect(later.zikrCounts, {'E1': 1});
    });

    test('merging two copies of the same device never double counts', () {
      final a = const DeviceActivity().recordZikr('E1', day1);
      final b = a.recordZikr('E1', day1);
      expect(a.merge(b), b);
      expect(b.merge(a), b);
    });

    test('rejects malformed day keys', () {
      final parsed = DeviceActivity.fromJson({
        'days': {
          '2026-02-31': {'z': 1},
          'nonsense': {'z': 1},
          '2026-09-20': {'z': 2},
        },
      });
      expect(parsed.days.keys, ['2026-09-20']);
    });
  });

  group('ActivitySummary', () {
    DeviceActivity activeOn(List<DateTime> days) => days.fold(
          const DeviceActivity(),
          (activity, day) => activity.recordZikr('E1', day),
        );

    test('sums devices, and counts a day active on either', () {
      final phone = activeOn([day1]);
      final tablet = activeOn([day1, day1.add(const Duration(days: 1))]);
      final summary = ActivitySummary(
        devices: [phone, tablet],
        now: day1.add(const Duration(days: 1)),
      );
      expect(summary.totalZikrs, 3);
      expect(summary.zikrCounts['E1'], 3);
      expect(summary.currentStreak, 2);
      expect(summary.activeDayCount, 2);
    });

    test('a streak survives until the end of the next day', () {
      final activity = activeOn([day1, day1.add(const Duration(days: 1))]);
      final nextMorning = day1.add(const Duration(days: 2));
      expect(
        ActivitySummary(devices: [activity], now: nextMorning).currentStreak,
        2,
      );
      expect(
        ActivitySummary(
          devices: [activity],
          now: nextMorning.add(const Duration(days: 1)),
        ).currentStreak,
        0,
      );
    });

    test('Quran recitation days count toward the streak', () {
      final activity = activeOn([day1]);
      final summary = ActivitySummary(
        devices: [activity],
        quranVersesByDay: {DateTime(2026, 9, 21): 12},
        quranVersesTotal: 12,
        now: DateTime(2026, 9, 21, 20),
      );
      expect(summary.currentStreak, 2);
      expect(summary.longestStreak, 2);
      expect(summary.scoreOn(DateTime(2026, 9, 21)), 2);
    });

    test('streaks cross a DST change', () {
      // Europe/US DST ends in late October / early November; calendar-day
      // arithmetic must not skip or repeat a day either way.
      final days = [
        for (var i = 0; i < 10; i++) DateTime(2026, 10, 28 + i, 12),
      ];
      final summary = ActivitySummary(
        devices: [activeOn(days)],
        now: days.last,
      );
      expect(summary.currentStreak, 10);
      expect(summary.longestStreak, 10);
    });

    test('keeps the best streak a device remembers after it ages out', () {
      final summary = ActivitySummary(
        devices: [const DeviceActivity(bestStreak: 40)],
        now: day1,
      );
      expect(summary.longestStreak, 40);
    });
  });

  group('ActivityStatsStore', () {
    late _FakeRemote remote;
    late DateTime now;
    late ActivityStatsStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SP.init();
      remote = _FakeRemote();
      now = day1;
      store = ActivityStatsStore(remote: remote, clock: () => now);
    });

    test('works signed out, with no network at all', () async {
      await store.recordZikrCompleted('X|E1');
      await store.pullAndMerge();
      await store.pushIfDue();
      expect(store.summary().zikrCounts, {'E1': 1});
      expect(remote.fetches, 0);
      expect(remote.pushes, 0);
    });

    test('persists locally across restarts', () async {
      await store.recordZikrCompleted('E1');
      await store.recordQazaCompleted();
      final restarted = ActivityStatsStore(remote: remote, clock: () => now);
      expect(restarted.summary().totalZikrs, 1);
      expect(restarted.summary().totalQaza, 1);
    });

    test('first sign-in seeds the account with one write', () async {
      await store.recordZikrCompleted('E1');
      remote.userId = 'u1';
      await store.pullAndMerge();
      expect(remote.fetches, 1);
      expect(remote.pushes, 1);
      expect(remote.stored![store.deviceId], store.own);
    });

    test('remembers the longest streak on the device', () async {
      for (var i = 0; i < 3; i++) {
        now = DateTime(2026, 9, 20 + i, 9);
        await store.recordZikrCompleted('E1');
      }
      expect(store.own.bestStreak, 3);
    });

    test('a pull with nothing new writes nothing', () async {
      remote.userId = 'u1';
      await store.recordZikrCompleted('E1');
      await store.pullAndMerge();
      await store.pullAndMerge();
      expect(remote.pushes, 1);
    });

    test('pushes are throttled to one per interval', () async {
      remote.userId = 'u1';
      await store.recordZikrCompleted('E1');
      await store.pullAndMerge();
      expect(remote.pushes, 1);

      await store.recordZikrCompleted('E1');
      await store.pushIfDue();
      expect(remote.pushes, 1, reason: 'too soon after the last push');

      now = now.add(ActivityStatsStore.minPushInterval);
      await store.pushIfDue();
      expect(remote.pushes, 2);
      await store.pushIfDue();
      expect(remote.pushes, 2, reason: 'nothing changed since');
    });

    test('a failed push stays pending', () async {
      remote.userId = 'u1';
      remote.failPush = true;
      await store.recordZikrCompleted('E1');
      await store.pullAndMerge();
      expect(remote.pushes, 0);
      remote.failPush = false;
      await store.pushIfDue();
      expect(remote.pushes, 1);
    });

    test('combines other devices and restores this one after a reinstall',
        () async {
      remote.userId = 'u1';
      final deviceId = store.deviceId;
      remote.stored = {
        deviceId: const DeviceActivity().recordZikr('E1', day1),
        'tablet': const DeviceActivity().recordZikr('G3', day1),
      };
      await store.pullAndMerge();
      final summary = store.summary();
      expect(summary.zikrCounts, {'E1': 1, 'G3': 1});
      expect(store.own.zikrCounts, {'E1': 1});
      expect(remote.pushes, 0, reason: 'the account already had it all');
    });

    test('signing out drops the account’s other devices', () async {
      remote.userId = 'u1';
      remote.stored = {
        'tablet': const DeviceActivity().recordZikr('G3', day1),
      };
      await store.pullAndMerge();
      expect(store.otherDevices, isNotEmpty);
      remote.userId = null;
      await store.pullAndMerge();
      expect(store.otherDevices, isEmpty);
    });
  });

  group('CommunityStatsService', () {
    final published = {
      'v': 1,
      'updatedAt': day1.millisecondsSinceEpoch,
      'week': {'c': 1200, 'o': 5000},
      'allTime': {'c': 90000, 'o': 400000},
      'days': [
        {'d': '2026-09-19', 'c': 150, 'o': 700},
        {'d': '2026-09-20', 'c': 180, 'o': 800},
      ],
      'top': [
        {'uid': 'E1', 'title': 'Dua Kumayl', 'c': 300},
      ],
    };

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SP.init();
    });

    test('parses the published summary', () async {
      final service = CommunityStatsService(fetch: () async => published);
      final stats = await service.load();
      expect(stats!.weekCompletions, 1200);
      expect(stats.allTimeCompletions, 90000);
      expect(stats.days, hasLength(2));
      expect(stats.top.single.title, 'Dua Kumayl');
    });

    test('fetches at most once per refresh interval', () async {
      var fetches = 0;
      var now = day1;
      final service = CommunityStatsService(
        fetch: () async {
          fetches++;
          return published;
        },
        clock: () => now,
      );
      await service.load();
      await service.load();
      expect(fetches, 1);
      expect(service.cached?.weekCompletions, 1200);
      now = now.add(CommunityStatsService.refreshInterval);
      await service.load();
      expect(fetches, 2);
    });

    test('falls back to the cache when offline, and hides when unpublished',
        () async {
      var online = true;
      var now = day1;
      final service = CommunityStatsService(
        fetch: () async {
          if (!online) throw Exception('offline');
          return published;
        },
        clock: () => now,
      );
      await service.load();
      online = false;
      now = now.add(const Duration(days: 1));
      expect((await service.load())?.weekCompletions, 1200);

      SharedPreferences.setMockInitialValues({});
      await SP.init();
      final unpublished = CommunityStatsService(fetch: () async => null);
      expect(await unpublished.load(), isNull);
    });
  });
}
