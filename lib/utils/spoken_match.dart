/// Matching what someone said - to Google Assistant, say - against the names
/// of things in the app: "kumail" against Dua Kumayl's old spelling, "prayer
/// times" against Calendar & Prayer Times, "yasin" against Surah Ya-Sin.
///
/// The Android end of what `SmartActionsCatalog.matches` does in Swift for
/// Siri, with a ranking on top: Assistant hands over one phrase and the app
/// has to pick one thing for it, not list every match.
library;

/// How well [query] names something called any of [candidates]:
///
/// - 3: the same words ("dua kumayl" for "Dua Kumayl");
/// - 2: every word said starts a word of the name ("kumayl", "thursday");
/// - 1: the words run together are inside the name's ("yasin" in
///   "Surah Ya-Sin");
/// - 0: no match.
///
/// Case, accents and apostrophes don't count, and neither do the filler
/// words in [ignoredWords] ("the", "my") unless they are all that was said.
SpokenMatchScore spokenMatchScore(
  String query,
  Iterable<String> candidates, {
  Set<String> ignoredWords = const {},
}) {
  final wanted = _queryWords(query, ignoredWords);
  if (wanted.isEmpty) return SpokenMatchScore.none;
  final wantedJoined = wanted.join();

  var best = SpokenMatchScore.none;
  for (final candidate in candidates) {
    final have = spokenWords(candidate);
    if (have.isEmpty) continue;
    final int score;
    if (_sameWords(wanted, have)) {
      score = 3;
    } else if (wanted.every((word) => have.any((w) => w.startsWith(word)))) {
      score = 2;
    } else if (wantedJoined.length >= 4 && have.join().contains(wantedJoined)) {
      score = 1;
    } else {
      continue;
    }
    final found = SpokenMatchScore(score, have.length - wanted.length);
    if (found.isBetterThan(best)) best = found;
  }
  return best;
}

/// The entry of [entries] that [query] names best, by [spokenMatchScore]
/// over its [names]; the earlier entry wins a tie. Null when none matches.
({T entry, SpokenMatchScore score})? bestSpokenMatch<T>(
  String query,
  Iterable<T> entries,
  Iterable<String> Function(T entry) names, {
  Set<String> ignoredWords = const {},
}) {
  ({T entry, SpokenMatchScore score})? best;
  for (final entry in entries) {
    final score =
        spokenMatchScore(query, names(entry), ignoredWords: ignoredWords);
    if (score.score == 0) continue;
    if (best == null || score.isBetterThan(best.score)) {
      best = (entry: entry, score: score);
    }
  }
  return best;
}

/// How well a phrase named something: [score] as [spokenMatchScore]
/// describes it, then [extraWords], how many words of the name went unsaid -
/// "kumayl" names Dua Kumayl better than Dua Kumayl (Night of 15th Shaban).
class SpokenMatchScore {
  const SpokenMatchScore(this.score, this.extraWords);

  static const SpokenMatchScore none = SpokenMatchScore(0, 0);

  final int score;
  final int extraWords;

  bool isBetterThan(SpokenMatchScore other) {
    if (score != other.score) return score > other.score;
    if (other.score == 0) return false;
    return extraWords < other.extraWords;
  }

  /// Whether this is at least as good a match as [other].
  bool isAtLeast(SpokenMatchScore other) => !other.isBetterThan(this);

  @override
  String toString() => 'SpokenMatchScore($score, +$extraWords)';
}

/// [text] as lowercase words without accents or apostrophes: "Mu'minin"
/// is "muminin", "Ṣalāt" is "salat".
List<String> spokenWords(String text) {
  final folded = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    if (_apostrophes.contains(char)) continue;
    folded.write(_accentFolds[char] ?? char);
  }
  return folded
      .toString()
      .split(_nonWord)
      .where((word) => word.isNotEmpty)
      .toList();
}

List<String> _queryWords(String query, Set<String> ignoredWords) {
  final words = spokenWords(query);
  final ignored = {..._fillerWords, ...ignoredWords};
  final kept = words.where((word) => !ignored.contains(word)).toList();
  return kept.isEmpty ? words : kept;
}

bool _sameWords(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

const Set<String> _fillerWords = {'the', 'my', 'please'};

const Set<String> _apostrophes = {"'", '’', '‘', 'ʿ', 'ʾ', '`'};

final RegExp _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

const Map<String, String> _accentFolds = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ā': 'a', 'ã': 'a', //
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', //
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', //
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'ō': 'o', //
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', //
  'ḥ': 'h', 'ṣ': 's', 'ḍ': 'd', 'ṭ': 't', 'ẓ': 'z', 'ḏ': 'dh', 'ṯ': 'th',
  'ġ': 'gh', 'š': 'sh', 'ç': 'c', 'ñ': 'n',
};
