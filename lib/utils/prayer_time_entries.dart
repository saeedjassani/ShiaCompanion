import 'package:shia_companion/utils/prayer_times.dart';
import 'package:timezone/timezone.dart' as tz;

const int prayerIndexFajr = 0;
const int prayerIndexSunrise = 1;
const int prayerIndexZuhr = 2;
const int prayerIndexAsr = 3;
const int prayerIndexSunset = 4;
const int prayerIndexMaghrib = 5;
const int prayerIndexIsha = 6;

class PrayerTimeDisplayEntry {
  const PrayerTimeDisplayEntry({
    required this.name,
    required this.time,
    this.notificationPrayerName,
  });

  final String name;
  final String time;
  final String? notificationPrayerName;

  bool get canNotify => notificationPrayerName != null;
}

List<PrayerTimeDisplayEntry> buildExtendedPrayerTimeEntries({
  required PrayerTime prayerTime,
  required DateTime date,
  required double latitude,
  required double longitude,
  required double timeZone,
}) {
  final originalFormat = prayerTime.getTimeFormat();
  try {
    prayerTime.setTimeFormat(prayerTime.getTime12());
    final names = prayerTime.getTimeNames();
    final times =
        prayerTime.getPrayerTimes(date, latitude, longitude, timeZone);
    final entries = <PrayerTimeDisplayEntry>[
      for (var index = 0; index < names.length; index++)
        PrayerTimeDisplayEntry(
          name: names[index],
          time: times[index],
          notificationPrayerName: names[index],
        ),
    ];

    final midnight = shiaMidnightForDate(
      prayerTime: prayerTime,
      date: date,
      latitude: latitude,
      longitude: longitude,
    );
    if (midnight != null) {
      entries.add(PrayerTimeDisplayEntry(
        name: 'Midnight',
        time: formatPrayerDateTime12(midnight),
        notificationPrayerName: 'Midnight',
      ));
    }

    return entries;
  } finally {
    prayerTime.setTimeFormat(originalFormat);
  }
}

DateTime? shiaMidnightForDate({
  required PrayerTime prayerTime,
  required DateTime date,
  required double latitude,
  required double longitude,
}) {
  final originalFormat = prayerTime.getTimeFormat();
  try {
    prayerTime.setTimeFormat(prayerTime.getTime24());
    // Not `date.add(Duration(days: 1))`: across a daylight-saving change a
    // day is 23 or 25 hours, and 24 from midnight can land on the same date.
    final nextDate = dateTimeOnClockOf(
        date, date.year, date.month, date.day + 1, date.hour, date.minute);
    final todayTimes = prayerTime.getPrayerTimes(
      date,
      latitude,
      longitude,
      prayerTimeZoneFor(date),
    );
    final nextDayTimes = prayerTime.getPrayerTimes(
      nextDate,
      latitude,
      longitude,
      prayerTimeZoneFor(nextDate),
    );
    final sunset = dateTimeForTime24(date, todayTimes[prayerIndexSunset]);
    final nextFajr = dateTimeForTime24(
      nextDate,
      nextDayTimes[prayerIndexFajr],
    );
    if (sunset == null || nextFajr == null || !nextFajr.isAfter(sunset)) {
      return null;
    }

    // Shia midnight is halfway from sunset to true dawn.
    final nightLength = nextFajr.difference(sunset);
    return sunset.add(Duration(milliseconds: nightLength.inMilliseconds ~/ 2));
  } finally {
    prayerTime.setTimeFormat(originalFormat);
  }
}

DateTime? dateTimeForTime24(DateTime date, String time24) {
  final parts = time24.split(':');
  if (parts.length != 2) return null;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;

  return dateTimeOnClockOf(date, date.year, date.month, date.day, hour, minute);
}

/// The UTC offset, in hours, that [date]'s prayer times are worked out in:
/// the one at noon that day, on [date]'s clock.
///
/// Not [date]'s own offset: a day's date is usually its midnight, before the
/// clocks change at 1-3 am, so on the day daylight saving starts or ends that
/// put every prayer an hour out. Every other day the two are the same.
double prayerTimeZoneFor(DateTime date) =>
    dateTimeOnClockOf(date, date.year, date.month, date.day, 12)
        .timeZoneOffset
        .inMinutes /
    60.0;

/// [year]-[month]-[day] [hour]:[minute] on the same clock as [like]: UTC, a
/// city's (a [tz.TZDateTime]) or the phone's.
///
/// Keep whichever zone the caller handed us. Building a local DateTime from a
/// UTC one silently shifts the result by the machine's offset, which makes any
/// comparison against a UTC instant wrong everywhere except UTC itself - and
/// the same goes for a city's clock against the phone's.
DateTime dateTimeOnClockOf(
  DateTime like,
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
]) {
  if (like is tz.TZDateTime) {
    return tz.TZDateTime(like.location, year, month, day, hour, minute);
  }
  return like.isUtc
      ? DateTime.utc(year, month, day, hour, minute)
      : DateTime(year, month, day, hour, minute);
}

String formatPrayerDateTime12(DateTime dateTime) {
  final suffix = dateTime.hour >= 12 ? 'pm' : 'am';
  final hour = ((dateTime.hour + 11) % 12) + 1;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${hour.toString().padLeft(2, '0')}:$minute $suffix';
}
