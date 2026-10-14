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
  const StatsHistoryCard({
    super.key,
    required this.summary,
    required this.metric,
    required this.onMetricChanged,
    this.metrics = StatsMetric.values,
  });

  final ActivitySummary summary;

  /// What is plotted - chosen by its pill here or by a tile above.
  final StatsMetric metric;
  final ValueChanged<StatsMetric> onMetricChanged;

  /// The pills offered, in order.
  final List<StatsMetric> metrics;

  @override
  State<StatsHistoryCard> createState() => _StatsHistoryCardState();
}

class _StatsHistoryCardState extends State<StatsHistoryCard> {
  static final NumberFormat _count = NumberFormat.decimalPattern();
  static final NumberFormat _compact = NumberFormat.compact();

  StatsPeriod _period = StatsPeriod.week;

  int _valueOn(DateTime day) {
    final summary = widget.summary;
    return switch (widget.metric) {
      StatsMetric.verses => summary.quranVersesOn(day),
      StatsMetric.zikrs => summary.activityOn(day).zikrs,
      StatsMetric.qaza => summary.activityOn(day).qaza,
    };
  }

  int get _lifetimeTotal => switch (widget.metric) {
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
          StatsPeriod.allTime => DateFormat('MMM').format(start),
        };
    String barName(DateTime start) => switch (_period) {
          StatsPeriod.week => DateFormat('EEEE').format(start),
          StatsPeriod.month => DateFormat('EEE d MMM').format(start),
          StatsPeriod.allTime => DateFormat('MMMM y').format(start),
        };

    final caption = switch (_period) {
      StatsPeriod.week => l10n.statsCaptionWeek(widget.metric.plural),
      StatsPeriod.month => l10n.statsCaptionMonth(widget.metric.plural),
      StatsPeriod.allTime => l10n.statsCaptionAllTime(widget.metric.plural),
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
              for (final metric in widget.metrics)
                ChoicePill(
                  label: metric.label,
                  selected: metric == widget.metric,
                  onTap: () => widget.onMetricChanged(metric),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: l10n.statsHistoryChart(
              widget.metric.label,
              [
                for (final bar in bars)
                  '${barName(bar.start)} ${_count.format(bar.value)}',
              ].join(l10n.listSeparator),
            ),
            excludeSemantics: true,
            child: StatsBarChart(
              values: values,
              labels: [
                for (var i = 0; i < bars.length; i++)
                  // A month of labels would overlap: every fifth day, or
                  // every third month, counted back from today so today -
                  // or this month - is always named.
                  switch (_period) {
                    StatsPeriod.month => (bars.length - 1 - i) % 5 == 0,
                    StatsPeriod.allTime => (bars.length - 1 - i) % 3 == 0,
                    StatsPeriod.week => true,
                  }
                      ? barLabel(bars[i].start, i == bars.length - 1)
                      : '',
              ],
              // Thirty values would overlap too.
              showValues: _period != StatsPeriod.month,
              format: (value) => localizeDigits(
                  value < 1000 ? _count.format(value) : _compact.format(value),
                  l10n),
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

/// A bar chart on a y-axis: one bar per value, scaled to a clean top tick
/// (0 / 5 / 10, 0 / 1K / 2K) with a hairline gridline at each tick and its
/// number at the start edge, its value on top when [showValues], its label
/// under it, and the last - today, or this month - in the accent when
/// [highlightLast]; an empty bar has no number over it. [tooltips], when given, name each bar on hover or long
/// press.
class StatsBarChart extends StatelessWidget {
  const StatsBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.format,
    this.showValues = false,
    this.highlightLast = true,
    this.tooltips,
    this.barArea = 96,
  });

  final List<int> values;
  final List<String> labels;
  final bool showValues;
  final bool highlightLast;
  final List<String>? tooltips;
  final String Function(int value) format;

  /// The height the top tick sits at.
  final double barArea;

  /// The ticks from 0 up to just past [best], a clean step apart (1, 2 or 5
  /// times a power of ten) - two to four intervals, never a fraction.
  @visibleForTesting
  static List<int> ticksFor(int best) {
    if (best <= 0) return const [0, 1];
    final rough = best / 3;
    var magnitude = 1;
    while (magnitude * 10 <= rough) {
      magnitude *= 10;
    }
    final step = [1, 2, 5, 10]
        .map((m) => m * magnitude)
        .firstWhere((step) => step >= rough);
    final top = (best / step).ceil() * step;
    return [for (var tick = 0; tick <= top; tick += step) tick];
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final style = ShiaText.caption.copyWith(color: colors.textMuted);
    final last = highlightLast ? values.length - 1 : -1;
    final ticks = ticksFor(values.fold<int>(0, math.max));
    final top = ticks.last;
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    // The axis is as wide as its widest number, and each number is centred
    // on its gridline.
    final tickPainters = [
      for (final tick in ticks)
        TextPainter(
          text: TextSpan(text: format(tick), style: style),
          textDirection: direction,
          textScaler: textScaler,
          maxLines: 1,
        )..layout(),
    ];
    final axisWidth =
        tickPainters.fold<double>(0, (w, p) => math.max(w, p.width)) + 6;
    final tickHeight = tickPainters.first.height;
    for (final painter in tickPainters) {
      painter.dispose();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final column = (constraints.maxWidth - axisWidth) / values.length;
        final barWidth = math.min(26.0, column * 0.7);
        final barColor = Color.lerp(colors.line, colors.chevron, 0.25);

        Widget bar(int i) {
          Widget mark = Container(
            width: barWidth,
            height: math.max(2, barArea * values[i] / top),
            decoration: BoxDecoration(
              color: i == last ? colors.accent : barColor,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(math.min(6, barWidth / 3)),
                bottom: const Radius.circular(2),
              ),
            ),
          );
          final tooltip = tooltips?[i];
          if (tooltip != null) {
            mark = Tooltip(message: tooltip, child: mark);
          }
          return mark;
        }

        return Column(
          children: [
            Padding(
              // Room for the top tick's number above its gridline.
              padding: EdgeInsets.only(top: tickHeight / 2),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final tick in ticks) ...[
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: barArea * tick / top,
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(start: axisWidth),
                        child: Container(height: 1, color: colors.line),
                      ),
                    ),
                    PositionedDirectional(
                      start: 0,
                      width: axisWidth - 6,
                      bottom: barArea * tick / top - tickHeight / 2,
                      child: Text(
                        format(tick),
                        maxLines: 1,
                        textAlign: TextAlign.end,
                        style: style,
                      ),
                    ),
                  ],
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: barArea),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(width: axisWidth),
                        for (var i = 0; i < values.length; i++)
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showValues && values[i] > 0) ...[
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
                                  const SizedBox(height: 4),
                                ],
                                bar(i),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(width: axisWidth),
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
