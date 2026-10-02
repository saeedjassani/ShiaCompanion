import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/activity_stats.dart';
import 'stats_widgets.dart';

/// What the history chart plots.
enum StatsMetric {
  verses('Verses', 'verses', 'verse'),
  zikrs('Zikrs', 'zikrs', 'zikr'),
  qaza('Qaza', 'qaza', 'qaza');

  const StatsMetric(this.label, this.plural, this.singular);

  final String label;
  final String plural;
  final String singular;

  String count(int value, NumberFormat format) =>
      '${format.format(value)} ${value == 1 ? singular : plural}';
}

/// The window the history chart covers: a bar per day for the week and the
/// month, a bar per month for all time.
enum StatsPeriod {
  week('Week'),
  month('Month'),
  allTime('All time');

  const StatsPeriod(this.label);

  final String label;
}

/// Months of bars in the all-time view - a year, which the per-day history
/// kept on each device (activityRetentionDays) always covers.
const int _allTimeMonths = 12;

/// Calendar-day arithmetic, safe across a DST change.
DateTime _day(DateTime now, int offset) =>
    DateTime(now.year, now.month, now.day + offset);

/// One bar: the day or month it covers, and its total.
typedef _Bar = ({DateTime start, int value});

/// A metric over a chosen window, with what turns a chart into
/// encouragement: the week or month against the one before it, the best day
/// or month in it, and - under All time - the lifetime total.
class StatsHistoryCard extends StatefulWidget {
  const StatsHistoryCard({super.key, required this.summary});

  final ActivitySummary summary;

  @override
  State<StatsHistoryCard> createState() => _StatsHistoryCardState();
}

class _StatsHistoryCardState extends State<StatsHistoryCard> {
  static final NumberFormat _count = NumberFormat.decimalPattern();

  StatsMetric _metric = StatsMetric.verses;
  StatsPeriod _period = StatsPeriod.week;

  int _valueOn(DateTime day) {
    final summary = widget.summary;
    return switch (_metric) {
      StatsMetric.verses => summary.quranVersesOn(day),
      StatsMetric.zikrs => summary.activityOn(day).zikrs,
      StatsMetric.qaza => summary.activityOn(day).qaza,
    };
  }

  int get _lifetimeTotal => switch (_metric) {
        StatsMetric.verses => widget.summary.quranVersesTotal,
        StatsMetric.zikrs => widget.summary.totalZikrs,
        StatsMetric.qaza => widget.summary.totalQaza,
      };

  List<_Bar> _dailyBars(DateTime now, int days, {int offset = 0}) => [
        for (var i = days - 1 + offset; i >= offset; i--)
          (start: _day(now, -i), value: _valueOn(_day(now, -i))),
      ];

  List<_Bar> _monthlyBars(DateTime now) {
    return [
      for (var i = _allTimeMonths - 1; i >= 0; i--)
        () {
          final start = DateTime(now.year, now.month - i);
          final next = DateTime(start.year, start.month + 1);
          var value = 0;
          for (var day = start;
              day.isBefore(next);
              day = DateTime(day.year, day.month, day.day + 1)) {
            value += _valueOn(day);
          }
          return (start: start, value: value);
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final isAllTime = _period == StatsPeriod.allTime;
    final days = _period == StatsPeriod.week ? 7 : 30;

    final bars = isAllTime ? _monthlyBars(now) : _dailyBars(now, days);
    final values = [for (final bar in bars) bar.value];
    final periodTotal = values.fold<int>(0, (sum, v) => sum + v);
    final total = isAllTime ? _lifetimeTotal : periodTotal;
    final previousTotal = isAllTime
        ? 0
        : _dailyBars(now, days, offset: days)
            .fold<int>(0, (sum, bar) => sum + bar.value);
    final best = values.fold<int>(0, math.max);
    final bestIndex = best == 0 ? -1 : values.lastIndexOf(best);
    final maxY = best == 0 ? 1.0 : best * 1.2;
    final narrowBars = _period == StatsPeriod.month;

    String barLabel(DateTime start) => switch (_period) {
          StatsPeriod.week => DateFormat('E').format(start).substring(0, 1),
          StatsPeriod.month => DateFormat('d').format(start),
          StatsPeriod.allTime =>
            DateFormat('MMM').format(start).substring(0, 1),
        };
    String barName(DateTime start) => isAllTime
        ? DateFormat('MMMM y').format(start)
        : DateFormat('EEE, MMM d').format(start);

    final caption = switch (_period) {
      StatsPeriod.week => '${_metric.plural} in the last 7 days',
      StatsPeriod.month => '${_metric.plural} in the last 30 days',
      StatsPeriod.allTime => '${_metric.plural} in total',
    };

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatsSectionTitle('History'),
          const SizedBox(height: 10),
          SegmentedButton<StatsPeriod>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              for (final period in StatsPeriod.values)
                ButtonSegment(value: period, label: Text(period.label)),
            ],
            selected: {_period},
            onSelectionChanged: (value) =>
                setState(() => _period = value.first),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in StatsMetric.values)
                ChoiceChip(
                  showCheckmark: false,
                  label: Text(metric.label),
                  selected: metric == _metric,
                  onSelected: (_) => setState(() => _metric = metric),
                ),
            ],
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
                      caption,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isAllTime)
                _TrendBadge(current: periodTotal, previous: previousTotal),
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
                        if (index < 0 || index >= bars.length) {
                          return const SizedBox.shrink();
                        }
                        // A month of labels would overlap: every fifth day,
                        // counted back from today so today is always named.
                        final fromEnd = bars.length - 1 - index;
                        if (narrowBars && fromEnd % 5 != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            barLabel(bars[index].start),
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
                      '${barName(bars[group.x].start)}\n'
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
                          width: narrowBars ? 6 : (isAllTime ? 14 : 22),
                          color: i == bestIndex
                              ? colorScheme.primary
                              : colorScheme.primary.withValues(alpha: 0.55),
                          borderRadius:
                              BorderRadius.circular(narrowBars ? 2 : 5),
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
              isAllTime
                  ? 'Best month: ${barName(bars[bestIndex].start)}'
                      ' · ${_metric.count(best, _count)}'
                  : 'Best day: ${barName(bars[bestIndex].start)}'
                      ' · ${_metric.count(best, _count)}'
                      ' · ${(periodTotal / days).toStringAsFixed(periodTotal / days < 10 ? 1 : 0)} a day on average',
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
