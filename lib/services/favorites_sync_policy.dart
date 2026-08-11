import '../data/universal_data.dart';

class FavoritesSyncDecision {
  const FavoritesSyncDecision({
    required this.visibleFavorites,
    this.remoteSeed,
    this.guestFavoritesToImport = const [],
    this.canCleanUpLegacyData = false,
  });

  final List<UniversalData> visibleFavorites;
  final List<UniversalData>? remoteSeed;
  final List<UniversalData> guestFavoritesToImport;
  final bool canCleanUpLegacyData;
}

class PendingFavoriteOperation {
  const PendingFavoriteOperation({
    required this.favorite,
    required this.shouldExist,
  });

  final UniversalData favorite;
  final bool shouldExist;
}

FavoritesSyncDecision resolveSignedInFavorites({
  required bool remoteReadSucceeded,
  required bool remoteExists,
  required List<UniversalData> remoteFavorites,
  required List<UniversalData> cachedFavorites,
  required List<UniversalData> guestFavorites,
  required List<UniversalData> legacyFavorites,
  required bool shouldImportGuestFavorites,
}) {
  if (!remoteReadSucceeded) {
    return FavoritesSyncDecision(
      visibleFavorites: cachedFavorites.isNotEmpty
          ? cachedFavorites
          : shouldImportGuestFavorites
              ? guestFavorites
              : const [],
    );
  }

  if (!remoteExists) {
    final seed = _deduplicate([
      ...cachedFavorites,
      ...guestFavorites,
      ...legacyFavorites,
    ]);
    return FavoritesSyncDecision(
      visibleFavorites: seed,
      remoteSeed: seed,
      canCleanUpLegacyData: true,
    );
  }

  final guestImport = shouldImportGuestFavorites
      ? _deduplicate(guestFavorites)
      : const <UniversalData>[];
  return FavoritesSyncDecision(
    visibleFavorites: _deduplicate([
      ...remoteFavorites,
      ...guestImport,
    ]),
    guestFavoritesToImport: guestImport,
    canCleanUpLegacyData: true,
  );
}

List<UniversalData> _deduplicate(Iterable<UniversalData> source) {
  final seen = <String>{};
  return [
    for (final favorite in source)
      if (seen.add(favorite.favoriteKey)) favorite,
  ];
}

/// Restores a user's manual ordering on top of a server list that has no
/// ordering of its own to offer.
///
/// Entries missing from [orderedKeys] (favorites added elsewhere since the
/// reorder) keep their relative order and land after the ordered ones.
List<UniversalData> applyFavoriteOrder(
  Iterable<UniversalData> favorites,
  Iterable<String> orderedKeys,
) {
  final ranks = <String, int>{};
  for (final key in orderedKeys) {
    ranks.putIfAbsent(key, () => ranks.length);
  }

  final entries = favorites.toList(growable: false);
  if (ranks.isEmpty) return entries;

  final unrankedOffset = ranks.length;
  final decorated = [
    for (var index = 0; index < entries.length; index++)
      (
        rank: ranks[entries[index].favoriteKey] ?? unrankedOffset + index,
        index: index,
        favorite: entries[index],
      ),
  ]..sort((a, b) =>
      a.rank != b.rank ? a.rank.compareTo(b.rank) : a.index.compareTo(b.index));

  return [for (final entry in decorated) entry.favorite];
}

List<UniversalData> applyPendingFavoriteOperations(
  Iterable<UniversalData> favorites,
  Iterable<PendingFavoriteOperation> operations,
) {
  final byKey = {
    for (final favorite in _deduplicate(favorites))
      favorite.favoriteKey: favorite,
  };

  for (final operation in operations) {
    final favorite = operation.favorite;
    if (operation.shouldExist) {
      byKey[favorite.favoriteKey] = favorite;
    } else {
      byKey.remove(favorite.favoriteKey);
    }
  }

  return byKey.values.toList(growable: false);
}
