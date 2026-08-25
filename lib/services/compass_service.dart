import '../models/compass_reading.dart';

import 'compass_platform_stub.dart'
    if (dart.library.io) 'compass_platform_io.dart'
    if (dart.library.js_interop) 'compass_platform_web.dart' as platform;

/// Where heading readings come from.
///
/// An interface rather than a bare function so a widget test can drive the
/// compass without a magnetometer: the page takes one of these, and the tests
/// hand it a stream they control.
abstract class CompassSource {
  /// Whether [requestPermission] has to be called from a user gesture before
  /// any readings arrive. True only on iOS Safari, which gates the sensor.
  bool get requiresPermission;

  Future<bool> requestPermission();

  /// A stream of headings, or null when this build has no compass at all.
  ///
  /// A non-null stream is not a promise of readings — a phone with no
  /// magnetometer returns one that stays silent — so callers still need to
  /// handle nothing arriving.
  Stream<CompassReading>? open();
}

/// The real device compass.
class PlatformCompassSource implements CompassSource {
  const PlatformCompassSource();

  @override
  bool get requiresPermission => platform.compassRequiresPermission;

  @override
  Future<bool> requestPermission() => platform.requestCompassPermission();

  @override
  Stream<CompassReading>? open() => platform.openCompassStream();
}
