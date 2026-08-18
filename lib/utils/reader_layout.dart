import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The vertical extent of one rendered line of text, in the coordinate space
/// of the column the chapter is laid out in.
///
/// A page may never end part-way through one of these: that is what clipping
/// the last line of a page looks like.
class ReaderLineBox {
  const ReaderLineBox(this.top, this.bottom);

  final double top;
  final double bottom;

  double get height => bottom - top;
}

/// Where every block and every line of a chapter ended up when the whole
/// chapter was laid out as one continuous column.
///
/// This is measured from the rendered widgets rather than predicted: the
/// reader shows pages by windowing onto that same column, so a page break can
/// only ever land where the text really has a break.
class ReaderColumnGeometry {
  const ReaderColumnGeometry({
    required this.columnHeight,
    required this.blockTops,
    required this.blockHeights,
    required this.lines,
  });

  /// Height of the whole chapter laid out in one column.
  final double columnHeight;

  /// The y of each block's top edge (its top margin included, since the
  /// margin is part of the widget the column lays out).
  final List<double> blockTops;

  /// The height of each block, margins included.
  final List<double> blockHeights;

  /// Every line of text in the chapter, ordered by where it starts.
  final List<ReaderLineBox> lines;

  double blockBottom(int index) => blockTops[index] + blockHeights[index];

  bool get isEmpty => blockTops.isEmpty || columnHeight <= 0;
}

/// One page of the reader: the window `[top, bottom)` of the chapter column
/// it shows, and the blocks that have to be built to fill it.
class ReaderPage {
  const ReaderPage({
    required this.top,
    required this.bottom,
    required this.firstBlock,
    required this.lastBlock,
    required this.contentOffset,
  });

  /// The y of the chapter column this page starts at.
  final double top;

  /// The y it ends at. Never inside a line of text.
  final double bottom;

  /// The first and last block (inclusive) that show any part of themselves on
  /// this page. A block spanning a page break is built on both pages, with
  /// the part belonging to the other page scrolled out of the window — the
  /// text is never re-cut, so it can never re-wrap.
  final int firstBlock;
  final int lastBlock;

  /// How far the block column has to be shifted up so that [top] sits at the
  /// top of the page.
  final double contentOffset;

  double get height => bottom - top;
}

/// The chapter cut into pages.
class ReaderPagination {
  const ReaderPagination({required this.pages, required this.columnHeight});

  final List<ReaderPage> pages;
  final double columnHeight;

  int get pageCount => pages.length;

  bool get isEmpty => pages.isEmpty;

  /// The page showing [blockIndex], or 0 if there is none.
  int pageForBlock(int blockIndex) {
    for (var i = 0; i < pages.length; i++) {
      if (blockIndex >= pages[i].firstBlock && blockIndex <= pages[i].lastBlock) {
        return i;
      }
    }
    return 0;
  }
}

/// Floating-point slack. Line and block edges come out of the engine as
/// device pixels, so anything below this is the same position.
const double _epsilon = 0.01;

/// How far inside a line a break has to fall before it counts as cutting it.
///
/// Consecutive lines of the same paragraph overlap by a fraction of a pixel —
/// each line box is grown to the tallest ascent and descent on it, and those
/// are rounded — so the bottom of one line lies a hair inside the top of the
/// next. Without this the bottom of every line in the chapter would look like
/// a cut, and pages would fall back to being cut anywhere at all. It stays far
/// below the case it is there to catch: text set beside other text, such as a
/// list marker next to its item, where the shorter of the two ends several
/// pixels up inside the taller one's line.
const double _lineInteriorTolerance = 1.0;

/// Reads the geometry of a chapter that has been laid out in one column.
///
/// [columnKey] is the column holding one child per block, [blockKeys] are
/// those children. Both must be laid out — call this from a post-frame
/// callback, not during build.
ReaderColumnGeometry harvestColumnGeometry({
  required GlobalKey columnKey,
  required List<GlobalKey> blockKeys,
}) {
  final columnObject = columnKey.currentContext?.findRenderObject();
  if (columnObject is! RenderBox || !columnObject.hasSize) {
    return const ReaderColumnGeometry(
      columnHeight: 0,
      blockTops: [],
      blockHeights: [],
      lines: [],
    );
  }

  final blockTops = <double>[];
  final blockHeights = <double>[];
  final lines = <ReaderLineBox>[];

  for (final key in blockKeys) {
    final object = key.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize) {
      blockTops.add(blockTops.isEmpty ? 0 : blockTops.last + blockHeights.last);
      blockHeights.add(0);
      continue;
    }

    final top = object.localToGlobal(Offset.zero, ancestor: columnObject).dy;
    blockTops.add(top);
    blockHeights.add(object.size.height);
    _collectLines(object, columnObject, lines);
  }

  lines.sort((a, b) => a.top.compareTo(b.top));

  return ReaderColumnGeometry(
    columnHeight: columnObject.size.height,
    blockTops: blockTops,
    blockHeights: blockHeights,
    lines: lines,
  );
}

