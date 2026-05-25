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
