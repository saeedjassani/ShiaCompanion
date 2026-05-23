import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/todays_recitation.dart';

class HomeScreenWidgetService {
  HomeScreenWidgetService._();

  static final HomeScreenWidgetService instance = HomeScreenWidgetService._();

  static const String appGroupId = 'group.com.developer110.shiacompanion';
  static const MethodChannel _channel =
      MethodChannel('shia_companion/home_widgets');

  static const String favoritesTitleKey = 'sc_favorites_title';
  static const String favoritesSubtitleKey = 'sc_favorites_subtitle';
  static const String favoriteItem1Key = 'sc_favorites_item_1';
  static const String favoriteItem2Key = 'sc_favorites_item_2';
  static const String favoriteItem3Key = 'sc_favorites_item_3';
  static const String favoriteUrl1Key = 'sc_favorites_url_1';
  static const String favoriteUrl2Key = 'sc_favorites_url_2';
  static const String favoriteUrl3Key = 'sc_favorites_url_3';

  static const String recitationTitleKey = 'sc_recitation_title';
  static const String recitationSubtitleKey = 'sc_recitation_subtitle';
  static const String recitationItem1Key = 'sc_recitation_item_1';
  static const String recitationItem2Key = 'sc_recitation_item_2';
  static const String recitationItem3Key = 'sc_recitation_item_3';
  static const String recitationUrl1Key = 'sc_recitation_url_1';
  static const String recitationUrl2Key = 'sc_recitation_url_2';
  static const String recitationUrl3Key = 'sc_recitation_url_3';

  static const String prayerTitleKey = 'sc_prayer_title';
  static const String prayerNameKey = 'sc_prayer_name';
  static const String prayerTimeKey = 'sc_prayer_time';
  static const String prayerDateKey = 'sc_prayer_date';
  static const String prayerLocationKey = 'sc_prayer_location';
  static const String prayerScheduleKey = 'sc_prayer_schedule';

  static String prayerFilterPreferenceKey(String prayerName) {
    return 'widget_upcoming_${notificationPreferenceKeyForPrayer(prayerName)}';
  }

  static bool defaultPrayerFilterValue(String prayerName) {
    final normalizedName = prayerName.trim().toLowerCase();
    return normalizedName != 'sunrise' && normalizedName != 'sunset';
  }

  static bool shouldIncludePrayer(String prayerName) {
    if (!SP.isInitialized) return defaultPrayerFilterValue(prayerName);
    return SP.prefs.getBool(prayerFilterPreferenceKey(prayerName)) ??
        defaultPrayerFilterValue(prayerName);
  }

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

  Map<String, String> buildWidgetSnapshot() {
    return {
      ...buildFavoritesSnapshot(),
      ...buildTodaysRecitationsSnapshot(),
      ...buildUpcomingPrayerSnapshot(),
    };
  }

  Map<String, String> buildFavoritesSnapshot() {
    final favorites = (favsData ?? const <UniversalData>[])
        .where((item) => item.type == 0)
        .toList(growable: false);
    final topFavorites = favorites.take(3).toList(growable: false);

    return {
      favoritesTitleKey: 'Favorites',
      favoritesSubtitleKey: _favoritesSubtitle(favorites.length),
      favoriteItem1Key:
          _widgetTitleForUniversalData(_itemAt(topFavorites, 0)) ??
              'No favorites yet',
      favoriteItem2Key:
          _widgetTitleForUniversalData(_itemAt(topFavorites, 1)) ?? '',
      favoriteItem3Key:
          _widgetTitleForUniversalData(_itemAt(topFavorites, 2)) ?? '',
      favoriteUrl1Key: _widgetUrlForUniversalData(_itemAt(topFavorites, 0)),
      favoriteUrl2Key: _widgetUrlForUniversalData(_itemAt(topFavorites, 1)),
      favoriteUrl3Key: _widgetUrlForUniversalData(_itemAt(topFavorites, 2)),
    };
  }

