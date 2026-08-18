import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/markdown_block.dart';
import 'package:shia_companion/utils/markdown_block_parser.dart';
import 'package:shia_companion/utils/reader_layout.dart';
import 'package:shia_companion/widgets/reader_content.dart';

/// The reader lays a chapter out once, as one column, and shows pages by
/// windowing onto it. So the two things a page can get wrong are geometric,
/// and both are checked here against the geometry the engine really produced:
///
///   * a page that ends part-way through a line — the last line clipped, or
///     half of it repeated at the top of the next page;
///   * a page that ends before it had to — blank space at the bottom that the
///     next line would have fitted into.
///
/// Every case runs over the same measured column the reader itself builds
/// ([ReaderMeasureColumn]), so what is checked is the layout, not a model of
/// it.
void main() {
  const lineHeight = 1.55;
  const epsilon = 0.01;
  // Lines of one paragraph overlap by a fraction of a pixel — each line box is
  // grown to the tallest ascent and descent on it — so "inside a line" means
  // properly inside it, not within rounding of its edge.
  const tolerance = 1.0;

  MarkdownStyleSheet readerStyleSheet(BuildContext context, double fontSize) {
    // Mirrors ChapterPage._readerStyleSheet.
    final textTheme = Theme.of(context).textTheme;
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

  /// Lays [markdown] out the way the reader's measuring pass does and returns
  /// what it measured.
  Future<(ReaderColumnGeometry, List<MarkdownBlock>)> measure(
    WidgetTester tester,
    String markdown, {
    required double fontSize,
    required double contentWidth,
    required double pageHeight,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    final blocks = MarkdownBlockParser.parse(markdown);
    final columnKey = GlobalKey();
    final blockKeys = [for (var i = 0; i < blocks.length; i++) GlobalKey()];

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Scaffold(
          body: SizedBox(
            width: contentWidth,
            height: pageHeight,
            child: Builder(builder: (context) {
              return ReaderMeasureColumn(
                columnKey: columnKey,
                blocks: blocks,
                blockKeys: blockKeys,
                styleSheet: readerStyleSheet(context, fontSize),
              );
            }),
          ),
        ),
      ),
    ));

    return (
      harvestColumnGeometry(columnKey: columnKey, blockKeys: blockKeys),
      blocks,
    );
  }

  /// The places a page could have ended, worked out independently of the
  /// engine: the bottom of a line or of a block, as long as no other line is
  /// still running there (a list marker sits beside its item, so the bottom of
  /// the marker falls inside the item's first line).
  List<double> usableBreaks(ReaderColumnGeometry geometry) {
    final candidates = <double>{geometry.columnHeight};
    for (final line in geometry.lines) {
      candidates.add(line.bottom);
    }
    for (var i = 0; i < geometry.blockTops.length; i++) {
      candidates.add(geometry.blockBottom(i));
    }

    bool insideALine(double y) => geometry.lines.any(
          (line) =>
              line.top < y - tolerance && line.bottom > y + tolerance,
        );

    return [
      for (final candidate in candidates.toList()..sort())
        if (!insideALine(candidate)) candidate,
    ];
  }

  /// Checks the two things a page can get wrong, for every page.
  void expectPagesFitExactly(
    ReaderColumnGeometry geometry,
    ReaderPagination pagination,
    double pageHeight,
    String description,
  ) {
    expect(pagination.pageCount, greaterThan(1),
        reason: '$description: a chapter that fits on one page tests nothing');

    final breaks = usableBreaks(geometry);

    for (var i = 0; i < pagination.pageCount; i++) {
      final page = pagination.pages[i];
      final where = '$description: page ${i + 1} of ${pagination.pageCount}';

      // The pages are the chapter, in order and without gaps.
      expect(page.top, i == 0 ? 0.0 : pagination.pages[i - 1].bottom,
          reason: '$where does not start where the last one ended');
      expect(page.height, lessThanOrEqualTo(pageHeight + epsilon),
          reason: '$where is taller than the page');

      // Nothing is cut in half.
      for (final line in geometry.lines) {
        final straddles = line.top < page.bottom - tolerance &&
            line.bottom > page.bottom + tolerance;
        expect(straddles, isFalse,
            reason: '$where ends at ${page.bottom.toStringAsFixed(1)}, '
                'inside a line running '
                '${line.top.toStringAsFixed(1)}–${line.bottom.toStringAsFixed(1)}');
      }

      // The blocks the page builds cover the window it shows.
      expect(geometry.blockTops[page.firstBlock], lessThanOrEqualTo(page.top + epsilon),
          reason: '$where starts above its first block');
      expect(geometry.blockBottom(page.lastBlock),
          greaterThanOrEqualTo(page.bottom - epsilon),
          reason: '$where ends below its last block');

      if (i == pagination.pageCount - 1) continue;

      // The page ended because the next line did not fit, not sooner: the
      // whole point of the exercise is that no page wastes space.
      final next = breaks.firstWhere((b) => b > page.bottom + epsilon,
          orElse: () => double.infinity);
      expect(next, greaterThan(page.top + pageHeight + epsilon),
          reason: '$where stops at ${page.bottom.toStringAsFixed(1)} and '
              'leaves ${(pageHeight - page.height).toStringAsFixed(1)}px '
              'blank, but the text breaks again at '
              '${next.toStringAsFixed(1)}, which would still have fitted');
    }

    expect(pagination.pages.last.bottom, geometry.columnHeight,
        reason: '$description: the last page does not reach the end');
  }

  const prose = '''
# The Rites of Hajj

Hajj is one of the pillars of Islam, and it is obligatory upon every
person who fulfils the conditions of istita'ah at least once in a
lifetime. The obligation is immediate, meaning it must be performed in
the first year in which one becomes capable, and delaying it without an
excuse is a sin.

The conditions of istita'ah include physical ability, the availability
of provisions and a mount, the safety of the route, and having enough
time to reach the sacred precinct and perform the rites.

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

The first of the obligatory acts at the miqat is the intention, which
must be made with the purpose of drawing near to Allah. Without it the
ihram is invalid and everything that follows is built on nothing.
''';

  const arabic = '''
## دعاء

اللهم صل على محمد وآل محمد، وارزقنا حج بيتك الحرام في عامنا هذا وفي كل
عام، ما أبقيتنا، في يسر منك وعافية وسعة رزق.

> ربنا تقبل منا إنك أنت السميع العليم، وتب علينا إنك أنت التواب الرحيم.

اللهم اجعلنا من عبادك الصالحين، واجعل عملنا خالصا لوجهك الكريم، ولا
تجعل للشيطان علينا سبيلا، ولا تكلنا إلى أنفسنا طرفة عين أبدا.

اللهم إنا نسألك من خير ما سألك منه عبادك الصالحون، ونعوذ بك من شر ما
استعاذ منه عبادك المخلصون، وصل على محمد وآله الطاهرين.
''';

  // A phone, minus the reader's horizontal padding.
  const contentWidth = 393.0 - 32;
  const pageHeight = 600.0;

  for (final fontSize in <double>[14, 18, 24, 28]) {
    testWidgets('prose pages fill exactly at ${fontSize.toInt()}pt',
        (tester) async {
      final (geometry, _) = await measure(tester, prose,
          fontSize: fontSize,
          contentWidth: contentWidth,
          pageHeight: pageHeight);
      expectPagesFitExactly(
        geometry,
        paginateColumn(geometry, pageHeight: pageHeight),
        pageHeight,
        'prose at ${fontSize.toInt()}pt',
      );
    });
  }

  for (final scale in <double>[1.3, 2.0]) {
    testWidgets('prose pages fill exactly at ${scale}x system text size',
        (tester) async {
      final (geometry, _) = await measure(tester, prose,
          fontSize: 18,
          contentWidth: contentWidth,
          pageHeight: pageHeight,
          textScaler: TextScaler.linear(scale));
      expectPagesFitExactly(
        geometry,
        paginateColumn(geometry, pageHeight: pageHeight),
        pageHeight,
        'prose at ${scale}x',
      );
    });
  }

  testWidgets('right-to-left pages fill exactly', (tester) async {
    final (geometry, _) = await measure(tester, arabic,
        fontSize: 22, contentWidth: contentWidth, pageHeight: 400);
    expectPagesFitExactly(
      geometry,
      paginateColumn(geometry, pageHeight: 400),
      400,
      'arabic',
    );
  });

  // The chapters kept as fixtures are the ones whose markdown broke the
  // reader's old height model: setext headings, `2)` list markers, escaped
  // backticks, quoted lists. Measuring the rendered column rather than
  // predicting it means none of those are special cases any more — which is
  // exactly what these check.
  final fixtures = Directory('test/fixtures/library_chapters')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.md'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final fixture in fixtures) {
    final name = fixture.uri.pathSegments.last;
    for (final fontSize in <double>[16, 26]) {
      testWidgets('$name pages fill exactly at ${fontSize.toInt()}pt',
          (tester) async {
        final (geometry, _) = await measure(tester, fixture.readAsStringSync(),
            fontSize: fontSize,
            contentWidth: contentWidth,
            pageHeight: pageHeight);
        expectPagesFitExactly(
          geometry,
          paginateColumn(geometry, pageHeight: pageHeight),
          pageHeight,
          '$name at ${fontSize.toInt()}pt',
        );
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  }
}
