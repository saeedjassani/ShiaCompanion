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
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return const [];
  }
  final slugQuery = normalizeSlug(normalizedQuery);

  bool matchesSlug(UidTitleData entry) =>
      slugsFor != null &&
      slugQuery.isNotEmpty &&
      slugsFor(entry.uid).any((slug) => slug.contains(slugQuery));

  final matches = entries
      .where(
        (entry) =>
            !entry.uid.contains('|') &&
            (entry.title.toLowerCase().contains(normalizedQuery) ||
                (entry.author?.toLowerCase().contains(normalizedQuery) ??
                    false) ||
                matchesSlug(entry) ||
                (matchUid &&
                    entry.uid.toLowerCase().contains(normalizedQuery))),
      )
      .toList();
  final ranked = [
    for (var i = 0; i < matches.length; i++)
      (rank: searchMatchRank(matches[i].title, normalizedQuery), index: i),
  ];
  // List.sort is not stable, so ties fall back to position explicitly.
  ranked.sort((a, b) => a.rank != b.rank ? a.rank - b.rank : a.index - b.index);
  return [for (final r in ranked) matches[r.index]];
}

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
