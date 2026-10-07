import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/islamic_day.dart';

void main() {
  // As in night_window_test: UTC on the Greenwich meridian at the equator,
  // so the prayer times match the clock on any machine. Fajr falls a little
  // before 5 am and Maghrib a little before 7 pm.
  final today = DateTime.utc(2024, 6, 16);
  final tomorrow = DateTime.utc(2024, 6, 17);

  IslamicDay at(DateTime now, {bool located = true, int offset = 0}) =>
      islamicDayAt(
        now,
        prayerTime: getPrayerTimeObject(),
        latitude: located ? 0.0 : null,
        longitude: located ? 0.0 : null,
        useAppLocation: false,
        hijriOffsetDays: offset,
      );

  int hijriDayOf(DateTime date, [int offset = 0]) =>
      HijriCalendar.fromDate(date.add(Duration(days: offset))).hDay;

  test('the daytime is the civil day, not an eve', () {
    final day = at(today.add(const Duration(hours: 12)));
    expect(day.isEve, isFalse);
    expect(day.day.civilDate, DateTime.utc(2024, 6, 16));
    expect(day.day.hijri.hDay, hijriDayOf(today));
  });

  test('from Maghrib it is the eve of the next day', () {
    final day = at(today.add(const Duration(hours: 21)));
    expect(day.isEve, isTrue);
    expect(day.day.civilDate, DateTime.utc(2024, 6, 17));
    expect(day.day.hijri.hDay, hijriDayOf(tomorrow));
  });

  test('the eve lasts until Fajr', () {
    final day = at(tomorrow.add(const Duration(hours: 2)));
    expect(day.isEve, isTrue);
    expect(day.day.civilDate, DateTime.utc(2024, 6, 17));
    expect(day.day.hijri.hDay, hijriDayOf(tomorrow));
  });

  test('without a location the date turns at midnight and is never an eve',
      () {
    for (final hour in [2, 12, 21, 23]) {
      final day = at(today.add(Duration(hours: hour)), located: false);
      expect(day.isEve, isFalse, reason: '$hour:00');
      expect(day.day.civilDate, DateTime.utc(2024, 6, 16), reason: '$hour:00');
    }
  });

  test('the moon-sighting offset moves the date, not the eve', () {
    final day = at(today.add(const Duration(hours: 21)), offset: -1);
    expect(day.isEve, isTrue);
    expect(day.day.hijri.hDay, hijriDayOf(tomorrow, -1));
  });
}
