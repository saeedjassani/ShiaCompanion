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

  group('new feature_use keys match what database.rules.json accepts', () {
    const newKeys = [
      'account_signed_in',
      'library_shared',
      'zikr_keep_awake_toggled',
      'zikr_focus_mode_toggled',
      'zikr_share_as_image_toggled',
      'zikr_show_transliteration_toggled',
      'zikr_show_translation_toggled',
      // The combined key a home-widget tap actually lands under (see
      // AnalyticsService.zikrView) — the raw ZikrOpenSource ids never pass
      // through safeKey / the rules on their own.
      'zikr_source_${ZikrOpenSource.homeWidgetFavorites}',
      'zikr_source_${ZikrOpenSource.homeWidgetRecitation}',
    ];

    for (final key in newKeys) {
      test(key, () {
        expect(AnalyticsService.safeKey(key), key);
        expect(RegExp(r'^[A-Za-z0-9_~-]{1,60}$').hasMatch(key), isTrue);
      });
    }
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
      }, [
        '2026-08-23',
        '2026-08-24'
      ]);

      expect(result.counts['screen']?['Home-Page'], 8);
      expect(result.trend['2026-08-23'], 3);
      expect(result.trend['2026-08-24'], 5);
    });

    test('drops a day outside the requested range', () {
      final result = parseUsageDays({
        '2026-01-01': {
          'screen': {'Home-Page': 99.0},
        },
      }, [
        '2026-08-23'
      ]);

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

  group('featureGroupFor', () {
    test('groups every feature_use key the app currently records', () {
      const expected = {
        // Zikr & library reading — the fixed keys, plus a sample of the
        // dynamic zikr_source_* and home_menu_* families below.
        'zikr_counter_shown': FeatureGroup.zikrReading,
        'zikr_audio_opened': FeatureGroup.zikrReading,
        'zikr_audio_play': FeatureGroup.zikrReading,
        'zikr_bookmark_saved': FeatureGroup.zikrReading,
        'zikr_bookmark_removed': FeatureGroup.zikrReading,
        'zikr_shared': FeatureGroup.zikrReading,
        'zikr_keep_awake_toggled': FeatureGroup.zikrReading,
        'zikr_focus_mode_toggled': FeatureGroup.zikrReading,
        'zikr_share_as_image_toggled': FeatureGroup.zikrReading,
        'zikr_show_transliteration_toggled': FeatureGroup.zikrReading,
        'zikr_show_translation_toggled': FeatureGroup.zikrReading,
        'arabic_font_size_changed': FeatureGroup.zikrReading,
        'english_font_size_changed': FeatureGroup.zikrReading,
        'arabic_font_changed': FeatureGroup.zikrReading,
        'library_shared': FeatureGroup.zikrReading,
        'zikr_source_search': FeatureGroup.zikrReading,
        'zikr_source_deep_link': FeatureGroup.zikrReading,
        'zikr_source_home_widget_favorites': FeatureGroup.zikrReading,
        'zikr_source_home_widget_recitation': FeatureGroup.zikrReading,
        // Navigation
        'home_menu_qibla': FeatureGroup.navigation,
        'home_menu_tasbeeh': FeatureGroup.navigation,
        // Prayer & azaan
        'azaan_selected': FeatureGroup.prayerAndAzaan,
        'azaan_notifications_toggled': FeatureGroup.prayerAndAzaan,
        'azaan_opt_in': FeatureGroup.prayerAndAzaan,
        'rakaat_prayer_completed': FeatureGroup.prayerAndAzaan,
        'prayer_times_selection_changed': FeatureGroup.prayerAndAzaan,
        // Account & tools
        'account_deleted': FeatureGroup.accountAndTools,
        'account_signed_in': FeatureGroup.accountAndTools,
        'favorite_added': FeatureGroup.accountAndTools,
        'flight_added': FeatureGroup.accountAndTools,
        'flight_edited': FeatureGroup.accountAndTools,
        'qaza_updated': FeatureGroup.accountAndTools,
        'tasbeeh_session': FeatureGroup.accountAndTools,
        // Search
        'search': FeatureGroup.search,
        'search_opened': FeatureGroup.search,
      };

      expected.forEach((key, group) {
        expect(featureGroupFor(key), group, reason: key);
      });
    });

    test('falls back to Other instead of dropping an unclassified key', () {
      // The safety net: a future feature() call nobody has sorted into a
      // group yet must still show up on the dashboard.
      expect(
        featureGroupFor('brand_new_feature_nobody_classified_yet'),
        FeatureGroup.other,
      );
    });
  });

  group('groupFeatureRows', () {
    test('keeps rank order within a group and omits empty groups', () {
      final rows = const [
        UsageRow(key: 'home_menu_qibla', label: 'Qibla', count: 50),
        UsageRow(key: 'search', label: 'Search', count: 40),
        UsageRow(key: 'home_menu_tasbeeh', label: 'Tasbeeh', count: 10),
      ];

      final grouped = groupFeatureRows(rows);

      expect(
        grouped[FeatureGroup.navigation]?.map((row) => row.key).toList(),
        ['home_menu_qibla', 'home_menu_tasbeeh'],
      );
      expect(grouped[FeatureGroup.search]?.map((row) => row.key).toList(),
          ['search']);
      expect(grouped.containsKey(FeatureGroup.prayerAndAzaan), isFalse);
    });
  });

  group('previousTotalsFrom', () {
    test('sums opens, drops completions, and counts distinct zikrs', () {
      final totals = previousTotalsFrom({
        'zikr': {'G1': 10, 'G1~done': 3, 'G2': 5},
        'feature': {'search': 4, 'zikr_shared': 2},
      });

      expect(totals.zikrOpens, 15);
      expect(totals.distinctZikrs, 2);
      expect(totals.featureUses, 6);
    });

    test('returns zeros for an empty counts map', () {
      final totals = previousTotalsFrom(const {});
      expect(totals.zikrOpens, 0);
      expect(totals.distinctZikrs, 0);
      expect(totals.featureUses, 0);
    });
  });

  group('periodDelta', () {
    test('reports a percentage increase', () {
      final delta = periodDelta(120, 100);
      expect(delta?.label, '+20%');
      expect(delta?.direction, DeltaDirection.up);
    });

    test('reports a percentage decrease', () {
      final delta = periodDelta(80, 100);
      expect(delta?.label, '-20%');
      expect(delta?.direction, DeltaDirection.down);
    });

    test('labels a previously-zero metric New instead of dividing by zero', () {
      final delta = periodDelta(5, 0);
      expect(delta?.label, 'New');
      expect(delta?.direction, DeltaDirection.isNew);
    });

    test('returns null when neither period has anything to report', () {
      expect(periodDelta(0, 0), isNull);
    });

    test('rounds a sub-percent change to flat rather than +0%/-0%', () {
      final delta = periodDelta(1001, 1000);
      expect(delta?.label, '±0%');
      expect(delta?.direction, DeltaDirection.flat);
    });
  });
}
