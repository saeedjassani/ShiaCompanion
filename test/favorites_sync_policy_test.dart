import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/services/favorites_sync_policy.dart';

void main() {
  UniversalData favorite(String uid) => UniversalData(uid, uid, 1);

  test('an existing remote list wins over stale cached and legacy entries', () {
    final kept = favorite('kept');
    final deleted = favorite('deleted');

    final decision = resolveSignedInFavorites(
      remoteReadSucceeded: true,
      remoteExists: true,
      remoteFavorites: [kept],
      cachedFavorites: [kept, deleted],
      guestFavorites: [deleted],
      legacyFavorites: [deleted],
      shouldImportGuestFavorites: false,
    );

    expect(decision.visibleFavorites, [kept]);
    expect(decision.remoteSeed, isNull);
    expect(decision.guestFavoritesToImport, isEmpty);
  });

  test('a failed remote read uses the cache without uploading a merged list',
      () {
    final kept = favorite('kept');

    final decision = resolveSignedInFavorites(
      remoteReadSucceeded: false,
      remoteExists: false,
      remoteFavorites: const [],
      cachedFavorites: [kept],
      guestFavorites: [favorite('stale-guest')],
      legacyFavorites: [favorite('stale-legacy')],
      shouldImportGuestFavorites: false,
    );

    expect(decision.visibleFavorites, [kept]);
    expect(decision.remoteSeed, isNull);
    expect(decision.canCleanUpLegacyData, isFalse);
  });

  test('local sources seed Firestore only when no remote index exists', () {
    final cached = favorite('cached');
    final guest = favorite('guest');
    final legacy = favorite('legacy');

    final decision = resolveSignedInFavorites(
      remoteReadSucceeded: true,
      remoteExists: false,
      remoteFavorites: const [],
      cachedFavorites: [cached],
      guestFavorites: [guest],
      legacyFavorites: [legacy, cached],
      shouldImportGuestFavorites: false,
    );

    expect(decision.visibleFavorites, [cached, guest, legacy]);
    expect(decision.remoteSeed, [cached, guest, legacy]);
    expect(decision.canCleanUpLegacyData, isTrue);
  });

  test('guest entries merge only during an explicit guest-to-user import', () {
    final remote = favorite('remote');
    final guest = favorite('guest');

    final decision = resolveSignedInFavorites(
      remoteReadSucceeded: true,
      remoteExists: true,
      remoteFavorites: [remote],
      cachedFavorites: const [],
      guestFavorites: [guest],
      legacyFavorites: const [],
      shouldImportGuestFavorites: true,
    );

    expect(decision.visibleFavorites, [remote, guest]);
    expect(decision.guestFavoritesToImport, [guest]);
    expect(decision.remoteSeed, isNull);
  });

  test('pending removals override a stale remote snapshot after restart', () {
    final kept = favorite('kept');
    final removedOffline = favorite('removed-offline');

    final favorites = applyPendingFavoriteOperations(
      [kept, removedOffline],
      [
        PendingFavoriteOperation(
          favorite: removedOffline,
          shouldExist: false,
        ),
      ],
    );

    expect(favorites, [kept]);
  });

  test('a pending reorder survives a server list that predates it', () {
    final first = favorite('first');
    final second = favorite('second');
    final third = favorite('third');

    final favorites = applyFavoriteOrder(
      [first, second, third],
      [third.favoriteKey, first.favoriteKey, second.favoriteKey],
    );

    expect(favorites, [third, first, second]);
  });

  test('favorites added since the reorder keep their order at the end', () {
    final reordered = favorite('reordered');
    final untouched = favorite('untouched');
    final addedElsewhere = favorite('added-elsewhere');
    final addedLater = favorite('added-later');

    final favorites = applyFavoriteOrder(
      [untouched, addedElsewhere, reordered, addedLater],
      [reordered.favoriteKey, untouched.favoriteKey],
    );

    expect(favorites, [reordered, untouched, addedElsewhere, addedLater]);
  });

  test('an empty order leaves the list untouched', () {
    final first = favorite('first');
    final second = favorite('second');

    expect(applyFavoriteOrder([first, second], const []), [first, second]);
  });

  test('a recorded order survives the round trip through storage', () {
    final encoded = encodePendingFavoriteOrder(
      PendingFavoriteOrder(version: 7, orderedKeys: ['1:second', '1:first']),
    );

    final decoded = decodePendingFavoriteOrder(encoded);

    expect(decoded?.version, 7);
    expect(decoded?.orderedKeys, ['1:second', '1:first']);
  });

  test('an unreadable marker is discarded rather than half applied', () {
    expect(decodePendingFavoriteOrder(null), isNull);
    expect(decodePendingFavoriteOrder(''), isNull);
    expect(decodePendingFavoriteOrder('not json'), isNull);
    expect(decodePendingFavoriteOrder('["1:first"]'), isNull);
    expect(decodePendingFavoriteOrder('{"version":1}'), isNull);
    expect(decodePendingFavoriteOrder('{"version":1,"keys":"1:first"}'), isNull);
    expect(decodePendingFavoriteOrder('{"version":1,"keys":[]}'), isNull);
  });

  test('unusable keys are dropped, and a marker left with none is too', () {
    final decoded = decodePendingFavoriteOrder(
      '{"version":1,"keys":["1:first",2,"","   ",null,"1:second"]}',
    );

    expect(decoded?.orderedKeys, ['1:first', '1:second']);
    expect(
      decodePendingFavoriteOrder('{"version":1,"keys":[2,"",null]}'),
      isNull,
    );
  });

  test('a marker written before versioning is treated as the oldest', () {
    final decoded = decodePendingFavoriteOrder('{"keys":["1:first"]}');

    expect(decoded?.version, 0);
    expect(shouldClearPendingFavoriteOrder(decoded, 0), isTrue);
  });

  test('a write only clears the reorder it published, or an older one', () {
    final stored = PendingFavoriteOrder(version: 5, orderedKeys: ['1:first']);

    expect(shouldClearPendingFavoriteOrder(stored, 5), isTrue);
    expect(shouldClearPendingFavoriteOrder(stored, 6), isTrue);
    expect(shouldClearPendingFavoriteOrder(stored, 4), isFalse);
    expect(shouldClearPendingFavoriteOrder(null, 5), isTrue);
  });

  test('the latest pending operation for an item determines its state', () {
    final favoriteToToggle = favorite('toggle');

    final favorites = applyPendingFavoriteOperations(
      const [],
      [
        PendingFavoriteOperation(
          favorite: favoriteToToggle,
          shouldExist: false,
        ),
        PendingFavoriteOperation(
          favorite: favoriteToToggle,
          shouldExist: true,
        ),
      ],
    );

    expect(favorites, [favoriteToToggle]);
  });
}
