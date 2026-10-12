import 'dart:math' as math;

import 'package:hijri/hijri_array.dart';

/// Predicts when each Hijri month begins at a place: the day after the first
/// evening on which the new crescent can be seen there with the naked eye.
///
/// The positions come from Meeus, "Astronomical Algorithms" (2nd ed.):
/// chapter 25 for the Sun (about 0.01°) and chapter 47 for the Moon (about
/// 10"). Visibility is B. D. Yallop's criterion (NAO Technical Note 69,
/// 1997), the one HM Nautical Almanac Office publishes: a crescent the
/// criterion puts in zone A or B (q > -0.014) can be seen without optical aid
/// in clear skies. Naked eye, because that is what the maraji' most of the
/// app's readers follow accept; a telescope sighting does not start a month
/// for them.
///
/// It is a prediction, not an announcement: cloud, haze or a sighting
/// accepted from another city can still move a month by a day, which is
/// what the manual offset in Settings is for.

/// Yallop's q above which a crescent is visible to the naked eye (zones A
/// and B).
const double yallopNakedEyeLimit = -0.014;

/// How the hijri package keys a month start in
/// [HijriCalendar.setAdjustments]: the index of that month in
/// [ummAlquraDateArray], plus this.
const int hijriAdjustmentKeyOffset = 16260;

/// The modified chronological Julian day number (local days since 17
/// November 1858) that [ummAlquraDateArray] and the hijri package count in.
const int _mcjdnEpoch = 2400000;

/// Each Hijri month's first day at ([latitude], [longitude]), predicted from
/// the crescent, for roughly [monthsBefore] months before the one holding
/// [around] through [monthsAfter] after it, keyed the way
/// [HijriCalendar.setAdjustments] wants them (see [hijriAdjustmentKeyOffset];
/// values are modified chronological Julian day numbers).
///
/// Every month stays 29 or 30 days long: a month that the crescent would
/// start earlier than its 29th day, or later than its 30th, is held to that
/// bound, as in practice a month is completed at 30 days when the moon is
/// not seen. The table starts on a month that is also in the Umm al-Qura
/// table and runs on until it meets that table again, so the months on
/// either side of it - which fall back to Umm al-Qura - keep their lengths.
Map<int, int> predictedHijriMonthStarts({
  required double latitude,
  required double longitude,
  required DateTime around,
  int monthsBefore = 24,
  int monthsAfter = 36,
}) {
  final table = ummAlquraDateArray;
  final mcjdn = _chronologicalJdn(around) - _mcjdnEpoch;
  var current = 0;
  while (current + 1 < table.length && table[current + 1] <= mcjdn) {
    current++;
  }

  final first = math.max(1, current - monthsBefore);
  final wanted = math.min(table.length - 2, current + monthsAfter);
  // How far past [wanted] to look for a month where the prediction and Umm
  // al-Qura agree again; nearly always within a few months.
  final last = math.min(table.length - 2, wanted + 12);

  final starts = <int, int>{};
  var previous = table[first];
  var seam = first;
  for (var index = first + 1; index <= last; index++) {
    final predicted = predictMonthStart(
          ummAlQuraStart: table[index],
          latitude: latitude,
          longitude: longitude,
        ) ??
        previous + 30;
    final start = predicted.clamp(previous + 29, previous + 30);
    starts[index + hijriAdjustmentKeyOffset] = start;
    if (start == table[index]) {
      seam = index;
      if (index >= wanted) break;
    }
    previous = start;
  }
  starts.removeWhere((key, _) => key > seam + hijriAdjustmentKeyOffset);
  return starts;
}

/// The first day (a modified chronological Julian day number) of the month
/// that Umm al-Qura starts on [ummAlQuraStart], as the crescent would start
/// it at ([latitude], [longitude]); `null` when it can't be seen there within
/// a few evenings of the new moon, e.g. near the poles.
int? predictMonthStart({
  required int ummAlQuraStart,
  required double latitude,
  required double longitude,
}) {
  // Umm al-Qura starts a month the day after the new moon or so: the new
  // moon nearest the evening before is this month's.
  final conjunction = newMoonNear(ummAlQuraStart + _mcjdnEpoch - 1.0);
  // The local date of the new moon, by the Sun at [longitude]. No sunset on
  // an earlier day can follow it.
  final conjunctionDay = _localDay(conjunction, longitude);
  for (var day = conjunctionDay; day <= conjunctionDay + 3; day++) {
    final q = yallopQ(
      jdn: day,
      latitude: latitude,
      longitude: longitude,
      conjunction: conjunction,
    );
    if (q != null && q > yallopNakedEyeLimit) return day + 1 - _mcjdnEpoch;
  }
  return null;
}

