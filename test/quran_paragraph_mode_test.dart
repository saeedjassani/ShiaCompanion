import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/zikr/zikr_content_parser.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';
import 'package:shia_companion/utils/quran_index.dart';

const _bismillah = 'بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ';

/// A Bismillah and [ayahs] verses in the `012` triplet shape every surah
/// uses, with a rukūʿ sign closing each verse listed in [rukuAfter].
String _surahContent({int ayahs = 6, Set<int> rukuAfter = const {3}}) {
  final lines = <String>[_bismillah];
  for (var ayah = 1; ayah <= ayahs; ayah++) {
    final ruku = rukuAfter.contains(ayah) ? rukuMark : '';
    lines.add('اَلْحَمْدُ لِلّٰهِ رَبِّ الْعٰلَمِيْنَ$ruku\u200f($ayah)');
    lines.add('TRANSLITERATION $ayah');
    lines.add('Translation of ayah $ayah');
  }
  return lines.join('\n');
}

Future<void> _pump(
  WidgetTester tester, {
  required String content,
  int? surahNumber = 1,
  AyahIndex? ayahIndex,
  VerseKey? initialVerse,
  Set<VerseKey> savedVerses = const {},
  ValueChanged<AyahActionRequest>? onAyahAction,
  ValueChanged<QuranReadingPosition>? onAyahPosition,
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
          ayahIndex: ayahIndex,
          initialVerse: initialVerse,
          savedVerses: savedVerses,
          onAyahAction: onAyahAction,
          onAyahPositionChanged: onAyahPosition,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The flowing paragraph whose text contains [needle].
Finder _paragraphContaining(String needle) => find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.textDirection == TextDirection.rtl &&
          widget.text.toPlainText().contains(needle),
    );

void main() {
  group('quranParagraphSpanRuns', () {
    ParsedZikrContent parse(String content) =>
        ZikrContentParser.parseContent(content, hideHeaderLine: false, code: '012');

    test('the Bismillah stands alone and a rukuʿ closes a passage', () {
      final content = _surahContent(ayahs: 6, rukuAfter: {3});
      final parsed = parse(content);
      final index = AyahIndex.fromParsedContent(parsed, surah: 1);

      // Span 0 is the Bismillah; spans 1..6 are ayahs 1..6.
      expect(quranParagraphSpanRuns(index, parsed), [
        [0],
        [1, 2, 3],
        [4, 5, 6],
      ]);
    });

    test('a surah with no marks is capped rather than one endless passage',
        () {
      final content = _surahContent(ayahs: 10, rukuAfter: {});
      final parsed = parse(content);
      final index = AyahIndex.fromParsedContent(parsed, surah: 1);

      final runs = quranParagraphSpanRuns(index, parsed, maxVerses: 4);
      expect(runs.skip(1).map((run) => run.length), [4, 4, 2]);
    });

    test('a new surah always starts a new passage', () {
      items = {'A8': '4: An-Nisa النساء', 'A9': '5: Al-Maidah المائدة'};
      addTearDown(() => items = {});

      final lines = <String>[];
      final spans = <AyahSpan>[];
      for (final surah in [4, 5]) {
        for (var ayah = 1; ayah <= 3; ayah++) {
          final start = lines.length;
          lines.addAll(['اَلْحَمْدُ لِلّٰهِ ($ayah)', 'T', 'Translation']);
          spans.add(AyahSpan(
            surah: surah,
            ayah: ayah,
            start: start,
            end: lines.length,
            startsSurah: ayah == 1 ? surahInfoFor(surah) : null,
          ));
        }
      }

      expect(
        quranParagraphSpanRuns(
          AyahIndex.fromSpans(spans),
          parse(lines.join('\n')),
        ),
        [
          [0, 1, 2],
          [3, 4, 5],
        ],
      );
    });
  });

  group('a surah in Arabic-only paragraph mode', () {
    setUp(() {
      showTransliteration = false;
      showTranslation = false;
      showArabicAsParagraph = true;
    });

    tearDown(() {
      showTransliteration = true;
      showTranslation = true;
      showArabicAsParagraph = false;
    });

    testWidgets('flows each passage into one paragraph, like any zikr',
        (tester) async {
      await _pump(tester, content: _surahContent());

      // Ayahs 1-3 share one block of text, and 4-6 another.
      final first = _paragraphContaining('(1)');
      expect(first, findsOneWidget);
      final text = (first.evaluate().single.widget as RichText)
          .text
          .toPlainText();
      expect(text, contains('(2)'));
      expect(text, contains('(3)'));
      expect(text, isNot(contains('(4)')));
    });

    testWidgets('labels each passage with the verses it holds',
        (tester) async {
      await _pump(tester, content: _surahContent());

      expect(find.text('1\u20133'), findsOneWidget);
      expect(find.text('4\u20136'), findsOneWidget);
    });

    testWidgets('keeps ayah mode when the setting is off', (tester) async {
      showArabicAsParagraph = false;
      await _pump(tester, content: _surahContent());

      expect(find.text('1\u20133'), findsNothing);
      // One badge per verse, as ever.
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('keeps ayah mode while an English aid is on', (tester) async {
      showTranslation = true;
      await _pump(tester, content: _surahContent());

      expect(find.text('1\u20133'), findsNothing);
      expect(find.text('Translation of ayah 2'), findsOneWidget);
    });

    testWidgets('tapping the paragraph opens the verse under the finger',
        (tester) async {
      final tapped = <int>[];
      await _pump(
        tester,
        content: _surahContent(),
        onAyahAction: (request) => tapped.add(request.verse.ayah!),
      );

      // Right-to-left: the start of the first row is ayah 1.
      final paragraph = _paragraphContaining('(1)');
      final rect = tester.getRect(paragraph);
      await tester.tapAt(Offset(rect.right - 4, rect.top + 8));
      await tester.pumpAndSettle();

      expect(tapped, [1]);
    });

    testWidgets('a tapped verse carries its Imam Ali (as) note, if any',
        (tester) async {
      AyahActionRequest? request;
      await _pump(
        tester,
        content: _surahContent(),
        onAyahAction: (r) => request = r,
      );

      final rect = tester.getRect(_paragraphContaining('(1)'));
      await tester.tapAt(Offset(rect.right - 4, rect.top + 8));
      await tester.pumpAndSettle();

      expect(request, isNotNull);
      expect(request!.lineIndex, isNonNegative);
      // Surah 1 has no curated verses, so nothing is attached.
      expect(request!.aliNote, isNull);
    });

    testWidgets('marks a kept verse by its number', (tester) async {
      await _pump(
        tester,
        content: _surahContent(),
        savedVerses: {const VerseKey(1, 2)},
      );

      final finder = _paragraphContaining('(1)');
      final paragraph = finder.evaluate().single.widget as RichText;
      // The verse-number markers, in reading order - the only spans holding
      // a `(n)` or an ayah medallion, whichever the selected font draws.
      final markers = <TextStyle?>[];
      paragraph.text.visitChildren((span) {
        final text = span is TextSpan ? span.text : null;
        if (text != null && (text.contains('(') || text.contains('\u06DD'))) {
          markers.add(span.style);
        }
        return true;
      });

      final primary = Theme.of(tester.element(finder)).colorScheme.primary;
      expect(markers, hasLength(3));
      expect(markers[1]?.color, primary);
      expect(markers[0]?.color, isNot(primary));
      expect(markers[2]?.color, isNot(primary));
    });

    testWidgets('opens at a requested verse inside a passage',
        (tester) async {
      await _pump(
        tester,
        content: _surahContent(ayahs: 80, rukuAfter: {40}),
        initialVerse: const VerseKey(1, 60),
      );

      // Ayah 60 sits partway down the second passage (41-80), so the view
      // has to have gone past that passage's top edge to reach it - landing
      // on the passage alone would leave its top on screen.
      final passage = _paragraphContaining('(60)');
      expect(passage, findsOneWidget);
      expect(tester.getRect(passage).top, lessThan(0));
      expect(tester.getRect(passage).bottom, greaterThan(0));
    });

    testWidgets('reports the verse being read inside a passage, not its first',
        (tester) async {
      final reports = <QuranReadingPosition>[];
      await _pump(
        tester,
        content: _surahContent(ayahs: 80, rukuAfter: {}),
        onAyahPosition: reports.add,
      );

      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(reports, isNotEmpty);
      expect(reports.last.fromUserScroll, isTrue);
      // Still inside the one passage, but well past its opening verse.
      expect(reports.last.verse.ayah!, greaterThan(1));
    });

    testWidgets('names each surah where a juz crosses into it',
        (tester) async {
      items = {'A8': '4: An-Nisa النساء', 'A9': '5: Al-Maidah المائدة'};
      addTearDown(() => items = {});

      final lines = <String>[];
      final spans = <AyahSpan>[];
      for (final surah in [4, 5]) {
        for (var ayah = 1; ayah <= 3; ayah++) {
          final start = lines.length;
          lines.addAll([
            'اَلْحَمْدُ لِلّٰهِ ($ayah)',
            'TRANSLITERATION $surah $ayah',
            'Translation of $surah:$ayah',
          ]);
          spans.add(AyahSpan(
            surah: surah,
            ayah: ayah,
            start: start,
            end: lines.length,
            startsSurah: ayah == 1 ? surahInfoFor(surah) : null,
          ));
        }
      }

      await _pump(
        tester,
        content: lines.join('\n'),
        surahNumber: null,
        ayahIndex: AyahIndex.fromSpans(spans),
      );

      expect(find.text('4. An-Nisa'), findsOneWidget);
      expect(find.text('5. Al-Maidah'), findsOneWidget);
      // Two passages, one per surah, each numbered from 1.
      expect(find.text('1\u20133'), findsNWidgets(2));
    });
  });
}
