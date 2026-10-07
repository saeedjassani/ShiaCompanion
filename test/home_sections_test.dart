import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/models/recitation_tracker_state.dart';
import 'package:shia_companion/navigation/home_menu.dart';
import 'package:shia_companion/pages/all_features_page.dart';
import 'package:shia_companion/pages/home/coming_up_section.dart';
import 'package:shia_companion/pages/home/continue_section.dart';
import 'package:shia_companion/pages/home/hadith_card.dart';
import 'package:shia_companion/pages/home/shortcuts_section.dart';
import 'package:shia_companion/services/home_shortcuts_store.dart';
import 'package:shia_companion/services/library_progress_store.dart';
import 'package:shia_companion/services/zikr_bookmark_store.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

Future<void> _prefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  await SP.init();
}

Widget _app(Widget child) => MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('HomeShortcutsStore', () {
    setUp(() => _prefs());

    test('starts with the agreed defaults', () {
      expect(HomeShortcutsStore.instance.ids, HomeShortcutsStore.defaultIds);
      expect(HomeShortcutsStore.instance.isCustomized, isFalse);
    });

    test('saves a choice, without repeats and at most eleven', () async {
      var notified = 0;
      void listener() => notified++;
      HomeShortcutsStore.instance.addListener(listener);
      addTearDown(() => HomeShortcutsStore.instance.removeListener(listener));

      await HomeShortcutsStore.instance.save([
        'duas',
        'duas',
        '',
        'a',
        'b',
        'c',
        'd',
        'e',
        'f',
        'g',
        'h',
        'i',
        'j',
        'k',
        'l'
      ]);

      expect(HomeShortcutsStore.instance.ids,
          ['duas', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j']);
      expect(HomeShortcutsStore.instance.isCustomized, isTrue);
      expect(notified, 1);
    });

    test('an empty choice is a choice, not the defaults', () async {
      await HomeShortcutsStore.instance.save(const []);
      expect(HomeShortcutsStore.instance.ids, isEmpty);
    });

    test('applies a choice synced from another device', () async {
      await HomeShortcutsStore.instance.applySynced(['qibla_finder']);
      expect(HomeShortcutsStore.instance.ids, ['qibla_finder']);
    });
  });

  group('splitHadith', () {
    test('takes the reference off its own last line', () {
      final parts = splitHadith(
          "Imam Ali (AS) said, 'Be patient.'\n[Ghurar al-Hikam, no. 2746]");
      expect(parts.text, "Imam Ali (AS) said, 'Be patient.'");
      expect(parts.source, 'Ghurar al-Hikam, no. 2746');
    });

    test('takes an inline reference that has a number in it', () {
      final parts = splitHadith(
          "Imam Ali (AS) said, ‘Cheerfulness is the trait of the free.’ "
          '[Ghurar al-Hikam, no. 656]');
      expect(parts.source, 'Ghurar al-Hikam, no. 656');
      expect(parts.text, endsWith('free.’'));
    });

    test('leaves an honorific in brackets in the text', () {
      const hadith = 'Said Imam al-Sadiq [a.s.]';
      expect(splitHadith(hadith).source, isNull);
      expect(splitHadith(hadith).text, hadith);
    });

    test('a hadith with no reference is all text', () {
      expect(splitHadith('Patience is a light.').source, isNull);
    });
  });

  group('Coming up', () {
    test('says Today only for today', () {
      final now = DateTime(2026, 10, 4, 15);
      ComingUpEvent on(DateTime date) =>
          ComingUpEvent(date: date, title: '', hijri: '');
      expect(on(DateTime(2026, 10, 4)).whenFrom(now), 'Today');
      expect(on(DateTime(2026, 10, 5)).whenFrom(now), 'Tomorrow');
      expect(on(DateTime(2026, 10, 17)).whenFrom(now), 'In 13 days');
    });

    test('lists the next two events, saying what happened', () {
      // 1 Muharram 1448 falls on 16 June 2026.
      final events = upcomingEvents(
        now: DateTime(2026, 6, 10),
        offsetDays: 0,
        events: {
          '01-01': {'content': 'Beginning of Moharram', 'color': 0},
          '01-03': {'content': 'Birth of Imam Someone (a.s.)', 'color': 0},
          '01-05': {'content': 'Later event', 'color': 0},
        },
      );
      expect(events, hasLength(2));
      expect(events.first.title, 'Beginning of Moharram');
      expect(events.last.title, 'Birth of Imam Someone (a.s.)');
      expect(events.last.hijri, startsWith('3 '));
    });
  });

  group('Continue', () {
    // Surah names come from the zikr index, loaded at startup in the app.
    setUp(() => items[uidForSurah(2)!] = '2: Al-Baqarah البقرة');
    tearDown(() => items.remove(uidForSurah(2)));

    final recitations = RecitationTrackerState({
      'r1': RecitationEntry(
        id: 'r1',
        label: unlabeledRecitationLabel,
        recitedAt: DateTime(2026, 10, 3),
        surah: 2,
        fromAyah: 130,
        toAyah: 141,
      ),
    });
    final bookmark = ZikrBookmark(
      uid: 'E1',
      title: 'Dua Kumayl',
      tabIndex: 0,
      scrollOffset: 0,
      lineIndex: 4,
      updatedAt: DateTime(2026, 10, 4),
    );
    final library = LibraryProgress(
      bookSlug: 'book',
      bookTitle: 'A Book',
      chapterSlug: 'ch1',
      chapterTitle: 'Chapter 1',
      chapterIndex: 0,
      pageIndex: 0,
      pageCount: 3,
      fontSize: 18,
      updatedAt: DateTime(2026, 10, 1),
    );

    test('one card per kind, newest first', () {
      final entries = continueEntries(
        recitations: recitations,
        bookmarks: [bookmark],
        library: [library],
        includeQuran: true,
      );
      expect(entries.map((e) => e.kind), [
        ContinueKind.bookmark,
        ContinueKind.quran,
        ContinueKind.library,
      ]);
      expect(entries[0].caption, 'Dua · bookmark');
      expect(entries[1].title, 'Al-Baqarah');
      expect(entries[1].subtitle, 'Verse 141 of 286');
      expect(entries[1].progress, closeTo(141 / 286, 1e-9));
      expect(entries[2].title, 'A Book');
    });

    test('keeps the Quran card for whoever has the Quran screen', () {
      final entries = continueEntries(
        recitations: recitations,
        bookmarks: const [],
        library: const [],
        includeQuran: false,
      );
      expect(entries, isEmpty);
    });

    test('names a bookmark by its current title', () {
      final entries = continueEntries(
        recitations: RecitationTrackerState(),
        bookmarks: [bookmark],
        library: const [],
        includeQuran: false,
        titles: {'E1': 'Dua Kumayl (new title)'},
      );
      expect(entries.single.title, 'Dua Kumayl (new title)');
    });
  });

  group('Shortcuts', () {
    setUp(() => _prefs());

    testWidgets('shows the seven shortcuts, then All features', (tester) async {
      var allFeatures = 0;
      await tester.pumpWidget(_app(ShortcutsSection(
        onOpen: (_) {},
        onOpenAllFeatures: () => allFeatures++,
      )));

      for (final label in [
        'Duas',
        'Ziyarats',
        "Today's Recitations",
        'Munajaat',
        'Calendar',
        'Tasbeeh',
        'Qibla',
        'All features',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await tester.tap(find.text('All features'));
      expect(allFeatures, 1);
    });

    testWidgets('has no heading and grows to a third row past seven',
        (tester) async {
      await HomeShortcutsStore.instance.save([
        'duas',
        'ziyarats',
        'today_s_recitations',
        'munajaat',
        'calendar_prayer_times',
        'tasbeeh_counter',
        'qibla_finder',
        'library',
      ]);
      await tester.pumpWidget(_app(ShortcutsSection(
        onOpen: (_) {},
        onOpenAllFeatures: () {},
      )));

      expect(find.text('Shortcuts'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      // Eight picks and All features: two full rows, then All features alone.
      final duas = tester.getCenter(find.text('Duas'));
      final library = tester.getCenter(find.text('Library'));
      final allFeatures = tester.getCenter(find.text('All features'));
      expect(library.dy, greaterThan(duas.dy));
      expect(allFeatures.dy, greaterThan(library.dy));
      expect(allFeatures.dx, closeTo(duas.dx, 1));
    });

    Future<void> pumpEditor(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(Builder(
        builder: (context) => Column(
          children: [
            ShortcutsSection(onOpen: (_) {}, onOpenAllFeatures: () {}),
            TextButton(
              onPressed: () => showShortcutsEditor(context),
              child: const Text('Open editor'),
            ),
          ],
        ),
      )));
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
    }

    testWidgets('the editor removes, adds and saves on Done', (tester) async {
      await pumpEditor(tester);

      expect(find.text('ON YOUR HOME · 7 OF 11'), findsOneWidget);

      // Each row reads as one stop, "Remove Qibla" first; activating it
      // removes, as a screen reader's double-tap would.
      tester.semantics.tap(find.semantics.byLabel(RegExp(r'^Remove Qibla')));
      await tester.pump();
      expect(find.text('ON YOUR HOME · 6 OF 11'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Add Library'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(HomeShortcutsStore.instance.ids, [
        'duas',
        'ziyarats',
        'today_s_recitations',
        'munajaat',
        'calendar_prayer_times',
        'tasbeeh_counter',
        'library',
      ]);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Qibla'), findsNothing);
    });

    testWidgets('the editor stops adding at eleven', (tester) async {
      await HomeShortcutsStore.instance.save([
        for (final item in shortcutCandidateMenuItems.take(11))
          item.analyticsId,
      ]);
      await pumpEditor(tester);

      expect(find.text('ON YOUR HOME · 11 OF 11'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(RegExp(r'^Add ')).first)
            .flagsCollection
            .isEnabled,
        isNot(true),
      );
    });

    testWidgets('Cancel leaves the shortcuts as they were', (tester) async {
      await pumpEditor(tester);
      tester.semantics.tap(find.semantics.byLabel(RegExp(r'^Remove Duas')));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(HomeShortcutsStore.instance.isCustomized, isFalse);
      expect(find.text('Duas'), findsOneWidget);
    });
  });

  group('All features', () {
    setUp(() => _prefs());

    testWidgets('marks what is already on Home', (tester) async {
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const AllFeaturesPage(),
      ));

      // The large title, and the bar it folds into on scrolling.
      expect(find.text('All features'), findsWidgets);
      expect(find.bySemanticsLabel('Duas, on your Home'), findsOneWidget);
      expect(find.bySemanticsLabel('Library'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Favorites'), findsNothing);
      // Every feature on the page, so none is lost with the old grid.
      for (final item in allFeaturesMenuItems) {
        expect(find.text(item.label), findsOneWidget, reason: item.label);
      }
    });
  });
}
