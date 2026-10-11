import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/quran_ali_verses.dart';
import 'package:shia_companion/data/quran_collections_i18n.dart';
import 'package:shia_companion/data/quran_duas.dart';
import 'package:shia_companion/data/quran_mahdi_verses.dart';
import 'package:shia_companion/data/quran_prophet_stories.dart';
import 'package:shia_companion/l10n/app_language.dart';

void main() {
  final latin = RegExp('[A-Za-z]');

  test('every app language but English has the collections translated', () {
    expect(
      quranCollectionsTranslations.keys.toSet(),
      appLanguages.map((l) => l.code).where((c) => c != 'en').toSet(),
    );
  });

  for (final entry in quranCollectionsTranslations.entries) {
    group(entry.key, () {
      final text = entry.value;

      void coversExactly(
          Map<String, String> translated, Iterable<String> keys, String what) {
        expect(translated.keys.toSet(), keys.toSet(),
            reason: '${entry.key} $what should cover exactly the entries');
        for (final MapEntry(:key, :value) in translated.entries) {
          expect(value.trim(), isNotEmpty, reason: '$what $key is empty');
          expect(value.contains(latin), isFalse,
              reason: '$what $key is still in English: $value');
        }
      }

      test('covers every dua', () {
        coversExactly(text.duas, quranDuas.map((d) => '${d.verse}'), 'duas');
      });

      test('covers every verse about Imam Ali (a.s.)', () {
        coversExactly(
            text.imamAli, quranAliVerses.keys.map((v) => '$v'), 'imamAli');
      });

      test('covers every verse about Imam al-Mahdi (a.t.f.s.)', () {
        coversExactly(text.imamMahdi, quranMahdiVerses.keys.map((v) => '$v'),
            'imamMahdi');
      });

      test("covers every prophet's stories and heading", () {
        coversExactly(text.stories,
            quranProphetStories.map((s) => '${s.verse}'), 'stories');
        coversExactly(text.prophets, quranProphetStories.map((s) => s.prophet),
            'prophets');
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
