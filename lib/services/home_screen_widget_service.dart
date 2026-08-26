import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/todays_recitation.dart';
import 'package:shia_companion/utils/widget_prayer_time_selection.dart';

class HomeScreenWidgetService {
  HomeScreenWidgetService._();

  static final HomeScreenWidgetService instance = HomeScreenWidgetService._();

  static const String appGroupId = 'group.com.developer110.shiacompanion';
  static const MethodChannel _channel =
      MethodChannel('shia_companion/home_widgets');

  static const String favoritesTitleKey = 'sc_favorites_title';
  static const String favoritesSubtitleKey = 'sc_favorites_subtitle';
  static const int listWidgetItemCount = 12;
  static final List<String> favoriteItemKeys = List.generate(
    listWidgetItemCount,
    (index) => 'sc_favorites_item_${index + 1}',
  );
  static final List<String> favoriteUrlKeys = List.generate(
    listWidgetItemCount,
    (index) => 'sc_favorites_url_${index + 1}',
  );
  static const String favoriteItem1Key = 'sc_favorites_item_1';
  static const String favoriteItem2Key = 'sc_favorites_item_2';
  static const String favoriteItem3Key = 'sc_favorites_item_3';
  static const String favoriteUrl1Key = 'sc_favorites_url_1';
  static const String favoriteUrl2Key = 'sc_favorites_url_2';
  static const String favoriteUrl3Key = 'sc_favorites_url_3';

  static const String recitationTitleKey = 'sc_recitation_title';
  static const String recitationSubtitleKey = 'sc_recitation_subtitle';
  static final List<String> recitationItemKeys = List.generate(
    listWidgetItemCount,
    (index) => 'sc_recitation_item_${index + 1}',
  );
  static final List<String> recitationUrlKeys = List.generate(
    listWidgetItemCount,
    (index) => 'sc_recitation_url_${index + 1}',
  );
  static const String recitationItem1Key = 'sc_recitation_item_1';
  static const String recitationItem2Key = 'sc_recitation_item_2';
  static const String recitationItem3Key = 'sc_recitation_item_3';
  static const String recitationUrl1Key = 'sc_recitation_url_1';
  static const String recitationUrl2Key = 'sc_recitation_url_2';
  static const String recitationUrl3Key = 'sc_recitation_url_3';
  static const String recitationScheduleKey = 'sc_recitation_schedule';

  static const String prayerTitleKey = 'sc_prayer_title';
  static const String prayerNameKey = 'sc_prayer_name';
  static const String prayerTimeKey = 'sc_prayer_time';
  static const String prayerDateKey = 'sc_prayer_date';
  static const String prayerLocationKey = 'sc_prayer_location';
  static const String prayerScheduleKey = 'sc_prayer_schedule';
  static const String prayerSecondaryNameKey = 'sc_prayer_secondary_name';
  static const String prayerSecondaryTimeKey = 'sc_prayer_secondary_time';

  static const String dailyPrayerTimesTitleKey = 'sc_daily_prayer_title';
  static const String dailyPrayerTimesScheduleKey = 'sc_daily_prayer_schedule';
  static const int dailyPrayerTimesItemCount = maxWidgetPrayerTimes;
  static final List<String> dailyPrayerNameKeys = List.generate(
    dailyPrayerTimesItemCount,
    (index) => 'sc_daily_prayer_name_${index + 1}',
  );
  static final List<String> dailyPrayerTimeKeys = List.generate(
    dailyPrayerTimesItemCount,
    (index) => 'sc_daily_prayer_time_${index + 1}',
  );

  List<UniversalData> _favorites = const [];

  bool get _isSupported {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }

  void updateFavorites(Iterable<UniversalData> favorites) {
    _favorites = List.unmodifiable(favorites);
  }

  Future<void> publishAll() async {
    if (!_isSupported) return;

    await _saveAndRefresh(buildWidgetSnapshot());
  }

  Future<void> publishFavorites() async {
    if (!_isSupported) return;

    await _saveAndRefresh(buildFavoritesSnapshot());
  }

  Future<void> publishTodaysRecitations() async {
    if (!_isSupported) return;

    await _saveAndRefresh(buildTodaysRecitationsSnapshot());
  }

  Future<void> publishUpcomingPrayer() async {
    if (!_isSupported) return;

    await _saveAndRefresh(buildUpcomingPrayerSnapshot());
  }

  Future<void> publishDailyPrayerTimes() async {
    if (!_isSupported) return;

    await _saveAndRefresh(buildDailyPrayerTimesSnapshot());
  }

