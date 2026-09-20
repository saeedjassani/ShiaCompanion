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
      expect(ZikrContentParser.formatArabicText('لَه بِه'), 'لَهٗ بِهٖ');
      expect(ZikrContentParser.formatArabicText('وَالْحِجَارَةُ ۖ'),
          'وَالْحِجَارَةُۖ');
    }
  });

  test('formatArabicText normalises waqf signs and spacing', () {
    // 1. Removes leading space before combining waqf marks so they attach to
    // the preceding word, and ensures space after.
    expect(
      ZikrContentParser.formatArabicText('فِيْهَا ؕ اَلَاۤ'),
      'فِيْهَاؕ اَلَاۤ',
    );
    expect(
      ZikrContentParser.formatArabicText('رَبَّهُمْ ؕ اَلَا'),
      'رَبَّهُمْؕ اَلَا',
    );

    // 2. Deduplicates conflicting adjacent waqf marks (e.g. Uthmani + Indo-Pak)
    expect(
      ZikrContentParser.formatArabicText('الْقُرْاٰنَ ۖ \uE01Cوَاِنْ'),
      'الْقُرْاٰنَ\uE01C وَاِنْ',
    );

    // 3. Preserves ruku mark while ensuring clean spacing before ayah medallion
    arabicFont = 'Qalam';
    expect(
      ZikrContentParser.formatArabicText('لِّثَمُوْدَ\uE022\u200F(68)'),
      'لِّثَمُوْدَ \uE022 (68)',
    );
    expect(
      ZikrContentParser.formatArabicText('جٰثِمِيْنَۙ\u200F(67)'),
      'جٰثِمِيْنَۙ (67)',
    );
    // Strips errant pause marks before ayah medallion (e.g. Yusuf 12:1, Ibrahim 14:37)
    // and maps mid-verse Qalam PUA pause mark \uE01E to clean high mark \uE01C.
    expect(
      ZikrContentParser.formatArabicText(
        'الٓرٰ\uE01E تِلْكَ اٰيٰتُ الْكِتٰبِ الْمُبِيْن\uE01E\u200F(1)',
      ),
      'الٓرٰ\uE01C تِلْكَ اٰيٰتُ الْكِتٰبِ الْمُبِيْن (1)',
    );
    expect(
      ZikrContentParser.formatArabicText(
        'مِنْ رَّبِّ الْعٰلَمِيْنَ\uE01E\u200F(37)',
      ),
      'مِنْ رَّبِّ الْعٰلَمِيْنَ (37)',
    );

    // 4. For Scheherazade, maps PUA marks to Unicode 14 and composes ayah marker
    arabicFont = 'Scheherazade';
    expect(
      ZikrContentParser.formatArabicText('الْقُرْاٰنَ ۖ \uE01Cوَاِنْ'),
      'الْقُرْاٰنَ\u08D7 وَاِنْ',
    );
    expect(
      ZikrContentParser.formatArabicText('لِّثَمُوْدَ\uE022\u200F(68)'),
      'لِّثَمُوْدَ \u08D6 ۝٦٨',
    );
    expect(
      ZikrContentParser.formatArabicText(
        'الٓرٰ\uE01E تِلْكَ اٰيٰتُ الْكِتٰبِ الْمُبِيْن\uE01E\u200F(1)',
      ),
      'الٓرٰ\u08DE تِلْكَ اٰيٰتُ الْكِتٰبِ الْمُبِيْن ۝١',
    );
  });

  test('formatArabicText does not split a word at a mid-word mark', () {
    // Indo-Pak text uses U+06D7 and U+06DC as letter marks inside a word
    // (Ayat al-Kursi's شَاۗءَ and اُولٰۗىِٕكَ, at-Tur's يَبْصُۜطُ), and stacks
    // combining marks (U+0615 U+0614) that must stay one cluster.
    const lines = [
      'شَا\u06D7ءَ',
      'اُولٰ\u06D7ىِٕكَ',
      'يَبْصُ\u06DCطُ',
      'فِيْهَا\u0615\u0614 اَلَا',
    ];
    for (final font in FontPreferences.validFonts) {
      arabicFont = font;
      for (final line in lines) {
        expect(ZikrContentParser.formatArabicText(line), line,
            reason: '$font must not add a space inside a word');
      }
    }
  });

  test('formatArabicText still separates a pause mark glued to the next word',
      () {
    // U+E01B directly followed by the next word's waw, as authored in A11.
    arabicFont = 'Qalam';
    expect(ZikrContentParser.formatArabicText('اَلْحَمْدْ\uE01Bوَ'),
        'اَلْحَمْدْ\uE01B وَ');
    arabicFont = 'Scheherazade';
    expect(ZikrContentParser.formatArabicText('اَلْحَمْدْ\uE01Bوَ'),
        'اَلْحَمْدْ\u08D5 وَ');
  });

  test('formatArabicText keeps the ruku mark after a pause mark', () {
    // Waqi'ah 40 is authored as U+0615 then the ruku mark then (40); nine
    // Quran lines end this way and must keep both signs.
    const line = 'الْاٰخِرِيْنَ\u0615\uE022\u200F(40)';
    arabicFont = 'Qalam';
    expect(ZikrContentParser.formatArabicText(line),
        'الْاٰخِرِيْنَ\u0615 \uE022 (40)');
    arabicFont = 'Scheherazade';
    expect(ZikrContentParser.formatArabicText(line),
        'الْاٰخِرِيْنَ\u0615 \u08D6 ۝٤٠');
  });

  test('formatArabicText strips a pause mark left against the medallion', () {
    // The Uthmani mark next to the Indo-Pak one is deduplicated away, which
    // leaves the Indo-Pak mark against (n) - that one must go too (90:11).
    arabicFont = 'Qalam';
    expect(
      ZikrContentParser.formatArabicText('الْعَقَبَةَ\uE01A\u06D6\u200F(11)'),
      'الْعَقَبَةَ (11)',
    );
    expect(
      ZikrContentParser.formatArabicText('سَلَامٌ \uE01E \u06D6(3)'),
      'سَلَامٌ (3)',
    );
  });

  test('formatArabicText keeps the zay and sad pause marks distinct', () {
    // Qalam draws U+E01A as a small ز (jā'iz) and U+E01B as a small ص
    // (qad yuṣal) - two different signs. Scheherazade has a glyph for each:
    // U+0617 (small high zain) and U+08D5 (small high sad).
    arabicFont = 'Scheherazade';
    // 7:195 is authored as the madda then U+E01A on the same alef.
    expect(ZikrContentParser.formatArabicText('بِهَا\u0653\uE01A اَمْ'),
        'بِهَا\u0653\u0617 اَمْ');
    // The mapped mark still gets the spacing every other pause mark gets.
    expect(ZikrContentParser.formatArabicText('بِهَا \uE01A اَمْ'),
        'بِهَا\u0617 اَمْ');
    expect(ZikrContentParser.formatArabicText('بِهَا\uE01Aاَمْ'),
        'بِهَا\u0617 اَمْ');
    expect(ZikrContentParser.formatArabicText('بِهَا\uE01B اَمْ'),
        'بِهَا\u08D5 اَمْ');
    // Qalam draws both itself, so the authored text is left as it is.
    arabicFont = 'Qalam';
    const line = 'بِهَا\u0653\uE01A اَمْ';
    expect(ZikrContentParser.formatArabicText(line), line);
  });

  test('formatArabicText maps E01D to a glyph Scheherazade has', () {
    // Qalam draws U+E01D itself, so it is left as authored there.
    arabicFont = 'Qalam';
    expect(
        ZikrContentParser.formatArabicText('كَذَا\uE01D وَ'), 'كَذَا\uE01D وَ');
    arabicFont = 'Scheherazade';
    expect(
        ZikrContentParser.formatArabicText('كَذَا\uE01D وَ'), 'كَذَا\u06D6 وَ');
  });

  test('formatArabicText returns a line with nothing to normalise as is', () {
    for (final font in FontPreferences.validFonts) {
      arabicFont = font;
      const line = 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيْمِ';
      expect(ZikrContentParser.formatArabicText(line), line);
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
