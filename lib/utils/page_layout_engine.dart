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
  });

  final List<MarkdownBlock> blocks;
  final List<List<PaginatedBlock>> pageBlocks;
  final Map<int, List<String>> splitFragments;

  int get pageCount => pageBlocks.length;
}

class PageLayoutEngine {
  PageLayoutEngine({
    required this.markdown,
    required this.contentWidth,
    required this.contentHeight,
    required this.fontSize,
    required this.lineHeight,
    required this.styleSheet,
  });

  final String markdown;
  final double contentWidth;
  final double contentHeight;
  final double fontSize;
  final double lineHeight;
  final MarkdownStyleSheet styleSheet;


  PaginationResult compute() {
    debugPrint('PAGINATION: contentHeight=$contentHeight, contentWidth=$contentWidth');
    final blocks = MarkdownBlockParser.parse(markdown);
    debugPrint('PAGINATION: parsed ${blocks.length} blocks');
    
    if (blocks.isEmpty) {
      return PaginationResult(
        blocks: blocks,
        pageBlocks: const [],
        splitFragments: const {},
      );
    }

    final splitFragments = <int, List<String>>{};
    final allHeights = <double>[];

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final blockHeight = _measureBlock(block);
      debugPrint('PAGINATION: block $i type=${block.type} height=$blockHeight margins=${block.totalVerticalMargin} rawText.len=${block.rawText.length}');

      if (blockHeight + block.totalVerticalMargin <= contentHeight) {
        allHeights.add(blockHeight + block.totalVerticalMargin);
      } else {
        final fragmentHeights = _splitBlockAcrossPages(block, i, splitFragments);
        debugPrint('PAGINATION: block $i split into ${fragmentHeights.length} fragments');
        allHeights.addAll(fragmentHeights);
      }
    }
    
    debugPrint('PAGINATION: allHeights=${allHeights.fold(0.0, (s, h) => s + h)}');

    final pageBlocks = _paginate(allHeights, blocks, splitFragments);
    debugPrint('PAGINATION: created ${pageBlocks.length} pages');
    
    for (var p = 0; p < pageBlocks.length; p++) {
      debugPrint('PAGINATION: page $p has ${pageBlocks[p].length} blocks');
    }

