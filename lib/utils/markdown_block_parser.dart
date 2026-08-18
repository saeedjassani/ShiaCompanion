import 'package:flutter/material.dart';

import 'markdown_block.dart';

/// Parses raw markdown chapter text into a list of typed [MarkdownBlock]s.
///
/// The parser splits on blank lines (`\n\s*\n`) to identify block-level
/// elements, then classifies each block by type, detects text direction,
/// and strips block-level markers.
class MarkdownBlockParser {
  MarkdownBlockParser._();

  /// Characters used for right-to-left scripts (Arabic, Persian, Urdu, Hebrew).
  static final RegExp _rtlCharPattern = RegExp(
    r'[\u0590-\u05FF' // Hebrew
    r'\u0600-\u06FF' // Arabic
    r'\u0750-\u077F' // Arabic Supplement
    r'\u08A0-\u08FF' // Arabic Extended-A
    r'\uFB50-\uFDFF' // Arabic Presentation Forms-A
    r'\uFE70-\uFEFF' // Arabic Presentation Forms-B
    r']',
  );

  static final RegExp _blankLineSplit = RegExp(r'\n\s*\n');

  /// Matches a single "soft" line break within a block (as opposed to the
  /// blank-line block separators matched by [_blankLineSplit]). Mirrors the
  /// pattern flutter_markdown_plus uses internally when `softLineBreak` is
  /// false (the default): a lone `\n` is rendered as a space, not a line
  /// break. Source markdown is often hard-wrapped at a fixed column, so
  /// without this normalization, height measurement (which treats `\n` as a
  /// forced break) wildly overestimates how tall a block will render.
  static final RegExp _softLineBreak = RegExp(r' ?\n *');

  // Block-level marker patterns.
  static final RegExp _headingPattern = RegExp(r'^(#{1,6})\s');
  static final RegExp _blockquotePattern = RegExp(r'^>\s?');
  static final RegExp _unorderedListPattern = RegExp(r'^[\-\*\+]\s');
  // CommonMark accepts `)` as well as `.` after an ordered list's number, and
  // the library's chapters use both.
  static final RegExp _orderedListPattern = RegExp(r'^\d+[.)]\s');
  static final RegExp _horizontalRulePattern = RegExp(r'^[-*_]{3,}$');

  /// The underline of a setext heading — `Title` on one line with `===` (h1)
  /// or `---` (h2) under it. The library's chapters use this form as often as
  /// they use `#`, and a heading measured as body text is measured several
  /// points too small.
  static final RegExp _setextH1Underline = RegExp(r'^=+\s*$');
  static final RegExp _setextH2Underline = RegExp(r'^-+\s*$');

  /// Parse the raw [markdown] string into a list of [MarkdownBlock]s.
  static List<MarkdownBlock> parse(String markdown) {
    if (markdown.trim().isEmpty) return [];

    final rawBlocks = markdown.split(_blankLineSplit);
    final blocks = <MarkdownBlock>[];

    for (final raw in rawBlocks) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      final block = _classifyBlock(trimmed);
      blocks.add(block);
    }

