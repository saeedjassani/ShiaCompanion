import 'dart:math';

import 'geo_utils.dart';

/// Magnetic declination from the World Magnetic Model (WMM2025).
///
/// A phone's magnetometer measures the angle to *magnetic* north, but every
/// bearing computed from coordinates — the qibla included — is measured from
/// *true* north. The difference is the declination, and it is not a rounding
/// error: it is under a degree across the Gulf, but around 13° on the US west
/// coast and worse at high latitudes. Pointing a qibla arrow with an
/// uncorrected magnetic heading would be visibly wrong for a large part of the
/// world, so the model is evaluated here rather than skipped.
///
/// Only declination is exposed. The model computes the whole field vector on
/// the way there, but nothing in the app has a use for inclination or
/// intensity, and an unused public API is a promise we would have to keep.
///
/// Coefficients are NOAA/BGS WMM2025, epoch 2025.0, valid through 2030.0.
/// Source: https://www.ncei.noaa.gov/products/world-magnetic-model

/// One Gauss coefficient pair and its yearly secular variation, in nT.
class _Gauss {
  const _Gauss(this.n, this.m, this.g, this.h, this.dg, this.dh);

  final int n;
  final int m;
  final double g;
  final double h;
  final double dg;
  final double dh;
}

/// Highest degree in the model. WMM is a degree-12 expansion.
const int _maxDegree = 12;

/// Decimal year the coefficients are referenced to.
const double _modelEpoch = 2025.0;

/// Last decimal year the coefficients are published for. Beyond this the
/// secular-variation extrapolation degrades, so time is clamped to the
/// validity window rather than run on indefinitely: a five-year-old model
/// frozen at its final year is far closer than one extrapolated a decade out.
const double _modelExpiry = 2030.0;

/// WGS84 ellipsoid, in km, matching the geodetic latitudes phones report.
const double _wgs84SemiMajorKm = 6378.137;
const double _wgs84Flattening = 1 / 298.257223563;

/// Geomagnetic reference radius the coefficients are scaled to, in km.
const double _geomagneticRadiusKm = 6371.2;

