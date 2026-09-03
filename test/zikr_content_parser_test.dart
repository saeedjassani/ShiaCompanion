import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/zikr/zikr_content_parser.dart';
import 'package:shia_companion/utils/font_preferences.dart';

void main() {
  tearDown(() {
    arabicFont = 'Qalam';
  });

  test('formatArabicText leaves Indo-Pak letterforms and marks intact', () {
    // The substitution table that used to rewrite these existed only because
    // MeQuran and Uthmani could not draw them. Both fonts are gone; Qalam and
    // Scheherazade both draw every one, so the text renders as authored.
    const line = 'اَللّٰھُمَّ یَا سَبَبَ لَهٗ بِهٖ الْڪِتٰبُ اللہ';
    for (final font in FontPreferences.validFonts) {
      arabicFont = font;
      expect(ZikrContentParser.formatArabicText(line), line,
          reason: '$font must not rewrite Indo-Pak letterforms');
    }
  });

  test('formatArabicText normalises private-use marks and spaces', () {
    // Qalam maps U+E003/U+E004 and U+0656/U+0657 to the same glyphs, so this
    // is invisible in Qalam and is what lets other fonts draw the marks.
    for (final font in FontPreferences.validFonts) {
      arabicFont = font;
      expect(ZikrContentParser.formatArabicText('لَه بِه'),
          'لَهٗ بِهٖ');
      expect(ZikrContentParser.formatArabicText('وَالْحِجَارَةُ ۖ'),
          'وَالْحِجَارَةُ ۖ');
    }
  });

  test('formatArabicText draws the ayah medallion for fonts that compose it',
      () {
    arabicFont = 'Scheherazade';
    expect(ZikrContentParser.formatArabicText('الرَّحِيْمِ (3)'),
        'الرَّحِيْمِ ۝٣');
    expect(ZikrContentParser.formatArabicText('اٰيَةُ الْكُرْسِىِّ (255)'),
        'اٰيَةُ الْكُرْسِىِّ ۝٢٥٥');
  });

  test('formatArabicText leaves ayah numbers alone for Qalam', () {
    // Qalam draws its own medallion from the ASCII parentheses, and renders
    // U+06DD as an empty ornament that swallows the digits.
    arabicFont = 'Qalam';
    expect(ZikrContentParser.formatArabicText('الرَّحِيْمِ (3)'),
        'الرَّحِيْمِ (3)');
  });

  test('formatArabicText leaves list numbering that leads a line', () {
    // Eight lines across the corpus open with "(1)" as ordinary numbering
    // rather than closing with a verse number.
    arabicFont = 'Scheherazade';
    const line = '(1) اَشْهَدُ اَنْ لَاۤ اِلٰهَ اِلَّا اللّٰهُ';
    expect(ZikrContentParser.formatArabicText(line), line);
  });

  test('formatArabicText leaves no glyph-less character in any bundled zikr',
      () {
    // Characters the shipped fonts have no glyph for, so they would be drawn
    // from a system fallback instead. Scheherazade covers every Indo-Pak
    // letterform, which is why this list is now only the private-use pause
    // signs — and those are deliberately left in place for the Qalam
    // fontFamilyFallback in the reader to resolve, because no font other
    // than Qalam has them and no Unicode codepoint exists to move them to.
    const alwaysAbsent = [' ', ' ', '', ''];
    final dir = Directory('assets/zikr');
    final offenders = <String>[];

    for (final font in FontPreferences.validFonts) {
      arabicFont = font;
      for (final file in dir.listSync().whereType<File>()) {
        final decoded = json.decode(file.readAsStringSync());
        if (decoded is! Map) continue;
        final sources = <String>[
          if (decoded['data'] is String) decoded['data'] as String,
          if (decoded['merits'] is String) decoded['merits'] as String,
          if (decoded['tabs'] is List)
            ...(decoded['tabs'] as List).whereType<String>(),
        ];
        for (final source in sources) {
          final formatted = ZikrContentParser.formatArabicText(source);
          for (final ch in alwaysAbsent) {
            if (formatted.contains(ch)) {
              offenders.add('$font ${file.path}: still contains '
                  'U+${ch.codeUnitAt(0).toRadixString(16).toUpperCase()}');
            }
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.take(20).join('\n'));
  });

  test('isArabic scans each early character', () {
    expect(ZikrContentParser.isArabic('* بسم الله'), isTrue);
    expect(ZikrContentParser.isArabic('English only'), isFalse);
  });

  test('parseContent trims lines and maps code 102 around Arabic text', () {
    final parsed = ZikrContentParser.parseContent(
      'Header\n transliteration \n بسم الله \n translation ',
      hideHeaderLine: true,
      code: '102',
    );

    expect(parsed.lines, [
      'transliteration',
      'بسم الله',
      'translation',
    ]);
    expect(parsed.arabicCodes, {1});
    expect(parsed.transliCodes, {0});
    expect(parsed.translaCodes, {2});
  });

  test('parseLineSegments keeps plain text around markdown links', () {
    final segments = ZikrContentParser.parseLineSegments(
      'Read [source](https://example.com) and [more](/zikr/G1).',
    );

    expect(segments, hasLength(5));
    expect(segments[0].text, 'Read ');
    expect(segments[0].href, isNull);
    expect(segments[1].text, 'source');
    expect(segments[1].href, 'https://example.com');
    expect(segments[2].text, ' and ');
    expect(segments[3].text, 'more');
    expect(segments[3].href, '/zikr/G1');
    expect(segments[4].text, '.');
  });
}
