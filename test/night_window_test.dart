import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/utils/lunar_date_matcher.dart';
import 'package:shia_companion/utils/night_window.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/prayer_times.dart';

PrayerTime _configuredPrayerTime() {
  final prayerTime = PrayerTime();
  prayerTime.setCalcMethod(prayerTime.getJafari());
  prayerTime.setAsrJuristic(prayerTime.getHanafi());
  prayerTime.setAdjustHighLats(prayerTime.getAngleBased());
  return prayerTime;
}

void main() {
  // The prayer-time calculator needs a timezone offset that actually
  // matches the given coordinates (in the real app this holds naturally,
  // since a device's local clock and its own location agree). For a test
  // that must be deterministic on any machine, use UTC paired with the
  // Greenwich-meridian equator, so the offset is always a correct 0.
  const latitude = 0.0;
  const longitude = 0.0;

  final prayerTime = _configuredPrayerTime();
  final today = DateTime.utc(2024, 6, 16);
  final timeZone = today.timeZoneOffset.inMinutes / 60.0;
  final times = prayerTime.getPrayerTimes(today, latitude, longitude, timeZone);
  final fajr = dateTimeForTime24(today, times[prayerIndexFajr])!;
  final maghrib = dateTimeForTime24(today, times[prayerIndexMaghrib])!;

  group('without a location, falls back to 16:00 - 08:00', () {
    LunarDay? at(int hour) => resolveNightLunarDay(
          now: today.add(Duration(hours: hour)),
          prayerTime: prayerTime,
        );
    final todayHijri = HijriCalendar.fromDate(today);
    final tomorrowHijri =
        HijriCalendar.fromDate(today.add(const Duration(days: 1)));

    test('before 08:00 is still last night', () {
      expect(at(7)?.hijri.hDay, todayHijri.hDay);
    });

    test('the daytime has no open night window', () {
      expect(at(8), isNull);
      expect(at(15), isNull);
    });

    test('from 16:00 tonight is tomorrow\'s Hijri date', () {
      expect(at(16)?.hijri.hDay, tomorrowHijri.hDay);
      expect(at(23)?.hijri.hDay, tomorrowHijri.hDay);
    });
  });

  test('daytime (between Fajr and Maghrib) has no open night window', () {
    final midday = fajr.add(maghrib.difference(fajr) ~/ 2);
    expect(
      resolveNightLunarDay(
        now: midday,
        prayerTime: prayerTime,
        latitude: latitude,
        longitude: longitude,
      ),
      isNull,
    );
  });

  test('before Fajr: still last night, so today\'s Hijri date applies', () {
    final beforeDawn = fajr.subtract(const Duration(minutes: 5));
    final result = resolveNightLunarDay(
      now: beforeDawn,
      prayerTime: prayerTime,
      latitude: latitude,
      longitude: longitude,
    );
    final expected = HijriCalendar.fromDate(today);
    expect(result?.hijri.hMonth, expected.hMonth);
    expect(result?.hijri.hDay, expected.hDay);
  });

  test('from Maghrib onward: tonight is already tomorrow\'s Hijri date', () {
    final afterSunset = maghrib.add(const Duration(minutes: 5));
    final result = resolveNightLunarDay(
      now: afterSunset,
      prayerTime: prayerTime,
      latitude: latitude,
      longitude: longitude,
    );
    final expected = HijriCalendar.fromDate(today.add(const Duration(days: 1)));
    expect(result?.hijri.hMonth, expected.hMonth);
    expect(result?.hijri.hDay, expected.hDay);
  });

  test('a manual Hijri-date correction shifts the resolved night date', () {
    final afterSunset = maghrib.add(const Duration(minutes: 5));
    final result = resolveNightLunarDay(
      now: afterSunset,
      prayerTime: prayerTime,
      latitude: latitude,
      longitude: longitude,
      hijriDateOffsetDays: 1,
    );
    final expected = HijriCalendar.fromDate(
      today.add(const Duration(days: 2)),
    );
    expect(result?.hijri.hMonth, expected.hMonth);
    expect(result?.hijri.hDay, expected.hDay);
  });

  test('the night carries the civil day it leads into, whatever the offset',
      () {
    final afterSunset = maghrib.add(const Duration(minutes: 5));
    for (final offset in [-1, 0, 1]) {
      final result = resolveNightLunarDay(
        now: afterSunset,
        prayerTime: prayerTime,
        latitude: latitude,
        longitude: longitude,
        hijriDateOffsetDays: offset,
      );
      expect(result?.civilDate, today.add(const Duration(days: 1)));
    }
  });
}
