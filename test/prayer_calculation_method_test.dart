import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/models/city.dart';
import 'package:shia_companion/services/city_repository.dart';
import 'package:shia_companion/utils/prayer_calculation_method.dart';
import 'package:shia_companion/utils/prayer_times.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

/// [prayerTime]'s Fajr, Sunrise, Zuhr, Sunset, Maghrib and Isha as "HH:mm"
/// at the Abbas shrine, Karbala, on 21 November 2026.
List<String> _karbala(PrayerTime prayerTime) {
  final original = prayerTime.getTimeFormat();
  prayerTime.setTimeFormat(prayerTime.getTime24());
  try {
    final times = prayerTime.getPrayerTimes(
      DateTime(2026, 11, 21),
      32.6155,
      44.0336,
      3.0,
    );
    return [times[0], times[1], times[2], times[4], times[5], times[6]];
  } finally {
    prayerTime.setTimeFormat(original);
  }
}

/// Minutes past midnight of [PrayerTime.getTimeNames]' times, in Qum.
List<double> _qum(PrayerTime prayerTime) {
  final original = prayerTime.getTimeFormat();
  prayerTime.setTimeFormat(prayerTime.getFloating());
  try {
    return prayerTime
        .getPrayerTimes(DateTime(2026, 3, 21), 34.6401, 50.8764, 3.5)
        .map((hours) => double.parse(hours) * 60)
        .toList();
  } finally {
    prayerTime.setTimeFormat(original);
  }
}

