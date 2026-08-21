import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../utils/markdown_block.dart';
import '../utils/reader_layout.dart';
import '../utils/reader_style.dart';

/// One block of a chapter, as both the measuring pass and the pages build it.
///
/// There is one builder for both on purpose: the reader's pages are windows
/// onto the column the measuring pass laid out, so a block that rendered
/// differently in the two would put every page after it out of step with the
/// text it was cut from.
class ReaderBlockView extends StatelessWidget {
  const ReaderBlockView({
    super.key,
    required this.block,
    required this.styleSheet,
  });

  final MarkdownBlock block;
  final MarkdownStyleSheet styleSheet;

  @override
  Widget build(BuildContext context) {
    // Derived here rather than passed in, so the measuring pass and the pages
    // cannot end up holding different styles for the same block: both build
    // through this one widget, from the same block and the same base sheet.
    final sheet = block.textDirection == TextDirection.rtl
        ? rtlReaderStyleSheet(styleSheet)
        : styleSheet;

    return Padding(
      padding: EdgeInsets.only(
        top: block.blockTopMargin,
        bottom: block.blockBottomMargin,
      ),
      child: Directionality(
        textDirection: block.textDirection,
        child: MarkdownBody(
          data: block.rawText,
          // Selection is the page's job, through a SelectionArea. Selectable
          // markdown lays its text out through RenderEditable, which wraps
          // three pixels narrower than the box it is given and keeps its line
          // metrics to itself — measurement could then neither see the lines
          // nor trust the width they were broken at.
          selectable: false,
          styleSheet: sheet,
        ),
      ),
    );
  }
}

/// The whole chapter laid out as one continuous column, for
/// [harvestColumnGeometry] to read the pages out of.
///
/// Built at the width the pages render in, and never painted: the reader shows
/// a spinner over it and replaces it with the pages as soon as the frame it
/// was laid out in is done.
class ReaderMeasureColumn extends StatelessWidget {
  const ReaderMeasureColumn({
    super.key,
    required this.columnKey,
    required this.blocks,
    required this.blockKeys,
    required this.styleSheet,
  });

  /// The key [harvestColumnGeometry] reads the laid-out column through. It
  /// goes on the column itself rather than on this widget: the scroll view
  /// around it is only one page tall, and the geometry wanted is the
  /// chapter's.
  final GlobalKey columnKey;

  final List<MarkdownBlock> blocks;
  final List<GlobalKey> blockKeys;
  final MarkdownStyleSheet styleSheet;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        key: columnKey,
        mainAxisSize: MainAxisSize.min,
        // Stretch, not start: a block that shrank to its text would sit against
        // the left margin whatever its direction, leaving a short Arabic quote
        // floating in the middle of the page with its rule beside it. At full
        // width the block's own Directionality puts the text — and the rule —
        // on the correct side.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < blocks.length; i++)
            KeyedSubtree(
              key: blockKeys[i],
              child: ReaderBlockView(block: blocks[i], styleSheet: styleSheet),
            ),
        ],
      ),
    );
  }
}

/// One page: the window `[page.top, page.bottom)` of the measured column.
///
/// The blocks it shows are built whole and shifted up so the page's first line
/// sits at the top; the clip takes the lines that belong to the pages either
/// side. Nothing is re-cut, so a block spanning a page break is the same
/// widget with the same text at the same width on both — its lines cannot move
/// between them, which is what makes a page hold exactly the text it was
/// measured to hold.
class ReaderPageWindow extends StatelessWidget {
  const ReaderPageWindow({
    super.key,
    required this.blocks,
    required this.page,
    required this.pageHeight,
    required this.styleSheet,
  });

  final List<MarkdownBlock> blocks;
  final ReaderPage page;
  final double pageHeight;
  final MarkdownStyleSheet styleSheet;

  @override
  Widget build(BuildContext context) {
    // The clip is the height of the page's own content, which is a whole page
    // less at most the line that did not fit — not the height of the slot the
    // page occupies. Clipping to the slot would let the first line of the next
    // page show its top edge over the bottom of this one.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRect(
          child: SizedBox(
            height: page.height,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Transform.translate(
                offset: Offset(0, -page.contentOffset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  // Matches ReaderMeasureColumn; see the note there. The pages
                  // must lay blocks out exactly as the measuring pass did.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = page.firstBlock;
                        i <= page.lastBlock && i < blocks.length;
                        i++)
                      ReaderBlockView(block: blocks[i], styleSheet: styleSheet),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
