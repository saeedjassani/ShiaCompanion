import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/pages/search_page.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'firebase_test_doubles.dart';

void main() {
  setUpAll(setUpFirebaseForRenderTests);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
  });

  final defaultEntries = [
    UidTitleData('E1', 'Dua Kumayl'),
    UidTitleData('E2', 'Dua for Light'),
    // A5 holds surah 1; A4 is Ayat al-Kursi, filed with the Quran but not a
    // surah, so it counts as one of the duas & more.
    UidTitleData('A5', '1: Al-Fatihah الفاتحة'),
    UidTitleData('A4', 'Ayat al-Kursi'),
    UidTitleData('A28', '24: An-Nur النور'),
    UidTitleData('B1', 'Commentary on Dua Kumayl', author: 'Ansariyan'),
    UidTitleData('B2', 'Light Within Me', author: 'Ansariyan'),
  ];

  Future<void> openSearch(
    WidgetTester tester,
    String query, {
    List<UidTitleData>? entries,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: SearchPage(
        entries: entries ?? defaultEntries,
        libraryUids: entries == null ? {'B1', 'B2'} : {},
      ),
    ));
    await tester.pump();
    if (query.isNotEmpty) {
      await tester.enterText(find.byType(TextField), query);
    }
    await tester.pumpAndSettle();
    // Let the debounced search record fire so no timer outlives the test.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('library books are folded by default but counted',
      (tester) async {
    await openSearch(tester, 'kumayl');

    expect(find.text('Dua Kumayl', findRichText: true), findsOneWidget);
    expect(find.text('Commentary on Dua Kumayl', findRichText: true),
        findsNothing);
    expect(find.text('1 match in Library'), findsOneWidget);
  });

  testWidgets('showing the library lists books with their author',
      (tester) async {
    await openSearch(tester, 'kumayl');

    await tester.tap(find.text('1 match in Library'));
    await tester.pumpAndSettle();

    expect(find.text('LIBRARY · 1'), findsOneWidget);
    expect(find.text('Commentary on Dua Kumayl', findRichText: true),
        findsOneWidget);
    expect(find.text('Ansariyan'), findsOneWidget);
    expect(find.text('1 match in Library'), findsNothing);
    // Remembered for next time.
    expect(SP.prefs.getStringList(SearchPage.sourcesPrefKey),
        containsAll(['zikr', 'quran', 'library']));
  });

  testWidgets('a search only the library matches still points to it',
      (tester) async {
    await openSearch(tester, 'ansariyan');

    expect(find.textContaining('Nothing called'), findsNothing);
    expect(find.text('2 matches in Library'), findsOneWidget);
  });

  testWidgets('duas & more and the Quran are sections, both open by default',
      (tester) async {
    await openSearch(tester, 'a');

    expect(find.text('DUAS & MORE · 3'), findsOneWidget);
    expect(find.text('QURAN · 2'), findsOneWidget);
    expect(find.text('Ayat al-Kursi', findRichText: true), findsOneWidget);
    expect(find.text('2 matches in Library'), findsOneWidget);
  });

  testWidgets('Hide folds a section to one row after the others',
      (tester) async {
    await openSearch(tester, 'a');

    await tester.tap(find.bySemanticsLabel('Hide Duas & more'));
    await tester.pumpAndSettle();

    expect(find.text('Dua Kumayl', findRichText: true), findsNothing);
    expect(find.text('3 matches in Duas & more'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('QURAN · 2')).dy,
      lessThan(tester.getTopLeft(find.text('3 matches in Duas & more')).dy),
    );
  });

  testWidgets('"fa" lists Al-Fatihah first, ahead of duas & more',
      (tester) async {
    await openSearch(tester, 'fa', entries: [
      for (var i = 1; i <= 30; i++)
        UidTitleData('D$i', 'Taqibaat of Namaz-e-Fajr $i'),
      UidTitleData('A5', '1: Al-Fatihah الفاتحة'),
    ]);

    expect(
      tester.getTopLeft(find.text('QURAN · 1')).dy,
      lessThan(tester.getTopLeft(find.text('DUAS & MORE · 30')).dy),
    );
  });

  testWidgets('on an equally good match, duas & more stay ahead',
      (tester) async {
    await openSearch(tester, 'fa', entries: [
      UidTitleData('A5', '1: Al-Fatihah الفاتحة'),
      UidTitleData('AA47', 'Farewell Prayer of Ramazan'),
    ]);

    expect(
      tester.getTopLeft(find.text('DUAS & MORE · 1')).dy,
      lessThan(tester.getTopLeft(find.text('QURAN · 1')).dy),
    );
  });

  testWidgets('a result says where it lives', (tester) async {
    final originalItems = items;
    addTearDown(() => items = originalItems);
    items = {
      'C~R9': 'Muharram',
      'R9': 'Aamal of Ashura',
      'G4': 'Ziyarat Ashura',
    };
    await openSearch(tester, 'ashura', entries: [
      UidTitleData('G4', 'Ziyarat Ashura'),
      UidTitleData('R9', 'Aamal of Ashura'),
    ]);

    expect(find.text('Ziyarats'), findsOneWidget);
    expect(find.text('Aamaal › Muharram'), findsOneWidget);
  });

  testWidgets('before typing it offers examples, which fill the field',
      (tester) async {
    await openSearch(tester, '');

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('TRY'), findsOneWidget);
    expect(find.text('RECENT'), findsNothing);

    await tester.tap(find.text('Kumayl'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Kumayl'), findsOneWidget);
    expect(find.text('Dua Kumayl', findRichText: true), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('keeps the last three searches, the refined one only',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      SearchPage.recentPrefKey: ['ashura', 'nudba', 'warith'],
    });
    await SP.init();
    await openSearch(tester, 'kum');
    await tester.enterText(find.byType(TextField), 'kumayl');
    await tester.pump(const Duration(seconds: 1));

    expect(SP.prefs.getStringList(SearchPage.recentPrefKey),
        ['kumayl', 'ashura', 'nudba']);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('RECENT'), findsOneWidget);
    expect(find.text('kumayl'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Clear recent searches'));
    await tester.pumpAndSettle();
    expect(find.text('RECENT'), findsNothing);
    expect(SP.prefs.getStringList(SearchPage.recentPrefKey), isNull);
  });

  testWidgets('finding nothing suggests a word and offers a request',
      (tester) async {
    await openSearch(tester, 'dua jameel');

    expect(find.text('Nothing called “dua jameel”'), findsOneWidget);
    expect(find.textContaining('like jameel', findRichText: true),
        findsOneWidget);
    expect(find.text('Still can\'t find it?'), findsOneWidget);
    expect(find.text('Request “dua jameel”'), findsOneWidget);
  });

  testWidgets('Close leaves search', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SearchPage(entries: defaultEntries))),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close search'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsNothing);
  });

  group('a verse reference', () {
    setUp(() => items = {'A6': '2: Al-Baqarah البقرة'});
    tearDown(() {
      items = {};
      isUserAdmin = false;
    });

    testWidgets('is offered first, as Go to verse', (tester) async {
      isUserAdmin = true;
      await openSearch(tester, 'baqarah 255');

      expect(find.text('GO TO VERSE'), findsOneWidget);
      expect(find.text('Al-Baqarah 2:255'), findsOneWidget);
      expect(find.text('Open verse 255'), findsOneWidget);
      // Found, so not a search that came up empty.
      expect(find.textContaining('Nothing called'), findsNothing);
    });

    testWidgets('is offered in its numeric form too', (tester) async {
      isUserAdmin = true;
      await openSearch(tester, '2:255');

      expect(find.text('Al-Baqarah 2:255'), findsOneWidget);
    });

    testWidgets('is left out where the reader cannot open at a verse',
        (tester) async {
      await openSearch(tester, '2:255');

      expect(find.text('GO TO VERSE'), findsNothing);
    });
  });
}
