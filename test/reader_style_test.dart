import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/markdown_block.dart';
import 'package:shia_companion/utils/markdown_block_parser.dart';
import 'package:shia_companion/utils/reader_style.dart';
import 'package:shia_companion/widgets/reader_content.dart';

/// How a quotation is presented in the reader.
///
/// Nearly every blockquote in the library is Qur'an or hadith in Arabic, and
/// chapters alternate quote and commentary for pages at a time, so the styling
/// of this one block type sets the character of the whole reader.
void main() {
  const arabicQuote = '> إنَّمَا الأَعْمَالُ بِالنِّيَّاتِ.';
  const englishQuote = '> The actions of a person depend on his intentions.';

  Future<MarkdownStyleSheet> sheetFor(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    late MarkdownStyleSheet sheet;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Builder(builder: (context) {
        sheet = readerStyleSheet(context, fontSize: 18);
        return const SizedBox();
      }),
    ));
    return sheet;
  }

  group('blockquote decoration', () {
    testWidgets('does not tint the quote', (tester) async {
      // flutter_markdown_plus defaults blockquotes to a hardcoded
      // Colors.blue.shade100. Overriding it is the whole point of setting
      // blockquoteDecoration, so assert the fill is gone rather than that it
      // is some particular colour.
      for (final brightness in Brightness.values) {
        final decoration = (await sheetFor(tester, brightness: brightness))
            .blockquoteDecoration as BoxDecoration;

        expect(
          decoration.color,
          isNull,
          reason: 'blockquotes should not be filled in ${brightness.name} mode',
        );
      }
    });

    testWidgets('marks the quote with a rule on its leading edge',
        (tester) async {
      final decoration =
          (await sheetFor(tester)).blockquoteDecoration as BoxDecoration;

      // BorderDirectional, not Border: the rule has to move to the right-hand
      // side of an Arabic quote, which a left/right Border cannot do.
      final border = decoration.border;
      expect(border, isA<BorderDirectional>());

      border as BorderDirectional;
      expect(border.start.width, greaterThan(0));
      expect(border.top, BorderSide.none);
      expect(border.bottom, BorderSide.none);
    });
  });

  group('right-to-left blocks', () {
    test('drop the synthetic oblique that italic would force on Arabic', () {
      // Arabic has no italic form, so FontStyle.italic gets a software shear
      // that breaks the joins between letters.
      final base = MarkdownStyleSheet(
        blockquote: const TextStyle(fontStyle: FontStyle.italic, fontSize: 18),
      );

      expect(base.blockquote!.fontStyle, FontStyle.italic);
      expect(
        rtlReaderStyleSheet(base).blockquote!.fontStyle,
        FontStyle.normal,
      );
    });

    test('keep every other property of the sheet they came from', () {
      final base = MarkdownStyleSheet(
        blockquote: const TextStyle(fontStyle: FontStyle.italic, fontSize: 21),
        p: const TextStyle(fontSize: 18),
        blockquoteAlign: WrapAlignment.spaceBetween,
      );
      final rtl = rtlReaderStyleSheet(base);

      expect(rtl.blockquote!.fontSize, 21);
      expect(rtl.p, base.p);
      expect(rtl.blockquoteAlign, WrapAlignment.spaceBetween);
    });
  });

  group('the reader applies the right sheet per block', () {
    /// The style [ReaderBlockView] actually rendered the quote's text with.
    Future<TextStyle> renderedQuoteStyle(
      WidgetTester tester,
      String markdown,
    ) async {
      final blocks = MarkdownBlockParser.parse(markdown);
      expect(blocks.single.type, MarkdownBlockType.blockquote);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ReaderBlockView(
              block: blocks.single,
              styleSheet: readerStyleSheet(context, fontSize: 18),
            );
          }),
        ),
      ));

      // The blockquote style lands on the span holding the text, not on the
      // RichText's root span, which markdown leaves unstyled.
      final root = tester.widget<RichText>(find.byType(RichText).first).text;
      TextStyle? found;
      root.visitChildren((span) {
        if (span is TextSpan && (span.text ?? '').trim().isNotEmpty) {
          found ??= span.style;
          return false;
        }
        return true;
      });
      return found ?? root.style!;
    }

    testWidgets('Arabic quotations render upright', (tester) async {
      final style = await renderedQuoteStyle(tester, arabicQuote);
      expect(style.fontStyle, FontStyle.normal);
    });

    testWidgets('English quotations keep their italic', (tester) async {
      final style = await renderedQuoteStyle(tester, englishQuote);
      expect(style.fontStyle, FontStyle.italic);
    });

    testWidgets('an Arabic quote lays out right-to-left', (tester) async {
      final blocks = MarkdownBlockParser.parse(arabicQuote);
      expect(blocks.single.textDirection, TextDirection.rtl);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ReaderBlockView(
              block: blocks.single,
              styleSheet: readerStyleSheet(context, fontSize: 18),
            );
          }),
        ),
      ));

      // The Directionality the block sets is what puts the leading-edge rule on
      // the right and the text against it.
      final directionality = tester.widget<Directionality>(
        find
            .descendant(
              of: find.byType(ReaderBlockView),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(directionality.textDirection, TextDirection.rtl);
    });
  });
}
