import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/navigation/home_menu.dart';
import 'package:shia_companion/services/home_shortcuts_store.dart';

void main() {
  test('home menu labels and icons come from the same definitions', () {
    final labels = homeMenuItems.map((item) => item.label).toList();
    final icons = homeMenuItems.map((item) => item.icon).toList();

    expect(labels.toSet(), hasLength(labels.length));
    expect(
      icons.toSet(),
      hasLength(icons.length),
      reason: 'Home menu icons must not be repeated; duplicate icons found.',
    );
    expect(zikr, equals(labels));
    expect(zikrIcons, equals(icons));
  });

  test('all home menu items build valid icons or custom glyphs', () {
    for (final item in homeMenuItems) {
      final iconWidget = item.buildIcon(size: 24, color: Colors.white);
      expect(iconWidget, isNotNull, reason: item.label);
    }
  });

  test('all home menu labels resolve to a concrete page', () {
    for (final item in homeMenuItems) {
      expect(getPage(item.label), isNot(isA<Container>()), reason: item.label);
    }

    expect(getHomeMenuItem('Munajaat')?.label, 'Munajaat');
    expect(getHomeMenuItem('Munajaats'), isNull);
    expect(getPage('Munajaat'), isNot(isA<Container>()));
  });

  test('every menu item keeps the analytics id its label used to derive', () {
    // Counters are keyed home_menu_<analyticsId>. These are the ids the old
    // label-derived getter produced; a relabelled item must keep its id, or
    // its history forks under a new key.
    expect(
      {for (final item in allHomeMenuItems) item.label: item.analyticsId},
      {
        'Favorites': 'favorites',
        "Today's Recitations": 'today_s_recitations',
        'Taqeebat e Namaz': 'taqeebat_e_namaz',
        'Namaz': 'namaz',
        'Duas': 'duas',
        'Ziyarats': 'ziyarats',
        'Surahs': 'surahs',
        'Aamaal': 'aamaal',
        'Calendar & Prayer Times': 'calendar_prayer_times',
        'Library': 'library',
        'Munajaat': 'munajaat',
        'Baaqeyaat As Saalehaat': 'baaqeyaat_as_saalehaat',
        'Playlists': 'playlists',
        'Qibla Finder': 'qibla_finder',
        'Tasbeeh Counter': 'tasbeeh_counter',
        'Qaza Tracker': 'qaza_tracker',
        // Android and iOS only.
        if (supportsPrayerCounterOnCurrentPlatform)
          'Rakaat Counter': 'rakaat_counter',
        'Prayer Times in Flight': 'prayer_times_in_flight',
        'News': 'news',
        // Relabelled from Preferences; the id stays.
        'Settings': 'preferences',
        'Quran': 'quran',
        'Usage': 'usage',
        'My Stats': 'my_stats',
        'Mistake Reports': 'mistake_reports',
        'Content Requests': 'content_requests',
      },
    );
  });

  group('tabs', () {
    tearDown(() => isUserAdmin = false);

    test('All features leaves out what has a tab of its own', () {
      for (final admin in [false, true]) {
        isUserAdmin = admin;
        final features = allFeaturesMenuItems;
        expect(features, isNot(contains(favoritesMenuItem)));
        expect(features, isNot(contains(surahsMenuItem)));
        expect(features, isNot(contains(quranMenuItem)));
        expect(features, contains(settingsMenuItem));
        expect(features, contains(calendarMenuItem));
      }
    });

    test('Settings can be reached from Home but is not a shortcut', () {
      expect(shortcutCandidateMenuItems, isNot(contains(settingsMenuItem)));
      expect(homeShortcutMenuItems(['preferences']), isEmpty);
    });

    test('shortcuts resolve in order and skip what cannot be opened', () {
      final items = homeShortcutMenuItems(
          ['qibla_finder', 'not_a_feature', 'duas', 'usage']);
      expect(items.map((item) => item.analyticsId), ['qibla_finder', 'duas']);
    });

    test('every default shortcut is a real feature', () {
      expect(
        homeShortcutMenuItems(HomeShortcutsStore.defaultIds)
            .map((item) => item.analyticsId),
        HomeShortcutsStore.defaultIds,
      );
      expect(
        homeShortcutMenuItems(HomeShortcutsStore.defaultIds)
            .map((item) => item.shortLabel),
        [
          'Duas',
          'Ziyarats',
          "Today's Recitations",
          'Munajaat',
          'Calendar',
          'Tasbeeh',
          'Qibla',
        ],
      );
    });

    test('the Quran tab keeps the Quran screen dark-launched to admins', () {
      isUserAdmin = false;
      expect(quranTabMenuItem, same(surahsMenuItem));
      isUserAdmin = true;
      expect(quranTabMenuItem, same(quranMenuItem));
    });
  });

  test('prayer time object exposes the expected prayer names', () {
    expect(getPrayerTimeObject().getTimeNames(), [
      'Fajr',
      'Sunrise',
      'Zuhr',
      'Asr',
      'Sunset',
      'Maghrib',
      'Isha',
    ]);
  });
}
