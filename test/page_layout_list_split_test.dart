import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/markdown_block.dart';
import 'package:shia_companion/utils/page_layout_engine.dart';

// Real chapter content (Manasek Hajj, "Mina and the Obligations There",
// https://github.com/saeedjassani/shiavault-library) that hits the
// multi-item list-block case: six ordered-list items with no blank line
// between them, one of which (#6) hard-wraps across six source lines.
const _listMarkdown =
    '1. The intention (niyyah) for the act must be to attain nearness to\n'
    'Allah.\n'
    '2. Seven pebbles must be thrown, not more or less, and it is not\n'
    'permitted to throw anything other than pebbles.\n'
    '3. The pebbles must be thrown one after the other and not two or more\n'
    'of them at the same time.\n'
    '4. It is necessary that the pebbles hit the Jamrah.\n'
    '5. The pebbles must reach the Jamrah by being thrown at it and not\n'
    'merely depositing them there.\n'
    '6. The throwing of the pebbles and hitting the Jamrah both must be done\n'
    'by the pilgrim himself. So, if the pebble was in his hand but he was\n'
    'pushed resulting in the pebble reaching the Jamrah, the obligation is\n'
    'not satisfied. The same rule applies if the Jamrah is obstructed by a\n'
    'man or an animal whose movements result in the pebble hitting the\n'
    'Jamrah. However, there is no objection if the pebble hits something and\n'
    'then reaches the Jamrah.';

void main() {
  const fontSize = 16.0;
  const lineHeight = 1.55;
  const contentWidth = 358.0; // ~iPhone width (390) minus ChapterPage's 32 padding.

  testWidgets(
      'a list block that must split across pages keeps its markers and '
      'fits the reserved page height', (tester) async {
    late MarkdownStyleSheet sheet;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        sheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          textAlign: WrapAlignment.spaceBetween,
          p: textTheme.bodyLarge?.copyWith(fontSize: fontSize, height: lineHeight),
        );
        return const SizedBox();
      }),
    ));

    // Short enough that the six-item list can't fit on one page — forces
    // the engine down the mid-block split path.
    const pageHeight = 220.0;

    final result = PageLayoutEngine(
      markdown: _listMarkdown,
      contentWidth: contentWidth,
      contentHeight: pageHeight,
      fontSize: fontSize,
      lineHeight: lineHeight,
      styleSheet: sheet,
    ).compute();

    expect(result.pageCount, greaterThan(1),
        reason: 'the six-item list should not fit an 220px page');

    // Print exactly what gets handed to MarkdownBody for each page, so a
    // human can see what actually renders.
    for (var i = 0; i < result.pageBlocks.length; i++) {
      // ignore: avoid_print
      print('--- page $i ---');
      for (final b in result.pageBlocks[i]) {
        // ignore: avoid_print
        print(b.text);
      }
    }

    // No fragment of the listItem block should have marker-like text
    // (`1. `, `- `, …) stranded mid-line -- that's the signature of the
    // list having been flattened into plain prose, which is what happens
    // when items after the first lose their marker. A marker is only
    // legitimate at the very start of a line.
    final anyMarker = RegExp(r'(?:[-*+]\s|\d+\.\s)');
    for (final page in result.pageBlocks) {
      for (final b in page) {
        final block = result.blocks[b.originalIndex];
        if (block.type != MarkdownBlockType.listItem) continue;

        for (final m in anyMarker.allMatches(b.text)) {
          final atLineStart = m.start == 0 || b.text[m.start - 1] == '\n';
          expect(atLineStart, isTrue,
              reason: 'marker-like text is stranded mid-line (the list got '
                  'flattened into prose) in fragment: "${b.text}"');
        }
      }
    }

    // Now actually render every page exactly the way ChapterPage._buildPage
    // does, and confirm nothing overflows the reserved page height.
    for (var i = 0; i < result.pageBlocks.length; i++) {
      final page = result.pageBlocks[i];
      final children = <Widget>[
        for (final b in page)
          Padding(
            padding: EdgeInsets.only(top: b.topMargin, bottom: b.bottomMargin),
            child: Directionality(
              textDirection: result.blocks[b.originalIndex].textDirection,
              child: MarkdownBody(data: b.text, styleSheet: sheet),
            ),
          ),
      ];

      final flutterErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) => flutterErrors.add(details);

      await tester.pumpWidget(MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: contentWidth,
            height: pageHeight,
            child: ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ),
      ));

      FlutterError.onError = previousOnError;

      final overflowErrors =
          flutterErrors.where((d) => d.exceptionAsString().contains('overflowed'));
      expect(overflowErrors, isEmpty,
          reason: 'page $i overflowed its reserved height:\n'
              '${overflowErrors.map((d) => d.exceptionAsString()).join("\n")}');
    }
  });
}
