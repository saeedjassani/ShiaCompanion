import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/activity_stats.dart';
import '../../models/recitation_tracker_state.dart';
import 'stats_widgets.dart';

/// What the history chart plots.
enum StatsMetric {
  verses('Verses', 'verses', 'verse'),
  sessions('Sessions', 'sessions', 'session'),
  zikrs('Zikrs', 'zikrs', 'zikr'),
  qaza('Qaza', 'qaza', 'qaza');

  const StatsMetric(this.label, this.plural, this.singular);

  final String label;
  final String plural;
  final String singular;

  String count(int value, NumberFormat format) =>
      '${format.format(value)} ${value == 1 ? singular : plural}';
}

/// Calendar-day arithmetic, safe across a DST change.
DateTime _day(DateTime now, int offset) =>
    DateTime(now.year, now.month, now.day + offset);

/// Daily totals for a metric over a chosen window, with the comparison that
/// turns a chart into encouragement: how this period went against the one
/// before it, and the best day in it.
class StatsHistoryCard extends StatefulWidget {
  const StatsHistoryCard({
    super.key,
    required this.summary,
    required this.recitation,
  });

  final ActivitySummary summary;
  final RecitationTrackerState recitation;

  @override
  State<StatsHistoryCard> createState() => _StatsHistoryCardState();
}

class _StatsHistoryCardState extends State<StatsHistoryCard> {
  static final NumberFormat _count = NumberFormat.decimalPattern();

  StatsMetric _metric = StatsMetric.verses;
  int _days = 7;

