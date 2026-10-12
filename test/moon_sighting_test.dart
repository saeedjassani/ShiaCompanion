import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_array.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/hijri_date.dart';
import 'package:shia_companion/utils/moon_sighting.dart';

const _najaf = (latitude: 32.0, longitude: 44.33);

/// The modified chronological Julian day number the hijri package counts
/// days in.
int _mcjdn(int year, int month, int day) => DateTime.utc(year, month, day)
    .difference(DateTime.utc(1858, 11, 16))
    .inDays;

/// The Julian date (UT) of a moment.
double _jd(DateTime utc) => utc.millisecondsSinceEpoch / 86400000 + 2440587.5;

void main() {
  tearDown(() => useHijriMonthStarts(const {}));

  group('positions', () {
    test('the Moon matches Meeus example 47.a', () {
      // 1992 April 12, 0h TD.
      final moon = moonPosition(2448724.5 - 59 / 86400);
      expect(moon.longitude, closeTo(133.162655, 0.001));
      expect(moon.latitude, closeTo(-3.229126, 0.001));
      expect(moon.parallax, closeTo(0.991990, 0.0001));
    });

    test('new moons land within a couple of minutes of PyEphem', () {
      // Times from PyEphem's next_new_moon.
      for (final expected in [
        DateTime.utc(2024, 1, 11, 11, 57, 22),
        DateTime.utc(2025, 2, 28, 0, 44, 46),
        DateTime.utc(2026, 3, 19, 1, 23, 25),
      ]) {
        final found = newMoonNear(_jd(expected) + 1.3);
        expect((found - _jd(expected)) * 1440, closeTo(0, 2),
            reason: '$expected');
      }
    });
  });

  group('Yallop', () {
    test('the Shaban 1446 evenings in Najaf: too young, then plain', () {
      final conjunction = _jd(DateTime.utc(2025, 2, 28, 0, 44, 46));
      double? q(int month, int day) => yallopQ(
            jdn: _mcjdn(2025, month, day) + 2400000,
            latitude: _najaf.latitude,
            longitude: _najaf.longitude,
            conjunction: conjunction,
          );
      // 28 February: about 15 hours old at sunset, not for the naked eye.
      expect(q(2, 28), lessThan(yallopNakedEyeLimit));
      // 1 March: a day and a half old, easily seen (Yallop's zone A).
      expect(q(3, 1), greaterThan(0.216));
    });

    test('no crescent on an evening before the new moon', () {
      final conjunction = _jd(DateTime.utc(2025, 2, 28, 0, 44, 46));
      expect(
        yallopQ(
          jdn: _mcjdn(2025, 2, 27) + 2400000,
          latitude: _najaf.latitude,
          longitude: _najaf.longitude,
          conjunction: conjunction,
        ),
        isNull,
      );
    });
  });

  group('predictedHijriMonthStarts', () {
    final starts = predictedHijriMonthStarts(
      latitude: _najaf.latitude,
      longitude: _najaf.longitude,
      around: DateTime(2026, 10, 12),
    );

    int startOf(int year, int month) =>
        starts[(year - 1) * 12 + month - 1] ??
        ummAlquraDateArray[(year - 1) * 12 + month - 1 - 16260];

    test('agrees with what was announced in Najaf', () {
      // Ramadan and Shawwal 1446, and Shawwal 1447, which Sayyid Sistani's
      // office announced for 21 March 2026 - a day after Saudi Arabia.
      expect(startOf(1446, 9), _mcjdn(2025, 3, 2));
      expect(startOf(1446, 10), _mcjdn(2025, 3, 31));
      expect(startOf(1447, 10), _mcjdn(2026, 3, 21));
    });

    test('keeps every month 29 or 30 days, Umm al-Qura on either side', () {
      final keys = starts.keys.toList()..sort();
      expect(keys.length, greaterThan(50));
      final first = keys.first - hijriAdjustmentKeyOffset;
      final last = keys.last - hijriAdjustmentKeyOffset;
      int start(int index) =>
          starts[index + hijriAdjustmentKeyOffset] ?? ummAlquraDateArray[index];
      for (var index = first - 1; index <= last + 1; index++) {
        expect(start(index + 1) - start(index), inInclusiveRange(29, 30),
            reason: 'month index $index');
      }
      // It ends on a month Umm al-Qura starts on the same day.
      expect(starts[keys.last], ummAlquraDateArray[last]);
    });

    test('never ends a month early near the poles', () {
      final polar = predictedHijriMonthStarts(
        latitude: 69.6,
        longitude: 18.9,
        around: DateTime(2026, 6, 21),
      );
      final keys = polar.keys.toList()..sort();
      for (final key in keys.skip(1)) {
        final previous = polar[key - 1];
        if (previous == null) continue;
        expect(polar[key]! - previous, inInclusiveRange(29, 30));
      }
    });
  });

  group('hijriForCivilDate', () {
    test('Umm al-Qura with no month starts in effect', () {
      final eid = hijriForCivilDate(DateTime(2026, 3, 20));
      expect([eid.hYear, eid.hMonth, eid.hDay], [1447, 10, 1]);
    });

    test('counts in the month starts in effect', () {
      useHijriMonthStarts(predictedHijriMonthStarts(
        latitude: _najaf.latitude,
        longitude: _najaf.longitude,
        around: DateTime(2026, 3, 1),
      ));
      final lastOfRamadan = hijriForCivilDate(DateTime(2026, 3, 20));
      expect([lastOfRamadan.hYear, lastOfRamadan.hMonth, lastOfRamadan.hDay],
          [1447, 9, 30]);
      final eid = hijriForCivilDate(DateTime(2026, 3, 21));
      expect([eid.hYear, eid.hMonth, eid.hDay], [1447, 10, 1]);
      // The manual offset still moves the date on top.
      final moved = hijriForCivilDate(DateTime(2026, 3, 20), offsetDays: 1);
      expect([moved.hMonth, moved.hDay], [10, 1]);
    });

    test('a day the clocks go back on is still one day', () {
      final before = hijriForCivilDate(DateTime(2026, 10, 24), offsetDays: 1);
      final day = hijriForCivilDate(DateTime(2026, 10, 25));
      expect([before.hMonth, before.hDay], [day.hMonth, day.hDay]);
    });
  });

  group('settings', () {
    late bool originalAutomatic;
    late int originalOffset;
    late double? originalLat, originalLong;

    setUp(() {
      originalAutomatic = hijriAutomatic;
      originalOffset = hijriDate;
      originalLat = lat;
      originalLong = long;
    });

    tearDown(() {
      hijriAutomatic = originalAutomatic;
      hijriDate = originalOffset;
      lat = originalLat;
      long = originalLong;
      applyHijriSighting();
    });

    test('Automatic is the default unless the date was moved by hand', () {
      expect(defaultHijriAutomatic(null), isTrue);
      expect(defaultHijriAutomatic(0), isTrue);
      expect(defaultHijriAutomatic(1), isFalse);
      expect(defaultHijriAutomatic(-2), isFalse);
    });

    test('Automatic ignores the manual offset and follows the location', () {
      hijriDate = 2;
      hijriAutomatic = true;
      lat = _najaf.latitude;
      long = _najaf.longitude;
      applyHijriSighting();
      expect(hijriOffsetInEffect, 0);
      expect(hijriMonthStartsInEffect, isNotEmpty);

      hijriAutomatic = false;
      applyHijriSighting();
      expect(hijriOffsetInEffect, 2);
      expect(hijriMonthStartsInEffect, isEmpty);
    });

    test('Automatic without a location stays on Umm al-Qura', () {
      hijriAutomatic = true;
      lat = null;
      long = null;
      applyHijriSighting();
      expect(hijriMonthStartsInEffect, isEmpty);
      expect(hijriOffsetInEffect, 0);
    });
  });
}
