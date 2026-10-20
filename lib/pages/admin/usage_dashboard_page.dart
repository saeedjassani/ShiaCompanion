import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../services/analytics_service.dart';
import '../../theme/shia_colors.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import 'usage_cards.dart';
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
  const UsageRow({
    required this.key,
    required this.label,
    required this.count,
    this.note,
  });

  final String key;
  final String label;
  final int count;

  /// A line under the label: how many of a zikr's opens were read to the
  /// end.
  final String? note;
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
      .where((entry) => _isZikrOpenKey(entry.key));
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
/// happened to fire from — a home-screen tap and a search are both
/// wayfinding, so they share [findingContent] rather than splitting into a
/// "Home menu" group and a separate "Search" group each too thin to read as
/// its own trend. Where a zikr open came from (`zikr_source_*`) is not in
/// any group: it is the zikr open itself, recorded a second time, so it
/// gets its own section (see [zikrSourceMetric]). Likewise the qaza tracker, the tasbeeh
/// counter and flight-aware prayer times are worship tools first, so they
/// sit in [prayerAndWorship] rather than the old catch-all "Account & tools".
///
/// [other] is the safety net: a feature key nothing below recognises still
/// renders, just outside any named group, rather than silently vanishing from
/// the ranking the way an unhandled key would in a `switch` with no default.
enum FeatureGroup {
  readingContent(
    'Reading the content',
    'Bookmarks, sharing, audio (including downloads and playlists), fonts, '
        'reminders, auto-scroll, Quran notes and the recitation tracker, and '
        'translation/transliteration toggles while reading a zikr, a library '
        'chapter, or the Quran',
  ),
  findingContent(
    'Finding content',
    'Home-screen taps, search and Quran listen-and-follow. Where each zikr '
        'open came from has its own section above',
  ),
  prayerAndWorship(
    'Prayer & worship tools',
    'Azaan (including its notification sound), rakaat counting, prayer '
        'times (including while flying), the Qibla target, the qaza tracker '
        'and the tasbeeh counter',
  ),
  personalizationAndAccount(
    'Personalization & account',
    'Favorites, theme, app text size, app and translation language, sign-in '
        'and account deletion',
  ),
  feedbackAndRatings(
    'Feedback & ratings',
    'App-store rating prompts and links, the feedback email, mistake '
        'reports, and content and translation requests (including admins '
        'resolving them)',
  ),
  other('Other', 'Not yet sorted into a group');

