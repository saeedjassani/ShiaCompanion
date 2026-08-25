import 'package:flutter/foundation.dart';
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

  final events = FlutterCompass.events;
  if (events == null) return null;

  final reference = defaultTargetPlatform == TargetPlatform.iOS
      ? NorthReference.geographic
      : NorthReference.magnetic;

  return events
      // A device with no magnetometer errors the channel rather than going
      // quiet. Swallowing it here leaves the stream silent, which is what the
      // caller's "no reading yet" timeout is already built to handle, instead
      // of an unhandled error tearing the page down.
      .handleError((Object _) {})
      .map((event) => _toReading(event, reference))
      .where((reading) => reading != null)
      .cast<CompassReading>();
}

CompassReading? _toReading(CompassEvent event, NorthReference reference) {
  final heading = event.heading;
  if (heading == null || !heading.isFinite) return null;

  // Core Location reports -1 when it cannot derive true north — no location
  // fix, or heading unavailable. Android has no such sentinel; its heading is
  // a signed angle where negatives are ordinary westerly readings.
  if (reference == NorthReference.geographic && heading < 0) return null;

  final accuracy = event.accuracy;
  return CompassReading(
    headingDegrees: normalizeBearing(heading),
    reference: reference,
    accuracyDegrees:
        accuracy != null && accuracy >= 0 && accuracy.isFinite ? accuracy : null,
  );
}
