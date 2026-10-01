import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/utils/slug_registry.dart';

/// The entries in [entries] whose title contains [query].
///
/// [slugsFor], when given, also lets a query match an entry's URL slugs.
/// Titles get respelled over time (Ziyarat e Waaresa became Ziyarat Warith)
/// while the slugs keep the old spelling so existing links still work, so
/// matching slugs too means a search for the spelling someone learned still
/// finds the zikr.
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

  return entries
      .where(
        (entry) =>
            !entry.uid.contains('|') &&
            (entry.title.toLowerCase().contains(normalizedQuery) ||
                matchesSlug(entry) ||
                (matchUid &&
                    entry.uid.toLowerCase().contains(normalizedQuery))),
      )
      .toList(growable: false);
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