/// Yallop's q for the crescent on the evening of the day [jdn] (a Julian day
/// number) at ([latitude], [longitude]); `null` when there is no crescent to
/// look for: no sunset, the Sun setting before the new moon at
/// [conjunction], or the Moon setting before the Sun.
double? yallopQ({
  required int jdn,
  required double latitude,
  required double longitude,
  required double conjunction,
}) {
  final sunset = _setting(
    latitude: latitude,
    longitude: longitude,
    from: jdn - longitude / 360,
    rate: 360.9856,
    position: sunPosition,
    altitude: (_) => -0.8333,
  );
  // The iteration can drift to another day's sunset (none at all that day).
  if (sunset == null || _localDay(sunset, longitude) != jdn) return null;
  if (sunset < conjunction) return null;
  final moonset = _setting(
    latitude: latitude,
    longitude: longitude,
    from: sunset,
    rate: 347.81,
    position: moonPosition,
    // Meeus 15: the Moon's centre at setting, its parallax and refraction
    // included.
    altitude: (moon) => 0.7275 * moon.parallax - 0.5667,
  );
  if (moonset == null || moonset <= sunset) return null;
  // Not tonight's moonset but the next one: the Moon is up all night.
  if (moonset - sunset > 0.5) return null;

  // Yallop's "best time" to look: four-ninths of the way from sunset to
  // moonset.
  final best = sunset + (moonset - sunset) * 4 / 9;
  final sun = sunPosition(best);
  final moon = moonPosition(best);
  final sunAltitude = _altitude(sun, best, latitude, longitude);
  final moonAltitude = _altitude(moon, best, latitude, longitude);

  final arcv = moonAltitude - sunAltitude;
  final arcl = _degrees(math.acos(
    (math.cos(_radians(moon.latitude)) *
            math.cos(_radians(moon.longitude - sun.longitude)))
        .clamp(-1.0, 1.0),
  ));
  // The topocentric width of the crescent, in arcminutes.
  final semiDiameter = 0.27245 * moon.parallax * 60;
  final topocentricSemiDiameter = semiDiameter *
      (1 +
          math.sin(_radians(moonAltitude)) * math.sin(_radians(moon.parallax)));
  final width = topocentricSemiDiameter * (1 - math.cos(_radians(arcl)));
  return (arcv -
          (11.8371 -
              6.3226 * width +
              0.7319 * width * width -
              0.1018 * width * width * width)) /
      10;
}

/// The Julian date (UT) of the new moon nearest [jd]: where the Moon's
/// longitude catches up with the Sun's.
double newMoonNear(double jd) {
  var t = jd;
  for (var i = 0; i < 8; i++) {
    final gap = _wrap180(moonPosition(t).longitude - sunPosition(t).longitude);
    // The Moon gains on the Sun about 12.19° a day.
    final step = gap / 12.1907;
    t -= step;
    if (step.abs() < 1e-6) break;
  }
  return t;
}

/// Where a body is in the sky at one moment, geocentric and of date.
class SkyPosition {
  const SkyPosition({
    required this.longitude,
    required this.latitude,
    required this.rightAscension,
    required this.declination,
    this.parallax = 0,
  });

  /// Ecliptic longitude and latitude, degrees.
  final double longitude;
  final double latitude;

  /// Equatorial coordinates, degrees.
  final double rightAscension;
  final double declination;

  /// Equatorial horizontal parallax, degrees (0 for the Sun).
  final double parallax;
}