  Map<String, String> buildWidgetSnapshot({
    Iterable<UniversalData>? favorites,
  }) {
    return {
      ...buildFavoritesSnapshot(favorites: favorites),
      ...buildTodaysRecitationsSnapshot(),
      ...buildUpcomingPrayerSnapshot(),
      ...buildDailyPrayerTimesSnapshot(),
    };
  }

  Map<String, String> buildFavoritesSnapshot({
    Iterable<UniversalData>? favorites,
  }) {
    final favoriteItems = (favorites ?? _favorites)
        .where((item) => _isLinkableFavorite(item))
        .toList(growable: false);
    final topFavorites = favoriteItems.take(favoriteItemKeys.length).toList(
          growable: false,
        );
    final snapshot = <String, String>{
      favoritesTitleKey: 'Favorites',
      favoritesSubtitleKey: '',
    };

    for (var index = 0; index < favoriteItemKeys.length; index++) {
      final item = _itemAt(topFavorites, index);
      snapshot[favoriteItemKeys[index]] = _widgetTitleForUniversalData(item) ??
          (index == 0 ? 'No favorites yet' : '');
      snapshot[favoriteUrlKeys[index]] = _widgetUrlForUniversalData(item);
    }

    return snapshot;
  }

  Map<String, String> buildTodaysRecitationsSnapshot({DateTime? now}) {
    final today = now ?? DateTime.now();
    final recitations = _buildRecitationItemsForDay(today);
    final snapshot = <String, String>{
      recitationTitleKey: "Today's Recitations",
      recitationSubtitleKey: '',
      recitationScheduleKey: jsonEncode(_buildRecitationSchedule(today)),
    };

    for (var index = 0; index < recitationItemKeys.length; index++) {
      final item = _itemAt(recitations, index);
      snapshot[recitationItemKeys[index]] = _widgetTitleForRecitation(item) ??
          (index == 0 ? 'Open app to refresh' : '');
      snapshot[recitationUrlKeys[index]] = _widgetUrlForRecitation(item);
    }

    return snapshot;
  }

  List<Map<String, Object>> _buildRecitationSchedule(DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);

