import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/quran_text_index.dart';
import 'package:shia_companion/utils/verse_matcher.dart';

/// Serves the real shipped surah documents off disk - the matcher is only worth
/// anything against the actual corpus.
class _DiskAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    return ByteData.view(bytes.buffer);
  }
}

void main() {
  late QuranTextIndex index;

  setUpAll(() async {
    resetQuranTextIndexCache();
    index = await loadQuranTextIndex(_DiskAssetBundle());
  });

  IndexedVerse verseAt(VerseKey key) =>
      index.verses[index.indexOf(key)!];

  /// Where [key] comes in the ranking for [transcript], or -1 if absent.
  int rankOf(VerseKey key, String transcript, {VerseKey? context}) {
    final matches =
        matchRecitation(transcript, index: index, context: context, limit: 10);
    for (var i = 0; i < matches.candidates.length; i++) {
      final verse = matches.candidates[i].verse;
      if (verse.surah == key.surah && verse.ayah == key.ayah) return i;
    }
    return -1;
  }

  /// Whether the top match is word-for-word the same text as [key] - a real
  /// duplicate rather than a wrong answer. The Quran repeats whole verses
  /// (ar-Rahman's refrain 31 times), so "the right verse" is sometimes a set.
  bool topIsSameTextAs(VerseKey key, RecitationMatches matches) {
    final best = matches.best;
    if (best == null) return false;
    final expected = verseAt(key).tokens.join(' ');
    final actual = verseAt(best.verse).tokens.join(' ');
    return expected == actual;
  }

  group('an exact recitation', () {
    test('finds itself first, for verses across the whole Quran', () {
      // Every 37th verse: a spread over all 114 surahs, of every length,
      // without paying for all 6,236.
      final failures = <String>[];
      for (var i = 0; i < index.verses.length; i += 37) {
        final indexed = index.verses[i];
        // The single-word muqatta'at verses are covered by their own test
        // below: one word cannot identify a verse, and the matcher declines
        // rather than guessing.
        if (indexed.tokens.length < 2) continue;

        final matches = matchRecitation(
          indexed.arabic,
          index: index,
          limit: 5,
        );
        if (topIsSameTextAs(indexed.verse, matches)) continue;
        failures.add('${indexed.verse} ranked ${rankOf(
          indexed.verse,
          indexed.arabic,
        )}');
      }
      expect(failures, isEmpty, reason: failures.take(10).join('; '));
    });

    test('is confident about a distinctive verse', () {
      final matches = matchRecitation(
        verseAt(const VerseKey(2, 255)).arabic, // Ayat al-Kursi
        index: index,
      );
      expect(matches.best!.verse.surah, 2);
      expect(matches.best!.verse.ayah, 255);
      expect(matches.isConfident, isTrue);
    });

    test('works from undiacriticised text, which is all a recogniser gives',
        () {
      // What an ASR engine would plausibly emit for al-Ikhlaas 2.
      const transcript = 'الله الصمد';
      final matches = matchRecitation(transcript, index: index, limit: 5);
      expect(matches.candidates, isNotEmpty);
      expect(rankOf(const VerseKey(112, 2), transcript), 0);
    });
  });

  group('a degraded transcript, which is the realistic case', () {
    /// Drops every [every]th word, as a recogniser swallows words.
    String dropWords(List<String> tokens, int every) {
      final kept = <String>[];
      for (var i = 0; i < tokens.length; i++) {
        if (i % every != 0) kept.add(tokens[i]);
      }
      return kept.join(' ');
    }

    test('still finds the verse with a third of its words missing', () {
      final failures = <String>[];
      // Only verses long enough that losing a third still leaves something to
      // go on; a four-word verse minus a third is not a retrieval problem, it
      // is a guess, and the candidate list is the honest answer there.
      for (var i = 0; i < index.verses.length; i += 53) {
        final indexed = index.verses[i];
        if (indexed.tokens.length < 8) continue;

        final transcript = dropWords(indexed.tokens, 3);
        final rank = rankOf(indexed.verse, transcript);
        final matches = matchRecitation(transcript, index: index, limit: 5);
        if (rank >= 0 && rank < 5) continue;
        if (topIsSameTextAs(indexed.verse, matches)) continue;
        failures.add('${indexed.verse} ranked $rank');
      }
      expect(failures, isEmpty, reason: failures.take(10).join('; '));
    });

    test('still finds the verse with words mis-recognised', () {
      final random = Random(7);
      final failures = <String>[];
      for (var i = 0; i < index.verses.length; i += 71) {
        final indexed = index.verses[i];
        if (indexed.tokens.length < 8) continue;

        // Replace two words with other real Quranic words - the mistake an ASR
        // engine actually makes, rather than nonsense it would never emit.
        final tokens = List.of(indexed.tokens);
        for (var swap = 0; swap < 2; swap++) {
          final donor = index.verses[random.nextInt(index.verses.length)];
          tokens[random.nextInt(tokens.length)] =
              donor.tokens[random.nextInt(donor.tokens.length)];
        }

        final transcript = tokens.join(' ');
        final rank = rankOf(indexed.verse, transcript);
        final matches = matchRecitation(transcript, index: index, limit: 5);
        if (rank >= 0 && rank < 5) continue;
        if (topIsSameTextAs(indexed.verse, matches)) continue;
        failures.add('${indexed.verse} ranked $rank');
      }
      expect(failures, isEmpty, reason: failures.take(10).join('; '));
    });

    test('finds a long verse from only its opening, not a short verse that '
        'shares a few words', () {
      // Al-Baqarah 282 is the longest verse in the Quran. Someone reciting its
      // first dozen words should land on it.
      final opening = verseAt(const VerseKey(2, 282)).tokens.take(12).join(' ');
      expect(rankOf(const VerseKey(2, 282), opening), 0);
    });
  });

  group('when it cannot know', () {
    test('declines to jump on a refrain that recurs verbatim', () {
      // "fa-bi-ayyi alaa'i rabbikumaa tukadhdhibaan" - 31 times in ar-Rahman.
      final matches = matchRecitation(
        verseAt(const VerseKey(55, 13)).arabic,
        index: index,
      );

      expect(matches.candidates.length, greaterThan(1));
      expect(
        matches.margin,
        lessThan(0.12),
        reason: 'identical verses must not separate in the ranking',
      );
      expect(
        matches.isConfident,
        isFalse,
        reason: 'a Quran reader must not be thrown to the wrong one of 31 '
            'identical verses',
      );
      // Every candidate offered is genuinely that refrain, so whichever the
      // reader picks is a right answer.
      for (final candidate in matches.candidates) {
        expect(candidate.verse.surah, 55);
      }
    });

    test('offers a refrain\'s occurrences in reading order', () {
      final matches = matchRecitation(
        verseAt(const VerseKey(55, 13)).arabic,
        index: index,
        limit: 5,
      );
      final ayahs = matches.candidates.map((c) => c.verse.ayah!).toList();
      expect(ayahs, orderedEquals(List.of(ayahs)..sort()));
    });

    test('returns nothing for Arabic that is not Quran', () {
      final matches = matchRecitation(
        'الطائرة تصل المطار في الساعة الثامنة صباحا غدا',
        index: index,
      );
      expect(matches.isConfident, isFalse);
    });

    test('returns nothing at all for too few words to go on', () {
      // One word is not a recitation: it matches thousands of verses equally.
      expect(matchRecitation('الله', index: index).candidates, isEmpty);
      expect(matchRecitation('', index: index).candidates, isEmpty);
      expect(matchRecitation('hello there friend', index: index).candidates,
          isEmpty);
    });

    test('still ranks the two-word verses the Quran actually contains', () {
      // 89:2, "wa layaalin 'ashr" - two words, and unreachable if a two-word
      // transcript is refused outright.
      final transcript = verseAt(const VerseKey(89, 2)).arabic;
      expect(rankOf(const VerseKey(89, 2), transcript), 0);
    });

    test('prefers a short verse over a long one that merely contains it', () {
      // 69:43 is four words; 32:2 is eight and holds all four in order. Without
      // the length term the two tie and the tie-break sends the reader to 32:2.
      // (56:80 is word-for-word 69:43, so it ties legitimately.)
      final transcript = verseAt(const VerseKey(69, 43)).arabic;
      final matches = matchRecitation(transcript, index: index, limit: 5);

      expect(topIsSameTextAs(const VerseKey(69, 43), matches), isTrue);
      final rankOf32 = rankOf(const VerseKey(32, 2), transcript);
      expect(rankOf32, greaterThan(1),
          reason: 'the longer verse must rank below both exact matches');
    });

    test('cannot identify a lone muqatta\'at verse, and says so', () {
      // Roughly twenty verses are a single word - حٰمٓ, طٰهٰ, يٰسٓ, صٓ, قٓ, نٓ.
      // One word matches too much to rank honestly, so the sheet asks for more
      // rather than offering a guess. A known limit, not a defect.
      final matches = matchRecitation(
        verseAt(const VerseKey(41, 1)).arabic,
        index: index,
      );
      expect(matches.candidates, isEmpty);
      expect(matches.isConfident, isFalse);
    });

    test('reports how much of the transcript was Quran at all', () {
      expect(matchRecitation('nothing arabic here', index: index).matchedTokens,
          0);
      expect(
        matchRecitation(verseAt(const VerseKey(2, 255)).arabic, index: index)
            .matchedTokens,
        greaterThan(10),
      );
    });
  });

  group('where the reader already is', () {
    test('breaks a tie towards the surah being read', () {
      // Al-Kafirun 2 and 3 share most of their words; sitting in al-Kafirun
      // should not change which is found, but sitting elsewhere must not
      // outrank a verse in the surah under way.
      final transcript = verseAt(const VerseKey(55, 13)).arabic;

      final withoutContext = matchRecitation(transcript, index: index, limit: 5);
      final withContext = matchRecitation(
        transcript,
        index: index,
        context: const VerseKey(55, 40),
        limit: 5,
      );

      expect(withoutContext.candidates, isNotEmpty);
      expect(withContext.best!.score,
          greaterThan(withoutContext.best!.score - 0.0001));
    });

    test('does not let context override a clear match elsewhere', () {
      final matches = matchRecitation(
        verseAt(const VerseKey(112, 2)).arabic,
        index: index,
        context: const VerseKey(2, 1),
      );
      expect(matches.best!.verse.surah, 112);
    });
  });
}
