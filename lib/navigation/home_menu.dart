import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/analytics_service.dart';
import '../pages/admin/content_requests_page.dart';
import '../pages/admin/mistake_reports_page.dart';
import '../pages/admin/usage_dashboard_page.dart';
import '../pages/calendar_page.dart';
import '../pages/favorites_page.dart';
import '../pages/flights_page.dart';
import '../pages/library_page.dart';
import '../pages/playlists_page.dart';
import '../pages/list_items.dart';
import '../pages/my_stats_page.dart';
import '../pages/news_page.dart';
import '../pages/prayer_counter_page.dart';
import '../pages/qaza_tracker_page.dart';
import '../pages/qibla_finder.dart';
import '../pages/quran/quran_page.dart';
import '../pages/settings_page.dart';
import '../pages/tasbeeh_page.dart';
import '../pages/todays_recitation_page.dart';
import '../widgets/home_glyph.dart';
import '../widgets/outline_icon.dart';
import '../l10n/l10n.dart';

typedef HomeMenuPageBuilder = Widget Function();

bool get supportsPrayerCounterOnCurrentPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class HomeMenuItem {
  const HomeMenuItem({
    required this.label,
    required this.analyticsId,
    required this.icon,
    required this.pageBuilder,
    this.glyphType,
    this.outlineGlyph,
    String? shortLabel,
    this.countsAsFeatureUse = true,
  }) : _shortLabel = shortLabel;

  final String label;

  final String? _shortLabel;

  /// What a Home shortcut calls this item, where a quarter of a phone's width
  /// has no room for [label]: "Calendar", not "Calendar & Prayer Times".
  String get shortLabel => _shortLabel ?? label;

  /// The key this feature's counter is recorded under (`home_menu_<id>`).
  ///
  /// Spelled out rather than derived from [label], so a label can be reworded
  /// (Preferences -> Settings, say) without forking the counter. Every id was
  /// set to what the old label-derived getter produced, so history carries
  /// over; keep it unchanged when the label changes.
  final String analyticsId;
  final IconData icon;
  final HomeGlyphType? glyphType;

  /// The line icon drawn for items with no [HomeGlyph] of their own.
  final OutlineGlyph? outlineGlyph;
  final HomeMenuPageBuilder pageBuilder;

  /// Builds the item's icon: its [HomeGlyph] when it has one, else its
  /// [OutlineGlyph] (drawn a little smaller, as line icons sit in the
  /// mockups), else the Material [icon].
  Widget buildIcon({required double size, required Color color}) {
    if (glyphType != null) {
      return HomeGlyph(type: glyphType!, size: size, color: color);
    }
    if (outlineGlyph != null) {
      return OutlineIcon(outlineGlyph!, size: size * 26 / 30, color: color);
    }
    return Icon(icon, size: size, color: color);
  }

  /// False for admin tools. The usage dashboard would otherwise appear in the
  /// feature ranking it exists to display, and every visit to check the numbers
  /// would change them.
  final bool countsAsFeatureUse;

  Widget buildPage() {
    recordOpen();
    return pageBuilder();
  }

  /// [label] as shown, in the app language. [label] itself stays English:
  /// it identifies the item (analytics, lookups by name).
  String get displayLabel => homeMenuDisplayLabel(label);

  /// [shortLabel] as shown, in the app language.
  String get displayShortLabel => homeMenuDisplayLabel(shortLabel);

  /// Counts one opening of this feature. Every home menu feature is opened
  /// through [buildPage] or a tab of the app shell, so one hook ranks Qibla,
  /// Tasbeeh, Qaza, Calendar and the rest against each other without each
  /// page needing its own event.
  void recordOpen() {
    if (!countsAsFeatureUse) return;
    AnalyticsService.feature(
      'home_menu_$analyticsId',
      label: label,
      parameters: {'menu_item': label},
    );
  }
}

final HomeMenuItem calendarMenuItem = HomeMenuItem(
  label: 'Calendar & Prayer Times',
  analyticsId: 'calendar_prayer_times',
  shortLabel: 'Calendar',
  outlineGlyph: OutlineGlyph.calendar,
  icon: Icons.calendar_month_rounded,
  pageBuilder: () => const CalendarPage(),
);

