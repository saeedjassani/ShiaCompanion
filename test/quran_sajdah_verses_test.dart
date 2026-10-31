import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/quran_sajdah_verses.dart';
import 'package:shia_companion/utils/quran_index.dart';

void main() {
  group('quranSajdahVerses', () {
    test('contains exactly 15 verses (4 Wajib, 11 Mustahabb)', () {
      expect(quranSajdahVerses.length, 15);

      final wajibCount =
          quranSajdahVerses.values.where((v) => v.isWajib).length;
      final mustahabbCount =
          quranSajdahVerses.values.where((v) => !v.isWajib).length;

      expect(wajibCount, 4);
      expect(mustahabbCount, 11);
    });

    test('the 4 Wajib verses belong to the 4 Surahs of Azaim', () {
      final wajibVerses = quranSajdahVerses.entries
          .where((e) => e.value.isWajib)
          .map((e) => e.key)
          .toSet();

      expect(
        wajibVerses,
        {
          const VerseKey(32, 15),
          const VerseKey(41, 38),
          const VerseKey(53, 62),
          const VerseKey(96, 19),
        },
      );

      for (final surah in [32, 41, 53, 96]) {
        expect(isAzaimSurah(surah), isTrue);
      }
      expect(isAzaimSurah(1), isFalse);
      expect(isAzaimSurah(2), isFalse);
    });

    test('every key is a valid ayah within its surah', () {
      for (final verse in quranSajdahVerses.keys) {
        final count = ayahCountOf(verse.surah);
        expect(count, isNotNull, reason: 'surah ${verse.surah} does not exist');
        expect(
          verse.ayah,
          allOf(isNotNull, greaterThanOrEqualTo(1), lessThanOrEqualTo(count!)),
          reason: '$verse is out of range for surah ${verse.surah}',
        );
      }
    });

    test('all 5 supported languages provide localized titles, badges and rulings', () {
      final languages = ['en', 'ur', 'fa', 'ar', 'gu'];

      for (final sajdah in quranSajdahVerses.values) {
        for (final lang in languages) {
          expect(sajdah.title(lang).trim(), isNotEmpty,
              reason: 'title in $lang should not be empty');
          expect(sajdah.badgeLabel(lang).trim(), isNotEmpty,
              reason: 'badgeLabel in $lang should not be empty');
          expect(sajdah.wajibPill(lang).trim(), isNotEmpty,
              reason: 'wajibPill in $lang should not be empty');
          expect(sajdah.ruling(lang).trim(), isNotEmpty,
              reason: 'ruling in $lang should not be empty');
          expect(sajdah.duaHeading(lang).trim(), isNotEmpty,
              reason: 'duaHeading in $lang should not be empty');
          if (lang != 'ar') {
            expect(sajdah.duaTranslation(lang).trim(), isNotEmpty,
                reason: 'duaTranslation in $lang should not be empty');
          }
        }

        // Verify that badge labels and titles differ per language
        expect(sajdah.badgeLabel('en'), isNot(equals(sajdah.badgeLabel('ur'))));
        expect(sajdah.badgeLabel('en'), isNot(equals(sajdah.badgeLabel('gu'))));
        expect(sajdah.title('en'), isNot(equals(sajdah.title('ur'))));
        expect(sajdah.ruling('en'), isNot(equals(sajdah.ruling('ur'))));
      }

      for (final lang in languages) {
        expect(azaimSurahBadgeLabel(lang).trim(), isNotEmpty);
      }
    });

    test('Arabic dua translation is empty so only the Arabic dua is shown', () {
      final sajdah = quranSajdahVerses.values.first;
      expect(sajdah.duaTranslation('ar'), isEmpty);
    });

    test('Arabic dua is non-empty and authentic', () {
      expect(QuranSajdahVerse.duaArabic.trim(), isNotEmpty);
      expect(QuranSajdahVerse.duaArabic.startsWith('لاَ إِلَهَ إِلَّا اللَّهُ'), isTrue);
      expect(QuranSajdahVerse.duaArabic.contains('ضَعِيْفٌ'), isTrue);
    });

    test('falls back to language prefix for region-suffixed locales', () {
      final sajdah = quranSajdahVerses.values.first;
      expect(sajdah.badgeLabel('en_US'), equals(sajdah.badgeLabel('en')));
      expect(sajdah.badgeLabel('ur_PK'), equals(sajdah.badgeLabel('ur')));
    });

    test('looks up a sajdah verse correctly', () {
      final wajib = sajdahVerseFor(const VerseKey(32, 15));
      expect(wajib, isNotNull);
      expect(wajib!.isWajib, isTrue);

      final mustahabb = sajdahVerseFor(const VerseKey(7, 206));
      expect(mustahabb, isNotNull);
      expect(mustahabb!.isWajib, isFalse);

      final regularVerse = sajdahVerseFor(const VerseKey(1, 1));
      expect(regularVerse, isNull);
    });
  });
}
