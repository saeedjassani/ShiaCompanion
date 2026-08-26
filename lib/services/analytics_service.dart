import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Two sinks behind one call site.
///
/// Everything goes to Firebase Analytics, which is where retention, geography
/// and funnels come for free. The events we want *ranked* — which zikr, which
/// feature — additionally increment counters in the Realtime Database, because
/// GA4 refuses to slice a custom parameter until it is registered as a custom
/// dimension, lags a day behind, and thins out older data. Those counters are
/// what [UsageDashboardPage] reads, and they are live.
class AnalyticsService {
  const AnalyticsService._();

  /// Metric buckets. `database.rules.json` whitelists exactly these names, so
  /// adding one here means adding it there too or the writes bounce.
  static const String metricZikr = 'zikr';
  static const String metricScreen = 'screen';
  static const String metricFeature = 'feature';
  static const String metricLibrary = 'library';
  static const String metricStream = 'stream';

  /// Debug traffic is developer traffic, and counting it would skew the very
  /// ranking this exists to produce. Flip to exercise the pipeline locally.
  static const bool recordUsageInDebug = false;

  static final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');

  /// A label is the human-readable name for a key. It does not change between
  /// two views in the same session, so write it once and skip the rest.
  static final Set<String> _labelledThisSession = <String>{};

  @visibleForTesting
  static void resetSessionState() => _labelledThisSession.clear();

  /// Widget tests render pages without standing up Firebase. Every entry point
  /// funnels through here so a missing app is a no-op rather than an unhandled
  /// async error that takes the screen down with it.
  static bool get _isLive => Firebase.apps.isNotEmpty;

  static bool get _shouldCount =>
      _isLive && (!kDebugMode || recordUsageInDebug);

  // ---------------------------------------------------------------------------
  // Screens
  // ---------------------------------------------------------------------------