final List<HomeMenuItem> homeMenuItems = List.unmodifiable([
  favoritesMenuItem,
  HomeMenuItem(
    label: "Today's Recitations",
    analyticsId: 'today_s_recitations',
    glyphType: HomeGlyphType.todaysRecitations,
    icon: Icons.auto_stories_rounded,
    pageBuilder: () => TodaysRecitationPage(),
  ),
  HomeMenuItem(
    label: 'Taqeebat e Namaz',
    analyticsId: 'taqeebat_e_namaz',
    glyphType: HomeGlyphType.taqeebat,
    icon: Icons.bookmarks_rounded,
    pageBuilder: () => ItemList("D", L10n.current.menuTaqeebat),
  ),
  HomeMenuItem(
    label: 'Namaz',
    analyticsId: 'namaz',
    glyphType: HomeGlyphType.namaz,
    icon: Icons.wb_twilight_rounded,
    pageBuilder: () => ItemList("F", L10n.current.menuNamaz),
  ),
  HomeMenuItem(
    label: 'Duas',
    analyticsId: 'duas',
    glyphType: HomeGlyphType.duas,
    icon: Icons.front_hand_rounded,
    pageBuilder: () => ItemList("E", L10n.current.menuDuas),
  ),
  HomeMenuItem(
    label: 'Ziyarats',
    analyticsId: 'ziyarats',
    glyphType: HomeGlyphType.ziyaraat,
    icon: Icons.mosque_rounded,
    pageBuilder: () => ItemList("G", L10n.current.menuZiyarats),
  ),
  surahsMenuItem,
  HomeMenuItem(
    label: 'Aamaal',
    analyticsId: 'aamaal',
    glyphType: HomeGlyphType.aamaal,
    icon: Icons.light_mode_rounded,
    pageBuilder: () => ItemList("C", L10n.current.menuAamaal),
  ),
  calendarMenuItem,
  HomeMenuItem(
    label: 'Library',
    analyticsId: 'library',
    glyphType: HomeGlyphType.library,
    icon: Icons.local_library_rounded,
    pageBuilder: () => LibraryPage(),
  ),
  HomeMenuItem(
    label: 'Munajaat',
    analyticsId: 'munajaat',
    glyphType: HomeGlyphType.munajaat,
    icon: Icons.nights_stay_rounded,
    pageBuilder: () => ItemList("H", L10n.current.menuMunajaat),
  ),
  HomeMenuItem(
    label: 'Baaqeyaat As Saalehaat',
    analyticsId: 'baaqeyaat_as_saalehaat',
    glyphType: HomeGlyphType.baqeyaat,
    icon: Icons.history_edu_rounded,
    pageBuilder: () => ItemList("I", L10n.current.menuBaaqeyaat),
  ),
  playlistsMenuItem,
  HomeMenuItem(
    label: 'Qibla Finder',
    analyticsId: 'qibla_finder',
    shortLabel: 'Qibla',
    outlineGlyph: OutlineGlyph.compass,
    icon: Icons.explore_rounded,
    pageBuilder: () => const QiblaFinder(),
  ),
  HomeMenuItem(
    label: 'Tasbeeh Counter',
    analyticsId: 'tasbeeh_counter',
    shortLabel: 'Tasbeeh',
    glyphType: HomeGlyphType.tasbeeh,
    icon: Icons.adjust_rounded,
    pageBuilder: () => const TasbeehPage(),
  ),
  HomeMenuItem(
    label: 'Qaza Tracker',
    analyticsId: 'qaza_tracker',
    outlineGlyph: OutlineGlyph.calendarCheck,
    icon: Icons.event_repeat_rounded,
    pageBuilder: () => const QazaTrackerPage(),
  ),
  if (supportsPrayerCounterOnCurrentPlatform)
    HomeMenuItem(
      label: 'Rakaat Counter',
      analyticsId: 'rakaat_counter',
      glyphType: HomeGlyphType.rakaat,
      icon: Icons.touch_app_rounded,
      pageBuilder: () => const PrayerCounterPage(),
    ),
  HomeMenuItem(
    label: 'Prayer Times in Flight',
    analyticsId: 'prayer_times_in_flight',
    outlineGlyph: OutlineGlyph.plane,
    icon: Icons.flight_takeoff_rounded,
    pageBuilder: () => const FlightsPage(),
  ),
  HomeMenuItem(
    label: 'News',
    analyticsId: 'news',
    outlineGlyph: OutlineGlyph.globe,
    icon: Icons.newspaper_rounded,
    pageBuilder: () => const NewsPage(),
  ),
  settingsMenuItem,
]);