  const FeatureGroup(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

/// Feature keys with no shared prefix to match on, grouped by [FeatureGroup].
/// `home_menu_*` keys are matched by prefix in [featureGroupFor] instead, so
/// they don't need an entry here.
const Set<String> _readingContentFeatureKeys = {
  'zikr_counter_shown',
  'zikr_audio_opened',
  'zikr_audio_play',
  'zikr_audio_download',
  'zikr_playlist_play',
  'zikr_playlist_track_play',
  'zikr_bookmark_saved',
  'zikr_bookmark_removed',
  'zikr_bookmark_moved',
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
  'quran_note_added',
  'quran_note_edited',
  'quran_note_deleted',
  'recitation_track_added',
  'recitation_entry_removed',
  'recitation_track_settings_changed',
  'quran_tracking_hint_dismissed',
  'quran_surah_step',
  'quran_juz_step',
  // The end-of-surah offer to read Dua Khatm al-Quran.
  'quran_khatm_dua',
  'zikr_auto_scroll_started',
};

const Set<String> _findingContentFeatureKeys = {
  'search',
  'search_opened',
  // Finding a verse by listening to a recitation, and picking one of its
  // candidate matches.
  'quran_listen_and_follow',
  'quran_listen_and_follow_chosen',
};

const Set<String> _prayerAndWorshipFeatureKeys = {
  'azaan_selected',
  'azaan_notifications_toggled',
  'azaan_opt_in',
  'prayer_sound_set',
  'rakaat_prayer_completed',
  'prayer_times_selection_changed',
  // Choosing a city by name, and going back to the phone's location.
  'city_chosen',
  'device_location_chosen',
  // Looking up another city's times, and the Home card's "Still in X?".
  'city_times_viewed',
  'city_nudge_answered',
  'city_prompt_dismissed',
  // The fix-it button on the prayer card's location line.
  'location_status_action',
  // Historical only: the prayer notifications screen before its rebuild.
  'prayer_notifications_master_toggled',
  'prayer_notifications_sheet_saved',
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
  // The old Dark mode switch, kept for its history; replaced by the
  // three-way Theme setting.
  'dark_mode_toggled',
  'theme_mode_changed',
  'home_shortcuts_changed',
  'app_text_scale_changed',
  'app_language_changed',
  'translation_language_changed',
};

const Set<String> _feedbackAndRatingsFeatureKeys = {
  'rating_prompt',
  'rating_prompt_feedback',
  'rate_us_settings',
  'feedback_email_opened',
  'github_settings',
  // The web Home's "Get the app" store links.
  'home_get_app',
  'zikr_mistake_reported',
  'content_requested',
  'zikr_translation_requested',
  // Admins working through those reports and requests.
  'mistake_report_resolved',
  'mistake_report_reopened',
  'content_request_resolved',
  'content_request_reopened',
};

/// Feature keys the dashboard leaves out entirely. Each one is something the
/// app did on its own, or a copy of an action already counted under its own
/// key, so ranking it beside real choices would only pad the numbers. They
/// now go to GA4 only (`countOnDashboard: false`); this hides the counts
/// they built up before that.
const Set<String> _unrankedFeatureKeys = {
  // Every new install passes through first-run setup.
  'first_run_setup',
  // Fired with every share, bookmark and favorite, each counted already.
  'rating_positive_action',
  // A one-off migration of old Quran bookmarks.
  'quran_legacy_bookmark_retired',
  // Logged on every automatic save while scrolling the Quran.
  'recitation_tracker_updated',
};

/// Prefix [AnalyticsService.zikrView] puts on the feature counter it bumps
/// next to every zikr open.
const String zikrSourcePrefix = 'zikr_source_';

/// Not a database bucket: where the dashboard files the `zikr_source_*`
/// counters once it has taken them out of the feature metric. One of them
/// is bumped with every zikr open, so left among the features they made
/// each open count twice - once in "Zikr opens", again in "Feature uses",
/// and a third time with the Home tap that led to it inside "Finding
/// content".
const String zikrSourceMetric = 'zikr_source';

/// The dashboard metric a stored counter is shown under, or null for one it
/// leaves out (see [_unrankedFeatureKeys]).
String? _dashboardMetricFor(String metric, String key) {
  if (metric != AnalyticsService.metricFeature) return metric;
  if (key.startsWith(zikrSourcePrefix)) return zikrSourceMetric;
  if (_unrankedFeatureKeys.contains(key)) return null;
  return metric;
}

/// See [FeatureGroup].
@visibleForTesting
FeatureGroup featureGroupFor(String key) {
  if (key.startsWith('home_menu_') ||
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

/// Suffix [AnalyticsService.zikrPlaylistPlay] appends: a zikr played inside a
/// playlist, counted in the zikr metric but never as an open.
const String zikrPlaylistSuffix = '~playlist';

/// Whether a zikr-metric key is an open (a bare uid) rather than one of the
/// suffixed counters riding along in the same metric.
bool _isZikrOpenKey(String key) =>
    !key.endsWith(zikrCompletionSuffix) && !key.endsWith(zikrPlaylistSuffix);

/// Parses `usage/totals`'s raw snapshot value into metric -> key -> count,
/// with each counter filed under its dashboard metric (see
/// [_dashboardMetricFor]).
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
      keys.forEach((key, count) {
        if (count is! num) return;
        final shownAs = _dashboardMetricFor('$metric', '$key');
        if (shownAs == null) return;
        final bucket = counts.putIfAbsent(shownAs, () => <String, int>{});
        bucket['$key'] = (bucket['$key'] ?? 0) + count.toInt();
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
///
/// Counters are filed the way [parseUsageTotals] files them. The
/// [zikrSourceMetric] ones stay out of both trends, since each is a zikr
/// open the zikr metric already plotted.
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
        keys.forEach((key, count) {
          if (count is! num) return;
          final shownAs = _dashboardMetricFor('$metric', '$key');
          if (shownAs == null) return;
          final value = count.toInt();
          final bucket = counts.putIfAbsent(shownAs, () => <String, int>{});
          bucket['$key'] = (bucket['$key'] ?? 0) + value;
          if (shownAs == zikrSourceMetric) return;
          trend[day] = (trend[day] ?? 0) + value;
          final dayBucket = metricTrend.putIfAbsent(
            shownAs,
            () => {for (final d in wantedDays) d: 0},
          );
          dayBucket[day] = (dayBucket[day] ?? 0) + value;
        });
      });
    });
  }
  return (counts: counts, trend: trend, metricTrend: metricTrend);
}

