import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/services/home_screen_widget_service.dart';
import 'package:shia_companion/services/zikr_audio_index.dart';
import 'package:shia_companion/utils/slug_registry.dart';

void main() {
  setUp(clearLocalSlugMaps);
  tearDown(clearLocalSlugMaps);

  Map<String, String> snapshotFor(List<UniversalData> favorites) {
    return HomeScreenWidgetService.instance
        .buildFavoritesSnapshot(favorites: favorites);
  }

  List<String> titlesFrom(Map<String, String> snapshot) {
    return [
      for (final key in HomeScreenWidgetService.favoriteItemKeys)
        if ((snapshot[key] ?? '').isNotEmpty) snapshot[key]!,
    ];
  }

  List<String> urlsFrom(Map<String, String> snapshot) {
    return [
      for (final key in HomeScreenWidgetService.favoriteUrlKeys)
        if ((snapshot[key] ?? '').isNotEmpty) snapshot[key]!,
    ];
  }

  test('library favourites reach the widget alongside zikr ones', () {
    final snapshot = snapshotFor([
      UniversalData('101', 'Dua Kumayl', 0),
      UniversalData('nahjul-balagha', 'Nahjul Balagha', 1),
    ]);

    expect(titlesFrom(snapshot), ['Dua Kumayl', 'Nahjul Balagha']);
    expect(urlsFrom(snapshot), [
      'https://shiacompanion.app/0/101?src=home_widget_favorites',
      'https://shiacompanion.app/library/nahjul-balagha'
          '?src=home_widget_favorites',
    ]);
  });

  test('a library favourite links by its book slug', () {
    final snapshot = snapshotFor([
      UniversalData('  mafatih-al-jinan  ', 'Mafatih al-Jinan', 1),
    ]);

    expect(
      urlsFrom(snapshot),
      [
        'https://shiacompanion.app/library/mafatih-al-jinan'
            '?src=home_widget_favorites',
      ],
    );
  });

  test('a zikr favourite still prefers its registered slug', () {
    setLocalSlugData('101', slug: 'dua-kumayl');

    final snapshot = snapshotFor([UniversalData('101', 'Dua Kumayl', 0)]);

    expect(
      urlsFrom(snapshot),
      [
        'https://shiacompanion.app/zikr/dua-kumayl'
            '?src=home_widget_favorites',
      ],
    );
  });

  test('every widget URL is tagged with where it was tapped from', () {
    // So a tap on the widget shows up on the dashboard as its own source
    // instead of collapsing into the generic "shared link" one.
    final snapshot = snapshotFor([
      UniversalData('101', 'Dua Kumayl', 0),
      UniversalData('nahjul-balagha', 'Nahjul Balagha', 1),
    ]);

    for (final url in urlsFrom(snapshot)) {
      expect(Uri.parse(url).queryParameters['src'], 'home_widget_favorites');
    }
  });

  test('shrines and channels stay out, having nothing to open', () {
    final snapshot = snapshotFor([
      UniversalData('https://example.com/stream', 'Karbala Live', 2),
      UniversalData('202', 'Ziyarat Ashura', 0),
    ]);

    expect(titlesFrom(snapshot), ['Ziyarat Ashura']);
  });

  test('every rendered favourite carries a link', () {
    final snapshot = snapshotFor([
      UniversalData('101', 'Dua Kumayl', 0),
      UniversalData('nahjul-balagha', 'Nahjul Balagha', 1),
      UniversalData('https://example.com/stream', 'Karbala Live', 2),
    ]);

    expect(titlesFrom(snapshot).length, urlsFrom(snapshot).length);
  });

  test('an empty favourites list still fills the first row', () {
    final snapshot = snapshotFor([]);

    expect(titlesFrom(snapshot), ['No favorites yet']);
    expect(urlsFrom(snapshot), isEmpty);
  });

  group('play buttons', () {
    setUp(() {
      ZikrAudioIndex.instance.setForTest(ZikrAudioIndex.parse({
        '101': [
          {'file': 'kumayl.mp3'},
        ],
      }));
    });
    tearDown(() => ZikrAudioIndex.instance.setForTest(const {}));

    List<String> playUrlsFrom(Map<String, String> snapshot) => [
          for (final key in HomeScreenWidgetService.favoritePlayUrlKeys)
            snapshot[key] ?? '',
        ];

    test('a zikr with a recording gets a play link, tagged like its row', () {
      setLocalSlugData('101', slug: 'dua-kumayl');

      final snapshot = snapshotFor([UniversalData('101', 'Dua Kumayl', 0)]);

      expect(
        playUrlsFrom(snapshot).first,
        'https://shiacompanion.app/play/dua-kumayl?src=home_widget_favorites',
      );
    });

    test('nothing to play, no button', () {
      final snapshot = snapshotFor([
        UniversalData('202', 'Ziyarat Ashura', 0),
        UniversalData('nahjul-balagha', 'Nahjul Balagha', 1),
        UniversalData('101', 'Dua Kumayl', 0),
      ]);

      expect(playUrlsFrom(snapshot).take(3), [
        '',
        '',
        'https://shiacompanion.app/play/101?src=home_widget_favorites',
      ]);
      // Rows past the last favourite are cleared, not left from before.
      expect(playUrlsFrom(snapshot).skip(3), everyElement(isEmpty));
    });

    test('the button has a label for screen readers', () {
      final snapshot = snapshotFor([UniversalData('101', 'Dua Kumayl', 0)]);

      expect(snapshot[HomeScreenWidgetService.playLabelKey], 'Play recitation');
    });
  });
}