/// Every line of text under [node], in [ancestor]'s coordinates.
///
/// The line boxes come from the render objects themselves rather than from a
/// second, parallel measurement of the same text: a `TextPainter` fed the same
/// string can still disagree with what the paragraph did with it, and a page
/// cut on the strength of that disagreement is a page with a clipped or an
/// orphaned line.
void _collectLines(
  RenderObject node,
  RenderBox ancestor,
  List<ReaderLineBox> out,
) {
  if (node is RenderParagraph) {
    if (!node.hasSize) return;
    final top = node.localToGlobal(Offset.zero, ancestor: ancestor).dy;
    final length = node.text.toPlainText(includeSemanticsLabels: false).length;
    if (length == 0) return;
    // `BoxHeightStyle.max` returns each line at its full line height, so
    // consecutive lines meet exactly: the bottom of one is the top of the
    // next, and a break between them leaves no sliver of either behind.
    final boxes = node.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: length),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    for (final box in boxes) {
      out.add(ReaderLineBox(top + box.top, top + box.bottom));
    }
    return;
  }
  node.visitChildren((child) => _collectLines(child, ancestor, out));
}

/// Cuts the measured chapter into pages of at most [pageHeight].
///
/// Each page runs to the last place the text actually breaks that still fits —
/// a line boundary or the end of a block — so pages fill to within one line of
/// the page height, and no line is ever half on one page and half on the next.
ReaderPagination paginateColumn(
  ReaderColumnGeometry geometry, {
  required double pageHeight,
}) {
  if (geometry.isEmpty || pageHeight <= 0) {
    return ReaderPagination(pages: const [], columnHeight: geometry.columnHeight);
  }

  final breaks = _breakCandidates(geometry);
  final pages = <ReaderPage>[];

  var top = 0.0;
  while (top < geometry.columnHeight - _epsilon) {
    final limit = top + pageHeight;
    final double bottom;
    if (limit >= geometry.columnHeight - _epsilon) {
      bottom = geometry.columnHeight;
    } else {
      final candidate = _lastBreakWithin(breaks, top, limit);
      // No break at all in a whole page's worth of content means a single
      // line taller than the page; cutting it is the only way forward.
      bottom = candidate ?? limit;
    }

    pages.add(_pageFor(geometry, top, bottom));
    top = bottom;
  }

  if (pages.isEmpty) {
    pages.add(_pageFor(geometry, 0, geometry.columnHeight));
  }

  return ReaderPagination(pages: pages, columnHeight: geometry.columnHeight);
}

ReaderPage _pageFor(ReaderColumnGeometry geometry, double top, double bottom) {
  var firstBlock = 0;
  for (var i = 0; i < geometry.blockTops.length; i++) {
    if (geometry.blockBottom(i) > top + _epsilon) {
      firstBlock = i;
      break;
    }
  }

  var lastBlock = firstBlock;
  for (var i = firstBlock; i < geometry.blockTops.length; i++) {
    if (geometry.blockTops[i] >= bottom - _epsilon) break;
    lastBlock = i;
  }

  return ReaderPage(
    top: top,
    bottom: bottom,
    firstBlock: firstBlock,
    lastBlock: lastBlock,
    contentOffset: top - geometry.blockTops[firstBlock],
  );
}

/// The places a page is allowed to end: the bottom of a line, the bottom of a
/// block, and the end of the chapter — minus any of those that fall inside
/// another line, which happens wherever two pieces of text sit side by side
/// (a list marker beside its item, say) and one is shorter than the other.
List<double> _breakCandidates(ReaderColumnGeometry geometry) {
  final candidates = <double>{};
  for (final line in geometry.lines) {
    candidates.add(line.bottom);
  }
  for (var i = 0; i < geometry.blockTops.length; i++) {
    candidates.add(geometry.blockBottom(i));
  }
  candidates.add(geometry.columnHeight);

  final sorted = candidates.toList()..sort();

  // Prefix maximum of line bottoms, so "does any line already open at this
  // point run past it" is a lookup rather than a scan of every line.
  final lineTops = [for (final line in geometry.lines) line.top];
  final maxBottomSoFar = <double>[];
  var runningMax = double.negativeInfinity;
  for (final line in geometry.lines) {
    runningMax = runningMax > line.bottom ? runningMax : line.bottom;
    maxBottomSoFar.add(runningMax);
  }

  return [
    for (final candidate in sorted)
      if (!_insideLine(candidate, lineTops, maxBottomSoFar)) candidate,
  ];
}

bool _insideLine(double y, List<double> lineTops, List<double> maxBottomSoFar) {
  // Index of the last line that starts above y.
  var low = 0;
  var high = lineTops.length - 1;
  var index = -1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    if (lineTops[mid] < y - _lineInteriorTolerance) {
      index = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  if (index < 0) return false;
  return maxBottomSoFar[index] > y + _lineInteriorTolerance;
}

double? _lastBreakWithin(List<double> breaks, double top, double limit) {
  double? best;
  var low = 0;
  var high = breaks.length - 1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    if (breaks[mid] <= limit + _epsilon) {
      if (breaks[mid] > top + _epsilon) best = breaks[mid];
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return best;
}
