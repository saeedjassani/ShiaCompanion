import 'dart:async';
import 'dart:convert';

import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import '../utils/prayer_calendar_plan.dart';
import '../utils/shared_preferences.dart';
import '../utils/widget_prayer_time_selection.dart';

/// A calendar the prayer times can go in.
@immutable
class PrayerCalendarChoice {
  const PrayerCalendarChoice({
    required this.id,
    required this.name,
    this.account,
    this.colorHex,
    this.isPrimary = false,
  });

  final String id;
  final String name;

  /// The account it belongs to (an email address for Google, iCloud).
  final String? account;
  final String? colorHex;
  final bool isPrimary;
}

/// The device calendar, behind a seam tests can replace.
abstract class PrayerCalendarBackend {
  /// Whether the app may read and write the calendars without asking.
  Future<bool> hasAccess();

  /// Asks for full access (reading the calendar list and taking events out
  /// again need it, not only adding); whether it was given.
  Future<bool> requestAccess();

  Future<void> openSettings();

  /// The calendars events can be added to, the default first.
  Future<List<PrayerCalendarChoice>> writableCalendars();

  Future<String> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
  });

  /// Takes an event out. One already gone (deleted by hand) is not an error.
  Future<void> deleteEvent(String id);
}

/// Thrown when the chosen calendar is no longer on the device.
class PrayerCalendarMissing implements Exception {
  const PrayerCalendarMissing();
}

class DevicePrayerCalendarBackend implements PrayerCalendarBackend {
  DeviceCalendar get _plugin => DeviceCalendar.instance;

  @override
  Future<bool> hasAccess() async =>
      await _plugin.hasPermissions() == CalendarPermissionStatus.granted;

  @override
  Future<bool> requestAccess() async =>
      await _plugin.requestPermissions(level: CalendarAccessLevel.full) ==
      CalendarPermissionStatus.granted;

  @override
  Future<void> openSettings() => _plugin.openAppSettings();

  @override
  Future<List<PrayerCalendarChoice>> writableCalendars() async {
    final calendars = await _plugin.listCalendars();
    final writable = [
      for (final calendar in calendars)
        if (!calendar.readOnly && !calendar.hidden)
          PrayerCalendarChoice(
            id: calendar.id,
            name: calendar.name,
            account: calendar.accountName,
            colorHex: calendar.colorHex,
            isPrimary: calendar.isPrimary,
          ),
    ];
    // Stable: the platform's order within each group.
    return [
      ...writable.where((calendar) => calendar.isPrimary),
      ...writable.where((calendar) => !calendar.isPrimary),
    ];
  }

