import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/admin/usage_dashboard_page.dart';
import 'package:shia_companion/services/analytics_service.dart';

void main() {
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
