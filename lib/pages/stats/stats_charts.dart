import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/activity_stats.dart';
import '../../theme/shia_colors.dart';
import '../../widgets/page_chrome.dart';
import 'stats_widgets.dart';
import '../../l10n/l10n.dart';

/// What the history chart plots.
enum StatsMetric {
  verses,
  zikrs,
  qaza;

  String get label => switch (this) {
        StatsMetric.verses => L10n.current.statsMetricVerses,
        StatsMetric.zikrs => L10n.current.statsMetricZikrs,
        StatsMetric.qaza => L10n.current.statsMetricQaza,
      };

  /// The metric in a caption ("verses in the last 7 days").
  String get plural => switch (this) {
        StatsMetric.verses => L10n.current.statsMetricVersesLower,
        StatsMetric.zikrs => L10n.current.statsMetricZikrsLower,
        StatsMetric.qaza => L10n.current.statsMetricQazaLower,
      };

  String count(int value, NumberFormat format) => switch (this) {
        StatsMetric.verses =>
          L10n.current.statsVerseCount(value, format.format(value)),
        StatsMetric.zikrs =>
          L10n.current.statsZikrCount(value, format.format(value)),
        StatsMetric.qaza =>
          L10n.current.statsQazaCount(value, format.format(value)),
      };
}

/// The window the history chart covers: a bar per day for the week and the
/// month, a bar per month for all time.
enum StatsPeriod {
  week,
  month,
  allTime;

  String get label => switch (this) {
        StatsPeriod.week => L10n.current.statsPeriodWeek,
        StatsPeriod.month => L10n.current.statsPeriodMonth,
        StatsPeriod.allTime => L10n.current.statsPeriodAllTime,
      };
}

/// Months of bars in the all-time view - a year, which the per-day history
/// kept on each device (activityRetentionDays) always covers.
const int _allTimeMonths = 12;

/// Calendar-day arithmetic, safe across a DST change.
DateTime _day(DateTime now, int offset) =>
    DateTime(now.year, now.month, now.day + offset);

/// One bar: the day or month it covers, and its total.
typedef _Bar = ({DateTime start, int value});

/// A metric over a chosen window (docs/DESIGN_SPEC.md, "My Stats"; mockup
/// `R3-My-stats`): Zikrs / Verses / Qaza as pills, one bar per day (per
/// month under All time) with its value on top and today in the accent,
/// the window as a segmented switcher, and the best day and the total in
/// words.
class StatsHistoryCard extends StatefulWidget {
  const StatsHistoryCard({super.key, required this.summary});

  final ActivitySummary summary;

  @override
  State<StatsHistoryCard> createState() => _StatsHistoryCardState();
}

class _StatsHistoryCardState extends State<StatsHistoryCard> {
  static final NumberFormat _count = NumberFormat.decimalPattern();
  static final NumberFormat _compact = NumberFormat.compact();

  StatsMetric _metric = StatsMetric.zikrs;
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

