import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../services/analytics_service.dart';
import '../../widgets/responsive_content.dart';

/// How far back a view of the counters reaches.
enum UsageRange {
  today('Today', 1),
  week('7 days', 7),
  month('30 days', 30),
  allTime('All time', 0);

  const UsageRange(this.label, this.days);

  final String label;

  /// Zero means read the all-time totals instead of summing day buckets.
  final int days;

  bool get isAllTime => days == 0;
}

/// One row of the ranking.
class UsageRow {
  const UsageRow({required this.key, required this.label, required this.count});

  final String key;
  final String label;
  final int count;
}

/// Everything the dashboard needs, read in one pass.
class UsageSnapshot {
  const UsageSnapshot({
    required this.metrics,
    required this.trend,
  });

  static const UsageSnapshot empty =
      UsageSnapshot(metrics: {}, trend: <MapEntry<String, int>>[]);

  /// metric name -> rows, already sorted with the biggest first.
  final Map<String, List<UsageRow>> metrics;

  /// Day -> total events, oldest first. Empty for the all-time view, which has
  /// no days to plot.
  final List<MapEntry<String, int>> trend;

  List<UsageRow> rowsFor(String metric) => metrics[metric] ?? const [];

  int totalFor(String metric) =>
      rowsFor(metric).fold<int>(0, (sum, row) => sum + row.count);

  bool get isEmpty => metrics.values.every((rows) => rows.isEmpty);
}

/// Suffix [AnalyticsService.zikrCompleted] appends so completions can share the
/// zikr metric without needing a metric of their own.
const String zikrCompletionSuffix = '~done';

/// Parses `usage/totals`'s raw snapshot value into metric -> key -> count.
///
/// A standalone function, because a counter written by
/// [ServerValue.increment] comes back as an `int` on Android/iOS but a
/// `double` on web -- JS has no integer type, and the web plugin's
/// JS-interop conversion reflects that. Worth a plain unit test rather than
/// only ever being exercised against a live database, since that split is
/// exactly the kind of thing that renders correctly on a phone and empty on
/// web.
@visibleForTesting
Map<String, Map<String, int>> parseUsageTotals(Object? value) {
  final counts = <String, Map<String, int>>{};
  if (value is Map) {
    value.forEach((metric, keys) {
      if (keys is! Map) return;
      final bucket = counts.putIfAbsent('$metric', () => <String, int>{});
      keys.forEach((key, count) {
        if (count is num) {
          bucket['$key'] = (bucket['$key'] ?? 0) + count.toInt();
        }
      });
    });
  }
  return counts;
}

/// Parses `usage/daily`'s raw snapshot value, keeping only the days in
/// [wantedDays] and folding every metric's counters into both the per-metric
/// totals and the day-by-day trend. See [parseUsageTotals] for why `count`
/// is checked against `num` rather than `int`.
@visibleForTesting
({Map<String, Map<String, int>> counts, Map<String, int> trend})
    parseUsageDays(Object? value, List<String> wantedDays) {
  final counts = <String, Map<String, int>>{};
  final trend = <String, int>{for (final day in wantedDays) day: 0};

  if (value is Map) {
    value.forEach((rawDay, metrics) {
      final day = '$rawDay';
      if (!trend.containsKey(day) || metrics is! Map) return;
      metrics.forEach((metric, keys) {
        if (keys is! Map) return;
        final bucket = counts.putIfAbsent('$metric', () => <String, int>{});
        keys.forEach((key, count) {
          if (count is! num) return;
          final value = count.toInt();
          bucket['$key'] = (bucket['$key'] ?? 0) + value;
          trend[day] = (trend[day] ?? 0) + value;
        });
      });
    });
  }
  return (counts: counts, trend: trend);
}

/// Folds the completion counters back into the zikr they belong to.
///
/// They live in the same metric as opens, so without this a popular zikr would
/// appear twice in the ranking and its completions would compete with its own
/// opens for a place in the top ten.
List<UsageRow> splitZikrCompletions(List<UsageRow> rows) {
  final completions = <String, int>{
    for (final row in rows)
      if (row.key.endsWith(zikrCompletionSuffix))
        row.key.substring(0, row.key.length - zikrCompletionSuffix.length):
            row.count,
  };

  return rows
      .where((row) => !row.key.endsWith(zikrCompletionSuffix))
      .map((row) {
    final done = completions[row.key] ?? 0;
    return UsageRow(
      key: row.key,
      label: done > 0 ? '${row.label}  ·  $done finished' : row.label,
      count: row.count,
    );
  }).toList();
}

