import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/navigation/app_shell.dart';
import 'package:shia_companion/navigation/home_menu.dart';
import 'package:shia_companion/models/city.dart';
import 'package:shia_companion/pages/about_page.dart';
import 'package:shia_companion/pages/all_features_page.dart';
import 'package:shia_companion/pages/city_picker.dart';
import 'package:shia_companion/pages/city_prayer_times_page.dart';
import 'package:shia_companion/pages/home/coming_up_section.dart';
import 'package:shia_companion/pages/home/continue_section.dart';
import 'package:shia_companion/pages/home/hadith_card.dart';
import 'package:shia_companion/pages/home/home_header.dart';
import 'package:shia_companion/pages/home/shortcuts_section.dart';
import 'package:shia_companion/pages/list_items.dart';
import 'package:shia_companion/services/city_repository.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/app_text_scale.dart';
import 'package:shia_companion/utils/language_provider.dart';
import 'package:shia_companion/utils/theme_mode.dart';
import 'package:shia_companion/widgets/prayer_times_widget.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'firebase_test_doubles.dart';

/// Renders every screen across the viewports and themes we ship to, and fails
/// on any framework error raised while laying it out.
///
/// This is the cheap half of "did the UI break". A RenderFlex overflow, a null
/// dereference during build or a bad constraint all surface here as an
/// exception, on every screen, in a few seconds and with no golden files to
/// maintain. Pixel-level regressions on the web build are covered separately by
/// the Playwright suite in test_visual/.
///
/// The screen list is [allHomeMenuItems] itself rather than a copy, so a new
/// menu entry — admin-gated ones included — is covered the day it is added and
/// cannot be forgotten here.
void main() {
  setUpAll(() async {
    // The app initialises SP before runApp; screens read SP.prefs directly and
    // it throws when unset.
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    await setUpFirebaseForRenderTests();
    // The real list is 2 MB; a few rows exercise the same layout.
    CityRepository.instance.seedForTesting([
      for (final (name, country) in [
        ('Baghdad', 'Iraq'),
        ('Karbala', 'Iraq'),
        ('Al Madīnah al Munawwarah ash Sharqiyah', 'Iraq'),
      ])
        City(
          name: name,
          countryCode: 'IQ',
          countryName: country,
          latitude: 33,
          longitude: 44,
          population: 1000000,
          timeZone: 'Asia/Baghdad',
        ),
    ]);
  });

  for (final screen in _screens) {
    for (final viewport in _viewports) {
      for (final brightness in Brightness.values) {
        testWidgets(
          '${screen.name} renders on ${viewport.name} in ${brightness.name} mode',
          (tester) async {
            await _pump(tester, screen, viewport, brightness);

            expect(
              tester.takeException(),
              isNull,
              reason:
                  '${screen.name} raised while rendering at ${viewport.size}',
            );
          },
        );
      }
    }
  }

  // The real Quran and Favorites tab roots inside the shell, under the
  // floating bar. Home is left out: it starts the whole app (deep links,
  // notifications, sync) and needs plugins this suite does not mock.
  testWidgets('the tab shell renders each tab at 1.5x system text',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pump(
      tester,
      _Screen('App shell', () => AppShell(tabs: _shellTabs())),
      _viewports.first,
      Brightness.light,
    );
    for (final label in ['Quran', 'Favorites', 'Home']) {
      await tester.tap(find.text(label).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  for (final viewport in _viewports) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'the tab shell renders each tab on ${viewport.name} in '
        '${brightness.name} mode',
        (tester) async {
          await _pump(
            tester,
            _Screen('App shell', () => AppShell(tabs: _shellTabs())),
            viewport,
            brightness,
          );
          for (final label in ['Quran', 'Favorites', 'Home']) {
            await tester.tap(find.text(label).last);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull, reason: label);
          }
        },
      );
    }
  }
}

List<AppShellTab> _shellTabs() => [
      AppShellTab(
        label: 'Home',
        icon: (color) => Icon(Icons.home_outlined, color: color),
        builder: (_) => const Scaffold(body: SizedBox.expand()),
      ),
      AppShellTab(
        label: 'Quran',
        icon: (color) => Icon(Icons.menu_book_outlined, color: color),
        builder: (_) => ItemList('A', 'Quran'),
      ),
      AppShellTab(
        label: 'Favorites',
        icon: (color) => Icon(Icons.favorite_border, color: color),
        builder: (_) => favoritesMenuItem.pageBuilder(),
      ),
    ];

class _Screen {
  const _Screen(this.name, this.build);

  final String name;
  final Widget Function() build;
}

class _Viewport {
  const _Viewport(this.name, this.size);

  final String name;
  final Size size;
}

/// Menu screens that cannot be rendered in a widget test, with the reason.
///
/// Empty at the moment. Qibla Finder used to be here, when it was a host for a
/// `WebViewWidget` that asserts unless a `WebViewPlatform` is registered; it
/// now draws its own compass and renders like any other screen.
const Set<String> _unrenderableMenuScreens = <String>{};

final List<_Screen> _screens = [
  for (final item in allHomeMenuItems)
    if (!_unrenderableMenuScreens.contains(item.label))
      _Screen(item.label, item.buildPage),
  // Reachable from the app bar rather than the menu.
  _Screen('About', () => AboutPage()),
  _Screen('All features', () => const AllFeaturesPage()),
  _Screen(
    'City picker',
    () => const Scaffold(body: CityPicker(timeZone: 'Asia/Baghdad')),
  ),
  _Screen(
    'City prayer times',
    () => const CityPrayerTimesPage(
      city: City(
        name: 'Karbala',
        countryCode: 'IQ',
        countryName: 'Iraq',
        latitude: 32.62,
        longitude: 44.03,
        population: 1218732,
        timeZone: 'Asia/Baghdad',
      ),
    ),
  ),
  // Home itself starts the whole app (deep links, notifications, sync), so
  // its sections are rendered on their own, laid out as Home lays them out.
  _Screen('Home sections', () => const _HomeSections()),
];

class _HomeSections extends StatelessWidget {
  const _HomeSections();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeHeader(onOpenSettings: () {}),
                const SizedBox(height: 18),
                HomePrayerTimesCard(
                  footer: ComingUpRow(onOpenCalendar: () {}),
                ),
              ],
            ),
          ),
          const ContinueSection(topSpacing: 18),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShortcutsSection(onOpen: (_) {}, onOpenAllFeatures: () {}),
                const SizedBox(height: 18),
                const HadithOfTheDayCard(
                  hadith: "Imam Ali (a.s.) said: 'Increase your silence and "
                      "your thoughts will flourish.'\n[Ghurar al-Hikam, no. "
                      '3725]',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const List<_Viewport> _viewports = [
  _Viewport('a phone', Size(393, 852)),
  _Viewport('a tablet', Size(834, 1194)),
  _Viewport('a desktop window', Size(1440, 900)),
];

Future<void> _pump(
  WidgetTester tester,
  _Screen screen,
  _Viewport viewport,
  Brightness brightness,
) async {
  tester.view.physicalSize = viewport.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    // Settings reads ThemeModeProvider, AppTextScaleProvider and
    // LanguageProvider from the tree, exactly as main.dart supplies them.
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModeProvider()),
        ChangeNotifierProvider(create: (_) => AppTextScaleProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp(
        theme: buildAppTheme(brightness),
        home: screen.build(),
      ),
    ),
  );

  // Screens kick off async loads in initState. pumpAndSettle would hang on any
  // screen with a repeating animation, so drain a bounded number of frames.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
