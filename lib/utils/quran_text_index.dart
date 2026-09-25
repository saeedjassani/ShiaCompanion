import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../pages/zikr/zikr_content_parser.dart';
import 'quran_index.dart';

/// A searchable index of the Arabic text of every ayah, for matching a
/// recitation heard through the microphone to the verse being recited.
///
/// This is the first thing in the app to look *inside* the Quran documents
/// rather than at their titles - `data_search.dart` matches titles only. It is
/// built from the same documents the reader draws, through the same parser, so
/// a verse can never be findable here and absent there.
///
/// Built at runtime rather than shipped as a generated asset: a generated index
/// would be one more thing to drift out of step with `assets/zikr/`. The cost is
/// reading 114 documents and parsing them - about 150ms of parsing, and rather
/// more reading on web, where each document is an HTTP request. Hence the batched
/// reads in [_loadDocuments] and [prewarmQuranTextIndex], and the process-wide
/// cache, which together keep that off the path between tapping and listening.

// -----------------------------------------------------------------------------
// Normalisation
// -----------------------------------------------------------------------------

/// Codepoints that carry no consonantal information and so cannot help identify
/// a verse. Stripped from both the corpus and the transcript, symmetrically.
///
/// Deliberately more aggressive than [ZikrContentParser.formatArabicText],
/// which normalises for *display* and must preserve every mark a reciter needs.
/// Nothing here is ever shown to anyone: the display text is kept alongside the
/// tokens, untouched.
bool _isStrippedRune(int rune) {
  return (rune >= 0x0610 && rune <= 0x061A) || // Arabic signs
      (rune >= 0x064B && rune <= 0x065F) || // harakat, ulta pesh, khaṛi zer
      rune == 0x0670 || // superscript alef, all over the Indo-Pak corpus
      (rune >= 0x06D6 && rune <= 0x06ED) || // waqf, sajdah, small high marks
      rune == 0x0640 || // tatweel
      (rune >= 0x200B && rune <= 0x200F) || // zero-width, LRM/RLM
      (rune >= 0x202A && rune <= 0x202E) || // bidi embedding
      rune == 0x2060 ||
      rune == 0xFEFF ||
      (rune >= 0xE000 && rune <= 0xF8FF); // Qalam's private-use marks
}

/// Letterforms folded together because a speech recogniser will not reliably
/// tell them apart, and neither do the orthographies the corpus mixes.
const Map<int, int> _foldedLetters = <int, int>{
  0x0622: 0x0627, // آ -> ا
  0x0623: 0x0627, // أ -> ا
  0x0625: 0x0627, // إ -> ا
  0x0671: 0x0627, // ٱ -> ا
  0x0649: 0x064A, // ى -> ي
  0x0629: 0x0647, // ة -> ه
  0x0624: 0x0648, // ؤ -> و
  0x0626: 0x064A, // ئ -> ي
};

bool _isArabicLetter(int rune) => rune >= 0x0621 && rune <= 0x064A;

/// Reduces an Arabic line to the bare consonantal skeleton, space-separated.
///
/// This is what makes matching possible at all: a recogniser outputs modern
/// undiacriticised Arabic, the corpus is fully-vowelised Indo-Pak, and the two
/// meet only once both are stripped to their letters.
String normalizeQuranArabic(String line) {
  // The ayah number the corpus closes a verse with is not part of the verse.
  final withoutMarker = line.replaceAll(_trailingAyahNumber, ' ');

  final out = StringBuffer();
  var pendingSpace = false;

  for (final rune in withoutMarker.runes) {
    if (_isStrippedRune(rune)) continue;

    final folded = _foldedLetters[rune] ?? rune;
    if (_isArabicLetter(folded)) {
      if (pendingSpace && out.isNotEmpty) out.write(' ');
      pendingSpace = false;
      out.writeCharCode(folded);
      continue;
    }

    // Everything else - Latin, digits, punctuation, brackets - is a separator.
    pendingSpace = true;
  }

  return out.toString();
}

final RegExp _trailingAyahNumber = RegExp(r'\((\d+)\)\s*$');

/// The alef, dropped from match keys because whether one is written is the
/// biggest single disagreement between this corpus and a speech recogniser.
///
/// The corpus is Indo-Pak, which writes a long *ā* as the superscript alef
/// U+0670 - `تُكَذِّبٰنِ`, `الرَّحْمٰنِ` - where modern Arabic writes a full
/// `ا`, or in `الرحمن`'s case writes none at all. A recogniser emits modern
/// spelling, so any rule that keeps alefs has the two sides disagreeing on a
/// great many words, `تكذبان` and every other verb like it among them.
///
/// Dropping the letter altogether settles it in both directions at once, and
/// costs less than it sounds: the remaining consonants still identify a verse,
/// and only pairs distinguished by nothing but an alef (`قال` and `قل`) run
/// together - which the word order in the second pass then separates again.
const int _alef = 0x0627;

