import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/geo_utils.dart';

const sanFrancisco = GeoPoint(37.6190, -122.3750);
const istanbul = GeoPoint(41.2622, 28.7278);
const london = GeoPoint(51.5074, -0.1278);
const newYork = GeoPoint(40.7128, -74.0060);

void main() {
  group('greatCircleDistanceKm', () {
    test('matches published distances', () {
      // London–New York is a very well known 5570 km.
      expect(
        greatCircleDistanceKm(london, newYork),
        closeTo(5570, 30),
      );
      expect(greatCircleDistanceKm(sanFrancisco, istanbul), closeTo(10766, 60));
    });

    test('is zero for a point against itself', () {
      expect(greatCircleDistanceKm(london, london), closeTo(0, 0.001));
    });
  });

  group('interpolateGreatCircle', () {
    test('returns the endpoints at 0 and 1', () {
      expect(interpolateGreatCircle(sanFrancisco, istanbul, 0), sanFrancisco);
      expect(interpolateGreatCircle(sanFrancisco, istanbul, 1), istanbul);
    });

    test('clamps fractions outside the route', () {
      expect(interpolateGreatCircle(sanFrancisco, istanbul, -2), sanFrancisco);
      expect(interpolateGreatCircle(sanFrancisco, istanbul, 5), istanbul);
    });

    test('the midpoint is equidistant from both ends', () {
      final midpoint = interpolateGreatCircle(sanFrancisco, istanbul, 0.5);
      final toOrigin = greatCircleDistanceKm(sanFrancisco, midpoint);
      final toDestination = greatCircleDistanceKm(istanbul, midpoint);

      expect(toOrigin, closeTo(toDestination, 1.0));
      expect(
        toOrigin + toDestination,
        closeTo(greatCircleDistanceKm(sanFrancisco, istanbul), 1.0),
      );
    });

    test('bends poleward rather than following a straight line on a map', () {
      // The whole point of great-circle routing: the midpoint sits far north
      // of the average of the two latitudes (39.4°).
      final midpoint = interpolateGreatCircle(sanFrancisco, istanbul, 0.5);
      expect(midpoint.latitude, greaterThan(65));
    });

    test('handles coincident endpoints without dividing by zero', () {
      final midpoint = interpolateGreatCircle(london, london, 0.5);
      expect(midpoint.latitude, closeTo(london.latitude, 1e-9));
      expect(midpoint.longitude, closeTo(london.longitude, 1e-9));
    });
  });

  group('qiblaBearingDegrees', () {
    test('matches well known qibla directions', () {
      // These are the figures mosques in each city publish.
      expect(qiblaBearingDegrees(newYork), closeTo(58.5, 1.5));
      expect(qiblaBearingDegrees(london), closeTo(118.9, 1.5));
      expect(qiblaBearingDegrees(sanFrancisco), closeTo(18.7, 1.5));
      expect(qiblaBearingDegrees(istanbul), closeTo(151.6, 1.5));
      // Southern hemisphere, where the qibla points north of west.
      expect(qiblaBearingDegrees(const GeoPoint(-33.8688, 151.2093)),
          closeTo(277.5, 2.0));
    });

    test('is always within a compass turn', () {
      for (final point in [sanFrancisco, istanbul, london, newYork]) {
        expect(qiblaBearingDegrees(point), inInclusiveRange(0, 360));
      }
    });
  });

  group('relativeBearingDegrees', () {
    test('wraps into -180..180 and signs right as positive', () {
      expect(relativeBearingDegrees(0, 90), closeTo(90, 1e-9));
      expect(relativeBearingDegrees(0, 270), closeTo(-90, 1e-9));
      expect(relativeBearingDegrees(350, 10), closeTo(20, 1e-9));
      expect(relativeBearingDegrees(10, 350), closeTo(-20, 1e-9));
      expect(relativeBearingDegrees(0, 0), closeTo(0, 1e-9));
    });
  });

  group('compassLabel', () {
    test('labels the cardinal and intercardinal points', () {
      expect(compassLabel(0), 'N');
      expect(compassLabel(45), 'NE');
      expect(compassLabel(90), 'E');
      expect(compassLabel(180), 'S');
      expect(compassLabel(270), 'W');
      expect(compassLabel(359), 'N');
      expect(compassLabel(22.5), 'NNE');
    });
  });

  group('formatCoordinates', () {
    test('uses hemisphere letters rather than signs', () {
      expect(formatCoordinates(sanFrancisco), '37.6°N 122.4°W');
      expect(formatCoordinates(istanbul), '41.3°N 28.7°E');
      expect(formatCoordinates(const GeoPoint(-33.9, 151.2)),
          '33.9°S 151.2°E');
    });
  });
}
