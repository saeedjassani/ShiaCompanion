import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import '../services/analytics_service.dart';
import '../services/home_screen_widget_service.dart';
import '../utils/prayer_calculation_method.dart';
import 'choice_sheet.dart';

/// [method]'s name, as Settings shows it.
String prayerMethodLabel(
  AppLocalizations l10n,
  PrayerCalculationMethod method,
) => switch (method) {
  PrayerCalculationMethod.jafari => l10n.settingsPrayerMethodJafari,
  PrayerCalculationMethod.tehran => l10n.settingsPrayerMethodTehran,
  PrayerCalculationMethod.iraqShrines => l10n.settingsPrayerMethodIraq,
};

/// Settings' Calculation method: Automatic (by the prayer location's
/// country), or one of the Shia methods. Saves what is picked and brings
/// the azan, reminders and widgets up to date. Resolves to whether the
/// choice changed.
Future<bool> showPrayerMethodSheet(BuildContext context) async {
  final l10n = context.l10n;
  final current = prayerCalculationMethodChoice;
  final automatic = PrayerCalculationMethod.defaultFor(prayerLocationCountry);
  // Records, not a nullable method: the sheet resolves to null when it is
  // dismissed.
  final picked = await showChoiceSheet<({PrayerCalculationMethod? method})>(
    context,
    title: l10n.settingsPrayerMethod,
    body: l10n.settingsPrayerMethodBody,
    current: (method: current),
    choices: [
      Choice(
        (method: null),
        l10n.settingsPrayerMethodAutomatic,
        hint: l10n.settingsPrayerMethodAutomaticHint(
          prayerMethodLabel(l10n, automatic),
        ),
      ),
      for (final method in PrayerCalculationMethod.values)
        Choice((method: method), prayerMethodLabel(l10n, method)),
    ],
  );
  if (picked == null || picked.method == current) return false;
  final before = prayerCalculationMethod.value;
  await setPrayerCalculationMethodChoice(picked.method);
  unawaited(
    AnalyticsService.feature(
      'prayer_method_changed',
      label: 'Prayer method changed',
      parameters: {'method': picked.method?.storageId ?? 'automatic'},
    ),
  );
  // Automatic and the method it stands for give the same times.
  if (prayerCalculationMethod.value != before) {
    unawaited(_applyNewTimes());
  }
  return true;
}

Future<void> _applyNewTimes() async {
  try {
    await HomeScreenWidgetService.instance.publishAll();
  } catch (e) {
    debugPrint('Prayer method changed, but publishing it failed: $e');
  }
  await reschedulePrayerTimeNotifications();
}
