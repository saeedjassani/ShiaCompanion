import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/markdown_block.dart';
import 'package:shia_companion/utils/markdown_block_parser.dart';

void main() {
  test('blank input parses to no blocks', () {
    expect(MarkdownBlockParser.parse(''), isEmpty);
    expect(MarkdownBlockParser.parse('   \n  \n'), isEmpty);
  });

  test('blank lines split paragraphs into separate blocks', () {
    final blocks = MarkdownBlockParser.parse('First paragraph.\n\nSecond paragraph.');

    expect(blocks, hasLength(2));
    expect(blocks[0].type, MarkdownBlockType.paragraph);
    expect(blocks[0].strippedText, 'First paragraph.');
    expect(blocks[1].strippedText, 'Second paragraph.');
  });

  test('headings are classified by level and stripped of markers', () {
    final blocks = MarkdownBlockParser.parse('### A heading');

    expect(blocks, hasLength(1));
    expect(blocks.single.type, MarkdownBlockType.heading3);
    expect(blocks.single.headingLevel, 3);
    expect(blocks.single.strippedText, 'A heading');
  });

  test('blockquote markers are stripped from every line', () {
    final blocks = MarkdownBlockParser.parse('> line one\n> line two');

    expect(blocks.single.type, MarkdownBlockType.blockquote);
    // Soft line breaks collapse to a space, matching how MarkdownBody
    // renders them (softLineBreak: false) so measured height stays in
    // sync with the actual rendered height.
    expect(blocks.single.strippedText, 'line one line two');
  });

  test('a soft line break within a paragraph collapses to a space', () {
    final blocks = MarkdownBlockParser.parse('Hard-wrapped line one\nline two continues.');

    expect(blocks.single.strippedText, 'Hard-wrapped line one line two continues.');
  });

  test('unordered and ordered list markers are stripped', () {
    final unordered = MarkdownBlockParser.parse('- an item');
    final ordered = MarkdownBlockParser.parse('2. an item');

    expect(unordered.single.type, MarkdownBlockType.listItem);
    expect(unordered.single.strippedText, 'an item');
    expect(ordered.single.type, MarkdownBlockType.listItem);
    expect(ordered.single.strippedText, 'an item');
  });

  test('a run of three or more dashes is a horizontal rule with empty text', () {
    final blocks = MarkdownBlockParser.parse('---');

    expect(blocks.single.type, MarkdownBlockType.horizontalRule);
    expect(blocks.single.strippedText, '');
  });

  test('text starting with Arabic script is detected as right-to-left', () {
    final blocks = MarkdownBlockParser.parse('السلام عليكم');

    expect(blocks.single.textDirection, TextDirection.rtl);
  });

  test('leading punctuation is skipped when detecting text direction', () {
    final blocks = MarkdownBlockParser.parse('"السلام عليكم"');

    expect(blocks.single.textDirection, TextDirection.rtl);
  });

  test('latin text is detected as left-to-right', () {
    final blocks = MarkdownBlockParser.parse('Hello world');

    expect(blocks.single.textDirection, TextDirection.ltr);
  });

  test('a leading number does not make an Arabic quotation left-to-right', () {
    // The library numbers its quotations, and Ghurar al-Hikam opens thousands
    // of aphorisms exactly like this. A digit is weak in the Unicode bidi
    // algorithm: it takes the direction of its surroundings rather than
    // setting one.
    final blocks = MarkdownBlockParser.parse(
      '> 1\u0640 \u0627\u0644\u062F\u064F\u0651\u0646\u0652\u064A\u0627 '
      '\u062F\u0627\u0631\u064F \u0645\u064E\u0645\u064E\u0631\u064D\u0651.',
    );

    expect(blocks.single.textDirection, TextDirection.rtl);
  });

  test('digits of any script are weak', () {
    // Arabic-Indic digit, then Arabic text.
    expect(
      MarkdownBlockParser.parse('\u0667\u0640 \u0627\u0644\u0633\u0644\u0627\u0645')
          .single
          .textDirection,
      TextDirection.rtl,
    );
    // A number that really does open English prose stays left-to-right.
    expect(
      MarkdownBlockParser.parse('7. Be in this world as a stranger.')
          .single
          .textDirection,
      TextDirection.ltr,
    );
  });

  test('a block with no strong character falls back to left-to-right', () {
    expect(
      MarkdownBlockParser.parse('123 456').single.textDirection,
      TextDirection.ltr,
    );
  });

  test(
      'a run of consecutive list lines parses as one listItem block '
      'spanning all items', () {
    final blocks = MarkdownBlockParser.parse(
      '1. First item\n2. Second item\n3. Third item',
    );

    expect(blocks, hasLength(1));
    expect(blocks.single.type, MarkdownBlockType.listItem);
  });




}
