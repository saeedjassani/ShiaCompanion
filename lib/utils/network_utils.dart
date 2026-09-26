import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkUtils {
  static final NetworkUtils _instance = NetworkUtils._internal();

  factory NetworkUtils() => _instance;

  NetworkUtils._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Future<bool> isDeviceOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Whether the only connection is mobile data - no Wi-Fi or ethernet - so
  /// a large download should be confirmed first. False when unknown.
  Future<bool> isOnMobileDataOnly() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.contains(ConnectivityResult.mobile) &&
          !result.contains(ConnectivityResult.wifi) &&
          !result.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize() async {
    _isOnline = await isDeviceOnline();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOffline = !_isOnline;
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      if (wasOffline && _isOnline) {
        // Optional: notify listeners when coming back online
      }
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
