import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:shia_companion/constants.dart';
import 'package:shia_companion/models/zikr_reminder.dart';
import 'package:shia_companion/services/analytics_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/zikr_reminder_scheduling.dart';

/// Owns the user's zikr reminders: persistence, and turning them into local
/// notifications.
///
/// Mirrors how `setUpNotifications` schedules Azan notifications in
/// constants.dart — same plugin, same `tz.local`, same tolerance for missing
/// location — but keeps its own id range
/// (`notificationBaseId` and up, allocated well clear of the Azan/prayer ids
/// constants.dart hands out) so the two schedules never collide or need to
/// know about each other.
class ZikrReminderService extends ChangeNotifier {
  ZikrReminderService._();

  static final ZikrReminderService instance = ZikrReminderService._();

  static const String _storageKey = 'zikr_reminders_v1';
  static const String _nextBaseIdKey = 'zikr_reminders_next_base_id';
  static const int _baseIdStart = 40000;

  /// Prefix on every notification [payload] this service schedules, so
  /// [handlePrayerNotificationResponse] can tell a zikr reminder tap apart
  /// from a prayer/Azan one and route it to the right reminder.
  static const String payloadPrefix = 'zikr_reminder:';

  static const String _androidChannelId = 'zikr_reminders';
  static const String _androidChannelName = 'Zikr Reminders';

  List<ZikrReminder> _reminders = const [];
  bool _loaded = false;
  int _idSeed = 0;

  List<ZikrReminder> get reminders => List.unmodifiable(_reminders);
  bool get hasLoaded => _loaded;

  /// Looks up one reminder by id — for a tapped notification to find which
  /// reminder (and so which zikr, if any) it was for. Null if it was since
  /// deleted.
  Future<ZikrReminder?> byId(String id) async {
    await load();
    for (final reminder in _reminders) {
      if (reminder.id == id) return reminder;
    }
    return null;
  }

