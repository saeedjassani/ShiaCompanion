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

  test('parseDeepLinkUri captures a home-widget src marker on a clean path',
      () {
    final target = parseDeepLinkUri(
      Uri.parse(
        'https://shia-companion.web.app/zikr/ziyarat-e-ashura'
        '?src=home_widget_favorites',
      ),
    );

    expect(target?.segments, ['ziyarat-e-ashura']);
    expect(target?.source, 'home_widget_favorites');
  });

  test('parseDeepLinkUri captures a src marker from inside a hash route', () {
    final target = parseDeepLinkUri(
      Uri.parse(
        'https://shia-companion.web.app/#/zikr/ziyarat-e-ashura'
        '?src=home_widget_recitation',
      ),
    );

    expect(target?.segments, ['ziyarat-e-ashura']);
    expect(target?.source, 'home_widget_recitation');
  });

  test('parseDeepLinkUri leaves source null for an ordinary shared link', () {
    final target = parseDeepLinkUri(
      Uri.parse('https://shia-companion.web.app/zikr/ziyarat-e-ashura'),
    );

    expect(target?.source, isNull);
  });

  test('parseDeepLinkUri treats a blank src as no source at all', () {
    final target = parseDeepLinkUri(
      Uri.parse('https://shia-companion.web.app/zikr/ziyarat-e-ashura?src='),
    );

    expect(target?.source, isNull);
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

  group('parseLaunchRouteName', () {
    // These are the names that must get a route of their own on web. Anything
    // returning null here falls through to onUnknownRoute, which mounts home,
    // removes itself, and rewrites the address bar to "/" on the way out —
    // the flicker a shared link used to show.
    test('claims zikr links so the launch URL survives start-up', () {
      final target = parseLaunchRouteName('/zikr/dua-e-ahad');

      expect(target, isNotNull);
      expect(target!.type, zikrDeepLinkType);
      expect(target.segments, ['dua-e-ahad']);
    });

    test('claims library books and chapters', () {
      final book = parseLaunchRouteName('/library/nahjul-balagha');
      expect(book, isNotNull);
      expect(book!.type, libraryDeepLinkType);
      expect(book.segments, ['nahjul-balagha']);

      final chapter = parseLaunchRouteName('/library/nahjul-balagha/sermon-1');
      expect(chapter, isNotNull);
      expect(chapter!.type, libraryDeepLinkType);
      expect(chapter.segments, ['nahjul-balagha', 'sermon-1']);
    });

    test('claims legacy root-level slugs', () {
      final target = parseLaunchRouteName('/ziyarat-e-ashura');

      expect(target, isNotNull);
      expect(target!.type, zikrDeepLinkType);
      expect(target.segments, ['ziyarat-e-ashura']);
    });

    test('leaves the home route alone', () {
      expect(parseLaunchRouteName('/'), isNull);
      expect(parseLaunchRouteName(''), isNull);
      expect(parseLaunchRouteName(null), isNull);
    });

    test('leaves reserved paths to their own routes', () {
      // These have dedicated handling in onGenerateRoute above the launch
      // check; claiming them here would shadow it.
      expect(parseLaunchRouteName('/delete-account'), isNull);
      expect(parseLaunchRouteName('/widget-preview'), isNull);
      expect(parseLaunchRouteName('/callback'), isNull);
    });
  });
}
