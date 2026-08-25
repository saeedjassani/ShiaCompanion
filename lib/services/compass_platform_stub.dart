import '../models/compass_reading.dart';

/// Fallback for platforms with neither `dart:io` nor `dart:js_interop`. There
/// are none today; it exists so the conditional import in [CompassSource] has
/// a default and the file resolves under any future target.
bool get compassRequiresPermission => false;

Future<bool> requestCompassPermission() async => false;

Stream<CompassReading>? openCompassStream() => null;
