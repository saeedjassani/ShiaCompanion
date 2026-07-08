import 'package:flutter/material.dart';

/// The type of a block-level element in the markdown content.
enum MarkdownBlockType {
  heading1,
  heading2,
  heading3,
  heading4,
  heading5,
  heading6,
  paragraph,
  blockquote,
  listItem,
  horizontalRule,
}

/// A single block-level element parsed from the markdown chapter content.
///
/// Each block has a known type, the raw markdown text, a stripped version
/// without block-level markers, a detected text direction (for correct
/// [TextPainter] measurement and rendering), and a heading level if applicable.
class MarkdownBlock {
  const MarkdownBlock({
    required this.rawText,
    required this.strippedText,
    required this.type,
    required this.textDirection,
    this.headingLevel = 0,
  });

  /// The original raw markdown text of this block.
  final String rawText;

  /// The block text with block-level markers removed
  /// (e.g. `# `, `> `, `- ` stripped).
  final String strippedText;

  /// The type of this block.
  final MarkdownBlockType type;

  /// The text direction for measuring and rendering this block.
  /// Use [TextDirection.rtl] for Arabic/Persian content.
  final TextDirection textDirection;

  /// The heading level (1-6) if [type] is a heading type, otherwise 0.
  final int headingLevel;

  /// The vertical margin above this block, matching typical MarkdownBody spacing.
  double get blockTopMargin {
    switch (type) {
      case MarkdownBlockType.heading1:
      case MarkdownBlockType.heading2:
      case MarkdownBlockType.heading3:
      case MarkdownBlockType.heading4:
      case MarkdownBlockType.heading5:
      case MarkdownBlockType.heading6:
        return 16.0;
      case MarkdownBlockType.blockquote:
        return 12.0;
      case MarkdownBlockType.listItem:
        return 4.0;
      case MarkdownBlockType.horizontalRule:
        return 16.0;
      case MarkdownBlockType.paragraph:
        return 0.0;
    }
  }

  /// The vertical margin below this block.
  double get blockBottomMargin {
    switch (type) {
      case MarkdownBlockType.heading1:
      case MarkdownBlockType.heading2:
      case MarkdownBlockType.heading3:
      case MarkdownBlockType.heading4:
      case MarkdownBlockType.heading5:
      case MarkdownBlockType.heading6:
        return 8.0;
      case MarkdownBlockType.blockquote:
        return 12.0;
      case MarkdownBlockType.listItem:
        return 4.0;
      case MarkdownBlockType.horizontalRule:
        return 16.0;
      case MarkdownBlockType.paragraph:
        return 0.0;
    }
  }

  /// Total vertical space (top + bottom) occupied by this block's margins.
  double get totalVerticalMargin => blockTopMargin + blockBottomMargin;

  @override
  String toString() =>
      'MarkdownBlock($type, heading=$headingLevel, $textDirection, '
      'stripped="${strippedText.length > 60 ? strippedText.substring(0, 60) : strippedText}")';
}
