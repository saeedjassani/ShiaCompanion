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

  /// What the headline tiles' period-over-period delta is measured against.
  /// Empty for All time, which has no equal-length "previous" period.
  String get previousPeriodLabel => switch (this) {
        UsageRange.today => 'yesterday',
        UsageRange.week => 'the previous 7 days',
        UsageRange.month => 'the previous 30 days',
        UsageRange.allTime => '',
      };
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
    this.previous,
  });

  static const UsageSnapshot empty =
      UsageSnapshot(metrics: {}, trend: <MapEntry<String, int>>[]);

  /// metric name -> rows, already sorted with the biggest first.
  final Map<String, List<UsageRow>> metrics;

  /// Day -> total events, oldest first. Empty for the all-time view, which has
  /// no days to plot.
  final List<MapEntry<String, int>> trend;

  /// The equal-length period immediately before this one, for the headline
  /// tiles' delta. Null for All time, which has nothing to compare against.
  final PreviousPeriodTotals? previous;

  List<UsageRow> rowsFor(String metric) => metrics[metric] ?? const [];

  int totalFor(String metric) =>
      rowsFor(metric).fold<int>(0, (sum, row) => sum + row.count);

  bool get isEmpty => metrics.values.every((rows) => rows.isEmpty);
}

/// The three headline numbers, aggregated for the period immediately before
/// the one being viewed. Nothing else on the dashboard needs a
/// previous-period figure, so this stops short of building and labelling a
/// whole second [UsageSnapshot].
class PreviousPeriodTotals {
  const PreviousPeriodTotals({
    required this.zikrOpens,
    required this.distinctZikrs,
    required this.featureUses,
  });

  final int zikrOpens;
  final int distinctZikrs;
  final int featureUses;
}

/// Reduces a parsed counts map (see [parseUsageDays]) down to
/// [PreviousPeriodTotals]. A standalone function so the headline delta logic
/// is testable without a live database, the same way [parseUsageTotals] is.
@visibleForTesting
PreviousPeriodTotals previousTotalsFrom(Map<String, Map<String, int>> counts) {
  final zikrOpenEntries = (counts[AnalyticsService.metricZikr] ?? const {})
      .entries
      .where((entry) => !entry.key.endsWith(zikrCompletionSuffix));
  final zikrOpens =
      zikrOpenEntries.fold<int>(0, (sum, entry) => sum + entry.value);
  final featureUses = (counts[AnalyticsService.metricFeature] ?? const {})
      .values
      .fold<int>(0, (sum, count) => sum + count);
  return PreviousPeriodTotals(
    zikrOpens: zikrOpens,
    distinctZikrs: zikrOpenEntries.length,
    featureUses: featureUses,
  );
}

/// Which way a [PeriodDelta] points, so the widget layer can colour and icon
/// it without re-deriving the sign from the label text.
enum DeltaDirection { up, down, flat, isNew }

/// A headline tile's change versus the previous period, already formatted.
class PeriodDelta {
  const PeriodDelta({required this.label, required this.direction});

  final String label;
  final DeltaDirection direction;
}

/// Compares a headline number to its previous-period figure.
///
/// Null when both are zero — a metric nobody has touched in either period is
/// not a trend worth reporting. A previous figure of zero is reported as
/// "New" rather than a division by zero or a meaningless "+∞%".
@visibleForTesting
PeriodDelta? periodDelta(int current, int previous) {
  if (current == 0 && previous == 0) return null;
  if (previous == 0) {
    return const PeriodDelta(label: 'New', direction: DeltaDirection.isNew);
  }

  final percent = ((current - previous) / previous * 100).round();
  if (percent == 0) {
    return const PeriodDelta(label: '±0%', direction: DeltaDirection.flat);
  }
  final sign = percent > 0 ? '+' : '';
  return PeriodDelta(
    label: '$sign$percent%',
    direction: percent > 0 ? DeltaDirection.up : DeltaDirection.down,
  );
}

