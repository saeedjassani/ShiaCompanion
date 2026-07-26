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
      remaining.add(_BlockWithHeight(i, block, block.rawText, h));
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
            page.add(PaginatedBlock(
              item.index, 0, split.key,
              item.block.blockTopMargin, 0.0,
            ));
            used += contentHeight; // fill the page
            // Replace remaining with the rest
            final remainderH = _measureBlock(MarkdownBlock(
              rawText: split.value, strippedText: split.value,
              type: item.block.type, textDirection: item.block.textDirection,
              headingLevel: item.block.headingLevel,
            ));
            remaining[0] = _BlockWithHeight(item.index, item.block, split.value, remainderH);
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
              PaginatedBlock(item.index, 0, frag, item.block.blockTopMargin, item.block.blockBottomMargin),
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

    final text = block.strippedText;
    if (text.trim().isEmpty) return null;

    // Try by sentences (natural)
    final sentences = _splitSentences(text);
    if (sentences.length >= 2) {
      for (var i = sentences.length - 1; i >= 1; i--) {
        final firstPart = sentences.take(i).join(' ');
        final h = _measureBlock(MarkdownBlock(
          rawText: firstPart, strippedText: firstPart,
          type: block.type, textDirection: block.textDirection,
          headingLevel: block.headingLevel,
        ));
        if (h <= effectiveHeight) {
          return MapEntry(sentences.take(i).join(' '), sentences.skip(i).join(' '));
        }
      }
    }

    // Fall back to word-level splitting. This also covers the case where the
    // block has multiple sentences but even the first one doesn't fit — we
    // still want to use as much of the remaining page space as possible
    // instead of leaving it blank.
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 2) return null;
    for (var i = words.length - 1; i >= 1; i--) {
      final firstPart = words.take(i).join(' ');
      final h = _measureBlock(MarkdownBlock(
        rawText: firstPart, strippedText: firstPart,
        type: block.type, textDirection: block.textDirection,
        headingLevel: block.headingLevel,
      ));
      if (h <= effectiveHeight) {
        return MapEntry(firstPart, words.skip(i).join(' '));
      }
    }

    return null;
  }

  /// Split a block into page-sized fragments (for blocks taller than a page).
  List<String> _splitIntoPages(MarkdownBlock block) {
    final available = contentHeight - block.totalVerticalMargin;
    if (available <= 0) return [block.strippedText];

    final fragments = <String>[];
    var remaining = block.strippedText;

    while (remaining.isNotEmpty) {
      final split = _splitAtHeight(
        MarkdownBlock(
          rawText: remaining, strippedText: remaining,
          type: block.type, textDirection: block.textDirection,
          headingLevel: block.headingLevel,
        ),
        contentHeight,
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

  static List<String> _splitSentences(String text) {
    if (text.trim().isEmpty) return [];
    return text.split(
      RegExp(r'(?<=[.!?\u061F\u060D\u0700\u0701\u0702\u003F])\s+(?=\S)'),
    ).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }
}

class _BlockWithHeight {
  const _BlockWithHeight(this.index, this.block, this.text, this.height);
  final int index;
  final MarkdownBlock block;
  final String text;
  final double height;
}

class _InlinePattern {
  const _InlinePattern(this.regex, this.builder);
  final RegExp regex;
  final TextSpan Function(Match match) builder;
}