import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/geo_utils.dart';
import 'package:shia_companion/utils/geomagnetism.dart';

/// One row of NOAA's published WMM2025 reference values.
class _ReferenceValue {
  const _ReferenceValue(
    this.decimalYear,
    this.altitudeKm,
    this.latitude,
    this.longitude,
    this.declination,
  );

  final double decimalYear;
  final double altitudeKm;
  final double latitude;
  final double longitude;
  final double declination;
}

/// Every fifth row of `WMM2025_TEST_VALUES.txt`, published by NOAA/NCEI
/// alongside the coefficients. It spans the model's whole validity window and
/// both hemispheres, including the high latitudes where declination is largest
/// and a sign or normalisation slip would be most obvious.
///
/// Declination is published to two decimals, so 0.01° is the tightest anything
/// here can be asserted to.
const List<_ReferenceValue> _noaaReferenceValues = [
  _ReferenceValue(2025.0, 28, 89, -121, -99.77),
  _ReferenceValue(2025.0, 39, -59, -8, -15.75),
  _ReferenceValue(2025.5, 6, -36, -137, 20.28),
  _ReferenceValue(2025.5, 8, -66, 17, -33.14),
  _ReferenceValue(2026.0, 74, -57, 3, -22.51),
  _ReferenceValue(2026.0, 62, -14, 99, -1.43),
  _ReferenceValue(2026.5, 14, 0, 80, -3.10),
  _ReferenceValue(2026.5, 12, 33, -145, 11.96),
  _ReferenceValue(2027.0, 37, -66, -5, -17.22),
  _ReferenceValue(2027.0, 44, -43, -111, 24.31),
  _ReferenceValue(2027.5, 8, 62, 53, 19.39),
  _ReferenceValue(2027.5, 73, -72, 95, -102.64),
  _ReferenceValue(2028.0, 49, 20, 167, 5.10),
  _ReferenceValue(2028.0, 75, 79, 125, -18.59),
  _ReferenceValue(2028.5, 28, 54, -120, 15.43),
  _ReferenceValue(2028.5, 72, -62, 65, -67.87),
  _ReferenceValue(2029.0, 95, -60, -59, 8.58),
  _ReferenceValue(2029.0, 38, -76, 49, -64.28),
  _ReferenceValue(2029.5, 31, 13, -132, 9.04),
  _ReferenceValue(2029.5, 66, -21, 32, -14.63),
];

DateTime _dateForDecimalYear(double decimalYear) {
  final year = decimalYear.floor();
  final fraction = decimalYear - year;
  final startOfYear = DateTime.utc(year);
  final yearLength = DateTime.utc(year + 1).difference(startOfYear);
  return startOfYear
      .add(Duration(seconds: (fraction * yearLength.inSeconds).round()));
}

void main() {
  group('WMM2025 declination', () {
    test('reproduces the NOAA reference values', () {
      for (final expected in _noaaReferenceValues) {
        final actual = magneticDeclinationDegrees(
          GeoPoint(expected.latitude, expected.longitude),
          date: _dateForDecimalYear(expected.decimalYear),
          altitudeKm: expected.altitudeKm,
        );

        expect(
          actual,
          closeTo(expected.declination, 0.01),
          reason: 'lat ${expected.latitude}, lon ${expected.longitude}, '
              'alt ${expected.altitudeKm}km, year ${expected.decimalYear}',
        );
      }
    });

    test('is near zero where the agonic line runs', () {
      // The zero-declination line crosses the Arabian peninsula, which is why
      // an uncorrected compass looks fine to anyone testing near Makkah and
      // wrong to everyone else.
      final makkah = magneticDeclinationDegrees(
        const GeoPoint(kaabaLatitude, kaabaLongitude),
        date: DateTime.utc(2026, 6),
      );
      expect(makkah.abs(), lessThan(5));
    });

    test('is large enough on the US west coast to matter', () {
      // Roughly 13° east near San Francisco. This is the case that makes the
      // model worth carrying: 13° is the difference between facing the Kaaba
      // and facing well past it.
      final sanFrancisco = magneticDeclinationDegrees(
        const GeoPoint(37.77, -122.42),
        date: DateTime.utc(2026, 6),
      );
      expect(sanFrancisco, closeTo(13, 2));
    });

    test('clamps outside the model validity window instead of extrapolating', () {
      // 2030.0 is the last published year, so anything later must return the
      // same answer rather than drifting further every year the app is not
      // updated.
      final atExpiry = magneticDeclinationDegrees(
        const GeoPoint(51.5, -0.13),
        date: DateTime.utc(2030),
      );
      final wellPastExpiry = magneticDeclinationDegrees(
        const GeoPoint(51.5, -0.13),
        date: DateTime.utc(2044),
      );
      expect(wellPastExpiry, closeTo(atExpiry, 1e-9));

      final beforeEpoch = magneticDeclinationDegrees(
        const GeoPoint(51.5, -0.13),
        date: DateTime.utc(2001),
      );
      final atEpoch = magneticDeclinationDegrees(
        const GeoPoint(51.5, -0.13),
        date: DateTime.utc(2025),
      );
      expect(beforeEpoch, closeTo(atEpoch, 1e-9));
    });

    test('stays finite at the poles', () {
      for (final latitude in [90.0, -90.0]) {
        final declination = magneticDeclinationDegrees(
          GeoPoint(latitude, 0),
          date: DateTime.utc(2026, 6),
        );
        expect(declination.isFinite, isTrue);
      }
    });
  });
}
