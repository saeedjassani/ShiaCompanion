import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The reference categorical palette (data-viz skill, `references/palette.md`):
/// eight hues in a fixed order, chosen so every adjacent pair clears the
/// colorblind-safety checks in both light and dark mode. A slot is assigned
/// by identity (which metric, which feature group) and never by rank, so
/// re-sorting the data it labels never repaints a series a different color.
const List<Color> _categoricalLight = [
  Color(0xFF2A78D6), // 1 blue
  Color(0xFFEB6834), // 2 orange
  Color(0xFF1BAF7A), // 3 aqua
  Color(0xFFEDA100), // 4 yellow
  Color(0xFFE87BA4), // 5 magenta
  Color(0xFF008300), // 6 green
  Color(0xFF4A3AA7), // 7 violet
  Color(0xFFE34948), // 8 red
];

const List<Color> _categoricalDark = [
  Color(0xFF3987E5),
  Color(0xFFD95926),
  Color(0xFF199E70),
  Color(0xFFC98500),
  Color(0xFFD55181),
  Color(0xFF008300),
  Color(0xFF9085E9),
  Color(0xFFE66767),
];

/// Slot [index] (0-based) of the fixed categorical order, stepped for
/// [brightness]. Callers hand out one fixed slot per entity up front (see
/// [UsageMetricSeries] and the feature-group share bar) rather than per rank.
Color categoricalColor(int index, Brightness brightness) {
  final palette =
      brightness == Brightness.dark ? _categoricalDark : _categoricalLight;
  return palette[index % palette.length];
}

final DateFormat _axisDayFormat = DateFormat('MMM d');
final DateFormat _isoDayFormat = DateFormat('yyyy-MM-dd');

String _shortDay(String isoDay) {
  try {
    return _axisDayFormat.format(_isoDayFormat.parse(isoDay));
  } catch (_) {
    return isoDay;
  }
}

/// Which day labels get a tick along the bottom axis, so a 30-day chart
/// doesn't try to cram thirty overlapping labels.
int _labelInterval(int pointCount) =>
    (pointCount / 5).ceil().clamp(1, pointCount == 0 ? 1 : pointCount);

AxisTitles get _hiddenAxis =>
    const AxisTitles(sideTitles: SideTitles(showTitles: false));

FlTitlesData _trendTitles(
  ThemeData theme,
  List<MapEntry<String, int>> days, {
  required double maxY,
}) {
  final interval = _labelInterval(days.length);
  return FlTitlesData(
    topTitles: _hiddenAxis,
    rightTitles: _hiddenAxis,
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 36,
        getTitlesWidget: (value, meta) {
          if (value < 0 || value == meta.max) return const SizedBox.shrink();
          return Text(
            NumberFormat.compact().format(value),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          );
        },
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 24,
        interval: interval.toDouble(),
        getTitlesWidget: (value, meta) {
          final index = value.round();
          if (index < 0 || index >= days.length) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _shortDay(days[index].key),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        },
      ),
    ),
  );
}

FlGridData _trendGrid(ThemeData theme) => FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) => FlLine(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        strokeWidth: 1,
      ),
    );

/// Daily totals for one series, drawn as a smooth-lined area chart — the
/// default form for "trend over time" (data-viz method: sequential/single
/// hue, one axis).
class TrendAreaChart extends StatelessWidget {
  const TrendAreaChart({
    super.key,
    required this.title,
    required this.trend,
    required this.color,
  });

