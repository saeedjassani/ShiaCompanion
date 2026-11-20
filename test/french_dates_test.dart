import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shia_companion/l10n/app_localizations.dart';
import 'package:shia_companion/l10n/hijri_l10n.dart';
import 'package:shia_companion/utils/zikr_occasions.dart';
import 'package:shia_companion/utils/zikr_reminder_labels.dart';

/// French writes weekly phrases in lower case mid-list, and the first of a
/// month as an ordinal.
void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));
  final previousLocale = Intl.defaultLocale;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    Intl.defaultLocale = 'fr';
  });
  tearDownAll(() => Intl.defaultLocale = previousLocale);

  test('a joined weekly label has one capital, at its start', () {
    expect(
      reminderDaysLabel({DateTime.tuesday, DateTime.friday}, fr,
          firstDayOfWeek: 1),
      'Tous les mardis et tous les vendredis',
    );
    expect(describeZikrOccasions(['*-*-4', '*-*-5'], fr),
        'Tous les jeudis et tous les vendredis');
    expect(describeZikrOccasions(['N*-*-5'], fr), 'Tous les jeudis soir');
  });

  test('the first of a month is "1er", other days stay numbers', () {
    expect(dayOfMonthLabel(1, fr), '1er');
    expect(dayOfMonthLabel(15, fr), '15');
    expect(dayOfMonthLabel(1, en), '1');
    expect(civilDayMonth(DateTime(2026, 5, 1), fr, true), 'vendredi 1er mai');
    expect(civilDayMonth(DateTime(2026, 5, 2), fr), '2 mai');
    expect(describeZikrOccasions(['N9-1'], fr), contains('1er Ramazan'));
  });

  test('capitalizeFirst leaves capitals and caseless scripts alone', () {
    expect(capitalizeFirst('Thursdays'), 'Thursdays');
    expect(capitalizeFirst('جمعہ'), 'جمعہ');
    expect(capitalizeFirst(''), '');
  });
}