/// Folds the completion counters back into the zikr they belong to, as its
/// [UsageRow.note], and drops the playlist-play counters (see
/// [zikrPlaylistRows]) so the result is opens only.
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

  return rows.where((row) => _isZikrOpenKey(row.key)).map((row) {
    final done = completions[row.key] ?? 0;
    return UsageRow(
      key: row.key,
      label: row.label,
      count: row.count,
      note: done > 0 && row.count > 0
          ? '$done finished · ${(done * 100 / row.count).round()}%'
          : null,
    );
  }).toList();
}

/// Every completion in the zikr metric: zikrs read to the end.
@visibleForTesting
int zikrCompletionTotal(Map<String, int>? zikrCounts) =>
    (zikrCounts ?? const {})
        .entries
        .where((entry) => entry.key.endsWith(zikrCompletionSuffix))
        .fold<int>(0, (sum, entry) => sum + entry.value);

/// Short names for the [zikrSourceMetric] rows, in the fixed order the
/// "How zikrs were opened" share bar colors them by. The recorded labels
/// ("Zikr opened from a category list") are written to stand alone in a
/// flat list; under a heading that already says "opened", the place is
/// enough. A key not listed keeps its recorded label and folds into the
/// share bar's "Other".
const Map<String, String> zikrSourceShortLabels = {
  'zikr_source_list': 'Category lists',
  'zikr_source_favorites': 'Favorites',
  'zikr_source_todays_recitation': "Today's Recitations",
  'zikr_source_search': 'Search',
  'zikr_source_deep_link': 'Shared links',
  'zikr_source_quran': 'Quran screen',
  'zikr_source_home_today': 'Today on Home',
  'zikr_source_quran_resume': 'Quran: carried on',
};

/// The rest, by name only.
const Map<String, String> _zikrSourceOtherLabels = {
  'zikr_source_zikr_link': 'A link inside another zikr',
  'zikr_source_home_continue': 'Continue on Home',
  'zikr_source_downloads': 'Downloaded recitations',
  'zikr_source_home_widget_recitation': "Today's Recitation widget",
  'zikr_source_home_widget_favorites': 'Favorites widget',
  'zikr_source_my_stats': 'My Stats',
  'zikr_source_zikr_reminder': 'A reminder notification',
  'zikr_source_playlist': 'A playlist',
  'zikr_source_library': 'The library',
  'zikr_source_admin': 'The admin list',
  'zikr_source_quran_listen_and_follow': 'Quran listen and follow',
  'zikr_source_unknown': 'Untagged',
};

/// [rows] of the zikr-source metric under their short names.
List<UsageRow> shortZikrSourceRows(List<UsageRow> rows) => [
      for (final row in rows)
        UsageRow(
          key: row.key,
          label: zikrSourceShortLabels[row.key] ??
              _zikrSourceOtherLabels[row.key] ??
              row.label,
          count: row.count,
        ),
    ];

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
    if (_isZikrOpenKey(key)) byKey[key] = count;
  });
  return byKey;
}

/// The zikr-metric rows counting plays inside a playlist, keyed by bare uid
/// and still in rank order, for their own "Played in playlists" ranking.
@visibleForTesting
List<UsageRow> zikrPlaylistRows(List<UsageRow> rows) => [
      for (final row in rows)
        if (row.key.endsWith(zikrPlaylistSuffix))
          UsageRow(
            key: row.key
                .substring(0, row.key.length - zikrPlaylistSuffix.length),
            label: row.label,
            count: row.count,
          ),
    ];

