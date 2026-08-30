import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
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
  final times =
      prayerTime.getPrayerTimes(today, latitude, longitude, timeZone);
  final fajr = dateTimeForTime24(today, times[prayerIndexFajr])!;
  final maghrib = dateTimeForTime24(today, times[prayerIndexMaghrib])!;

  test('returns null without a location', () {
    expect(
      resolveNightAdjustedHijriDate(now: fajr, prayerTime: prayerTime),
      isNull,
    );
  });

  test('daytime (between Fajr and Maghrib) has no open night window', () {
    final midday = fajr.add(maghrib.difference(fajr) ~/ 2);
    expect(
      resolveNightAdjustedHijriDate(
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
    final result = resolveNightAdjustedHijriDate(
      now: beforeDawn,
      prayerTime: prayerTime,
      latitude: latitude,
      longitude: longitude,
    );
    final expected = HijriCalendar.fromDate(today);
    expect(result?.hMonth, expected.hMonth);
    expect(result?.hDay, expected.hDay);
  });

  test('from Maghrib onward: tonight is already tomorrow\'s Hijri date', () {
    final afterSunset = maghrib.add(const Duration(minutes: 5));
    final result = resolveNightAdjustedHijriDate(
      now: afterSunset,
      prayerTime: prayerTime,
      latitude: latitude,
      longitude: longitude,
    );
    final expected =
        HijriCalendar.fromDate(today.add(const Duration(days: 1)));
    expect(result?.hMonth, expected.hMonth);
    expect(result?.hDay, expected.hDay);
  });

  test('a manual Hijri-date correction shifts the resolved night date', () {
    final afterSunset = maghrib.add(const Duration(minutes: 5));
    final result = resolveNightAdjustedHijriDate(
      now: afterSunset,
      prayerTime: prayerTime,
      latitude: latitude,
      longitude: longitude,
      hijriDateOffsetDays: 1,
    );
    final expected = HijriCalendar.fromDate(
      today.add(const Duration(days: 2)),
    );
    expect(result?.hMonth, expected.hMonth);
    expect(result?.hDay, expected.hDay);
  });
}