final HomeMenuItem favoritesMenuItem = HomeMenuItem(
  label: 'Favorites',
  analyticsId: 'favorites',
  icon: Icons.favorite_rounded,
  pageBuilder: () => FavoritesPage(),
);

final HomeMenuItem surahsMenuItem = HomeMenuItem(
  label: 'Surahs',
  analyticsId: 'surahs',
  glyphType: HomeGlyphType.surahs,
  icon: Icons.menu_book_rounded,
  pageBuilder: () => ItemList("A", L10n.current.menuSurahs),
);

/// Also what the profile button on Home opens. Was "Preferences"; the id
/// keeps that name so its counter carries on.
final HomeMenuItem settingsMenuItem = HomeMenuItem(
  label: 'Settings',
  analyticsId: 'preferences',
  icon: Icons.settings_rounded,
  outlineGlyph: OutlineGlyph.sliders,
  pageBuilder: () => const SettingsPage(),
);

/// The Quran screen (ayah browsing, juz reading, saved verses, resume). It
/// takes the place of 'Surahs' in [visibleHomeMenuItems]; 'Surahs' stays in
/// [homeMenuItems] so the lookups by its label keep working.
final HomeMenuItem quranMenuItem = HomeMenuItem(
  label: 'Quran',
  analyticsId: 'quran',
  glyphType: HomeGlyphType.surahs,
  icon: Icons.menu_book_rounded,
  pageBuilder: () => const QuranPage(),
);

/// Audio playlists. Also offered from every zikr's audio player.
final HomeMenuItem playlistsMenuItem = HomeMenuItem(
  label: 'Playlists',
  analyticsId: 'playlists',
  outlineGlyph: OutlineGlyph.playlist,
  icon: Icons.playlist_play_rounded,
  pageBuilder: () => const PlaylistsPage(),
);

/// Personal stats and community totals. Still dark-launched to admins -
/// move this into [homeMenuItems] when it ships. Recording already runs for everyone, locally, so
/// readers have their history on launch day; see ActivityStatsStore for the
/// sync, which is gated the same way until then.
final HomeMenuItem myStatsMenuItem = HomeMenuItem(
  label: 'My Stats',
  analyticsId: 'my_stats',
  outlineGlyph: OutlineGlyph.stats,
  icon: Icons.insights_rounded,
  pageBuilder: () => const MyStatsPage(),
);

/// Menu entries only an admin sees, added on top of the regular grid rather
/// than replacing anything in it. Kept out of [homeMenuItems] so the grid
/// every user gets stays a compile-time constant, and so admin state — which
/// arrives after the session refresh, not at startup — is read at build time.
final List<HomeMenuItem> adminHomeMenuItems = List.unmodifiable([
  HomeMenuItem(
    label: 'Usage',
    analyticsId: 'usage',
    icon: Icons.query_stats_rounded,
    pageBuilder: () => const UsageDashboardPage(),
    countsAsFeatureUse: false,
  ),
  myStatsMenuItem,
  HomeMenuItem(
    label: 'Mistake Reports',
    analyticsId: 'mistake_reports',
    icon: Icons.flag_outlined,
    pageBuilder: () => const MistakeReportsPage(),
    countsAsFeatureUse: false,
  ),
  HomeMenuItem(
    label: 'Content Requests',
    analyticsId: 'content_requests',
    icon: Icons.playlist_add_rounded,
    pageBuilder: () => const ContentRequestsPage(),
    countsAsFeatureUse: false,
  ),
]);

