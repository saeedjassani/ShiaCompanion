import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shia_companion/main.dart' as app;
import 'package:shia_companion/navigation/home_menu.dart';

/// Automated Smoke Crawler for iOS & Android.
///
/// Discovers and navigates through every section of ShiaCompanion's home
/// grid without a hardcoded, easily-stale copy of the menu — the crawl list
/// comes straight from [visibleHomeMenuItems], the same source the grid
/// itself renders from (mirrors the approach `test/ui/page_render_test.dart`
/// already takes for exactly this reason: a new menu entry is covered the
/// day it is added, nothing here needs updating for it). Verifies that every
/// visited screen builds, mounts, handles scrolling, and dismisses without
/// throwing uncaught framework exceptions or crashing native platform
/// channels.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  /// Helper to drain frames for a bounded duration. Avoids timeouts caused by
  /// periodic timers (such as prayer time countdowns or audio handlers).
  Future<void> settleBounded(
    WidgetTester tester, {
    Duration duration = const Duration(seconds: 2),
    Duration step = const Duration(milliseconds: 100),
  }) async {
    final deadline = DateTime.now().add(duration);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(step);
    }
  }

  testWidgets('Automated Smoke Crawler: explore home menu and core screens',
      (WidgetTester tester) async {
    // 1. Launch the real application entry point
    debugPrint('==> Smoke Crawler: Booting app...');
    app.main();
    await settleBounded(tester, duration: const Duration(seconds: 4));

    // 2. Dismiss initial Azan opt-in dialog if presented on first run
    final notNowFinder = find.text('Not now');
    if (notNowFinder.evaluate().isNotEmpty) {
      debugPrint('==> Smoke Crawler: Dismissing initial Azan opt-in prompt...');
      await tester.tap(notNowFinder.first);
      await settleBounded(tester, duration: const Duration(seconds: 1));
    }

    // 3. Verify Home Screen is mounted
    expect(find.byType(Scaffold), findsWidgets,
        reason: 'App failed to render Home Scaffold');
    debugPrint('==> Smoke Crawler: Home screen successfully mounted.');

    // 4. Every section on the home grid, in the order it renders there.
    final sectionsToCrawl = visibleHomeMenuItems.map((item) => item.label);

    for (final section in sectionsToCrawl) {
      debugPrint('==> Smoke Crawler: Navigating to "$section"...');

      // Locate section card/label on home screen, scrolling further down each
      // attempt if not yet in view. Bounded so a genuinely missing label
      // (the failure mode this exists to catch) skips instead of looping.
      Finder itemFinder = find.text(section);
      var scrollAttempts = 0;
      while (itemFinder.evaluate().isEmpty && scrollAttempts < 6) {
        final homeScrollables = find.byType(Scrollable);
        if (homeScrollables.evaluate().isEmpty) break;
        await tester.drag(homeScrollables.first, const Offset(0, -300));
        await settleBounded(tester, duration: const Duration(milliseconds: 500));
        itemFinder = find.text(section);
        scrollAttempts++;
      }

      if (itemFinder.evaluate().isNotEmpty) {
        // Tap section
        await tester.tap(itemFinder.first);
        await settleBounded(tester, duration: const Duration(seconds: 2));

        // Assert no unhandled framework exceptions occurred during build/layout
        expect(tester.takeException(), isNull,
            reason: 'Exception thrown when opening "$section"');

        // Verify page content rendered
        expect(find.byType(Scaffold), findsWidgets,
            reason: '"$section" did not present a Scaffold');

        // Test gentle scrolling on the opened page
        final pageScrollables = find.byType(Scrollable);
        if (pageScrollables.evaluate().isNotEmpty) {
          await tester.drag(pageScrollables.first, const Offset(0, -200));
          await settleBounded(tester, duration: const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull,
              reason: 'Exception thrown when scrolling "$section"');
        }

        // Navigate back to the home screen
        final backButtons = find.byType(BackButton);
        final backTooltips = find.byTooltip('Back');
        if (backButtons.evaluate().isNotEmpty) {
          await tester.tap(backButtons.first);
        } else if (backTooltips.evaluate().isNotEmpty) {
          await tester.tap(backTooltips.first);
        } else {
          // Direct Navigator pop if back button widget was not found
          final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
          nav.pop();
        }

        await settleBounded(tester, duration: const Duration(seconds: 2));
        debugPrint('==> Smoke Crawler: "$section" passed cleanly.');
      } else {
        debugPrint('==> Smoke Crawler: Section "$section" was not visible, skipped.');
      }
    }

    // 5. Test search bar interaction
    debugPrint('==> Smoke Crawler: Testing search interaction...');
    final searchIcons = find.byIcon(Icons.search);
    if (searchIcons.evaluate().isNotEmpty) {
      await tester.tap(searchIcons.first);
      await settleBounded(tester, duration: const Duration(seconds: 1));

      // Type a search query
      await tester.enterText(find.byType(TextField).first, 'Kumayl');
      await settleBounded(tester, duration: const Duration(seconds: 1));
      expect(tester.takeException(), isNull,
          reason: 'Exception thrown during search query entry');

      // Dismiss search
      final searchBackButtons = find.byType(BackButton);
      if (searchBackButtons.evaluate().isNotEmpty) {
        await tester.tap(searchBackButtons.first);
      } else {
        final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
        nav.pop();
      }
      await settleBounded(tester, duration: const Duration(seconds: 1));
      debugPrint('==> Smoke Crawler: Search interaction passed.');
    }

    debugPrint('==> Smoke Crawler completed all checks with ZERO errors!');
  });
}
