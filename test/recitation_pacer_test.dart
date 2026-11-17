import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_reading_stats.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/recitation_pacer.dart';

/// Verses on screen count as recited only as fast as they could be read.
/// The bug this guards: a short surah that fits on one screen of Arabic-only
/// paragraph view counted as Completed - Khatm, streak and stats - after a
/// nudge, without a word of it read.
void main() {
  final start = DateTime(2026, 11, 17, 9);
  DateTime at(int seconds) => start.add(Duration(seconds: seconds));
  List<VerseKey> surah(int number, int ayahs) => [
    for (var a = 1; a <= ayahs; a++) VerseKey(number, a),
  ];

  /// Ten words a verse, four words a second.
  RecitationPacer pacer({Map<VerseKey, int> words = const {}}) =>
      RecitationPacer(
        start: start,
        wordsPerSecond: 4,
        wordsOf: (verse) => words[verse] ?? 10,
      );

  test('a nudge right after opening counts only what could be read', () {
    final p = pacer()..see(surah(67, 30));
    expect(p.release(at(0)), isEmpty);
    // 8 words by now: not yet one verse.
    expect(p.release(at(2)), isEmpty);
    // 20 words: two verses.
    expect(p.release(at(5)), surah(67, 2));
  });

  test('a screenful counts verse by verse, at reading pace', () {
    final p = pacer()..see(surah(67, 30));
    expect(p.release(at(30)), hasLength(12));
    expect(p.release(at(60)), hasLength(12));
    expect(p.release(at(75)), hasLength(6));
    expect(p.hasPending, isFalse);
  });

  test('time left idle can\'t be cashed in by a fling later', () {
    final p = pacer();
    // Ten minutes open on one screen before scrolling through the surah: a
    // minute of reading is kept, not ten.
    p.see(surah(2, 286));
    expect(p.release(at(600)), hasLength(24));
  });

  test('a verse seen twice is queued once, in the order first seen', () {
    final p = pacer()
      ..see(surah(1, 3))
      ..see([const VerseKey(1, 2), const VerseKey(1, 4)]);
    expect(p.release(at(100)), surah(1, 4));
    expect(p.firstSeenAyah(1), 1);
    expect(p.firstSeenAyah(2), isNull);
  });

  test('says when the next verse can count', () {
    final p = pacer()..see(surah(108, 3));
    expect(p.untilNext(at(0)), const Duration(milliseconds: 2500));
    expect(p.release(at(10)), hasLength(3));
    expect(p.untilNext(at(10)), isNull);

    // 40 words by now, 30 spent: the next 10-word verse is already paid
    // for, and the one after it is 2.5 s of reading away.
    p.see(surah(109, 2));
    expect(p.untilNext(at(10)), Duration.zero);
    expect(p.release(at(10)), [const VerseKey(109, 1)]);
    expect(p.untilNext(at(10)), const Duration(milliseconds: 2500));
  });

  test('a verse longer than a minute of reading still counts in the end', () {
    const longest = VerseKey(2, 282);
    final p = pacer(words: {longest: 400})..see([longest]);
    expect(p.release(at(60)), isEmpty);
    expect(p.release(at(100)), [longest]);
  });

  test('the pace leaves the fastest reciters far behind', () {
    // Hadr runs at some 250 words a minute at most; a fling at thousands of
    // words a second.
    expect(quranFastestWordsPerSecond * 60, greaterThanOrEqualTo(4 * 250));
    expect(quranFastestWordsPerSecond, lessThan(100));
  });

  test('a reader at any real pace has every verse counted as they go', () {
    // 250 words a minute - fast hadr - over al-Mulk's 30 verses, a screen
    // of six verses at a time, then the page closed on the last screen.
    final p = RecitationPacer(
      start: start,
      wordsPerSecond: quranFastestWordsPerSecond,
      wordsOf: (_) => 11,
    );
    final counted = <VerseKey>[];
    const secondsPerScreen = 6 * 11 * 60 ~/ 250;
    for (var screen = 0; screen < 5; screen++) {
      p.see([
        for (var a = screen * 6 + 1; a <= screen * 6 + 6; a++)
          VerseKey(67, a),
      ]);
      counted.addAll(p.release(at(screen * secondsPerScreen)));
    }
    counted.addAll(p.release(at(5 * secondsPerScreen)));
    expect(counted, surah(67, 30));
  });

  test('a slow first screen counts in full at the first scroll', () {
    // Five minutes over 80 verses of ten words before scrolling.
    final p = RecitationPacer(
      start: start,
      wordsPerSecond: quranFastestWordsPerSecond,
      wordsOf: (_) => 10,
    )..see(surah(2, 80));
    expect(p.release(at(300)), hasLength(80));
  });

  test('counts each verse\'s Arabic words, not its English', () {
    const content =
        'بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ\n'
        'قُلْ هُوَ اللّٰهُ اَحَدٌ‏(1)\n'
        'Qul huwa Allahu ahad\n'
        'Say, He is Allah, the One\n'
        'اَللّٰهُ الصَّمَدُ‏(2)\n'
        'Allahu as-samad\n'
        'Allah, the Eternal Refuge';
    final words = quranVerseWordCounts(content, surah: 112);
    expect(words[const VerseKey(112, 1)], 4);
    expect(words[const VerseKey(112, 2)], 2);
  });
}
