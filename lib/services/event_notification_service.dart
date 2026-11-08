import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../constants.dart';
import '../l10n/hijri_l10n.dart';
import '../l10n/l10n.dart';
import '../utils/calendar_events.dart';
import '../utils/event_notification_planning.dart';
import '../utils/islamic_calendar_widget_data.dart';
import '../utils/shared_preferences.dart';
import 'analytics_service.dart';

/// Notifications for the Islamic calendar's events (assets/events.json):
/// wiladat, shahadat and the other days, each kind opted into on its own.
///
/// Off until the reader turns it on. Each event is told at Maghrib on its
/// eve, when its Islamic day begins: "Tonight · 13 Rajab".
///
/// Which events get a notification is
/// [planEventNotifications]'s choice: it spreads a fixed number of them over
/// the coming year so that a reader who stays away from the app still hears
/// about at least one event a month, the quiet months included. Every launch
/// plans again from that day, so someone who opens the app now and then gets
/// every event of the weeks ahead.
///
/// Its notifications live in their own id block, [_baseId] and up, clear of
/// the Azan's (100-831, 786) and the zikr reminders' (40000 and up).
class EventNotificationService extends ChangeNotifier {
  EventNotificationService._();

  static final EventNotificationService instance = EventNotificationService._();

  static const String enabledKey = 'event_notifications_enabled';
  static const String kindsKey = 'event_notifications_kinds';

  /// Prefix on every notification payload this service schedules, followed
  /// by the event's civil date (`2026-12-08`), so a tap can open the Calendar
  /// on that day.
  static const String payloadPrefix = 'calendar_event:';

  static const int _baseId = 39000;
  static const int _idSlots = 100;

  /// How many events may be pending at once. Android has room for a year of
  /// them. iOS keeps only the soonest 64 notifications an app has pending and
  /// silently drops the rest; the Azan takes the others, and gives up these
  /// slots while events are on (see [iosReservedSlots]).
  static const int _androidBudget = 40;
  static const int _iosBudget = 8;

  static String get _androidChannelId => 'calendar_events';

  /// The iOS notification slots kept free of the Azan for events: none while
  /// events are off. See `prayerNotificationScheduleDays`.
  static int get iosReservedSlots =>
      SP.isInitialized && instance.enabled ? _iosBudget : 0;

  bool get enabled =>
      SP.isInitialized && (SP.prefs.getBool(enabledKey) ?? false);

  /// Every kind until the reader turns one off.
  Set<EventNotificationKind> get kinds {
    if (!SP.isInitialized) return EventNotificationKind.values.toSet();
    final saved = SP.prefs.getStringList(kindsKey);
    if (saved == null) return EventNotificationKind.values.toSet();
    return {
      for (final kind in EventNotificationKind.values)
        if (saved.contains(kind.name)) kind,
    };
  }

  Future<void> setEnabled(bool value) async {
    if (value == enabled) return;
    await SP.prefs.setBool(enabledKey, value);
    notifyListeners();
    unawaited(AnalyticsService.feature(
      value ? 'event_notifications_on' : 'event_notifications_off',
      label: value ? 'Event notifications on' : 'Event notifications off',
    ));
    if (value) await requestNotificationPermissions();
    // On iOS the Azan's share of the 64 pending notifications depends on
    // whether events are on.
    if (!kIsWeb && Platform.isIOS && flutterLocalNotificationsPlugin != null) {
      await setUpNotifications();
    }
    await rescheduleAll();
  }

  Future<void> setKind(EventNotificationKind kind, bool on) async {
    final next = kinds;
    on ? next.add(kind) : next.remove(kind);
    await SP.prefs.setStringList(kindsKey, [for (final k in next) k.name]);
    notifyListeners();
    unawaited(AnalyticsService.feature(
      'event_notifications_kind',
      label: 'Event notification kind changed',
      parameters: {'kind': kind.name, 'on': on ? 1 : 0},
    ));
    await rescheduleAll();
  }

  Future<void>? _running;
  bool _again = false;

