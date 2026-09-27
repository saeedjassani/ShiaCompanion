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
      'favorite_removed',
      'favorite_reordered',
      'library_offline_saved',
      'library_offline_removed',
      'qibla_target_changed',
      'dark_mode_toggled',
      'feedback_email_opened',
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

    test('also tracks each metric\'s own day-by-day trend', () {
      final result = parseUsageDays({
        '2026-08-23': {
          'screen': {'Home-Page': 3},
          'zikr': {'G1': 2},
        },
        '2026-08-24': {
          'screen': {'Home-Page': 5},
        },
      }, [
        '2026-08-23',
        '2026-08-24',
      ]);

      expect(result.metricTrend['screen'], {'2026-08-23': 3, '2026-08-24': 5});
      // zikr had no events on the 24th, so that day is still present as zero
      // rather than missing — every series shares the same day axis.
      expect(result.metricTrend['zikr'], {'2026-08-23': 2, '2026-08-24': 0});
      // A metric that never appears in the range gets no entry at all.
      expect(result.metricTrend.containsKey('feature'), isFalse);
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

  group('zikrPreviousByKey', () {
    test('drops completion counters and keeps only opens', () {
      final byKey = zikrPreviousByKey({
        'zikr': {'G1': 10, 'G1~done': 3, 'G2': 5},
      });

      expect(byKey, {'G1': 10, 'G2': 5});
    });

    test('returns an empty map when there is no previous zikr data', () {
      expect(zikrPreviousByKey(null), isEmpty);
      expect(zikrPreviousByKey(const {}), isEmpty);
      expect(
          zikrPreviousByKey(const {
            'screen': {'Home-Page': 4}
          }),
          isEmpty);
    });
  });

  group('groupPreviousTotals', () {
    test('sums the previous period\'s counts by feature group', () {
      final totals = groupPreviousTotals({
        'home_menu_qibla': 20,
        'home_menu_tasbeeh': 5,
        'search': 8,
      });

      // home_menu_* and search share findingContent — see featureGroupFor.
      expect(totals[FeatureGroup.findingContent], 33);
      expect(totals.containsKey(FeatureGroup.prayerAndWorship), isFalse);
    });

    test('returns an empty map when there is no previous period', () {
      expect(groupPreviousTotals(null), isEmpty);
    });
  });

  group('featureGroupFor', () {
    test('groups every feature_use key the app currently records', () {
      const expected = {
        // Reading the content — the fixed keys.
        'zikr_counter_shown': FeatureGroup.readingContent,
        'zikr_audio_opened': FeatureGroup.readingContent,
        'zikr_audio_play': FeatureGroup.readingContent,
        'zikr_bookmark_saved': FeatureGroup.readingContent,
        'zikr_bookmark_removed': FeatureGroup.readingContent,
        'zikr_bookmark_moved': FeatureGroup.readingContent,
        'zikr_shared': FeatureGroup.readingContent,
        'zikr_keep_awake_toggled': FeatureGroup.readingContent,
        'zikr_focus_mode_toggled': FeatureGroup.readingContent,
        'zikr_share_as_image_toggled': FeatureGroup.readingContent,
        'zikr_show_transliteration_toggled': FeatureGroup.readingContent,
        'zikr_show_translation_toggled': FeatureGroup.readingContent,
        'arabic_font_size_changed': FeatureGroup.readingContent,
        'english_font_size_changed': FeatureGroup.readingContent,
        'arabic_font_changed': FeatureGroup.readingContent,
        'library_shared': FeatureGroup.readingContent,
        'library_offline_saved': FeatureGroup.readingContent,
        'library_offline_removed': FeatureGroup.readingContent,
        'zikr_show_arabic_as_paragraph_toggled': FeatureGroup.readingContent,
        // Zikr reminders and the Quran recitation tracker — ongoing
        // engagement with content someone is already reading.
        'zikr_reminder_added': FeatureGroup.readingContent,
        'zikr_reminder_edited': FeatureGroup.readingContent,
        'zikr_reminder_deleted': FeatureGroup.readingContent,
        'zikr_reminder_entry_point_opened': FeatureGroup.readingContent,
        'quran_verse_saved': FeatureGroup.readingContent,
        'quran_verse_unsaved': FeatureGroup.readingContent,
        'recitation_tracker_updated': FeatureGroup.readingContent,
        // Finding content — home menu taps, search, and where a zikr open
        // came from (the dynamic zikr_source_* and home_menu_* families).
        'zikr_source_search': FeatureGroup.findingContent,
        'zikr_source_deep_link': FeatureGroup.findingContent,
        'zikr_source_home_widget_favorites': FeatureGroup.findingContent,
        'zikr_source_home_widget_recitation': FeatureGroup.findingContent,
        'home_menu_qibla': FeatureGroup.findingContent,
        'home_menu_tasbeeh': FeatureGroup.findingContent,
        'search': FeatureGroup.findingContent,
        'search_opened': FeatureGroup.findingContent,
        // Prayer & worship tools
        'azaan_selected': FeatureGroup.prayerAndWorship,
        'azaan_notifications_toggled': FeatureGroup.prayerAndWorship,
        'azaan_opt_in': FeatureGroup.prayerAndWorship,
        'prayer_sound_set': FeatureGroup.prayerAndWorship,
        'rakaat_prayer_completed': FeatureGroup.prayerAndWorship,
        'prayer_times_selection_changed': FeatureGroup.prayerAndWorship,
        'qibla_target_changed': FeatureGroup.prayerAndWorship,
        'qaza_updated': FeatureGroup.prayerAndWorship,
        'tasbeeh_session': FeatureGroup.prayerAndWorship,
        'flight_added': FeatureGroup.prayerAndWorship,
        'flight_edited': FeatureGroup.prayerAndWorship,
        // Personalization & account
        'account_deleted': FeatureGroup.personalizationAndAccount,
        'account_signed_in': FeatureGroup.personalizationAndAccount,
        'favorite_added': FeatureGroup.personalizationAndAccount,
        'favorite_removed': FeatureGroup.personalizationAndAccount,
        'favorite_reordered': FeatureGroup.personalizationAndAccount,
        'dark_mode_toggled': FeatureGroup.personalizationAndAccount,
        // Feedback & ratings
        'rating_prompt': FeatureGroup.feedbackAndRatings,
        'rating_prompt_feedback': FeatureGroup.feedbackAndRatings,
        'rate_us_settings': FeatureGroup.feedbackAndRatings,
        'feedback_email_opened': FeatureGroup.feedbackAndRatings,
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

      // home_menu_* and search are both wayfinding, so they share
      // findingContent — rank order within the group survives the merge.
      expect(
        grouped[FeatureGroup.findingContent]?.map((row) => row.key).toList(),
        ['home_menu_qibla', 'search', 'home_menu_tasbeeh'],
      );
      expect(grouped.containsKey(FeatureGroup.prayerAndWorship), isFalse);
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
