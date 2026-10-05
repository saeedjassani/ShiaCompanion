import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
