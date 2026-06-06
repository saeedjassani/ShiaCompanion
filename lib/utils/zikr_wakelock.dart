import 'package:wakelock_plus/wakelock_plus.dart';

import 'shared_preferences.dart';

final Set<Object> _activeZikrWakelockOwners = <Object>{};

void syncZikrWakelockPreference({
  required Object owner,
  required bool isActive,
}) {
  if (isActive) {
    _activeZikrWakelockOwners.add(owner);
  } else {
    _activeZikrWakelockOwners.remove(owner);
  }

  final keepAwake =
      SP.isInitialized ? SP.prefs.getBool('keep_awake') ?? true : false;

  if (_activeZikrWakelockOwners.isNotEmpty && keepAwake) {
    WakelockPlus.enable();
  } else {
    WakelockPlus.disable();
  }
}
