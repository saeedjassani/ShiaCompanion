import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/pages/home/today_section.dart';
import 'package:shia_companion/services/zikr_translations.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/todays_recitation.dart';

import 'ui/firebase_test_doubles.dart';

List<String> _uids(List<TodayPick> picks) =>
    [for (final pick in picks) pick.entry.uid];

/// Serves [files] as assets, with an AssetManifest.bin listing them - all
/// [ZikrTranslations] needs to discover a language and load its titles.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<Object?, Object?>{
        for (final path in files.keys)
          path: <Object?>[
            <Object?, Object?>{'asset': path},
          ],
      })!;
    }
    final content = files[key];
    if (content == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(utf8.encode(content));
  }
}

final _arabicTitles = _FakeBundle({
  zikrTranslationIndexPath('ar'): '{"titles": {"G4": "زيارة عاشوراء"}}',
});

void main() {
  group('todayPicks', () {
    TodaysRecitationGroup titled(
            TodaysRecitationKind kind, Map<String, String> entries) =>
        TodaysRecitationGroup(kind, [
          for (final entry in entries.entries)
            UidTitleData(entry.key, entry.value),
        ]);

    test('shows only the recited weekday and every-day recitations', () {
      final picks = todayPicks([
        titled(TodaysRecitationKind.weekday, {
          'J1': 'Merits & Rituals of Friday Night & Day',
          'J3': 'Ziyarat on Friday',
          'J6': 'Recommended Rites of Friday',
          'E26': 'Dua Simat',
          'E29': 'Dua Jawshan Kabir',
          'E34': 'Dua Nudba',
        }),
        titled(TodaysRecitationKind.everyDay, {
          'G4': 'Ziyarat Ashura',
          'G6': 'Ziyarat Warith',
          'E18': 'Dua Ahad',
          'E37': 'Dua Sanamay Quraish',
        }),
      ]);
      // Jawshan Kabir and Simat on Friday are left to See all.
      expect(_uids(picks), ['E34', 'G4', 'G6', 'E18']);
    });

    test('leads with the whole of tonight\'s occasion, Jawshan Kabir first',
        () {
      final picks = todayPicks([
        titled(TodaysRecitationKind.night, {
          'G14': 'Ziyarat of Imam Husayn (a.s.) on the Qadr Nights',
          'AA29': 'Common Aamal at Each of the Three Qadr Nights',
          'AA35': 'Dua for the 23rd Night of Ramazan',
          'E29': 'Dua Jawshan Kabir',
        }),
        titled(TodaysRecitationKind.month, {
          'AA16': 'Aamal of Sahar in the Holy Month of Ramazan',
          'AA10': 'Dua Iftitah',
        }),
        titled(TodaysRecitationKind.weekday, {'E31': 'Dua Kumayl'}),
        titled(TodaysRecitationKind.everyDay, {'G6': 'Ziyarat Warith'}),
      ]);
      // The month's aamal waits in See all, and with a dua for the night
      // the every-day ziyarat does too.
      expect(_uids(picks), ['E29', 'G14', 'AA35', 'AA29', 'AA10', 'E31']);
      expect(picks.first.kind, TodaysRecitationKind.night);
    });

    test('keeps the every-day recitations when the occasion is only aamal', () {
      final picks = todayPicks([
        titled(TodaysRecitationKind.night, {
          'AA30': 'The 13th Night of Ramazan',
        }),
        titled(TodaysRecitationKind.everyDay, {'G4': 'Ziyarat Ashura'}),
      ]);
      expect(_uids(picks), ['AA30', 'G4']);
      expect(todayPicks(const []), isEmpty);
    });

    test('knows a dua, ziyarat or munajat by category or title', () {
      TodayRecitationType type(String uid, String title) =>
          todayRecitationType(UidTitleData(uid, title));
      expect(type('E31', 'Dua Kumayl'), TodayRecitationType.dua);
      expect(type('AA10', 'Dua Iftitah'), TodayRecitationType.dua);
      expect(type('G6', 'Ziyarat Warith'), TodayRecitationType.ziyarat);
      expect(type('X4', 'Ziyarat Rajabiyah'), TodayRecitationType.ziyarat);
      expect(type('Y4', 'Munajat Shabaniyah'), TodayRecitationType.munajat);
      expect(
          type('J6', 'Recommended Rites of Friday'), TodayRecitationType.other);
    });
  });

  group('TodaySection', () {
    setUpAll(setUpFirebaseForRenderTests);

    late Map originalItems;
    late Map<String, double> originalItemOrder;
    late Map<String, dynamic> originalItemMetadata;
    late int originalHijriDate;
    late bool originalReady;
    final originalLat = lat;
    final originalLong = long;

    setUp(() async {
      SharedPreferences.setMockInitialValues(const {});
      await SP.init();
      originalItems = Map.of(items);
      originalItemOrder = Map.of(itemOrder);
      originalItemMetadata = Map.of(itemMetadata);
      originalHijriDate = hijriDate;
      originalReady = zikrIndexReady.value;
      // Without a location the night window is 16:00 - 08:00; noon is day.
      lat = null;
      long = null;
      hijriDate = 0;
      itemOrder = {};
      TodaySection.debugNow = () => DateTime(2024, 6, 16, 12); // a Sunday
    });

    tearDown(() {
      items = originalItems;
      itemOrder = originalItemOrder;
      itemMetadata = originalItemMetadata;
      hijriDate = originalHijriDate;
      zikrIndexReady.value = originalReady;
      lat = originalLat;
      long = originalLong;
      TodaySection.debugNow = DateTime.now;
    });

    Widget app({VoidCallback? onSeeAll}) => MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: TodaySection(onSeeAll: onSeeAll ?? () {}),
            ),
          ),
        );

    testWidgets('shows today\'s recitations as cards, then See all for more',
        (tester) async {
      items = {
        'L1': 'The Supplication of Sunday',
        'L3': 'Ziyarat on Sunday',
        'E18': 'Dua Ahad',
        'G4': 'Ziyarat Ashura',
        'G6': 'Ziyarat Warith',
        'Q1': 'The Supplication of Thursday',
      };
      itemMetadata = {
        for (final uid in ['L1', 'L3']) uid: {'day': '*-*-0'},
        'E18': {'day': '*-*'},
        'G4': {'day': '*-*'},
        'G6': {'day': '*-*'},
        'Q1': {'day': '*-*-4'},
      };
      zikrIndexReady.value = true;
      var seeAll = 0;

      await tester.pumpWidget(app(onSeeAll: () => seeAll++));

      expect(find.text('Today'), findsOneWidget);
      // The every-day recitations centres recite; Sunday's ziyarat and
      // supplication are left to See all.
      for (final title in ['Ziyarat Ashura', 'Ziyarat Warith', 'Dua Ahad']) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text('Ziyarat on Sunday'), findsNothing);
      expect(find.text('The Supplication of Sunday'), findsNothing);
      expect(find.text('The Supplication of Thursday'), findsNothing);
      // No caption saying when: the heading says Today.
      expect(find.text('For Sunday'), findsNothing);
      expect(find.text('Every day'), findsNothing);
      // One strip of cards, in order.
      expect(
        tester.getTopLeft(find.text('Ziyarat Ashura')).dx,
        lessThan(tester.getTopLeft(find.text('Ziyarat Warith')).dx),
      );

      await tester.tap(find.text('See all'));
      expect(seeAll, 1);
    });

    testWidgets('has no See all when every recitation is already shown',
        (tester) async {
      items = {'G6': 'Ziyarat Warith', 'G4': 'Ziyarat Ashura'};
      itemMetadata = {
        'G6': {'day': '*-*'},
        'G4': {'day': '*-*'},
      };
      zikrIndexReady.value = true;

      await tester.pumpWidget(app());

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Ziyarat Ashura'), findsOneWidget);
      expect(find.text('See all'), findsNothing);
    });

    testWidgets('tags tonight\'s occasion, and leaves every day\'s to See all',
        (tester) async {
      // 20:00: without a location the night runs from 16:00.
      final evening = DateTime(2024, 6, 16, 20);
      TodaySection.debugNow = () => evening;
      final night = todaysLunarDays(now: evening).night!.hijri;
      items = {'Y9': 'Dua of the Night', 'G4': 'Ziyarat Ashura'};
      itemMetadata = {
        'Y9': {'day': 'N${night.hMonth}-${night.hDay}'},
        'G4': {'day': '*-*'},
      };
      zikrIndexReady.value = true;

      await tester.pumpWidget(app());

      expect(find.text('TONIGHT'), findsOneWidget);
      expect(find.text('Dua of the Night'), findsOneWidget);
      // Tonight has a dua of its own, so the every-day ziyarat waits in
      // See all.
      expect(find.text('Ziyarat Ashura'), findsNothing);
      expect(find.text('See all'), findsOneWidget);
    });

    testWidgets(
        'is hidden until the index loads, and when nothing is for today',
        (tester) async {
      items = {'Q1': 'The Supplication of Thursday'};
      itemMetadata = {
        'Q1': {'day': '*-*-4'},
      };
      zikrIndexReady.value = false;

      await tester.pumpWidget(app());
      expect(find.text('Today'), findsNothing);

      zikrIndexReady.value = true;
      await tester.pump();
      expect(find.text('Today'), findsNothing);
      expect(find.text('See all'), findsNothing);
    });

    testWidgets('retitles its cards when the zikr titles\' language loads',
        (tester) async {
      items = {'G4': 'Ziyarat Ashura'};
      itemMetadata = {
        'G4': {'day': '*-*'},
      };
      zikrIndexReady.value = true;
      final translations = ZikrTranslations.instance..debugReset();
      addTearDown(translations.debugReset);

      await tester.pumpWidget(app());
      expect(find.text('Ziyarat Ashura'), findsOneWidget);

      await tester
          .runAsync(() => translations.setLanguage('ar', _arabicTitles));
      await tester.pump();
      expect(find.text('زيارة عاشوراء'), findsOneWidget);
      expect(find.text('Ziyarat Ashura'), findsNothing);
    });
  });

  test('shares cards out so no row of the grid has empty slots', () {
    expect(todayGridRowSizes(10, 4), [3, 3, 2, 2]);
    expect(todayGridRowSizes(6, 2), [3, 3]);
    expect(todayGridRowSizes(7, 3), [3, 2, 2]);
    expect(todayGridRowSizes(1, 1), [1]);
    expect(todayGridRowSizes(0, 0), isEmpty);
  });
}
