import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/services/home_screen_widget_service.dart';
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
      'https://shia-companion.web.app/0/101?src=home_widget_favorites',
      'https://shia-companion.web.app/library/nahjul-balagha'
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
        'https://shia-companion.web.app/library/mafatih-al-jinan'
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
        'https://shia-companion.web.app/zikr/dua-kumayl'
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
}