    return List.generate(8, (dayOffset) {
      final date = calendarDayFrom(startOfToday, dayOffset);
      final items = _buildRecitationItemsForDay(date);

      return {
        'start': date.millisecondsSinceEpoch,
        'items': items
            .map((item) => {
                  'title': _widgetTitleForRecitation(item) ?? '',
                  'url': _widgetUrlForRecitation(item),
                })
            .where((item) => (item['title'] ?? '').isNotEmpty)
            .toList(),
      };
    });
  }

  List<UidTitleData> _buildRecitationItemsForDay(DateTime date) {
    return buildTodaysRecitationItems(now: date)
        .take(recitationItemKeys.length)
        .toList();
  }

  Map<String, String> buildUpcomingPrayerSnapshot() {
    final prayerSnapshot = _buildPrayerSnapshot();
    return {
      prayerTitleKey: 'Up Next',
      prayerNameKey: prayerSnapshot.name,
      prayerTimeKey: prayerSnapshot.time,
      prayerDateKey: prayerSnapshot.dateLabel,
      prayerLocationKey: prayerSnapshot.location,
      prayerScheduleKey: prayerSnapshot.encodedSchedule,
      prayerSecondaryNameKey: prayerSnapshot.secondaryName,
      prayerSecondaryTimeKey: prayerSnapshot.secondaryTime,
    };
  }

  Map<String, String> buildDailyPrayerTimesSnapshot({DateTime? now}) {
    final snapshot = <String, String>{
      dailyPrayerTimesTitleKey: 'Prayer Times',
      dailyPrayerTimesScheduleKey: '',
      prayerLocationKey: lat == null || long == null
          ? 'Location needed'
          : city ?? 'Saved location',
    };

    if (lat == null || long == null) {
      for (var index = 0; index < dailyPrayerTimesItemCount; index++) {
        snapshot[dailyPrayerNameKeys[index]] = index == 0 ? 'Set location' : '';
        snapshot[dailyPrayerTimeKeys[index]] = index == 0 ? 'Open app' : '';
      }
      return snapshot;
    }

    final today = now ?? DateTime.now();
    final prayers = _buildUpcomingPrayerTimes(today);
    snapshot[dailyPrayerTimesScheduleKey] =
        jsonEncode(_buildDailyPrayerTimesSchedule(today));

    for (var index = 0; index < dailyPrayerTimesItemCount; index++) {
      final prayer = _itemAt(prayers, index);
      snapshot[dailyPrayerNameKeys[index]] = prayer?.time.name ?? '';
      snapshot[dailyPrayerTimeKeys[index]] = prayer?.displayTime ?? '';
    }

    return snapshot;
  }

  Future<void> publishAllSoon() async {
    if (!_isSupported) return;

    unawaited(publishAll());
  }

  Future<void> publishFavoritesSoon() async {
    if (!_isSupported) return;

    unawaited(publishFavorites());
  }

  Future<void> publishRecitationsSoon() async {
    if (!_isSupported) return;

    unawaited(publishTodaysRecitations());
  }

  Future<void> publishPrayerSoon() async {
    if (!_isSupported) return;

    unawaited(publishUpcomingPrayer());
  }

  Future<void> publishDailyPrayerTimesSoon() async {
    if (!_isSupported) return;

    unawaited(publishDailyPrayerTimes());
  }

  Future<void> _saveAndRefresh(Map<String, String> values) async {
    try {
      await _channel.invokeMethod<void>('saveWidgetData', values);
      await _channel.invokeMethod<void>('refreshWidgets');
    } on MissingPluginException catch (e) {
      debugPrint('Home widget bridge unavailable: $e');
    } catch (e) {
      debugPrint('Unable to publish home widget data: $e');
    }
  }

  _PrayerSnapshot _buildPrayerSnapshot() {
    if (lat == null || long == null) {
      return const _PrayerSnapshot(
        name: 'Prayer Times',
        time: 'Set location',
        dateLabel: 'Open app',
        location: 'Location needed',
        encodedSchedule: '',
        secondaryName: '',
        secondaryTime: '',
      );
    }

    final now = DateTime.now();
    final entries = _buildPrayerSchedule(now);
    final nextEntry = _firstWhereOrNull(
      entries,
      (entry) => entry.dateTime.isAfter(now),
    );

    if (nextEntry == null) {
      return _PrayerSnapshot(
        name: 'Prayer Times',
        time: 'Open app',
        dateLabel: 'Refresh schedule',
        location: city ?? 'Saved location',
        encodedSchedule: entries.map((entry) => entry.encode()).join(';'),
        secondaryName: '',
        secondaryTime: '',
      );
    }

    return _PrayerSnapshot(
      name: nextEntry.name,
      time: nextEntry.displayTime,
      dateLabel: nextEntry.dateLabel,
      location: city ?? 'Saved location',
      encodedSchedule: entries.map((entry) => entry.encode()).join(';'),
      secondaryName: nextEntry.secondaryName,
      secondaryTime: nextEntry.secondaryTime,
    );
  }

  List<_PrayerScheduleEntry> _buildPrayerSchedule(DateTime now) {
    final schedule = <_PrayerScheduleEntry>[];
    final selected = selectedWidgetPrayerTimes();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (var dayOffset = 0; dayOffset < 8; dayOffset++) {
      final date = calendarDayFrom(startOfToday, dayOffset);
      final dateLabel = _dateLabelForDay(date, dayOffset);
      // Every time, not just the selected ones, so a prayer can still name the
      // deadline it has to be offered before even when that marker is hidden.
      final readings = {
        for (final reading in _readWidgetPrayerTimesForDay(date))
          reading.time.id: reading,
      };

      for (final time in selected) {
        final reading = readings[time.id];
        if (reading == null) continue;

        final offerBefore = readings[time.offerBeforeId];
        schedule.add(_PrayerScheduleEntry(
          dateTime: reading.dateTime,
          name: time.name,
          displayTime: reading.displayTime,
          dateLabel: dateLabel,
          secondaryName: offerBefore == null ? '' : offerBefore.time.name,
          secondaryTime: offerBefore == null ? '' : offerBefore.displayTime,
        ));
      }
    }

    schedule.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return schedule;
  }

  List<WidgetPrayerTimeReading> _readWidgetPrayerTimesForDay(
    DateTime date, {
    List<WidgetPrayerTime>? times,
  }) {
    return readWidgetPrayerTimes(
      prayerTime: getPrayerTimeObject(),
      date: date,
      latitude: lat!,
      longitude: long!,
      timeZone: date.timeZoneOffset.inMinutes / 60.0,
      times: times ?? widgetPrayerTimes,
    );
  }

  List<WidgetPrayerTimeReading> _buildDailyPrayerTimesForDay(DateTime date) {
    return _readWidgetPrayerTimesForDay(
      date,
      times: selectedWidgetPrayerTimes(),
    );
  }

  /// The next [maxWidgetPrayerTimes] prayers from [moment] — the same rolling
  /// window [HomePrayerTimesCard] draws, via the same function, so the widget
  /// and the card cannot drift apart.
  List<WidgetPrayerTimeReading> _buildUpcomingPrayerTimes(DateTime moment) {
    return nextWidgetPrayerTimeReadings(
      prayerTime: getPrayerTimeObject(),
      latitude: lat!,
      longitude: long!,
      count: selectedWidgetPrayerTimes().length,
      now: moment,
      times: selectedWidgetPrayerTimes(),
    );
  }

  /// One entry per prayer, rather than one per day.
  ///
  /// The widget used to publish a day at a time and the native side picks the
  /// last entry that has started, so from the evening onwards it displayed a
  /// list of prayers that had all already happened while the card beside it in
  /// the app had rolled on to tomorrow. Cutting a new entry at every prayer
  /// makes the widget advance the way the card does — WidgetKit already wakes
  /// at these instants, since the prayer schedule contributes the same dates as
  /// timeline transition points.
  List<Map<String, Object>> _buildDailyPrayerTimesSchedule(DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    final boundaries = <DateTime>{startOfToday};

    for (var dayOffset = 0; dayOffset < 8; dayOffset++) {
      final date = calendarDayFrom(startOfToday, dayOffset);
      for (final reading in _buildDailyPrayerTimesForDay(date)) {
        // A prayer is a transition the moment it arrives: that is when it stops
        // being the next one and drops off the front of the list.
        if (!reading.dateTime.isBefore(startOfToday)) {
          boundaries.add(reading.dateTime);
        }
      }
    }

    final ordered = boundaries.toList()..sort();
    return [
      for (final boundary in ordered)
        {
          'start': boundary.millisecondsSinceEpoch,
          'items': _buildUpcomingPrayerTimes(boundary)
              .map((prayer) => {
                    'title': prayer.time.name,
                    'time': prayer.displayTime,
                    'url': '',
                  })
              .toList(),
        },
    ];
  }

  String _dateLabelForDay(DateTime date, int dayOffset) {
    if (dayOffset == 0) return 'Today';
    if (dayOffset == 1) return 'Tomorrow';
    return '${date.month}/${date.day}';
  }

  String? _widgetTitleForUniversalData(UniversalData? item) {
    if (item == null) return null;
    final title = item.title.trim();
    return title.isNotEmpty ? title : item.canonicalUid;
  }

  /// Favourites the widget can open. Shrines and channels (type 2) are
  /// navigation targets with no deep link, so a row for one would do nothing
  /// when tapped; zikr and library items both have one.
  bool _isLinkableFavorite(UniversalData item) {
    return item.type == zikrDeepLinkType || item.type == libraryDeepLinkType;
  }

  String _widgetUrlForUniversalData(UniversalData? item) {
    if (item == null) return '';

    final uid = item.canonicalUid;
    switch (item.type) {
      case zikrDeepLinkType:
        return buildZikrDeepLinkUrl(uid: uid, slug: itemSlugs[uid]);
      case libraryDeepLinkType:
        // A library favourite is saved straight from the book list, where the
        // uid already is the book's slug.
        return buildLibraryDeepLinkUrl(bookSlug: uid);
      default:
        return '';
    }
  }

  String? _widgetTitleForRecitation(UidTitleData? item) {
    final title = item?.title.trim();
    if (title == null || title.isEmpty) return null;
    return title;
  }

  String _widgetUrlForRecitation(UidTitleData? item) {
    if (item == null) return '';
    if (item.getUId().contains('~')) return '';
    final uid = item.getFirstUId();
    return buildZikrDeepLinkUrl(uid: uid, slug: itemSlugs[uid]);
  }

  T? _itemAt<T>(List<T> items, int index) {
    if (index < 0 || index >= items.length) return null;
    return items[index];
  }

  T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}

class _PrayerSnapshot {
  const _PrayerSnapshot({
    required this.name,
    required this.time,
    required this.dateLabel,
    required this.location,
    required this.encodedSchedule,
    required this.secondaryName,
    required this.secondaryTime,
  });

  final String name;
  final String time;
  final String dateLabel;
  final String location;
  final String encodedSchedule;
  final String secondaryName;
  final String secondaryTime;
}

class _PrayerScheduleEntry {
  const _PrayerScheduleEntry({
    required this.dateTime,
    required this.name,
    required this.displayTime,
    required this.dateLabel,
    required this.secondaryName,
    required this.secondaryTime,
  });

  final DateTime dateTime;
  final String name;
  final String displayTime;
  final String dateLabel;
  final String secondaryName;
  final String secondaryTime;

  String encode() {
    return [
      dateTime.millisecondsSinceEpoch.toString(),
      name,
      displayTime,
      dateLabel,
      secondaryName,
      secondaryTime,
    ].join('|');
  }
}