    return blocks;
  }

  /// Classify a single trimmed block and produce a [MarkdownBlock].
  static MarkdownBlock _classifyBlock(String text) {
    final textDirection = _detectTextDirection(text);

    // Check horizontal rule first (must be a complete line match)
    if (_horizontalRulePattern.hasMatch(text.trim())) {
      return MarkdownBlock(
        rawText: text,
        strippedText: '',
        type: MarkdownBlockType.horizontalRule,
        textDirection: textDirection,
      );
    }

    // Check setext heading (`Title` with `===` or `---` underneath it). This
    // has to come before the list and paragraph checks: the content line above
    // the underline is the heading, whatever it looks like on its own.
    final setext = _setextHeading(text, textDirection);
    if (setext != null) return setext;

    // Check heading
    final headingMatch = _headingPattern.firstMatch(text);
    if (headingMatch != null) {
      final level = headingMatch.group(1)!.length;
      final stripped = text.replaceFirst(_headingPattern, '');
      final blockType = MarkdownBlockType.values
          .firstWhere((t) => t.name == 'heading$level');
      return MarkdownBlock(
        rawText: text,
        strippedText: _collapseSoftLineBreaks(stripped),
        type: blockType,
        textDirection: textDirection,
        headingLevel: level,
      );
    }

    // Check blockquote
    if (_blockquotePattern.hasMatch(text)) {
      // For blockquotes, also strip `>` from continuation lines
      final lines = text.split('\n');
      final strippedLines = lines.map((line) {
        return line.replaceFirst(_blockquotePattern, '');
      });
      return MarkdownBlock(
        rawText: text,
        strippedText: _collapseSoftLineBreaks(strippedLines.join('\n')),
        type: MarkdownBlockType.blockquote,
        textDirection: textDirection,
      );
    }

    // Check list item
    if (_unorderedListPattern.hasMatch(text) ||
        _orderedListPattern.hasMatch(text)) {
      final stripped = text
          .replaceFirst(_unorderedListPattern, '')
          .replaceFirst(_orderedListPattern, '');
      return MarkdownBlock(
        rawText: text,
        strippedText: _collapseSoftLineBreaks(stripped),
        type: MarkdownBlockType.listItem,
        textDirection: textDirection,
      );
    }

    // Default: paragraph
    return MarkdownBlock(
      rawText: text,
      strippedText: _collapseSoftLineBreaks(text),
      type: MarkdownBlockType.paragraph,
      textDirection: textDirection,
    );
  }

  /// The block as a setext heading, or null if its last line isn't a setext
  /// underline. Everything above the underline is the heading's text, matching
  /// how the markdown parser reads it.
  static MarkdownBlock? _setextHeading(String text, TextDirection direction) {
    final lines = text.split('\n');
    if (lines.length < 2) return null;

    final underline = lines.last;
    final int level;
    if (_setextH1Underline.hasMatch(underline)) {
      level = 1;
    } else if (_setextH2Underline.hasMatch(underline)) {
      level = 2;
    } else {
      return null;
    }

    final content = lines.take(lines.length - 1).join('\n').trim();
    if (content.isEmpty) return null;

    return MarkdownBlock(
      rawText: text,
      strippedText: _collapseSoftLineBreaks(content),
      type: level == 1
          ? MarkdownBlockType.heading1
          : MarkdownBlockType.heading2,
      textDirection: direction,
      headingLevel: level,
    );
  }

  /// Collapses soft line breaks the same way flutter_markdown_plus does when
  /// rendering (`softLineBreak: false`), so height measurement of
  /// [strippedText] matches how the text actually reflows on screen.
  static String _collapseSoftLineBreaks(String text) {
    return text.replaceAll(_softLineBreak, ' ');
  }

  /// Detect the text direction of a block's content.
  ///
  /// Returns [TextDirection.rtl] if the first non-whitespace character
  /// belongs to a right-to-left script, otherwise [TextDirection.ltr].
  static TextDirection _detectTextDirection(String text) {
    // Find the first significant character (non-whitespace, non-punctuation)
    for (var i = 0; i < text.length && i < 500; i++) {
      final char = text[i];
      if (_rtlCharPattern.hasMatch(char)) {
        return TextDirection.rtl;
      }
      // Skip whitespace and common ASCII punctuation
      if (char.trim().isEmpty || _isAsciiPunctuation(char)) {
        continue;
      }
      // First non-whitespace, non-punctuation character is LTR
      return TextDirection.ltr;
    }
    return TextDirection.ltr;
  }

  static bool _isAsciiPunctuation(String char) {
    // Use code-unit checks to avoid const string escaping issues.
    for (final c in char.codeUnits) {
      if (c == 46 ||
          c == 44 ||
          c == 59 ||
          c == 58 ||
          c == 33 ||
          c == 63 ||
          c == 45 ||
          c == 34 ||
          c == 39 ||
          c == 40 ||
          c == 41 ||
          c == 91 ||
          c == 93 ||
          c == 123 ||
          c == 125 ||
          c == 60 ||
          c == 62 ||
          c == 47 ||
          c == 64 ||
          c == 35 ||
          c == 36 ||
          c == 37 ||
          c == 94 ||
          c == 38 ||
          c == 42 ||
          c == 95 ||
          c == 126 ||
          c == 96 ||
          c == 43 ||
          c == 61 ||
          c == 124) {
        return true;
      }
    }
    return false;
  }
}