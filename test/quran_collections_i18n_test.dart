import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/quran_ali_verses.dart';
import 'package:shia_companion/data/quran_collections_i18n.dart';
import 'package:shia_companion/data/quran_duas.dart';
import 'package:shia_companion/data/quran_mahdi_verses.dart';
import 'package:shia_companion/data/quran_prophet_stories.dart';
import 'package:shia_companion/l10n/app_language.dart';

void main() {
  final latin = RegExp('[A-Za-z]');
  // Languages written in Latin letters: still English means the English
  // text itself, not any Latin letter.
  const latinScript = {'fr'};

  test('every app language but English has the collections translated', () {
    expect(
      quranCollectionsTranslations.keys.toSet(),
      appLanguages.map((l) => l.code).where((c) => c != 'en').toSet(),
    );
  });

  for (final entry in quranCollectionsTranslations.entries) {
    group(entry.key, () {
      final text = entry.value;

      void coversExactly(Map<String, String> translated,
          Map<String, String> english, String what,
          {bool sameAsEnglishOk = false}) {
        expect(translated.keys.toSet(), english.keys.toSet(),
            reason: '${entry.key} $what should cover exactly the entries');
        for (final MapEntry(:key, :value) in translated.entries) {
          expect(value.trim(), isNotEmpty, reason: '$what $key is empty');
          final stillEnglish = latinScript.contains(entry.key)
              ? value == english[key] && !sameAsEnglishOk
              : value.contains(latin);
          expect(stillEnglish, isFalse,
              reason: '$what $key is still in English: $value');
        }
      }

      test('covers every dua', () {
        coversExactly(
            text.duas, {for (final d in quranDuas) '${d.verse}': d.note}, 'duas');
      });

      test('covers every verse about Imam Ali (a.s.)', () {
        coversExactly(text.imamAli,
            {for (final e in quranAliVerses.entries) '${e.key}': e.value},
            'imamAli');
      });

      test('covers every verse about Imam al-Mahdi (a.t.f.s.)', () {
        coversExactly(text.imamMahdi,
            {for (final e in quranMahdiVerses.entries) '${e.key}': e.value},
            'imamMahdi');
      });

      test("covers every prophet's stories and heading", () {
        coversExactly(text.stories,
            {for (final s in quranProphetStories) '${s.verse}': s.title},
            'stories');
        coversExactly(text.prophets,
            {for (final s in quranProphetStories) s.prophet: s.prophet},
            'prophets',
            // A name can be spelt alike: Adam (a.s.).
            sameAsEnglishOk: true);
      });
    });
  }

  test('every dua has its opening in Arabic', () {
    final arabic = RegExp('^[؀-ۿݐ-ݿ ]+\$');
    for (final dua in quranDuas) {
      expect(arabic.hasMatch(dua.arabic), isTrue,
          reason: '${dua.opening} has no Arabic opening: ${dua.arabic}');
    }
  });
}