/// The previous period's playlist-play counts, keyed by bare uid the way
/// [zikrPlaylistRows] keys its rows.
@visibleForTesting
Map<String, int> zikrPlaylistPreviousByKey(
    Map<String, Map<String, int>>? previousCounts) {
  final raw = previousCounts?[AnalyticsService.metricZikr] ?? const {};
  return {
    for (final entry in raw.entries)
      if (entry.key.endsWith(zikrPlaylistSuffix))
        entry.key.substring(0, entry.key.length - zikrPlaylistSuffix.length):
            entry.value,
  };
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
    // Zikr sources are stored, labels and all, under the feature metric.
    final storedAs =
        metric == zikrSourceMetric ? AnalyticsService.metricFeature : metric;
    final recorded = labels['$storedAs/$key'];
    if (recorded != null && recorded.isNotEmpty) return recorded;
    if (metric == AnalyticsService.metricZikr) {
      final uid = key.endsWith(zikrPlaylistSuffix)
          ? key.substring(0, key.length - zikrPlaylistSuffix.length)
          : key;
      final title = items[uid]?.toString();
      if (title != null && title.isNotEmpty) return title;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return LargeTitlePage(
      maxWidth: widePageWidth,
      title: 'Usage',
      subtitle: 'How people use the app',
      actions: [
        RoundIconButton(
          icon: OutlineIcon(OutlineGlyph.reset, color: colors.accent),
          label: 'Refresh',
          onPressed: _reload,
        ),
      ],
      slivers: [
        SliverPadding(
          padding: pageGutter(context, maxWidth: widePageWidth)
              .copyWith(bottom: 32),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedSwitcher<UsageRange>(
                  segments: [
                    for (final range in UsageRange.values)
                      Segment(range, range.label),
                  ],
                  selected: _range,
                  onChanged: (range) => setState(() {
                    _range = range;
                    _snapshot = _load();
                  }),
                ),
                const SizedBox(height: 18),
                FutureBuilder<UsageSnapshot>(
                  future: _snapshot,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        height: 240,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return EmptyStateCard(
                        glyph: OutlineGlyph.alert,
                        title: 'Could not read usage',
                        body: '${snapshot.error}',
                        actionLabel: 'Retry',
                        onAction: _reload,
                      );
                    }
                    final data = snapshot.data ?? UsageSnapshot.empty;
                    if (data.isEmpty) {
                      return EmptyStateCard(
                        glyph: OutlineGlyph.stats,
                        title: 'No usage recorded for '
                            '${_range.label.toLowerCase()}',
                        body: 'Counters start filling once a release with '
                            "analytics is in people's hands. Debug builds "
                            'are excluded on purpose.',
                      );
                    }
                    return UsageOverview(data: data, range: _range);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The dashboard's content for one loaded [UsageSnapshot]: the headline
/// numbers, the activity chart, then a card per question - which zikrs, how
/// people reach them, whether search finds things, what they do in each
/// area of the app. A widget of its own so it renders in a test without a
/// database.
@visibleForTesting
class UsageOverview extends StatelessWidget {
  const UsageOverview({super.key, required this.data, required this.range});

  final UsageSnapshot data;
  final UsageRange range;

  @override
  Widget build(BuildContext context) {
    final previousCaption = range.previousPeriodLabel;
    final previous = data.previousCounts;
    final hasPrevious = previous != null;
    final brightness = Theme.of(context).brightness;

    final zikrPrevious = hasPrevious ? zikrPreviousByKey(previous) : null;
    final playlistPrevious =
        hasPrevious ? zikrPlaylistPreviousByKey(previous) : null;
    final featureRows = data.rowsFor(AnalyticsService.metricFeature);

    final cardsStart = <Widget>[
      if (_zikrRows().isNotEmpty)
        UsageRankedCard(
          title: 'Most opened zikrs',
          subtitle: 'With how many were read to the end. Aliases count '
              'with the zikr they point at',
          rows: _zikrRows(),
          previousTotal: data.previous?.zikrOpens,
          previousByKey: zikrPrevious,
          previousCaption: previousCaption,
        ),
      if (data.rowsFor(zikrSourceMetric).isNotEmpty)
        _buildEntryPoints(context),
      if (_searchSteps().any((step) => step.value > 0))
        _buildSearch(),
      if (zikrPlaylistRows(data.rowsFor(AnalyticsService.metricZikr))
          .isNotEmpty)
        UsageRankedCard(
          title: 'Played in playlists',
          subtitle: 'Each zikr counted once per playlist run',
          rows: zikrPlaylistRows(data.rowsFor(AnalyticsService.metricZikr)),
          previousTotal: playlistPrevious?.values
              .fold<int>(0, (sum, count) => sum + count),
          previousByKey: playlistPrevious,
          previousCaption: previousCaption,
          color: categoricalColor(6, brightness),
        ),
    ];

    final cardsEnd = <Widget>[
      if (featureRows.isNotEmpty) _buildAreas(context, featureRows),
      if (data.rowsFor(AnalyticsService.metricLibrary).isNotEmpty)
        UsageRankedCard(
          title: 'Library',
          subtitle: 'Chapters opened, by book',
          rows: data.rowsFor(AnalyticsService.metricLibrary),
          previousTotal: data.previousTotalFor(AnalyticsService.metricLibrary),
          previousByKey: previous?[AnalyticsService.metricLibrary],
          previousCaption: previousCaption,
          color: categoricalColor(3, brightness),
        ),
      if (data.rowsFor(AnalyticsService.metricStream).isNotEmpty)
        UsageRankedCard(
          title: 'Live streams',
          rows: data.rowsFor(AnalyticsService.metricStream),
          previousTotal: data.previousTotalFor(AnalyticsService.metricStream),
          previousByKey: previous?[AnalyticsService.metricStream],
          previousCaption: previousCaption,
          color: categoricalColor(4, brightness),
        ),
      if (data.rowsFor(AnalyticsService.metricScreen).isNotEmpty)
        UsageRankedCard(
          title: 'Screens',
          subtitle: 'Pages opened, whatever was done there',
          rows: data.rowsFor(AnalyticsService.metricScreen),
          previousTotal: data.previousTotalFor(AnalyticsService.metricScreen),
          previousByKey: previous?[AnalyticsService.metricScreen],
          previousCaption: previousCaption,
          color: categoricalColor(1, brightness),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeadlines(),
        if (data.metricTrend.isNotEmpty && data.trend.length > 1) ...[
          const SizedBox(height: 18),
          UsageCard(
            title: 'Activity',
            subtitle: 'Events per day, by kind',
            child: MetricTrendChart(series: _metricSeries(context)),
          ),
        ],
        const SizedBox(height: 18),
        WideColumns(
          spacing: 18,
          gap: 18,
          start: cardsStart.isEmpty ? cardsEnd : cardsStart,
          end: cardsStart.isEmpty ? const [] : cardsEnd,
        ),
      ],
    );
  }

  /// Where zikr opens start: a share bar of the main entry points, and
  /// the ranking under it in the same colors.
  Widget _buildEntryPoints(BuildContext context) {
    final colors = ShiaColors.of(context);
    final brightness = Theme.of(context).brightness;
    final rows = shortZikrSourceRows(data.rowsFor(zikrSourceMetric));
    final named = zikrSourceShortLabels.keys.toList();
    Color? colorFor(UsageRow row) {
      final slot = named.indexOf(row.key);
      return slot < 0 ? colors.textMuted : categoricalColor(slot, brightness);
    }

    return UsageRankedCard(
      title: 'How zikrs were opened',
      subtitle: 'Every zikr open, counted once, by where it started',
      rows: rows,
      previousTotal: data.previousTotalFor(zikrSourceMetric),
      previousByKey: data.previousCounts?[zikrSourceMetric],
      previousCaption: range.previousPeriodLabel,
      colorFor: colorFor,
      header: ShareBar(
        segments:
            namedShareSegments(rows, named, brightness, colors.textMuted),
      ),
    );
  }

  /// Opened search, typed a search, opened a result.
  List<({String label, int value, PeriodDelta? delta})> _searchSteps() {
    int now(String metric, String key) =>
        data.rowsFor(metric).where((row) => row.key == key).fold<int>(
            0, (sum, row) => sum + row.count);
    PeriodDelta? delta(String metric, String key, int value) {
      final previous = data.previousCounts;
      if (previous == null) return null;
      return periodDelta(value, previous[metric]?[key] ?? 0);
    }

    ({String label, int value, PeriodDelta? delta}) step(
        String label, String metric, String key) {
      final value = now(metric, key);
      return (label: label, value: value, delta: delta(metric, key, value));
    }

    return [
      step('Opened search', AnalyticsService.metricFeature, 'search_opened'),
      step('Searches typed', AnalyticsService.metricFeature, 'search'),
      step('Results opened', zikrSourceMetric, 'zikr_source_search'),
    ];
  }

  Widget _buildSearch() {
    final steps = _searchSteps();
    final opened = steps.first.value;
    final results = steps.last.value;
    return UsageCard(
      title: 'Search',
      subtitle: 'From opening search to opening what it found',
      child: UsageFunnel(
        steps: steps,
        note: opened == 0
            ? null
            : '${(results / opened).toStringAsFixed(1)} results opened for '
                'every time search is opened',
      ),
    );
  }

  /// Feature uses by area: the share bar, and a tile per area opening its
  /// actions.
  Widget _buildAreas(BuildContext context, List<UsageRow> rows) {
    final brightness = Theme.of(context).brightness;
    final grouped = groupFeatureRows(rows);
    final previousByKey = data.previousCounts?[AnalyticsService.metricFeature];
    final previousTotals = groupPreviousTotals(previousByKey);
    final total = rows.fold<int>(0, (sum, row) => sum + row.count);
    final present = [
      for (final group in FeatureGroup.values)
        if (grouped[group] case final groupRows? when groupRows.isNotEmpty)
          (group, groupRows),
    ];
    Color colorOf(FeatureGroup group) =>
        categoricalColor(FeatureGroup.values.indexOf(group), brightness);

    return UsageCard(
      title: 'What people do',
      subtitle: 'Actions taken, by area of the app. Open one for its '
          'actions',
      total: total,
      delta: data.previous == null
          ? null
          : periodDelta(total, data.previous!.featureUses),
      deltaCaption: range.previousPeriodLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (present.length > 1) ...[
            ShareBar(segments: [
              for (final (group, groupRows) in present)
                ShareSegment(
                  label: group.title,
                  value: groupRows.fold<int>(0, (sum, r) => sum + r.count),
                  color: colorOf(group),
                ),
            ]),
            const SizedBox(height: 14),
          ],
          UsageTileGrid(tiles: [
            for (final (group, groupRows) in present)
              Builder(builder: (context) {
                final groupTotal =
                    groupRows.fold<int>(0, (sum, r) => sum + r.count);
                return UsageAreaTile(
                  title: group.title,
                  color: colorOf(group),
                  total: groupTotal,
                  share: total == 0 ? 0 : groupTotal / total,
                  delta: previousByKey == null
                      ? null
                      : periodDelta(groupTotal, previousTotals[group] ?? 0),
                  top: groupRows.first.label,
                  onTap: () => pushPageRoute(
                    context,
                    UsageRankedPage(
                      title: group.title,
                      subtitle: group.subtitle,
                      rows: groupRows,
                      previousByKey: previousByKey,
                      color: colorOf(group),
                    ),
                  ),
                );
              }),
          ]),
        ],
      ),
    );
  }

  List<UsageRow> _zikrRows() =>
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
    AnalyticsService.metricZikr: 'Zikrs',
    AnalyticsService.metricScreen: 'Screens',
    AnalyticsService.metricFeature: 'Actions',
    AnalyticsService.metricLibrary: 'Library',
    AnalyticsService.metricStream: 'Streams',
  };

  List<UsageMetricSeries> _metricSeries(BuildContext context) {
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

  Widget _buildHeadlines() {
    final zikrRows = _zikrRows();
    final zikrOpens = zikrRows.fold<int>(0, (sum, r) => sum + r.count);
    final finished = zikrCompletionTotal({
      for (final row in data.rowsFor(AnalyticsService.metricZikr))
        row.key: row.count,
    });
    final searches = data
        .rowsFor(AnalyticsService.metricFeature)
        .where((row) => row.key == 'search')
        .fold<int>(0, (sum, row) => sum + row.count);
    final featureUses = data.totalFor(AnalyticsService.metricFeature);
    final libraryOpens = data.totalFor(AnalyticsService.metricLibrary);
    final previous = data.previous;
    final previousCounts = data.previousCounts;
    final caption = range.previousPeriodLabel;
    final previousLibrary =
        data.previousTotalFor(AnalyticsService.metricLibrary);

    String count(int value) => usageCountFormat.format(value);

    return UsageKpiGrid(tiles: [
      UsageKpiTile(
        label: 'Zikr opens',
        value: count(zikrOpens),
        delta: previous == null
            ? null
            : periodDelta(zikrOpens, previous.zikrOpens),
        deltaCaption: caption,
      ),
      UsageKpiTile(
        label: 'Read to the end',
        value: zikrOpens == 0
            ? '–'
            : usagePercentFormat.format(finished / zikrOpens),
        note: '${count(finished)} finished',
      ),
      UsageKpiTile(
        label: 'Different zikrs',
        value: count(zikrRows.length),
        delta: previous == null
            ? null
            : periodDelta(zikrRows.length, previous.distinctZikrs),
        deltaCaption: caption,
      ),
      UsageKpiTile(
        label: 'Searches',
        value: count(searches),
        delta: previousCounts == null
            ? null
            : periodDelta(searches,
                previousCounts[AnalyticsService.metricFeature]?['search'] ?? 0),
        deltaCaption: caption,
      ),
      UsageKpiTile(
        label: 'Actions taken',
        value: count(featureUses),
        delta: previous == null
            ? null
            : periodDelta(featureUses, previous.featureUses),
        deltaCaption: caption,
      ),
      UsageKpiTile(
        label: 'Library chapters',
        value: count(libraryOpens),
        delta: previousLibrary == null
            ? null
            : periodDelta(libraryOpens, previousLibrary),
        deltaCaption: caption,
      ),
    ]);
  }
}
