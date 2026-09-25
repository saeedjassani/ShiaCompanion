import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/quran_ali_verses.dart';
import 'package:shia_companion/pages/zikr/zikr_content_parser.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/quran_indopak.dart';

const _bismillah = 'بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ';

/// The rukūʿ sign, at the private-use codepoint Al Qalam draws it from.
const _rukuMark = '\uE022';

/// The bookmark glyph drawn inline at the start of the bookmarked verse.
final _bookmarkGlyph = String.fromCharCode(Icons.bookmark.codePoint);

/// A Bismillah and [ayahs] verses in the `012` triplet shape every surah
/// uses, with a rukūʿ sign closing each verse listed in [rukuAfter].
String _surahContent({int ayahs = 6, Set<int> rukuAfter = const {3}}) {
  final lines = <String>[_bismillah];
  for (var ayah = 1; ayah <= ayahs; ayah++) {
    final ruku = rukuAfter.contains(ayah) ? _rukuMark : '';
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
  int? bookmarkLineIndex,
  double? bookmarkScrollOffset,
  ValueChanged<AyahActionRequest>? onAyahAction,
  ValueChanged<QuranReadingPosition>? onAyahPosition,
  ValueChanged<ZikrContentScrollPosition>? onScrollPosition,
  String? arabicFontFamily,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        // As on the zikr page, where the reading area is selectable - which
        // changes what [Text] builds under the paragraph's key.
        body: SelectionArea(
          child: ZikrContentViewerWidget(
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
            initialBookmarkTabIndex: bookmarkLineIndex == null ? null : 0,
            initialBookmarkLineIndex: bookmarkLineIndex,
            initialBookmarkScrollOffset: bookmarkScrollOffset,
            onAyahAction: onAyahAction,
            onAyahPositionChanged: onAyahPosition,
            onScrollPositionChanged: onScrollPosition,
            arabicFontFamily: arabicFontFamily,
          ),
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
        ZikrContentParser.parseContent(content,
            hideHeaderLine: false, code: '012');

    test('the Bismillah stands alone and a rukuʿ does not break the surah', () {
      final content = _surahContent(ayahs: 6, rukuAfter: {3});
      final parsed = parse(content);
      final index = AyahIndex.fromParsedContent(parsed, surah: 1);

      // Span 0 is the Bismillah; spans 1..6 are ayahs 1..6.
      expect(quranParagraphSpanRuns(index), [
        [0],
        [1, 2, 3, 4, 5, 6],
      ]);
    });

    test('a long surah is still one paragraph', () {
      final content = _surahContent(ayahs: 286, rukuAfter: {7, 20, 29});
      final parsed = parse(content);
      final index = AyahIndex.fromParsedContent(parsed, surah: 1);

      final runs = quranParagraphSpanRuns(index);
      expect(runs.map((run) => run.length), [1, 286]);
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
        quranParagraphSpanRuns(AyahIndex.fromSpans(spans)),
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

    testWidgets('flows the whole surah into one paragraph, rukuʿ and all',
        (tester) async {
      await _pump(tester, content: _surahContent());

      // Ayahs 1-6 share one block of text, the rukuʿ after 3 notwithstanding.
      final first = _paragraphContaining('(1)');
      expect(first, findsOneWidget);
      final text =
          (first.evaluate().single.widget as RichText).text.toPlainText();
      for (var ayah = 2; ayah <= 6; ayah++) {
        expect(text, contains('($ayah)'));
      }
      expect(text, contains(_rukuMark));
      // No range label above it.
      expect(find.text('1\u20136'), findsNothing);
    });

    testWidgets('draws no Imam Ali (as) seal in the paragraph', (tester) async {
      final note = aliRelatedNoteFor(const VerseKey(5, 55))!;
      Future<void> open() => _pump(
            tester,
            content: _surahContent(ayahs: 60, rukuAfter: {}),
            surahNumber: 5,
            initialVerse: const VerseKey(5, 55),
          );

      showArabicAsParagraph = false;
      await open();
      expect(find.byTooltip(note), findsOneWidget,
          reason: 'ayah mode still seals the verse');

      showArabicAsParagraph = true;
      await open();
      expect(_paragraphContaining('(55)'), findsOneWidget);
      expect(find.byTooltip(note), findsNothing);
      expect(find.byTooltip('55: $note'), findsNothing);
    });

    testWidgets('keeps ayah mode when the setting is off', (tester) async {
      showArabicAsParagraph = false;
      await _pump(tester, content: _surahContent());

      // One badge per verse, as ever.
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('keeps ayah mode while an English aid is on', (tester) async {
      showTranslation = true;
      await _pump(tester, content: _surahContent());

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
      expect(markers, hasLength(6));
      expect(markers[1]?.color, primary);
      expect(markers[0]?.color, isNot(primary));
      expect(markers[2]?.color, isNot(primary));
    });

    testWidgets('marks a kept verse by its QuranWBW medallion', (tester) async {
      final quran = IndoPakQuran.parse(File(indoPakAsset).readAsStringSync());
      final content = toIndoPak(1, _surahContent(rukuAfter: {}), quran);
      await _pump(
        tester,
        content: content,
        savedVerses: {const VerseKey(1, 2)},
        arabicFontFamily: quranWbwFontFamily,
      );

      final medallion = RegExp('[\uE820\uF500-\uF6FF]');
      final finder = _paragraphContaining(String.fromCharCode(0xF500));
      final paragraph = finder.evaluate().single.widget as RichText;
      final markers = <TextSpan>[];
      paragraph.text.visitChildren((span) {
        if (span is TextSpan && medallion.hasMatch(span.text ?? '')) {
          markers.add(span);
        }
        return true;
      });

      final primary = Theme.of(tester.element(finder)).colorScheme.primary;
      // Each medallion is a span of its own, and QuranWBW's number is the only
      // one shown: the `(n)` the text carries for lookups is hidden.
      expect(markers.map((span) => span.text!.trim()),
          [for (var n = 0; n < 6; n++) String.fromCharCode(0xF500 + n)]);
      expect(paragraph.text.toPlainText(), isNot(contains('(')));
      expect(markers[1].style?.color, primary);
      expect(markers[0].style?.color, isNot(primary));
    });

    // Line 0 is the Bismillah and ayah n's Arabic is line 3n - 2.
    for (final paragraphMode in [true, false]) {
      testWidgets(
          'a verse opened at is the one a bookmark then records '
          '(${paragraphMode ? 'paragraph' : 'ayah'} mode)', (tester) async {
        showArabicAsParagraph = paragraphMode;
        final positions = <ZikrContentScrollPosition>[];
        await _pump(
          tester,
          content: _surahContent(ayahs: 80, rukuAfter: {40}),
          initialVerse: const VerseKey(1, 60),
          onScrollPosition: positions.add,
        );

        // The verse lands a small margin below the top edge, over the tail
        // of the one before it, and must not read back as that one.
        expect(positions, isNotEmpty);
        expect(positions.last.lineIndex, 3 * 60 - 2);
      });
    }

    testWidgets('opens at a requested verse inside the surah', (tester) async {
      await _pump(
        tester,
        content: _surahContent(ayahs: 80, rukuAfter: {40}),
        initialVerse: const VerseKey(1, 60),
      );

      // Ayah 60 sits partway down the surah's one paragraph, so the view has
      // to have gone past the paragraph's top edge to reach it - landing on
      // the paragraph alone would leave its top on screen.
      final passage = _paragraphContaining('(60)');
      expect(passage, findsOneWidget);
      expect(tester.getRect(passage).top, lessThan(0));
      expect(tester.getRect(passage).bottom, greaterThan(0));
    });

    testWidgets(
        'reports the verse being read inside the paragraph, not its first',
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
      // Still inside the one paragraph, but well past its opening verse.
      expect(reports.last.verse.ayah!, greaterThan(1));
    });

    testWidgets('a bookmark comes back to its verse, not its old offset',
        (tester) async {
      // Line 0 is the Bismillah and ayah n's Arabic is line 3n - 2, so line
      // 178 is ayah 60's Arabic. The offset was measured in ayah mode, where
      // every verse took a block of its own - far past here in this layout.
      await _pump(
        tester,
        content: _surahContent(ayahs: 80, rukuAfter: {40}),
        bookmarkLineIndex: 178,
        bookmarkScrollOffset: 9000,
      );

      final passage = _paragraphContaining('(60)');
      expect(passage, findsOneWidget);
      expect(tester.getRect(passage).top, lessThan(0));
      expect(tester.getRect(passage).bottom, greaterThan(0));
      // The bookmark is an icon inline at the start of the verse itself, not
      // a label that would break the paragraph.
      final text =
          (passage.evaluate().single.widget as RichText).text.toPlainText();
      final glyphAt = text.indexOf(_bookmarkGlyph);
      expect(glyphAt, greaterThan(text.indexOf('(59)')));
      expect(glyphAt, lessThan(text.indexOf('(60)')));
      expect(find.text('Bookmarked'), findsNothing);
    });

    testWidgets('names each surah where a juz crosses into it', (tester) async {
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
      // Two paragraphs, one per surah, each numbered from 1.
      expect(_paragraphContaining('(1)'), findsNWidgets(2));
    });
  });
}
