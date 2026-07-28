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

  test('parseDeepLinkUri ignores query strings inside hash routes', () {
    final target = parseDeepLinkUri(
      Uri.parse(
        'https://shia-companion.web.app/#/zikr/ziyarat-e-ashura?from=share',
      ),
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

  test('parseDeepLinkUri decodes path segments exactly once', () {
    final target = parseDeepLinkUri(
      Uri.parse('https://shia-companion.web.app/#/zikr/dua%25percent'),
    );

    expect(target, isNotNull);
    expect(target?.segments, ['dua%percent']);
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

  test('extractZikrLinkSegment supports internal link shapes', () {
    expect(extractZikrLinkSegment('G1'), 'G1');
    expect(
        extractZikrLinkSegment('/zikr/ziyarat-e-ashura'), 'ziyarat-e-ashura');
    expect(
      extractZikrLinkSegment(
        'https://shia-companion.web.app/#/0/ziyarat-e-ashura',
      ),
      'ziyarat-e-ashura',
    );
    expect(
      extractZikrLinkSegment(
        'https://shia-companion.web.app/0/ziyarat-e-ashura',
      ),
      'ziyarat-e-ashura',
    );
    expect(
      extractZikrLinkSegment(
        'https://shia-companion.web.app/#/zikr/ziyarat-e-ashura?from=share',
      ),
      'ziyarat-e-ashura',
    );
    expect(
      extractZikrLinkSegment('https://example.com/zikr/dua%25percent'),
      'dua%percent',
    );
  });

  test('extractZikrLinkSegment ignores non-zikr routes and external pages', () {
    expect(extractZikrLinkSegment('/delete-account'), isNull);
    expect(extractZikrLinkSegment('https://example.com/articles/1'), isNull);
  });

  test('reserved non-zikr routes are recognized case-insensitively', () {
    expect(isReservedNonZikrRouteName('/CALLBACK'), isTrue);
    expect(isReservedNonZikrRouteName('/Delete-Account'), isTrue);
    expect(
      parseDeepLinkUri(Uri.parse('/Widget-Preview')),
      isNull,
    );
  });

  test('parseDeepLinkUri supports book-level library links', () {
    final target = parseDeepLinkUri(
      Uri.parse('https://shia-companion.web.app/library/some-book'),
    );

    expect(target, isNotNull);
    expect(target?.type, libraryDeepLinkType);
    expect(target?.segments, ['some-book']);
  });

  test('parseDeepLinkUri supports chapter-level library links', () {
    final target = parseDeepLinkUri(
      Uri.parse(
        'https://shia-companion.web.app/library/some-book/chapter-1',
      ),
    );

    expect(target, isNotNull);
    expect(target?.type, libraryDeepLinkType);
    expect(target?.segments, ['some-book', 'chapter-1']);
  });

  test('parseDeepLinkUri supports hash-based library links', () {
    final target = parseDeepLinkUri(
      Uri.parse('https://shia-companion.web.app/#/library/some-book'),
    );

    expect(target, isNotNull);
    expect(target?.type, libraryDeepLinkType);
    expect(target?.segments, ['some-book']);
  });

  test('parseDeepLinkUri rejects malformed library links', () {
    expect(
      parseDeepLinkUri(Uri.parse('https://shia-companion.web.app/library')),
      isNull,
    );
    expect(
      parseDeepLinkUri(
        Uri.parse('https://shia-companion.web.app/library/a/b/c'),
      ),
      isNull,
    );
  });

  test('buildLibraryDeepLinkPath builds book and chapter paths', () {
    expect(
      buildLibraryDeepLinkPath(bookSlug: 'some-book'),
      '/library/some-book',
    );
    expect(
      buildLibraryDeepLinkPath(
        bookSlug: 'some-book',
        chapterSlug: 'chapter-1',
      ),
      '/library/some-book/chapter-1',
    );
  });

  test('buildLibraryDeepLinkUrl builds an absolute share URL', () {
    expect(
      buildLibraryDeepLinkUrl(
        bookSlug: 'some-book',
        chapterSlug: 'chapter-1',
      ),
      'https://shia-companion.web.app/library/some-book/chapter-1',
    );
  });
}
