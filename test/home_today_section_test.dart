import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/pages/home/today_section.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/todays_recitation.dart';

import 'ui/firebase_test_doubles.dart';

List<String> _uids(List<TodayPick> picks) =>
    [for (final pick in picks) pick.entry.uid];

void main() {
  group('todayPicks', () {
    TodaysRecitationGroup titled(
            TodaysRecitationKind kind, Map<String, String> entries) =>
        TodaysRecitationGroup(kind, [
          for (final entry in entries.entries)
            UidTitleData(entry.key, entry.value),
        ]);

    test('every dua and ziyarat shows, however many rites come first', () {
      final picks = todayPicks([
        titled(TodaysRecitationKind.weekday, {
          'J1': 'Merits & Rituals of Friday Night & Day',
          'J3': 'Ziyarat on Friday',
          'J4': 'The Supplication of Friday',
          'J6': 'Recommended Rites of Friday',
          'J7': 'Aamal of Zuhr Prayer on Friday',
          'J8': 'Aamal of Asr on Friday',
          'E26': 'Dua Simat',
          'E34': 'Dua Nudba',
        }),
        titled(TodaysRecitationKind.everyDay, {
          'G4': 'Ziyarat Ashura',
          'G6': 'Ziyarat Warith',
          'E18': 'Dua Ahad',
        }),
      ]);
      expect(_uids(picks), ['E26', 'E34', 'J3', 'G4', 'G6', 'E18']);
    });

    test('puts the duas category before a ziyarat known by its title', () {
      final picks = todayPicks([
        titled(TodaysRecitationKind.weekday, {
          'Q3': 'Ziyarat on Thursday',
          'E31': 'Dua Kumayl',
        }),
      ]);
      expect(_uids(picks), ['E31', 'Q3']);
    });

    test('leads with the whole of tonight\'s occasion', () {
      final picks = todayPicks([
        titled(TodaysRecitationKind.night, {
          'AA29': 'Common Aamal at Each of the Three Qadr Nights',
          'AA35': 'Dua for the 23rd Night of Ramazan',
          'E29': 'Dua Jawshan Kabir',
        }),
        titled(TodaysRecitationKind.month, {
          'AA16': 'Aamal of Sahar in the Holy Month of Ramazan',
          'AA10': 'Dua Iftitah',
        }),
        titled(TodaysRecitationKind.everyDay, {'G6': 'Ziyarat Warith'}),
      ]);
      expect(_uids(picks), ['E29', 'AA35', 'AA29', 'AA10', 'G6', 'AA16']);
      expect(picks.first.kind, TodaysRecitationKind.night);
    });

    test('tops up with rites only to the minimum', () {
      final picks = todayPicks([
        titled(TodaysRecitationKind.weekday, {
          'K1': 'The Supplication of Saturday',
          'K2': 'Namaz on Saturdays',
          'K3': 'Ziyarat on Saturday',
        }),
        titled(TodaysRecitationKind.everyDay, {'G4': 'Ziyarat Ashura'}),
      ], minimum: 3);
      expect(_uids(picks), ['K3', 'G4', 'K1']);
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
        'L2': 'Namaz on Sundays',
        'L3': 'Ziyarat on Sunday',
        'L4': 'Recommended Rites of Sunday',
        'L5': 'Merits of Sunday',
        'E18': 'Dua Ahad',
        'G4': 'Ziyarat Ashura',
        'Q1': 'The Supplication of Thursday',
      };
      itemMetadata = {
        for (final uid in ['L1', 'L2', 'L3', 'L4', 'L5']) uid: {'day': '*-*-0'},
        'E18': {'day': '*-*'},
        'G4': {'day': '*-*'},
        'Q1': {'day': '*-*-4'},
      };
      zikrIndexReady.value = true;
      var seeAll = 0;

      await tester.pumpWidget(app(onSeeAll: () => seeAll++));

      expect(find.text('Today'), findsOneWidget);
      // The day's ziyarat and the every-day recitations, then rites to
      // make up six cards; the seventh is left to See all.
      for (final title in [
        'Ziyarat on Sunday',
        'Ziyarat Ashura',
        'Dua Ahad',
        'The Supplication of Sunday',
        'Namaz on Sundays',
        'Recommended Rites of Sunday',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text('Merits of Sunday'), findsNothing);
      expect(find.text('The Supplication of Thursday'), findsNothing);
      // No caption saying when: the heading says Today.
      expect(find.text('For Sunday'), findsNothing);
      expect(find.text('Every day'), findsNothing);
      // One strip of cards, in order.
      expect(
        tester.getTopLeft(find.text('Ziyarat on Sunday')).dx,
        lessThan(tester.getTopLeft(find.text('Ziyarat Ashura')).dx),
      );

      await tester.tap(find.text('See all'));
      expect(seeAll, 1);
    });

    testWidgets('has no See all when every recitation is already shown',
        (tester) async {
      items = {'L3': 'Ziyarat on Sunday', 'G4': 'Ziyarat Ashura'};
      itemMetadata = {
        'L3': {'day': '*-*-0'},
        'G4': {'day': '*-*'},
      };
      zikrIndexReady.value = true;

      await tester.pumpWidget(app());

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Ziyarat Ashura'), findsOneWidget);
      expect(find.text('See all'), findsNothing);
    });

    testWidgets('tags tonight\'s occasion, and nothing else', (tester) async {
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
      expect(
        tester.getTopLeft(find.text('Dua of the Night')).dx,
        lessThan(tester.getTopLeft(find.text('Ziyarat Ashura')).dx),
      );
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
  });

  test('shares cards out so no row of the grid has empty slots', () {
    expect(todayGridRowSizes(10, 4), [3, 3, 2, 2]);
    expect(todayGridRowSizes(6, 2), [3, 3]);
    expect(todayGridRowSizes(7, 3), [3, 2, 2]);
    expect(todayGridRowSizes(1, 1), [1]);
    expect(todayGridRowSizes(0, 0), isEmpty);
  });
}
