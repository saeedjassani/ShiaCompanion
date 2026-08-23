import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/zikr/zikr_content_parser.dart';

void main() {
  tearDown(() {
    arabicFont = 'Qalam';
  });

  test('formatArabicText leaves Qalam text untouched', () {
    arabicFont = 'Qalam';
    expect(ZikrContentParser.formatArabicText('وَ اَنَا وَ لِىٌّ لَهٗ'),
        'وَ اَنَا وَ لِىٌّ لَهٗ');
  });

  test('formatArabicText flattens ulta pesh / khaṛi zer for non-Qalam fonts',
      () {
    // Uthmani has U+0657 in its cmap but draws it as a slanted stroke that
    // reads as a fatha, so leaving it through turns "lahu" into "laha".
    // The marks stay intact in the stored text; only rendering flattens them.
    arabicFont = 'Uthmani';
    expect(ZikrContentParser.formatArabicText('لَهٗ'), 'لَهُ');
    expect(ZikrContentParser.formatArabicText('اٰيَاتِهٖ'), 'اٰيَاتِهِ');
    arabicFont = 'MeQuran';
    expect(ZikrContentParser.formatArabicText('بِهٖ وَ'), 'بِهِ وَ');
    arabicFont = 'Qalam';
    expect(ZikrContentParser.formatArabicText('لَهٗ'), 'لَهٗ');
  });

  test('formatArabicText maps Indo-Pak letterforms to standard Arabic', () {
    arabicFont = 'MeQuran';
    expect(ZikrContentParser.formatArabicText('اَللّٰھُمَّ یَا سَبَبَ'),
        'اَللّٰهُمَّ يَا سَبَبَ');
    // Urdu spelling of "Allah" (ہ, not ه) must still be caught.
    expect(ZikrContentParser.formatArabicText('اللہ'), 'اللّٰه');
  });

  test('formatArabicText expands the single-codepoint Allah ligature', () {
    arabicFont = 'Uthmani';
    // The ligature carries its own alif: the result must not double it.
    expect(ZikrContentParser.formatArabicText('صَلَّی اﷲُ عَلٰی'),
        'صَلَّي اللّٰهُ عَلٰي');
    expect(ZikrContentParser.formatArabicText('اَﷲُ'), 'اَللّٰهُ');
  });

  test(
      'formatArabicText leaves no glyph-less character in any bundled zikr',
      () {
    // Characters each font's file has no glyph for, so they would be drawn
    // from a system fallback instead of the selected font. Verified against
    // the real cmaps by scripts/zikr_arabic/audit.py (INV-2); this test is
    // the cheap guard that runs on every change.
    //
    // ٗ (ulta pesh) and ٖ (khaṛi zer) are deliberately absent from both lists:
    // they're correct, distinct Indo-Pak marks, not something to flatten
    // away, and all three fonts carry them.
    const perFont = {
      'Uthmani': ['ی', 'ہ', 'ھ', 'ک', 'ۃ', 'ﷲ'],
      'MeQuran': ['ی', 'ہ', 'ھ', 'ک', 'ۃ', 'ﷲ', 'ؕ', 'ٮ'],
    };
    final dir = Directory('assets/zikr');
    final offenders = <String>[];

    for (final entry in perFont.entries) {
      arabicFont = entry.key;
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
          for (final ch in entry.value) {
            if (formatted.contains(ch)) {
              offenders.add('${entry.key} ${file.path}: still contains $ch');
            }
          }
          if (formatted.contains('الله')) {
            offenders.add('${entry.key} ${file.path}: "الله" unconverted');
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
