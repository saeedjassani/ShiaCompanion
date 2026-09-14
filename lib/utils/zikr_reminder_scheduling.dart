import 'package:shia_companion/constants.dart';
import 'package:shia_companion/models/zikr_reminder.dart';
import 'package:shia_companion/utils/prayer_times.dart';

/// Local-notification ids reserved per zikr reminder, starting at its
/// `notificationBaseId`. A fixed-time reminder uses one id per selected day;
/// a prayer-relative one uses up to [zikrReminderRelativeOccurrenceCount] ids
/// per selected day (one per upcoming occurrence). 100 comfortably covers the
/// worst case — all 7 days, [zikrReminderRelativeOccurrenceCount] occurrences
/// each is 70 ids — while leaving room to raise the occurrence count later
/// without a migration.
const int zikrReminderIdSlotsPerReminder = 100;

/// How many upcoming occurrences a prayer-relative reminder schedules per
/// selected day. Prayer times shift daily, so — unlike a fixed-time reminder,
/// which recurs forever from one `zonedSchedule` call — these have to be
/// precomputed as one-off notifications and refreshed periodically. The app
/// already reschedules on every cold start and on a meaningful location
/// change, so this only needs to outlast a reasonably long gap between opens.
const int zikrReminderRelativeOccurrenceCount = 5;

/// The most notification ids zikr reminders are ever allowed to claim from
/// iOS's 64-pending-notification cap.
///
/// That cap is shared with Azan: `setUpNotifications` already schedules up to
/// 63 prayer notifications plus a "come back to the app" reminder, which can
/// leave nothing for reminders on a device with several prayers enabled. So
/// the two sides split the budget instead of each assuming it owns all of
/// it — see [zikrReminderIdealNotificationDemand] (what Azan gives up) and
/// [zikrReminderRelativeOccurrenceCountFor] (how reminders live within that)
/// — sized so that even at 8 enabled prayers, Azan's own floor of at least
/// one scheduled day never has to compete with this for room.
const int zikrReminderMaxIosNotificationBudget = 16;

/// How many notification ids the given reminders would use if every
/// prayer-relative one got the full [zikrReminderRelativeOccurrenceCount]
/// occurrences and every fixed-time one its single recurring id.
///
/// This is the *ideal* figure, used only to decide how much of the shared iOS
/// budget Azan should give up (see [zikrReminderMaxIosNotificationBudget]) —
/// the actual schedule may use fewer, once
/// [zikrReminderRelativeOccurrenceCountFor] trims prayer-relative reminders
/// to fit.
int zikrReminderIdealNotificationDemand(Iterable<ZikrReminder> reminders) {
  var total = 0;
  for (final reminder in reminders) {
    if (!reminder.enabled || reminder.daysOfWeek.isEmpty) continue;
    final perDay = reminder.mode == ZikrReminderTimeMode.fixedTime
        ? 1
        : zikrReminderRelativeOccurrenceCount;
    total += reminder.daysOfWeek.length * perDay;
  }
  return total;
}

/// How many upcoming occurrences each prayer-relative reminder-day should
/// actually schedule so the whole set — plus every fixed-time reminder's
/// single id, always honoured in full since that's the cheap case and it
/// recurs forever on its own — fits within [budget] ids.
///
/// Never returns less than 1: a configured reminder always fires at its next
/// occurrence at minimum, however tight the budget.
int zikrReminderRelativeOccurrenceCountFor({
  required Iterable<ZikrReminder> reminders,
  required int budget,
}) {
  var fixedDemand = 0;
  var relativeDayCount = 0;
  for (final reminder in reminders) {
    if (!reminder.enabled || reminder.daysOfWeek.isEmpty) continue;
    if (reminder.mode == ZikrReminderTimeMode.fixedTime) {
      fixedDemand += reminder.daysOfWeek.length;
    } else {
      relativeDayCount += reminder.daysOfWeek.length;
    }
  }
  if (relativeDayCount == 0) return zikrReminderRelativeOccurrenceCount;

  final remaining = budget - fixedDemand;
  final perDay = remaining ~/ relativeDayCount;
  return perDay.clamp(1, zikrReminderRelativeOccurrenceCount);
}

/// The local-notification id for one occurrence of a reminder.
///
/// [weekday] is `DateTime.monday`(1)..`DateTime.sunday`(7) and
/// [occurrenceIndex] is 0 for a fixed-time reminder (it needs only one id per
/// day) or 0..([zikrReminderRelativeOccurrenceCount] - 1) for a
/// prayer-relative one.
int zikrReminderNotificationId({
  required int baseId,
  required int weekday,
  required int occurrenceIndex,
}) {
  assert(weekday >= DateTime.monday && weekday <= DateTime.sunday);
  assert(occurrenceIndex >= 0 && occurrenceIndex < 10);
  return baseId + weekday * 10 + occurrenceIndex;
}

/// The next date/time, strictly after [now], that falls on [weekday] at
/// [hour]:[minute]. Used as the anchor for a `zonedSchedule` call with
/// `matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime`, which then
/// recurs on its own every week.
DateTime nextInstanceOfWeekdayAndTime(
  DateTime now,
  int weekday,
  int hour,
  int minute,
) {
  var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
  while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}

/// The next [count] times a given prayer (plus [offsetMinutes]) falls on
/// [weekday], starting from [now].
///
/// Reuses [buildPrayerNotificationEntriesForDay] — the same prayer-time
/// computation the Azan notifications schedule from — so a Maghrib-relative
/// zikr reminder and the Maghrib Azan notification always agree on when
/// Maghrib actually is.
List<DateTime> upcomingPrayerRelativeOccurrences({
  required PrayerTime prayerTime,
  required DateTime now,
  required int weekday,
  required String prayerName,
  required int offsetMinutes,
  required double latitude,
  required double longitude,
  required int count,
  int maxDaysToScan = 90,
}) {
  final results = <DateTime>[];
  final today = DateTime(now.year, now.month, now.day);

  for (var offset = 0;
      offset < maxDaysToScan && results.length < count;
      offset++) {
    final date = today.add(Duration(days: offset));
    if (date.weekday != weekday) continue;

    final entries = buildPrayerNotificationEntriesForDay(
      prayerTime: prayerTime,
      date: date,
      latitude: latitude,
      longitude: longitude,
    );

    PrayerNotificationScheduleEntry? entry;
    for (final candidate in entries) {
      if (candidate.name == prayerName) {
        entry = candidate;
        break;
      }
    }
    if (entry == null) continue;

    final scheduled = entry.dateTime.add(Duration(minutes: offsetMinutes));
    if (scheduled.isAfter(now)) results.add(scheduled);
  }

  return results;
}
