import 'package:flutter/foundation.dart';

import 'geo_utils.dart';

/// A link that opens [point] in the platform's maps app, labelled [label]:
/// Apple Maps on iOS and macOS, Google Maps (its app when installed, else
/// the website) everywhere else, the web included.
///
/// A link rather than an in-app map: no SDK, no tiles to license or cache,
/// and the maps app gives walking directions from where the pilgrim stands.
Uri mapsUriFor(GeoPoint point, String label, {TargetPlatform? platform}) {
  final ll = '${point.latitude.toStringAsFixed(5)},'
      '${point.longitude.toStringAsFixed(5)}';
  final target = platform ?? (kIsWeb ? null : defaultTargetPlatform);
  if (target == TargetPlatform.iOS || target == TargetPlatform.macOS) {
    return Uri.https('maps.apple.com', '/', {'ll': ll, 'q': label});
  }
  return Uri.https(
      'www.google.com', '/maps/search/', {'api': '1', 'query': ll});
}