  @override
  Future<String> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
  }) async {
    try {
      return await _plugin.createEvent(
        calendarId: calendarId,
        title: title,
        startDate: start,
        endDate: end,
        description: description,
        availability: EventAvailability.free,
      );
    } on DeviceCalendarException catch (e) {
      if (e.errorCode == DeviceCalendarError.notFound) {
        throw const PrayerCalendarMissing();
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteEvent(String id) async {
    try {
      await _plugin.deleteEvent(instanceId: id);
    } on DeviceCalendarException catch (e) {
      if (e.errorCode != DeviceCalendarError.notFound) rethrow;
    }
  }
}

/// Puts the prayer times in one of the phone's calendars - a Google
/// account's shows in Google Calendar, iCloud's in Apple Calendar - and
/// keeps them right.
///
/// Every time is a 15-minute event marked free. The app remembers each
/// event it added, so it can take them out again: when the reader turns it
/// off, unticks a time, or a time moves because the city or the calculation
/// method changed. [refresh] runs at launch and after those changes; it only
/// touches the calendar where something differs, and tops the range back up
/// to [days] ahead as the days go by.
class PrayerCalendarService extends ChangeNotifier {
  PrayerCalendarService._();

  static final PrayerCalendarService instance = PrayerCalendarService._();

  @visibleForTesting
  static PrayerCalendarBackend backend = DevicePrayerCalendarBackend();

  /// Lets tests pin which day is today.
  @visibleForTesting
  static DateTime Function() debugNow = DateTime.now;

  static const String calendarIdKey = 'prayer_calendar_id';
  static const String calendarNameKey = 'prayer_calendar_name';
  static const String timesKey = 'prayer_calendar_times';
  static const String daysKey = 'prayer_calendar_days';
  static const String eventsKey = 'prayer_calendar_events';

  /// The device calendar plugin is Android and iOS only.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Completer<void>? _running;
  bool _busy = false;

  /// True while events are being written or taken out.
  bool get busy => _busy;

  /// Whether the last write found the calendar gone (deleted on the phone,
  /// or its account removed) and turned this off.
  bool get lostCalendar => _lostCalendar;
  bool _lostCalendar = false;

  String? get calendarId =>
      SP.isInitialized ? SP.prefs.getString(calendarIdKey) : null;

  bool get isOn => calendarId != null;

  String? get calendarName =>
      SP.isInitialized ? SP.prefs.getString(calendarNameKey) : null;

  Set<String> get timeIds {
    final stored = SP.isInitialized ? SP.prefs.getStringList(timesKey) : null;
    final known = {for (final time in widgetPrayerTimes) time.id};
    final ids = {...?stored}.intersection(known);
    return ids.isEmpty ? defaultPrayerCalendarTimeIds.toSet() : ids;
  }

  int get days {
    final stored = SP.isInitialized ? SP.prefs.getInt(daysKey) : null;
    return prayerCalendarDayChoices.contains(stored)
        ? stored!
        : defaultPrayerCalendarDays;
  }

  /// The day of the last event in the calendar, or null when there is none.
  DateTime? get filledThrough {
    final events = _tracked();
    if (events.isEmpty) return null;
    final last = events
        .map((event) => event.start)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return DateTime(last.year, last.month, last.day);
  }

  Future<bool> hasAccess() => backend.hasAccess();
  Future<bool> requestAccess() => backend.requestAccess();
  Future<void> openSettings() => backend.openSettings();
  Future<List<PrayerCalendarChoice>> writableCalendars() =>
      backend.writableCalendars();

  /// Starts filling [calendar] with the prayer times, or moves them there
  /// from the calendar used before. Access must already be granted. Returns
  /// how many events were added.
  Future<int> turnOn(PrayerCalendarChoice calendar) => _serialized(() async {
    _lostCalendar = false;
    if (calendarId != null && calendarId != calendar.id) {
      await _deleteAll();
    }
    await SP.prefs.setString(calendarIdKey, calendar.id);
    await SP.prefs.setString(calendarNameKey, calendar.name);
    // What the page showed before there was a calendar is what is wanted.
    await SP.prefs.setStringList(timesKey, _ordered(timeIds));
    await SP.prefs.setInt(daysKey, days);
    return _sync();
  });

  /// Takes every event this app added out of the calendar, and stops.
  Future<int> turnOff() => _serialized(() async {
    final removed = await _deleteAll();
    await SP.prefs.remove(calendarIdKey);
    await SP.prefs.remove(calendarNameKey);
    return removed;
  });

  Future<void> setTimes(Set<String> ids) => _serialized(() async {
    if (ids.isEmpty) return;
    await SP.prefs.setStringList(timesKey, _ordered(ids));
    if (isOn) await _sync();
  });

  Future<void> setDays(int value) => _serialized(() async {
    if (!prayerCalendarDayChoices.contains(value)) return;
    await SP.prefs.setInt(daysKey, value);
    if (isOn) await _sync();
  });

  /// Brings the calendar up to date without asking for anything: a no-op
  /// when it is off, when there is no location, or when access was taken
  /// away in the phone's settings.
  Future<void> refresh() async {
    if (!isSupported || !isOn) return;
    try {
      if (!await backend.hasAccess()) return;
      await _serialized(_sync);
    } catch (e) {
      debugPrint('Could not bring the prayer calendar up to date: $e');
    }
  }

  /// One change at a time: a tick while a month is still being written
  /// waits for it, so two never write the same events.
  Future<T> _serialized<T>(Future<T> Function() task) async {
    while (_running != null) {
      await _running!.future;
    }
    final running = _running = Completer<void>();
    _busy = true;
    notifyListeners();
    try {
      return await task();
    } finally {
      _running = null;
      running.complete();
      _busy = false;
      notifyListeners();
    }
  }

  /// Writes what differs; returns how many events were added.
  Future<int> _sync() async {
    final id = calendarId;
    final latitude = lat, longitude = long;
    if (id == null || latitude == null || longitude == null) return 0;

    final now = debugNow();
    final today = DateTime(now.year, now.month, now.day);
    final l10n = L10n.current;
    final planned = planPrayerCalendarEvents(
      prayerTime: getPrayerTimeObject(),
      firstDay: today,
      days: days,
      timeIds: timeIds,
      latitude: latitude,
      longitude: longitude,
      titleFor: (name) => localizedPrayerName(name, l10n),
    );
    final changes = diffPrayerCalendar(
      tracked: _tracked(),
      planned: planned,
      today: today,
    );
    if (changes.isEmpty) return 0;

    final place = city;
    final description = place == null || place.isEmpty
        ? l10n.prayerCalendarEventNoteNoPlace
        : l10n.prayerCalendarEventNote(place);

    // Saved as it goes, so an app closed halfway still knows what it wrote
    // and never adds a second copy.
    final tracked = <TrackedPrayerEvent>[...changes.keep];
    final remaining = <TrackedPrayerEvent>[...changes.delete];
    Future<void> save() => _saveTracked([...tracked, ...remaining]);

    var sinceSave = 0;
    var created = 0;
    try {
      for (final event in changes.delete) {
        await backend.deleteEvent(event.id);
        remaining.remove(event);
        if (++sinceSave >= 10) {
          sinceSave = 0;
          await save();
        }
      }
      for (final event in changes.create) {
        final eventId = await backend.createEvent(
          calendarId: id,
          title: event.title,
          start: event.start,
          end: event.end,
          description: description,
        );
        tracked.add(
          TrackedPrayerEvent(
            id: eventId,
            start: event.start,
            title: event.title,
          ),
        );
        created++;
        if (++sinceSave >= 10) {
          sinceSave = 0;
          await save();
        }
      }
    } on PrayerCalendarMissing {
      // Deleted on the phone, or its account removed: nothing left to keep
      // up to date.
      _lostCalendar = true;
      await SP.prefs.remove(calendarIdKey);
      await SP.prefs.remove(calendarNameKey);
      await SP.prefs.remove(eventsKey);
    } finally {
      if (isOn) await save();
    }
    return created;
  }

  Future<int> _deleteAll() async {
    final remaining = _tracked();
    final count = remaining.length;
    while (remaining.isNotEmpty) {
      await backend.deleteEvent(remaining.first.id);
      remaining.removeAt(0);
      if (remaining.length % 10 == 0) await _saveTracked(remaining);
    }
    await SP.prefs.remove(eventsKey);
    return count;
  }

  List<TrackedPrayerEvent> _tracked() {
    final raw = SP.isInitialized ? SP.prefs.getString(eventsKey) : null;
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [for (final item in decoded) ?TrackedPrayerEvent.fromJson(item)];
    } catch (e) {
      debugPrint('Could not read the prayer calendar events: $e');
      return [];
    }
  }

  Future<void> _saveTracked(List<TrackedPrayerEvent> events) =>
      SP.prefs.setString(
        eventsKey,
        jsonEncode([for (final event in events) event.toJson()]),
      );

  List<String> _ordered(Set<String> ids) => [
    for (final time in widgetPrayerTimes)
      if (ids.contains(time.id)) time.id,
  ];
}
