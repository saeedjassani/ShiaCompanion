import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../models/compass_reading.dart';
import '../utils/geo_utils.dart';

/// Browser compass, built on `DeviceOrientationEvent`.
///
/// Two dialects have to be handled. Safari never implemented the spec's
/// absolute orientation and instead exposes `webkitCompassHeading`, a ready-made
/// compass bearing. Chrome on Android fires `deviceorientationabsolute` with
/// Euler angles that have to be turned into a bearing. Both are measured from
/// magnetic north, so both need the declination correction the caller applies.
///
/// Desktop browsers have no magnetometer and simply never fire a usable event.
/// Nothing here reports that; the caller's "no reading yet" timeout does, which
/// keeps one code path for "this browser can't" and "this phone can't".

/// iOS 13 and later gate the sensor behind a permission call that must happen
/// inside a user gesture — hence a button in the UI rather than a request on
/// page load.
bool get compassRequiresPermission {
  final constructor = _deviceOrientationEventClass;
  return constructor != null &&
      constructor.hasProperty('requestPermission'.toJS).toDart;
}

Future<bool> requestCompassPermission() async {
  final constructor = _deviceOrientationEventClass;
  if (constructor == null) return false;
  if (!constructor.hasProperty('requestPermission'.toJS).toDart) return true;

  try {
    final response =
        constructor.callMethod<JSPromise<JSAny?>>('requestPermission'.toJS);
    final state = (await response.toDart)?.dartify();
    return state == 'granted';
  } catch (_) {
    // Safari throws rather than resolving when the call is not inside a user
    // gesture. Either way the answer is "no readings", which is what false says.
    return false;
  }
}

Stream<CompassReading>? openCompassStream() {
  if (_deviceOrientationEventClass == null) return null;

  late final StreamController<CompassReading> controller;
  late final web.EventListener listener;

  void emit(web.Event event) {
    final reading = _toReading(event as JSObject);
    if (reading != null && !controller.isClosed) controller.add(reading);
  }

  void subscribe() {
    listener = emit.toJS;
    // Both, not one or the other: Chrome fires only the absolute event, Safari
    // only the plain one, and a browser that fires both simply gives us the
    // same bearing twice.
    web.window.addEventListener('deviceorientationabsolute', listener);
    web.window.addEventListener('deviceorientation', listener);
  }

  void unsubscribe() {
    web.window.removeEventListener('deviceorientationabsolute', listener);
    web.window.removeEventListener('deviceorientation', listener);
  }

  controller = StreamController<CompassReading>(
    onListen: subscribe,
    onCancel: unsubscribe,
  );
  return controller.stream;
}

CompassReading? _toReading(JSObject event) {
  final webkitHeading = _numberProperty(event, 'webkitCompassHeading');
  if (webkitHeading != null) {
    final accuracy = _numberProperty(event, 'webkitCompassAccuracy');
    return CompassReading(
      headingDegrees: normalizeBearing(webkitHeading + _screenAngleDegrees),
      reference: NorthReference.magnetic,
      accuracyDegrees: accuracy != null && accuracy >= 0 ? accuracy : null,
    );
  }

  // Without the absolute flag the angles are relative to wherever the device
  // happened to be when the page loaded, which is worthless as a compass.
  final absolute = event.getProperty<JSAny?>('absolute'.toJS);
  if (!absolute.isA<JSBoolean>() || !(absolute as JSBoolean).toDart) return null;

  final alpha = _numberProperty(event, 'alpha');
  final beta = _numberProperty(event, 'beta');
  final gamma = _numberProperty(event, 'gamma');
  if (alpha == null || beta == null || gamma == null) return null;

  return CompassReading(
    headingDegrees:
        normalizeBearing(_headingFromEulerAngles(alpha, beta, gamma) +
            _screenAngleDegrees),
    reference: NorthReference.magnetic,
  );
}

/// Bearing of the device's top edge from the spec's alpha/beta/gamma triple.
///
/// Reading alpha directly is only correct with the phone flat on a table; this
/// projects the device's axes onto the horizontal plane so a phone held up at
/// reading angle still points the right way.
double _headingFromEulerAngles(double alpha, double beta, double gamma) {
  const toRadians = math.pi / 180.0;
  final cosAlpha = math.cos(alpha * toRadians);
  final sinAlpha = math.sin(alpha * toRadians);
  final sinBeta = math.sin(beta * toRadians);
  final cosGamma = math.cos(gamma * toRadians);
  final sinGamma = math.sin(gamma * toRadians);

  final east = -cosAlpha * sinGamma - sinAlpha * sinBeta * cosGamma;
  final north = -sinAlpha * sinGamma + cosAlpha * sinBeta * cosGamma;

  return math.atan2(east, north) * 180.0 / math.pi;
}

/// How far the page is rotated inside the device, so the dial follows the top
/// of the *screen* rather than the top of the *handset* in landscape.
double get _screenAngleDegrees {
  final orientation = web.window.screen.getProperty<JSAny?>('orientation'.toJS);
  if (!orientation.isA<JSObject>()) return 0;
  return _numberProperty(orientation as JSObject, 'angle') ?? 0;
}

JSObject? get _deviceOrientationEventClass {
  final value = web.window.getProperty<JSAny?>('DeviceOrientationEvent'.toJS);
  return value.isA<JSObject>() ? value as JSObject : null;
}

/// Reads a finite number off a JS object, or null for anything else — absent,
/// null, NaN, or a value of some other type.
double? _numberProperty(JSObject object, String name) {
  final value = object.getProperty<JSAny?>(name.toJS);
  if (!value.isA<JSNumber>()) return null;
  final number = (value as JSNumber).toDartDouble;
  return number.isFinite ? number : null;
}
