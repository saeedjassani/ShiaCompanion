import 'dart:convert';

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

/// A reorder that has not reached the server yet.
///
/// [version] is the mutation counter the reorder was recorded at, which is what
/// lets a late write tell its own reorder apart from a newer one.
class PendingFavoriteOrder {
  const PendingFavoriteOrder({
    required this.version,
    required this.orderedKeys,
  });

  final int version;
  final List<String> orderedKeys;
}

String encodePendingFavoriteOrder(PendingFavoriteOrder order) {
  return jsonEncode({
    'version': order.version,
    'keys': order.orderedKeys,
  });
}

/// Returns null for anything that cannot be read back as an ordering, so a
/// corrupt marker is dropped instead of scrambling the list.
PendingFavoriteOrder? decodePendingFavoriteOrder(String? encoded) {
  if (encoded == null || encoded.isEmpty) return null;

  try {
    final parsed = jsonDecode(encoded);
    if (parsed is! Map) return null;
    final keys = parsed['keys'];
    if (keys is! List) return null;
    final orderedKeys = [
      for (final key in keys)
        if (key is String && key.trim().isNotEmpty) key,
    ];
    if (orderedKeys.isEmpty) return null;
    final version = parsed['version'];
    return PendingFavoriteOrder(
      version: version is int ? version : 0,
      orderedKeys: orderedKeys,
    );
  } catch (_) {
    return null;
  }
}

/// Whether a write that published [version] may drop [stored].
///
/// A marker recorded after that write belongs to a reorder still waiting on the
/// network, so clearing it would lose the newer ordering.
bool shouldClearPendingFavoriteOrder(
  PendingFavoriteOrder? stored,
  int version,
) {
  return stored == null || stored.version <= version;
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
