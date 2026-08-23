import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/analytics_service.dart';
import '../pages/calendar_page.dart';
import '../pages/favorites_page.dart';
import '../pages/flights_page.dart';
import '../pages/library_page.dart';
import '../pages/list_items.dart';
import '../pages/prayer_counter_page.dart';
import '../pages/qaza_tracker_page.dart';
import '../pages/qibla_finder.dart';
import '../pages/settings_page.dart';
import '../pages/todays_recitation_page.dart';
import '../widgets/tasbeeh_widget.dart';

typedef HomeMenuPageBuilder = Widget Function();

bool get supportsPrayerCounterOnCurrentPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class HomeMenuItem {
  const HomeMenuItem({
    required this.label,
    required this.icon,
    required this.pageBuilder,
  });

  final String label;
  final IconData icon;
  final HomeMenuPageBuilder pageBuilder;

  Widget buildPage() {
    // Every home menu feature is opened through here, so one hook ranks Qibla,
    // Tasbeeh, Qaza, Calendar and the rest against each other without each page
    // needing its own event.
    AnalyticsService.feature(
      'home_menu_$analyticsId',
      label: label,
      parameters: {'menu_item': label},
    );
    return pageBuilder();
  }

  /// Stable id derived from the label, so the counter key survives a rebuild
  /// but forks if the feature is ever genuinely renamed.
  String get analyticsId => label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

final List<HomeMenuItem> homeMenuItems = List.unmodifiable([
  HomeMenuItem(
    label: 'Favorites',
    icon: Icons.favorite,
    pageBuilder: () => FavoritesPage(),
  ),
  HomeMenuItem(
    label: "Today's Recitations",
    icon: Icons.book,
    pageBuilder: () => TodaysRecitationPage(),
  ),
  HomeMenuItem(
    label: 'Taqeebat e Namaz',
    icon: Icons.bookmark,
    pageBuilder: () => ItemList("D", "Taqeebat e Namaz"),
  ),
  HomeMenuItem(
    label: 'Namaz',
    icon: Icons.wb_sunny,
    pageBuilder: () => ItemList("F", "Namaz"),
  ),
  HomeMenuItem(
    label: 'Duas',
    icon: Icons.menu_book,
    pageBuilder: () => ItemList("E", "Duas"),
  ),
  HomeMenuItem(
    label: 'Ziyarats',
    icon: Icons.mosque,
    pageBuilder: () => ItemList("G", "Ziyarats"),
  ),
  HomeMenuItem(
    label: 'Surahs',
    icon: Icons.menu_book,
    pageBuilder: () => ItemList("A", "Surahs"),
  ),
  HomeMenuItem(
    label: 'Aamaal',
    icon: Icons.check_circle,
    pageBuilder: () => ItemList("C", "Aamaal"),
  ),
  HomeMenuItem(
    label: 'Calendar & Prayer Times',
    icon: Icons.calendar_today,
    pageBuilder: () => Scaffold(
      appBar: AppBar(title: Text('Calendar')),
      body: CalendarPage(),
    ),
  ),
  HomeMenuItem(
    label: 'Library',
    icon: Icons.library_books,
    pageBuilder: () => Scaffold(
      appBar: AppBar(title: Text('Library')),
      body: LibraryPage(),
    ),
  ),
  HomeMenuItem(
    label: 'Munajaat',
    icon: Icons.menu_book,
    pageBuilder: () => ItemList("H", "Munajaat"),
  ),
  HomeMenuItem(
    label: 'Baaqeyaat As Saalehaat',
    icon: Icons.list_alt,
    pageBuilder: () => ItemList("I", "Baaqeyaat As Saalehaat"),
  ),
  HomeMenuItem(
    label: 'Qibla Finder',
    icon: Icons.explore,
    pageBuilder: () => QiblaFinder(),
  ),
  HomeMenuItem(
    label: 'Tasbeeh Counter',
    icon: tasbeehCounterIcon,
    pageBuilder: () => TasbeehWidget(),
  ),
  HomeMenuItem(
    label: 'Qaza Tracker',
    icon: Icons.event_available_rounded,
    pageBuilder: () => const QazaTrackerPage(),
  ),
  if (supportsPrayerCounterOnCurrentPlatform)
    HomeMenuItem(
      label: 'Rakaat Counter',
      icon: Icons.sensor_occupied_rounded,
      pageBuilder: () => const PrayerCounterPage(),
    ),
  HomeMenuItem(
    label: 'Prayer Times in Flight',
    icon: Icons.flight,
    pageBuilder: () => const FlightsPage(),
  ),
  HomeMenuItem(
    label: 'Preferences',
    icon: Icons.settings,
    pageBuilder: () => Scaffold(
      appBar: AppBar(title: Text('Preferences')),
      body: SettingsPage(),
    ),
  ),
]);

HomeMenuItem? getHomeMenuItem(String label) {
  for (final item in homeMenuItems) {
    if (item.label == label) return item;
  }
  return null;
}

Widget getPage(String label) {
  return getHomeMenuItem(label)?.buildPage() ?? Container();
}

final List<String> zikr =
    List.unmodifiable(homeMenuItems.map((item) => item.label));

final List<IconData> zikrIcons =
    List.unmodifiable(homeMenuItems.map((item) => item.icon));
