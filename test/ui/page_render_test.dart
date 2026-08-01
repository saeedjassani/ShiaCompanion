import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/about_page.dart';
import 'package:shia_companion/pages/calendar_page.dart';
import 'package:shia_companion/pages/flights_page.dart';
import 'package:shia_companion/pages/qaza_tracker_page.dart';
import 'package:shia_companion/widgets/tasbeeh_widget.dart';

/// Renders each screen across the viewports and themes we ship to, and fails on
/// any framework error raised while laying it out.
///
/// This is the cheap half of "did the UI break". A RenderFlex overflow, a null
/// dereference during build or a bad constraint all surface here as an
/// exception, on every screen, in a few seconds and with no golden files to
/// maintain. Pixel-level regressions on the web build are covered separately by
/// the Playwright suite in test_visual/.
///
/// Adding a screen: append it to [_screens]. Screens that reach Firebase while
/// building — anything using FavoritesManager, or ItemList, which constructs a
/// Firestore collection reference in a field initializer — cannot be listed
/// until the suite stands up Firebase test doubles. See docs/CI.md.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

// trackScreenOnInit is disabled where the screen exposes it so the tests do not
// depend on analytics being reachable.
final List<_Screen> _screens = [
  _Screen('About', () => AboutPage()),
  _Screen(
    'Calendar',
    () => const CalendarPage(trackScreenOnInit: false),
  ),
  _Screen('Flights', () => const FlightsPage(trackScreenOnInit: false)),
  _Screen('Qaza tracker', () => const QazaTrackerPage()),
  _Screen('Tasbeeh counter', () => const TasbeehWidget()),
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
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          brightness: brightness,
        ),
      ),
      home: screen.build(),
    ),
  );

  // Screens kick off async loads in initState. pumpAndSettle would hang on any
  // screen with a repeating animation, so drain a bounded number of frames.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