const List<_Gauss> _wmm2025 = [
  _Gauss(1, 0, -29351.8, 0.0, 12.0, 0.0),
  _Gauss(1, 1, -1410.8, 4545.4, 9.7, -21.5),
  _Gauss(2, 0, -2556.6, 0.0, -11.6, 0.0),
  _Gauss(2, 1, 2951.1, -3133.6, -5.2, -27.7),
  _Gauss(2, 2, 1649.3, -815.1, -8.0, -12.1),
  _Gauss(3, 0, 1361.0, 0.0, -1.3, 0.0),
  _Gauss(3, 1, -2404.1, -56.6, -4.2, 4.0),
  _Gauss(3, 2, 1243.8, 237.5, 0.4, -0.3),
  _Gauss(3, 3, 453.6, -549.5, -15.6, -4.1),
  _Gauss(4, 0, 895.0, 0.0, -1.6, 0.0),
  _Gauss(4, 1, 799.5, 278.6, -2.4, -1.1),
  _Gauss(4, 2, 55.7, -133.9, -6.0, 4.1),
  _Gauss(4, 3, -281.1, 212.0, 5.6, 1.6),
  _Gauss(4, 4, 12.1, -375.6, -7.0, -4.4),
  _Gauss(5, 0, -233.2, 0.0, 0.6, 0.0),
  _Gauss(5, 1, 368.9, 45.4, 1.4, -0.5),
  _Gauss(5, 2, 187.2, 220.2, 0.0, 2.2),
  _Gauss(5, 3, -138.7, -122.9, 0.6, 0.4),
  _Gauss(5, 4, -142.0, 43.0, 2.2, 1.7),
  _Gauss(5, 5, 20.9, 106.1, 0.9, 1.9),
  _Gauss(6, 0, 64.4, 0.0, -0.2, 0.0),
  _Gauss(6, 1, 63.8, -18.4, -0.4, 0.3),
  _Gauss(6, 2, 76.9, 16.8, 0.9, -1.6),
  _Gauss(6, 3, -115.7, 48.8, 1.2, -0.4),
  _Gauss(6, 4, -40.9, -59.8, -0.9, 0.9),
  _Gauss(6, 5, 14.9, 10.9, 0.3, 0.7),
  _Gauss(6, 6, -60.7, 72.7, 0.9, 0.9),
  _Gauss(7, 0, 79.5, 0.0, -0.0, 0.0),
  _Gauss(7, 1, -77.0, -48.9, -0.1, 0.6),
  _Gauss(7, 2, -8.8, -14.4, -0.1, 0.5),
  _Gauss(7, 3, 59.3, -1.0, 0.5, -0.8),
  _Gauss(7, 4, 15.8, 23.4, -0.1, 0.0),
  _Gauss(7, 5, 2.5, -7.4, -0.8, -1.0),
  _Gauss(7, 6, -11.1, -25.1, -0.8, 0.6),
  _Gauss(7, 7, 14.2, -2.3, 0.8, -0.2),
  _Gauss(8, 0, 23.2, 0.0, -0.1, 0.0),
  _Gauss(8, 1, 10.8, 7.1, 0.2, -0.2),
  _Gauss(8, 2, -17.5, -12.6, 0.0, 0.5),
  _Gauss(8, 3, 2.0, 11.4, 0.5, -0.4),
  _Gauss(8, 4, -21.7, -9.7, -0.1, 0.4),
  _Gauss(8, 5, 16.9, 12.7, 0.3, -0.5),
  _Gauss(8, 6, 15.0, 0.7, 0.2, -0.6),
  _Gauss(8, 7, -16.8, -5.2, -0.0, 0.3),
  _Gauss(8, 8, 0.9, 3.9, 0.2, 0.2),
  _Gauss(9, 0, 4.6, 0.0, -0.0, 0.0),
  _Gauss(9, 1, 7.8, -24.8, -0.1, -0.3),
  _Gauss(9, 2, 3.0, 12.2, 0.1, 0.3),
  _Gauss(9, 3, -0.2, 8.3, 0.3, -0.3),
  _Gauss(9, 4, -2.5, -3.3, -0.3, 0.3),
  _Gauss(9, 5, -13.1, -5.2, 0.0, 0.2),
  _Gauss(9, 6, 2.4, 7.2, 0.3, -0.1),
  _Gauss(9, 7, 8.6, -0.6, -0.1, -0.2),
  _Gauss(9, 8, -8.7, 0.8, 0.1, 0.4),
  _Gauss(9, 9, -12.9, 10.0, -0.1, 0.1),
  _Gauss(10, 0, -1.3, 0.0, 0.1, 0.0),
  _Gauss(10, 1, -6.4, 3.3, 0.0, 0.0),
  _Gauss(10, 2, 0.2, 0.0, 0.1, -0.0),
  _Gauss(10, 3, 2.0, 2.4, 0.1, -0.2),
  _Gauss(10, 4, -1.0, 5.3, -0.0, 0.1),
  _Gauss(10, 5, -0.6, -9.1, -0.3, -0.1),
  _Gauss(10, 6, -0.9, 0.4, 0.0, 0.1),
  _Gauss(10, 7, 1.5, -4.2, -0.1, 0.0),
  _Gauss(10, 8, 0.9, -3.8, -0.1, -0.1),
  _Gauss(10, 9, -2.7, 0.9, -0.0, 0.2),
  _Gauss(10, 10, -3.9, -9.1, -0.0, -0.0),
  _Gauss(11, 0, 2.9, 0.0, 0.0, 0.0),
  _Gauss(11, 1, -1.5, 0.0, -0.0, -0.0),
  _Gauss(11, 2, -2.5, 2.9, 0.0, 0.1),
  _Gauss(11, 3, 2.4, -0.6, 0.0, -0.0),
  _Gauss(11, 4, -0.6, 0.2, 0.0, 0.1),
  _Gauss(11, 5, -0.1, 0.5, -0.1, -0.0),
  _Gauss(11, 6, -0.6, -0.3, 0.0, -0.0),
  _Gauss(11, 7, -0.1, -1.2, -0.0, 0.1),
  _Gauss(11, 8, 1.1, -1.7, -0.1, -0.0),
  _Gauss(11, 9, -1.0, -2.9, -0.1, 0.0),
  _Gauss(11, 10, -0.2, -1.8, -0.1, 0.0),
  _Gauss(11, 11, 2.6, -2.3, -0.1, 0.0),
  _Gauss(12, 0, -2.0, 0.0, 0.0, 0.0),
  _Gauss(12, 1, -0.2, -1.3, 0.0, -0.0),
  _Gauss(12, 2, 0.3, 0.7, -0.0, 0.0),
  _Gauss(12, 3, 1.2, 1.0, -0.0, -0.1),
  _Gauss(12, 4, -1.3, -1.4, -0.0, 0.1),
  _Gauss(12, 5, 0.6, -0.0, -0.0, -0.0),
  _Gauss(12, 6, 0.6, 0.6, 0.1, -0.0),
  _Gauss(12, 7, 0.5, -0.1, -0.0, -0.0),
  _Gauss(12, 8, -0.1, 0.8, 0.0, 0.0),
  _Gauss(12, 9, -0.4, 0.1, 0.0, -0.0),
  _Gauss(12, 10, -0.2, -1.0, -0.1, -0.0),
  _Gauss(12, 11, -1.3, 0.1, -0.0, 0.0),
  _Gauss(12, 12, -0.7, 0.2, -0.1, -0.1),
];

