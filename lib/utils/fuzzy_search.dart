import 'dart:math';

import 'package:shia_companion/utils/data_search_filter.dart'
    show foldSearchText;

/// Matching by how a name sounds rather than how it is spelled, for the
/// searches exact matching misses.
///
/// Readers type a dua's name the way they learned to say it, in whatever
/// romanization (or script) they know: "sanamaiqoraish" and "duae
/// sunmaikuresh" for Dua Sanamay Quraish, "bakra" for Al-Baqarah, "hadis
/// kissa" for Hadith al-Kisa, "thawassul" for Tawassul, and Hindi
/// "दुआ-ए-मुक़ातिल बिन सुलेमान" for Dua Muqatil ibn Sulayman. All of these
/// reached the "Request a Zikr" queue because search found nothing.
///
/// Each word is reduced to a consonant skeleton ([phoneticKey]): vowels,
/// doubled letters and a final h are dropped, and the letters romanizations
/// disagree on are merged (q/k, th/s as Urdu says ث, dh/z, v/w...). A query
/// matches when every one of its words matches a word of the title, its
/// slugs or its translated title, allowing a small edit distance on longer
/// skeletons. Words run together ("duasanme") match adjacent title words
/// joined, and the last word may be a prefix, as it is mid-typing.
class FuzzyQuery {
  FuzzyQuery._(
    this._required,
    this._optional,
    this._lastTyped, {
    this.weak = false,
  });

  /// The query, ready to test entries against; null when it has no word
  /// worth matching by sound (only generic words like "dua", or only
  /// one-letter skeletons).
  static FuzzyQuery? parse(String query) {
    final folded = foldSearchText(query);
    // Numbers alone have no sound to match. Word by word, the "2" of a
    // verse reference "2:55" is too short to count and "55" found Surah 55.
    if (!_letter.hasMatch(folded)) return null;
    final tokens = _tokens(folded)
        .where((t) => !t.isStopword && t.key.length >= 2)
        .toList();
    if (tokens.isEmpty) return null;
    // Two-letter skeletons ("kisa" is "ks") match too much on their own, so
    // they only help rank - unless they are all the query has.
    final required = [
      for (final t in tokens)
        if (t.key.length >= 3) t,
    ];
    final optional = [
      for (final t in tokens)
        if (t.key.length < 3) t,
    ];
    if (required.isEmpty) {
      return FuzzyQuery._(optional, const [], tokens.last, weak: true);
    }
    return FuzzyQuery._(required, optional, tokens.last);
  }

  /// Whether every word is a two-letter skeleton - "kisa" is "ks", as are
  /// "case" and "kaws". Such a query is worth matching by sound only when it
  /// matches nothing exactly.
  final bool weak;

  final List<_Token> _required;
  final List<_Token> _optional;

  /// The word still being typed, which may be a prefix of a title word.
  final _Token _lastTyped;

  /// How much further than the closest fuzzy match another may be: past it
  /// they share a skeleton with the query, not a name. A [weak] query keeps
  /// only the closest.
  int get slack => weak ? 0 : 2;

  /// How far from the query itself a fuzzy match may be spelled when the
  /// query also matches exactly: only a variant spelling ("Kumail" beside
  /// "Kumayl") belongs next to exact matches.
  static const int besideExact = 1;

  /// How far [texts] (a title, its slugs, its translated title; folded or
  /// not) are from this query - lower is closer - or null when
  /// they do not match it.
  ///
  /// [allowPrefix] is off when the query already matches something exactly:
  /// then "sakina" is a whole word, not the start of "seeking".
  int? score(Iterable<String?> texts, {bool allowPrefix = true}) {
    final words = <_Token>[];
    for (final text in texts) {
      if (text != null && text.isNotEmpty) words.addAll(_entryWords(text));
    }
    if (words.isEmpty) return null;

    var total = 0;
    for (final token in _required) {
      final distance = _bestDistance(
        token,
        words,
        prefix: allowPrefix && identical(token, _lastTyped),
      );
      if (distance == null) return null;
      total += distance;
    }
    // An optional word that matches nothing costs more than any spelling
    // difference, so "hadis kissa" puts Hadith al-Kisa above other hadith.
    for (final token in _optional) {
      total += _bestDistance(token, words, prefix: false) ?? 100;
    }
    return total;
  }

