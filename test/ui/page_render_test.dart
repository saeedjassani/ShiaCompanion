import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/navigation/home_menu.dart';
import 'package:shia_companion/pages/about_page.dart';
import 'package:shia_companion/utils/dark_mode.dart';
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
/// The screen list is [homeMenuItems] itself rather than a copy, so a new menu
/// entry is covered the day it is added and cannot be forgotten here.
void main() {
  setUpAll(() async {
    // The app initialises SP before runApp; screens read SP.prefs directly and
    // it throws when unset.
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    await setUpFirebaseForRenderTests();
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
}

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
/// Qibla Finder is a host for a `WebViewWidget`, which asserts unless a
/// `WebViewPlatform` is registered. Standing one up means implementing the
/// controller, widget, navigation delegate and cookie manager interfaces — at
/// which point the test exercises those stubs rather than the screen, since
/// the screen is little more than a Scaffold around the web view.
const Set<String> _unrenderableMenuScreens = {'Qibla Finder'};

final List<_Screen> _screens = [
  for (final item in homeMenuItems)
    if (!_unrenderableMenuScreens.contains(item.label))
      _Screen(item.label, item.buildPage),
  // Reachable from the app bar rather than the menu.
  _Screen('About', () => AboutPage()),
];

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
    // Settings reads DarkModeProvider from the tree, exactly as main.dart
    // supplies it.
    ChangeNotifierProvider(
      create: (_) => DarkModeProvider(),
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.brown,
            brightness: brightness,
          ),
        ),
        home: screen.build(),
      ),
    ),
  );

  // Screens kick off async loads in initState. pumpAndSettle would hang on any
  // screen with a repeating animation, so drain a bounded number of frames.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