/// The Sun at the Julian date [jd] (UT): Meeus 25, low accuracy, aberration
/// included.
SkyPosition sunPosition(double jd) {
  final t = _centuries(jd);
  final meanLongitude = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
  final anomaly = _radians(357.52911 + 35999.05029 * t - 0.0001537 * t * t);
  final centre =
      (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(anomaly) +
          (0.019993 - 0.000101 * t) * math.sin(2 * anomaly) +
          0.000289 * math.sin(3 * anomaly);
  final longitude = _wrap360(meanLongitude + centre - 0.00569);
  return _fromEcliptic(longitude, 0, t);
}

/// The Moon at the Julian date [jd] (UT): Meeus 47, the full periodic terms.
SkyPosition moonPosition(double jd) {
  final t = _centuries(jd);
  final t2 = t * t, t3 = t2 * t, t4 = t3 * t;
  final meanLongitude = 218.3164477 +
      481267.88123421 * t -
      0.0015786 * t2 +
      t3 / 538841 -
      t4 / 65194000;
  final elongation = 297.8501921 +
      445267.1114034 * t -
      0.0018819 * t2 +
      t3 / 545868 -
      t4 / 113065000;
  final sunAnomaly =
      357.5291092 + 35999.0502909 * t - 0.0001536 * t2 + t3 / 24490000;
  final moonAnomaly = 134.9633964 +
      477198.8675055 * t +
      0.0087414 * t2 +
      t3 / 69699 -
      t4 / 14712000;
  final argument = 93.2720950 +
      483202.0175233 * t -
      0.0036539 * t2 -
      t3 / 3526000 +
      t4 / 863310000;
  final a1 = 119.75 + 131.849 * t;
  final a2 = 53.09 + 479264.290 * t;
  final a3 = 313.45 + 481266.484 * t;
  final e = 1 - 0.002516 * t - 0.0000074 * t2;

  double eccentricity(int m) => switch (m.abs()) { 1 => e, 2 => e * e, _ => 1 };

  var sumL = 0.0, sumR = 0.0, sumB = 0.0;
  for (final row in _moonLongitudeTerms) {
    final angle = _radians(row[0] * elongation +
        row[1] * sunAnomaly +
        row[2] * moonAnomaly +
        row[3] * argument);
    final factor = eccentricity(row[1]);
    sumL += row[4] * factor * math.sin(angle);
    sumR += row[5] * factor * math.cos(angle);
  }
  for (final row in _moonLatitudeTerms) {
    final angle = _radians(row[0] * elongation +
        row[1] * sunAnomaly +
        row[2] * moonAnomaly +
        row[3] * argument);
    sumB += row[4] * eccentricity(row[1]) * math.sin(angle);
  }
  sumL += 3958 * math.sin(_radians(a1)) +
      1962 * math.sin(_radians(meanLongitude - argument)) +
      318 * math.sin(_radians(a2));
  sumB += -2235 * math.sin(_radians(meanLongitude)) +
      382 * math.sin(_radians(a3)) +
      175 * math.sin(_radians(a1 - argument)) +
      175 * math.sin(_radians(a1 + argument)) +
      127 * math.sin(_radians(meanLongitude - moonAnomaly)) -
      115 * math.sin(_radians(meanLongitude + moonAnomaly));

  final longitude = _wrap360(meanLongitude + sumL / 1e6);
  final latitude = sumB / 1e6;
  final distance = 385000.56 + sumR / 1000;
  final parallax = _degrees(math.asin(6378.14 / distance));
  return _fromEcliptic(longitude, latitude, t, parallax: parallax);
}

/// The Julian date [jd] (UT) in Julian centuries of Terrestrial Time from
/// J2000.0.
double _centuries(double jd) => (jd + _deltaT(jd) / 86400 - 2451545) / 36525;

/// TT - UT in seconds: Espenak and Meeus's polynomial for 2005-2050, which
/// stays within a minute or so for the decades either side - a minute moves
/// the Moon by half an arcminute, too little to matter here.
double _deltaT(double jd) {
  final t = (jd - 2451545) / 365.25;
  return 62.92 + 0.32217 * t + 0.005589 * t * t;
}

SkyPosition _fromEcliptic(
  double longitude,
  double latitude,
  double t, {
  double parallax = 0,
}) {
  final obliquity = _radians(23.439291 - 0.0130042 * t);
  final lambda = _radians(longitude), beta = _radians(latitude);
  final rightAscension = math.atan2(
    math.sin(lambda) * math.cos(obliquity) -
        math.tan(beta) * math.sin(obliquity),
    math.cos(lambda),
  );
  final declination = math.asin(math.sin(beta) * math.cos(obliquity) +
      math.cos(beta) * math.sin(obliquity) * math.sin(lambda));
  return SkyPosition(
    longitude: longitude,
    latitude: latitude,
    rightAscension: _wrap360(_degrees(rightAscension)),
    declination: _degrees(declination),
    parallax: parallax,
  );
}

/// Greenwich mean sidereal time at the Julian date [jd] (UT), degrees.
double _siderealTime(double jd) {
  final t = (jd - 2451545) / 36525;
  return _wrap360(280.46061837 +
      360.98564736629 * (jd - 2451545) +
      0.000387933 * t * t -
      t * t * t / 38710000);
}

double _hourAngle(SkyPosition body, double jd, double longitude) =>
    _wrap180(_siderealTime(jd) + longitude - body.rightAscension);

/// [body]'s geocentric altitude, airless, degrees.
double _altitude(
  SkyPosition body,
  double jd,
  double latitude,
  double longitude,
) {
  final phi = _radians(latitude), delta = _radians(body.declination);
  final h = _radians(_hourAngle(body, jd, longitude));
  return _degrees(math.asin(math.sin(phi) * math.sin(delta) +
      math.cos(phi) * math.cos(delta) * math.cos(h)));
}

/// When a body sets nearest [from]: the moment its hour angle reaches the one
/// at which its centre is at [altitude]; `null` when it doesn't set (or
/// rise) that day.
double? _setting({
  required double latitude,
  required double longitude,
  required double from,
  required double rate,
  required SkyPosition Function(double jd) position,
  required double Function(SkyPosition body) altitude,
}) {
  var t = from;
  final phi = _radians(latitude);
  for (var i = 0; i < 6; i++) {
    final body = position(t);
    final delta = _radians(body.declination);
    final cosH =
        (math.sin(_radians(altitude(body))) - math.sin(phi) * math.sin(delta)) /
            (math.cos(phi) * math.cos(delta));
    if (cosH < -1 || cosH > 1) return null;
    final target = _degrees(math.acos(cosH));
    final step = _wrap180(target - _hourAngle(body, t, longitude)) / rate;
    t += step;
    if (step.abs() < 1e-5) break;
  }
  return t;
}

/// The Julian day number of the local (mean solar) date at [jd] (UT) and
/// [longitude].
int _localDay(double jd, double longitude) =>
    (jd + longitude / 360 + 0.5).floor();

/// The Julian day number of [date]'s calendar day.
int _chronologicalJdn(DateTime date) {
  final noon = DateTime.utc(date.year, date.month, date.day, 12);
  return (noon.millisecondsSinceEpoch / 86400000 + 2440587.5).round();
}

double _radians(double degrees) => degrees * math.pi / 180;
double _degrees(double radians) => radians * 180 / math.pi;
double _wrap360(double degrees) => degrees % 360;
double _wrap180(double degrees) {
  final wrapped = (degrees + 180) % 360;
  return wrapped - 180;
}

/// Meeus table 47.A: multiples of D, M, M', F, then the coefficients of the
/// sine for longitude (1e-6°) and of the cosine for distance (0.001 km).
const List<List<int>> _moonLongitudeTerms = [
  [0, 0, 1, 0, 6288774, -20905355],
  [2, 0, -1, 0, 1274027, -3699111],
  [2, 0, 0, 0, 658314, -2955968],
  [0, 0, 2, 0, 213618, -569925],
  [0, 1, 0, 0, -185116, 48888],
  [0, 0, 0, 2, -114332, -3149],
  [2, 0, -2, 0, 58793, 246158],
  [2, -1, -1, 0, 57066, -152138],
  [2, 0, 1, 0, 53322, -170733],
  [2, -1, 0, 0, 45758, -204586],
  [0, 1, -1, 0, -40923, -129620],
  [1, 0, 0, 0, -34720, 108743],
  [0, 1, 1, 0, -30383, 104755],
  [2, 0, 0, -2, 15327, 10321],
  [0, 0, 1, 2, -12528, 0],
  [0, 0, 1, -2, 10980, 79661],
  [4, 0, -1, 0, 10675, -34782],
  [0, 0, 3, 0, 10034, -23210],
  [4, 0, -2, 0, 8548, -21636],
  [2, 1, -1, 0, -7888, 24208],
  [2, 1, 0, 0, -6766, 30824],
  [1, 0, -1, 0, -5163, -8379],
  [1, 1, 0, 0, 4987, -16675],
  [2, -1, 1, 0, 4036, -12831],
  [2, 0, 2, 0, 3994, -10445],
  [4, 0, 0, 0, 3861, -11650],
  [2, 0, -3, 0, 3665, 14403],
  [0, 1, -2, 0, -2689, -7003],
  [2, 0, -1, 2, -2602, 0],
  [2, -1, -2, 0, 2390, 10056],
  [1, 0, 1, 0, -2348, 6322],
  [2, -2, 0, 0, 2236, -9884],
  [0, 1, 2, 0, -2120, 5751],
  [0, 2, 0, 0, -2069, 0],
  [2, -2, -1, 0, 2048, -4950],
  [2, 0, 1, -2, -1773, 4130],
  [2, 0, 0, 2, -1595, 0],
  [4, -1, -1, 0, 1215, -3958],
  [0, 0, 2, 2, -1110, 0],
  [3, 0, -1, 0, -892, 3258],
  [2, 1, 1, 0, -810, 2616],
  [4, -1, -2, 0, 759, -1897],
  [0, 2, -1, 0, -713, -2117],
  [2, 2, -1, 0, -700, 2354],
  [2, 1, -2, 0, 691, 0],
  [2, -1, 0, -2, 596, 0],
  [4, 0, 1, 0, 549, -1423],
  [0, 0, 4, 0, 537, -1117],
  [4, -1, 0, 0, 520, -1571],
  [1, 0, -2, 0, -487, -1739],
  [2, 1, 0, -2, -399, 0],
  [0, 0, 2, -2, -381, -4421],
  [1, 1, 1, 0, 351, 0],
  [3, 0, -2, 0, -340, 0],
  [4, 0, -3, 0, 330, 0],
  [2, -1, 2, 0, 327, 0],
  [0, 2, 1, 0, -323, 1165],
  [1, 1, -1, 0, 299, 0],
  [2, 0, 3, 0, 294, 0],
  [2, 0, -1, -2, 0, 8752],
];

/// Meeus table 47.B: multiples of D, M, M', F, then the coefficient of the
/// sine for latitude (1e-6°).
const List<List<int>> _moonLatitudeTerms = [
  [0, 0, 0, 1, 5128122],
  [0, 0, 1, 1, 280602],
  [0, 0, 1, -1, 277693],
  [2, 0, 0, -1, 173237],
  [2, 0, -1, 1, 55413],
  [2, 0, -1, -1, 46271],
  [2, 0, 0, 1, 32573],
  [0, 0, 2, 1, 17198],
  [2, 0, 1, -1, 9266],
  [0, 0, 2, -1, 8822],
  [2, -1, 0, -1, 8216],
  [2, 0, -2, -1, 4324],
  [2, 0, 1, 1, 4200],
  [2, 1, 0, -1, -3359],
  [2, -1, -1, 1, 2463],
  [2, -1, 0, 1, 2211],
  [2, -1, -1, -1, 2065],
  [0, 1, -1, -1, -1870],
  [4, 0, -1, -1, 1828],
  [0, 1, 0, 1, -1794],
  [0, 0, 0, 3, -1749],
  [0, 1, -1, 1, -1565],
  [1, 0, 0, 1, -1491],
  [0, 1, 1, 1, -1475],
  [0, 1, 1, -1, -1410],
  [0, 1, 0, -1, -1344],
  [1, 0, 0, -1, -1335],
  [0, 0, 3, 1, 1107],
  [4, 0, 0, -1, 1021],
  [4, 0, -1, 1, 833],
  [0, 0, 1, -3, 777],
  [4, 0, -2, 1, 671],
  [2, 0, 0, -3, 607],
  [2, 0, 2, -1, 596],
  [2, -1, 1, -1, 491],
  [2, 0, -2, 1, -451],
  [0, 0, 3, -1, 439],
  [2, 0, 2, 1, 422],
  [2, 0, -3, -1, 421],
  [2, 1, -1, 1, -366],
  [2, 1, 0, 1, -351],
  [4, 0, 0, 1, 331],
  [2, -1, 1, 1, 315],
  [2, -2, 0, -1, 302],
  [0, 0, 1, 3, -283],
  [2, 1, 1, -1, -229],
  [1, 1, 0, -1, 223],
  [1, 1, 0, 1, 223],
  [0, 1, -2, -1, -220],
  [2, 1, -1, -1, -220],
  [1, 0, 1, 1, -185],
  [2, -1, -2, -1, 181],
  [0, 1, 2, 1, -177],
  [4, 0, -2, -1, 176],
  [4, -1, -1, -1, 166],
  [1, 0, 1, -1, -164],
  [4, 0, 1, -1, 132],
  [1, 0, -1, -1, -119],
  [4, -1, 0, -1, 115],
  [2, -2, 0, 1, 107],
];