  int _valueOn(DateTime day, Map<DateTime, int> sessions) {
    return switch (_metric) {
      StatsMetric.verses => widget.summary.quranVersesOn(day),
      StatsMetric.sessions => sessions[day] ?? 0,
      StatsMetric.zikrs => widget.summary.activityOn(day).zikrs,
      StatsMetric.qaza => widget.summary.activityOn(day).qaza,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final sessions = widget.recitation.dailySessionCounts(_days * 2);

    final days = [for (var i = _days - 1; i >= 0; i--) _day(now, -i)];
    final values = [for (final day in days) _valueOn(day, sessions)];
    final previous = [
      for (var i = _days * 2 - 1; i >= _days; i--)
        _valueOn(_day(now, -i), sessions),
    ];
    final total = values.fold<int>(0, (sum, v) => sum + v);
    final previousTotal = previous.fold<int>(0, (sum, v) => sum + v);
    final best = values.fold<int>(0, math.max);
    final bestIndex = best == 0 ? -1 : values.lastIndexOf(best);
    final maxY = best == 0 ? 1.0 : best * 1.2;

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: StatsSectionTitle('History')),
              SegmentedButton<int>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(value: 7, label: Text('Week')),
                  ButtonSegment(value: 30, label: Text('Month')),
                ],
                selected: {_days},
                onSelectionChanged: (value) =>
                    setState(() => _days = value.first),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final metric in StatsMetric.values) ...[
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text(metric.label),
                    selected: metric == _metric,
                    onSelected: (_) => setState(() => _metric = metric),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _count.format(total),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${_metric.plural} ${_days == 7 ? 'in the last 7 days' : 'in the last 30 days'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _TrendBadge(current: total, previous: previousTotal),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= days.length) {
                          return const SizedBox.shrink();
                        }
                        // A month of labels would overlap: every fifth day,
                        // counted back from today so today is always named.
                        final fromEnd = days.length - 1 - index;
                        if (_days > 7 && fromEnd % 5 != 0) {
                          return const SizedBox.shrink();
                        }
                        final day = days[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _days == 7
                                ? DateFormat('E').format(day).substring(0, 1)
                                : DateFormat('d').format(day),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: fromEnd == 0 ? FontWeight.w800 : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colorScheme.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                      '${DateFormat('EEE, MMM d').format(days[group.x])}\n'
                      '${_metric.count(rod.toY.round(), _count)}',
                      TextStyle(
                        color: colorScheme.onInverseSurface,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i].toDouble(),
                          width: _days == 7 ? 22 : 6,
                          color: i == bestIndex
                              ? colorScheme.primary
                              : colorScheme.primary.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(
                            _days == 7 ? 6 : 2,
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.04),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (best > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Best day: ${DateFormat('EEE, MMM d').format(days[bestIndex])}'
              ' · ${_metric.count(best, _count)}'
              ' · ${(total / _days).toStringAsFixed(total / _days < 10 ? 1 : 0)} a day on average',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "▲ 24%" against the previous period - only ever shown in a positive or
/// neutral light: a dip reads as "last time", not as a red failure.
class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.current, required this.previous});

  final int current;
  final int previous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String text;
    final bool up;
    if (previous == 0) {
      if (current == 0) return const SizedBox.shrink();
      text = 'New';
      up = true;
    } else {
      final change = ((current - previous) / previous * 100).round();
      up = change >= 0;
      text = up
          ? '▲ $change%'
          : 'vs ${NumberFormat.compact().format(previous)} before';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: up
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: up
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The last [weeks] weeks as a GitHub-style grid, a column per week, darker
/// for a fuller day - consistency at a glance, the way a missed day reads as
/// one pale square among many rather than a reset counter.
class ConsistencyHeatmap extends StatelessWidget {
  const ConsistencyHeatmap({
    super.key,
    required this.summary,
    this.weeks = 17,
  });

  final ActivitySummary summary;
  final int weeks;

  /// One number per day across every kind of activity. Verses are scaled down
  /// so a long surah does not drown out a day of duas.
  int _score(DateTime day) {
    final activity = summary.activityOn(day);
    return activity.zikrs +
        activity.qaza +
        (summary.quranVersesOn(day) / 10).ceil();
  }

  static int _level(int score) {
    if (score <= 0) return 0;
    if (score <= 2) return 1;
    if (score <= 5) return 2;
    if (score <= 10) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    // Columns start on Monday; the last column ends with this week.
    final thisMonday = _day(now, -(now.weekday - 1));
    final firstMonday = DateTime(
      thisMonday.year,
      thisMonday.month,
      thisMonday.day - 7 * (weeks - 1),
    );
    final today = _day(now, 0);
    final activeDays = summary.activeDaysInLast(weeks * 7);

    Color colorFor(int level) => level == 0
        ? colorScheme.onSurface.withValues(alpha: 0.06)
        : colorScheme.primary.withValues(alpha: 0.2 + 0.2 * level);

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatsSectionTitle('Consistency'),
          const SizedBox(height: 2),
          Text(
            'Active on $activeDays of the last ${weeks * 7} days',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 3.0;
              final cell = math.min(
                18.0,
                (constraints.maxWidth - gap * (weeks - 1)) / weeks,
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var w = 0; w < weeks; w++)
                    Padding(
                      padding: EdgeInsets.only(left: w == 0 ? 0 : gap),
                      child: Column(
                        children: [
                          for (var d = 0; d < 7; d++)
                            Builder(builder: (context) {
                              final day = DateTime(
                                firstMonday.year,
                                firstMonday.month,
                                firstMonday.day + w * 7 + d,
                              );
                              final future = day.isAfter(today);
                              final level = future ? 0 : _level(_score(day));
                              return Padding(
                                padding: EdgeInsets.only(top: d == 0 ? 0 : gap),
                                child: Tooltip(
                                  message: future
                                      ? ''
                                      : DateFormat('EEE, MMM d').format(day),
                                  child: Container(
                                    width: cell,
                                    height: cell,
                                    decoration: BoxDecoration(
                                      color: future
                                          ? Colors.transparent
                                          : colorFor(level),
                                      borderRadius:
                                          BorderRadius.circular(cell / 4),
                                      border: day == today
                                          ? Border.all(
                                              color: colorScheme.primary,
                                              width: 1.5,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Less', style: theme.textTheme.labelSmall),
              for (var level = 0; level <= 4; level++)
                Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    color: colorFor(level),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const SizedBox(width: 4),
              Text('More', style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}