/// Admin-only view of the usage counters written by [AnalyticsService].
///
/// Reads the Realtime Database rather than GA4 because these numbers are live,
/// need no custom-dimension registration, and can be sliced the way this app
/// thinks about itself rather than the way GA4 does.
class UsageDashboardPage extends StatefulWidget {
  const UsageDashboardPage({super.key});

  @override
  State<UsageDashboardPage> createState() => _UsageDashboardPageState();
}

class _UsageDashboardPageState extends State<UsageDashboardPage> {
  static final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');
  static final NumberFormat _countFormat = NumberFormat.decimalPattern();

  UsageRange _range = UsageRange.week;
  late Future<UsageSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    trackScreen('Usage Dashboard Page');
    _snapshot = _load();
  }

  void _reload() {
    setState(() => _snapshot = _load());
  }

  Future<UsageSnapshot> _load() {
    return _range.isAllTime ? _loadTotals() : _loadDays(_range.days);
  }

  Future<UsageSnapshot> _loadTotals() async {
    final snapshot = await FirebaseDatabase.instance.ref('usage/totals').get();
    final labels = await _loadLabels();
    final counts = parseUsageTotals(snapshot.value);
    return _toSnapshot(counts, labels, const []);
  }

  Future<UsageSnapshot> _loadDays(int days) async {
    final today = DateTime.now();
    final wanted = List.generate(
      days,
      (offset) => _dayFormat.format(today.subtract(Duration(days: offset))),
    ).reversed.toList();

    // Day keys are ISO dates, so they sort lexicographically and the range can
    // be pushed to the server. Reading the whole tree and filtering here would
    // download every retained day — up to 400 of them — to show thirty.
    final snapshot = await FirebaseDatabase.instance
        .ref('usage/daily')
        .orderByKey()
        .startAt(wanted.first)
        .endAt(wanted.last)
        .get();
    final labels = await _loadLabels();

    final parsed = parseUsageDays(snapshot.value, wanted);
    return _toSnapshot(
      parsed.counts,
      labels,
      wanted.map((day) => MapEntry(day, parsed.trend[day] ?? 0)).toList(),
    );
  }

  Future<Map<String, String>> _loadLabels() async {
    final snapshot = await FirebaseDatabase.instance.ref('usage/labels').get();
    final labels = <String, String>{};
    final value = snapshot.value;
    if (value is Map) {
      value.forEach((metric, keys) {
        if (keys is! Map) return;
        keys.forEach((key, label) => labels['$metric/$key'] = '$label');
      });
    }
    return labels;
  }

  UsageSnapshot _toSnapshot(
    Map<String, Map<String, int>> counts,
    Map<String, String> labels,
    List<MapEntry<String, int>> trend,
  ) {
    final metrics = <String, List<UsageRow>>{};
    counts.forEach((metric, keys) {
      final rows = keys.entries
          .map((entry) => UsageRow(
                key: entry.key,
                label: _labelFor(metric, entry.key, labels),
                count: entry.value,
              ))
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));
      metrics[metric] = rows;
    });
    return UsageSnapshot(metrics: metrics, trend: trend);
  }

  /// Prefers the label recorded alongside the counter, falls back to the live
  /// zikr index, and shows the raw key when a zikr has since been deleted so a
  /// row is never silently dropped.
  String _labelFor(String metric, String key, Map<String, String> labels) {
    final recorded = labels['$metric/$key'];
    if (recorded != null && recorded.isNotEmpty) return recorded;
    if (metric == AnalyticsService.metricZikr) {
      final title = items[key]?.toString();
      if (title != null && title.isNotEmpty) return title;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<UsageSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error!, onRetry: _reload);
          }
          return _buildBody(context, snapshot.data ?? UsageSnapshot.empty);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, UsageSnapshot data) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          ResponsiveContent(
            maxWidth: listContentWidth,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildRangePicker(context),
                const SizedBox(height: 16),
                if (data.isEmpty)
                  _EmptyView(range: _range)
                else ...[
                  _buildHeadlines(context, data),
                  if (data.trend.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _TrendChart(trend: data.trend),
                  ],
                  const SizedBox(height: 8),
                  _UsageSection(
                    title: 'Most opened zikrs',
                    subtitle: 'Aliases counted with the zikr they point at',
                    rows: _zikrRows(data),
                    countFormat: _countFormat,
                  ),
                  _UsageSection(
                    title: 'Features used',
                    subtitle: 'Actions taken, not just screens opened',
                    rows: data.rowsFor(AnalyticsService.metricFeature),
                    countFormat: _countFormat,
                  ),
                  _UsageSection(
                    title: 'Screens',
                    rows: data.rowsFor(AnalyticsService.metricScreen),
                    countFormat: _countFormat,
                  ),
                  _UsageSection(
                    title: 'Library',
                    subtitle: 'Chapters opened, by book',
                    rows: data.rowsFor(AnalyticsService.metricLibrary),
                    countFormat: _countFormat,
                  ),
                  _UsageSection(
                    title: 'Live streams',
                    rows: data.rowsFor(AnalyticsService.metricStream),
                    countFormat: _countFormat,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<UsageRow> _zikrRows(UsageSnapshot data) =>
      splitZikrCompletions(data.rowsFor(AnalyticsService.metricZikr));

  Widget _buildRangePicker(BuildContext context) {
    return SegmentedButton<UsageRange>(
      segments: UsageRange.values
          .map((range) => ButtonSegment<UsageRange>(
                value: range,
                label: Text(range.label),
              ))
          .toList(),
      selected: {_range},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() {
          _range = selection.first;
          _snapshot = _load();
        });
      },
    );
  }

  Widget _buildHeadlines(BuildContext context, UsageSnapshot data) {
    final zikrOpens = _zikrRows(data).fold<int>(0, (sum, r) => sum + r.count);
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Zikr opens',
            value: _countFormat.format(zikrOpens),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Distinct zikrs',
            value: _countFormat.format(_zikrRows(data).length),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Feature uses',
            value: _countFormat.format(
              data.totalFor(AnalyticsService.metricFeature),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ranked list with a proportional bar, so the shape of the distribution reads
/// at a glance instead of having to compare numbers.
class _UsageSection extends StatefulWidget {
  const _UsageSection({
    required this.title,
    required this.rows,
    required this.countFormat,
    this.subtitle,
  });

  static const int _collapsedRowCount = 10;

  final String title;
  final String? subtitle;
  final List<UsageRow> rows;
  final NumberFormat countFormat;

  @override
  State<_UsageSection> createState() => _UsageSectionState();
}

class _UsageSectionState extends State<_UsageSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final max = widget.rows.first.count;
    final visible = _expanded
        ? widget.rows
        : widget.rows.take(_UsageSection._collapsedRowCount).toList();
    final hidden = widget.rows.length - visible.length;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: theme.textTheme.titleMedium),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              widget.subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (var i = 0; i < visible.length; i++)
            _UsageBar(
              rank: i + 1,
              row: visible[i],
              fraction: max == 0 ? 0 : visible[i].count / max,
              countFormat: widget.countFormat,
            ),
          if (hidden > 0 || _expanded)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Show less' : 'Show $hidden more'),
              ),
            ),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({
    required this.rank,
    required this.row,
    required this.fraction,
    required this.countFormat,
  });

  final int rank;
  final UsageRow row;
  final double fraction;
  final NumberFormat countFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  row.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                countFormat.format(row.count),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Daily totals as a bar strip. Deliberately dependency-free — a chart package
/// would be a lot of weight for one sparkline.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.trend});

  final List<MapEntry<String, int>> trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = trend.fold<int>(0, (m, e) => e.value > m ? e.value : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Events per day', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in trend)
                Expanded(
                  child: Tooltip(
                    message: '${entry.key}: ${entry.value}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: max == 0
                                ? 2
                                : (entry.value / max * 88).clamp(2.0, 88.0),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(trend.first.key, style: theme.textTheme.bodySmall),
            Text(trend.last.key, style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.range});

  final UsageRange range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.query_stats,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('No usage recorded for ${range.label.toLowerCase()}',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Counters start filling once a release with analytics is in '
            'people\'s hands. Debug builds are excluded on purpose.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text('Could not read usage', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
