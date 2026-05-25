import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_content_parser.dart';

void main() {
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