/// Declination at [point] on [date] — the angle from true north to magnetic
/// north, positive when magnetic north lies east of true north.
///
/// Add it to a magnetic heading to get a true heading.
///
/// [altitudeKm] is part of the model and defaults to sea level, which is as
/// close as makes any difference for someone holding a phone: the declination
/// changes by well under a tenth of a degree over the height of any mountain
/// on earth. It is a parameter because NOAA publishes its reference values at
/// altitude, and being able to reproduce those is what makes this checkable.
double magneticDeclinationDegrees(
  GeoPoint point, {
  DateTime? date,
  double altitudeKm = 0,
}) {
  final field = _fieldAt(point, date ?? DateTime.now(), altitudeKm);
  return atan2(field.east, field.north) * 180.0 / pi;
}

/// Horizontal field components in the local geodetic frame, in nT.
class _HorizontalField {
  const _HorizontalField(this.north, this.east);

  final double north;
  final double east;
}

_HorizontalField _fieldAt(GeoPoint point, DateTime date, double altitudeKm) {
  final years = _decimalYear(date).clamp(_modelEpoch, _modelExpiry) -
      _modelEpoch;

  // The model is undefined exactly at the poles, where the east component
  // divides by cos(latitude). Nudging off the pole keeps it finite; nobody
  // reads a compass standing on the geographic pole anyway.
  final latitude = point.latitude.clamp(-89.99, 89.99) * pi / 180.0;
  final longitude = point.longitude * pi / 180.0;

  // Geodetic to geocentric spherical. The coefficients live in a spherical
  // frame, but latitude arrives from GPS as geodetic, and the two differ by up
  // to ~0.19° — small, but the same order as the accuracy we are chasing.
  final sinGeodetic = sin(latitude);
  final cosGeodetic = cos(latitude);
  final eccentricitySquared = _wgs84Flattening * (2 - _wgs84Flattening);
  final primeVertical =
      _wgs84SemiMajorKm / sqrt(1 - eccentricitySquared * sinGeodetic * sinGeodetic);
  final equatorial = (primeVertical + altitudeKm) * cosGeodetic;
  final polar =
      (primeVertical * (1 - eccentricitySquared) + altitudeKm) * sinGeodetic;
  final radius = sqrt(equatorial * equatorial + polar * polar);
  final geocentricLatitude = asin(polar / radius);

  // Colatitude, the variable the Legendre functions are written in.
  final cosTheta = sin(geocentricLatitude);
  final sinTheta = cos(geocentricLatitude);

  final legendre = _schmidtLegendre(cosTheta, sinTheta);

  // Longitude harmonics, built by angle addition rather than repeated calls to
  // sin/cos — degree 12 needs 13 of each.
  final cosMLon = List<double>.filled(_maxDegree + 1, 0.0);
  final sinMLon = List<double>.filled(_maxDegree + 1, 0.0);
  cosMLon[0] = 1.0;
  sinMLon[0] = 0.0;
  for (var m = 1; m <= _maxDegree; m++) {
    cosMLon[m] = cosMLon[m - 1] * cos(longitude) - sinMLon[m - 1] * sin(longitude);
    sinMLon[m] = sinMLon[m - 1] * cos(longitude) + cosMLon[m - 1] * sin(longitude);
  }

  // Field in the geocentric frame: north (X'), east (Y'), down (Z').
  var geocentricNorth = 0.0;
  var geocentricEast = 0.0;
  var geocentricDown = 0.0;

  final radiusRatio = _geomagneticRadiusKm / radius;
  final ratioPower = List<double>.filled(_maxDegree + 1, 0.0);
  for (var n = 1; n <= _maxDegree; n++) {
    ratioPower[n] = pow(radiusRatio, n + 2).toDouble();
  }

  for (final term in _wmm2025) {
    final g = term.g + years * term.dg;
    final h = term.h + years * term.dh;
    final p = legendre.value[term.n][term.m];
    final dp = legendre.derivative[term.n][term.m];
    final scale = ratioPower[term.n];

    final inPhase = g * cosMLon[term.m] + h * sinMLon[term.m];
    final quadrature = g * sinMLon[term.m] - h * cosMLon[term.m];

    geocentricNorth += scale * inPhase * dp;
    geocentricEast += scale * term.m * quadrature * p / sinTheta;
    geocentricDown -= scale * (term.n + 1) * inPhase * p;
  }

  // Rotate the horizontal plane from geocentric back to geodetic. Only the
  // north component changes; east is common to both frames.
  final tilt = geocentricLatitude - latitude;
  return _HorizontalField(
    geocentricNorth * cos(tilt) - geocentricDown * sin(tilt),
    geocentricEast,
  );
}

