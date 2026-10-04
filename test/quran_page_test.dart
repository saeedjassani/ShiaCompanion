import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/quran_ali_verses.dart';
import 'package:shia_companion/data/quran_mahdi_verses.dart';
import 'package:shia_companion/pages/quran/quran_page.dart';
import 'package:shia_companion/services/recitation_tracker_manager.dart';
import 'package:shia_companion/services/saved_verses_manager.dart';
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
    // A singleton that would otherwise keep the last test's saved verses.
    SavedVersesManager.instance.resetForTesting();
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

  Future<void> openCollection(WidgetTester tester, String chip) async {
    await tester.tap(find.text('Collections'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, chip));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every surah with its ayah count', (tester) async {
    await pump(tester);

    expect(find.text('Surah1'), findsOneWidget);
    expect(find.text('7 ayahs'), findsOneWidget);
    // Ayat al Kursi is not a surah and must not appear among the 114.
    expect(find.text('Ayat al Kursi'), findsNothing);
  });

  testWidgets('the juz tab lists all thirty with their ranges', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Juz'));
    await tester.pumpAndSettle();

    expect(find.text('Juz 1'), findsOneWidget);
    expect(find.text('Surah1 1 → Surah2 141'), findsOneWidget);
  });

  testWidgets('the app bar opens recent sessions', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Recent sessions'));
    await tester.pumpAndSettle();

    expect(find.text('Recent sessions'), findsOneWidget);
    expect(find.textContaining('No sessions yet'), findsOneWidget);
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

  testWidgets('the Saved collection says so when nothing is kept',
      (tester) async {
    await pump(tester);
    await openCollection(tester, 'Saved');

    expect(find.text('No saved verses yet'), findsOneWidget);
  });

  testWidgets('kept verses are listed in mushaf order', (tester) async {
    await tester.runAsync(() async {
      for (final verse in [const VerseKey(36, 9), const VerseKey(2, 255)]) {
        await SavedVersesManager.instance.save(
          SavedVerse(
            surah: verse.surah,
            ayah: verse.ayah!,
            surahName: 'Surah${verse.surah}',
            excerpt: 'excerpt ${verse.surah}',
            savedAt: DateTime.now().toUtc(),
          ),
        );
      }
    });
    await pump(tester);
    await openCollection(tester, 'Saved');

    expect(find.text('Surah2 255'), findsOneWidget);
    expect(find.text('Surah36 9'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Surah2 255')).dy,
      lessThan(tester.getTopLeft(find.text('Surah36 9')).dy),
      reason: 'al-Baqarah comes before Ya-Sin in the mushaf',
    );
  });

  testWidgets('a kept verse can be removed from the list', (tester) async {
    await tester.runAsync(
      () => SavedVersesManager.instance.save(
        SavedVerse(
          surah: 2,
          ayah: 255,
          surahName: 'Surah2',
          excerpt: '',
          savedAt: DateTime.now().toUtc(),
        ),
      ),
    );
    await pump(tester);
    await openCollection(tester, 'Saved');

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('No saved verses yet'), findsOneWidget);
    expect(SavedVersesManager.instance.state.verses, isEmpty);
  });

  testWidgets('verses saved on the device before syncing move into the list',
      (tester) async {
    await SP.prefs.setString(
      'quran_saved_verses_v1',
      '[{"surah":2,"ayah":255,"surahName":"Surah2",'
          '"savedAt":"2026-06-07T10:30:00.000Z"}]',
    );
    await tester.runAsync(
      () => SavedVersesManager.instance.loadSavedVerses(force: true),
    );

    await pump(tester);
    await openCollection(tester, 'Saved');

    expect(find.text('Surah2 255'), findsOneWidget);
    expect(
      SavedVersesStore.instance.readAll(),
      isEmpty,
      reason: 'the device copy is emptied once moved, so it moves only once',
    );
  });

  testWidgets(
      'the Duas collection holds the non-surah Quran zikrs, Ayat al Kursi '
      'included', (tester) async {
    items = {
      ...items,
      'A2': 'Dua after reciting Holy Quran',
      'A4': 'Ayat al Kursi',
      'E1': 'Some other dua',
    };
    await pump(tester);
    await openCollection(tester, 'Duas');

    expect(find.text('Ayat al Kursi'), findsOneWidget);
    expect(find.text('Dua after reciting Holy Quran'), findsOneWidget);
    expect(find.text('Some other dua'), findsNothing);
    expect(find.text('Surah1'), findsNothing);
  });

  testWidgets('the Duas collection lists the duas of the Quran after the zikrs',
      (tester) async {
    await pump(tester);
    await openCollection(tester, 'Duas');

    expect(find.text('From the Quran'), findsOneWidget);
    expect(find.text('Rabbana Atina fid-Dunya Hasanah'), findsOneWidget);
    expect(find.text('Surah2 201 · For good in this world and the hereafter'),
        findsOneWidget);
  });

  testWidgets('the Imam Ali collection lists the curated verses',
      (tester) async {
    await pump(tester);
    await openCollection(tester, 'Imam Ali (a.s.)');

    // The list is lazy and runs well past one screen, so bring the verse
    // into view before looking for it.
    await tester.scrollUntilVisible(find.text('Surah5 55'), 200,
        scrollable: _verticalScrollable);

    expect(find.text('Surah5 55'), findsOneWidget);
    expect(
        find.text(aliRelatedNoteFor(const VerseKey(5, 55))!), findsOneWidget);
  });

  testWidgets('the Imam al-Mahdi collection lists the curated verses',
      (tester) async {
    await pump(tester);
    await openCollection(tester, 'Imam al-Mahdi (a.t.f.s.)');

    await tester.scrollUntilVisible(find.text('Surah11 86'), 200,
        scrollable: _verticalScrollable);

    expect(find.text('Surah11 86'), findsOneWidget);
    expect(find.text(mahdiRelatedNoteFor(const VerseKey(11, 86))!),
        findsOneWidget);
  });

  testWidgets('the Prophets collection groups stories under each prophet',
      (tester) async {
    await pump(tester);
    await openCollection(tester, 'Prophets');

    expect(find.text('Adam (a.s.)'), findsOneWidget);
    expect(find.text('The creation of Adam and the fall'), findsOneWidget);
    expect(find.text('Surah2 30-39'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Musa and al-Khidr'), 200,
        scrollable: _verticalScrollable);
    expect(find.text('Surah18 60-82'), findsOneWidget);
  });

  testWidgets('a new track can read by juz from a chosen start',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('New track'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Khatm');
    await tester.tap(find.text('Juz (Para)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The beginning'));
    await tester.pumpAndSettle();
    // Opens on the unit already chosen - juz 1 - so step back to the list.
    await tester.tap(find.byTooltip('All juz'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Juz 12'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Juz 12'));
    await tester.pumpAndSettle();
    // Opening a juz readies its first verse.
    expect(find.text('Juz 12'), findsWidgets);
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(find.text('Juz 12'), findsOneWidget);

    await tester.tap(find.text('Create track'));
    await tester.pumpAndSettle();

    expect(find.text('Create track'), findsNothing);
    expect(find.bySemanticsLabel('Edit Khatm track'), findsOneWidget);
    expect(find.text('From Juz 12'), findsOneWidget);
  });

  testWidgets('a track can be switched to juz later', (tester) async {
    await pump(tester);

    await tester.tap(find.text('New track'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Later');
    await tester.tap(find.text('Create track'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Edit Later track'));
    await tester.pumpAndSettle();
    expect(find.text('Continue from'), findsOneWidget);
    await tester.tap(find.text('Juz (Para)'));
    await tester.pumpAndSettle();
    expect(find.text('Juz 1'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      RecitationTrackerManager.instance.state.settingsFor('Later').readByJuz,
      isTrue,
    );
  });

  testWidgets('a start can be typed down to the ayah', (tester) async {
    await pump(tester);

    await tester.tap(find.text('New track'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ahzab');
    await tester.tap(find.text('Juz (Para)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The beginning'));
    await tester.pumpAndSettle();

    // The picker's own search box, not the Quran screen's behind it.
    await tester.enterText(
        find.widgetWithIcon(TextField, Icons.search).last, '33:33');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.text('Juz 22 · Surah33 33'), findsOneWidget);

    // A tap in the grid moves the choice to that ayah.
    await tester.tap(find.bySemanticsLabel('Ayah 35'));
    await tester.pumpAndSettle();
    expect(find.text('Juz 22 · Surah33 35'), findsOneWidget);

    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create track'));
    await tester.pumpAndSettle();

    expect(find.text('From Juz 22 · 33:35'), findsOneWidget);
    final target =
        RecitationTrackerManager.instance.state.resumeTargetFor('Ahzab');
    expect(target.verse, const VerseKey(33, 35));
    expect(target.inJuz, isTrue);
  });

  testWidgets('a new track needs a name', (tester) async {
    await pump(tester);

    await tester.tap(find.text('New track'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create track'));
    await tester.pumpAndSettle();

    expect(find.text('Give the track a name'), findsOneWidget);
  });

  testWidgets('the Collections tab remembers the chip last picked',
      (tester) async {
    await pump(tester);
    await openCollection(tester, 'Saved');

    await tester.pumpWidget(const SizedBox());
    await pump(tester);
    await tester.tap(find.text('Collections'));
    await tester.pumpAndSettle();

    expect(find.text('No saved verses yet'), findsOneWidget);
  });
}

// The tab bar scrolls sideways too, so pick the vertical list.
final _verticalScrollable = find
    .byWidgetPredicate((widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down)
    .last;