  List<_Bar> _dailyBars(DateTime now, int days) => [
        for (var i = days - 1; i >= 0; i--)
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
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final now = DateTime.now();
    final isAllTime = _period == StatsPeriod.allTime;
    final days = _period == StatsPeriod.week ? 7 : 30;

    final bars = isAllTime ? _monthlyBars(now) : _dailyBars(now, days);
    final values = [for (final bar in bars) bar.value];
    final periodTotal = values.fold<int>(0, (sum, v) => sum + v);
    final total = isAllTime ? _lifetimeTotal : periodTotal;
    final best = values.fold<int>(0, math.max);
    final bestIndex = best == 0 ? -1 : values.lastIndexOf(best);

    String barLabel(DateTime start, bool last) => switch (_period) {
          StatsPeriod.week =>
            last ? l10n.statsToday : DateFormat('EEE').format(start),
          StatsPeriod.month => DateFormat('d').format(start),
          StatsPeriod.allTime =>
            DateFormat('MMM').format(start).substring(0, 1),
        };
    String barName(DateTime start) => switch (_period) {
          StatsPeriod.week => DateFormat('EEEE').format(start),
          StatsPeriod.month => DateFormat('EEE d MMM').format(start),
          StatsPeriod.allTime => DateFormat('MMMM y').format(start),
        };

    final caption = switch (_period) {
      StatsPeriod.week => l10n.statsCaptionWeek(_metric.plural),
      StatsPeriod.month => l10n.statsCaptionMonth(_metric.plural),
      StatsPeriod.allTime => l10n.statsCaptionAllTime(_metric.plural),
    };

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: StatsSectionTitle(l10n.statsHistory)),
              if (bestIndex >= 0)
                Flexible(
                  child: Text(
                    isAllTime
                        ? l10n.statsBestMonthShort(
                            DateFormat('MMMM').format(bars[bestIndex].start))
                        : l10n
                            .statsBestDayShort(barName(bars[bestIndex].start)),
                    textAlign: TextAlign.end,
                    style: ShiaText.caption.copyWith(color: colors.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in const [
                StatsMetric.zikrs,
                StatsMetric.verses,
                StatsMetric.qaza,
              ])
                ChoicePill(
                  label: metric.label,
                  selected: metric == _metric,
                  onTap: () => setState(() => _metric = metric),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: l10n.statsHistoryChart(
              _metric.label,
              [
                for (final bar in bars)
                  '${barName(bar.start)} ${_count.format(bar.value)}',
              ].join(l10n.listSeparator),
            ),
            excludeSemantics: true,
            child: _HistoryBars(
              values: values,
              labels: [
                for (var i = 0; i < bars.length; i++)
                  // A month of labels would overlap: every fifth day,
                  // counted back from today so today is always named.
                  _period == StatsPeriod.month && (bars.length - 1 - i) % 5 != 0
                      ? ''
                      : barLabel(bars[i].start, i == bars.length - 1),
              ],
              // Thirty values would overlap too.
              showValues: _period != StatsPeriod.month,
              format: (value) =>
                  value < 1000 ? _count.format(value) : _compact.format(value),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.statsTotalCaption(_count.format(total), caption),
            style: ShiaText.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 12),
          SegmentedSwitcher<StatsPeriod>(
            segments: [
              for (final period in StatsPeriod.values)
                Segment(period, period.label),
            ],
            selected: _period,
            onChanged: (period) => setState(() => _period = period),
          ),
        ],
      ),
    );
  }
}

/// The bars of [StatsHistoryCard]: one per value, its value on top when
/// [showValues], its label under it, and the last - today, or this month -
/// in the accent.
class _HistoryBars extends StatelessWidget {
  const _HistoryBars({
    required this.values,
    required this.labels,
    required this.showValues,
    required this.format,
  });

  final List<int> values;
  final List<String> labels;
  final bool showValues;
  final String Function(int value) format;

  static const double _barArea = 96;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final best = values.fold<int>(0, math.max);
    final style = ShiaText.caption.copyWith(color: colors.textMuted);
    final last = values.length - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final column = constraints.maxWidth / values.length;
        final barWidth = math.min(26.0, column * 0.7);
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showValues)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              format(values[i]),
                              maxLines: 1,
                              style: style.copyWith(
                                fontWeight: FontWeight.w600,
                                color: i == last ? colors.text : null,
                              ),
                            ),
                          ),
                        if (showValues) const SizedBox(height: 4),
                        Container(
                          width: barWidth,
                          height: best == 0
                              ? 2
                              : math.max(2, _barArea * values[i] / best),
                          decoration: BoxDecoration(
                            color: i == last
                                ? colors.accent
                                : Color.lerp(colors.line, colors.chevron, 0.25),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(math.min(6, barWidth / 3)),
                              bottom: const Radius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    // A label can be wider than its bar's column (a month's
                    // "25" under a 10 px bar); let it spill rather than wrap.
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.center,
                      style: style.copyWith(
                        fontWeight:
                            i == last ? FontWeight.w700 : FontWeight.w500,
                        color: i == last ? colors.text : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
