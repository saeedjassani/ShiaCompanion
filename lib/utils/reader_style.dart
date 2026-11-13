// MarkdownStyleSheet.fromTheme takes the framework's ThemeData, which
// MaterialUiCompatibilityBridge (in main.dart's MaterialApp.builder) mirrors
// from the app's material_ui theme.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// The line height the reader lays body text out at.
const double kReaderLineHeight = 1.55;

/// The reader's markdown styles, for one font size.
///
/// This lives outside [ChapterPage] because the pagination tests have to
/// measure a chapter with exactly the styles it renders in — a copy of this
/// that drifted by a point would test a layout the reader never produces.
MarkdownStyleSheet readerStyleSheet(
  BuildContext context, {
  required double fontSize,
}) {
  final theme = Theme.of(context);
  final textTheme = theme.textTheme;
  return MarkdownStyleSheet.fromTheme(legacy.Theme.of(context)).copyWith(
    // Justified body text is what makes a page read like a printed book
    // rather than a web page. WrapAlignment.spaceBetween is how
    // flutter_markdown_plus spells TextAlign.justify. Headings and list items
    // stay ragged-right — justifying short lines just stretches them.
    textAlign: WrapAlignment.spaceBetween,
    blockquoteAlign: WrapAlignment.spaceBetween,
    p: textTheme.bodyLarge?.copyWith(
      fontSize: fontSize,
      height: kReaderLineHeight,
    ),
    h1: textTheme.headlineSmall?.copyWith(fontSize: fontSize + 8),
    h2: textTheme.titleLarge?.copyWith(fontSize: fontSize + 5),
    h3: textTheme.titleMedium?.copyWith(fontSize: fontSize + 3),
    h4: textTheme.titleSmall?.copyWith(fontSize: fontSize + 2),
    h5: textTheme.titleSmall?.copyWith(fontSize: fontSize + 1),
    h6: textTheme.titleSmall?.copyWith(fontSize: fontSize),
    blockquote: textTheme.bodyLarge?.copyWith(
      fontSize: fontSize,
      height: kReaderLineHeight,
      fontStyle: FontStyle.italic,
    ),
    blockquotePadding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 4,
    ),
    // flutter_markdown_plus fills every blockquote with a hardcoded
    // Colors.blue.shade100 that ignores the theme — the same blue in dark mode
    // as in light. Most of this library's quotations are Qur'an and hadith, and
    // whole chapters alternate quote and commentary, so a filled panel turns
    // the page into bands of colour instead of marking anything. A rule down
    // the leading edge says "quotation" without tinting the text, and
    // BorderDirectional follows the block's own direction, so it sits on the
    // right of an Arabic quote and the left of an English one.
    blockquoteDecoration: BoxDecoration(
      border: BorderDirectional(
        start: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.45),
          width: 3,
        ),
      ),
    ),
    code: textTheme.bodyMedium?.copyWith(
      fontSize: fontSize - 2,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    ),
    a: textTheme.bodyLarge?.copyWith(
      fontSize: fontSize,
      color: theme.colorScheme.primary,
    ),
    // fromTheme takes these from the app's card and divider colours and
    // primaryColor, which the compatibility bridge doesn't carry over, so
    // they're set from the app's own theme, as fromTheme would have.
    checkbox: textTheme.bodyMedium?.copyWith(color: theme.primaryColor),
    tableBorder: TableBorder.all(color: theme.dividerColor),
    codeblockDecoration: BoxDecoration(
      color: theme.cardTheme.color ?? theme.cardColor,
      borderRadius: BorderRadius.circular(2.0),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(width: 5.0, color: theme.dividerColor)),
    ),
  );
}

/// [base] adjusted for a right-to-left block.
///
/// Arabic has no italic form. Asking for one gets a synthetic oblique — the
/// glyphs sheared over by software — which breaks the joins between letters and
/// is exactly the effect Arabic typography avoids. The library's blockquotes
/// are overwhelmingly Arabic, so the reader keeps the italic for quotations in
/// English and drops it everywhere the text runs right to left.
MarkdownStyleSheet rtlReaderStyleSheet(MarkdownStyleSheet base) {
  return base.copyWith(
    blockquote: base.blockquote?.copyWith(fontStyle: FontStyle.normal),
  );
}
