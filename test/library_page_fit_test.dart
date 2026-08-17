import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/page_layout_engine.dart';

/// The library reader cuts a chapter into fixed-height pages by measuring each
/// block with a [TextPainter], then renders those pages with `MarkdownBody`
/// inside a `ClipRect` of exactly the height it measured for. Any block that
/// renders taller than it measured is therefore not an off-by-a-pixel nicety:
/// the overflow is silently clipped, and the reader loses the last line of the
/// page with no way to get it back.
///
/// So rather than asserting on the engine's arithmetic, these tests render the
/// pages it produces and check they fit — the same check the ClipRect makes,
/// only visible.
void main() {
  const lineHeight = 1.55;
  const contentWidth = 393.0 - 32; // A phone, minus the reader's padding.
  const pageHeight = 600.0;

  // Ordinary chapter prose, hard-wrapped the way the shiavault-library
  // markdown is, with the block types a chapter actually mixes: headings,
  // paragraphs, a blockquote (which renders inside blockquotePadding) and a
  // list (which renders one indented row per item).
  const englishMarkdown = '''
# The Rites of Hajj

Hajj is one of the pillars of Islam, and it is obligatory upon every
person who fulfils the conditions of istita'ah at least once in a
lifetime. The obligation is immediate, meaning it must be performed in
the first year in which one becomes capable, and delaying it without an
excuse is a sin.

The conditions of istita'ah include physical ability, the availability
of provisions and a mount, the safety of the route, and having enough
time to reach the sacred precinct and perform the rites. A person who
lacks any one of these conditions is not obliged to perform Hajj in
that year, though a voluntary pilgrimage remains meritorious.

> Whoever possesses provisions and a mount that will convey him to the
> House of Allah, and he does not perform the pilgrimage, then there is
> no difference whether he dies a Jew or a Christian.

## Entering Ihram

When the pilgrim reaches the miqat he enters the state of ihram, which
begins with the intention and the talbiyah. From that moment a number
of things become forbidden to him, and remain so until he completes
the acts that release him from ihram.

1. The intention must be to attain nearness to Allah, and it must be
made at the miqat itself and not before it.
2. The talbiyah must be recited in correct Arabic, and one who cannot
recite it should have someone prompt him.
3. Wearing the two garments of ihram, which for men replace all sewn
clothing for the duration of the rites.

> The pilgrim who leaves his home seeking the House of Allah is under
> the protection of Allah until he returns.

The first of the obligatory acts at the miqat is the intention, which
must be made with the purpose of drawing near to Allah. Without it the
ihram is invalid and everything that follows is built on nothing, so
the pilgrim should take care to make it deliberately and knowingly.
''';

  // Arabic runs right-to-left and is measured with a different text direction.
  const arabicMarkdown = '''
## دعاء

اللهم صل على محمد وآل محمد، وارزقنا حج بيتك الحرام في عامنا هذا وفي كل
عام، ما أبقيتنا، في يسر منك وعافية وسعة رزق.

> ربنا تقبل منا إنك أنت السميع العليم، وتب علينا إنك أنت التواب الرحيم.

اللهم اجعلنا من عبادك الصالحين، واجعل عملنا خالصا لوجهك الكريم، ولا
تجعل للشيطان علينا سبيلا، ولا تكلنا إلى أنفسنا طرفة عين أبدا.
''';

  MarkdownStyleSheet readerStyleSheet(BuildContext context, double fontSize) {
    final textTheme = Theme.of(context).textTheme;
    // Mirrors ChapterPage._readerStyleSheet.
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      textAlign: WrapAlignment.spaceBetween,
      blockquoteAlign: WrapAlignment.spaceBetween,
      p: textTheme.bodyLarge?.copyWith(fontSize: fontSize, height: lineHeight),
      h1: textTheme.headlineSmall?.copyWith(fontSize: fontSize + 8),
      h2: textTheme.titleLarge?.copyWith(fontSize: fontSize + 5),
      h3: textTheme.titleMedium?.copyWith(fontSize: fontSize + 3),
      h4: textTheme.titleSmall?.copyWith(fontSize: fontSize + 2),
      h5: textTheme.titleSmall?.copyWith(fontSize: fontSize + 1),
      h6: textTheme.titleSmall?.copyWith(fontSize: fontSize),
      blockquote: textTheme.bodyLarge?.copyWith(
        fontSize: fontSize,
        height: lineHeight,
        fontStyle: FontStyle.italic,
      ),
      code: textTheme.bodyMedium?.copyWith(fontSize: fontSize - 2),
      a: textTheme.bodyLarge?.copyWith(fontSize: fontSize),
    );
  }

  /// Paginates [markdown] and renders each page exactly as ChapterPage does,
  /// returning the rendered height of every page.
  Future<List<double>> renderedPageHeights(
    WidgetTester tester,
    String markdown, {
    required double fontSize,
    required TextScaler textScaler,
  }) async {
    late MarkdownStyleSheet sheet;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Builder(builder: (context) {
          sheet = readerStyleSheet(context, fontSize);
          return const SizedBox();
        }),
      ),
    ));

    final result = PageLayoutEngine(
      markdown: markdown,
      contentWidth: contentWidth,
      contentHeight: pageHeight,
      styleSheet: sheet,
      textScaler: textScaler,
    ).compute();

    final heights = <double>[];
    for (var i = 0; i < result.pageCount; i++) {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  key: const Key('page'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final pb in result.pageBlocks[i])
                      Padding(
                        padding: EdgeInsets.only(
                          top: pb.topMargin,
                          bottom: pb.bottomMargin,
                        ),
                        child: Directionality(
                          textDirection:
                              result.blocks[pb.originalIndex].textDirection,
                          child: MarkdownBody(
                            data: pb.text,
                            selectable: true,
                            styleSheet: sheet,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      heights.add(tester.getSize(find.byKey(const Key('page'))).height);
    }
    return heights;
  }

  Future<void> expectPagesFit(
    WidgetTester tester,
    String markdown, {
    required double fontSize,
    required TextScaler textScaler,
    required String label,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final heights = await renderedPageHeights(
      tester,
      markdown,
      fontSize: fontSize,
      textScaler: textScaler,
    );

    expect(heights, isNotEmpty, reason: '$label produced no pages');
    for (var i = 0; i < heights.length; i++) {
      expect(
        heights[i],
        lessThanOrEqualTo(pageHeight),
        reason: '$label: page ${i + 1}/${heights.length} renders '
            '${heights[i].toStringAsFixed(1)}px into a ${pageHeight}px page, '
            'so ${(heights[i] - pageHeight).toStringAsFixed(1)}px is clipped',
      );
    }
  }

  for (final fontSize in <double>[14, 18, 22, 28]) {
    testWidgets('English pages fit at ${fontSize.toInt()}pt', (tester) async {
      await expectPagesFit(
        tester,
        englishMarkdown,
        fontSize: fontSize,
        textScaler: TextScaler.noScaling,
        label: '${fontSize.toInt()}pt',
      );
    });
  }

  testWidgets('Arabic pages fit', (tester) async {
    await expectPagesFit(
      tester,
      arabicMarkdown,
      fontSize: 20,
      textScaler: TextScaler.noScaling,
      label: 'Arabic at 20pt',
    );
  });

  for (final scale in <double>[1.3, 1.8]) {
    testWidgets('pages fit at a $scale system text scale', (tester) async {
      await expectPagesFit(
        tester,
        englishMarkdown,
        fontSize: 18,
        textScaler: TextScaler.linear(scale),
        label: '18pt at ${scale}x system scale',
      );
    });
  }

  // A paragraph long enough that it has to be cut, put back, and cut again —
  // the case where splitting the block it came from rather than what is left
  // of it shows the reader the same sentences twice.
  final longParagraph = List.generate(
    120,
    (i) => 'This is sentence number ${i + 1} of a single very long paragraph.',
  ).join(' ');

  testWidgets('a paragraph spanning many pages is shown once, in order',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late MarkdownStyleSheet sheet;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      sheet = readerStyleSheet(context, 20);
      return const SizedBox();
    })));

    final result = PageLayoutEngine(
      markdown: '# A Long Chapter\n\n$longParagraph\n\n'
          '> $longParagraph\n\n'
          '1. $longParagraph',
      contentWidth: contentWidth,
      contentHeight: pageHeight,
      styleSheet: sheet,
    ).compute();

    expect(result.pageCount, greaterThan(3),
        reason: 'the fixture should need several pages to be a useful test');

    // Every page's words, in reading order, with the block markers the
    // renderer consumes (`#`, `>`, `1.`) taken back out.
    final shown = [
      for (final page in result.pageBlocks)
        for (final block in page)
          ...block.text
              .replaceAll(RegExp(r'^\s*(#{1,6}|>|[-*+]|\d+\.)\s*', multiLine: true), '')
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty),
    ];

    final expected = [
      'A', 'Long', 'Chapter',
      ...longParagraph.split(' '),
      ...longParagraph.split(' '),
      ...longParagraph.split(' '),
    ];

    expect(shown, expected);
  });
}
