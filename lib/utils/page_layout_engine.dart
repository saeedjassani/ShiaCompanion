import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'markdown_block.dart';
import 'markdown_block_parser.dart';

class PaginatedBlock {
  const PaginatedBlock(this.originalIndex, this.fragmentIndex, this.text, this.topMargin, this.bottomMargin);
  final int originalIndex;
  final int fragmentIndex;
  final String text;
  final double topMargin;
  final double bottomMargin;
}

class PaginationResult {
  const PaginationResult({
    required this.blocks,
    required this.pageBlocks,
    required this.splitFragments,
    required this.renderingWidth,
  });

  final List<MarkdownBlock> blocks;
  final List<List<PaginatedBlock>> pageBlocks;
  final Map<int, List<String>> splitFragments;
  final double renderingWidth;

  int get pageCount => pageBlocks.length;
}

class PageLayoutEngine {
  PageLayoutEngine({
    required this.markdown,
    required this.contentWidth,
    required this.contentHeight,
    required this.styleSheet,
    this.textScaler = TextScaler.noScaling,
    this.selectable = true,
  });

  /// Width `RenderEditable` reserves for the caret and its gap
  /// (`_kCaretGap` 1.0 + `SelectableText`'s default `cursorWidth` 2.0), and so
  /// does *not* give the text: selectable markdown wraps 3px narrower than the
  /// box it sits in. Small, but it is the difference between the last line of
  /// a page fitting and being clipped away.
  static const double _selectableCaretMargin = 3.0;

  final String markdown;
  final double contentWidth;
  final double contentHeight;

  /// The same style sheet the page is rendered with — font sizes and line
  /// heights are read from it, so measurement and rendering can't drift apart.
  final MarkdownStyleSheet styleSheet;

  /// The scaler the rendered text will be laid out with — the caller's
  /// `MediaQuery.textScalerOf(context)`, i.e. the reader's system font-size
  /// setting. [TextPainter] does no scaling by default, so leaving this out
  /// would measure every block at 100% while the page renders larger, and the
  /// bottom of each page would be clipped.
  final TextScaler textScaler;

  /// Whether the page renders its text with `MarkdownBody(selectable: true)`,
  /// which costs [_selectableCaretMargin] of wrapping width.
  final bool selectable;

  /// The width text actually wraps in, as opposed to the width of the box it
  /// is given.
  double get _wrapWidth =>
      contentWidth - (selectable ? _selectableCaretMargin : 0.0);

  PaginationResult compute() {
    final blocks = MarkdownBlockParser.parse(markdown);

    if (blocks.isEmpty) {
      return PaginationResult(
        blocks: blocks,
        pageBlocks: const [],
        splitFragments: const {},
        renderingWidth: contentWidth,
      );
    }

    final pageBlocks = <List<PaginatedBlock>>[];
    var remaining = <_BlockWithHeight>[];

    // Pre-measure all blocks
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final h = _measureBlock(block);
      remaining.add(_BlockWithHeight(i, block, h));
    }

    while (remaining.isNotEmpty) {
      final page = <PaginatedBlock>[];
      var used = 0.0;

      while (remaining.isNotEmpty) {
        final item = remaining.first;
        final available = contentHeight - used;
        final itemTotal = item.height + item.block.totalVerticalMargin;

        if (itemTotal <= available) {
          // Whole block fits
          page.add(PaginatedBlock(
            item.index, 0, item.text,
            item.block.blockTopMargin, item.block.blockBottomMargin,
          ));
          used += itemTotal;
          remaining.removeAt(0);
        } else if (page.isNotEmpty && available > 20) {
          // Block doesn't fit but there's usable space — split it
          final split = _splitAtHeight(item.block, available);
          if (split != null) {
            // First part fits on this page
            final head = _fragment(item.block, split.key);
            page.add(PaginatedBlock(
              item.index, 0, head.rawText,
              item.block.blockTopMargin, 0.0,
            ));
            used += contentHeight; // fill the page
            // Replace remaining with the rest. It becomes the block that gets
            // measured and, if it still doesn't fit, split again — carrying
            // the original block here instead would re-split its full text and
            // repeat on the next page what this one just showed.
            final tail = _fragment(item.block, split.value);
            remaining[0] =
                _BlockWithHeight(item.index, tail, _measureBlock(tail));
          }
          break;
        } else {
          // Doesn't fit, can't split — start new page or break out
          break;
        }
      }

      if (page.isNotEmpty) {
        pageBlocks.add(page);
      } else if (remaining.isNotEmpty) {
        // Force a block onto its own page (it's taller than a full page)
        final item = remaining.first;
        // If it's splittable, split it into page-sized chunks
        if (_canSplitBlock(item.block.type)) {
          final fragments = _splitIntoPages(item.block);
          for (final frag in fragments) {
            pageBlocks.add([
              PaginatedBlock(item.index, 0, _fragment(item.block, frag).rawText,
                  item.block.blockTopMargin, item.block.blockBottomMargin),
            ]);
          }
          remaining.removeAt(0);
        } else {
          // Can't split, force it on its own page anyway
          pageBlocks.add([
            PaginatedBlock(item.index, 0, item.text,
              item.block.blockTopMargin, item.block.blockBottomMargin),
          ]);
          remaining.removeAt(0);
        }
      }
    }

