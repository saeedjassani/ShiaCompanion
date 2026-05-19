import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/utils/todays_recitation.dart';

class HomeScreenWidgetService {
  HomeScreenWidgetService._();

  static final HomeScreenWidgetService instance = HomeScreenWidgetService._();

  static const String appGroupId = 'group.com.developer110.shiacompanion';

  static const String favoritesWidgetKind = 'FavoritesWidget';
  static const String recitationWidgetKind = 'TodaysRecitationWidget';
  static const String prayerWidgetKind = 'UpcomingPrayerWidget';

  static const String _androidPackage = 'com.developer110.shiacompanion';
  static const String _androidWidgetPackage = '$_androidPackage.widgets';

  static const String favoritesAndroidProvider =
      '$_androidWidgetPackage.FavoritesWidgetProvider';
  static const String recitationAndroidProvider =
      '$_androidWidgetPackage.TodaysRecitationWidgetProvider';
  static const String prayerAndroidProvider =
      '$_androidWidgetPackage.UpcomingPrayerWidgetProvider';

  static const String favoritesTitleKey = 'sc_favorites_title';
  static const String favoritesSubtitleKey = 'sc_favorites_subtitle';
  static const String favoriteItem1Key = 'sc_favorites_item_1';
  static const String favoriteItem2Key = 'sc_favorites_item_2';
  static const String favoriteItem3Key = 'sc_favorites_item_3';

  static const String recitationTitleKey = 'sc_recitation_title';
  static const String recitationSubtitleKey = 'sc_recitation_subtitle';
  static const String recitationItem1Key = 'sc_recitation_item_1';
  static const String recitationItem2Key = 'sc_recitation_item_2';
  static const String recitationItem3Key = 'sc_recitation_item_3';

  static const String prayerTitleKey = 'sc_prayer_title';
  static const String prayerNameKey = 'sc_prayer_name';
  static const String prayerTimeKey = 'sc_prayer_time';
  static const String prayerDateKey = 'sc_prayer_date';
  static const String prayerLocationKey = 'sc_prayer_location';
  static const String prayerScheduleKey = 'sc_prayer_schedule';

  bool _configured = false;

  bool get _isSupported {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }

  Future<void> configure() async {
    if (!_isSupported || _configured) return;

    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(appGroupId);
    }
    _configured = true;
  }

  Future<void> publishAll() async {
    if (!_isSupported) return;

    await configure();
    await publishFavorites();
    await publishTodaysRecitations();
    await publishUpcomingPrayer();
  }

  Future<void> publishFavorites() async {
    if (!_isSupported) return;

    final favorites = favsData ?? const <UniversalData>[];
    final topFavorites = favorites
        .map(
          (item) => item.title.trim().isNotEmpty ? item.title.trim() : item.uid,
        )
        .take(3)
        .toList(growable: false);

    await _saveWidgetData({
      favoritesTitleKey: 'Favorites',
      favoritesSubtitleKey: _favoritesSubtitle(favorites.length),
      favoriteItem1Key: _itemAt(topFavorites, 0) ?? 'No favorites yet',
      favoriteItem2Key: _itemAt(topFavorites, 1) ?? '',
      favoriteItem3Key: _itemAt(topFavorites, 2) ?? '',
    });
    await _updateWidget(
      androidName: 'FavoritesWidgetProvider',
      iOSName: favoritesWidgetKind,
      qualifiedAndroidName: favoritesAndroidProvider,
    );
  }

  Future<void> publishTodaysRecitations() async {
    if (!_isSupported) return;

    final today = DateTime.now();
    final recitations = buildTodaysRecitationItems(now: today);
    final topRecitations =
        recitations.map((item) => item.title.trim()).take(3).toList();

    await _saveWidgetData({
      recitationTitleKey: "Today's Recitations",
      recitationSubtitleKey: _weekdayLabel(today),
      recitationItem1Key: _itemAt(topRecitations, 0) ?? 'Open app to refresh',
      recitationItem2Key: _itemAt(topRecitations, 1) ?? '',
      recitationItem3Key: _itemAt(topRecitations, 2) ?? '',
    });
    await _updateWidget(
      androidName: 'TodaysRecitationWidgetProvider',
      iOSName: recitationWidgetKind,
      qualifiedAndroidName: recitationAndroidProvider,
    );
  }

  Future<void> publishUpcomingPrayer() async {
    if (!_isSupported) return;

    final prayerSnapshot = _buildPrayerSnapshot();
    await _saveWidgetData({
      prayerTitleKey: 'Upcoming Prayer',
      prayerNameKey: prayerSnapshot.name,
      prayerTimeKey: prayerSnapshot.time,
      prayerDateKey: prayerSnapshot.dateLabel,
      prayerLocationKey: prayerSnapshot.location,
      prayerScheduleKey: prayerSnapshot.encodedSchedule,
    });
    await _updateWidget(
      androidName: 'UpcomingPrayerWidgetProvider',
      iOSName: prayerWidgetKind,
      qualifiedAndroidName: prayerAndroidProvider,
    );
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

  Future<void> _saveWidgetData(Map<String, String> values) async {
    try {
      await configure();
      for (final entry in values.entries) {
        await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
      }
    } on MissingPluginException catch (e) {
      debugPrint('Home widget plugin unavailable: $e');
    } catch (e) {
      debugPrint('Unable to save home widget data: $e');
    }
  }

  Future<void> _updateWidget({
    required String androidName,
    required String iOSName,
    required String qualifiedAndroidName,
  }) async {
    try {
      await HomeWidget.updateWidget(
        androidName: androidName,
        iOSName: iOSName,
        qualifiedAndroidName: qualifiedAndroidName,
      );
    } on MissingPluginException catch (e) {
      debugPrint('Home widget update unavailable: $e');
    } catch (e) {
      debugPrint('Unable to update home widget: $e');
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
    if (count == 0) return 'Open app to add favorites';
    if (count == 1) return '1 saved item';
    return '$count saved items';
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
