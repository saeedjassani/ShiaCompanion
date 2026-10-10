import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/l10n/app_language.dart';
import 'package:shia_companion/l10n/hijri_l10n.dart';
import 'package:shia_companion/l10n/l10n.dart';
import 'package:shia_companion/utils/language_provider.dart';
import 'package:shia_companion/utils/prayer_times.dart';

void main() {
  group('app text', () {
    test('every shipped ARB file is a language the app knows', () {
      for (final locale in AppLocalizations.supportedLocales) {
        expect(appLanguageFor(locale.languageCode), isNotNull,
            reason: 'Add ${locale.languageCode} to appLanguages in '
                'lib/l10n/app_language.dart');
      }
      expect(LanguageProvider.appTextLanguages.first.code, 'en');
    });

    test('no translation uses a placeholder English does not declare', () {
      final english = _arb('lib/l10n/app_en.arb');
      final translations = Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((f) => RegExp(r'app_\w+\.arb$').hasMatch(f.path))
          .where((f) => !f.path.endsWith('app_en.arb'));
      for (final file in translations) {
        final translated = _arb(file.path);
        for (final entry in translated.entries) {
          if (entry.key.startsWith('@')) continue;
          expect(english.containsKey(entry.key), isTrue,
              reason: '${file.path}: ${entry.key} is not in app_en.arb');
          final declared =
              ((english['@${entry.key}'] as Map?)?['placeholders'] as Map?)
                      ?.keys
                      .toSet() ??
                  const <String>{};
          expect(_placeholders(entry.value as String).difference(declared),
              isEmpty,
              reason: '${file.path}: ${entry.key} - a misspelt placeholder '
                  'would show literally on screen');
        }
      }
    });

    testWidgets('context.l10n falls back to English without delegates',
        (tester) async {
      late String text;
      await tester.pumpWidget(Builder(builder: (context) {
        text = context.l10n.commonCancel;
        return const SizedBox();
      }));
      expect(text, 'Cancel');
    });
  });

  group('names that double as identifiers', () {
    test('every prayer name has a display name', () {
      final names = [...PrayerTime().getTimeNames(), 'Midnight'];
      for (final name in names) {
        expect(localizedPrayerName(name), isNotEmpty);
      }
      // English shows the identifiers themselves.
      expect(names.map(localizedPrayerName), names);
      expect(localizedPrayerName('Unknown'), 'Unknown');
    });

    test('weekday and Hijri month names cover every value', () {
      expect(
        [for (var day = 1; day <= 7; day++) shortWeekdayName(day)],
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      );
      expect(hijriMonthName(1), 'Muharram');
      expect(hijriMonthName(12), 'Dhu Al-Hijjah');
      expect(
        {for (var month = 1; month <= 12; month++) hijriMonthShortName(month)},
        hasLength(12),
      );
    });
  });

  group('digits', () {
    test('English keeps 0-9', () {
      expect(
          localizeDigits('5:25 am', lookupAppLocalizations(const Locale('en'))),
          '5:25 am');
    });

    testWidgets('Arabic writes numbers in Arabic-Indic digits', (tester) async {
      SharedPreferences.setMockInitialValues(
          {LanguageProvider.appLanguagePrefsKey: 'ar'});
      final provider = LanguageProvider();
      addTearDown(() async {
        await provider.setAppLanguage(englishLanguageCode);
        provider.dispose();
      });
      await tester.runAsync(() async {
        while (provider.appLanguage.code != 'ar') {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

      // Hand-built strings, int placeholders, and intl dates and numbers.
      expect(localizeDigits('5:25 am'), '٥:٢٥ am');
      expect(L10n.current.calendarDaysAgo(5), contains('٥'));
      expect(DateFormat('d').format(DateTime(2026, 10, 18)), '١٨');
      expect(NumberFormat.decimalPattern().format(1448), '١٬٤٤٨');
    });

    test('Urdu and Gujarati write their own digits, not intl\'s 0-9', () {
      final ur = lookupAppLocalizations(const Locale('ur'));
      final gu = lookupAppLocalizations(const Locale('gu'));
      expect(localizeDigits('5:25', ur), '۵:۲۵');
      expect(localizeDigits('5:25', gu), '૫:૨૫');
      expect(asciiDigits('۳۳:۳۳ ٢ ૧૮'), '33:33 2 18');
    });

    test('a prayer time gets the language\'s am/pm', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final ur = lookupAppLocalizations(const Locale('ur'));
      final fa = lookupAppLocalizations(const Locale('fa'));
      expect(localizeClockTime('05:12 pm', en), '05:12 pm');
      expect(localizeClockTime('05:12 am', ur), '۰۵:۱۲ ${ur.timeAm}');
      expect(localizeClockTime('7:45 PM', fa), '۷:۴۵ ${fa.timePm}');
    });

    testWidgets('Urdu dates and numbers come out in Urdu digits and am/pm',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {LanguageProvider.appLanguagePrefsKey: 'ur'});
      final provider = LanguageProvider();
      addTearDown(() async {
        await provider.setAppLanguage(englishLanguageCode);
        provider.dispose();
      });
      await tester.runAsync(() async {
        // Past the provider's own load, which would otherwise land after.
        while (provider.translationLanguages.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await provider.setAppLanguage('ur');
      });

      expect(L10n.current.calendarDaysAgo(5), contains('۵'));
      expect(DateFormat('h:mm a').format(DateTime(2026, 10, 18, 19, 5)),
          '۷:۰۵ ${L10n.current.timePm}');
      expect(NumberFormat.decimalPattern().format(1448), '۱,۴۴۸');
    });

    testWidgets('Material\'s locale load does not undo the Urdu digits',
        (tester) async {
      String? shown;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ur'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          IntlSymbolsDelegate(),
        ],
        home: Builder(builder: (context) {
          shown = DateFormat('h:mm a', 'ur').format(DateTime(2026, 1, 1, 5));
          return const SizedBox();
        }),
      ));
      expect(
          shown, '۵:۰۰ ${lookupAppLocalizations(const Locale('ur')).timeAm}');
    });
  });

  test('the language catalog has the languages the app is prepared for', () {
    expect(appLanguages.map((l) => l.code), ['en', 'ur', 'fa', 'ar', 'gu']);
    expect(
      appLanguages.where((l) => l.isRtl).map((l) => l.code),
      ['ur', 'fa', 'ar'],
    );
  });
}

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// The `{name}` / `{name, plural, ...}` placeholders a message uses.
Set<String> _placeholders(String message) => RegExp(r'\{([A-Za-z_]\w*)\s*[,}]')
    .allMatches(message)
    .map((m) => m.group(1)!)
    .toSet();