  /// The closest [words] come to [token], as the edit distance between their
  /// spellings (so "kumail" is nearer "Kumayl" than "Kamilah"), or null.
  static int? _bestDistance(
    _Token token,
    List<_Token> words, {
    required bool prefix,
  }) {
    int? best;
    for (final word in words) {
      final lead = word.leadingStopword;
      if (lead != null
          ? token.key != word.key || !token.spelling.startsWith(lead)
          : !_keysMatch(token, word, prefix: prefix)) {
        continue;
      }
      final distance = _editDistance(token.spelling, word.spelling);
      if (best == null || distance < best) best = distance;
    }
    return best;
  }

  static bool _keysMatch(
    _Token queryToken,
    _Token wordToken, {
    required bool prefix,
  }) {
    final query = queryToken.key;
    final word = wordToken.key;
    if (query == word) return true;
    // Numbers are not spellings: "114" is not one edit from "14".
    if (queryToken.hasDigit || wordToken.hasDigit) return false;
    // Four consonants before a prefix counts: "kntr" (Centre) starts with
    // "knt", and "qunoot" is not being typed towards it.
    if (prefix && query.length >= 4 && word.startsWith(query)) return true;
    final shorter = min(query.length, word.length);
    final allowed = shorter >= 7
        ? 2
        : shorter >= 4
        ? 1
        : 0;
    // Near misses keep their first sound, as Soundex does; without it a
    // keyboard mash is one letter from something.
    if (allowed == 0 ||
        query[0] != word[0] ||
        (query.length - word.length).abs() > allowed) {
      return false;
    }
    return _editDistance(query, word, cutoff: allowed) <= allowed;
  }
}

final RegExp _digit = RegExp('[0-9]');

/// A letter in any script.
final RegExp _letter = RegExp(r'\p{L}', unicode: true);

/// [word]'s consonant skeleton; see [FuzzyQuery].
String phoneticKey(String word) => _tokenFor(word)?.key ?? '';

class _Token {
  _Token(
    this.spelling,
    this.key, {
    this.isStopword = false,
    this.leadingStopword,
  });

  /// The word in one Latin alphabet, vowels kept (for ranking).
  final String spelling;

  /// Its consonant skeleton (for matching).
  final String key;

  /// Worked out once: [FuzzyQuery._keysMatch] asks on every comparison.
  late final bool hasDigit = _digit.hasMatch(key);

  final bool isStopword;

  /// For title words joined after a generic word ("dua" + "sanamay"), that
  /// word's spelling: they match only a query word that starts with it and
  /// has the very same skeleton - "duasanme", not "rehman" for "the human"
  /// or "father" for "of asr".
  final String? leadingStopword;
}

/// Generic words that say what kind of entry it is, not which one: "surah e
/// bakra" should find Al-Baqarah, whose title has no "surah".
const Set<String> _stopwords = {
  'a', 'al', 'an', 'and', 'aur', 'e', 'el', 'i', 'ka', 'ke', 'ki', 'ko', //
  'of', 'the', 'for', 'ul', 'ur',
  'dua', 'duaa', 'duae', 'doa', 'dooa',
  'sura', 'surah', 'surat', 'surae', 'soora', 'soorah', 'soreh', 'sureh',
  'ziyarat', 'ziarat', 'ziyarah', 'ziyaarat', 'zyarat', 'zeyarat',
  'namaz', 'namaaz', 'nimaz', 'salat', 'salah', 'salaat',
  // Arabic-script "dua", "surah", "ziyarat", "namaz" (as foldSearchText
  // leaves them); Devanagari "दुआ" is spelled "dua" and needs no entry.
  'دعا', 'دعای', 'دعاء', 'دعایی', 'سوره', 'زیارت', 'زیاره', 'نماز',
};

final RegExp _wordSplit = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);

/// Entry texts repeat on every keystroke, so their words are worked out once.
final Map<String, List<_Token>> _entryCache = {};