/// Which area of the app a `feature` metric key belongs to, so "Features
/// used" reads as a handful of groups instead of one flat list mixing
/// home-menu taps, zikr actions, prayer settings, account changes and search.
///
/// [other] is the safety net: a feature key nothing below recognises still
/// renders, just outside any named group, rather than silently vanishing from
/// the ranking the way an unhandled key would in a `switch` with no default.
enum FeatureGroup {
  zikrReading(
    'Zikr & library reading',
    'Bookmarks, sharing, audio, fonts and where the open came from',
  ),
  navigation('Home menu', 'Which home-screen tile people tap'),
  prayerAndAzaan(
    'Prayer & azaan',
    'Azaan choice, notifications, rakaat counting, prayer times shown and '
        'the Qibla target',
  ),
  accountAndTools(
    'Account & tools',
    'Favorites, flights, the qaza tracker, sign-in and account deletion',
  ),
  search('Search', 'Reaching for search, and searches actually run'),
  other('Other', 'Not yet sorted into a group');

  const FeatureGroup(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

/// Feature keys with no shared prefix to match on, grouped by [FeatureGroup].
/// Keys under a shared prefix (`home_menu_*`, `zikr_source_*`) are matched in
/// [featureGroupFor] instead, so they don't need an entry here.
const Set<String> _zikrReadingFeatureKeys = {
  'zikr_counter_shown',
  'zikr_audio_opened',
  'zikr_audio_play',
  'zikr_bookmark_saved',
  'zikr_bookmark_removed',
  'zikr_shared',
  'zikr_keep_awake_toggled',
  'zikr_focus_mode_toggled',
  'zikr_share_as_image_toggled',
  'zikr_show_transliteration_toggled',
  'zikr_show_translation_toggled',
  'arabic_font_size_changed',
  'english_font_size_changed',
  'arabic_font_changed',
  'library_shared',
  'library_offline_saved',
  'library_offline_removed',
};

const Set<String> _prayerAndAzaanFeatureKeys = {
  'azaan_selected',
  'azaan_notifications_toggled',
  'azaan_opt_in',
  'rakaat_prayer_completed',
  'prayer_times_selection_changed',
  'qibla_target_changed',
};

const Set<String> _accountAndToolsFeatureKeys = {
  'account_deleted',
  'account_signed_in',
  'favorite_added',
  'favorite_removed',
  'favorite_reordered',
  'flight_added',
  'flight_edited',
  'qaza_updated',
  'tasbeeh_session',
};

const Set<String> _searchFeatureKeys = {'search', 'search_opened'};

/// See [FeatureGroup].
@visibleForTesting
FeatureGroup featureGroupFor(String key) {
  if (key.startsWith('home_menu_')) return FeatureGroup.navigation;
  if (key.startsWith('zikr_source_') || _zikrReadingFeatureKeys.contains(key)) {
    return FeatureGroup.zikrReading;
  }
  if (_prayerAndAzaanFeatureKeys.contains(key)) {
    return FeatureGroup.prayerAndAzaan;
  }
  if (_accountAndToolsFeatureKeys.contains(key)) {
    return FeatureGroup.accountAndTools;
  }
  if (_searchFeatureKeys.contains(key)) return FeatureGroup.search;
  return FeatureGroup.other;
}

/// Splits already-ranked `feature` rows into their [FeatureGroup]s, each list
/// keeping the overall rank order. A group with nothing in it is left out of
/// the map entirely, so callers can render "one section per present key"
/// without an extra emptiness check.
@visibleForTesting
Map<FeatureGroup, List<UsageRow>> groupFeatureRows(List<UsageRow> rows) {
  final grouped = <FeatureGroup, List<UsageRow>>{};
  for (final row in rows) {
    grouped.putIfAbsent(featureGroupFor(row.key), () => []).add(row);
  }
  return grouped;
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
({Map<String, Map<String, int>> counts, Map<String, int> trend}) parseUsageDays(
    Object? value, List<String> wantedDays) {
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
  static final NumberFormat _percentFormat =
      NumberFormat.decimalPercentPattern(decimalDigits: 0);

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

    // Started together, not awaited in sequence: the three reads are
    // independent, so there is no reason to pay their latency one after
    // another.
    //
    // Day keys are ISO dates, so they sort lexicographically and the range can
    // be pushed to the server. Reading the whole tree and filtering here would
    // download every retained day — up to 400 of them — to show thirty.
    final daysFuture = FirebaseDatabase.instance
        .ref('usage/daily')
        .orderByKey()
        .startAt(wanted.first)
        .endAt(wanted.last)
        .get();
    final labelsFuture = _loadLabels();
    final previousFuture =
        _loadPreviousPeriodTotals(days, before: wanted.first);

    final snapshot = await daysFuture;
    final labels = await labelsFuture;
    final previous = await previousFuture;

    final parsed = parseUsageDays(snapshot.value, wanted);
    return _toSnapshot(
      parsed.counts,
      labels,
      wanted.map((day) => MapEntry(day, parsed.trend[day] ?? 0)).toList(),
      previous: previous,
    );
  }

  /// The equal-length window immediately before [before], read the same way
  /// [_loadDays] reads its own window — day keys sort lexicographically, so
  /// this still pushes the range to the server instead of scanning history.
  Future<PreviousPeriodTotals> _loadPreviousPeriodTotals(
    int days, {
    required String before,
  }) async {
    final beforeDate = _dayFormat.parse(before);
    final wanted = List.generate(
      days,
      (offset) =>
          _dayFormat.format(beforeDate.subtract(Duration(days: offset + 1))),
    ).reversed.toList();

    final snapshot = await FirebaseDatabase.instance
        .ref('usage/daily')
        .orderByKey()
        .startAt(wanted.first)
        .endAt(wanted.last)
        .get();
    return previousTotalsFrom(parseUsageDays(snapshot.value, wanted).counts);
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
    List<MapEntry<String, int>> trend, {
    PreviousPeriodTotals? previous,
  }) {
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
    return UsageSnapshot(metrics: metrics, trend: trend, previous: previous);
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
                    percentFormat: _percentFormat,
                  ),
                  _FeatureUsageSections(
                    rows: data.rowsFor(AnalyticsService.metricFeature),
                    countFormat: _countFormat,
                    percentFormat: _percentFormat,
                  ),
                  _UsageSection(
                    title: 'Screens',
                    rows: data.rowsFor(AnalyticsService.metricScreen),
                    countFormat: _countFormat,
                    percentFormat: _percentFormat,
                  ),
                  _UsageSection(
                    title: 'Library',
                    subtitle: 'Chapters opened, by book',
                    rows: data.rowsFor(AnalyticsService.metricLibrary),
                    countFormat: _countFormat,
                    percentFormat: _percentFormat,
                  ),
                  _UsageSection(
                    title: 'Live streams',
                    rows: data.rowsFor(AnalyticsService.metricStream),
                    countFormat: _countFormat,
                    percentFormat: _percentFormat,
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
    final zikrRows = _zikrRows(data);
    final zikrOpens = zikrRows.fold<int>(0, (sum, r) => sum + r.count);
    final distinctZikrs = zikrRows.length;
    final featureUses = data.totalFor(AnalyticsService.metricFeature);
    final previous = data.previous;
    final previousCaption = _range.previousPeriodLabel;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Zikr opens',
            value: _countFormat.format(zikrOpens),
            delta: previous == null
                ? null
                : periodDelta(zikrOpens, previous.zikrOpens),
            deltaCaption: previousCaption,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Distinct zikrs',
            value: _countFormat.format(distinctZikrs),
            delta: previous == null
                ? null
                : periodDelta(distinctZikrs, previous.distinctZikrs),
            deltaCaption: previousCaption,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Feature uses',
            value: _countFormat.format(featureUses),
            delta: previous == null
                ? null
                : periodDelta(featureUses, previous.featureUses),
            deltaCaption: previousCaption,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.delta,
    this.deltaCaption,
  });

  final String label;
  final String value;

  /// Change versus the previous equal-length period. Null when that period
  /// doesn't apply (All time) or when both periods are zero.
  final PeriodDelta? delta;

  /// What [delta] is measured against, e.g. "the previous 7 days" — shown in
  /// a tooltip so the tile itself stays a single short line.
  final String? deltaCaption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = this.delta;
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
            if (delta != null) ...[
              const SizedBox(height: 4),
              Tooltip(
                message: deltaCaption == null ? '' : 'vs $deltaCaption',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconFor(delta.direction),
                      size: 14,
                      color: _colorFor(delta.direction, theme),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      delta.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _colorFor(delta.direction, theme),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(DeltaDirection direction) => switch (direction) {
        DeltaDirection.up || DeltaDirection.isNew => Icons.arrow_upward,
        DeltaDirection.down => Icons.arrow_downward,
        DeltaDirection.flat => Icons.remove,
      };

  Color _colorFor(DeltaDirection direction, ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    return switch (direction) {
      DeltaDirection.up ||
      DeltaDirection.isNew =>
        dark ? Colors.green.shade300 : Colors.green.shade700,
      DeltaDirection.down => theme.colorScheme.error,
      DeltaDirection.flat => theme.colorScheme.onSurfaceVariant,
    };
  }
}

/// Ranked list with a proportional bar, so the shape of the distribution reads
/// at a glance instead of having to compare numbers.
class _UsageSection extends StatefulWidget {
  const _UsageSection({
    required this.title,
    required this.rows,
    required this.countFormat,
    required this.percentFormat,
    this.subtitle,
    this.dense = false,
  });

  static const int _collapsedRowCount = 10;

  final String title;
  final String? subtitle;
  final List<UsageRow> rows;
  final NumberFormat countFormat;
  final NumberFormat percentFormat;

  /// True for a subsection nested under a group heading (see
  /// [_FeatureUsageSections]): a smaller title and no extra top margin, since
  /// the group heading above it already carries both.
  final bool dense;

  @override
  State<_UsageSection> createState() => _UsageSectionState();
}

class _UsageSectionState extends State<_UsageSection> {
  // Whether every row beyond the top ten is showing — independent of
  // [_sectionCollapsed], which hides the section's rows entirely.
  bool _expanded = false;

  // Starts open: collapsing is something the admin opts into per section, not
  // a default that would hide numbers nobody asked to hide.
  bool _sectionCollapsed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final max = widget.rows.first.count;
    final total = widget.rows.fold<int>(0, (sum, row) => sum + row.count);
    final visible = _expanded
        ? widget.rows
        : widget.rows.take(_UsageSection._collapsedRowCount).toList();
    final hidden = widget.rows.length - visible.length;

    return Padding(
      padding: EdgeInsets.only(top: widget.dense ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _sectionCollapsed = !_sectionCollapsed),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: widget.dense
                            ? theme.textTheme.titleSmall
                            : theme.textTheme.titleMedium,
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_sectionCollapsed) ...[
                  Text(
                    widget.countFormat.format(total),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  _sectionCollapsed ? Icons.expand_more : Icons.expand_less,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          if (!_sectionCollapsed) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < visible.length; i++)
              _UsageBar(
                rank: i + 1,
                row: visible[i],
                fraction: max == 0 ? 0 : visible[i].count / max,
                percentOfTotal: total == 0 ? 0 : visible[i].count / total,
                countFormat: widget.countFormat,
                percentFormat: widget.percentFormat,
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
        ],
      ),
    );
  }
}

/// "Features used", broken into its [FeatureGroup]s. A group with no rows for
/// the current range is left out entirely rather than shown empty.
class _FeatureUsageSections extends StatelessWidget {
  const _FeatureUsageSections({
    required this.rows,
    required this.countFormat,
    required this.percentFormat,
  });

  final List<UsageRow> rows;
  final NumberFormat countFormat;
  final NumberFormat percentFormat;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final grouped = groupFeatureRows(rows);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Features used', style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            'Actions taken, not just screens opened, grouped by area of the '
            'app',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final group in FeatureGroup.values)
            if (grouped[group] case final groupRows? when groupRows.isNotEmpty)
              _UsageSection(
                title: group.title,
                subtitle: group.subtitle,
                rows: groupRows,
                countFormat: countFormat,
                percentFormat: percentFormat,
                dense: true,
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
    required this.percentOfTotal,
    required this.countFormat,
    required this.percentFormat,
  });

  final int rank;
  final UsageRow row;

  /// Share of the section's top row, for the proportional bar.
  final double fraction;

  /// Share of the section's total, shown next to the count.
  final double percentOfTotal;

  final NumberFormat countFormat;
  final NumberFormat percentFormat;

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
              const SizedBox(width: 4),
              Text(
                '(${percentFormat.format(percentOfTotal)})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
