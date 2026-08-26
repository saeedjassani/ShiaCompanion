import 'package:shia_companion/data/uid_title_data.dart';

List<UidTitleData> filterDataSearchResults(
  Iterable<UidTitleData> entries,
  String query,
) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return const [];
  }

  return entries
      .where(
        (entry) =>
            !entry.uid.contains('|') &&
            entry.title.toLowerCase().contains(normalizedQuery),
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
