import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/page_layout_engine.dart';

/// The same fit check as `library_page_fit_test.dart`, run over real chapters
/// from the shiavault-library repo the reader actually loads.
///
/// Hand-written fixtures only exercise the markdown you thought to write. Real
/// chapters brought the constructs that broke the page-height model in
/// practice: setext headings (`Title` underlined with `===`), ordered lists
/// numbered past 9, `2)` markers, quoted lists, and backslash-escaped
/// backticks before transliterated names. Each file below is kept for the
/// construct named in its filename.
void main() {
  const lineHeight = 1.55;
  const contentWidth = 393.0 - 32;
  const pageHeight = 600.0;

  final fixtures = Directory('test/fixtures/library_chapters')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

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

  for (final fixture in fixtures) {
    final name = fixture.uri.pathSegments.last;

    testWidgets('$name paginates into pages that fit', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final markdown = fixture.readAsStringSync();

      for (final fontSize in <double>[16, 24]) {
        late MarkdownStyleSheet sheet;
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
          sheet = readerStyleSheet(context, fontSize);
          return const SizedBox();
        })));

        final result = PageLayoutEngine(
          markdown: markdown,
          contentWidth: contentWidth,
          contentHeight: pageHeight,
          styleSheet: sheet,
        ).compute();

        expect(result.pageCount, greaterThan(0));

        for (var i = 0; i < result.pageCount; i++) {
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
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
          ));
          await tester.pump();

          final rendered = tester.getSize(find.byKey(const Key('page'))).height;
          expect(
            rendered,
            lessThanOrEqualTo(pageHeight),
            reason: '$name at ${fontSize.toInt()}pt: page ${i + 1} of '
                '${result.pageCount} renders ${rendered.toStringAsFixed(1)}px '
                'into a ${pageHeight}px page',
          );
        }
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
