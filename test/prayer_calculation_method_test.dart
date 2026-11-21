import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/prayer_calculation_method.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

/// Minutes past midnight of each of [PrayerTime.getTimeNames]' times.
List<double> _minutes(PrayerTime prayerTime) {
  final original = prayerTime.getTimeFormat();
  prayerTime.setTimeFormat(prayerTime.getFloating());
  try {
    // Qum, on a spring day.
    return prayerTime
        .getPrayerTimes(DateTime(2026, 3, 21), 34.6401, 50.8764, 3.5)
        .map((hours) => double.parse(hours) * 60)
        .toList();
  } finally {
    prayerTime.setTimeFormat(original);
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    await SP.init();
    restorePrayerCalculationMethod();
  });

  tearDown(
    () => prayerCalculationMethod.value = PrayerCalculationMethod.jafari,
  );

  test('the app keeps the Leva Institute (Jafari) method until changed', () {
    expect(prayerCalculationMethod.value, PrayerCalculationMethod.jafari);
    final prayerTime = getPrayerTimeObject();
    expect(prayerTime.getCalcMethod(), prayerTime.getJafari());
  });

  test('a chosen method is saved, restored and used for the times', () async {
    final jafari = _minutes(getPrayerTimeObject());

    await setPrayerCalculationMethod(PrayerCalculationMethod.tehran);
    expect(SP.prefs.getString(prayerCalculationMethodKey), 'tehran');
    final prayerTime = getPrayerTimeObject();
    expect(prayerTime.getCalcMethod(), prayerTime.getTehran());
    final tehran = _minutes(prayerTime);

    // Fajr at 17.7° comes before Fajr at 16°; Maghrib at 4.5° after 4°.
    expect(tehran[0], lessThan(jafari[0] - 5));
    expect(tehran[5], greaterThan(jafari[5]));
    expect(tehran[5] - jafari[5], lessThan(5));
    // Sunrise, Zuhr and sunset are the sun's own, whatever the method.
    for (final index in [1, 2, 4]) {
      expect(tehran[index], closeTo(jafari[index], 0.01));
    }
    // Both put Isha at 14°.
    expect(tehran[6], closeTo(jafari[6], 0.01));

    prayerCalculationMethod.value = PrayerCalculationMethod.jafari;
    restorePrayerCalculationMethod();
    expect(prayerCalculationMethod.value, PrayerCalculationMethod.tehran);
  });

  test('an unknown saved method falls back to Jafari', () async {
    await SP.prefs.setString(prayerCalculationMethodKey, 'karachi');
    restorePrayerCalculationMethod();
    expect(prayerCalculationMethod.value, PrayerCalculationMethod.jafari);
  });

  test('only Shia methods are offered: Maghrib after sunset in both', () {
    final prayerTime = PrayerTime();
    for (final method in PrayerCalculationMethod.values) {
      final params = prayerTime.methodParams[method.idIn(prayerTime)]!;
      expect(params[1], 0, reason: '$method: Maghrib is an angle');
      expect(params[2], greaterThan(0), reason: '$method: below the horizon');
    }
  });
}