  /// Records a screen view.
  ///
  /// Uses [FirebaseAnalytics.logScreenView] rather than a hand-rolled
  /// `screen_view` event so the SDK fills the parameters GA4's built-in screen
  /// reports actually read.
  static Future<void> screen(
    String screenName, {
    bool deferOnWeb = false,
  }) async {
    if (!_isLive) return;
    if (kIsWeb && deferOnWeb) {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(seconds: 5));
    }
    await _guard(() => FirebaseAnalytics.instance.logScreenView(
          screenName: screenName,
          screenClass: screenName,
        ));
    _count(metricScreen, screenName, label: screenName);
  }

  // ---------------------------------------------------------------------------
  // Content
  // ---------------------------------------------------------------------------

  /// Records a zikr being opened, keyed by its canonical uid so an alias and
  /// its target are one row rather than two, and a retitled zikr keeps its
  /// history.
  ///
  /// [source] is where the tap came from — the thing that tells you whether
  /// search, the home grid or a shared link is doing the work.
  static Future<void> zikrView({
    required String uid,
    required String title,
    required String source,
  }) async {
    if (!_isLive) return;
    final canonicalUid = uid.split('|').last.trim();
    if (canonicalUid.isEmpty) return;

    await _guard(() => FirebaseAnalytics.instance.logEvent(
          name: 'zikr_view',
          parameters: {
            'zikr_uid': canonicalUid,
            'zikr_title': title,
            'source': source,
          },
        ));
    // select_content stays because GA4 gives it a built-in report, and it is
    // free now that it fires from one place with a stable id.
    await _guard(() => FirebaseAnalytics.instance.logSelectContent(
          contentType: 'zikr',
          itemId: canonicalUid,
        ));
    _count(metricZikr, canonicalUid, label: title);
    _count(metricFeature, 'zikr_source_$source',
        label: _sourceLabels[source] ?? 'Zikr opened via $source');
  }

  /// Dashboard names for the [ZikrOpenSource] ids.
  ///
  /// The ids are stable because they are database keys, but "deep_link" and
  /// "zikr_link" read as the same thing to anyone who does not already know
  /// which is which, so the row says what the entry point actually was.
  static const Map<String, String> _sourceLabels = <String, String>{
    ZikrOpenSource.list: 'Zikr opened from a category list',
    ZikrOpenSource.search: 'Zikr opened from search',
    ZikrOpenSource.favorites: 'Zikr opened from favorites',
    ZikrOpenSource.library: 'Zikr opened from the library',
    ZikrOpenSource.todaysRecitation: "Zikr opened from today's recitation",
    ZikrOpenSource.liveStreaming: 'Zikr opened from live streaming',
    ZikrOpenSource.deepLink: 'Zikr opened from a shared link (from outside '
        'the app)',
    ZikrOpenSource.zikrLink: 'Zikr opened from a link inside another zikr',
    ZikrOpenSource.admin: 'Zikr opened from the admin list',
    ZikrOpenSource.unknown: 'Zikr opened from an untagged entry point',
  };

  /// Records a zikr being read to the end, which is the difference between a
  /// zikr people open and a zikr people actually recite.
  static Future<void> zikrCompleted({
    required String uid,
    required String title,
  }) async {
    if (!_isLive) return;
    final canonicalUid = uid.split('|').last.trim();
    if (canonicalUid.isEmpty) return;

    await _guard(() => FirebaseAnalytics.instance.logEvent(
          name: 'zikr_completed',
          parameters: {'zikr_uid': canonicalUid, 'zikr_title': title},
        ));
    _count(metricZikr, '$canonicalUid~done', label: '$title (completed)');
  }

  /// Records a library book or chapter being opened.
  static Future<void> libraryView({
    required String bookUid,
    required String bookTitle,
    String? chapterUid,
  }) async {
    if (!_isLive) return;
    if (bookUid.trim().isEmpty) return;

    await _guard(() => FirebaseAnalytics.instance.logEvent(
          name: 'library_view',
          parameters: {
            'book_uid': bookUid,
            'book_title': bookTitle,
            if (chapterUid != null) 'chapter_uid': chapterUid,
          },
        ));
    _count(metricLibrary, bookUid, label: bookTitle);
  }

  /// Records a live stream or shrine channel being opened. Keyed by title
  /// because the uid is a URL, which is not a legal database key.
  static Future<void> streamView({
    required String title,
    String? link,
  }) async {
    if (!_isLive) return;
    if (title.trim().isEmpty) return;

    await _guard(() => FirebaseAnalytics.instance.logEvent(
          name: 'stream_view',
          parameters: {'stream_title': title, if (link != null) 'link': link},
        ));
    _count(metricStream, title, label: title);
  }

  // ---------------------------------------------------------------------------
  // Features
  // ---------------------------------------------------------------------------

  /// Records a feature actually being *used*, as opposed to its screen merely
  /// being opened. [name] is a stable snake_case id; [label] is what the
  /// dashboard shows a human.
  static Future<void> feature(
    String name, {
    String? label,
    Map<String, Object>? parameters,
  }) async {
    if (!_isLive) return;
    if (name.trim().isEmpty) return;

    await _guard(() => FirebaseAnalytics.instance.logEvent(
          name: 'feature_use',
          parameters: {'feature': name, ...?parameters},
        ));
    _count(metricFeature, name, label: label ?? name);
  }

  /// Records the "Prayer Times Shown" selection being saved — which times the
  /// home card, the list widget and the Up Next countdown treat as the next
  /// prayer.
  ///
  /// The counter says how often people change it at all; the chosen ids go to
  /// GA4, where the popular combinations are readable and a comma-separated
  /// list is not a problem the way it would be as a database key.
  static Future<void> prayerTimesSelectionChanged(List<String> ids) => feature(
        'prayer_times_selection_changed',
        label: 'Prayer times shown changed',
        parameters: {'prayer_times': ids.join(',')},
      );

  /// Records the search screen being opened.
  ///
  /// Counted separately from [search] because the two answer different
  /// questions: this one is how often people reach for search at all, which is
  /// the honest measure of how much the feature is wanted, while [search]
  /// counts the searches actually typed. Together with `zikr_source_search`
  /// they read as a funnel — opened, searched, opened something.
  static Future<void> searchOpened() => feature(
        'search_opened',
        label: 'Search opened',
      );

  /// Records a search. The term goes to GA4 only — free text does not belong in
  /// a database key, and GA4 already reports it.
  static Future<void> search(String term) async {
    if (!_isLive) return;
    await _guard(() => FirebaseAnalytics.instance.logSearch(searchTerm: term));
    _count(metricFeature, 'search', label: 'Search');
  }

  // ---------------------------------------------------------------------------
  // Counter plumbing
  // ---------------------------------------------------------------------------

  /// Bumps the all-time and per-day counters for one key in one round trip.
  ///
  /// Deliberately not awaited by callers: a counter is never worth delaying a
  /// screen for, and a failed write is worth less than a crash.
  static void _count(String metric, String rawKey, {String? label}) {
    if (!_shouldCount) return;

    final key = safeKey(rawKey);
    if (key == null) return;

    final day = _dayFormat.format(DateTime.now());
    final updates = <String, Object?>{
      'totals/$metric/$key': ServerValue.increment(1),
      'daily/$day/$metric/$key': ServerValue.increment(1),
    };

    final labelId = '$metric/$key';
    final trimmedLabel = label?.trim();
    if (trimmedLabel != null &&
        trimmedLabel.isNotEmpty &&
        _labelledThisSession.add(labelId)) {
      // Labels are capped because a title is a display string, not a payload.
      updates['labels/$metric/$key'] = trimmedLabel.length > 120
          ? trimmedLabel.substring(0, 120)
          : trimmedLabel;
    }

    unawaited(_guard(
      () => FirebaseDatabase.instance.ref('usage').update(updates),
    ));
  }

  /// Realtime Database keys may not contain `.`, `$`, `#`, `[`, `]`, `/` or
  /// control characters, and the security rules narrow that further to a fixed
  /// charset so a hostile client cannot invent unbounded key space.
  ///
  /// Case is preserved: zikr uids like `L4~2` are the join key back into the
  /// in-memory `items` index, and lowercasing them would break the lookup.
  @visibleForTesting
  static String? safeKey(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_~-]'), '-')
        .replaceAll(RegExp('-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (sanitized.isEmpty) return null;
    return sanitized.length > 60 ? sanitized.substring(0, 60) : sanitized;
  }

  static Future<void> _guard(Future<void> Function() write) async {
    try {
      await write();
    } catch (error) {
      // Analytics is never allowed to be the reason a screen fails.
      debugPrint('AnalyticsService: dropped an event: $error');
    }
  }
}

/// Where a zikr open came from. Stable ids, because they become database keys
/// and a renamed source would fork its own history.
class ZikrOpenSource {
  const ZikrOpenSource._();

  static const String unknown = 'unknown';
  static const String list = 'list';
  static const String search = 'search';
  static const String favorites = 'favorites';
  static const String library = 'library';
  static const String todaysRecitation = 'todays_recitation';
  static const String liveStreaming = 'live_streaming';
  static const String deepLink = 'deep_link';
  static const String zikrLink = 'zikr_link';
  static const String admin = 'admin';
}
