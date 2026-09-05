import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';
import 'package:shia_companion/utils/quran_index.dart';

/// Three ayahs behind a Bismillah, in the triplet shape every surah uses.
String _surahContent({int ayahs = 3}) {
  final lines = <String>['بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ'];
  for (var ayah = 1; ayah <= ayahs; ayah++) {
    lines.add('اَلْحَمْدُ لِلّٰهِ رَبِّ الْعٰلَمِيْنَ ($ayah)');
    lines.add('TRANSLITERATION $ayah');
    lines.add('Translation of ayah $ayah');
  }
  return lines.join('\n');
}

Future<void> _pump(
  WidgetTester tester, {
  required String content,
  int? surahNumber,
  VerseKey? initialVerse,
  ValueChanged<QuranReadingPosition>? onAyahPosition,
  ValueChanged<AyahActionRequest>? onAyahAction,
  AyahIndex? ayahIndex,
  int? bookmarkLineIndex,
  VerseKey? bookmarkVerse,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ZikrContentViewerWidget(
          tabContents: <String>[content],
          selectedTabIndex: 0,
          onTabChanged: (_) {},
          hasMerits: false,
          onShowMerits: () {},
          onLinkTap: (_) async {},
          code: '012',
          surahNumber: surahNumber,
          initialVerse: initialVerse,
          ayahIndex: ayahIndex,
          initialBookmarkTabIndex:
              bookmarkLineIndex == null && bookmarkVerse == null ? null : 0,
          initialBookmarkLineIndex: bookmarkLineIndex,
          initialBookmarkVerse: bookmarkVerse,
          onAyahPositionChanged: onAyahPosition,
          onAyahAction: onAyahAction,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Two short surahs stitched together, the way a juz portion arrives.
({String data, AyahIndex index}) _portion() {
  final lines = <String>[];
  final spans = <AyahSpan>[];

  for (final surah in [4, 5]) {
    for (var ayah = 1; ayah <= 6; ayah++) {
      final start = lines.length;
      lines.add('اَلْحَمْدُ لِلّٰهِ ($ayah)');
      lines.add('TRANSLITERATION $surah $ayah');
      lines.add('Translation of $surah:$ayah');
      spans.add(
        AyahSpan(
          surah: surah,
          ayah: ayah,
          start: start,
          end: lines.length,
          startsSurah: ayah == 1 ? surahInfoFor(surah) : null,
        ),
      );
    }
  }

  return (data: lines.join('\n'), index: AyahIndex.fromSpans(spans));
}

/// Drags the reading list until [finder] is actually on screen.
///
/// `scrollUntilVisible` cannot be used here: the viewer nests a ListView inside
/// a PageView, so it finds two scrollables and refuses to choose. Nor is "the
/// finder matches" enough on its own - a ListView builds a little beyond the
/// fold, so a match can still be below the viewport and untappable.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  bool onScreen() {
    if (finder.evaluate().isEmpty) return false;
    final centre = tester.getCenter(finder);
    return centre.dy >= 0 && centre.dy <= tester.view.physicalSize.height;
  }

  for (var attempt = 0; attempt < 20 && !onScreen(); attempt++) {
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('a juz portion', () {
    setUp(() {
      items = {'A8': '4: An-Nisa النساء', 'A9': '5: Al-Maidah المائدة'};
    });

    tearDown(() => items = {});

    testWidgets('draws no rule of its own above the first surah name',
        (tester) async {
      // A divider here sat with nothing above it at the top of a juz, and
      // stacked under the previous verse's separator at a boundary.
      final portion = _portion();
      await _pump(
        tester,
        content: portion.data,
        ayahIndex: portion.index,
      );

      final heading = find.text('4. An-Nisa');
      expect(heading, findsOneWidget);
      // The heading's own Column is the innermost one around it; the outer
      // ones belong to the block and the list, which do draw separators.
      expect(
        find.descendant(
          of: find.ancestor(of: heading, matching: find.byType(Column)).first,
          matching: find.byType(Divider),
        ),
        findsNothing,
      );
    });

    testWidgets('names each surah where the reading crosses into it',
        (tester) async {
      final portion = _portion();
      await _pump(
        tester,
        content: portion.data,
        ayahIndex: portion.index,
      );

      expect(find.text('4. An-Nisa'), findsOneWidget);
      // The join is below the fold on a phone-sized viewport, so reach it the
      // way a reader would.
      await _scrollTo(tester, find.text('5. Al-Maidah'));
      expect(find.text('5. Al-Maidah'), findsOneWidget);
    });

    testWidgets('numbers restart at the boundary rather than running on',
        (tester) async {
      final portion = _portion();
      await _pump(
        tester,
        content: portion.data,
        ayahIndex: portion.index,
      );

      expect(find.text('Translation of 4:1'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Al-Maidah opens at 1 again rather than continuing an-Nisa's numbering,
      // which is what it would do if the portion were treated as one surah.
      await _scrollTo(tester, find.text('Translation of 5:1'));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('7'), findsNothing);
    });

    testWidgets('a tapped verse reports the surah it actually belongs to',
        (tester) async {
      final portion = _portion();
      AyahActionRequest? request;
      await _pump(
        tester,
        content: portion.data,
        ayahIndex: portion.index,
        onAyahAction: (value) => request = value,
      );

      await _scrollTo(tester, find.text('Translation of 5:2'));
      await tester.tap(find.text('Translation of 5:2'));
      await tester.pumpAndSettle();

      expect(request!.verse, const VerseKey(5, 2));
    });

    testWidgets('opens at the right surah, not just the right ayah number',
        (tester) async {
      // Ayah 2 exists in both surahs of this portion. Resuming at 5:2 must
      // land in al-Maidah - carrying only the number would land in an-Nisa.
      final portion = _portion();
      await _pump(
        tester,
        content: portion.data,
        ayahIndex: portion.index,
        initialVerse: const VerseKey(5, 2),
      );

      expect(find.text('Translation of 5:2'), findsOneWidget);
      expect(find.text('Translation of 4:2'), findsNothing);
    });

    testWidgets('the reported reading position changes surah across the join',
        (tester) async {
      final portion = _portion();
      final reports = <QuranReadingPosition>[];
      await _pump(
        tester,
        content: portion.data,
        ayahIndex: portion.index,
        onAyahPosition: reports.add,
      );

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(reports, isNotEmpty);
      expect(
        reports.last.verse.surah,
        5,
        reason: 'scrolling past the join is reading al-Maidah, not an-Nisa',
      );
    });
  });

  group('the bookmark marker', () {
    setUp(() {
      items = {'A8': '4: An-Nisa النساء', 'A9': '5: Al-Maidah المائدة'};
    });

    tearDown(() => items = {});

    testWidgets('a bookmark with only an ayah still marks its verse',
        (tester) async {
      // The reported bug: a bookmark taken while reading a juz carries the
      // verse but no line index, because the line was measured inside the
      // portion. Nothing resolved it, so the surah's own page drew nothing.
      await _pump(
        tester,
        content: _surahContent(),
        surahNumber: 1,
        bookmarkVerse: const VerseKey(1, 2),
      );

      expect(find.text('Bookmarked'), findsNothing,
          reason: 'the ayah path marks the block, not a line label');
      final marked = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Translation of ayah 2'),
              matching: find.byType(Container),
            )
            .last,
      );
      expect(marked.decoration, isNotNull);
    });

    testWidgets('the verse is resolved against the portion being shown',
        (tester) async {
      final portion = _portion();
      await _pump(
        tester,
        content: portion.data,
        ayahIndex: portion.index,
        bookmarkVerse: const VerseKey(4, 2),
      );

      // 4:2 and 5:2 share an ayah number; only the right surah's block is
      // marked, which is what a line index alone could never express.
      expect(find.text('Translation of 4:2'), findsOneWidget);
    });

    testWidgets('a recorded line index still wins over the verse',
        (tester) async {
      await _pump(
        tester,
        content: _surahContent(),
        surahNumber: 1,
        bookmarkLineIndex: 1,
        bookmarkVerse: const VerseKey(1, 3),
      );

      // Line 1 is ayah 1's Arabic. If the verse had won, ayah 3 would be
      // marked instead.
      expect(find.text('Translation of ayah 1'), findsOneWidget);
    });

    testWidgets('no bookmark at all marks nothing', (tester) async {
      await _pump(tester, content: _surahContent(), surahNumber: 1);

      expect(find.text('Bookmarked'), findsNothing);
    });
  });

  group('non-surah zikrs are untouched', () {
    // The whole compatibility guarantee of ayah mode is that it is opt-in.
    // Every other zikr must keep the line-by-line rendering it has always had.
    testWidgets('no surah number means no ayah blocks and no badges',
        (tester) async {
      await _pump(tester, content: _surahContent());

      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
      // Each line is still its own item, so the translation lines are separate
      // widgets rather than children of a verse block.
      expect(find.text('Translation of ayah 1'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('a verse cannot be tapped when there is no ayah index',
        (tester) async {
      var actions = 0;
      await _pump(
        tester,
        content: _surahContent(),
        onAyahAction: (_) => actions++,
      );

      await tester.tap(find.text('Translation of ayah 1'));
      await tester.pumpAndSettle();

      expect(actions, 0);
    });
  });

  group('ayah mode', () {
    testWidgets('numbers each verse and leaves the Bismillah unnumbered',
        (tester) async {
      await _pump(tester, content: _surahContent(), surahNumber: 1);

      for (final ayah in ['1', '2', '3']) {
        expect(find.text(ayah), findsOneWidget);
      }
      // Four Arabic lines, but only three of them are ayahs.
      expect(find.byType(Divider), findsNWidgets(4));
    });

    testWidgets('a verse and its translation are one item', (tester) async {
      await _pump(
        tester,
        content: _surahContent(),
        surahNumber: 1,
        onAyahAction: (_) {},
      );

      final block = find.ancestor(
        of: find.text('Translation of ayah 2'),
        matching: find.byType(InkWell),
      );
      expect(block, findsOneWidget);
      expect(
        find.descendant(of: block, matching: find.text('TRANSLITERATION 2')),
        findsOneWidget,
      );
    });

    testWidgets('tapping a verse reports it with its text', (tester) async {
      int? tappedAyah;
      String? tappedText;
      await _pump(
        tester,
        content: _surahContent(),
        surahNumber: 1,
        onAyahAction: (request) {
          tappedAyah = request.verse.ayah;
          tappedText = request.text;
        },
      );

      await tester.tap(find.text('Translation of ayah 2'));
      await tester.pumpAndSettle();

      expect(tappedAyah, 2);
      expect(tappedText, contains('Translation of ayah 2'));
      expect(tappedText, contains('(2)'));
    });

    testWidgets('a tapped verse carries where it sits, so it can be bookmarked',
        (tester) async {
      AyahActionRequest? request;
      await _pump(
        tester,
        content: _surahContent(ayahs: 40),
        surahNumber: 1,
        onAyahAction: (value) => request = value,
      );

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Translation of ayah').first);
      await tester.pumpAndSettle();

      expect(request, isNotNull);
      expect(
        request!.lineIndex,
        greaterThan(0),
        reason: 'a verse scrolled to must report a line past the first',
      );
    });

    testWidgets('the Bismillah offers no verse actions', (tester) async {
      var actions = 0;
      await _pump(
        tester,
        content: _surahContent(),
        surahNumber: 1,
        onAyahAction: (_) => actions++,
      );

      await tester.tap(find.text('بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ'));
      await tester.pumpAndSettle();

      expect(actions, 0, reason: 'the Bismillah is not a numbered verse');
    });
  });

  group('reading position', () {
    testWidgets('a lookup is not reported as reading', (tester) async {
      final reports = <QuranReadingPosition>[];
      await _pump(
        tester,
        content: _surahContent(ayahs: 40),
        surahNumber: 1,
        initialVerse: const VerseKey(1, 20),
        onAyahPosition: reports.add,
      );

      // Jumping to a linked verse scrolls the list, but nothing here came
      // from the reader's hand, so nothing may claim it did.
      expect(
        reports.every((report) => !report.fromUserScroll),
        isTrue,
        reason: 'a programmatic jump must never look like reading',
      );
    });

    testWidgets('dragging is reported as reading', (tester) async {
      final reports = <QuranReadingPosition>[];
      await _pump(
        tester,
        content: _surahContent(ayahs: 40),
        surahNumber: 1,
        onAyahPosition: reports.add,
      );

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(reports, isNotEmpty);
      expect(reports.last.fromUserScroll, isTrue);
      expect(reports.last.verse.ayah!, greaterThan(1));
    });

    testWidgets('a lookup that turns into reading becomes the position',
        (tester) async {
      final reports = <QuranReadingPosition>[];
      await _pump(
        tester,
        content: _surahContent(ayahs: 40),
        surahNumber: 1,
        initialVerse: const VerseKey(1, 10),
        onAyahPosition: reports.add,
      );

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(reports.last.fromUserScroll, isTrue);
    });

    testWidgets('nothing is reported for a zikr that is not a surah',
        (tester) async {
      final reports = <QuranReadingPosition>[];
      await _pump(
        tester,
        content: _surahContent(ayahs: 40),
        onAyahPosition: reports.add,
      );

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(reports, isEmpty);
    });
  });

  group('opening at a verse', () {
    testWidgets('scrolls to the requested ayah', (tester) async {
      await _pump(
        tester,
        content: _surahContent(ayahs: 40),
        surahNumber: 1,
        initialVerse: const VerseKey(1, 25),
      );

      expect(find.text('Translation of ayah 25'), findsOneWidget);
      expect(find.text('Translation of ayah 1'), findsNothing);
    });

    testWidgets('opens at the top when no verse is asked for', (tester) async {
      await _pump(
        tester,
        content: _surahContent(ayahs: 40),
        surahNumber: 1,
      );

      expect(find.text('Translation of ayah 1'), findsOneWidget);
    });
  });
}
