import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../models/compass_reading.dart';
import '../utils/geo_utils.dart';

/// Android and iOS both grant sensor access without a prompt. Location
/// permission is a separate matter — the page needs coordinates anyway — but
/// the magnetometer itself is not gated.
bool get compassRequiresPermission => false;

Future<bool> requestCompassPermission() async => true;

Stream<CompassReading>? openCompassStream() {
  // Desktop has no compass, and the plugin has no desktop implementation, so
  // touching the channel there only produces a MissingPluginException.
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return null;
  }

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return _quietly(_iosHeadingChannel
        .receiveBroadcastStream()
        .map(iosHeadingEventToReading));
  }

  final events = FlutterCompass.events;
  if (events == null) return null;
  return _quietly(events.map(androidCompassEventToReading));
}

/// Fed by `SCHeadingStreamHandler` in `ios/Runner/AppDelegate.m`.
///
/// iOS does not use flutter_compass: the plugin only forwards `trueHeading`,
/// which Core Location leaves at -1 unless that same location manager is also
/// running location updates — and the plugin's never is. The result, on
/// iPhones with working magnetometers, was a stream of nothing but -1s and a
/// screen claiming there was no compass (issue #62).
const EventChannel _iosHeadingChannel =
    EventChannel('shia_companion/compass_heading');

Stream<CompassReading> _quietly(Stream<CompassReading?> readings) {
  return readings
      // A device with no magnetometer errors the channel rather than going
      // quiet. Swallowing it here leaves the stream silent, which is what the
      // caller's "no reading yet" timeout is already built to handle, instead
      // of an unhandled error tearing the page down.
      .handleError((Object _) {})
      .where((reading) => reading != null)
      .cast<CompassReading>();
}

/// Converts one `[magneticHeading, trueHeading, headingAccuracy]` event from
/// the iOS heading channel.
///
/// Prefers Core Location's own true heading, and falls back to the magnetic
/// one — which the page corrects with its declination model — when true north
/// is unavailable (reported as a negative number). A negative accuracy means
/// Core Location has no valid heading at all, typically an uncalibrated
/// compass, so that sample is dropped.
@visibleForTesting
CompassReading? iosHeadingEventToReading(Object? event) {
  if (event is! List || event.length < 3) return null;
  final magnetic = (event[0] as num?)?.toDouble();
  final trueNorth = (event[1] as num?)?.toDouble();
  final accuracy = (event[2] as num?)?.toDouble();
  if (accuracy == null || !accuracy.isFinite || accuracy < 0) return null;

  final accuracyDegrees = accuracy > 0 ? accuracy : null;
  if (trueNorth != null && trueNorth.isFinite && trueNorth >= 0) {
    return CompassReading(
      headingDegrees: normalizeBearing(trueNorth),
      reference: NorthReference.geographic,
      accuracyDegrees: accuracyDegrees,
    );
  }
  if (magnetic != null && magnetic.isFinite && magnetic >= 0) {
    return CompassReading(
      headingDegrees: normalizeBearing(magnetic),
      reference: NorthReference.magnetic,
      accuracyDegrees: accuracyDegrees,
    );
  }
  return null;
}

/// Android's rotation-vector heading, measured from magnetic north. It has no
/// sentinel: negatives are ordinary westerly readings.
@visibleForTesting
CompassReading? androidCompassEventToReading(CompassEvent event) {
  final heading = event.heading;
  if (heading == null || !heading.isFinite) return null;

  final accuracy = event.accuracy;
  return CompassReading(
    headingDegrees: normalizeBearing(heading),
    reference: NorthReference.magnetic,
    accuracyDegrees: accuracy != null && accuracy >= 0 && accuracy.isFinite
        ? accuracy
        : null,
  );
}
