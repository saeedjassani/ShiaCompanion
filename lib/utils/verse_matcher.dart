import 'dart:math' as math;

import 'quran_index.dart';
import 'quran_text_index.dart';

/// Works out which verse a recitation transcript is.
///
/// Pure and synchronous - no microphone, no plugin, no assets. That is
/// deliberate: this is the part of "listen and follow" that decides whether the
/// feature is any good, and keeping it a plain function means it can be tested
/// against degraded transcripts rather than only by reciting at a phone.
///
/// The task is retrieval, not transcription. A speech recogniser trained on
/// conversational Arabic will get a good share of the words of a recitation
/// wrong, but it only has to leave enough behind to pick one verse out of 6,236,
/// and Quranic phrasing is distinctive enough that it usually does. Where it
/// does not - short verses, and refrains that recur verbatim (55:13 appears 31
/// times) - the scores come back close together, and [RecitationMatches.isConfident]
/// says so rather than guessing.

/// One candidate verse.
class VerseMatch {
  const VerseMatch({
    required this.verse,
    required this.score,
    required this.arabic,
    required this.translation,
  });

  final VerseKey verse;

  /// How well the transcript fits this verse, 0..1.
  final double score;

  /// The verse as authored, for showing in a candidate row.
  final String arabic;
  final String translation;
}

/// The ranked candidates for one transcript.
class RecitationMatches {
  const RecitationMatches({
    required this.candidates,
    required this.matchedTokens,
  });

  const RecitationMatches.none()
      : candidates = const [],
        matchedTokens = 0;

  /// Best first.
  final List<VerseMatch> candidates;

  /// How many of the transcript's distinct words were found in the corpus at
  /// all - the measure of whether the recogniser produced Quran or mush.
  final int matchedTokens;

  VerseMatch? get best => candidates.isEmpty ? null : candidates.first;

  /// How far clear of the runner-up the winner is.
  ///
  /// The decisive number for a Quran reader. A verse can score highly and still
  /// be the wrong one: every "fa-bi-ayyi ālāʾi rabbikumā tukadhdhibān" in
  /// ar-Rahman scores identically, and so does every near-repeat in ash-Shu'ara.
  /// A wide margin is what distinguishes "this is the verse" from "it is one of
  /// these".
  double get margin {
    if (candidates.length < 2) return candidates.isEmpty ? 0 : candidates.first.score;
    return candidates[0].score - candidates[1].score;
  }

  /// Whether to jump straight there instead of asking.
  ///
  /// Both halves matter: a strong score alone would jump confidently into the
  /// wrong ar-Rahman refrain, and a wide margin alone would jump on the
  /// strength of one lucky rare word.
  bool get isConfident =>
      best != null && best!.score >= _confidentScore && margin >= _confidentMargin;
}

const double _confidentScore = 0.55;
const double _confidentMargin = 0.12;

/// The fewest words worth ranking on.
///
/// Two, not more: the Quran has verses of two words - `وَكِتَابٍ مَسْطُورٍ`,
/// `وَلَيَالٍ عَشْرٍ` - and refusing to rank them at all would make those verses
/// permanently unreachable. Whether two words are *enough to jump on* is a
/// different question, and [RecitationMatches.isConfident] answers it: a
/// distinctive pair jumps, an ordinary one offers a list.
///
/// One word is not a recitation, and matches thousands of verses equally.
const int _minimumTokens = 2;

/// How many first-pass candidates get the (more expensive) ordered rescore.
const int _rescoreDepth = 60;