  /// Cancels and rebuilds the event notifications from today, in the app
  /// language and the Hijri months in effect.
  ///
  /// Cheap, and safe to call often: on every cold start, after a change of
  /// language, Hijri date setting or location (which moves Automatic's month
  /// starts), and after any change here. Calls that overlap run once more
  /// after the one in flight rather than side by side.
  Future<void> rescheduleAll() async {
    if (kIsWeb) return;
    if (_running != null) {
      _again = true;
      return _running;
    }
    final run = _reschedule();
    _running = run;
    try {
      await run;
    } finally {
      _running = null;
    }
    if (_again) {
      _again = false;
      await rescheduleAll();
    }
  }

  Future<void> _reschedule() async {
    final plugin = flutterLocalNotificationsPlugin;
    if (plugin == null || !SP.isInitialized) return;

    await Future.wait([
      for (var id = _baseId; id < _baseId + _idSlots; id++)
        plugin.cancel(id: id),
    ]);
    if (!enabled) return;

    await initializeNotificationTimeZone();
    final l10n = L10n.current;
    final events = await CalendarEvents.load(languageCode: l10n.localeName);
    final plan = planEventNotifications(
      now: DateTime.now(),
      events: events,
      offsetDays: hijriOffsetInEffect,
      kinds: kinds,
      notifyAt: eventMaghrib,
      budget: Platform.isIOS ? _iosBudget : _androidBudget,
    );

    final details = _notificationDetails();
    await Future.wait([
      for (var i = 0; i < plan.length && i < _idSlots; i++)
        plugin.zonedSchedule(
          id: _baseId + i,
          title: eventNotificationTitle(plan[i].event),
          body: l10n.eventNotificationBody(
            l10n.homeEventTonight,
            localizeDigits(
                '${plan[i].hijriDay} ${hijriMonthName(plan[i].hijriMonth)}'),
          ),
          scheduledDate: tz.TZDateTime.from(plan[i].fireAt, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: '$payloadPrefix${_dateKey(plan[i].eventDate)}',
        ),
    ]);
    debugPrint('Scheduled ${plan.length} event notifications');
  }

  /// Maghrib on [eve] where the reader is, as the Azan and the prayer times
  /// card have it: the moment the event's Islamic day begins. 8:00 pm without
  /// a location.
  @visibleForTesting
  static DateTime eventMaghrib(DateTime eve) {
    final latitude = lat, longitude = long;
    if (latitude != null && longitude != null) {
      try {
        for (final entry in buildPrayerNotificationEntriesForDay(
          prayerTime: getPrayerTimeObject(),
          date: eve,
          latitude: latitude,
          longitude: longitude,
        )) {
          if (entry.name == 'Maghrib') return entry.dateTime;
        }
      } catch (e) {
        debugPrint('No Maghrib for event notifications: $e');
      }
    }
    return eventNotificationFallbackTime(eve);
  }

  NotificationDetails _notificationDetails() {
    return NotificationDetails(
      android: Platform.isAndroid
          ? AndroidNotificationDetails(
              _androidChannelId,
              L10n.current.eventNotificationsTitle,
              channelDescription: L10n.current.eventNotificationsSubtitle,
            )
          : null,
      iOS: Platform.isIOS ? const DarwinNotificationDetails() : null,
    );
  }

  /// The civil date a tapped notification's event falls on, or null when
  /// [payload] isn't one of this service's.
  static DateTime? eventDateOfPayload(String? payload) {
    if (payload == null || !payload.startsWith(payloadPrefix)) return null;
    final parts = payload.substring(payloadPrefix.length).split('-');
    if (parts.length != 3) return null;
    final numbers = parts.map(int.tryParse).toList();
    if (numbers.contains(null)) return null;
    return DateTime(numbers[0]!, numbers[1]!, numbers[2]!);
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// A notification's title for an events.json day: what happened and to whom,
/// as Home's Coming up row says it ("Birth of Imam Ali (a.s.)").
String eventNotificationTitle(Map<dynamic, dynamic> event) {
  final text = eventHeadline(event);
  return text.kind.isEmpty
      ? text.name
      : L10n.current.homeEventKindOf(text.kind, text.name);
}
