import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/geo_utils.dart';
import 'package:shia_companion/utils/maps_links.dart';

void main() {
  const shrine = GeoPoint(32.02967, 44.31452);

  test('Apple Maps on iOS and macOS, labelled', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      final uri = mapsUriFor(shrine, 'العتبة العلوية', platform: platform);
      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters['ll'], '32.02967,44.31452');
      expect(uri.queryParameters['q'], 'العتبة العلوية');
    }
  });

  test('Google Maps everywhere else', () {
    final uri = mapsUriFor(shrine, 'x', platform: TargetPlatform.android);
    expect(uri.toString(),
        'https://www.google.com/maps/search/?api=1&query=32.02967%2C44.31452');
  });
}