    return PaginationResult(
      blocks: blocks,
      pageBlocks: pageBlocks,
      splitFragments: const {},
      renderingWidth: contentWidth,
    );
  }

  double _measureBlock(MarkdownBlock block) {
    if (block.type == MarkdownBlockType.listItem) {
      return _measureListBlock(block);
    }
    final insets = _blockInsets(block.type);

    // A quoted list (`> 1. …`) is a list as far as the renderer is concerned:
    // indented rows inside the quote's padding, not quoted prose.
    if (block.type == MarkdownBlockType.blockquote &&
        MarkdownBlockParser.startsWithListMarker(block.strippedText)) {
      return _measureListBlock(block, widthInset: insets.horizontal) +
          insets.vertical;
    }

    final painter = TextPainter(
      text: _buildTextSpan(block),
      textDirection: block.textDirection,
      textScaler: textScaler,
    );
    painter.layout(
      maxWidth: (_wrapWidth - insets.horizontal).clamp(1.0, contentWidth),
    );
    return painter.height + insets.vertical;
  }

  /// Padding flutter_markdown_plus wraps a block's text in, on top of the text
  /// metrics themselves. A blockquote is the one that bites: it renders inside
  /// `blockquotePadding` (8 on every side by default), so it takes 16px more
  /// height than its text and wraps in 16px less width — enough to push an
  /// extra line past the bottom of the page if measurement ignores it.
  EdgeInsets _blockInsets(MarkdownBlockType type) {
    switch (type) {
      case MarkdownBlockType.blockquote:
        // The quote's text is still a paragraph inside the quote, so it picks
        // up pPadding as well.
        return (styleSheet.blockquotePadding ?? EdgeInsets.zero)
            .add(styleSheet.pPadding ?? EdgeInsets.zero)
            .resolve(TextDirection.ltr);
      case MarkdownBlockType.heading1:
        return styleSheet.h1Padding ?? EdgeInsets.zero;
      case MarkdownBlockType.heading2:
        return styleSheet.h2Padding ?? EdgeInsets.zero;
      case MarkdownBlockType.heading3:
        return styleSheet.h3Padding ?? EdgeInsets.zero;
      case MarkdownBlockType.heading4:
        return styleSheet.h4Padding ?? EdgeInsets.zero;
      case MarkdownBlockType.heading5:
        return styleSheet.h5Padding ?? EdgeInsets.zero;
      case MarkdownBlockType.heading6:
        return styleSheet.h6Padding ?? EdgeInsets.zero;
      case MarkdownBlockType.paragraph:
        return styleSheet.pPadding ?? EdgeInsets.zero;
      case MarkdownBlockType.listItem:
      case MarkdownBlockType.horizontalRule:
        // `li` and `hr` get no text padding of their own.
        return EdgeInsets.zero;
    }
  }

  // A single listItem block can represent several consecutive `1. `/`- `
  // lines (there's no blank line between list items to split them apart at
  // the parser level), but flutter_markdown_plus renders each one as its own
  // row: a fixed-width bullet/number column plus text that wraps in the
  // remaining width, with blockSpacing between rows. Measuring the whole
  // block as one continuously-wrapped paragraph at the full content width
  // (as a plain paragraph would be) undercounts wrapped lines and produces a
  // block that renders taller than measured — hence the per-item measurement
  // here instead of the single-TextSpan path used for other block types.
  double _measureListBlock(MarkdownBlock block, {double widthInset = 0}) {
    // A quoted list has had its `>` markers stripped; a plain one hasn't.
    final source = block.type == MarkdownBlockType.blockquote
        ? block.strippedText
        : block.rawText;
    final rawItems = MarkdownBlockParser.splitListItemsRaw(source);
    if (rawItems.isEmpty) return 0.0;

    final heights = _measureListItemHeights(rawItems, block, widthInset);
    final blockSpacing = styleSheet.blockSpacing ?? 8.0;

    var total = 0.0;
    for (var i = 0; i < heights.length; i++) {
      if (i > 0) total += blockSpacing;
      total += heights[i];
    }
    return total;
  }

  /// The rendered height of each list item's row, as flutter_markdown_plus
  /// lays it out: a fixed-width bullet/number column beside text that wraps in
  /// what's left, the two baseline-aligned.
  List<double> _measureListItemHeights(
    List<String> rawItems,
    MarkdownBlock block, [
    double widthInset = 0,
  ]) {
    return [
      for (final item in rawItems)
        _measureListRow(
          MarkdownBlockParser.leadingListMarker(item),
          MarkdownBlockParser.stripListMarker(item),
          block,
          widthInset,
        ),
    ];
  }

  /// The height of one list row: its marker column and its text sit in a
  /// baseline-aligned `Row`, whose height is the tallest thing above the
  /// shared baseline plus the tallest thing below it — not simply the taller
  /// of the two children. The marker column is only [MarkdownStyleSheet
  /// .listIndent] wide, so a long marker (`137.`) wraps and can make the row
  /// taller than its text.
  double _measureListRow(
    String? marker,
    String text,
    MarkdownBlock block, [
    double widthInset = 0,
  ]) {
    final indent = styleSheet.listIndent ?? 24.0;
    final bulletColumn = indent + (styleSheet.listBulletPadding?.horizontal ?? 4.0);
    final textWidth =
        (_wrapWidth - widthInset - bulletColumn).clamp(1.0, contentWidth);

    final textPainter = TextPainter(
      text: _parseInlineMarkdown(text, _styleForBlock(block)),
      textDirection: block.textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: textWidth);

    if (marker == null) return textPainter.height;

    final bulletPainter = TextPainter(
      // An unordered item renders a bullet glyph rather than its source
      // marker; an ordered one renders its own number followed by a period
      // (whatever delimiter the source used), since the builder carries the
      // list's `start` through.
      text: TextSpan(
        text: _renderedListMarker(marker),
        style: styleSheet.listBullet,
      ),
      textDirection: block.textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: indent);

    return _baselineAlignedHeight(textPainter, bulletPainter);
  }

  static String _renderedListMarker(String marker) {
    final number = RegExp(r'^\d+').firstMatch(marker);
    return number == null ? '•' : '${number.group(0)}.';
  }

  /// The cross-axis extent `RenderFlex` gives a baseline-aligned row of two
  /// text children.
  double _baselineAlignedHeight(TextPainter a, TextPainter b) {
    final aBaseline = a.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final bBaseline = b.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final above = aBaseline > bBaseline ? aBaseline : bBaseline;
    final belowA = a.height - aBaseline;
    final belowB = b.height - bBaseline;
    return above + (belowA > belowB ? belowA : belowB);
  }

  TextSpan _buildTextSpan(MarkdownBlock block) {
    final baseStyle = _styleForBlock(block);
    return _parseInlineMarkdown(block.strippedText, baseStyle);
  }

  /// The style a block's text is measured with. These are the style sheet's
  /// own styles, untouched: the renderer lays the text out with exactly these,
  /// so overriding anything here (a line height the heading styles don't
  /// actually carry, say) measures a page that isn't the one that renders.
  TextStyle? _styleForBlock(MarkdownBlock block) {
    switch (block.type) {
      case MarkdownBlockType.heading1:
        return styleSheet.h1;
      case MarkdownBlockType.heading2:
        return styleSheet.h2;
      case MarkdownBlockType.heading3:
        return styleSheet.h3;
      case MarkdownBlockType.heading4:
        return styleSheet.h4;
      case MarkdownBlockType.heading5:
        return styleSheet.h5;
      case MarkdownBlockType.heading6:
        return styleSheet.h6;
      case MarkdownBlockType.blockquote:
        return styleSheet.blockquote;
      case MarkdownBlockType.listItem:
      case MarkdownBlockType.horizontalRule:
      case MarkdownBlockType.paragraph:
        return styleSheet.p;
    }
  }

  TextSpan _parseInlineMarkdown(String text, TextStyle? baseStyle) {
    if (text.isEmpty) return TextSpan(text: '', style: baseStyle);
    final spans = <TextSpan>[];
    var remaining = text;
    final patterns = <_InlinePattern>[
      _InlinePattern(
        // A backslash escape renders the character after it literally, and —
        // the point of matching it first — stops that character from acting
        // as a delimiter. The chapters are full of `\`` before transliterated
        // names, which would otherwise read as code-span backticks and be
        // measured in the (smaller) code style.
        RegExp(r'\\([!-/:-@\[-`{-~])'),
        (match) => TextSpan(text: match.group(1), style: baseStyle),
      ),
      _InlinePattern(
        RegExp(r'`([^`]+)`'),
        (match) => TextSpan(
          text: match.group(1),
          style: styleSheet.code,
        ),
      ),
      _InlinePattern(
        RegExp(r'~~([^~]+)~~'),
        (match) => TextSpan(
          text: match.group(1),
          style: (baseStyle ?? const TextStyle())
              .copyWith(decoration: TextDecoration.lineThrough),
        ),
      ),
      _InlinePattern(
        // Bold-italic. It has to be tried before `**`, which would otherwise
        // fail on the inner `*` and leave the asterisks in the measured text.
        // The content may not begin or end with whitespace: `*** ***` is a run
        // of literal asterisks, not emphasis, and treating it as emphasis
        // measures six characters that do get rendered.
        RegExp(r'\*\*\*(\S(?:[^*]*\S)?)\*\*\*|___(\S(?:[^_]*\S)?)___'),
        (match) => TextSpan(
          text: match.group(1) ?? match.group(2) ?? '',
          style: (baseStyle ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      _InlinePattern(
        RegExp(r'\*\*(\S(?:[^*]*\S)?)\*\*|__(\S(?:[^_]*\S)?)__'),
        (match) => TextSpan(
          text: match.group(1) ?? match.group(2) ?? '',
          style: (baseStyle ?? const TextStyle())
              .copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      _InlinePattern(
        RegExp(r'\*(\S(?:[^*]*\S)?)\*|_(\S(?:[^_]*\S)?)_'),
        (match) => TextSpan(
          text: match.group(1) ?? match.group(2) ?? '',
          style: (baseStyle ?? const TextStyle())
              .copyWith(fontStyle: FontStyle.italic),
        ),
      ),
      _InlinePattern(
        RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
        (match) => TextSpan(text: match.group(1) ?? '', style: baseStyle),
      ),
      _InlinePattern(
        RegExp(r'\[([^\]]+)\]\([^)]+\)'),
        (match) => TextSpan(
          text: match.group(1) ?? '',
          style: styleSheet.a ?? baseStyle,
        ),
      ),
    ];

    while (remaining.isNotEmpty) {
      int earliestIndex = remaining.length;
      TextSpan? matchedSpan;
      int matchedLength = 0;
      for (final pattern in patterns) {
        final match = pattern.regex.firstMatch(remaining);
        if (match != null && match.start < earliestIndex) {
          earliestIndex = match.start;
          matchedSpan = pattern.builder(match);
          matchedLength = match.end - match.start;
        }
      }
      if (matchedSpan == null) {
        spans.add(TextSpan(text: remaining, style: baseStyle));
        break;
      }
      if (earliestIndex > 0) {
        spans.add(TextSpan(
          text: remaining.substring(0, earliestIndex),
          style: baseStyle,
        ));
      }
      spans.add(matchedSpan);
      remaining = remaining.substring(earliestIndex + matchedLength);
    }
    return TextSpan(children: spans, style: baseStyle);
  }

  /// A piece of [source] that has been split off it, as a block in its own
  /// right — the thing the page renders and the engine measures and re-splits.
  ///
  /// [text] is what the split routines hand back, which is marker-free for
  /// paragraphs and blockquotes (they split [MarkdownBlock.strippedText]) and
  /// already-marked list markdown for lists. Rendering a blockquote fragment
  /// as-is would drop the quote styling on every page after the first, so its
  /// `> ` is put back here.
  MarkdownBlock _fragment(MarkdownBlock source, String text) {
    final raw = source.type == MarkdownBlockType.blockquote
        ? text.split('\n').map((line) => '> $line').join('\n')
        : text;
    return MarkdownBlock(
      rawText: raw,
      strippedText: text,
      type: source.type,
      textDirection: source.textDirection,
      headingLevel: source.headingLevel,
    );
  }

  bool _canSplitBlock(MarkdownBlockType type) {
    return type == MarkdownBlockType.paragraph ||
        type == MarkdownBlockType.blockquote ||
        type == MarkdownBlockType.listItem;
  }

  /// Split [block]'s text so that the first part fits within [availableHeight]
  /// (minus top margin). Returns [firstPart, remainder] or null.
  MapEntry<String, String>? _splitAtHeight(MarkdownBlock block, double availableHeight) {
    if (!_canSplitBlock(block.type)) return null;
    final effectiveHeight = availableHeight - block.blockTopMargin;
    if (effectiveHeight <= 15) return null;

    if (block.type == MarkdownBlockType.listItem) {
      return _splitListAtHeight(block, effectiveHeight);
    }

    return _splitTextAtHeight(
      block.strippedText,
      effectiveHeight,
      (candidate) => _measureBlock(MarkdownBlock(
        rawText: candidate, strippedText: candidate,
        type: block.type, textDirection: block.textDirection,
        headingLevel: block.headingLevel,
      )),
    );
  }

  /// Splits [text] so the first part's rendered height (per [measureHeight])
  /// fits within [effectiveHeight]. Tries sentence boundaries first, falling
  /// back to word boundaries so as much of the remaining page space is used
  /// as possible instead of leaving it blank. Returns null if not even one
  /// word fits.
  MapEntry<String, String>? _splitTextAtHeight(
    String text,
    double effectiveHeight,
    double Function(String candidate) measureHeight,
  ) {
    if (text.trim().isEmpty) return null;

    final sentences = _splitSentences(text);
    if (sentences.length >= 2) {
      for (var i = sentences.length - 1; i >= 1; i--) {
        final firstPart = sentences.take(i).join(' ');
        if (measureHeight(firstPart) <= effectiveHeight) {
          return MapEntry(firstPart, sentences.skip(i).join(' '));
        }
      }
    }

    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 2) return null;
    for (var i = words.length - 1; i >= 1; i--) {
      final firstPart = words.take(i).join(' ');
      if (measureHeight(firstPart) <= effectiveHeight) {
        return MapEntry(firstPart, words.skip(i).join(' '));
      }
    }

    return null;
  }

  /// Splits a listItem block at an item boundary, so each fragment stays
  /// whole, correctly-marked list markdown. Splitting on [block.strippedText]
  /// the way the generic paragraph/blockquote path does would flatten the
  /// list into plain prose — only the block's very first item ever had its
  /// marker stripped there, so every later item's `1. `/`- ` would render as
  /// literal text — and would measure it at the wrong (unindented) width.
  ///
  /// If not even the first item fits whole, falls back to splitting *within*
  /// that item at a sentence/word boundary — the same way an oversized
  /// paragraph splits — keeping the item's marker (if any) on the fitting
  /// head. The tail has no marker of its own, which is deliberate:
  /// flutter_markdown_plus treats an unmarked line directly following a list
  /// item (no blank line) as a lazy continuation of that same item, so it
  /// still renders indented under it rather than as a new bullet. A "first
  /// item" with no marker at all happens when this is itself the unmarked
  /// tail of an earlier inner split that still doesn't fit one page — it
  /// keeps splitting the same way, just without a marker to carry forward.
  ///
  /// Returns null if not even one word of the first item fits.
  MapEntry<String, String>? _splitListAtHeight(
    MarkdownBlock block,
    double effectiveHeight,
  ) {
    final rawItems = MarkdownBlockParser.splitListItemsRaw(block.rawText);
    if (rawItems.isEmpty) return null;

    final heights = _measureListItemHeights(rawItems, block);
    final blockSpacing = styleSheet.blockSpacing ?? 8.0;

    var used = 0.0;
    var fitCount = 0;
    for (var i = 0; i < heights.length; i++) {
      final addition = heights[i] + (i > 0 ? blockSpacing : 0.0);
      if (used + addition > effectiveHeight) break;
      used += addition;
      fitCount++;
    }

    if (fitCount > 0) {
      return MapEntry(
        rawItems.take(fitCount).join('\n'),
        rawItems.skip(fitCount).join('\n'),
      );
    }

    // Not even the first item fits whole — split within it.
    final marker = MarkdownBlockParser.leadingListMarker(rawItems.first);

    final innerSplit = _splitTextAtHeight(
      MarkdownBlockParser.stripListMarker(rawItems.first),
      effectiveHeight,
      (candidate) => _measureListRow(marker, candidate, block),
    );
    if (innerSplit == null) return null;

    final tailRaw = [innerSplit.value, ...rawItems.skip(1)]
        .where((s) => s.trim().isNotEmpty)
        .join('\n');
    if (tailRaw.isEmpty) return null;

    return MapEntry('${marker ?? ''}${innerSplit.key}', tailRaw);
  }

  /// Split a block into page-sized fragments (for blocks taller than a page).
  ///
  /// Every fragment is rendered with the block's own top *and* bottom margin,
  /// so the height a fragment may occupy is the page less both — cutting them
  /// to the full page height and adding the margins afterwards is what pushes
  /// the closing line of the fragment off the bottom of the page.
  List<String> _splitIntoPages(MarkdownBlock block) {
    final available = contentHeight - block.totalVerticalMargin;
    if (available <= 0) return [block.strippedText];

    if (block.type == MarkdownBlockType.listItem) {
      return _splitListIntoPages(block);
    }

    final fragments = <String>[];
    var remaining = block.strippedText;

    while (remaining.isNotEmpty) {
      final split = _splitAtHeight(
        _fragment(block, remaining),
        // _splitAtHeight takes the space before the top margin comes out.
        available + block.blockTopMargin,
      );
      if (split != null) {
        fragments.add(split.key);
        remaining = split.value;
      } else {
        fragments.add(remaining);
        break;
      }
    }

    return fragments;
  }

  /// The list-item counterpart to [_splitIntoPages]: walks item boundaries
  /// (via [_splitListAtHeight]) instead of sentences/words.
  List<String> _splitListIntoPages(MarkdownBlock block) {
    // Net of both margins, for the reason given on [_splitIntoPages].
    final effectiveHeight = contentHeight - block.totalVerticalMargin;
    final fragments = <String>[];
    var remainingRaw = block.rawText;

    while (remainingRaw.isNotEmpty) {
      final split = _splitListAtHeight(
        MarkdownBlock(
          rawText: remainingRaw, strippedText: remainingRaw,
          type: MarkdownBlockType.listItem, textDirection: block.textDirection,
        ),
        effectiveHeight,
      );
      if (split != null) {
        fragments.add(split.key);
        remainingRaw = split.value;
      } else {
        fragments.add(remainingRaw);
        break;
      }
    }

    return fragments;
  }

  static List<String> _splitSentences(String text) {
    if (text.trim().isEmpty) return [];
    return text.split(
      RegExp(r'(?<=[.!?\u061F\u060D\u0700\u0701\u0702\u003F])\s+(?=\S)'),
    ).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }
}

class _BlockWithHeight {
  const _BlockWithHeight(this.index, this.block, this.height);

  /// Index into the parsed block list — several fragments of one split block
  /// all keep the index of the block they came from.
  final int index;

  /// The block still to be laid out: the original, or what's left of it after
  /// earlier pages took their share.
  final MarkdownBlock block;
  final double height;

  String get text => block.rawText;
}

class _InlinePattern {
  const _InlinePattern(this.regex, this.builder);
  final RegExp regex;
  final TextSpan Function(Match match) builder;
}