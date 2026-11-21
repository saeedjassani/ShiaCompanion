import 'package:flutter/foundation.dart';

import 'prayer_times.dart';
import 'shared_preferences.dart';

/// The Shia (Ja'fari) ways of computing Fajr, Maghrib and Isha that the app
/// offers. All put Maghrib after the redness in the east has gone (an angle
/// below the horizon, not sunset itself) and midnight halfway from sunset to
/// Fajr; they differ in the angles.
///
/// Sunni methods (Karachi, ISNA, MWL, Umm al-Qura, Egypt) are deliberately
/// not offered: their Maghrib is at sunset.
enum PrayerCalculationMethod {
  /// Shia Ithna Ashari, Leva Institute, Qum: Fajr 16°, Maghrib 4°, Isha 14°.
  /// The app's only method before there was a choice, and the default
  /// outside Iraq and Iran.
  jafari('jafari'),

  /// Institute of Geophysics, University of Tehran: Fajr 17.7°, Maghrib
  /// 4.5°, Isha 14°. Iran's official timetables; the default in Iran.
  tehran('tehran'),

  /// The holy shrines of Najaf and Karbala: Fajr 18°, Maghrib 4°, Isha 14°.
  /// The Imam Ali shrine's site runs PrayTimes.js with its Jafari Fajr
  /// changed from 16° to 18°, and the Abbas shrine's published times
  /// (alkafeel.net) fit the same angles to the minute. The default in Iraq.
  iraqShrines('iraq_shrines');

  const PrayerCalculationMethod(this.storageId);

  /// What the preference stores. Never rename one: it is on readers' phones.
  final String storageId;

  /// [PrayerTime]'s number for this method.
  int idIn(PrayerTime prayerTime) => switch (this) {
    PrayerCalculationMethod.jafari => prayerTime.getJafari(),
    PrayerCalculationMethod.tehran => prayerTime.getTehran(),
    PrayerCalculationMethod.iraqShrines => prayerTime.getIraqShrines(),
  };

  /// The method chosen in Settings, or null for Automatic (nothing saved,
  /// or a value this version doesn't know).
  static PrayerCalculationMethod? fromStorageId(String? id) {
    for (final method in PrayerCalculationMethod.values) {
      if (method.storageId == id) return method;
    }
    return null;
  }

  /// What Automatic uses where the prayer location is in [countryCode]
  /// (ISO 3166 alpha-2, as the city list has it).
  static PrayerCalculationMethod defaultFor(String? countryCode) =>
      switch (countryCode) {
        'IQ' => PrayerCalculationMethod.iraqShrines,
        'IR' => PrayerCalculationMethod.tehran,
        _ => PrayerCalculationMethod.jafari,
      };
}

/// The method chosen in Settings; absent for Automatic.
const String prayerCalculationMethodKey = 'prayer_calculation_method';

/// The country of the prayer location, which Automatic goes by. Absent
/// until it is first worked out (see [setPrayerLocationCountry]).
const String prayerLocationCountryKey = 'prayer_location_country';

/// The method whose change the prayer times card still has to tell the
/// reader about (see [notePrayerMethodChangedOnUpdate]); absent otherwise.
const String prayerMethodNoticeKey = 'prayer_method_notice';

PrayerCalculationMethod? _choice;
String? _country;

/// The method in effect: the one chosen in Settings, or Automatic's for the
/// prayer location. Listeners (Home's prayer times card) redraw on a change.
final ValueNotifier<PrayerCalculationMethod> prayerCalculationMethod =
    ValueNotifier(PrayerCalculationMethod.jafari);

/// The method chosen in Settings, or null for Automatic.
PrayerCalculationMethod? get prayerCalculationMethodChoice => _choice;

/// The prayer location's country, once known.
String? get prayerLocationCountry => _country;

/// Whether the prayer location's country has been worked out.
bool get hasPrayerLocationCountry => _country != null;

void _recompute() {
  prayerCalculationMethod.value =
      _choice ?? PrayerCalculationMethod.defaultFor(_country);
}

/// Reads the saved choice and country; call once preferences are loaded.
void restorePrayerCalculationMethod() {
  if (!SP.isInitialized) return;
  _choice = PrayerCalculationMethod.fromStorageId(
    SP.prefs.getString(prayerCalculationMethodKey),
  );
  _country = SP.prefs.getString(prayerLocationCountryKey);
  _recompute();
}

/// Saves [method] as the reader's choice, or Automatic when null.
/// Rescheduling and republishing what depends on the times is the caller's.
Future<void> setPrayerCalculationMethodChoice(
  PrayerCalculationMethod? method,
) async {
  _choice = method;
  if (SP.isInitialized) {
    if (method == null) {
      await SP.prefs.remove(prayerCalculationMethodKey);
    } else {
      await SP.prefs.setString(prayerCalculationMethodKey, method.storageId);
    }
    // Choosing is answer enough to the notice about Automatic's change.
    await SP.prefs.remove(prayerMethodNoticeKey);
  }
  _recompute();
}

/// Records the prayer location's [countryCode] (empty when unknown, e.g.
/// out at sea). Returns whether the method in effect changed.
Future<bool> setPrayerLocationCountry(String countryCode) async {
  final before = prayerCalculationMethod.value;
  _country = countryCode;
  if (SP.isInitialized) {
    await SP.prefs.setString(prayerLocationCountryKey, countryCode);
  }
  _recompute();
  return prayerCalculationMethod.value != before;
}

/// The method the prayer times card should announce, if any.
PrayerCalculationMethod? get pendingPrayerMethodNotice {
  if (!SP.isInitialized) return null;
  final pending = PrayerCalculationMethod.fromStorageId(
    SP.prefs.getString(prayerMethodNoticeKey),
  );
  // Stale if the method has moved on since (another city, or a choice).
  return pending == prayerCalculationMethod.value ? pending : null;
}

/// An update moved an existing reader's times off the method they had
/// (Leva) onto Automatic's for their country: the card says so once.
Future<void> notePrayerMethodChangedOnUpdate() async {
  if (!SP.isInitialized) return;
  await SP.prefs.setString(
    prayerMethodNoticeKey,
    prayerCalculationMethod.value.storageId,
  );
}

Future<void> dismissPrayerMethodNotice() async {
  if (SP.isInitialized) await SP.prefs.remove(prayerMethodNoticeKey);
}

@visibleForTesting
void resetPrayerCalculationMethodForTest() {
  _choice = null;
  _country = null;
  _recompute();
}