  Map<String, String> buildTodaysRecitationsSnapshot({DateTime? now}) {
    final today = now ?? DateTime.now();
    final recitations = buildTodaysRecitationItems(now: today)
        .where((item) => !item.uid.contains('~'))
        .take(3)
        .toList();

    return {
      recitationTitleKey: "Today's Recitations",
      recitationSubtitleKey: _weekdayLabel(today),
      recitationItem1Key: _widgetTitleForRecitation(_itemAt(recitations, 0)) ??
          'Open app to refresh',
      recitationItem2Key:
          _widgetTitleForRecitation(_itemAt(recitations, 1)) ?? '',
      recitationItem3Key:
          _widgetTitleForRecitation(_itemAt(recitations, 2)) ?? '',
      recitationUrl1Key: _widgetUrlForRecitation(_itemAt(recitations, 0)),
      recitationUrl2Key: _widgetUrlForRecitation(_itemAt(recitations, 1)),
      recitationUrl3Key: _widgetUrlForRecitation(_itemAt(recitations, 2)),
    };
  }

  Map<String, String> buildUpcomingPrayerSnapshot() {
    final prayerSnapshot = _buildPrayerSnapshot();
    return {
      prayerTitleKey: 'Upcoming Prayer',
      prayerNameKey: prayerSnapshot.name,
      prayerTimeKey: prayerSnapshot.time,
      prayerDateKey: prayerSnapshot.dateLabel,
      prayerLocationKey: prayerSnapshot.location,
      prayerScheduleKey: prayerSnapshot.encodedSchedule,
    };
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
      );
    }

    return _PrayerSnapshot(
      name: nextEntry.name,
      time: nextEntry.displayTime,
      dateLabel: nextEntry.dateLabel,
      location: city ?? 'Saved location',
      encodedSchedule: entries.map((entry) => entry.encode()).join(';'),
    );
  }

  List<_PrayerScheduleEntry> _buildPrayerSchedule(DateTime now) {
    final schedule = <_PrayerScheduleEntry>[];
    final prayerTime = getPrayerTimeObject();
    final names = prayerTime.getTimeNames();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (var dayOffset = 0; dayOffset < 2; dayOffset++) {
      final date = startOfToday.add(Duration(days: dayOffset));
      final dateLabel = dayOffset == 0 ? 'Today' : 'Tomorrow';

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

      for (var index = 0; index < names.length; index++) {
        if (!shouldIncludePrayer(names[index])) continue;

        final dateTime = _dateTimeForTime24(date, times24[index]);
        if (dateTime == null) continue;

        schedule.add(_PrayerScheduleEntry(
          dateTime: dateTime,
          name: names[index],
          displayTime: displayTimes[index],
          dateLabel: dateLabel,
        ));
      }
    }

    schedule.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return schedule;
  }

  DateTime? _dateTimeForTime24(DateTime date, String time24) {
    final parts = time24.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _favoritesSubtitle(int count) {
    if (count == 0) return 'Open app to add zikr favorites';
    if (count == 1) return '1 saved zikr';
    return '$count saved zikr';
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

  String _weekdayLabel(DateTime date) {
    const labels = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return labels[date.weekday - 1];
  }
}

class _PrayerSnapshot {
  const _PrayerSnapshot({
    required this.name,
    required this.time,
    required this.dateLabel,
    required this.location,
    required this.encodedSchedule,
  });

  final String name;
  final String time;
  final String dateLabel;
  final String location;
  final String encodedSchedule;
}

class _PrayerScheduleEntry {
  const _PrayerScheduleEntry({
    required this.dateTime,
    required this.name,
    required this.displayTime,
    required this.dateLabel,
  });

  final DateTime dateTime;
  final String name;
  final String displayTime;
  final String dateLabel;

  String encode() {
    return [
      dateTime.millisecondsSinceEpoch.toString(),
      name,
      displayTime,
      dateLabel,
    ].join('|');
  }
}
