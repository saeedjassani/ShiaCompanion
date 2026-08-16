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

  test(
      'formatArabicText leaves khaṛi zer / ulta pesh untouched (distinct marks, not shorthand)',
      () {
    arabicFont = 'Uthmani';
    expect(ZikrContentParser.formatArabicText('لَهٗ'), 'لَهٗ');
    expect(ZikrContentParser.formatArabicText('اٰيَاتِهٖ'), 'اٰيَاتِهٖ');
    expect(ZikrContentParser.formatArabicText('بِهٖ وَ'), 'بِهٖ وَ');
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
    expect(ZikrContentParser.formatArabicText('صَلَّی اﷲُ عَلٰی'),
        contains('اللّٰهُ'));
  });

  test(
      'formatArabicText leaves no Indo-Pak-only character in any bundled zikr',
      () {
    arabicFont = 'Uthmani';
    // ٗ (ulta pesh) and ٖ (khaṛi zer) are deliberately excluded: they're
    // correct, distinct Indo-Pak marks, not something to flatten away.
    const indoPakOnly = ['ی', 'ہ', 'ھ', 'ک', 'ۃ', 'ﷲ'];
    final dir = Directory('assets/zikr');
    final offenders = <String>[];
    for (final entry in dir.listSync().whereType<File>()) {
      final decoded = json.decode(entry.readAsStringSync());
      if (decoded is! Map || decoded['data'] is! String) continue;
      final formatted =
          ZikrContentParser.formatArabicText(decoded['data'] as String);
      for (final ch in indoPakOnly) {
        if (formatted.contains(ch)) {
          offenders.add('${entry.path}: still contains $ch');
        }
      }
      if (formatted.contains('الله')) {
        offenders.add('${entry.path}: "الله" survived unconverted');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
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