  Future<void> load() async {
    if (_loaded) return;
    _reminders = ZikrReminder.listFrom(SP.prefs.getString(_storageKey));
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() {
    return SP.prefs.setString(_storageKey, ZikrReminder.encodeList(_reminders));
  }

  Future<int> _allocateBaseId() async {
    final next = SP.prefs.getInt(_nextBaseIdKey) ?? _baseIdStart;
    await SP.prefs.setInt(_nextBaseIdKey, next + zikrReminderIdSlotsPerReminder);
    return next;
  }

  String _generateId() {
    _idSeed++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_idSeed';
  }

  Future<ZikrReminder> addReminder({
    required String title,
    String? zikrUid,
    required Set<int> daysOfWeek,
    required ZikrReminderTimeMode mode,
    int hour = 21,
    int minute = 0,
    String prayerName = 'Maghrib',
    int offsetMinutes = 30,
  }) async {
    await load();
    final baseId = await _allocateBaseId();
    final reminder = ZikrReminder(
      id: _generateId(),
      notificationBaseId: baseId,
      title: title,
      zikrUid: zikrUid,
      daysOfWeek: daysOfWeek,
      mode: mode,
      hour: hour,
      minute: minute,
      prayerName: prayerName,
      offsetMinutes: offsetMinutes,
    );

    _reminders = [..._reminders, reminder];
    await _persist();
    notifyListeners();

    unawaited(AnalyticsService.feature(
      'zikr_reminder_added',
      label: 'Zikr reminder added',
      parameters: {'mode': mode.name, 'days': daysOfWeek.length},
    ));

    await rescheduleAll();
    return reminder;
  }

  Future<void> updateReminder(ZikrReminder updated) async {
    await load();
    _reminders = [
      for (final reminder in _reminders)
        reminder.id == updated.id ? updated : reminder,
    ];
    await _persist();
    notifyListeners();

    unawaited(AnalyticsService.feature(
      'zikr_reminder_edited',
      label: 'Zikr reminder edited',
      parameters: {'mode': updated.mode.name},
    ));

    await rescheduleAll();
  }

  Future<void> deleteReminder(String id) async {
    await load();
    ZikrReminder? removed;
    final next = <ZikrReminder>[];
    for (final reminder in _reminders) {
      if (reminder.id == id) {
        removed = reminder;
      } else {
        next.add(reminder);
      }
    }
    if (removed == null) return;

    _reminders = next;
    await _persist();
    notifyListeners();

    unawaited(AnalyticsService.feature(
      'zikr_reminder_deleted',
      label: 'Zikr reminder deleted',
    ));

    await _cancelReminderNotifications(removed);
  }

  /// Removes every reminder and cancels their notifications.
  ///
  /// Exists for tests, and for any future "clear all" affordance — mirrors
  /// the `clear()` other per-user stores (QuranProgressStore,
  /// SavedVersesStore) already expose.
  Future<void> clearAll() async {
    await load();
    final existing = _reminders;
    if (existing.isEmpty) return;

    _reminders = const [];
    await _persist();
    notifyListeners();
    await Future.wait(existing.map(_cancelReminderNotifications));
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await load();
    final index = _reminders.indexWhere((reminder) => reminder.id == id);
    if (index == -1) return;

    final updated = List<ZikrReminder>.of(_reminders);
    updated[index] = updated[index].copyWith(enabled: enabled);
    _reminders = updated;
    await _persist();
    notifyListeners();

    await rescheduleAll();
  }

  /// Cancels this reminder's whole reserved id block in parallel — mirrors
  /// `cancelPrayerNotifications` in constants.dart, which cancels its (much
  /// larger) Azan id range the same way rather than one `await` at a time.
  Future<void> _cancelReminderNotifications(ZikrReminder reminder) async {
    final plugin = flutterLocalNotificationsPlugin;
    if (plugin == null) return;
    await Future.wait(Iterable<int>.generate(
      zikrReminderIdSlotsPerReminder,
      (offset) => reminder.notificationBaseId + offset,
    ).map((id) => plugin.cancel(id: id)));
  }

  /// Cancels and rebuilds every reminder's notifications against the current
  /// time, location and enabled state.
  ///
  /// Safe — and cheap — to call often: it is a no-op on web, before the
  /// notifications plugin exists, or once there are no reminders at all. A
  /// reminder that needs a location it doesn't have yet skips itself rather
  /// than failing the whole pass, exactly like `setUpNotifications` does for
  /// Azan. Call sites: after any add/edit/delete/toggle above, on app start
  /// once the plugin is ready, and after a location change (prayer-relative
  /// reminders shift with location just like Azan times do).
  Future<void> rescheduleAll() async {
    if (kIsWeb) return;
    final plugin = flutterLocalNotificationsPlugin;
    if (plugin == null) return;

    await load();
    if (_reminders.isEmpty) return;

    await initializeNotificationTimeZone();
    await Future.wait(
      _reminders.map((reminder) => _scheduleReminder(plugin, reminder)),
    );
  }

  Future<void> _scheduleReminder(
    FlutterLocalNotificationsPlugin plugin,
    ZikrReminder reminder,
  ) async {
    await _cancelReminderNotifications(reminder);
    if (!reminder.enabled || reminder.daysOfWeek.isEmpty) return;

    final details = _notificationDetails();
    final scheduleMode = canScheduleExactPrayerNotifications
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final body = "It's time for ${reminder.title}";
    final now = DateTime.now();
    final schedulingTasks = <Future<void>>[];

    if (reminder.mode == ZikrReminderTimeMode.fixedTime) {
      for (final weekday in reminder.daysOfWeek) {
        final scheduled = nextInstanceOfWeekdayAndTime(
          now,
          weekday,
          reminder.hour,
          reminder.minute,
        );
        final id = zikrReminderNotificationId(
          baseId: reminder.notificationBaseId,
          weekday: weekday,
          occurrenceIndex: 0,
        );
        schedulingTasks.add(plugin.zonedSchedule(
          id: id,
          title: reminder.title,
          body: body,
          scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
          notificationDetails: details,
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: '$payloadPrefix${reminder.id}',
        ));
      }
      await Future.wait(schedulingTasks);
      return;
    }

    if (lat == null || long == null) {
      debugPrint(
          'Skipping zikr reminder "${reminder.title}": location unavailable');
      return;
    }

    final prayerTime = getPrayerTimeObject();
    for (final weekday in reminder.daysOfWeek) {
      final occurrences = upcomingPrayerRelativeOccurrences(
        prayerTime: prayerTime,
        now: now,
        weekday: weekday,
        prayerName: reminder.prayerName,
        offsetMinutes: reminder.offsetMinutes,
        latitude: lat!,
        longitude: long!,
        count: zikrReminderRelativeOccurrenceCount,
      );

      for (var index = 0; index < occurrences.length; index++) {
        final id = zikrReminderNotificationId(
          baseId: reminder.notificationBaseId,
          weekday: weekday,
          occurrenceIndex: index,
        );
        schedulingTasks.add(plugin.zonedSchedule(
          id: id,
          title: reminder.title,
          body: body,
          scheduledDate: tz.TZDateTime.from(occurrences[index], tz.local),
          notificationDetails: details,
          androidScheduleMode: scheduleMode,
          payload: '$payloadPrefix${reminder.id}',
        ));
      }
    }
    await Future.wait(schedulingTasks);
  }

  NotificationDetails _notificationDetails() {
    return NotificationDetails(
      android: Platform.isAndroid
          ? const AndroidNotificationDetails(
              _androidChannelId,
              _androidChannelName,
              channelDescription: 'Reminders for zikr and duas you scheduled',
              importance: Importance.high,
              priority: Priority.high,
            )
          : null,
      iOS: Platform.isIOS ? const DarwinNotificationDetails() : null,
    );
  }
}
