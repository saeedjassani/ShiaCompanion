import 'package:flutter/widgets.dart';
import 'package:shia_companion/l10n/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations? get l10n => AppLocalizations.of(this);
}

String localizedPrayerName(BuildContext context, String name) {
  final l10n = context.l10n;
  if (l10n == null) return name;
  switch (name.trim().toLowerCase()) {
    case 'fajr':
      return l10n.fajr;
    case 'sunrise':
      return l10n.sunrise;
    case 'zuhr':
    case 'dhuhr':
      return l10n.dhuhr;
    case 'asr':
      return l10n.asr;
    case 'maghrib':
      return l10n.maghrib;
    case 'isha':
      return l10n.isha;
    case 'midnight':
      return l10n.midnight;
    default:
      return name;
  }
}
