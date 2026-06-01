import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/todays_recitation.dart';

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
  static const int dailyPrayerTimesItemCount = 5;
  static final List<String> dailyPrayerNameKeys = List.generate(
    dailyPrayerTimesItemCount,
    (index) => 'sc_daily_prayer_name_${index + 1}',
  );
  static final List<String> dailyPrayerTimeKeys = List.generate(
    dailyPrayerTimesItemCount,
    (index) => 'sc_daily_prayer_time_${index + 1}',
  );

  bool get _isSupported {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
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

  Map<String, String> buildWidgetSnapshot() {
    return {
      ...buildFavoritesSnapshot(),
      ...buildTodaysRecitationsSnapshot(),
      ...buildUpcomingPrayerSnapshot(),
      ...buildDailyPrayerTimesSnapshot(),
    };
  }

  Map<String, String> buildFavoritesSnapshot() {
    final favorites = (favsData ?? const <UniversalData>[])
        .where((item) => item.type == 0)
        .toList(growable: false);
    final topFavorites = favorites.take(favoriteItemKeys.length).toList(
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
      final date = startOfToday.add(Duration(days: dayOffset));
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
      prayerTitleKey: 'Next Prayer',
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
    final prayers = _buildDailyPrayerTimesForDay(today);
    snapshot[dailyPrayerTimesScheduleKey] =
        jsonEncode(_buildDailyPrayerTimesSchedule(today));

    for (var index = 0; index < dailyPrayerTimesItemCount; index++) {
      final prayer = _itemAt(prayers, index);
      snapshot[dailyPrayerNameKeys[index]] = prayer?.name ?? '';
      snapshot[dailyPrayerTimeKeys[index]] = prayer?.time ?? '';
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
    final prayerTime = getPrayerTimeObject();
    final names = prayerTime.getTimeNames();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (var dayOffset = 0; dayOffset < 8; dayOffset++) {
      final date = startOfToday.add(Duration(days: dayOffset));
      final dateLabel = _dateLabelForDay(date, dayOffset);

      prayerTime.setTimeFormat(prayerTime.getTime24());
      final times24 = prayerTime.getPrayerTimes(
        date,
        lat!,
        long!,
        date.timeZoneOffset.inMinutes / 60.0,
      );

      prayerTime.setTimeFormat(prayerTime.getTime12());
      final displayTimes = prayerTime.getPrayerTimes(
        date,
        lat!,
        long!,
        date.timeZoneOffset.inMinutes / 60.0,
      );

      final midnight = shiaMidnightForDate(
        prayerTime: prayerTime,
        date: date,
        latitude: lat!,
        longitude: long!,
      );
      final periods = [
        _PrayerPeriod(
          index: prayerIndexFajr,
          name: names[prayerIndexFajr],
          secondaryName: 'Sunrise',
          secondaryTime: displayTimes[prayerIndexSunrise],
        ),
        _PrayerPeriod(
          index: prayerIndexZuhr,
          name: names[prayerIndexZuhr],
          secondaryName: 'Sunset',
          secondaryTime: displayTimes[prayerIndexSunset],
        ),
        _PrayerPeriod(
          index: prayerIndexMaghrib,
          name: names[prayerIndexMaghrib],
          secondaryName: 'Midnight',
          secondaryTime:
              midnight == null ? '' : formatPrayerDateTime12(midnight),
        ),
      ];

      for (final period in periods) {
        final dateTime = dateTimeForTime24(date, times24[period.index]);
        if (dateTime == null) continue;

        schedule.add(_PrayerScheduleEntry(
          dateTime: dateTime,
          name: period.name,
          displayTime: displayTimes[period.index],
          dateLabel: dateLabel,
          secondaryName: period.secondaryName,
          secondaryTime: period.secondaryTime,
        ));
      }
    }

    schedule.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return schedule;
  }

  List<PrayerTimeDisplayEntry> _buildDailyPrayerTimesForDay(DateTime date) {
    return buildFiveDailyPrayerTimeEntries(
      prayerTime: getPrayerTimeObject(),
      date: date,
      latitude: lat!,
      longitude: long!,
      timeZone: date.timeZoneOffset.inMinutes / 60.0,
    );
  }

  List<Map<String, Object>> _buildDailyPrayerTimesSchedule(DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);

    return List.generate(8, (dayOffset) {
      final date = startOfToday.add(Duration(days: dayOffset));
      final prayers = _buildDailyPrayerTimesForDay(date);

      return {
        'start': date.millisecondsSinceEpoch,
        'items': prayers
            .map((prayer) => {
                  'title': prayer.name,
                  'time': prayer.time,
                  'url': '',
                })
            .toList(),
      };
    });
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

  String _widgetUrlForUniversalData(UniversalData? item) {
    if (item == null || item.type != 0) return '';
    final uid = item.canonicalUid;
    return buildZikrDeepLinkUrl(uid: uid, slug: itemSlugs[uid]);
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

class _PrayerPeriod {
  const _PrayerPeriod({
    required this.index,
    required this.name,
    required this.secondaryName,
    required this.secondaryTime,
  });

  final int index;
  final String name;
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
