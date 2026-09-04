import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/quran/quran_page.dart';
import 'package:shia_companion/services/quran_progress_store.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'ui/firebase_test_doubles.dart';

void main() {
  setUpAll(() async {
    // The surah rows carry a favourite toggle, which reaches for Firestore.
    await setUpFirebaseForRenderTests();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    await QuranProgressStore.instance.clear();
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

  testWidgets('shows no Continue card until reading has recorded a place',
      (tester) async {
    await pump(tester);

    expect(find.text('Continue reciting'), findsNothing);
  });

  testWidgets('shows where the reader left off once there is progress',
      (tester) async {
    await QuranProgressStore.instance.save(
      QuranProgress(
        surah: 2,
        ayah: 156,
        surahTitle: '2: Surah2',
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await pump(tester);

    expect(find.text('Continue reciting'), findsOneWidget);
    expect(find.text('Surah2 · ayah 156'), findsOneWidget);
  });

  testWidgets('the Continue card can be cleared', (tester) async {
    await QuranProgressStore.instance.save(
      QuranProgress(
        surah: 2,
        ayah: 156,
        surahTitle: '2: Surah2',
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await pump(tester);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Continue reciting'), findsNothing);
    expect(QuranProgressStore.instance.read(), isNull);
  });
}
