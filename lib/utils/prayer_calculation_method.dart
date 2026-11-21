import 'package:flutter/foundation.dart';

import 'prayer_times.dart';
import 'shared_preferences.dart';

/// The Shia (Ja'fari) ways of computing Fajr, Maghrib and Isha that the app
/// offers. Both put Maghrib after the redness in the east has gone (an angle
/// below the horizon, not sunset itself) and midnight halfway from sunset to
/// Fajr; they differ in the angles.
///
/// Sunni methods (Karachi, ISNA, MWL, Umm al-Qura, Egypt) are deliberately
/// not offered: their Maghrib is at sunset.
enum PrayerCalculationMethod {
  /// Shia Ithna Ashari, Leva Institute, Qum: Fajr 16°, Maghrib 4°, Isha 14°.
  /// The app's method since it began, and still the default.
  jafari('jafari'),

  /// Institute of Geophysics, University of Tehran: Fajr 17.7°, Maghrib
  /// 4.5°, Isha 14°. Iran's official timetables.
  tehran('tehran');

  const PrayerCalculationMethod(this.storageId);

  /// What the preference stores. Never rename one: it is on readers' phones.
  final String storageId;

  /// [PrayerTime]'s number for this method.
  int idIn(PrayerTime prayerTime) => switch (this) {
    PrayerCalculationMethod.jafari => prayerTime.getJafari(),
    PrayerCalculationMethod.tehran => prayerTime.getTehran(),
  };

  static PrayerCalculationMethod fromStorageId(String? id) =>
      PrayerCalculationMethod.values.firstWhere(
        (method) => method.storageId == id,
        orElse: () => PrayerCalculationMethod.jafari,
      );
}

const String prayerCalculationMethodKey = 'prayer_calculation_method';

/// The method in effect. Changes go through [setPrayerCalculationMethod] so
/// listeners (Home's prayer times card) redraw.
final ValueNotifier<PrayerCalculationMethod> prayerCalculationMethod =
    ValueNotifier(PrayerCalculationMethod.jafari);

/// Reads the saved method; call once preferences are loaded.
void restorePrayerCalculationMethod() {
  if (!SP.isInitialized) return;
  prayerCalculationMethod.value = PrayerCalculationMethod.fromStorageId(
    SP.prefs.getString(prayerCalculationMethodKey),
  );
}

/// Saves [method] and makes it the one in effect. Rescheduling and
/// republishing what depends on the times is the caller's to do.
Future<void> setPrayerCalculationMethod(PrayerCalculationMethod method) async {
  if (SP.isInitialized) {
    await SP.prefs.setString(prayerCalculationMethodKey, method.storageId);
  }
  prayerCalculationMethod.value = method;
}
