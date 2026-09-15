import 'dart:convert';

/// Whether a [ZikrReminder] fires at a clock time the user picked, or at an
/// offset from a prayer time that shifts with the calendar and location.
enum ZikrReminderTimeMode {
  fixedTime,
  relativeToPrayer,
}

/// A user-defined reminder to recite a particular zikr/dua on one or more
/// days of the week — e.g. Tawassul every Tuesday night, or Dua Kumail 30
/// minutes after Maghrib on Thursday.
///
/// [daysOfWeek] uses `DateTime.monday`(1) .. `DateTime.sunday`(7), matching
/// the rest of the app's own weekday handling.
///
/// [notificationBaseId] is allocated once, at creation, from
/// `ZikrReminderService` and reserves a fixed block of local-notification ids
/// for this reminder (see `zikrReminderIdSlotsPerReminder`) so scheduling can
/// cancel and rebuild just this reminder's notifications without touching
/// anyone else's.
class ZikrReminder {
  const ZikrReminder({
    required this.id,
    required this.notificationBaseId,
    required this.title,
    this.zikrUid,
    required this.daysOfWeek,
    required this.mode,
    this.hour = 21,
    this.minute = 0,
    this.prayerName = 'Maghrib',
    this.offsetMinutes = 30,
    this.enabled = true,
  });

  /// Locally-generated, stable identifier — not a server id.
  final String id;

  final int notificationBaseId;

  /// What the notification (and the reminders list) shows. Pre-filled from
  /// the picked zikr's title when there is one, but always editable — some
  /// reminders (Dua Nudbah, Tawassul) are named things the zikr library
  /// itself may not title exactly that way.
  final String title;

  /// The linked zikr's uid, if the reminder was created by picking one from
  /// the library. Null for a free-text reminder.
  final String? zikrUid;

  /// `DateTime.monday`(1) through `DateTime.sunday`(7). Never empty for a
  /// reminder that is actually scheduled.
  final Set<int> daysOfWeek;

  final ZikrReminderTimeMode mode;

  /// 24-hour clock time, used when [mode] is [ZikrReminderTimeMode.fixedTime].
  final int hour;
  final int minute;

  /// One of `getPrayerNotificationPrayerNames()` (Fajr, Sunrise, Zuhr, Asr,
  /// Sunset, Maghrib, Isha, Midnight), used when [mode] is
  /// [ZikrReminderTimeMode.relativeToPrayer].
  final String prayerName;

  /// Minutes from [prayerName]'s time; negative fires before it, positive
  /// after. Used when [mode] is [ZikrReminderTimeMode.relativeToPrayer].
  final int offsetMinutes;

  final bool enabled;

  ZikrReminder copyWith({
    String? title,
    String? zikrUid,
    bool clearZikrUid = false,
    Set<int>? daysOfWeek,
    ZikrReminderTimeMode? mode,
    int? hour,
    int? minute,
    String? prayerName,
    int? offsetMinutes,
    bool? enabled,
  }) {
    return ZikrReminder(
      id: id,
      notificationBaseId: notificationBaseId,
      title: title ?? this.title,
      zikrUid: clearZikrUid ? null : (zikrUid ?? this.zikrUid),
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      mode: mode ?? this.mode,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      prayerName: prayerName ?? this.prayerName,
      offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      enabled: enabled ?? this.enabled,
    );
  }

  /// "9:00 PM" for a fixed time, or "30 min after Maghrib" / "At Maghrib" /
  /// "15 min before Fajr" for a prayer-relative one.
  String get timeLabel {
    if (mode == ZikrReminderTimeMode.fixedTime) {
      final hour12 = ((hour + 11) % 12) + 1;
      final suffix = hour >= 12 ? 'PM' : 'AM';
      final minuteLabel = minute.toString().padLeft(2, '0');
      return '$hour12:$minuteLabel $suffix';
    }

    if (offsetMinutes == 0) return 'At $prayerName';
    final magnitude = offsetMinutes.abs();
    final direction = offsetMinutes > 0 ? 'after' : 'before';
    return '$magnitude min $direction $prayerName';
  }

  static const List<String> _weekdayShortLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// "Tue" or "Tue, Fri" — always in Monday-first order regardless of
  /// insertion order.
  String get daysLabel {
    final sortedDays = daysOfWeek.toList()..sort();
    return sortedDays
        .map((day) => _weekdayShortLabels[(day - 1).clamp(0, 6)])
        .join(', ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'notificationBaseId': notificationBaseId,
        'title': title,
        'zikrUid': zikrUid,
        'daysOfWeek': (daysOfWeek.toList()..sort()),
        'mode': mode.name,
        'hour': hour,
        'minute': minute,
        'prayerName': prayerName,
        'offsetMinutes': offsetMinutes,
        'enabled': enabled,
      };

  /// Parses one reminder, tolerating anything malformed by returning null —
  /// one bad entry should cost itself, not the whole stored list.
  static ZikrReminder? fromJson(Map<dynamic, dynamic> json) {
    try {
      final id = json['id']?.toString().trim();
      final title = json['title']?.toString().trim();
      final notificationBaseId = json['notificationBaseId'];
      if (id == null ||
          id.isEmpty ||
          title == null ||
          title.isEmpty ||
          notificationBaseId is! int) {
        return null;
      }

      final days = <int>{};
      final rawDays = json['daysOfWeek'];
      if (rawDays is List) {
        for (final rawDay in rawDays) {
          final day =
              rawDay is int ? rawDay : int.tryParse(rawDay.toString());
          if (day != null && day >= DateTime.monday && day <= DateTime.sunday) {
            days.add(day);
          }
        }
      }

      final mode = ZikrReminderTimeMode.values.firstWhere(
        (value) => value.name == json['mode'],
        orElse: () => ZikrReminderTimeMode.fixedTime,
      );

      final hour = json['hour'];
      final minute = json['minute'];
      final offsetMinutes = json['offsetMinutes'];

      return ZikrReminder(
        id: id,
        notificationBaseId: notificationBaseId,
        title: title,
        zikrUid: json['zikrUid']?.toString(),
        daysOfWeek: days,
        mode: mode,
        hour: hour is int && hour >= 0 && hour <= 23 ? hour : 21,
        minute: minute is int && minute >= 0 && minute <= 59 ? minute : 0,
        prayerName: json['prayerName']?.toString().trim().isNotEmpty == true
            ? json['prayerName'].toString().trim()
            : 'Maghrib',
        offsetMinutes: offsetMinutes is int ? offsetMinutes : 30,
        enabled: json['enabled'] != false,
      );
    } catch (_) {
      return null;
    }
  }

  static List<ZikrReminder> listFrom(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      final parsed = jsonDecode(encoded);
      if (parsed is! List) return const [];
      return [
        for (final entry in parsed)
          if (entry is Map) ZikrReminder.fromJson(entry),
      ].whereType<ZikrReminder>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static String encodeList(List<ZikrReminder> reminders) {
    return jsonEncode(reminders.map((reminder) => reminder.toJson()).toList());
  }
}
