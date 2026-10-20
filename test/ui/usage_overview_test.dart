import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/admin/usage_cards.dart';
import 'package:shia_companion/pages/admin/usage_dashboard_page.dart';
import 'package:shia_companion/theme/app_theme.dart';

/// Renders the Usage dashboard's content with representative counts - long
/// zikr titles, every entry point, every feature group - on a phone and a
/// desktop, in both themes, and fails on any framework error (an overflow
/// from a long label would otherwise only show on an admin's phone).
void main() {
  final days = ['2026-10-18', '2026-10-19', '2026-10-20'];
  final raw = {
    for (final day in days)
      day: {
        'zikr': {
          'G1': 40,
          'G1~done': 12,
          'G2': 9,
          'G1~playlist': 3,
          'E31': 25,
        },
        'feature': {
          'zikr_source_list': 30,
          'zikr_source_favorites': 20,
          'zikr_source_search': 9,
          'zikr_source_deep_link': 4,
          'zikr_source_zikr_link': 2,
          'zikr_source_home_widget_recitation': 1,
          'home_menu_favorites': 18,
          'home_menu_duas': 11,
          'search_opened': 7,
          'search': 10,
          'zikr_shared': 5,
          'qaza_updated': 4,
          'favorite_added': 3,
          'rating_prompt': 2,
          'brand_new_feature': 1,
          'first_run_setup': 6,
        },
        'screen': {'Zikr-Page': 70, 'Home-Page': 50},
        'library': {'book1': 6},
        'stream': {'Karbala live': 3},
      },
  };
  final parsed = parseUsageDays(raw, days);
  final previous = parseUsageDays(raw, days.sublist(0, 1)).counts;

  UsageRow row(String metric, MapEntry<String, int> entry) => UsageRow(
        key: entry.key,
        label: metric == 'zikr'
            ? 'A long zikr title that runs on, Dua Abu Hamza al-Thumali '
                'دعاء أبي حمزة الثمالي'
            : entry.key,
        count: entry.value,
      );

  final data = UsageSnapshot(
    metrics: {
      for (final metric in parsed.counts.entries)
        metric.key: [
          for (final entry in metric.value.entries) row(metric.key, entry)
        ]..sort((a, b) => b.count.compareTo(a.count)),
    },
    trend: [for (final day in days) MapEntry(day, parsed.trend[day] ?? 0)],
    metricTrend: {
      for (final entry in parsed.metricTrend.entries)
        entry.key: [for (final day in days) MapEntry(day, entry.value[day]!)],
    },
    previous: previousTotalsFrom(previous),
    previousCounts: previous,
  );

  for (final size in const [Size(360, 800), Size(1280, 900)]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          'renders at ${size.width.toInt()} px in ${brightness.name} mode',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(brightness),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: UsageOverview(data: data, range: UsageRange.week),
            ),
          ),
        ));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('How zikrs were opened'), findsOneWidget);
        expect(find.text('What people do'), findsOneWidget);
        expect(find.text('Opened search'), findsOneWidget);
        // Automatic events never reach the dashboard.
        expect(find.textContaining('first_run_setup'), findsNothing);
      });
    }
  }

  testWidgets('an area tile opens its actions on a page of their own',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
        body: SingleChildScrollView(
          child: UsageOverview(data: data, range: UsageRange.week),
        ),
      ),
    ));
    final tile = find.widgetWithText(UsageAreaTile, 'Finding content');
    await tester.scrollUntilVisible(tile, 200);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('home_menu_favorites'), findsOneWidget);
    expect(find.text('search_opened'), findsOneWidget);
  });
}
