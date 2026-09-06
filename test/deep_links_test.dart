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

    test('claims quran links', () {
      final surah = parseLaunchRouteName('/quran/23');
      expect(surah, isNotNull);
      expect(surah!.type, quranDeepLinkType);
      expect(surah.segments, ['23']);

      final verse = parseLaunchRouteName('/quran/23/56');
      expect(verse!.type, quranDeepLinkType);
      expect(verse.segments, ['23', '56']);
    });
  });

  group('quran links', () {
    DeepLinkTarget? parse(String path) =>
        parseDeepLinkUri(Uri.parse('https://shia-companion.web.app$path'));

    test('a bare /quran names the Quran screen', () {
      final target = parse('/quran');

      expect(target, isNotNull);
      expect(target!.type, quranDeepLinkType);
      expect(target.segments, isEmpty);
    });

    test('opens a whole surah', () {
      final target = parse('/quran/23');

      expect(target!.type, quranDeepLinkType);
      expect(target.segments, ['23']);
    });

    test('opens a verse in either path form', () {
      for (final path in ['/quran/23/56', '/quran/23:56']) {
        final target = parse(path);
        expect(target, isNotNull, reason: 'failed on $path');
        expect(target!.type, quranDeepLinkType, reason: 'failed on $path');
        expect(target.segments, ['23', '56'], reason: 'failed on $path');
      }
    });

    test('normalises every single-segment separator to one shape', () {
      // "." and "-" both reach us in shared text; a reader should not have to
      // know which one the app prefers.
      for (final separator in [':', '.', '-']) {
        final target = parse('/quran/23${separator}56');
        expect(target?.segments, ['23', '56'],
            reason: 'failed on separator "$separator"');
      }
    });

    test('reads a juz', () {
      final target = parse('/quran/juz/5');

      expect(target!.type, quranDeepLinkType);
      expect(target.segments, [quranJuzSegment, '5']);
    });

    test('works through a hash route the same as a path', () {
      final target = parseDeepLinkUri(
        Uri.parse('https://shia-companion.web.app/#/quran/23/56'),
      );

      expect(target!.type, quranDeepLinkType);
      expect(target.segments, ['23', '56']);
    });

    test('rejects shapes that are not verses', () {
      for (final path in [
        '/quran/al-baqarah',
        '/quran/23/56/78',
        '/quran/juz',
        '/quran/juz/five',
        '/quran/23:',
      ]) {
        expect(parse(path), isNull, reason: 'accepted $path');
      }
    });

    test('never falls through to the legacy bare-slug branch', () {
      // Without "quran" being reserved, a malformed Quran link would resolve
      // as a zikr slug and open the wrong thing rather than a not-found page.
      final target = parse('/quran/al-baqarah');
      expect(target, isNull);
    });

    test('builds the canonical path and url', () {
      expect(buildQuranDeepLinkPath(surah: 23, ayah: 56), '/quran/23/56');
      expect(buildQuranDeepLinkPath(surah: 23), '/quran/23');
      expect(buildQuranJuzDeepLinkPath(5), '/quran/juz/5');
      expect(
        buildQuranDeepLinkUrl(surah: 23, ayah: 56),
        'https://shia-companion.web.app/quran/23/56',
      );
    });
  });

  group('a zikr link with an ayah on it', () {
    DeepLinkTarget? parse(String path) =>
        parseDeepLinkUri(Uri.parse('https://shia-companion.web.app$path'));

    test('takes the slash form someone would type', () {
      final target = parse('/zikr/3-aal-e-imraan/91');

      expect(target!.type, zikrDeepLinkType);
      expect(target.segments, ['3-aal-e-imraan', '91']);
      expect(zikrDeepLinkAyah(target), 91);
    });

    test('takes the colon form too', () {
      final target = parse('/zikr/3-aal-e-imraan:35');

      expect(target!.type, zikrDeepLinkType);
      expect(target.segments, ['3-aal-e-imraan', '35']);
      expect(zikrDeepLinkAyah(target), 35);
    });

    test('a slug with digits and hyphens survives either form', () {
      // The slug itself is full of the characters being split on, so this is
      // the case a naive split would get wrong.
      expect(parse('/zikr/3-aal-e-imraan')!.segments, ['3-aal-e-imraan']);
      expect(parse('/zikr/2-al-baqarah/255')!.segments, ['2-al-baqarah', '255']);
    });

    test('a plain slug still carries no ayah', () {
      final target = parse('/zikr/ziyarat-e-ashura');

      expect(target!.segments, ['ziyarat-e-ashura']);
      expect(zikrDeepLinkAyah(target), isNull);
    });

    test('rejects a trailing part that is not a number', () {
      expect(parse('/zikr/3-aal-e-imraan/notaverse'), isNull);
      expect(parse('/zikr/3-aal-e-imraan:notaverse'), isNull);
    });

    test('rejects an empty slug', () {
      expect(parse('/zikr/:35'), isNull);
    });

    test('the launch route claims it too', () {
      final target = parseLaunchRouteName('/zikr/3-aal-e-imraan/91');
      expect(target!.segments, ['3-aal-e-imraan', '91']);
    });
  });

  group('links that worked before still work', () {
    // Adding the Quran type reserved a new path prefix and added a branch to
    // the parser. These are the forms already in the wild.
    DeepLinkTarget? parse(String url) => parseDeepLinkUri(Uri.parse(url));

    test('clean zikr slugs', () {
      final target = parse('https://shia-companion.web.app/zikr/2-al-baqarah');
      expect(target!.type, zikrDeepLinkType);
      expect(target.segments, ['2-al-baqarah']);
    });

    test('numeric zikr uids', () {
      final target = parse('https://shia-companion.web.app/0/A6');
      expect(target!.type, zikrDeepLinkType);
      expect(target.segments, ['A6']);
    });

    test('legacy root-level slugs', () {
      final target = parse('https://shia-companion.web.app/2-al-baqarah');
      expect(target!.type, zikrDeepLinkType);
      expect(target.segments, ['2-al-baqarah']);
    });

    test('library books and chapters', () {
      final target =
          parse('https://shia-companion.web.app/library/some-book/chapter-1');
      expect(target!.type, libraryDeepLinkType);
      expect(target.segments, ['some-book', 'chapter-1']);
    });

    test('hash-routed links', () {
      final target =
          parse('https://shia-companion.web.app/#/zikr/ziyarat-e-ashura');
      expect(target!.type, zikrDeepLinkType);
      expect(target.segments, ['ziyarat-e-ashura']);
    });

    test('reserved paths are still not zikrs', () {
      expect(parse('https://shia-companion.web.app/delete-account'), isNull);
      expect(parse('https://shia-companion.web.app/callback'), isNull);
    });
  });
}
