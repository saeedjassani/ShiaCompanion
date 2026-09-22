import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/quran_text_index.dart';

/// Serves the real shipped surah documents off disk, so these tests run against
/// the corpus the app actually reads rather than a fixture of it. Same bundle
/// `quran_portion_test.dart` uses.
class _DiskAssetBundle extends CachingAssetBundle {
  var loads = 0;

  @override
  Future<ByteData> load(String key) async {
    loads++;
    final bytes = File(key).readAsBytesSync();
    return ByteData.view(bytes.buffer);
  }
}

void main() {
  group('normalizeQuranArabic', () {
    test('strips harakat down to the consonantal skeleton', () {
      // Al-Ikhlaas 1, exactly as the corpus carries it.
      expect(
        normalizeQuranArabic('قُلْ هُوَ اللّٰهُ اَحَدٌ ۚ‏(1)'),
        'قل هو الله احد',
      );
    });

    test('strips the superscript alef the Indo-Pak corpus is full of', () {
      expect(normalizeQuranArabic('الرَّحْمٰنِ'), 'الرحمن');
    });

    test('strips the Qalam private-use marks', () {
      expect(normalizeQuranArabic('بِه'), 'به');
      expect(normalizeQuranArabic('بِه'), 'به');
    });

    test('folds the alef and ya forms a recogniser will not distinguish', () {
      expect(normalizeQuranArabic('أَإِآٱا'), 'ااااا');
      expect(normalizeQuranArabic('عَلٰى'), 'علي');
      expect(normalizeQuranArabic('رَحْمَة'), 'رحمه');
    });

    test('drops the trailing ayah marker but keeps numbering inside a line', () {
      expect(normalizeQuranArabic('قُلْ (12)'), 'قل');
    });

    test('treats Latin text, digits and punctuation as separators', () {
      expect(normalizeQuranArabic('قل ABC 123 - هو'), 'قل هو');
    });

    test('collapses runs of separators rather than emitting empty words', () {
      expect(normalizeQuranArabic('  قل   ۚ‏  هو  '), 'قل هو');
    });

    test('is empty for a line with no Arabic at all', () {
      expect(normalizeQuranArabic('BISMIL LAAHIR RAHMAANIR RAHEEM'), '');
    });
  });

  group('quranTokens', () {
    test('matches the corpus superscript alef to a recogniser\'s full alef',
        () {
      // ar-Rahman's refrain: the corpus writes تُكَذِّبٰنِ, an engine writes
      // تكذبان. Nothing works if these two are not the same key.
      expect(quranTokens('تُكَذِّبٰنِ'), quranTokens('تكذبان'));
    });

    test('matches al-Rahman however the alef is written', () {
      // The corpus writes الرَّحْمٰنِ; modern Arabic writes الرحمن, with no
      // alef at all.
      expect(quranTokens('الرَّحْمٰنِ'), quranTokens('الرحمن'));
    });

    test('matches Allah however the corpus spells it', () {
      expect(quranTokens('اللّٰهُ'), quranTokens('الله'));
    });

    test('keeps the definite article, which a reciter pronounces', () {
      expect(quranTokens('الرحمن'), isNot(quranTokens('رحمن')));
    });

    test('never emits an empty key for a word that was only an alef', () {
      expect(quranTokens('قل ا هو'), ['قل', 'هو']);
    });

    test('is empty for text carrying no Arabic', () {
      expect(quranTokens('nothing here'), isEmpty);
    });
  });

  group('indexing one document', () {
    // The single parsing path, shared by the isolate build used on mobile and
    // the yielding one used on web, so the two cannot come to differ.
    test('reads the ayahs out of a document and skips the Bismillah', () {
      final verses = indexOneDocumentForTest(
        112,
        '{"title":"112","code":"012","data":'
            '"بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ\\n'
            'BISMILLAH\\nIn the Name of Allah\\n'
            'قُلْ هُوَ اللّٰهُ اَحَدٌ (1)\\nQUL\\nSay: He is One\\n'
            'اَللّٰهُ الصَّمَدُ (2)\\nALLAAH\\nGod, the Needless"}',
      );

      expect(verses.map((v) => v.verse.ayah), [1, 2]);
      expect(verses.first.tokens, quranTokens('قل هو الله احد'));
      expect(verses.first.translation, 'Say: He is One');
      expect(verses.last.verse.surah, 112);
    });

    test('survives a document that is not an object', () {
      expect(indexOneDocumentForTest(112, '"just a string"'), isEmpty);
    });

    test('survives a document that is not JSON at all', () {
      // One unreadable document must cost that surah, not the whole index.
      expect(indexOneDocumentForTest(112, '{not json'), isEmpty);
    });

    test('yields nothing for a document with no Arabic', () {
      expect(
        indexOneDocumentForTest(112, '{"code":"012","data":"no arabic here"}'),
        isEmpty,
      );
    });
  });

  group('loading', () {
    test('reads every surah document exactly once', () async {
      final bundle = _DiskAssetBundle();
      resetQuranTextIndexCache();
      final index = await loadQuranTextIndex(bundle);

      // Batching the reads must not drop or duplicate any of them. Reading them
      // in series is what made the wait before listening on web, where each is
      // an HTTP request rather than a file.
      expect(bundle.loads, surahCount);
      expect(index.verses.length, 6236);
    });

    test('builds once however many callers ask at the same time', () async {
      final bundle = _DiskAssetBundle();
      resetQuranTextIndexCache();

      final results = await Future.wait([
        loadQuranTextIndex(bundle),
        loadQuranTextIndex(bundle),
        loadQuranTextIndex(bundle),
      ]);

      expect(bundle.loads, surahCount);
      expect(results[0], same(results[1]));
      expect(results[1], same(results[2]));
    });

    test('a prewarm satisfies the load that follows it', () async {
      final bundle = _DiskAssetBundle();
      resetQuranTextIndexCache();

      prewarmQuranTextIndex(bundle);
      final index = await loadQuranTextIndex(bundle);

      // The point of prewarming: the tap that follows pays nothing.
      expect(bundle.loads, surahCount);
      expect(index.verses.length, 6236);
    });

    test('prewarming twice does not read the corpus twice', () async {
      final bundle = _DiskAssetBundle();
      resetQuranTextIndexCache();

      prewarmQuranTextIndex(bundle);
      prewarmQuranTextIndex(bundle);
      await loadQuranTextIndex(bundle);

      expect(bundle.loads, surahCount);
    });
  });

  group('the index of the shipped corpus', () {
    late QuranTextIndex index;

    setUpAll(() async {
      resetQuranTextIndexCache();
      index = await loadQuranTextIndex(_DiskAssetBundle());
    });

    test('carries every ayah of every surah, and no more', () {
      final byAyah = <int, Set<int>>{};
      for (final indexed in index.verses) {
        (byAyah[indexed.verse.surah] ??= <int>{}).add(indexed.verse.ayah!);
      }

      for (var surah = 1; surah <= surahCount; surah++) {
        final expected = surahAyahCounts[surah - 1];
        final found = byAyah[surah] ?? const <int>{};
        expect(
          found.length,
          expected,
          reason: 'surah $surah has ${found.length} ayahs, expected $expected',
        );
        expect(
          found,
          containsAll(List.generate(expected, (i) => i + 1)),
          reason: 'surah $surah is missing ayah numbers',
        );
      }
    });

    test('totals the 6,236 ayahs of the Quran', () {
      expect(index.verses.length, 6236);
      expect(index.verses.length, surahAyahCounts.reduce((a, b) => a + b));
    });

    test('every verse has text to match on and text to show', () {
      for (final indexed in index.verses) {
        expect(indexed.tokens, isNotEmpty,
            reason: '${indexed.verse} has no tokens');
        expect(indexed.arabic.trim(), isNotEmpty,
            reason: '${indexed.verse} has no Arabic to show');
      }
    });

    test('the Bismillah heading a surah is not indexed as one of its ayahs',
        () {
      // Al-Ikhlaas opens with an unnumbered Bismillah, so its first indexed
      // verse must be "qul huwa Allahu ahad", not the Bismillah.
      final first = index.verses.firstWhere((v) => v.verse.surah == 112);
      expect(first.verse.ayah, 1);
      expect(first.tokens.first, 'قل');
    });

    test('al-Fatehah numbers its Bismillah as ayah 1, as the corpus does', () {
      final first = index.verses.firstWhere((v) => v.verse.surah == 1);
      expect(first.verse.ayah, 1);
      expect(first.tokens, quranTokens('بسم الله الرحمن الرحيم'));
    });

    test('most verses carry a translation to show beside the Arabic', () {
      final translated =
          index.verses.where((v) => v.translation.trim().isNotEmpty).length;
      expect(translated / index.verses.length, greaterThan(0.95));
    });

    test('rates a common word as near worthless and a rare one as decisive',
        () {
      final common = quranTokens('الله').single;
      final rare = quranTokens('تكذبان').single;
      expect(index.idf(common), lessThan(index.idf(rare)));
      expect(index.idf(quranTokens('من').single), lessThan(index.idf(rare)));
    });

    test('finds the ar-Rahman refrain under the spelling an engine emits', () {
      // The guard on the orthography fix: a recogniser's تكذبان must reach the
      // corpus's تُكَذِّبٰنِ, in all 31 places it appears.
      final verses = index.versesWith(quranTokens('تكذبان').single);
      expect(verses, isNotNull);
      expect(verses!.length, greaterThanOrEqualTo(31));
    });

    test('scores a word that is nowhere in the Quran at zero', () {
      final absent = quranTokens('كمبيوتر').single;
      expect(index.idf(absent), 0);
      expect(index.versesWith(absent), isNull);
    });

    test('finds a verse by its position', () {
      final at = index.indexOf(const VerseKey(112, 1));
      expect(at, isNotNull);
      expect(index.verses[at!].verse.surah, 112);
    });
  });
}
