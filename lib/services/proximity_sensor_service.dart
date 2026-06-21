import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ProximitySensorService {
  const ProximitySensorService();

  static const MethodChannel _methodChannel =
      MethodChannel('shia_companion/proximity_sensor');
  static const EventChannel _eventChannel =
      EventChannel('shia_companion/proximity_sensor_events');

  bool get supportsCurrentPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<bool> isAvailable() async {
    if (!supportsCurrentPlatform) return false;

    try {
      return await _methodChannel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Stream<bool> get proximityStates {
    if (!supportsCurrentPlatform) return const Stream<bool>.empty();
    return _eventChannel.receiveBroadcastStream().map((event) => event == true);
  }
}
