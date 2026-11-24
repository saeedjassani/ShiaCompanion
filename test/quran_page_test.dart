import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/quran_ali_verses.dart';
import 'package:shia_companion/data/quran_mahdi_verses.dart';
import 'package:shia_companion/models/recitation_tracker_state.dart';
import 'package:shia_companion/pages/quran/quran_page.dart';
import 'package:shia_companion/pages/quran/recitation_track_sheet.dart';
import 'package:shia_companion/widgets/app_toast.dart';
import 'package:shia_companion/widgets/page_chrome.dart';
import 'package:shia_companion/services/recitation_tracker_manager.dart';
import 'package:shia_companion/services/saved_verses_manager.dart';
import 'package:shia_companion/services/saved_verses_store.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'ui/firebase_test_doubles.dart';
import 'helpers/finders.dart';

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

  /// The tracks "Start Khatm" opened - recorded instead of opening the
  /// reader, which never settles in a widget test.
  late List<String> openedTracks;

  setUp(() {
    openedTracks = [];
    openNewRecitationTrack = (context, label) async => openedTracks.add(label);
  });

  tearDown(() {
    items = {};
    openNewRecitationTrack = openRecitationTrack;
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: QuranPage()));
    await tester.pumpAndSettle();
  }

  Future<void> openCollection(WidgetTester tester, String chip) async {
    // Tall enough that the listening card above the tabs leaves them and a
    // collection's first rows on screen.
    tester.view.physicalSize = Size(
      tester.view.physicalSize.width,
      1000 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collections'));
    await tester.pumpAndSettle();
    // The pills are one sideways row, so the later ones start off screen.
    // The row is dragged rather than the pill ensureVisible'd, which would
    // also scroll the page.
    final pill = find.widgetWithText(ChoicePill, chip);
    final row = find
        .ancestor(of: pill, matching: find.byType(Scrollable))
        .first;
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    while (tester.getRect(pill).right > screenWidth) {
      await tester.drag(row, const Offset(-150, 0));
      await tester.pumpAndSettle();
    }
    await tester.tap(pill);
    await tester.pumpAndSettle();
  }

  Future<void> tapNewTrack(WidgetTester tester) async {
    // Tracks made by earlier tests can push the card past the screen's edge.
    // (Dragged rather than ensureVisible'd, which would also scroll the page
    // and leave the card under the folded title bar.)
    // "Start a Khatm" until the first is made, "New Khatm" after.
    final newKhatm = find.text('New Khatm');
    final card = newKhatm.evaluate().isEmpty
        ? find.text('Start a Khatm')
        : newKhatm;
    await tester.drag(
      find.ancestor(of: card, matching: find.byType(Scrollable)).first,
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  /// Opens a new Khatm's "More options": reading by juz, and counting the
  /// verses before a mid-way start.
  Future<void> tapMoreOptions(WidgetTester tester) async {
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every surah with its verse count', (tester) async {
    await pump(tester);

    expect(find.text('Surah1'), findsOneWidget);
    expect(find.text('7 verses'), findsOneWidget);
    // Ayat al Kursi is not a surah and must not appear among the 114.
    expect(find.text('Ayat al Kursi'), findsNothing);
  });

  group('the tracking hint', () {
    const hint =
        'No need for a bookmark: a Khatm remembers where you '
        'stopped. Tap its card above to carry on. Surahs opened from the '
        "list below don't count towards it.";
    const viewsKey = 'quran_tracking_hint_views';

    testWidgets('shows on the first open and counts it', (tester) async {
      await pump(tester);

      expect(find.text(hint), findsOneWidget);
      expect(SP.prefs.getInt(viewsKey), 1);
    });

    testWidgets('closing it keeps it closed', (tester) async {
      await pump(tester);
      await tester.tap(findTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text(hint), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(find.text(hint), findsNothing);
    });

    testWidgets('stops after the first few opens', (tester) async {
      await SP.prefs.setInt(viewsKey, 5);
      await pump(tester);

      expect(find.text(hint), findsNothing);
    });
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

    await tester.tap(findTooltip('Recent sessions'));
    await tester.pumpAndSettle();

    expect(find.text('Recent sessions'), findsWidgets);
    expect(find.textContaining('No sessions yet'), findsOneWidget);
  });

  testWidgets('Go to a verse picks a surah, then a verse', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Go to a verse'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 2 · Choose a surah'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Surah2').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Step 2 of 2 · Choose a verse (1 to 286)'),
      findsOneWidget,
    );
    // Nothing is chosen until a verse is tapped.
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Choose a verse'),
          )
          .onPressed,
      isNull,
    );

    await tester.drag(find.text('1–50'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('251–286'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Verse 255'));
    await tester.pumpAndSettle();
    expect(find.text('Open Surah2 2:255'), findsOneWidget);
  });

  testWidgets('Go to a verse offers a reference typed in full', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Go to a verse'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '36:9');
    await tester.pumpAndSettle();

    expect(find.text('Go to Surah36 36:9'), findsOneWidget);
  });

  testWidgets('Go to a verse says when no surah matches', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Go to a verse'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No surah called “zzz”'), findsOneWidget);
  });

  testWidgets(
    'before any Khatm there is only a card to start one, saying what a '
    'Khatm is',
    (tester) async {
      await pump(tester);

      expect(find.text('Start reading'), findsNothing);
      expect(find.text('Start a Khatm'), findsOneWidget);
      expect(
        find.text(
          'Read the whole Quran from start to finish. '
          'Your place is saved as you go.',
        ),
        findsOneWidget,
      );
      expect(find.text('New Khatm'), findsNothing);
    },
  );

  testWidgets('everyday reading has no card among the Khatms', (tester) async {
    // Not awaited: the save queues behind the screen's earlier writes, which
    // only finish as the test's clock is pumped - as the sheet's own do.
    unawaited(
      RecitationTrackerManager.instance.logRecitation(
        id: 'everyday',
        label: unlabeledRecitationLabel,
        surah: 2,
        fromAyah: 1,
        toAyah: 141,
        syncRemote: false,
      ),
    );
    await pump(tester);

    expect(find.text('Surah2 141'), findsNothing);
    expect(find.textContaining('% of the Quran'), findsNothing);
    expect(find.text('Start a Khatm'), findsOneWidget);

    unawaited(RecitationTrackerManager.instance.removeEntry('everyday'));
    await tester.pumpAndSettle();
  });

  testWidgets('the Saved collection says so when nothing is kept', (
    tester,
  ) async {
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
    // The hint above the lists can leave the second row below the fold.
    await tester.scrollUntilVisible(
      find.text('Surah36 9'),
      200,
      scrollable: _verticalScrollable,
    );

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

    await tester.tap(findTooltip('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('No saved verses yet'), findsOneWidget);
    expect(SavedVersesManager.instance.state.verses, isEmpty);
  });

  testWidgets('verses saved on the device before syncing move into the list', (
    tester,
  ) async {
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
    'the Duas collection leaves Ayat al Kursi and the Quran zikrs to the '
    'Duas list',
    (tester) async {
      items = {
        ...items,
        'A2': 'Dua after reciting Holy Quran',
        'A4': 'Ayat al Kursi',
      };
      await pump(tester);
      await openCollection(tester, 'Duas');

      expect(find.text('Ayat al Kursi'), findsNothing);
      expect(find.text('Dua after reciting Holy Quran'), findsNothing);
    },
  );

  testWidgets('the Duas collection lists the duas of the Quran', (
    tester,
  ) async {
    await pump(tester);
    await openCollection(tester, 'Duas');
    await tester.scrollUntilVisible(
      find.text('Rabbana Atina fid-Dunya Hasanah'),
      200,
      scrollable: _verticalScrollable,
    );

    expect(find.text('Rabbana Atina fid-Dunya Hasanah'), findsOneWidget);
    expect(
      find.text('Surah2 201 · For good in this world and the hereafter'),
      findsOneWidget,
    );
  });

  testWidgets('the Imam Ali collection lists the curated verses', (
    tester,
  ) async {
    await pump(tester);
    await openCollection(tester, 'Imam Ali (a.s.)');

    // The list is lazy and runs well past one screen, so bring the verse
    // into view before looking for it.
    await tester.scrollUntilVisible(
      find.text('Surah5 55'),
      200,
      scrollable: _verticalScrollable,
    );

    expect(find.text('Surah5 55'), findsOneWidget);
    expect(
      find.text(aliRelatedNoteFor(const VerseKey(5, 55))!),
      findsOneWidget,
    );
  });

  testWidgets('the Imam al-Mahdi collection lists the curated verses', (
    tester,
  ) async {
    await pump(tester);
    await openCollection(tester, 'Imam al-Mahdi (a.t.f.s.)');

    await tester.scrollUntilVisible(
      find.text('Surah11 86'),
      200,
      scrollable: _verticalScrollable,
    );

    expect(find.text('Surah11 86'), findsOneWidget);
    expect(
      find.text(mahdiRelatedNoteFor(const VerseKey(11, 86))!),
      findsOneWidget,
    );
  });

  testWidgets('the Prophets collection groups stories under each prophet', (
    tester,
  ) async {
    await pump(tester);
    await openCollection(tester, 'Prophets');

    expect(find.text('Adam (a.s.)'), findsOneWidget);
    expect(find.text('The creation of Adam and the fall'), findsOneWidget);
    expect(find.text('Surah2 30-39'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Musa and al-Khidr'),
      200,
      scrollable: _verticalScrollable,
    );
    expect(find.text('Surah18 60-82'), findsOneWidget);
  });

  testWidgets('a new track can read by juz from a chosen start', (
    tester,
  ) async {
    await pump(tester);

    await tapNewTrack(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Khatm');
    // Reading by juz waits under More options.
    expect(find.text('Juz (Para)'), findsNothing);
    await tapMoreOptions(tester);
    expect(find.text('More options'), findsNothing);
    await tester.tap(find.text('Juz (Para)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The beginning'));
    await tester.pumpAndSettle();
    // Opens on the list, with the beginning already chosen.
    expect(find.text('Choose a verse'), findsOneWidget);
    expect(find.text('Juz 1'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Juz 12'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Juz 12'));
    await tester.pumpAndSettle();
    // Opening a juz readies its first verse.
    expect(find.text('Juz 12'), findsWidgets);
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(find.text('Juz 12'), findsOneWidget);

    await tester.tap(find.text('Start Khatm'));
    await tester.pumpAndSettle();

    expect(find.text('Start Khatm'), findsNothing);
    expect(find.bySemanticsLabel('Edit Khatm'), findsOneWidget);
    expect(find.text('Juz 12'), findsOneWidget);
    // Starting it opens the reader at its start.
    expect(openedTracks, ['Khatm']);
    final target = RecitationTrackerManager.instance.state.resumeTargetFor(
      'Khatm',
    );
    expect(target.inJuz, isTrue);
    expect(target.juz, 12);
  });

  testWidgets('a track can be switched to juz later', (tester) async {
    await pump(tester);

    await tapNewTrack(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Later');
    await tester.tap(find.text('Start Khatm'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Edit Later'));
    await tester.pumpAndSettle();
    expect(find.text('CONTINUE FROM'), findsOneWidget);
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

  testWidgets('a track can be deleted, after asking', (tester) async {
    await pump(tester);

    await tapNewTrack(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Gone');
    await tester.tap(find.text('Start Khatm'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Edit Gone'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete Khatm'));
    await tester.tap(find.text('Delete Khatm'));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Gone"?'), findsOneWidget);

    // Cancel keeps it. (The sheet behind has a Cancel of its own.)
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(RecitationTrackerManager.instance.state.labels, contains('Gone'));

    await tester.tap(find.text('Delete Khatm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      RecitationTrackerManager.instance.state.labels,
      isNot(contains('Gone')),
    );
    expect(find.text('Gone'), findsNothing);
    expect(find.text('Delete Khatm'), findsNothing);
  });

  testWidgets('a start can be typed down to the ayah', (tester) async {
    await pump(tester);

    await tapNewTrack(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ahzab');
    await tapMoreOptions(tester);
    await tester.tap(find.text('Juz (Para)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The beginning'));
    await tester.pumpAndSettle();

    // The picker's own search box, not the Quran screen's behind it.
    await tester.enterText(
      find.widgetWithIcon(TextField, Icons.search).last,
      '33:33',
    );
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.text('Juz 22 · Surah33 33'), findsOneWidget);

    // A tap in the grid moves the choice to that ayah.
    await tester.tap(find.bySemanticsLabel('Ayah 35'));
    await tester.pumpAndSettle();
    expect(find.text('Juz 22 · Surah33 35'), findsOneWidget);

    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Khatm'));
    await tester.pumpAndSettle();

    expect(find.text('Juz 22 · 33:35'), findsOneWidget);
    final target = RecitationTrackerManager.instance.state.resumeTargetFor(
      'Ahzab',
    );
    expect(target.verse, const VerseKey(33, 35));
    expect(target.inJuz, isTrue);
  });

  testWidgets('a new track needs a name', (tester) async {
    await pump(tester);

    await tapNewTrack(tester);
    await tester.tap(find.text('Start Khatm'));
    await tester.pumpAndSettle();

    expect(find.text('Give the Khatm a name'), findsOneWidget);
    expect(openedTracks, isEmpty);
  });

  testWidgets('a new track cannot take the default track\'s name', (
    tester,
  ) async {
    await pump(tester);

    await tapNewTrack(tester);
    await tester.enterText(find.byType(TextField).first, 'other reading');
    await tester.tap(find.text('Start Khatm'));
    await tester.pumpAndSettle();

    expect(
      find.text('There is already a Khatm called "other reading"'),
      findsOneWidget,
    );
  });

  testWidgets('says once that My reading became a Khatm, and Undo deletes it', (
    tester,
  ) async {
    final manager = RecitationTrackerManager.instance;
    unawaited(
      manager.addLabel(
        'My reading',
        settings: RecitationTrackSettings(
          startAt: const VerseKey(2, 201),
          startSetAt: DateTime.now(),
        ),
      ),
    );
    await SP.prefs.setString(
      RecitationTrackerManager.myReadingPortNoticeKey,
      'My reading',
    );
    await pump(tester);

    const notice =
        '"My reading" is now a Khatm, so it keeps your place as '
        'before. Reading opened from the surah list no longer counts towards '
        'it.';
    expect(find.text(notice), findsOneWidget);
    expect(find.text('Surah2 201'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text(notice), findsNothing);
    expect(manager.state.labels, isNot(contains('My reading')));
    expect(
      SP.prefs.getString(RecitationTrackerManager.myReadingPortNoticeKey),
      isNull,
    );
  });

  group('opening from the list while a Khatm is up to it', () {
    // Not awaited, as elsewhere here: the state changes at once, and the
    // backup it then waits on never answers in a test.
    void addFamilyAt(VerseKey verse) {
      unawaited(
        RecitationTrackerManager.instance.addLabel(
          'Family',
          settings: RecitationTrackSettings(
            startAt: verse,
            startSetAt: DateTime.now(),
          ),
        ),
      );
    }

    testWidgets('offers the Khatm only where it is up to', (tester) async {
      addFamilyAt(const VerseKey(2, 201));
      await tester.pump();
      final state = RecitationTrackerManager.instance.state;

      expect(khatmToOffer(state, surah: 2), 'Family');
      expect(khatmToOffer(state, juz: juzOf(2, 201)), 'Family');
      expect(khatmToOffer(state, surah: 3), isNull);
      expect(khatmToOffer(state, juz: 30), isNull);
    });

    testWidgets('a toast says where the Khatm is, with a way to it', (
      tester,
    ) async {
      addFamilyAt(const VerseKey(2, 201));
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          navigatorObservers: [toastRouteObserver],
          home: const Scaffold(body: SizedBox()),
        ),
      );

      offerKhatmPlace('Family');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Your Khatm "Family" has reached Surah2 201.'),
        findsOneWidget,
      );
      expect(find.text('Continue Khatm'), findsOneWidget);
      // No question to answer: it goes by itself.
      expect(find.byType(Dialog), findsNothing);
      await tester.pump(khatmToastDuration);
      await tester.pumpAndSettle();
      expect(find.text('Continue Khatm'), findsNothing);
    });
  });

  testWidgets('the Collections view remembers the collection last picked', (
    tester,
  ) async {
    await pump(tester);
    await openCollection(tester, 'Saved');

    await tester.pumpWidget(const SizedBox());
    await pump(tester);
    await tester.tap(find.text('Collections'));
    await tester.pumpAndSettle();

    expect(find.text('No saved verses yet'), findsOneWidget);
    // Scrolled into view, though it is the last pill of the row.
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(
      tester.getRect(find.widgetWithText(ChoicePill, 'Saved')).right,
      lessThanOrEqualTo(screenWidth),
    );
  });
}

// The track cards scroll sideways too, so pick the vertical list.
final _verticalScrollable = find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .last;
