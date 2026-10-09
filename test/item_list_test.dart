import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/list_items.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/zikr_list_row.dart';

import 'ui/firebase_test_doubles.dart';

void main() {
  late Map originalItems;
  late Map<String, double> originalItemOrder;
  late Map<String, dynamic> originalItemMetadata;
  late int originalHijriDate;

  setUpAll(setUpFirebaseForRenderTests);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    originalItems = Map.of(items);
    originalItemOrder = Map.of(itemOrder);
    originalItemMetadata = Map.of(itemMetadata);
    originalHijriDate = hijriDate;
    hijriDate = 0;
    itemOrder = {};
  });

  tearDown(() {
    items = originalItems;
    itemOrder = originalItemOrder;
    itemMetadata = originalItemMetadata;
    hijriDate = originalHijriDate;
  });

  /// [page] pushed over a blank root, as the menu opens it.
  Future<void> pumpPushed(WidgetTester tester, Widget page) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Scaffold()));
    navigator.currentState!.push(MaterialPageRoute(builder: (_) => page));
    await tester.pumpAndSettle();
  }

  testWidgets('counts the list and says when an occasion dua is recited',
      (tester) async {
    items = {
      'E1': 'Dua Istighatha الکامل التام',
      'E8': 'Dua Alqama',
      'G4': 'Ziyarat Ashura',
    };
    itemMetadata = {
      'E8': {'day': '01-10'},
    };
    await pumpPushed(tester, ItemList('E', 'Duas'));

    expect(find.text('Duas'), findsWidgets);
    expect(find.text('2 duas'), findsOneWidget);
    // The Arabic a title ends in gets a line of its own.
    expect(find.text('Dua Istighatha'), findsOneWidget);
    expect(find.text('الکامل التام'), findsOneWidget);
    expect(find.text('On 10 Muharram'), findsOneWidget);
    // Not a dua: another list's entry.
    expect(find.text('Ziyarat Ashura'), findsNothing);
  });

  testWidgets('marks what falls today, but not what falls every day',
      (tester) async {
    final today = HijriCalendar.fromDate(DateTime.now());
    final weekday = DateTime.now().weekday % 7;
    items = {
      'G4': 'Ziyarat Ashura',
      'G7': 'Ziyarat for today',
      'G8': 'Ziyarat for another day',
    };
    itemMetadata = {
      'G4': {'day': '*-*'},
      'G7': {'day': '*-*-$weekday'},
      'G8': {'day': '${today.hMonth % 12 + 1}-01'},
    };
    await pumpPushed(tester, ItemList('G', 'Ziyarats'));

    expect(find.byType(TodayPill), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Ziyarat for today'),
          matching: find.byType(ZikrListRow),
        ),
        matching: find.byType(TodayPill),
      ),
      findsOneWidget,
    );
    expect(find.text('Every day'), findsOneWidget);
  });

  testWidgets('a group row says what is inside and opens it', (tester) async {
    items = {
      'G4': 'Ziyarat Ashura',
      'G0~B': 'Ziyarat of Hijaz, Iran & Iraq',
      'B3': 'Etiquettes of Ziyarat',
      'B~AE7': 'Iran',
      'B~AF8': 'Iraq',
    };
    itemMetadata = {};
    await pumpPushed(tester, ItemList('G', 'Ziyarats'));

    expect(find.byType(ZikrGroupRow), findsOneWidget);
    expect(find.text('Iran, Iraq · 3 sections'), findsOneWidget);

    await tester.tap(find.text('Ziyarat of Hijaz, Iran & Iraq'));
    await tester.pumpAndSettle();

    expect(find.text('Etiquettes of Ziyarat'), findsOneWidget);
    expect(find.text('3 sections'), findsOneWidget);
  });

  testWidgets('the find field narrows the list, and offers search when empty',
      (tester) async {
    items = {
      'E19': 'Dua Faraj',
      'E31': 'Dua Kumayl',
      'E18': 'Dua Ahad',
    };
    itemMetadata = {};
    await pumpPushed(tester, ItemList('E', 'Duas'));

    expect(find.widgetWithText(TextField, 'Find a dua'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'kum');
    await tester.pump();
    expect(find.byType(ZikrListRow), findsOneWidget);
    expect(find.text('Dua Kumayl', findRichText: true), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'jameel');
    await tester.pump();
    expect(find.byType(ZikrListRow), findsNothing);
    expect(find.text('Nothing called “jameel” here'), findsOneWidget);
    expect(find.text('Search everything'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Clear search'));
    await tester.pump();
    expect(find.byType(ZikrListRow), findsNWidgets(3));
  });

  testWidgets('no find field on a tab root, where the tab bar has search',
      (tester) async {
    items = {'A5': '1: Al-Fatihah الفاتحة'};
    itemMetadata = {};
    await tester.pumpWidget(MaterialApp(home: ItemList('A', 'Quran')));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Al-Fatihah'), findsOneWidget);
    expect(find.text('1 surah'), findsOneWidget);
  });
}
