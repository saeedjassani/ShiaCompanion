import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/utils/data_search.dart';

import 'firebase_test_doubles.dart';

void main() {
  setUpAll(setUpFirebaseForRenderTests);

  Future<void> openSearch(WidgetTester tester, String query) async {
    final delegate = DataSearch(
      [
        UidTitleData('E1', 'Dua Kumayl'),
        UidTitleData('E2', 'Dua for Light'),
        // A5 holds surah 1; A4 is Ayat al-Kursi, filed with the Quran but not a
        // surah, so it counts as zikr.
        UidTitleData('A5', '1: Al-Fatihah الفاتحة'),
        UidTitleData('A4', 'Ayat al-Kursi'),
        UidTitleData('A28', '24: An-Nur النور'),
        UidTitleData('B1', 'Commentary on Dua Kumayl', author: 'Ansariyan'),
        UidTitleData('B2', 'Light Within Me', author: 'Ansariyan'),
      ],
      libraryUids: {'B1', 'B2'},
    );
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showSearch(context: context, delegate: delegate),
          child: const Text('search'),
        ),
      ),
    ));
    await tester.tap(find.text('search'));
    await tester.pumpAndSettle();
    delegate.query = query;
    await tester.pumpAndSettle();
    // Let the debounced search record fire so no timer outlives the test.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('library books are hidden by default but counted',
      (tester) async {
    await openSearch(tester, 'kumayl');

    expect(find.text('Dua Kumayl'), findsOneWidget);
    expect(find.text('Commentary on Dua Kumayl'), findsNothing);
    expect(find.text('1 match in Library'), findsOneWidget);
  });

  testWidgets('including the library lists books with their author',
      (tester) async {
    await openSearch(tester, 'kumayl');

    await tester.tap(find.widgetWithText(FilterChip, 'Library'));
    await tester.pumpAndSettle();

    expect(find.text('Library (1)'), findsOneWidget);
    expect(find.text('Commentary on Dua Kumayl'), findsOneWidget);
    expect(find.text('Ansariyan'), findsOneWidget);
    expect(find.text('1 match in Library'), findsNothing);
  });

  testWidgets('a search only the library matches still points to it',
      (tester) async {
    await openSearch(tester, 'ansariyan');

    expect(find.text('No results'), findsNothing);
    expect(find.text('2 matches in Library'), findsOneWidget);
  });

  testWidgets('zikr and Quran are separate sections, both on by default',
      (tester) async {
    await openSearch(tester, 'a');

    expect(find.text('Zikr (3)'), findsOneWidget);
    expect(find.text('Quran (2)'), findsOneWidget);
    expect(find.text('Ayat al-Kursi'), findsOneWidget);
    expect(find.text('2 matches in Library'), findsOneWidget);
  });

  testWidgets('switching Zikr off leaves only the Quran', (tester) async {
    await openSearch(tester, 'a');

    await tester.tap(find.widgetWithText(FilterChip, 'Zikr'));
    await tester.pumpAndSettle();

    expect(find.text('Dua Kumayl'), findsNothing);
    expect(find.text('1: Al-Fatihah الفاتحة'), findsOneWidget);
    // One section left, so no heading.
    expect(find.text('Quran (2)'), findsNothing);
    expect(find.text('3 matches in Zikr'), findsOneWidget);
  });
}
