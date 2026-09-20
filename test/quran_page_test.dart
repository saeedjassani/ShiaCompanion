import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/quran/quran_page.dart';
import 'package:shia_companion/services/saved_verses_store.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'ui/firebase_test_doubles.dart';

void main() {
  setUpAll(() async {
    // The surah rows carry a favourite toggle, and the recitation cards read
    // the tracker's Firestore doc for a signed-in user - both reach for
    // Firestore even though these tests run signed out.
    await setUpFirebaseForRenderTests();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    await SavedVersesStore.instance.clear();
    items = {
      for (var surah = 1; surah <= surahCount; surah++)
        uidForSurah(surah)!: '$surah: Surah$surah اسم',
    };
  });

  tearDown(() => items = {});

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: QuranPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every surah with its ayah count', (tester) async {
    await pump(tester);

    expect(find.text('Surah1'), findsOneWidget);
    expect(find.text('7 ayahs'), findsOneWidget);
    // Ayat al Kursi is not a surah and must not appear among the 114.
    expect(find.text('Ayat al Kursi'), findsNothing);
  });

  testWidgets('the juz tab lists all thirty with their ranges',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Juz'));
    await tester.pumpAndSettle();

    expect(find.text('Juz 1'), findsOneWidget);
    expect(find.text('Surah1 1 → Surah2 141'), findsOneWidget);
  });

  testWidgets('rejects a verse reference it cannot read', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'not a verse');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(find.text('Try something like 23:56'), findsOneWidget);
  });

  testWidgets(
      'the Unlabeled recitation track always shows, with nothing to resume yet',
      (tester) async {
    await pump(tester);

    expect(find.text('Unlabeled'), findsOneWidget);
    expect(find.text('Start reading'), findsOneWidget);
  });

  testWidgets('the Saved tab says so when nothing is kept', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();

    expect(find.text('No saved verses yet'), findsOneWidget);
  });

  testWidgets('kept verses are listed in mushaf order', (tester) async {
    for (final verse in [const VerseKey(36, 9), const VerseKey(2, 255)]) {
      await SavedVersesStore.instance.add(
        SavedVerse(
          surah: verse.surah,
          ayah: verse.ayah!,
          surahName: 'Surah${verse.surah}',
          excerpt: 'excerpt ${verse.surah}',
          savedAt: DateTime.now().toUtc(),
        ),
      );
    }
    await pump(tester);
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();

    expect(find.text('Surah2 255'), findsOneWidget);
    expect(find.text('Surah36 9'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Surah2 255')).dy,
      lessThan(tester.getTopLeft(find.text('Surah36 9')).dy),
      reason: 'al-Baqarah comes before Ya-Sin in the mushaf',
    );
  });

  testWidgets('a kept verse can be removed from the list', (tester) async {
    await SavedVersesStore.instance.add(
      SavedVerse(
        surah: 2,
        ayah: 255,
        surahName: 'Surah2',
        excerpt: '',
        savedAt: DateTime.now().toUtc(),
      ),
    );
    await pump(tester);
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('No saved verses yet'), findsOneWidget);
    expect(SavedVersesStore.instance.readAll(), isEmpty);
  });
}