City _city(String name, String countryCode, double latitude, double longitude) =>
    City(
      name: name,
      countryCode: countryCode,
      countryName: countryCode,
      latitude: latitude,
      longitude: longitude,
      population: 1000000,
      timeZone: 'Asia/Baghdad',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    await SP.init();
    restorePrayerCalculationMethod();
    lat = null;
    long = null;
  });

  tearDown(resetPrayerCalculationMethodForTest);

  test('Automatic goes by the country: Iraq, Iran, and Leva elsewhere', () {
    expect(
      PrayerCalculationMethod.defaultFor('IQ'),
      PrayerCalculationMethod.iraqShrines,
    );
    expect(
      PrayerCalculationMethod.defaultFor('IR'),
      PrayerCalculationMethod.tehran,
    );
    for (final elsewhere in ['PK', 'IN', 'GB', '', null]) {
      expect(
        PrayerCalculationMethod.defaultFor(elsewhere),
        PrayerCalculationMethod.jafari,
      );
    }
  });

  test('with nothing known the app keeps the Leva Institute method', () {
    expect(prayerCalculationMethodChoice, isNull);
    expect(prayerCalculationMethod.value, PrayerCalculationMethod.jafari);
    final prayerTime = getPrayerTimeObject();
    expect(prayerTime.getCalcMethod(), prayerTime.getJafari());
  });

  test('in Iraq the times are the ones the Abbas shrine publishes', () async {
    expect(await setPrayerLocationCountry('IQ'), isTrue);
    final prayerTime = getPrayerTimeObject();
    expect(prayerTime.getCalcMethod(), prayerTime.getIraqShrines());
    // alkafeel.net's own times for the day: Fajr 05:13, sunrise 06:39,
    // noon 11:50, Maghrib 05:16 pm.
    final times = _karbala(prayerTime);
    expect(times[0], '05:13');
    expect(times[1], '06:39');
    expect(times[2], '11:50');
    expect(times[4], '17:16');
  });

  test('a chosen method beats the country, and is saved and restored',
      () async {
    await setPrayerLocationCountry('IQ');
    await setPrayerCalculationMethodChoice(PrayerCalculationMethod.tehran);
    expect(SP.prefs.getString(prayerCalculationMethodKey), 'tehran');
    expect(prayerCalculationMethod.value, PrayerCalculationMethod.tehran);

    resetPrayerCalculationMethodForTest();
    restorePrayerCalculationMethod();
    expect(prayerCalculationMethodChoice, PrayerCalculationMethod.tehran);
    expect(prayerLocationCountry, 'IQ');

    // Back to Automatic: the country's method again.
    await setPrayerCalculationMethodChoice(null);
    expect(SP.prefs.containsKey(prayerCalculationMethodKey), isFalse);
    expect(prayerCalculationMethod.value, PrayerCalculationMethod.iraqShrines);
  });

  test('an unknown saved method counts as Automatic', () async {
    await SP.prefs.setString(prayerCalculationMethodKey, 'karachi');
    restorePrayerCalculationMethod();
    expect(prayerCalculationMethodChoice, isNull);
  });

  test('Tehran moves Fajr earlier and Maghrib later than Leva', () async {
    final leva = _qum(getPrayerTimeObject());
    await setPrayerCalculationMethodChoice(PrayerCalculationMethod.tehran);
    final tehran = _qum(getPrayerTimeObject());

    expect(tehran[0], lessThan(leva[0] - 5));
    expect(tehran[5], greaterThan(leva[5]));
    expect(tehran[5] - leva[5], lessThan(5));
    // Sunrise, Zuhr and sunset are the sun's own, whatever the method.
    for (final index in [1, 2, 4]) {
      expect(tehran[index], closeTo(leva[index], 0.01));
    }
    expect(tehran[6], closeTo(leva[6], 0.01));
  });

  test('only Shia methods are offered: Maghrib after sunset in each', () {
    final prayerTime = PrayerTime();
    for (final method in PrayerCalculationMethod.values) {
      final params = prayerTime.methodParams[method.idIn(prayerTime)]!;
      expect(params[1], 0, reason: '$method: Maghrib is an angle');
      expect(params[2], greaterThan(0), reason: '$method: below the horizon');
    }
  });

  group('the first launch after the update', () {
    setUp(() {
      CityRepository.instance.seedForTesting([
        _city('Karbala', 'IQ', 32.616, 44.0249),
        _city('Qom', 'IR', 34.6401, 50.8764),
        _city('Karachi', 'PK', 24.8607, 67.0011),
      ]);
    });

    test('moves an existing reader in Iraq and says so once', () async {
      lat = 32.6155;
      long = 44.0336;
      await resolvePrayerLocationCountryOnLaunch(freshInstall: false);

      expect(prayerLocationCountry, 'IQ');
      expect(prayerCalculationMethod.value, PrayerCalculationMethod.iraqShrines);
      expect(pendingPrayerMethodNotice, PrayerCalculationMethod.iraqShrines);

      await dismissPrayerMethodNotice();
      expect(pendingPrayerMethodNotice, isNull);
    });

    test('says nothing to a new install, or where nothing changes', () async {
      lat = 32.6155;
      long = 44.0336;
      await resolvePrayerLocationCountryOnLaunch(freshInstall: true);
      expect(prayerCalculationMethod.value, PrayerCalculationMethod.iraqShrines);
      expect(pendingPrayerMethodNotice, isNull);

      resetPrayerCalculationMethodForTest();
      await SP.prefs.remove(prayerLocationCountryKey);
      lat = 24.86;
      long = 67.0;
      await resolvePrayerLocationCountryOnLaunch(freshInstall: false);
      expect(prayerLocationCountry, 'PK');
      expect(pendingPrayerMethodNotice, isNull);
    });

    test('leaves a chosen method alone, and runs only once', () async {
      await setPrayerCalculationMethodChoice(PrayerCalculationMethod.jafari);
      lat = 34.64;
      long = 50.87;
      await resolvePrayerLocationCountryOnLaunch(freshInstall: false);
      expect(prayerLocationCountry, 'IR');
      expect(prayerCalculationMethod.value, PrayerCalculationMethod.jafari);
      expect(pendingPrayerMethodNotice, isNull);

      // Known now: a later launch elsewhere leaves it to the location code.
      lat = 32.6155;
      long = 44.0336;
      await resolvePrayerLocationCountryOnLaunch(freshInstall: false);
      expect(prayerLocationCountry, 'IR');
    });

    test('a choice answers the notice', () async {
      lat = 34.64;
      long = 50.87;
      await resolvePrayerLocationCountryOnLaunch(freshInstall: false);
      expect(pendingPrayerMethodNotice, PrayerCalculationMethod.tehran);
      await setPrayerCalculationMethodChoice(PrayerCalculationMethod.jafari);
      expect(pendingPrayerMethodNotice, isNull);
    });
  });
}
