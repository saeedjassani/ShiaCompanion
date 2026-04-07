import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/deep_links.dart';

void main() {
  test('parseDeepLinkUri supports hash-based zikr links', () {
    final target = parseDeepLinkUri(
      Uri.parse('https://shia-companion.web.app/#/0/ziyarat-e-ashura'),
    );

    expect(target, isNotNull);
    expect(target?.type, 0);
    expect(target?.segments, ['ziyarat-e-ashura']);
  });

  test('parseDeepLinkUri supports clean zikr paths', () {
    final target = parseDeepLinkUri(
      Uri.parse('https://shia-companion.web.app/zikr/ziyarat-e-ashura'),
    );

    expect(target, isNotNull);
    expect(target?.type, 0);
    expect(target?.segments, ['ziyarat-e-ashura']);
  });

  test('buildZikrDeepLinkUrl prefers clean path URLs', () {
    final url = buildZikrDeepLinkUrl(
      uid: 'G1',
      slug: 'ziyarat-e-ashura',
    );

    expect(
      url,
      'https://shia-companion.web.app/zikr/ziyarat-e-ashura',
    );
  });
}
