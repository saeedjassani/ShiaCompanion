import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/l10n/app_localizations.dart';
import 'package:shia_companion/navigation/home_menu.dart';
import 'package:shia_companion/utils/l10n_extension.dart';

void main() {
  testWidgets('loads English localizations correctly', (tester) async {
    late BuildContext savedContext;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            savedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final l10n = savedContext.l10n!;
    expect(l10n.prayers, equals('Prayers'));
    expect(l10n.calendar, equals('Calendar'));
    expect(l10n.settings, equals('Settings'));
    expect(l10n.darkMode, equals('Dark Mode'));
    expect(l10n.language, equals('Language'));
    expect(l10n.fajr, equals('Fajr'));
    expect(l10n.sunrise, equals('Sunrise'));
    expect(l10n.dhuhr, equals('Dhuhr'));
    expect(l10n.asr, equals('Asr'));
    expect(l10n.maghrib, equals('Maghrib'));
    expect(l10n.isha, equals('Isha'));
    expect(l10n.midnight, equals('Midnight'));
    expect(l10n.nextDay, equals('(next day)'));

    expect(localizedPrayerName(savedContext, 'Sunrise'), equals('Sunrise'));
    expect(localizedPrayerName(savedContext, 'Zuhr'), equals('Dhuhr'));

    final settingsItem = homeMenuItems.firstWhere((item) => item.label == 'Preferences');
    expect(settingsItem.localizedLabel(savedContext), equals('Settings'));
  });

  testWidgets('loads French localizations correctly', (tester) async {
    late BuildContext savedContext;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            savedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final l10n = savedContext.l10n!;
    expect(l10n.prayers, equals('Prières'));
    expect(l10n.calendar, equals('Calendrier'));
    expect(l10n.settings, equals('Paramètres'));
    expect(l10n.darkMode, equals('Mode sombre'));
    expect(l10n.language, equals('Langue'));
    expect(l10n.fajr, equals('Fajr'));
    expect(l10n.sunrise, equals('Lever du soleil'));
    expect(l10n.dhuhr, equals('Dhohr'));
    expect(l10n.asr, equals('Asr'));
    expect(l10n.maghrib, equals('Maghrib'));
    expect(l10n.isha, equals('Isha'));
    expect(l10n.midnight, equals('Minuit'));
    expect(l10n.nextDay, equals('(jour suivant)'));

    expect(localizedPrayerName(savedContext, 'Sunrise'), equals('Lever du soleil'));
    expect(localizedPrayerName(savedContext, 'Zuhr'), equals('Dhohr'));

    final settingsItem = homeMenuItems.firstWhere((item) => item.label == 'Preferences');
    expect(settingsItem.localizedLabel(savedContext), equals('Paramètres'));

    final favItem = homeMenuItems.firstWhere((item) => item.label == 'Favorites');
    expect(favItem.localizedLabel(savedContext), equals('Favoris'));
  });
}
