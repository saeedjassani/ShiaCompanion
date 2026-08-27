import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/admin/usage_dashboard_page.dart';
import 'package:shia_companion/services/analytics_service.dart';

import 'ui/firebase_test_doubles.dart';

void main() {
  group('AnalyticsService.feature account_deleted', () {
    // The dashboard's "Delete Account Page" screen count only tracks the
    // page being opened — Google Play's public /delete-account link gets
    // visited by bots and the curious, not just people who actually delete.
    // A real deletion additionally logs this feature event, which lands
    // under "Features used" instead.
    setUpAll(() async {
      await setUpFirebaseForRenderTests();
    });

    test(
        'the key delete_account_page.dart tracks matches what '
        'database.rules.json accepts for the feature metric bucket', () {
      const key = 'account_deleted';
      expect(AnalyticsService.safeKey(key), key);
      expect(RegExp(r'^[A-Za-z0-9_~-]{1,60}$').hasMatch(key), isTrue);
    });

    test('completes without throwing once an account is actually deleted',
        () async {
      await expectLater(
        AnalyticsService.feature('account_deleted', label: 'Account deleted'),
        completes,
      );
    });
  });

  group('AnalyticsService.safeKey', () {
    test('leaves a zikr uid untouched, case and tilde included', () {
      expect(AnalyticsService.safeKey('L4~2'), 'L4~2');
      expect(AnalyticsService.safeKey('G1'), 'G1');
    });

    test('replaces characters the database rejects in a key', () {
      expect(
        AnalyticsService.safeKey('https://youtube.com/watch?v=abc'),
        'https-youtube-com-watch-v-abc',
      );
      expect(AnalyticsService.safeKey('Rakaat Counter Page'),
          'Rakaat-Counter-Page');
    });

    test('collapses runs of separators and trims the edges', () {
      expect(AnalyticsService.safeKey('  a...b  '), 'a-b');
      expect(AnalyticsService.safeKey('///lead///'), 'lead');
    });

    test('caps the length so a key cannot grow without bound', () {
      final key = AnalyticsService.safeKey('a' * 200);
      expect(key, isNotNull);
      expect(key!.length, 60);
    });

    test('returns null when nothing usable survives', () {
      expect(AnalyticsService.safeKey('...'), isNull);
      expect(AnalyticsService.safeKey('   '), isNull);
    });
  });

  group('parseUsageTotals', () {
    test('reads counts stored as int, as they arrive on Android/iOS', () {
      final counts = parseUsageTotals({
        'screen': {'Home-Page': 12},
      });
      expect(counts['screen']?['Home-Page'], 12);
    });

    test('reads counts stored as double, as they arrive on web', () {
      // JS has no integer type, so the web plugin's JS-interop conversion
      // hands every RTDB number back as a double. A dashboard that only
      // recognised `int` would silently drop every row here.
      final counts = parseUsageTotals({
        'screen': {'Home-Page': 12.0},
      });
      expect(counts['screen']?['Home-Page'], 12);
    });

    test('ignores a value that is neither, without throwing', () {
      final counts = parseUsageTotals({
        'screen': {'Home-Page': 'not a count'},
      });
      expect(counts['screen']?['Home-Page'], isNull);
    });

    test('returns an empty map for a null or malformed snapshot', () {
      expect(parseUsageTotals(null), isEmpty);
      expect(parseUsageTotals('not a map'), isEmpty);
    });
  });

  group('parseUsageDays', () {
    test('sums double counts into both the metric bucket and the trend', () {
      final result = parseUsageDays({
        '2026-08-23': {
          'screen': {'Home-Page': 3.0},
        },
        '2026-08-24': {
          'screen': {'Home-Page': 5.0},
        },
      }, ['2026-08-23', '2026-08-24']);

      expect(result.counts['screen']?['Home-Page'], 8);
      expect(result.trend['2026-08-23'], 3);
      expect(result.trend['2026-08-24'], 5);
    });

    test('drops a day outside the requested range', () {
      final result = parseUsageDays({
        '2026-01-01': {
          'screen': {'Home-Page': 99.0},
        },
      }, ['2026-08-23']);

      expect(result.counts, isEmpty);
      expect(result.trend['2026-08-23'], 0);
    });
  });

  group('splitZikrCompletions', () {
    test('folds a completion count into the zikr it belongs to', () {
      final rows = splitZikrCompletions(const [
        UsageRow(key: 'G1', label: 'Dua Kumayl', count: 40),
        UsageRow(key: 'G1~done', label: 'Dua Kumayl (completed)', count: 12),
      ]);

      expect(rows.length, 1);
      expect(rows.single.key, 'G1');
      expect(rows.single.count, 40);
      expect(rows.single.label, contains('Dua Kumayl'));
      expect(rows.single.label, contains('12 finished'));
    });

    test('leaves a zikr nobody finished with a plain label', () {
      final rows = splitZikrCompletions(const [
        UsageRow(key: 'G2', label: 'Ziyarat Ashura', count: 9),
      ]);

      expect(rows.single.label, 'Ziyarat Ashura');
    });

    test('never lets a completion row compete for a place in the ranking', () {
      final rows = splitZikrCompletions(const [
        UsageRow(key: 'G1~done', label: 'Dua Kumayl (completed)', count: 99),
        UsageRow(key: 'G2', label: 'Ziyarat Ashura', count: 5),
      ]);

      expect(rows.map((row) => row.key), ['G2']);
    });
  });
}