  final String title;
  final List<MapEntry<String, int>> trend;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = trend.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    final maxY = maxCount == 0 ? 1.0 : maxCount * 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (trend.length - 1).toDouble().clamp(0, double.infinity),
              minY: 0,
              maxY: maxY,
              gridData: _trendGrid(theme),
              borderData: FlBorderData(show: false),
              titlesData: _trendTitles(theme, trend, maxY: maxY),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  getTooltipItems: (spots) => spots.map((spot) {
                    final index = spot.x.round();
                    final day = index >= 0 && index < trend.length
                        ? _shortDay(trend[index].key)
                        : '';
                    return LineTooltipItem(
                      '$day\n${NumberFormat.decimalPattern().format(spot.y.round())}',
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < trend.length; i++)
                      FlSpot(i.toDouble(), trend[i].value.toDouble()),
                  ],
                  isCurved: true,
                  curveSmoothness: 0.2,
                  color: color,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One line of [MetricTrendChart] — a metric's own daily counts, already
/// assigned its fixed categorical color.
class UsageMetricSeries {
  const UsageMetricSeries({
    required this.label,
    required this.color,
    required this.points,
  });

  final String label;
  final Color color;
  final List<MapEntry<String, int>> points;
}

/// Compares how several metrics trend day to day — identity is the job, so
/// color is categorical with a legend (data-viz method: "tell distinct
/// series apart"). Every series shares the same day axis; a metric with no
/// activity on a given day still gets a zero point rather than a gap, so the
/// lines stay comparable.
class MetricTrendChart extends StatelessWidget {
  const MetricTrendChart({super.key, required this.series});

  final List<UsageMetricSeries> series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (series.isEmpty) return const SizedBox.shrink();
    final dayCount = series.first.points.length;
    final maxCount = series.fold<int>(
      0,
      (m, s) => s.points.fold<int>(m, (m2, e) => e.value > m2 ? e.value : m2),
    );
    final maxY = maxCount == 0 ? 1.0 : maxCount * 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Activity by area', style: theme.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          'Same day axis as above, split out by what was used',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (dayCount - 1).toDouble().clamp(0, double.infinity),
              minY: 0,
              maxY: maxY,
              gridData: _trendGrid(theme),
              borderData: FlBorderData(show: false),
              titlesData: _trendTitles(theme, series.first.points, maxY: maxY),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  getTooltipItems: (spots) => spots.map((spot) {
                    final s = series[spot.barIndex];
                    return LineTooltipItem(
                      '${s.label}: ${NumberFormat.decimalPattern().format(spot.y.round())}',
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                for (final s in series)
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < s.points.length; i++)
                        FlSpot(i.toDouble(), s.points[i].value.toDouble()),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: s.color,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final s in series) _LegendEntry(color: s.color, label: s.label)
          ],
        ),
      ],
    );
  }
}

/// One segment of a [ShareBar]: a fixed-identity slice of a part-to-whole
/// total (e.g. a feature group's share of "Features used").
class ShareSegment {
  const ShareSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

/// Part-to-whole share as a single horizontal stacked bar — the data-viz
/// method's form for "part-to-whole" with several long-named categories,
/// used in preference to a pie/donut chart. Segments keep a 2px surface gap
/// (mark spec) so touching colors stay visually distinct without a stroke.
class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.segments});

  final List<ShareSegment> segments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = segments.fold<int>(0, (sum, s) => sum + s.value);
    if (total == 0) return const SizedBox.shrink();
    final percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 20,
            child: Row(
              children: [
                for (var i = 0; i < segments.length; i++) ...[
                  if (i > 0)
                    Container(width: 2, color: theme.colorScheme.surface),
                  Expanded(
                    flex: (segments[i].value * 1000 / total)
                        .round()
                        .clamp(1, 1000),
                    child: Tooltip(
                      message:
                          '${segments[i].label}: ${percentFormat.format(segments[i].value / total)}',
                      child: ColoredBox(color: segments[i].color),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final s in segments)
              _LegendEntry(
                color: s.color,
                label: '${s.label} · ${percentFormat.format(s.value / total)}',
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        // Flexible, not a bare Text: Wrap constrains this Row's width to the
        // row it sits in, and a long label (a feature group's title, a
        // custom event name) needs somewhere to give — wrapping onto a
        // second line rather than overflowing past the chart's edge.
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
