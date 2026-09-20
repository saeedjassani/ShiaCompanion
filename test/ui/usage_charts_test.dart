import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/admin/usage_charts.dart';

/// Renders the usage dashboard's chart widgets directly with representative
/// data, on a narrow phone viewport and in both themes, and fails on any
/// framework error — a RenderFlex overflow from a long legend label or an
/// fl_chart API misuse would otherwise only show up on a live admin's phone.
void main() {
  final thirtyDayTrend = [
    for (var i = 0; i < 30; i++)
      MapEntry('2026-08-${(i + 1).toString().padLeft(2, '0')}', (i * 7) % 40),
  ];

  for (final brightness in Brightness.values) {
    testWidgets(
        'TrendAreaChart renders a 30-day trend in ${brightness.name} mode',
        (tester) async {
      await _pump(
        tester,
        brightness,
        TrendAreaChart(
          title: 'Events per day',
          trend: thirtyDayTrend,
          color: Colors.brown,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Events per day'), findsOneWidget);
    });

    testWidgets(
        'TrendAreaChart renders a flat all-zero trend without dividing by zero',
        (tester) async {
      await _pump(
        tester,
        brightness,
        TrendAreaChart(
          title: 'Events per day',
          trend: const [MapEntry('2026-08-01', 0), MapEntry('2026-08-02', 0)],
          color: Colors.brown,
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'MetricTrendChart renders five series with a legend in ${brightness.name} mode',
        (tester) async {
      await _pump(
        tester,
        brightness,
        MetricTrendChart(
          series: [
            for (var i = 0; i < 5; i++)
              UsageMetricSeries(
                label: 'Series $i with a fairly long name',
                color: categoricalColor(i, brightness),
                points: thirtyDayTrend,
              ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Series'), findsWidgets);
    });

    testWidgets(
        'ShareBar renders six long-named segments in ${brightness.name} mode',
        (tester) async {
      await _pump(
        tester,
        brightness,
        ShareBar(
          segments: [
            for (var i = 0; i < 6; i++)
              ShareSegment(
                label: 'Feature group with a long descriptive name $i',
                value: (i + 1) * 17,
                color: categoricalColor(i, brightness),
              ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('ShareBar renders nothing for an all-zero total',
        (tester) async {
      await _pump(
        tester,
        brightness,
        const ShareBar(segments: [
          ShareSegment(label: 'Empty', value: 0, color: Colors.brown)
        ]),
      );

      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pump(
    WidgetTester tester, Brightness brightness, Widget chart) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.brown, brightness: brightness),
      ),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: chart),
      ),
    ),
  );
  await tester.pump();
}
