import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/prayer_time_icons.dart';

void main() {
  group('prayerIconFor', () {
    const names = [
      'Fajr',
      'Sunrise',
      'Zuhr',
      'Asr',
      'Sunset',
      'Maghrib',
      'Isha',
      'Midnight',
    ];

    test('every known prayer/time name maps to a distinct icon', () {
      final icons = {for (final name in names) name: prayerIconFor(name)};
      final uniqueIcons = icons.values.toSet();
      expect(
        uniqueIcons.length,
        names.length,
        reason: 'Duplicate icons found among: $icons',
      );
    });

    test('is case-insensitive and matches alternate spellings', () {
      expect(prayerIconFor('fajr'), prayerIconFor('FAJR'));
      expect(prayerIconFor('Dhuhr'), prayerIconFor('Zuhr'));
      expect(prayerIconFor('Dhohr'), prayerIconFor('Zuhr'));
    });

    test('falls back to a generic icon for unknown names', () {
      expect(prayerIconFor('Unknown Prayer'), Icons.mosque);
    });
  });
}
