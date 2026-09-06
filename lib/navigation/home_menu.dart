import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/analytics_service.dart';
import '../pages/admin/usage_dashboard_page.dart';
import '../pages/calendar_page.dart';
import '../pages/favorites_page.dart';
import '../pages/flights_page.dart';
import '../pages/library_page.dart';
import '../pages/list_items.dart';
import '../pages/prayer_counter_page.dart';
import '../pages/qaza_tracker_page.dart';
import '../pages/qibla_finder.dart';
import '../pages/quran/quran_page.dart';
import '../pages/settings_page.dart';
import '../pages/todays_recitation_page.dart';
import '../widgets/home_glyph.dart';
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
    this.glyphType,
    this.countsAsFeatureUse = true,
  });

  final String label;
  final IconData icon;
  final HomeGlyphType? glyphType;
  final HomeMenuPageBuilder pageBuilder;

  /// Builds the icon widget for the home screen grid, rendering a custom
  /// [HomeGlyph] when defined or falling back to a standard [Icon].
  Widget buildIcon({required double size, required Color color}) {
    if (glyphType != null) {
      return HomeGlyph(type: glyphType!, size: size, color: color);
    }
    return Icon(icon, size: size, color: color);
  }

  /// False for admin tools. The usage dashboard would otherwise appear in the
  /// feature ranking it exists to display, and every visit to check the numbers
  /// would change them.
  final bool countsAsFeatureUse;

  Widget buildPage() {
    // Every home menu feature is opened through here, so one hook ranks Qibla,
    // Tasbeeh, Qaza, Calendar and the rest against each other without each page
    // needing its own event.
    if (countsAsFeatureUse) {
      AnalyticsService.feature(
        'home_menu_$analyticsId',
        label: label,
        parameters: {'menu_item': label},
      );
    }
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
    icon: Icons.favorite_rounded,
    pageBuilder: () => FavoritesPage(),
  ),
  HomeMenuItem(
    label: "Today's Recitations",
    glyphType: HomeGlyphType.todaysRecitations,
    icon: Icons.auto_stories_rounded,
    pageBuilder: () => TodaysRecitationPage(),
  ),
  HomeMenuItem(
    label: 'Taqeebat e Namaz',
    glyphType: HomeGlyphType.taqeebat,
    icon: Icons.bookmarks_rounded,
    pageBuilder: () => ItemList("D", "Taqeebat e Namaz"),
  ),
  HomeMenuItem(
    label: 'Namaz',
    glyphType: HomeGlyphType.namaz,
    icon: Icons.wb_twilight_rounded,
    pageBuilder: () => ItemList("F", "Namaz"),
  ),
  HomeMenuItem(
    label: 'Duas',
    glyphType: HomeGlyphType.duas,
    icon: Icons.front_hand_rounded,
    pageBuilder: () => ItemList("E", "Duas"),
  ),
  HomeMenuItem(
    label: 'Ziyarats',
    glyphType: HomeGlyphType.ziyaraat,
    icon: Icons.mosque_rounded,
    pageBuilder: () => ItemList("G", "Ziyarats"),
  ),
  // Renamed from 'Surahs', which deliberately forks the usage counter: the
  // analytics id comes from the label, so Quran counts start fresh under
  // home_menu_quran and the historical Surahs numbers stay where they are.
  HomeMenuItem(
    label: 'Quran',
    glyphType: HomeGlyphType.surahs,
    icon: Icons.menu_book_rounded,
    pageBuilder: () => const QuranPage(),
  ),
  HomeMenuItem(
    label: 'Aamaal',
    glyphType: HomeGlyphType.aamaal,
    icon: Icons.light_mode_rounded,
    pageBuilder: () => ItemList("C", "Aamaal"),
  ),
  HomeMenuItem(
    label: 'Calendar & Prayer Times',
    icon: Icons.calendar_month_rounded,
    pageBuilder: () => Scaffold(
      appBar: AppBar(title: Text('Calendar')),
      body: CalendarPage(),
    ),
  ),
  HomeMenuItem(
    label: 'Library',
    icon: Icons.local_library_rounded,
    pageBuilder: () => Scaffold(
      appBar: AppBar(title: Text('Library')),
      body: LibraryPage(),
    ),
  ),
  HomeMenuItem(
    label: 'Munajaat',
    glyphType: HomeGlyphType.munajaat,
    icon: Icons.nights_stay_rounded,
    pageBuilder: () => ItemList("H", "Munajaat"),
  ),
  HomeMenuItem(
    label: 'Baaqeyaat As Saalehaat',
    icon: Icons.history_edu_rounded,
    pageBuilder: () => ItemList("I", "Baaqeyaat As Saalehaat"),
  ),
  HomeMenuItem(
    label: 'Qibla Finder',
    icon: Icons.explore_rounded,
    pageBuilder: () => const QiblaFinder(),
  ),
  HomeMenuItem(
    label: 'Tasbeeh Counter',
    glyphType: HomeGlyphType.tasbeeh,
    icon: Icons.adjust_rounded,
    pageBuilder: () => TasbeehWidget(),
  ),
  HomeMenuItem(
    label: 'Qaza Tracker',
    icon: Icons.event_repeat_rounded,
    pageBuilder: () => const QazaTrackerPage(),
  ),
  if (supportsPrayerCounterOnCurrentPlatform)
    HomeMenuItem(
      label: 'Rakaat Counter',
      glyphType: HomeGlyphType.rakaat,
      icon: Icons.touch_app_rounded,
      pageBuilder: () => const PrayerCounterPage(),
    ),
  HomeMenuItem(
    label: 'Prayer Times in Flight',
    icon: Icons.flight_takeoff_rounded,
    pageBuilder: () => const FlightsPage(),
  ),
  HomeMenuItem(
    label: 'Preferences',
    icon: Icons.settings_rounded,
    pageBuilder: () => Scaffold(
      appBar: AppBar(title: Text('Preferences')),
      body: SettingsPage(),
    ),
  ),
]);

/// Menu entries only an admin sees. Kept out of [homeMenuItems] so the grid
/// every user gets stays a compile-time constant, and so admin state — which
/// arrives after the session refresh, not at startup — is read at build time.
final List<HomeMenuItem> adminHomeMenuItems = List.unmodifiable([
  HomeMenuItem(
    label: 'Usage',
    icon: Icons.query_stats_rounded,
    pageBuilder: () => const UsageDashboardPage(),
    countsAsFeatureUse: false,
  ),
]);

/// Every menu screen there is, admin-gated ones included, so the render test
/// covers an admin entry the same day it is added.
final List<HomeMenuItem> allHomeMenuItems =
    List.unmodifiable([...homeMenuItems, ...adminHomeMenuItems]);

/// What the home grid shows right now, which depends on who is signed in.
List<HomeMenuItem> get visibleHomeMenuItems =>
    isUserAdmin ? allHomeMenuItems : homeMenuItems;

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
