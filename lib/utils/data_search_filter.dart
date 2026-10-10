import 'dart:math';

import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/utils/slug_registry.dart';

/// The entries in [entries] whose title contains [query].
///
/// [slugsFor], when given, also lets a query match an entry's URL slugs.
/// Titles get respelled over time (Ziyarat e Waaresa became Ziyarat Warith)
/// while the slugs keep the old spelling so existing links still work, so
/// matching slugs too means a search for the spelling someone learned still
/// finds the zikr.
///
/// [translatedTitleFor], when given, also matches the title an entry is shown
/// under in the reader's translation language, so a zikr is found by the name
/// on screen as well as by its English one.
///
/// A book also matches on its author, so someone who remembers who wrote a
/// book but not what it is called still finds it.
///
/// Results come best match first (see [searchMatchRank]), and in the order of
/// [entries] among equally good matches. "fa" matches 65 titles; ranked by
/// position alone, Al-Fatihah sat below "Dua No. 43 of Sahifa al-Kamila".
List<UidTitleData> filterDataSearchResults(
  Iterable<UidTitleData> entries,
  String query, {
  bool matchUid = false,
  Iterable<String> Function(String uid)? slugsFor,
  String? Function(String uid)? translatedTitleFor,
}) {
  final normalizedQuery = foldSearchText(query);
  if (normalizedQuery.isEmpty) {
    return const [];
  }
  final slugQuery = normalizeSlug(normalizedQuery);

  bool matchesSlug(UidTitleData entry) =>
      slugsFor != null &&
      slugQuery.isNotEmpty &&
      slugsFor(entry.uid).any((slug) => slug.contains(slugQuery));

  String? foldedTranslatedTitle(UidTitleData entry) {
    final title = translatedTitleFor?.call(entry.uid);
    return title == null ? null : foldSearchText(title);
  }

  bool matchesTranslatedTitle(UidTitleData entry) =>
      foldedTranslatedTitle(entry)?.contains(normalizedQuery) ?? false;

  final matches = entries
      .where(
        (entry) =>
            !entry.uid.contains('|') &&
            (entry.title.toLowerCase().contains(normalizedQuery) ||
                (entry.author?.toLowerCase().contains(normalizedQuery) ??
                    false) ||
                matchesSlug(entry) ||
                matchesTranslatedTitle(entry) ||
                (matchUid &&
                    entry.uid.toLowerCase().contains(normalizedQuery))),
      )
      .toList();
  int rankOf(UidTitleData entry) {
    final english = searchMatchRank(entry.title, normalizedQuery);
    final translated = foldedTranslatedTitle(entry);
    if (translated == null) return english;
    return min(english, searchMatchRank(translated, normalizedQuery));
  }

  final ranked = [
    for (var i = 0; i < matches.length; i++)
      (rank: rankOf(matches[i]), index: i),
  ];
  // List.sort is not stable, so ties fall back to position explicitly.
  ranked.sort((a, b) => a.rank != b.rank ? a.rank - b.rank : a.index - b.index);
  return [for (final r in ranked) matches[r.index]];
}

/// [text] as search compares it: lowercased, and - for Arabic, Urdu and
/// Persian - without what people type one way or another: harakat and
/// Quranic marks, tatweel, hamza seats (أ إ آ -> ا), the Arabic, Persian and
/// Urdu forms of ya, kaf and ha (ي ى ئ ے -> ی, ك -> ک, ة ۀ ہ ھ -> ه), and
/// Arabic-Indic, Persian and Gujarati digits. A zero-width non-joiner (Persian
/// half-space) counts as a space, so "نمازها" and "نماز‌ها" find each other
/// only where the reader typed the space too - as they would see it.
String foldSearchText(String text) {
  final buffer = StringBuffer();
  for (final rune in text.trim().toLowerCase().runes) {
    if ((rune >= 0x064B && rune <= 0x065F) ||
        rune == 0x0670 ||
        (rune >= 0x06D6 && rune <= 0x06ED) ||
        rune == 0x0640 ||
        rune == 0x200E ||
        rune == 0x200F) {
      continue;
    }
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + rune - 0x06F0);
    } else if (rune >= 0x0AE6 && rune <= 0x0AEF) {
      buffer.writeCharCode(0x30 + rune - 0x0AE6);
    } else {
      buffer.writeCharCode(_searchFolds[rune] ?? rune);
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

const Map<int, int> _searchFolds = {
  0x0623: 0x0627, // أ
  0x0625: 0x0627, // إ
  0x0622: 0x0627, // آ
  0x0671: 0x0627, // ٱ
  0x064A: 0x06CC, // ي
  0x0649: 0x06CC, // ى
  0x0626: 0x06CC, // ئ
  0x06D2: 0x06CC, // ے
  0x0643: 0x06A9, // ك
  0x0629: 0x0647, // ة
  0x06C0: 0x0647, // ۀ
  0x06C1: 0x0647, // ہ
  0x06C3: 0x0647, // ۃ
  0x06BE: 0x0647, // ھ
  0x0624: 0x0648, // ؤ
  0x200C: 0x0020, // zero-width non-joiner
};

/// Leading surah number and Arabic article: the "1: Al-" of "1: Al-Fatihah".
final RegExp _titleLeadPattern = RegExp(r'^(\d+:\s*)?(a[a-z]{1,2}-)?');
final RegExp _wordStartPattern = RegExp(r'[^a-z0-9]');

/// How well [title] matches [query] (lowercased and trimmed); lower is better.
///
///  0. The title starts with it, ignoring a surah number and an "Al-"-style
///     article - "fa" for "1: Al-Fatihah", "kum" for "Dua Kumayl".
///  1. A word in the title starts with it - "kum" for "Commentary on Dua
///     Kumayl".
///  2. It appears mid-word - "fa" for "8: Al-Anfal".
///  3. Only the slug, author or uid matched.
int searchMatchRank(String title, String query) {
  final lower = title.toLowerCase();
  final lead = _titleLeadPattern.matchAsPrefix(lower)?.end ?? 0;
  if (lower.startsWith(query) || lower.startsWith(query, lead)) return 0;

  var index = lower.indexOf(query);
  if (index < 0) return 3;
  while (index >= 0) {
    if (index == 0 || _wordStartPattern.hasMatch(lower[index - 1])) return 1;
    index = lower.indexOf(query, index + 1);
  }
  return 2;
}

/// Whether [term] is a search in its own right, or just more of [previous].
///
/// Someone typing "kumayl" pauses on the way, and narrowing with the backspace
/// key is the same move in reverse. Both are one search being refined, so a
/// term that extends — or is extended by — the one already recorded does not
/// count again.
bool isNewSearchTerm({required String? previous, required String term}) {
  if (previous == null) return true;

  final recorded = previous.trim().toLowerCase();
  final candidate = term.trim().toLowerCase();
  if (candidate.isEmpty) return false;

  return !recorded.startsWith(candidate) && !candidate.startsWith(recorded);
}