/// Ranks the verses [transcript] might be.
///
/// [context] is where the reader already is, if anywhere; verses in that surah
/// get a small nudge, on the grounds that someone following along in al-Baqarah
/// is probably still in al-Baqarah. It is deliberately small enough that a clear
/// match elsewhere still wins.
RecitationMatches matchRecitation(
  String transcript, {
  required QuranTextIndex index,
  VerseKey? context,
  int limit = 5,
}) {
  final tokens = quranTokens(transcript);
  if (tokens.length < _minimumTokens || index.isEmpty) {
    return const RecitationMatches.none();
  }

  final distinct = tokens.toSet();

  // First pass: how much of the transcript's weight each verse accounts for.
  var totalWeight = 0.0;
  var matchedTokens = 0;
  final coverage = <int, double>{};

  for (final token in distinct) {
    final verses = index.versesWith(token);
    final weight = index.idf(token);
    // An unknown word still counts against coverage - it is transcript the
    // winner has to explain - but a word in nearly every verse barely counts
    // for anyone.
    totalWeight += weight > 0 ? weight : _unknownTokenWeight;
    if (verses == null) continue;

    matchedTokens++;
    for (final verse in verses) {
      coverage[verse] = (coverage[verse] ?? 0) + weight;
    }
  }

  if (matchedTokens < _minimumTokens || totalWeight <= 0) {
    return RecitationMatches(candidates: const [], matchedTokens: matchedTokens);
  }

  final ranked = coverage.keys.toList()
    ..sort((a, b) => coverage[b]!.compareTo(coverage[a]!));
  final shortlist = ranked.take(_rescoreDepth);

  // Second pass: reward the words arriving in the right order, so a verse built
  // of common words cannot win on overlap alone.
  final scored = <VerseMatch>[];
  for (final verseIndex in shortlist) {
    final indexed = index.verses[verseIndex];
    final ordered = _orderedSimilarity(tokens, indexed.tokens);
    var score = _coverageWeight * (coverage[verseIndex]! / totalWeight) +
        _orderWeight * ordered +
        _lengthWeight * _lengthAgreement(tokens.length, indexed.tokens.length);

    if (context != null && indexed.verse.surah == context.surah) {
      score += _sameSurahBonus;
    }

    scored.add(VerseMatch(
      verse: indexed.verse,
      score: score.clamp(0.0, 1.0),
      arabic: indexed.arabic,
      translation: indexed.translation,
    ));
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    // Ties resolve in reading order, so a repeated refrain offers its
    // occurrences in the order someone would meet them.
    final bySurah = a.verse.surah.compareTo(b.verse.surah);
    if (bySurah != 0) return bySurah;
    return (a.verse.ayah ?? 0).compareTo(b.verse.ayah ?? 0);
  });

  return RecitationMatches(
    candidates: scored.take(limit).toList(growable: false),
    matchedTokens: matchedTokens,
  );
}

const double _coverageWeight = 0.50;
const double _orderWeight = 0.40;
const double _lengthWeight = 0.10;
const double _sameSurahBonus = 0.03;

/// How close the transcript is in length to the verse, 0..1.
///
/// Carries a small weight, but an essential one. Without it a short verse loses
/// to any longer verse that happens to contain it: recite the four words of
/// 69:43 and both it and every longer verse holding those four words in order
/// score identically, so the tie-break sends the reader to the wrong one. This
/// says that a four-word transcript is better explained by a four-word verse.
///
/// Kept small so that reciting the opening of a long verse still finds it -
/// there the coverage term carries a much larger advantage than this gives away.
double _lengthAgreement(int transcript, int verse) {
  if (transcript == 0 || verse == 0) return 0;
  return transcript < verse ? transcript / verse : verse / transcript;
}

/// What an unrecognised word costs. Low, because a recogniser inventing a word
/// is expected, but not zero, or a transcript of pure noise with one real word
/// in it would score perfectly.
const double _unknownTokenWeight = 0.5;

/// How much of [transcript] appears in [verse], in order, 0..1.
///
/// Longest common subsequence over words, normalised by the shorter of the two
/// so that reciting part of a long verse still matches it fully - someone
/// reciting the opening of al-Baqarah 282 should land on 282, not on whichever
/// short verse happens to share a few words.
double _orderedSimilarity(List<String> transcript, List<String> verse) {
  if (transcript.isEmpty || verse.isEmpty) return 0;

  // Rolling two-row LCS: the verses are short enough that this is cheap, and
  // only the shortlist reaches here.
  var previous = List<int>.filled(verse.length + 1, 0);
  var current = List<int>.filled(verse.length + 1, 0);

  for (var i = 1; i <= transcript.length; i++) {
    for (var j = 1; j <= verse.length; j++) {
      current[j] = transcript[i - 1] == verse[j - 1]
          ? previous[j - 1] + 1
          : math.max(previous[j], current[j - 1]);
    }
    final swap = previous;
    previous = current;
    current = swap;
    current.fillRange(0, current.length, 0);
  }

  final lcs = previous[verse.length];
  return lcs / math.min(transcript.length, verse.length);
}