/// Schmidt semi-normalised associated Legendre functions and their derivatives
/// with respect to colatitude, indexed `[n][m]`.
class _Legendre {
  const _Legendre(this.value, this.derivative);

  final List<List<double>> value;
  final List<List<double>> derivative;
}

/// Builds the Legendre tables for one colatitude.
///
/// The unnormalised (Ferrers) recursions are run first and the Schmidt factor
/// applied afterwards. Written the other way round the normalisation folds
/// into the recursion and stops being checkable against a textbook; at degree
/// 12 the intermediate values peak around 1e11, nowhere near a double's range,
/// so there is nothing to gain by fusing them.
_Legendre _schmidtLegendre(double cosTheta, double sinTheta) {
  final p = List<List<double>>.generate(
    _maxDegree + 1,
    (_) => List<double>.filled(_maxDegree + 1, 0.0),
  );
  final dp = List<List<double>>.generate(
    _maxDegree + 1,
    (_) => List<double>.filled(_maxDegree + 1, 0.0),
  );

  p[0][0] = 1.0;
  dp[0][0] = 0.0;

  for (var n = 1; n <= _maxDegree; n++) {
    for (var m = 0; m <= n; m++) {
      if (m == n) {
        // Sectoral: P(n,n) = (2n-1) sin(theta) P(n-1,n-1).
        final factor = 2.0 * n - 1.0;
        p[n][m] = factor * sinTheta * p[n - 1][n - 1];
        dp[n][m] =
            factor * (cosTheta * p[n - 1][n - 1] + sinTheta * dp[n - 1][n - 1]);
      } else if (m == n - 1) {
        final factor = 2.0 * n - 1.0;
        p[n][m] = factor * cosTheta * p[n - 1][m];
        dp[n][m] = factor * (cosTheta * dp[n - 1][m] - sinTheta * p[n - 1][m]);
      } else {
        // Zonal/tesseral: (n-m) P(n,m) = (2n-1) cos(theta) P(n-1,m)
        //                              - (n+m-1) P(n-2,m).
        final a = 2.0 * n - 1.0;
        final b = n + m - 1.0;
        final c = n - m;
        p[n][m] = (a * cosTheta * p[n - 1][m] - b * p[n - 2][m]) / c;
        dp[n][m] =
            (a * (cosTheta * dp[n - 1][m] - sinTheta * p[n - 1][m]) - b * dp[n - 2][m]) /
                c;
      }
    }
  }

  // Schmidt semi-normalisation: sqrt(2 (n-m)! / (n+m)!) for m > 0, 1 for m = 0.
  for (var n = 1; n <= _maxDegree; n++) {
    for (var m = 1; m <= n; m++) {
      var factor = 2.0;
      for (var k = n - m + 1; k <= n + m; k++) {
        factor /= k;
      }
      final norm = sqrt(factor);
      p[n][m] *= norm;
      dp[n][m] *= norm;
    }
  }

  return _Legendre(p, dp);
}

/// Fractional year, so that a date halfway through 2026 reads as 2026.5.
double _decimalYear(DateTime date) {
  final utc = date.toUtc();
  final startOfYear = DateTime.utc(utc.year);
  final startOfNextYear = DateTime.utc(utc.year + 1);
  final elapsed = utc.difference(startOfYear).inSeconds;
  final length = startOfNextYear.difference(startOfYear).inSeconds;
  return utc.year + elapsed / length;
}
