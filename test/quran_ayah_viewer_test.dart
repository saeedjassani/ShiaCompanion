import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';

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
  int? initialAyah,
  ValueChanged<QuranReadingPosition>? onAyahPosition,
  ValueChanged<AyahActionRequest>? onAyahAction,
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
          initialAyah: initialAyah,
          onAyahPositionChanged: onAyahPosition,
          onAyahAction: onAyahAction,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
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
          tappedAyah = request.ayah;
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
        request!.scrollOffset,
        greaterThan(0),
        reason: 'a verse scrolled to must report a position past the top',
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
        initialAyah: 20,
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
      expect(reports.last.ayah, greaterThan(1));
    });

    testWidgets('a lookup that turns into reading becomes the position',
        (tester) async {
      final reports = <QuranReadingPosition>[];
      await _pump(
        tester,
        content: _surahContent(ayahs: 40),
        surahNumber: 1,
        initialAyah: 10,
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
        initialAyah: 25,
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
