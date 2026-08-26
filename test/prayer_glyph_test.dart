import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/widgets/prayer_glyph.dart';

void main() {
  group('prayerGlyphTypeFor', () {
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

    test('every known prayer/time name maps to a distinct glyph', () {
      final types = {for (final name in names) name: prayerGlyphTypeFor(name)};
      final uniqueTypes = types.values.toSet();
      expect(
        uniqueTypes.length,
        names.length,
        reason: 'Duplicate glyphs found among: $types',
      );
    });

    test('is case-insensitive and matches alternate spellings', () {
      expect(prayerGlyphTypeFor('fajr'), prayerGlyphTypeFor('FAJR'));
      expect(prayerGlyphTypeFor('Dhuhr'), prayerGlyphTypeFor('Zuhr'));
      expect(prayerGlyphTypeFor('Dhohr'), prayerGlyphTypeFor('Zuhr'));
    });

    test('falls back to unknown for unrecognized names', () {
      expect(prayerGlyphTypeFor('Unknown Prayer'), PrayerGlyphType.unknown);
    });
  });
}
