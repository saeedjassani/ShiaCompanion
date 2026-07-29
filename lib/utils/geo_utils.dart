import 'dart:math';

/// Mean earth radius in kilometres.
const double earthRadiusKm = 6371.0088;

/// Coordinates of the Kaaba, used for qibla bearings.
const double kaabaLatitude = 21.4225;
const double kaabaLongitude = 39.8262;

double _toRadians(double degrees) => degrees * pi / 180.0;

double _toDegrees(double radians) => radians * 180.0 / pi;

/// A latitude/longitude pair in degrees.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  String toString() =>
      'GeoPoint(${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Great-circle (orthodromic) distance between two points, in kilometres.
double greatCircleDistanceKm(GeoPoint from, GeoPoint to) {
  return _centralAngle(from, to) * earthRadiusKm;
}

/// Angular separation between two points, in radians (0..pi).
double _centralAngle(GeoPoint from, GeoPoint to) {
  final lat1 = _toRadians(from.latitude);
  final lat2 = _toRadians(to.latitude);
  final deltaLat = lat2 - lat1;
  final deltaLon = _toRadians(to.longitude - from.longitude);

  // Haversine — numerically stable for the small angles that dominate here.
  final a = pow(sin(deltaLat / 2), 2) +
      cos(lat1) * cos(lat2) * pow(sin(deltaLon / 2), 2);
  return 2 * atan2(sqrt(a), sqrt(1 - a));
}

/// Interpolates along the great-circle path from [from] to [to].
///
/// [fraction] 0 returns [from] and 1 returns [to]. Values outside 0..1 are
/// clamped, since a flight never leaves its own route. This is the standard
/// slerp on the unit sphere, which is the path airliners actually fly (subject
/// to winds and airspace routing) rather than a straight line on a flat map.
GeoPoint interpolateGreatCircle(GeoPoint from, GeoPoint to, double fraction) {
  final f = fraction.clamp(0.0, 1.0).toDouble();
  if (f <= 0) return from;
  if (f >= 1) return to;

  final angle = _centralAngle(from, to);
  // Coincident (or effectively coincident) endpoints have no defined path.
  if (angle < 1e-9) return from;

  final lat1 = _toRadians(from.latitude);
  final lon1 = _toRadians(from.longitude);
  final lat2 = _toRadians(to.latitude);
  final lon2 = _toRadians(to.longitude);

  final sinAngle = sin(angle);
  final a = sin((1 - f) * angle) / sinAngle;
  final b = sin(f * angle) / sinAngle;

  final x = a * cos(lat1) * cos(lon1) + b * cos(lat2) * cos(lon2);
  final y = a * cos(lat1) * sin(lon1) + b * cos(lat2) * sin(lon2);
  final z = a * sin(lat1) + b * sin(lat2);

  return GeoPoint(
    _toDegrees(atan2(z, sqrt(x * x + y * y))),
    _toDegrees(atan2(y, x)),
  );
}

/// Initial great-circle bearing from [from] to [to], in degrees clockwise from
/// true north (0..360).
double initialBearingDegrees(GeoPoint from, GeoPoint to) {
  final lat1 = _toRadians(from.latitude);
  final lat2 = _toRadians(to.latitude);
  final deltaLon = _toRadians(to.longitude - from.longitude);

  final y = sin(deltaLon) * cos(lat2);
  final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon);
  return normalizeBearing(_toDegrees(atan2(y, x)));
}

/// Bearing from [from] towards the Kaaba, in degrees clockwise from true north.
double qiblaBearingDegrees(GeoPoint from) {
  return initialBearingDegrees(
    from,
    const GeoPoint(kaabaLatitude, kaabaLongitude),
  );
}

/// Wraps any bearing into the 0..360 range.
double normalizeBearing(double degrees) {
  final wrapped = degrees % 360.0;
  return wrapped < 0 ? wrapped + 360.0 : wrapped;
}

/// Signed difference [target] - [reference], wrapped into -180..180.
///
/// Positive means [target] is clockwise (to the right) of [reference].
double relativeBearingDegrees(double reference, double target) {
  final difference = normalizeBearing(target - reference);
  return difference > 180 ? difference - 360 : difference;
}

/// A 16-point compass label such as `NNE` for a bearing in degrees.
String compassLabel(double bearingDegrees) {
  const points = [
    'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', //
    'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
  ];
  final index = ((normalizeBearing(bearingDegrees) / 22.5) + 0.5).floor() % 16;
  return points[index];
}

/// Formats coordinates as `37.6°N 122.4°W`.
String formatCoordinates(GeoPoint point) {
  final latHemisphere = point.latitude >= 0 ? 'N' : 'S';
  final lonHemisphere = point.longitude >= 0 ? 'E' : 'W';
  return '${point.latitude.abs().toStringAsFixed(1)}°$latHemisphere '
      '${point.longitude.abs().toStringAsFixed(1)}°$lonHemisphere';
}
