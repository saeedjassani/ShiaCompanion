import 'package:shia_companion/utils/prayer_times.dart';

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

List<PrayerTimeDisplayEntry> buildFiveDailyPrayerTimeEntries({
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
    final indices = [
      prayerIndexFajr,
      prayerIndexZuhr,
      prayerIndexAsr,
      prayerIndexMaghrib,
      prayerIndexIsha,
    ];

    return [
      for (final index in indices)
        PrayerTimeDisplayEntry(
          name: names[index],
          time: times[index],
          notificationPrayerName: names[index],
        ),
    ];
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
    final nextDate = date.add(const Duration(days: 1));
    final todayTimes = prayerTime.getPrayerTimes(
      date,
      latitude,
      longitude,
      date.timeZoneOffset.inMinutes / 60.0,
    );
    final nextDayTimes = prayerTime.getPrayerTimes(
      nextDate,
      latitude,
      longitude,
      nextDate.timeZoneOffset.inMinutes / 60.0,
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

  return DateTime(date.year, date.month, date.day, hour, minute);
}

String formatPrayerDateTime12(DateTime dateTime) {
  final suffix = dateTime.hour >= 12 ? 'pm' : 'am';
  final hour = ((dateTime.hour + 11) % 12) + 1;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${hour.toString().padLeft(2, '0')}:$minute $suffix';
}