List<_Token> _entryWords(String text) {
  final cached = _entryCache[text];
  if (cached != null) return cached;
  if (_entryCache.length > 20000) _entryCache.clear();

  final tokens = _tokens(foldSearchText(text));
  final words = <_Token>[
    for (final t in tokens)
      if (!t.isStopword && t.key.isNotEmpty) t,
  ];
  // Adjacent words joined, for a query that runs them together. A generic
  // word may lead the run, as "duasanme" includes the "dua", but nowhere
  // else: "hajj the" and "an and" are not names.
  for (var n = 2; n <= 3; n++) {
    for (var i = 0; i + n <= tokens.length; i++) {
      final run = tokens.sublist(i, i + n);
      if (run.skip(1).any((t) => t.isStopword)) continue;
      // Initials such as the "a.t.f.s." after a name join into nonsense.
      if (run.any((t) => t.spelling.length < 2)) continue;
      final spelling = run.map((t) => t.spelling).join();
      // Long enough to be a name: "ya" + "sin" is, "of" + "a" is not.
      if (spelling.length < 5) continue;
      final key = _collapse(run.map((t) => t.key).join());
      words.add(
        _Token(
          spelling,
          key,
          leadingStopword: run.first.isStopword ? run.first.spelling : null,
        ),
      );
    }
  }
  return _entryCache[text] = words;
}

List<_Token> _tokens(String text) => [
  for (final word in text.toLowerCase().split(_wordSplit))
    if (_tokenFor(word) case final token?) token,
];

_Token? _tokenFor(String word) {
  if (word.isEmpty) return null;
  final first = word.runes.first;
  if (first >= 0x0600 && first <= 0x06FF) return _arabicToken(word);

  final String spelling;
  if (first >= 0x0900 && first <= 0x097F) {
    spelling = _devanagariSpelling(word);
    if (spelling.isEmpty) return null;
    // "दुआ" is spelled "dua" like the Latin word, so it is a stopword too.
    return _Token(
      spelling,
      _latinKey(spelling),
      isStopword: _stopwords.contains(spelling),
    );
  }
  final latin = _latinSpelling(word);
  if (latin.isEmpty) return null;
  return _Token(
    latin,
    _latinKey(latin),
    isStopword: _stopwords.contains(_plainLatin(word)),
  );
}

/// [word] lowercased, accents and apostrophes dropped: the form stopwords
/// are listed in.
String _plainLatin(String word) {
  final buffer = StringBuffer();
  for (final rune in word.runes) {
    if ((rune >= 0x61 && rune <= 0x7A) || (rune >= 0x30 && rune <= 0x39)) {
      buffer.writeCharCode(rune);
    } else if (_accentFolds[String.fromCharCode(rune)] case final folded?) {
      buffer.write(folded);
    }
  }
  return buffer.toString();
}

/// [word] in the merged alphabet both Latin and Devanagari words are spelled
/// in: the letter pairs romanizations disagree on become one letter.
String _latinSpelling(String word) {
  var s = _plainLatin(word);
  if (s.isEmpty) return s;
  // ث, which Urdu says (and spells) as s mid-word - "hadis" is "hadith" -
  // but a leading th is more often an aspirated t: "thawassul".
  if (s.startsWith('th')) s = 't${s.substring(2)}';
  // A diphthong before a consonant: "jawshan" is said "joshan" too, while
  // the w of "tawassul" and "awwal" is a consonant.
  s = s.replaceAll(RegExp(r'[ao]w(?=[^aeiouyw]|$)'), 'o');
  s = s
      .replaceAll('ch', '\u0001')
      .replaceAll('kh', 'k')
      .replaceAll('gh', 'g')
      .replaceAll('sh', 's')
      .replaceAll('th', 's')
      // ذ, which Urdu says as z: "zikr" is "dhikr".
      .replaceAll('dh', 'z')
      .replaceAll('zh', 'z')
      .replaceAll('ph', 'f')
      .replaceAll('bh', 'b')
      .replaceAll('jh', 'j')
      .replaceAll('ck', 'k')
      .replaceAll('c', 'k')
      .replaceAll('\u0001', 'c')
      .replaceAll('q', 'k')
      .replaceAll('v', 'w')
      .replaceAll('x', 'ks');
  // A final h is silent: "baqarah" is "bakra".
  if (s.length > 1 && s.endsWith('h')) s = s.substring(0, s.length - 1);
  return s;
}

/// [spelling]'s consonant skeleton: no vowels (y counts as one - "kumail"
/// is "kumayl") and no doubled letters.
String _latinKey(String spelling) =>
    _collapse(spelling.replaceAll(RegExp('[aeiouy]'), ''));

/// [s] with doubled letters single; digits stay as they are ("114").
String _collapse(String s) =>
    s.replaceAllMapped(RegExp(r'([a-z])\1+'), (m) => m.group(1)!);