    return PaginationResult(
      blocks: blocks,
      pageBlocks: pageBlocks,
      splitFragments: splitFragments,
    );
  }

  double _measureBlock(MarkdownBlock block) {
    final span = _buildTextSpan(block);
    final painter = TextPainter(
      text: span,
      textDirection: block.textDirection,
    );
    painter.layout(maxWidth: contentWidth);
    return painter.height;
  }

  TextSpan _buildTextSpan(MarkdownBlock block) {
    final baseStyle = _styleForBlock(block);
    return _parseInlineMarkdown(block.strippedText, baseStyle);
  }

  TextStyle? _styleForBlock(MarkdownBlock block) {
    switch (block.type) {
      case MarkdownBlockType.heading1:
        return styleSheet.h1?.copyWith(height: lineHeight);
      case MarkdownBlockType.heading2:
        return styleSheet.h2?.copyWith(height: lineHeight);
      case MarkdownBlockType.heading3:
        return styleSheet.h3?.copyWith(height: lineHeight);
      case MarkdownBlockType.heading4:
        return styleSheet.h4?.copyWith(height: lineHeight);
      case MarkdownBlockType.heading5:
        return styleSheet.h5?.copyWith(height: lineHeight);
      case MarkdownBlockType.heading6:
        return styleSheet.h6?.copyWith(height: lineHeight);
      case MarkdownBlockType.blockquote:
        return styleSheet.blockquote?.copyWith(height: lineHeight);
      case MarkdownBlockType.listItem:
        return styleSheet.p?.copyWith(height: lineHeight);
      case MarkdownBlockType.horizontalRule:
        return styleSheet.p?.copyWith(height: lineHeight, fontSize: fontSize);
      case MarkdownBlockType.paragraph:
        return styleSheet.p?.copyWith(height: lineHeight);
    }
  }

  TextSpan _parseInlineMarkdown(String text, TextStyle? baseStyle) {
    if (text.isEmpty) return TextSpan(text: '', style: baseStyle);
    final spans = <TextSpan>[];
    var remaining = text;
    final patterns = <_InlinePattern>[
      _InlinePattern(
        RegExp(r'`([^`]+)`'),
        (match) => TextSpan(
          text: match.group(1),
          style: styleSheet.code?.copyWith(height: lineHeight, fontSize: fontSize),
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
        RegExp(r'\*\*([^*]+)\*\*|__([^_]+)__'),
        (match) => TextSpan(
          text: match.group(1) ?? match.group(2) ?? '',
          style: (baseStyle ?? const TextStyle())
              .copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      _InlinePattern(
        RegExp(r'\*([^*]+)\*|_([^_]+)_'),
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
          style: styleSheet.a?.copyWith(height: lineHeight) ?? baseStyle,
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

  List<double> _splitBlockAcrossPages(
    MarkdownBlock block,
    int blockIndex,
    Map<int, List<String>> splitFragments,
  ) {
    final sentences = _splitSentences(block.strippedText);
    if (sentences.isEmpty) {
      return [_measureBlock(block) + block.totalVerticalMargin];
    }
    final fragmentHeights = <double>[];
    final fragments = <String>[];
    var currentText = '';
    var currentHeight = 0.0;

    for (var i = 0; i < sentences.length; i++) {
      final candidate =
          currentText.isEmpty ? sentences[i] : '$currentText ${sentences[i]}';
      final testBlock = MarkdownBlock(
        rawText: candidate,
        strippedText: candidate,
        type: block.type,
        textDirection: block.textDirection,
        headingLevel: block.headingLevel,
      );
      final testHeight = _measureBlock(testBlock);

      if (testHeight + block.totalVerticalMargin > contentHeight &&
          currentText.isNotEmpty) {
        final fragmentText = currentText.trim();
        if (fragmentText.isNotEmpty) {
          fragments.add(fragmentText);
          fragmentHeights.add(currentHeight + block.totalVerticalMargin);
        }
        currentText = sentences[i];
        final nextBlock = MarkdownBlock(
          rawText: sentences[i],
          strippedText: sentences[i],
          type: block.type,
          textDirection: block.textDirection,
          headingLevel: block.headingLevel,
        );
        currentHeight = _measureBlock(nextBlock);
      } else {
        currentText = candidate;
        currentHeight = testHeight;
      }
    }

    final remainingText = currentText.trim();
    if (remainingText.isNotEmpty) {
      fragments.add(remainingText);
      fragmentHeights.add(currentHeight + block.totalVerticalMargin);
    }

    if (fragments.isNotEmpty) {
      splitFragments[blockIndex] = fragments;
    }
    return fragmentHeights;
  }

  static List<String> _splitSentences(String text) {
    if (text.trim().isEmpty) return [];
    final parts = text.split(
      RegExp(r'(?<=[.!?\u061F\u060D\u0700\u0701\u0702\u003F])\s+(?=\S)'),
    );
    return parts
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  static List<String> _splitWords(String text) {
    if (text.trim().isEmpty) return [];
    // Split on whitespace to support both LTR and RTL text
    return text.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();
  }

  bool _canSplitBlock(MarkdownBlockType type) {
    return type == MarkdownBlockType.paragraph ||
        type == MarkdownBlockType.blockquote ||
        type == MarkdownBlockType.listItem;
  }

  List<String> _splitBlockForRemainingSpace(
    MarkdownBlock block,
    double availableHeight,
  ) {
    final words = _splitWords(block.strippedText);
    if (words.isEmpty) return [block.strippedText];
    final fragments = <String>[];
    var currentText = '';
    for (var i = 0; i < words.length; i++) {
      final candidate = currentText.isEmpty ? words[i] : '$currentText ${words[i]}';
      final testBlock = MarkdownBlock(
        rawText: candidate,
        strippedText: candidate,
        type: block.type,
        textDirection: block.textDirection,
        headingLevel: block.headingLevel,
      );
      final testHeight = _measureBlock(testBlock);
      if (testHeight > availableHeight && currentText.isNotEmpty) {
        fragments.add(currentText.trim());
        currentText = words[i];
      } else {
        currentText = candidate;
      }
    }
    if (currentText.trim().isNotEmpty) {
      fragments.add(currentText.trim());
    }
    return fragments;
  }

  List<List<PaginatedBlock>> _paginate(
    List<double> heights,
    List<MarkdownBlock> blocks,
    Map<int, List<String>> splitFragments,
  ) {
    if (heights.isEmpty) return [];

    final pageBlocks = <List<PaginatedBlock>>[];
    var currentPage = <PaginatedBlock>[];
    var usedHeight = 0.0;
    var heightIndex = 0;

    for (var i = 0; i < blocks.length; i++) {
      if (splitFragments.containsKey(i)) {
        for (var f = 0; f < splitFragments[i]!.length; f++) {
          final h = heights[heightIndex];
          heightIndex++;
          if (usedHeight + h > contentHeight) {
            debugPrint('PAGINATION: page break before fragment block $i frag $f (usedHeight=$usedHeight, h=$h, limit=$contentHeight)');
            pageBlocks.add(List.from(currentPage));
            currentPage.clear();
            usedHeight = 0;
          }
          final top = f == 0 ? blocks[i].blockTopMargin : 0.0;
          final bottom = f == splitFragments[i]!.length - 1 ? blocks[i].blockBottomMargin : 0.0;
          currentPage.add(PaginatedBlock(i, f, splitFragments[i]![f], top, bottom));
          usedHeight += h - blocks[i].totalVerticalMargin + top + bottom;
        }
      } else {
        final block = blocks[i];
        final h = heights[heightIndex];
        heightIndex++;
        if (usedHeight + h > contentHeight && currentPage.isNotEmpty) {
          if (_canSplitBlock(block.type)) {
            final remainingSpace = (contentHeight - usedHeight);
            final availableForText = remainingSpace - block.blockTopMargin - block.blockBottomMargin;
            if (availableForText > 0) {
              final fragments = _splitBlockForRemainingSpace(block, availableForText);
              for (var f = 0; f < fragments.length; f++) {
                final fragBlock = MarkdownBlock(
                  rawText: fragments[f],
                  strippedText: fragments[f],
                  type: block.type,
                  textDirection: block.textDirection,
                  headingLevel: block.headingLevel,
                );
                final fragHeight = _measureBlock(fragBlock);
                final top = f == 0 ? block.blockTopMargin : 0.0;
                final bottom = f == fragments.length - 1 ? block.blockBottomMargin : 0.0;
                final totalFragHeight = fragHeight + top + bottom;
                if (usedHeight + totalFragHeight > contentHeight && currentPage.isNotEmpty) {
                  debugPrint('PAGINATION: page break before block $i frag $f (usedHeight=$usedHeight, fragHeight=$totalFragHeight)');
                  pageBlocks.add(List.from(currentPage));
                  currentPage.clear();
                  usedHeight = 0;
                }
                currentPage.add(PaginatedBlock(i, f, fragments[f], top, bottom));
                usedHeight += totalFragHeight;
              }
              continue;
            }
          }
          debugPrint('PAGINATION: page break before block $i (usedHeight=$usedHeight, h=$h, limit=$contentHeight)');
          pageBlocks.add(List.from(currentPage));
          currentPage.clear();
          usedHeight = 0;
        }
        currentPage.add(PaginatedBlock(i, 0, block.rawText, block.blockTopMargin, block.blockBottomMargin));
        usedHeight += h;
      }
    }

    if (currentPage.isNotEmpty) {
      pageBlocks.add(currentPage);
    }
    return pageBlocks;
  }
}

class _InlinePattern {
  const _InlinePattern(this.regex, this.builder);
  final RegExp regex;
  final TextSpan Function(Match match) builder;
}