String _matchKey(String token) {
  final out = StringBuffer();
  for (final rune in token.runes) {
    if (rune != _alef) out.writeCharCode(rune);
  }
  return out.toString();
}

/// The match keys of an Arabic line, in order, duplicates kept.
List<String> quranTokens(String line) {
  final normalized = normalizeQuranArabic(line);
  if (normalized.isEmpty) return const [];

  return normalized
      .split(' ')
      .map(_matchKey)
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

// -----------------------------------------------------------------------------
// The index
// -----------------------------------------------------------------------------

/// One ayah as the matcher sees it: what to match against, and what to show
/// once it is matched.
class IndexedVerse {
  const IndexedVerse({
    required this.verse,
    required this.arabic,
    required this.translation,
    required this.tokens,
  });

  final VerseKey verse;

  /// The Arabic line exactly as authored, ayah marker and all - so a candidate
  /// row can be rendered with [ZikrContentParser.formatArabicText] like any
  /// other line in the app.
  final String arabic;

  /// The English line belonging to this ayah, or empty when the document has
  /// none.
  final String translation;

  final List<String> tokens;
}

/// Every ayah of the Quran, with an inverted index over their tokens.
class QuranTextIndex {
  QuranTextIndex._(this.verses, this._postings);

  factory QuranTextIndex.fromVerses(List<IndexedVerse> verses) {
    final postings = <String, List<int>>{};
    for (var i = 0; i < verses.length; i++) {
      // A token repeated inside one verse posts once: a verse either carries a
      // word or it does not, and repetition says nothing about which verse was
      // recited.
      for (final token in verses[i].tokens.toSet()) {
        (postings[token] ??= <int>[]).add(i);
      }
    }
    return QuranTextIndex._(
      List.unmodifiable(verses),
      Map.unmodifiable(postings),
    );
  }

  final List<IndexedVerse> verses;
  final Map<String, List<int>> _postings;

  bool get isEmpty => verses.isEmpty;

  /// The verses carrying [token], or null when none do.
  List<int>? versesWith(String token) => _postings[token];

  /// How much a token narrows things down.
  ///
  /// This is the whole reason matching works on a bad transcript: `الله`, `من`
  /// and `في` are in thousands of verses and count for almost nothing, while
  /// one uncommon word is very nearly an answer on its own.
  double idf(String token) {
    final df = _postings[token]?.length ?? 0;
    if (df == 0) return 0;
    return math.log(verses.length / (1 + df)).clamp(0.0, double.infinity);
  }

  /// The index of [verse], or null when it is absent.
  int? indexOf(VerseKey verse) {
    for (var i = 0; i < verses.length; i++) {
      final candidate = verses[i].verse;
      if (candidate.surah == verse.surah && candidate.ayah == verse.ayah) {
        return i;
      }
    }
    return null;
  }
}

// -----------------------------------------------------------------------------
// Loading
// -----------------------------------------------------------------------------

QuranTextIndex? _cached;
Future<QuranTextIndex>? _inFlight;

/// The index, built on first use and kept for the life of the process.
///
/// Concurrent callers share one build rather than racing two - the button can
/// be tapped again while the first tap is still loading.
Future<QuranTextIndex> loadQuranTextIndex(AssetBundle bundle) {
  final cached = _cached;
  if (cached != null) return Future.value(cached);

  return _inFlight ??= _build(bundle).then((index) {
    _cached = index;
    _inFlight = null;
    return index;
  }, onError: (Object error, StackTrace stack) {
    _inFlight = null;
    throw error;
  });
}

/// Starts the build before anything asks for it, ignoring the result.
///
/// The index is a few hundred milliseconds of work on a device and noticeably
/// more on web, where every document is a separate request. Paying that when the
/// Quran screen opens rather than when the microphone is tapped means the wait
/// falls in the time someone spends looking at the surah list, instead of between
/// the tap and the listening.
///
/// Safe to call repeatedly: a build already done or in flight is left alone. A
/// failure here is silent by design - it is nobody's error yet, and the real
/// call will surface it.
void prewarmQuranTextIndex(AssetBundle bundle) {
  if (_cached != null || _inFlight != null) return;
  loadQuranTextIndex(bundle).ignore();
}

/// Drops the cached index. For tests, which build it against fake bundles.
@visibleForTesting
void resetQuranTextIndexCache() {
  _cached = null;
  _inFlight = null;
}

Future<QuranTextIndex> _build(AssetBundle bundle) async {
  // Assets can only be read on the main isolate, so the reading happens here
  // and only the parsing goes to the worker.
  final documents = await _loadDocuments(bundle);

  final verses = kIsWeb
      ? await _indexOnMainThread(documents)
      : await compute(_indexDocuments, documents);
  return QuranTextIndex.fromVerses(verses);
}

/// How many documents to read at once.
///
/// Bounded rather than unbounded so this never opens 114 connections at once,
/// but wide enough that the round trips overlap.
const int _loadBatchSize = 16;

/// Reads every surah document, a batch at a time.
///
/// Reading them one after another is nearly free on a device, where an asset is
/// a file - 114 of them in about 300ms. On web each one is a separate HTTP
/// request, so in series they put 114 round trips between the tap and the
/// microphone, which is most of the wait before listening starts. Parsing, by
/// contrast, is about 150ms of the total on either platform.
///
/// Batching collapses those round trips into a handful. A surah that will not
/// load still costs that surah, not the feature.
Future<Map<int, String>> _loadDocuments(AssetBundle bundle) async {
  final uids = <int, String>{};
  for (var surah = 1; surah <= surahCount; surah++) {
    final uid = uidForSurah(surah);
    if (uid != null) uids[surah] = uid;
  }

  final documents = <int, String>{};
  final surahs = uids.keys.toList();

  for (var start = 0; start < surahs.length; start += _loadBatchSize) {
    final batch = surahs.skip(start).take(_loadBatchSize);
    await Future.wait(batch.map((surah) async {
      try {
        documents[surah] =
            await bundle.loadString('assets/zikr/${uids[surah]}');
      } catch (error) {
        debugPrint('QuranTextIndex: could not load ${uids[surah]}: $error');
      }
    }));
  }

  return documents;
}

/// Indexes the documents a surah at a time, yielding between each.
///
/// For web, where [compute] is not a worker at all - it awaits one frame and
/// then runs the callback inline - so parsing 114 documents in one go would
/// block the page, freezing even the spinner that is meant to say it is working.
/// Yielding lets each frame draw; the whole build is still a one-time cost
/// before the cache is warm.
Future<List<IndexedVerse>> _indexOnMainThread(
  Map<int, String> documents,
) async {
  final verses = <IndexedVerse>[];
  final surahs = documents.keys.toList()..sort();

  for (final surah in surahs) {
    verses.addAll(_indexOneDocument(surah, documents[surah]!));
    await null;
  }

  return verses;
}

/// Parses every document and flattens it to ayahs. Top-level and pure so it can
/// run on a background isolate.
List<IndexedVerse> _indexDocuments(Map<int, String> documents) {
  final verses = <IndexedVerse>[];
  final surahs = documents.keys.toList()..sort();
  for (final surah in surahs) {
    verses.addAll(_indexOneDocument(surah, documents[surah]!));
  }
  return verses;
}

/// The ayahs of one surah document. The single parsing path, shared by the
/// isolate build and the yielding one, so the two cannot come to differ.
@visibleForTesting
List<IndexedVerse> indexOneDocumentForTest(int surah, String raw) =>
    _indexOneDocument(surah, raw);

List<IndexedVerse> _indexOneDocument(int surah, String raw) {
  final Object? decoded;
  try {
    decoded = json.decode(raw);
  } catch (error) {
    // Same bargain as a surah that will not load: one unreadable document costs
    // that surah, not the whole index.
    debugPrint('QuranTextIndex: could not parse surah $surah: $error');
    return const [];
  }
  if (decoded is! Map) return const [];

  final content = ZikrContentParser.parseContent(
    decoded['data']?.toString() ?? '',
    hideHeaderLine: false,
  );

  final verses = <IndexedVerse>[];
  for (final span in spansOfParsedContent(content, surah: surah)) {
    final verse = span.verse;
    // Spans with no ayah number are the Bismillah heading a surah, which is
    // not an ayah anywhere but al-Fatehah - and there the corpus numbers it,
    // so it arrives here as ayah 1 like any other verse.
    if (verse == null) continue;

    final arabic = content.lines[span.start];
    final tokens = quranTokens(arabic);
    if (tokens.isEmpty) continue;

    verses.add(IndexedVerse(
      verse: verse,
      arabic: arabic,
      translation: _translationIn(content, span),
      tokens: tokens,
    ));
  }

  return verses;
}

/// The translation line inside [span], or empty when the document carries none.
///
/// Read out of the parser's own classification rather than by assuming the
/// layout code's offsets, so a document whose triplets are incomplete gives an
/// empty translation instead of somebody else's line.
String _translationIn(ParsedZikrContent content, AyahSpan span) {
  for (var line = span.start; line < span.end; line++) {
    if (content.translaCodes.contains(line)) return content.lines[line];
  }
  return '';
}
