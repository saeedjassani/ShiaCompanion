import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../services/analytics_service.dart';
import '../../widgets/responsive_content.dart';
import 'usage_charts.dart';

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
    this.metricTrend = const {},
    this.previous,
    this.previousCounts,
  });

  static const UsageSnapshot empty =
      UsageSnapshot(metrics: {}, trend: <MapEntry<String, int>>[]);

  /// metric name -> rows, already sorted with the biggest first.
  final Map<String, List<UsageRow>> metrics;

  /// Day -> total events, oldest first. Empty for the all-time view, which has
  /// no days to plot.
  final List<MapEntry<String, int>> trend;

  /// metric -> (day, count), oldest first, same day range as [trend]. Only
  /// carries metrics that had at least one event in the range; empty for the
  /// all-time view.
  final Map<String, List<MapEntry<String, int>>> metricTrend;

  /// The equal-length period immediately before this one, for the headline
  /// tiles' delta. Null for All time, which has nothing to compare against.
  final PreviousPeriodTotals? previous;

  /// Raw metric -> key -> count for that same previous period, so every
  /// section and row can show its own change % rather than just the three
  /// headline numbers. Null for All time.
  final Map<String, Map<String, int>>? previousCounts;

  List<UsageRow> rowsFor(String metric) => metrics[metric] ?? const [];

  int totalFor(String metric) =>
      rowsFor(metric).fold<int>(0, (sum, row) => sum + row.count);

  /// Sum of the previous period's counts for [metric]. Null when there is no
  /// previous period (All time); zero is a real "nothing happened" value.
  int? previousTotalFor(String metric) {
    final counts = previousCounts;
    if (counts == null) return null;
    return (counts[metric] ?? const {})
        .values
        .fold<int>(0, (sum, count) => sum + count);
  }

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
/// used" reads as a handful of groups instead of one flat list.
///
/// Grouped by what someone was *doing*, not by which screen the action
/// happened to fire from — "how did they get to this zikr" and "did they
/// search" are both wayfinding, whether the tap was on the home screen, in
/// search, or via a deep link, so they share [findingContent] rather than
/// splitting into a "Home menu" group and a separate "Search" group each too
/// thin to read as its own trend. Likewise the qaza tracker, the tasbeeh
/// counter and flight-aware prayer times are worship tools first, so they
/// sit in [prayerAndWorship] rather than the old catch-all "Account & tools".
///
/// [other] is the safety net: a feature key nothing below recognises still
/// renders, just outside any named group, rather than silently vanishing from
/// the ranking the way an unhandled key would in a `switch` with no default.
enum FeatureGroup {
  readingContent(
    'Reading the content',
    'Bookmarks, sharing, audio, fonts, reminders, and translation/'
        'transliteration toggles while reading a zikr, a library chapter, or '
        'the Quran',
  ),
  findingContent(
    'Finding content',
    'Home-screen taps, search, and how a zikr was reached — a deep link, a '
        'widget, or search itself',
  ),
  prayerAndWorship(
    'Prayer & worship tools',
    'Azaan (including its notification sound), rakaat counting, prayer '
        'times (including while flying), the Qibla target, the qaza tracker '
        'and the tasbeeh counter',
  ),
  personalizationAndAccount(
    'Personalization & account',
    'Favorites, dark mode, sign-in and account deletion',
  ),
  feedbackAndRatings(
    'Feedback & ratings',
    'App-store rating prompts and the feedback email',
  ),
  other('Other', 'Not yet sorted into a group');

