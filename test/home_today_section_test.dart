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

    testWidgets('shows today\'s recitations as cards, with what each is for',
        (tester) async {
      items = {
        'L1': 'The Supplication of Sunday',
        'L2': 'Namaz on Sundays',
        'L3': 'Ziyarat on Sunday',
        'E18': 'Dua Ahad',
        'G4': 'Ziyarat Ashura',
        'Q1': 'The Supplication of Thursday',
      };
      itemMetadata = {
        'L1': {'day': '*-*-0'},
        'L2': {'day': '*-*-0'},
        'L3': {'day': '*-*-0'},
        'E18': {'day': '*-*'},
        'G4': {'day': '*-*'},
        'Q1': {'day': '*-*-4'},
      };
      zikrIndexReady.value = true;
      var seeAll = 0;

      await tester.pumpWidget(app(onSeeAll: () => seeAll++));

      expect(find.text('Today'), findsOneWidget);
      // The day's ziyarat and the every-day recitations, then rites to
      // make up the cards.
      expect(find.text('Ziyarat on Sunday'), findsOneWidget);
      expect(find.text('Ziyarat Ashura'), findsOneWidget);
      expect(find.text('Dua Ahad'), findsOneWidget);
      expect(find.text('The Supplication of Sunday'), findsOneWidget);
      expect(find.text('Namaz on Sundays'), findsOneWidget);
      expect(find.text('For Sunday'), findsNWidgets(3));
      expect(find.text('Every day'), findsNWidgets(2));
      expect(find.text('The Supplication of Thursday'), findsNothing);
      // One strip of cards, in order.
      expect(
        tester.getTopLeft(find.text('Ziyarat on Sunday')).dx,
        lessThan(tester.getTopLeft(find.text('Ziyarat Ashura')).dx),
      );

      await tester.tap(find.text('See all'));
      expect(seeAll, 1);
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
}
