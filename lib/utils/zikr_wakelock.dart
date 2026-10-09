import 'package:wakelock_plus/wakelock_plus.dart';

import 'shared_preferences.dart';

final Set<Object> _activeZikrWakelockOwners = <Object>{};

/// Owners keeping the screen on whatever the Keep screen on setting says -
/// a reader auto-scrolling, whose hands are off the screen by design.
final Set<Object> _forcedZikrWakelockOwners = <Object>{};

void syncZikrWakelockPreference({
  required Object owner,
  required bool isActive,
  bool forceAwake = false,
}) {
  if (isActive) {
    _activeZikrWakelockOwners.add(owner);
  } else {
    _activeZikrWakelockOwners.remove(owner);
  }
  if (isActive && forceAwake) {
    _forcedZikrWakelockOwners.add(owner);
  } else {
    _forcedZikrWakelockOwners.remove(owner);
  }

  final keepAwake =
      SP.isInitialized ? SP.prefs.getBool('keep_awake') ?? true : false;

  if (_forcedZikrWakelockOwners.isNotEmpty ||
      (_activeZikrWakelockOwners.isNotEmpty && keepAwake)) {
    WakelockPlus.enable();
  } else {
    WakelockPlus.disable();
  }
}