/// Arabic-script words are compared as typed (already folded by
/// `foldSearchText`), without the article: "صنعی" still finds "صنمی".
_Token? _arabicToken(String word) {
  var s = word;
  if (s.startsWith('ال') && s.length > 3) s = s.substring(2);
  if (s.isEmpty) return null;
  return _Token(s, s, isStopword: _stopwords.contains(word));
}

/// [word] (Devanagari) in the merged Latin alphabet of [_latinSpelling].
String _devanagariSpelling(String word) {
  final runes = word.runes.toList();
  final out = StringBuffer();
  for (var i = 0; i < runes.length; i++) {
    final rune = runes[i];
    var consonant = _devaConsonants[rune];
    if (consonant != null) {
      if (i + 1 < runes.length && runes[i + 1] == 0x093C) {
        consonant = _devaNukta[rune] ?? consonant;
        i++;
      }
      out.write(consonant);
      final after = i + 1 < runes.length ? runes[i + 1] : null;
      // The vowel a consonant carries unless a sign replaces or cancels it
      // (left off at the end of a word, where Hindi drops it too).
      if (after != null && after != 0x094D && !_devaMatras.containsKey(after)) {
        out.write('a');
      }
      continue;
    }
    final vowel = _devaMatras[rune] ?? _devaVowels[rune];
    if (vowel != null) {
      out.write(vowel);
    } else if (rune == 0x0902 || rune == 0x0901) {
      out.write('n');
    } else if (rune >= 0x0966 && rune <= 0x096F) {
      out.writeCharCode(0x30 + rune - 0x0966);
    }
  }
  return out.toString();
}

const Map<int, String> _devaConsonants = {
  0x0915: 'k', 0x0916: 'k', 0x0917: 'g', 0x0918: 'g', 0x0919: 'n', //
  0x091A: 'c', 0x091B: 'c', 0x091C: 'j', 0x091D: 'j', 0x091E: 'n',
  0x091F: 't', 0x0920: 't', 0x0921: 'd', 0x0922: 'd', 0x0923: 'n',
  0x0924: 't', 0x0925: 't', 0x0926: 'd', 0x0927: 'd', 0x0928: 'n',
  0x092A: 'p', 0x092B: 'f', 0x092C: 'b', 0x092D: 'b', 0x092E: 'm',
  0x092F: 'y', 0x0930: 'r', 0x0932: 'l', 0x0935: 'w', 0x0936: 's',
  0x0937: 's', 0x0938: 's', 0x0939: 'h',
  // Precomposed nukta letters: क़ ख़ ग़ ज़ ड़ ढ़ फ़ य़.
  0x0958: 'k', 0x0959: 'k', 0x095A: 'g', 0x095B: 'z', 0x095C: 'r',
  0x095D: 'r', 0x095E: 'f', 0x095F: 'y',
};

/// A consonant followed by a nukta (़): ज़ is z, not j.
const Map<int, String> _devaNukta = {
  0x091C: 'z', 0x0921: 'r', 0x0922: 'r', 0x092B: 'f', 0x0916: 'k', //
  0x0917: 'g', 0x0915: 'k',
};

const Map<int, String> _devaMatras = {
  0x093E: 'a', 0x093F: 'i', 0x0940: 'i', 0x0941: 'u', 0x0942: 'u', //
  0x0943: 'ri', 0x0947: 'e', 0x0948: 'ai', 0x094B: 'o', 0x094C: 'au',
  0x0949: 'o', 0x0945: 'e',
};

const Map<int, String> _devaVowels = {
  0x0905: 'a', 0x0906: 'a', 0x0907: 'i', 0x0908: 'i', 0x0909: 'u', //
  0x090A: 'u', 0x090B: 'ri', 0x090F: 'e', 0x0910: 'ai', 0x0913: 'o',
  0x0914: 'au', 0x0911: 'o',
};

const Map<String, String> _accentFolds = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ā': 'a', 'ã': 'a', 'å': 'a', //
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'ō': 'o', 'õ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
  'ç': 'c', 'ñ': 'n', 'ḥ': 'h', 'ṣ': 's', 'ṭ': 't', 'ẓ': 'z', 'ḍ': 'd',
  'ẖ': 'h', 'ġ': 'g', 'ḳ': 'k',
};

/// Levenshtein distance; stops early once past [cutoff].
int _editDistance(String a, String b, {int? cutoff}) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    var rowMin = current[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = min(
        min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + cost,
      );
      if (current[j] < rowMin) rowMin = current[j];
    }
    if (cutoff != null && rowMin > cutoff) return rowMin;
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}
