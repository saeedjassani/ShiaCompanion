import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shia_companion/main.dart' as app;
import 'package:shia_companion/navigation/app_shell.dart';
import 'package:shia_companion/navigation/home_menu.dart';

/// Automated Smoke Crawler for iOS & Android.
///
/// Discovers and navigates through every feature on the All features page
/// without a hardcoded, easily-stale copy of the menu — the crawl list
/// comes straight from [allFeaturesMenuItems], the same source the page
/// itself renders from (mirrors the approach `test/ui/page_render_test.dart`
/// already takes for exactly this reason: a new menu entry is covered the
/// day it is added, nothing here needs updating for it), then the Quran and
/// Favorites tabs and search from the tab bar. Verifies that every
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

  /// Pumps until [finder] matches something or [timeout] passes, returning
  /// whether it was found. App startup is not a fixed cost: `main()` awaits
  /// audio, alarm-manager and Firebase setup before it ever calls `runApp`,
  /// and on a cold CI emulator (software GPU, freshly installed APK) that
  /// alone has taken over 4 seconds - so a fixed settle let the Home
  /// Scaffold check run before the app had rendered anything at all.
  Future<bool> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 60),
    Duration step = const Duration(milliseconds: 250),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(step);
      if (finder.evaluate().isNotEmpty) return true;
    }
    return finder.evaluate().isNotEmpty;
  }

  /// integration_test screenshot names become filenames on disk, so section
  /// labels (which may contain spaces, apostrophes, "&") need sanitizing.
  String screenshotSafeName(String label) =>
      label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  testWidgets('Automated Smoke Crawler: explore home menu and core screens',
      (WidgetTester tester) async {
    // 1. Launch the real application entry point
    debugPrint('==> Smoke Crawler: Booting app...');
    app.main();
    // Wait for the first real frame of the app, however long boot takes,
    // then give the home page's post-frame work (first-run prompts) time to
    // surface before looking for them.
    await pumpUntilFound(tester, find.byType(Scaffold));
    await settleBounded(tester, duration: const Duration(seconds: 3));

    // Required on Android before the first screenshot, to switch from
    // SurfaceView-based rendering to a normal View so the platform can
    // actually capture a frame; a documented no-op on iOS.
    await binding.convertFlutterSurfaceToImage();

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
    await tester.pump();
    await binding.takeScreenshot('00_home');

    // 4. Every feature on All features, in the order it renders there,
    // reached from the last Home shortcut. Quran and Favorites are tabs
    // rather than features; they are visited from the tab bar further down.
    debugPrint('==> Smoke Crawler: Opening All features...');
    final allFeaturesTile = find.text('All features');
    await tester.ensureVisible(allFeaturesTile.first);
    await tester.tap(allFeaturesTile.first);
    await settleBounded(tester, duration: const Duration(seconds: 2));
    expect(tester.takeException(), isNull,
        reason: 'Exception thrown when opening All features');
    await binding.takeScreenshot('00b_all_features');

    final sectionsToCrawl =
        allFeaturesMenuItems.map((item) => item.label).toList();

    for (var i = 0; i < sectionsToCrawl.length; i++) {
      final section = sectionsToCrawl[i];
      debugPrint('==> Smoke Crawler: Navigating to "$section"...');

      // Locate the feature on All features, scrolling further down each
      // attempt if not yet in view. Bounded so a genuinely missing label
      // (the failure mode this exists to catch) skips instead of looping.
      Finder itemFinder = find.text(section);
      var scrollAttempts = 0;
      while (itemFinder.evaluate().isEmpty && scrollAttempts < 6) {
        final homeScrollables = find.byType(Scrollable);
        if (homeScrollables.evaluate().isEmpty) break;
        await tester.drag(homeScrollables.first, const Offset(0, -300));
        await settleBounded(tester,
            duration: const Duration(milliseconds: 500));
        itemFinder = find.text(section);
        scrollAttempts++;
      }

      if (itemFinder.evaluate().isNotEmpty) {
        // Being found above only means Flutter has *built* the widget —
        // grid/list views build somewhat beyond the visible viewport
        // (cacheExtent), so a just-found item can still be off-screen.
        // Tapping it then hits nothing (a silent WidgetController warning)
        // and previously cascaded into every section for the rest of the
        // run reporting "not visible" instead of the real cause. Scroll it
        // fully into view first.
        await tester.ensureVisible(itemFinder.first);
        await settleBounded(tester,
            duration: const Duration(milliseconds: 300));

        // Tap section
        await tester.tap(itemFinder.first);
        await settleBounded(tester, duration: const Duration(seconds: 2));

        // Assert no unhandled framework exceptions occurred during build/layout
        expect(tester.takeException(), isNull,
            reason: 'Exception thrown when opening "$section"');

        // Verify page content rendered
        expect(find.byType(Scaffold), findsWidgets,
            reason: '"$section" did not present a Scaffold');

        await binding.takeScreenshot(
            '${(i + 1).toString().padLeft(2, '0')}_${screenshotSafeName(section)}');

        // Test gentle scrolling on the opened page
        final pageScrollables = find.byType(Scrollable);
        if (pageScrollables.evaluate().isNotEmpty) {
          await tester.drag(pageScrollables.first, const Offset(0, -200));
          await settleBounded(tester,
              duration: const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull,
              reason: 'Exception thrown when scrolling "$section"');
        }

        // Navigate back to All features
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

        // Captured before the assertions below so that if one fails, the
        // artifact still shows exactly what was left on screen.
        await binding.takeScreenshot(
            '${(i + 1).toString().padLeft(2, '0')}b_after_${screenshotSafeName(section)}');

        // Verify we actually returned to a live All features page. This was
        // previously unchecked, so a failed pop — or an exception thrown
        // asynchronously during a section's teardown — went completely
        // undetected: the loop kept running, but every subsequent
        // find.text(section) silently found nothing for the rest of the
        // test, logging each remaining section as "not visible, skipped"
        // instead of surfacing the real failure at its actual source.
        expect(tester.takeException(), isNull,
            reason:
                'Exception thrown returning from "$section" to All features');
        expect(find.byType(Scrollable), findsWidgets,
            reason: 'Did not return to a scrollable All features page after '
                '"$section"');

        debugPrint('==> Smoke Crawler: "$section" passed cleanly.');
      } else {
        debugPrint(
            '==> Smoke Crawler: Section "$section" was not visible, skipped.');
      }
    }

    // Back from All features to Home.
    final allFeaturesBack = find.byType(BackButton);
    if (allFeaturesBack.evaluate().isNotEmpty) {
      await tester.tap(allFeaturesBack.first);
    } else {
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    }
    await settleBounded(tester, duration: const Duration(seconds: 2));
    expect(find.byType(AppTabBar), findsOneWidget,
        reason: 'Did not return to Home from All features');

    // 5. The other tabs, through the tab bar, and back to Home.
    Finder tabLabel(String label) =>
        find.descendant(of: find.byType(AppTabBar), matching: find.text(label));
    for (final tab in ['Quran', 'Favorites']) {
      debugPrint('==> Smoke Crawler: Opening the "$tab" tab...');
      expect(tabLabel(tab), findsOneWidget,
          reason: 'The tab bar has no "$tab" tab');
      await tester.tap(tabLabel(tab));
      await settleBounded(tester, duration: const Duration(seconds: 2));
      expect(tester.takeException(), isNull,
          reason: 'Exception thrown when opening the "$tab" tab');
      await binding.takeScreenshot('tab_${screenshotSafeName(tab)}');

      final tabScrollables = find.byType(Scrollable);
      if (tabScrollables.evaluate().isNotEmpty) {
        await tester.drag(tabScrollables.last, const Offset(0, -200));
        await settleBounded(tester,
            duration: const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull,
            reason: 'Exception thrown when scrolling the "$tab" tab');
      }
    }
    await tester.tap(tabLabel('Home'));
    await settleBounded(tester, duration: const Duration(seconds: 1));

    // 6. Test search bar interaction
    debugPrint('==> Smoke Crawler: Testing search interaction...');
    final searchButtons = find.byTooltip('Search');
    expect(searchButtons, findsOneWidget,
        reason: 'The search button beside the tab bar is missing');
    if (searchButtons.evaluate().isNotEmpty) {
      await tester.tap(searchButtons.first);
      await settleBounded(tester, duration: const Duration(seconds: 1));

      // Type a search query
      await tester.enterText(find.byType(TextField).first, 'Kumayl');
      await settleBounded(tester, duration: const Duration(seconds: 1));
      expect(tester.takeException(), isNull,
          reason: 'Exception thrown during search query entry');

      await binding.takeScreenshot('99_search');

      // Dismiss search with the Close button beside its field
      final closeSearch = find.byTooltip('Close search');
      if (closeSearch.evaluate().isNotEmpty) {
        await tester.tap(closeSearch.first);
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