/// Every menu screen there is, dark-launched and admin-gated ones included,
/// so the render test covers a new entry the same day it is added — even one
/// like Quran that never appears in [visibleHomeMenuItems] side by side with
/// the item it replaces there.
final List<HomeMenuItem> allHomeMenuItems = List.unmodifiable(
  [...homeMenuItems, quranMenuItem, ...adminHomeMenuItems],
);

/// What the home grid shows right now, which depends on who is signed in:
/// 'Surahs' replaced by the Quran screen, plus admin-only tools appended
/// after for an admin.
List<HomeMenuItem> get visibleHomeMenuItems {
  return List.unmodifiable([
    for (final item in homeMenuItems)
      if (item.label == 'Surahs') quranMenuItem else item,
    if (isUserAdmin) ...adminHomeMenuItems,
  ]);
}

/// What the Quran tab holds.
HomeMenuItem get quranTabMenuItem => quranMenuItem;

/// The All features page: everything in [visibleHomeMenuItems], in the same
/// order, except what has a tab of its own.
List<HomeMenuItem> get allFeaturesMenuItems => List.unmodifiable([
      for (final item in visibleHomeMenuItems)
        if (item != favoritesMenuItem &&
            item != surahsMenuItem &&
            item != quranMenuItem)
          item,
    ]);

/// What can be one of Home's shortcuts: All features less Settings, which
/// already has the profile button on Home.
List<HomeMenuItem> get shortcutCandidateMenuItems => List.unmodifiable([
      for (final item in allFeaturesMenuItems)
        if (item != settingsMenuItem) item,
    ]);

/// The shortcuts [ids] name, in order, skipping any this build or this user
/// cannot open (an Android-only tool on web, an admin tool after sign-out).
List<HomeMenuItem> homeShortcutMenuItems(Iterable<String> ids) {
  final byId = {
    for (final item in shortcutCandidateMenuItems) item.analyticsId: item,
  };
  return List.unmodifiable([
    for (final id in ids)
      if (byId[id] case final item?) item,
  ]);
}

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

/// [label], one of the home menu's English item labels (or a short label,
/// see [HomeMenuItem.shortLabel]), in the app language.
/// Labels the menu does not know (admin tools) are shown as they are.
String homeMenuDisplayLabel(String label) {
  return switch (label) {
    'Calendar & Prayer Times' => L10n.current.menuCalendarPrayerTimes,
    'Calendar' => L10n.current.menuCalendar,
    'Favorites' => L10n.current.menuFavorites,
    'Today\'s Recitations' => L10n.current.menuTodaysRecitations,
    'Taqeebat e Namaz' => L10n.current.menuTaqeebat,
    'Namaz' => L10n.current.menuNamaz,
    'Duas' => L10n.current.menuDuas,
    'Ziyarats' => L10n.current.menuZiyarats,
    'Surahs' => L10n.current.menuSurahs,
    'Aamaal' => L10n.current.menuAamaal,
    'Library' => L10n.current.menuLibrary,
    'Munajaat' => L10n.current.menuMunajaat,
    'Baaqeyaat As Saalehaat' => L10n.current.menuBaaqeyaat,
    'Qibla Finder' => L10n.current.menuQiblaFinder,
    'Qibla' => L10n.current.menuQiblaShort,
    'Tasbeeh Counter' => L10n.current.menuTasbeehCounter,
    'Tasbeeh' => L10n.current.menuTasbeehShort,
    'Qaza Tracker' => L10n.current.menuQazaTracker,
    'Rakaat Counter' => L10n.current.menuRakaatCounter,
    'Prayer Times in Flight' => L10n.current.menuPrayerTimesInFlight,
    'Preferences' => L10n.current.menuPreferences,
    'Settings' => L10n.current.actionSettings,
    'Quran' => L10n.current.menuQuran,
    'Playlists' => L10n.current.menuPlaylists,
    'My Stats' => L10n.current.menuMyStats,
    'News' => L10n.current.menuNews,
    _ => label,
  };
}
