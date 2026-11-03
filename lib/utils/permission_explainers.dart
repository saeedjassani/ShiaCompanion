import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../constants.dart';

/// App Store Review guideline 5.1.1(iv): a screen that explains why the app
/// wants a permission, shown before the OS has asked for it, must lead on to
/// the OS prompt - no "Not now", "Skip" or other way to put the prompt off.
/// Apple rejected setup's location step for exactly that.
///
/// So on iOS, while a permission is still unasked, the explainers offer only
/// the way on: setup's Location and Azan steps show a single Continue, Home's
/// "Which city are you in?" card has no Not now, and its azan question waits
/// until notifications are already allowed. Android and the web keep their
/// Not now. See docs/DESIGN_SPEC.md, "First-run setup".
class PermissionExplainers {
  PermissionExplainers._();

  /// Lets tests choose the answers instead of calling the plugins.
  @visibleForTesting
  static Future<bool> Function()? debugLocationPromptPending;
  @visibleForTesting
  static Future<bool> Function()? debugNotificationsAllowed;

  /// Whether explainers here must lead straight on to the OS prompt.
  static bool get mustLeadToPrompt =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Whether the OS has yet to ask for location. Geolocator reports iOS's
  /// "not determined" as [LocationPermission.denied]; a refusal there is
  /// [LocationPermission.deniedForever], since iOS never asks twice. Unknown
  /// counts as unasked, so a failed check never brings Not now back.
  static Future<bool> locationPromptPending() async {
    final debug = debugLocationPromptPending;
    if (debug != null) return debug();
    try {
      return await Geolocator.checkPermission() == LocationPermission.denied;
    } catch (e) {
      debugPrint('Could not read the location permission: $e');
      return true;
    }
  }

  /// Whether iOS already lets the app post notifications. False when it
  /// hasn't been asked yet, when it was refused, or when that can't be read.
  static Future<bool> notificationsAllowed() async {
    final debug = debugNotificationsAllowed;
    if (debug != null) return debug();
    try {
      final plugin = await ensureNotificationsPlugin();
      final options = await plugin
          ?.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return options?.isEnabled ?? false;
    } catch (e) {
      debugPrint('Could not read the notification permission: $e');
      return false;
    }
  }
}