  const FeatureGroup(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

/// Feature keys with no shared prefix to match on, grouped by [FeatureGroup].
/// Keys under a shared prefix (`home_menu_*`, `zikr_source_*`) are matched in
/// [featureGroupFor] instead, so they don't need an entry here.
const Set<String> _readingContentFeatureKeys = {
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
  'zikr_show_arabic_as_paragraph_toggled',
  'arabic_font_size_changed',
  'english_font_size_changed',
  'arabic_font_changed',
  'library_shared',
  'library_offline_saved',
  'library_offline_removed',
  // Reminders to read a zikr, and the Quran recitation tracker — both are
  // ongoing-engagement tools for content someone is already reading, not
  // account settings or worship-tool configuration.
  'zikr_reminder_added',
  'zikr_reminder_edited',
  'zikr_reminder_deleted',
  'zikr_reminder_entry_point_opened',
  'quran_verse_saved',
  'quran_verse_unsaved',
  'recitation_tracker_updated',
};

const Set<String> _findingContentFeatureKeys = {'search', 'search_opened'};

const Set<String> _prayerAndWorshipFeatureKeys = {
  'azaan_selected',
  'azaan_notifications_toggled',
  'azaan_opt_in',
  'prayer_sound_set',
  'rakaat_prayer_completed',
  'prayer_times_selection_changed',
  'qibla_target_changed',
  'qaza_updated',
  'tasbeeh_session',
  'flight_added',
  'flight_edited',
};

const Set<String> _personalizationAndAccountFeatureKeys = {
  'account_deleted',
  'account_signed_in',
  'favorite_added',
  'favorite_removed',
  'favorite_reordered',
  'dark_mode_toggled',
};

const Set<String> _feedbackAndRatingsFeatureKeys = {
  'rating_prompt',
  'rating_prompt_feedback',
  'rate_us_settings',
  'feedback_email_opened',
};

/// See [FeatureGroup].
@visibleForTesting
FeatureGroup featureGroupFor(String key) {
  if (key.startsWith('home_menu_') ||
      key.startsWith('zikr_source_') ||
      _findingContentFeatureKeys.contains(key)) {
    return FeatureGroup.findingContent;
  }
  if (_readingContentFeatureKeys.contains(key)) {
    return FeatureGroup.readingContent;
  }
  if (_prayerAndWorshipFeatureKeys.contains(key)) {
    return FeatureGroup.prayerAndWorship;
  }
  if (_personalizationAndAccountFeatureKeys.contains(key)) {
    return FeatureGroup.personalizationAndAccount;
  }
  if (_feedbackAndRatingsFeatureKeys.contains(key)) {
    return FeatureGroup.feedbackAndRatings;
  }
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

/// Splits already-ranked `feature` rows into their [FeatureGroup]s' totals
/// for the *previous* period, so each group's section header and the share
/// bar can show a change % without re-deriving it from the raw counts
/// themselves. Mirrors [groupFeatureRows], but on plain counts rather than
/// ranked [UsageRow]s since the previous period is never itself displayed as
/// a ranking.
@visibleForTesting
Map<FeatureGroup, int> groupPreviousTotals(Map<String, int>? previousByKey) {
  if (previousByKey == null) return const {};
  final totals = <FeatureGroup, int>{};
  previousByKey.forEach((key, count) {
    final group = featureGroupFor(key);
    totals[group] = (totals[group] ?? 0) + count;
  });
  return totals;
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
/// [wantedDays] and folding every metric's counters into the per-metric
/// totals, the day-by-day trend, and each metric's own day-by-day trend (for
/// the "activity by area" chart). See [parseUsageTotals] for why `count` is
/// checked against `num` rather than `int`.
@visibleForTesting
({
  Map<String, Map<String, int>> counts,
  Map<String, int> trend,
  Map<String, Map<String, int>> metricTrend,
}) parseUsageDays(Object? value, List<String> wantedDays) {
  final counts = <String, Map<String, int>>{};
  final trend = <String, int>{for (final day in wantedDays) day: 0};
  final metricTrend = <String, Map<String, int>>{};

  if (value is Map) {
    value.forEach((rawDay, metrics) {
      final day = '$rawDay';
      if (!trend.containsKey(day) || metrics is! Map) return;
      metrics.forEach((metric, keys) {
        if (keys is! Map) return;
        final metricKey = '$metric';
        final bucket = counts.putIfAbsent(metricKey, () => <String, int>{});
        final dayBucket = metricTrend.putIfAbsent(
          metricKey,
          () => {for (final d in wantedDays) d: 0},
        );
        keys.forEach((key, count) {
          if (count is! num) return;
          final value = count.toInt();
          bucket['$key'] = (bucket['$key'] ?? 0) + value;
          trend[day] = (trend[day] ?? 0) + value;
          dayBucket[day] = (dayBucket[day] ?? 0) + value;
        });
      });
    });
  }
  return (counts: counts, trend: trend, metricTrend: metricTrend);
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

/// The previous period's zikr *open* counts, keyed the same way
/// [splitZikrCompletions] keys its rows (by uid, completions stripped out) —
/// so a zikr row's change % compares opens against opens, never against a
/// mix that includes completions.
@visibleForTesting
Map<String, int> zikrPreviousByKey(
    Map<String, Map<String, int>>? previousCounts) {
  final raw = previousCounts?[AnalyticsService.metricZikr] ?? const {};
  final byKey = <String, int>{};
  raw.forEach((key, count) {
    if (!key.endsWith(zikrCompletionSuffix)) byKey[key] = count;
  });
  return byKey;
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
    final previousCountsFuture =
        _loadPreviousPeriod(days, before: wanted.first);

    final snapshot = await daysFuture;
    final labels = await labelsFuture;
    final previousCounts = await previousCountsFuture;

    final parsed = parseUsageDays(snapshot.value, wanted);
    return _toSnapshot(
      parsed.counts,
      labels,
      wanted.map((day) => MapEntry(day, parsed.trend[day] ?? 0)).toList(),
      metricTrend: {
        for (final entry in parsed.metricTrend.entries)
          entry.key: wanted
              .map((day) => MapEntry(day, entry.value[day] ?? 0))
              .toList(),
      },
      previous: previousTotalsFrom(previousCounts),
      previousCounts: previousCounts,
    );
  }

  /// The equal-length window immediately before [before]'s raw per-metric,
  /// per-key counts, read the same way [_loadDays] reads its own window — day
  /// keys sort lexicographically, so this still pushes the range to the
  /// server instead of scanning history. Reused for the headline tiles' delta
  /// (via [previousTotalsFrom]) and for every section's and row's change %.
  Future<Map<String, Map<String, int>>> _loadPreviousPeriod(
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
    return parseUsageDays(snapshot.value, wanted).counts;
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
    Map<String, List<MapEntry<String, int>>> metricTrend = const {},
    PreviousPeriodTotals? previous,
    Map<String, Map<String, int>>? previousCounts,
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
    return UsageSnapshot(
      metrics: metrics,
      trend: trend,
      metricTrend: metricTrend,
      previous: previous,
      previousCounts: previousCounts,
    );
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
    final theme = Theme.of(context);
    final previousCaption = _range.previousPeriodLabel;
    // Null, not an empty map, when there's no previous period at all (All
    // time) — zikrPreviousByKey on its own can't tell "no previous period"
    // apart from "previous period had zero zikr activity", since both parse
    // to {}.
    final zikrPrevious = data.previousCounts == null
        ? null
        : zikrPreviousByKey(data.previousCounts);

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
                  if (data.trend.length > 1) ...[
                    const SizedBox(height: 28),
                    TrendAreaChart(
                      title: 'Events per day',
                      trend: data.trend,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                  if (data.metricTrend.length > 1) ...[
                    const SizedBox(height: 28),
                    MetricTrendChart(series: _metricSeries(context, data)),
                  ],
                  const SizedBox(height: 8),
                  _UsageSection(
                    title: 'Most opened zikrs',
                    subtitle: 'Aliases counted with the zikr they point at',
                    rows: _zikrRows(data),
                    countFormat: _countFormat,
                    percentFormat: _percentFormat,
                    previousTotal: data.previous?.zikrOpens,
                    previousByKey: zikrPrevious,
                    previousCaption: previousCaption,
                  ),
                  _FeatureUsageSections(
                    rows: data.rowsFor(AnalyticsService.metricFeature),
                    countFormat: _countFormat,
                    percentFormat: _percentFormat,
                    previousByKey:
                        data.previousCounts?[AnalyticsService.metricFeature],
                    previousCaption: previousCaption,
                  ),
                  _UsageSection(
                    title: 'Screens',
                    rows: data.rowsFor(AnalyticsService.metricScreen),
                    countFormat: _countFormat,
                    percentFormat: _percentFormat,
                    previousTotal:
                        data.previousTotalFor(AnalyticsService.metricScreen),
                    previousByKey:
                        data.previousCounts?[AnalyticsService.metricScreen],
                    previousCaption: previousCaption,
                  ),
                  _UsageSection(
                    title: 'Library',
                    subtitle: 'Chapters opened, by book',
                    rows: data.rowsFor(AnalyticsService.metricLibrary),
                    countFormat: _countFormat,
                    percentFormat: _percentFormat,
                    previousTotal:
                        data.previousTotalFor(AnalyticsService.metricLibrary),
                    previousByKey:
                        data.previousCounts?[AnalyticsService.metricLibrary],
                    previousCaption: previousCaption,
                  ),
                  _UsageSection(
                    title: 'Live streams',
                    rows: data.rowsFor(AnalyticsService.metricStream),
                    countFormat: _countFormat,
                    percentFormat: _percentFormat,
                    previousTotal:
                        data.previousTotalFor(AnalyticsService.metricStream),
                    previousByKey:
                        data.previousCounts?[AnalyticsService.metricStream],
                    previousCaption: previousCaption,
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

  /// One fixed-color line per metric that had activity in the range, in a
  /// stable order so a metric's color never shifts as the range changes.
  static const List<String> _metricOrder = [
    AnalyticsService.metricZikr,
    AnalyticsService.metricScreen,
    AnalyticsService.metricFeature,
    AnalyticsService.metricLibrary,
    AnalyticsService.metricStream,
  ];

  static const Map<String, String> _metricLabels = {
    AnalyticsService.metricZikr: 'Zikr',
    AnalyticsService.metricScreen: 'Screens',
    AnalyticsService.metricFeature: 'Features',
    AnalyticsService.metricLibrary: 'Library',
    AnalyticsService.metricStream: 'Streams',
  };

  List<UsageMetricSeries> _metricSeries(
      BuildContext context, UsageSnapshot data) {
    final brightness = Theme.of(context).brightness;
    return [
      for (var i = 0; i < _metricOrder.length; i++)
        if (data.metricTrend[_metricOrder[i]] case final points?)
          UsageMetricSeries(
            label: _metricLabels[_metricOrder[i]]!,
            color: categoricalColor(i, brightness),
            points: points,
          ),
    ];
  }

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
    final screenViews = data.totalFor(AnalyticsService.metricScreen);
    final libraryOpens = data.totalFor(AnalyticsService.metricLibrary);
    final previous = data.previous;
    final previousCaption = _range.previousPeriodLabel;
    final previousScreens =
        data.previousTotalFor(AnalyticsService.metricScreen);
    final previousLibrary =
        data.previousTotalFor(AnalyticsService.metricLibrary);

    final tiles = [
      _StatTile(
        label: 'Zikr opens',
        value: _countFormat.format(zikrOpens),
        delta: previous == null
            ? null
            : periodDelta(zikrOpens, previous.zikrOpens),
        deltaCaption: previousCaption,
      ),
      _StatTile(
        label: 'Distinct zikrs',
        value: _countFormat.format(distinctZikrs),
        delta: previous == null
            ? null
            : periodDelta(distinctZikrs, previous.distinctZikrs),
        deltaCaption: previousCaption,
      ),
      _StatTile(
        label: 'Feature uses',
        value: _countFormat.format(featureUses),
        delta: previous == null
            ? null
            : periodDelta(featureUses, previous.featureUses),
        deltaCaption: previousCaption,
      ),
      _StatTile(
        label: 'Screens viewed',
        value: _countFormat.format(screenViews),
        delta: previousScreens == null
            ? null
            : periodDelta(screenViews, previousScreens),
        deltaCaption: previousCaption,
      ),
      _StatTile(
        label: 'Library opens',
        value: _countFormat.format(libraryOpens),
        delta: previousLibrary == null
            ? null
            : periodDelta(libraryOpens, previousLibrary),
        deltaCaption: previousCaption,
      ),
    ];

    // A Wrap rather than a fixed-column GridView: each tile keeps its own
    // intrinsic height (the delta row makes some tiles taller than others),
    // and a 4th/5th tile simply wraps to a new row at the same width.
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const columns = 3;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
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
              _DeltaChip(delta: delta, caption: deltaCaption),
            ],
          ],
        ),
      ),
    );
  }
}

/// Which arrow and color a [PeriodDelta] gets — shared by the headline
/// tiles, section header totals, and individual ranked rows, so "up" always
/// looks the same wherever it appears on the dashboard.
IconData _deltaIcon(DeltaDirection direction) => switch (direction) {
      DeltaDirection.up || DeltaDirection.isNew => Icons.arrow_upward,
      DeltaDirection.down => Icons.arrow_downward,
      DeltaDirection.flat => Icons.remove,
    };

Color _deltaColor(DeltaDirection direction, ThemeData theme) {
  final dark = theme.brightness == Brightness.dark;
  return switch (direction) {
    DeltaDirection.up ||
    DeltaDirection.isNew =>
      dark ? Colors.green.shade300 : Colors.green.shade700,
    DeltaDirection.down => theme.colorScheme.error,
    DeltaDirection.flat => theme.colorScheme.onSurfaceVariant,
  };
}

/// A small "+12%"-style chip for a [PeriodDelta]. Reused by the headline
/// tiles (normal size, with a tooltip naming the comparison period), each
/// section's header total, and individual ranked rows (dense, no tooltip —
/// a row is busy enough already).
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta, this.caption, this.dense = false});

  final PeriodDelta delta;
  final String? caption;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _deltaColor(delta.direction, theme);
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_deltaIcon(delta.direction), size: dense ? 12 : 14, color: color),
        const SizedBox(width: 2),
        Text(
          delta.label,
          style:
              (dense ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
    if (caption == null || caption!.isEmpty) return chip;
    return Tooltip(message: 'vs $caption', child: chip);
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
    this.accentColor,
    this.previousTotal,
    this.previousByKey,
    this.previousCaption,
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

  /// This group's fixed slot in the categorical palette — the same color as
  /// its swatch in the share bar above, so a group reads as one visual
  /// identity wherever it shows up. Only ever set on a [dense] group section;
  /// null renders the plain (no card, default-colored bars) look the
  /// top-level sections use.
  final Color? accentColor;

  /// The previous equal-length period's total for this section, for the
  /// header's change % chip. Null when there's no previous period (All time)
  /// or the caller has nothing to compare (e.g. a nested feature group with
  /// no previous-period breakdown).
  final int? previousTotal;

  /// The previous period's count for each row's key, for that row's own
  /// change % chip. A key absent from this map means zero for that period —
  /// the RTDB counters it comes from are only ever incremented, so "never
  /// written" and "zero" are the same state — which shows as "New" rather
  /// than being silently skipped. Null (as opposed to an empty map) means
  /// there is no previous period at all (All time), so no row gets a chip.
  final Map<String, int>? previousByKey;

  /// What [previousTotal]/[previousByKey] are measured against, e.g. "the
  /// previous 7 days".
  final String? previousCaption;

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
    final sectionDelta = widget.previousTotal == null
        ? null
        : periodDelta(total, widget.previousTotal!);
    final accent = widget.accentColor;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _sectionCollapsed = !_sectionCollapsed),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (accent != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 8),
              ],
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
              if (sectionDelta != null) ...[
                _DeltaChip(
                    delta: sectionDelta, caption: widget.previousCaption),
                const SizedBox(width: 8),
              ],
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
              accentColor: accent,
              delta: widget.previousByKey == null
                  ? null
                  : periodDelta(visible[i].count,
                      widget.previousByKey![visible[i].key] ?? 0),
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
    );

    // A group section gets its own tinted card, in its fixed accent color, so
    // "Features used" reads as a row of distinct panels rather than one long
    // list with subheadings. Top-level sections (accent == null) keep the
    // plain look — they aren't part of a group of siblings that need telling
    // apart.
    if (accent == null) {
      return Padding(
        padding: EdgeInsets.only(top: widget.dense ? 16 : 24),
        child: content,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: content,
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
    this.previousByKey,
    this.previousCaption,
  });

  final List<UsageRow> rows;
  final NumberFormat countFormat;
  final NumberFormat percentFormat;

  /// The previous period's raw feature counts (metric-level, not yet split
  /// by group) — see [_UsageSection.previousByKey].
  final Map<String, int>? previousByKey;
  final String? previousCaption;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final grouped = groupFeatureRows(rows);
    final previousTotals = groupPreviousTotals(previousByKey);
    final brightness = theme.brightness;

    final shareSegments = [
      for (final group in FeatureGroup.values)
        if (grouped[group] case final groupRows? when groupRows.isNotEmpty)
          ShareSegment(
            label: group.title,
            value: groupRows.fold<int>(0, (sum, r) => sum + r.count),
            color: categoricalColor(
                FeatureGroup.values.indexOf(group), brightness),
          ),
    ];

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
          if (shareSegments.length > 1) ...[
            const SizedBox(height: 16),
            ShareBar(segments: shareSegments),
          ],
          for (final group in FeatureGroup.values)
            if (grouped[group] case final groupRows? when groupRows.isNotEmpty)
              _UsageSection(
                title: group.title,
                subtitle: group.subtitle,
                rows: groupRows,
                countFormat: countFormat,
                percentFormat: percentFormat,
                dense: true,
                accentColor: categoricalColor(
                    FeatureGroup.values.indexOf(group), brightness),
                previousTotal:
                    previousByKey == null ? null : previousTotals[group] ?? 0,
                previousByKey: previousByKey,
                previousCaption: previousCaption,
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
    this.accentColor,
    this.delta,
  });

  final int rank;
  final UsageRow row;

  /// Share of the section's top row, for the proportional bar.
  final double fraction;

  /// Share of the section's total, shown next to the count.
  final double percentOfTotal;

  final NumberFormat countFormat;
  final NumberFormat percentFormat;

  /// The bar's own color, when this row belongs to a group with a fixed
  /// identity color (see [_UsageSection.accentColor]). Null keeps the
  /// default primary-colored bar the top-level sections use.
  final Color? accentColor;

  /// This row's own change % versus the previous equal-length period. Null
  /// when there's no previous period to compare (All time).
  final PeriodDelta? delta;

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
              if (delta != null) ...[
                const SizedBox(width: 6),
                _DeltaChip(delta: delta!, dense: true),
              ],
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
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
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
