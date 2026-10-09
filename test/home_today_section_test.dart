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

TodaysRecitationGroup _group(TodaysRecitationKind kind, List<String> uids) =>
    TodaysRecitationGroup(
        kind, [for (final uid in uids) UidTitleData(uid, uid)]);

List<String> _uids(List<TodayPick> picks) =>
    [for (final pick in picks) pick.entry.uid];

void main() {
  group('todayPicks', () {
    test('gives each occasion two rows before any gets more', () {
      final picks = todayPicks([
        _group(TodaysRecitationKind.month, ['M1', 'M2', 'M3', 'M4', 'M5']),
        _group(TodaysRecitationKind.weekday, ['W1', 'W2', 'W3']),
        _group(TodaysRecitationKind.everyDay, ['D1', 'D2']),
      ]);
      expect(_uids(picks), ['M1', 'M2', 'W1', 'W2']);
    });

    test('fills what is left from the most specific occasions first', () {
      final picks = todayPicks([
        _group(TodaysRecitationKind.night, ['N1']),
        _group(TodaysRecitationKind.weekday, ['W1', 'W2', 'W3', 'W4']),
        _group(TodaysRecitationKind.everyDay, ['D1', 'D2']),
      ]);
      expect(_uids(picks), ['N1', 'W1', 'W2', 'W3']);
      expect(picks.first.kind, TodaysRecitationKind.night);
    });

    test('every-day recitations only fill the rows nothing else needs', () {
      final picks = todayPicks([
        _group(TodaysRecitationKind.weekday, ['W1']),
        _group(TodaysRecitationKind.everyDay, ['D1', 'D2', 'D3', 'D4']),
      ]);
      expect(_uids(picks), ['W1', 'D1', 'D2', 'D3']);
    });

    test('shows fewer rows when fewer are for today', () {
      expect(
          _uids(todayPicks([
            _group(TodaysRecitationKind.everyDay, ['D1']),
          ])),
          ['D1']);
      expect(todayPicks(const []), isEmpty);
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

    testWidgets('lists today\'s recitations with what each is for',
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
      expect(find.text('The Supplication of Sunday'), findsOneWidget);
      expect(find.text('Namaz on Sundays'), findsOneWidget);
      expect(find.text('Ziyarat on Sunday'), findsOneWidget);
      expect(find.text('For Sunday'), findsNWidgets(3));
      // Four rows: one every-day recitation fills the last.
      expect(find.text('Every day'), findsOneWidget);
      expect(find.text('The Supplication of Thursday'), findsNothing);

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
