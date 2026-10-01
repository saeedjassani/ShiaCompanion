import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/services/zikr_bookmark_store.dart';
import 'package:shia_companion/services/zikr_bookmarks_manager.dart';
import 'package:shia_companion/services/zikr_bookmarks_sync_policy.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'ui/firebase_test_doubles.dart';

ZikrBookmark _bookmark(
  String uid, {
  int? line = 10,
  int minute = 0,
  int tab = 0,
}) {
  return ZikrBookmark(
    uid: uid,
    title: 'Zikr $uid',
    tabIndex: tab,
    scrollOffset: 300,
    lineIndex: line,
    updatedAt: DateTime.utc(2026, 9, 30, 12, minute),
  );
}

void main() {
  group('ZikrBookmarksState', () {
    test('keeps one bookmark per zikr', () {
      final state = ZikrBookmarksState.empty
          .save(_bookmark('A1', line: 3))
          .save(_bookmark('A2', line: 5))
          .save(_bookmark('A1', line: 8, minute: 1));
      expect(state.bookmarks.keys, unorderedEquals(['A1', 'A2']));
      expect(state['A1']!.lineIndex, 8);
    });

    test('a bookmark without a line is not synced', () {
      // Its scroll offset would land somewhere else on any other screen.
      expect(
        ZikrBookmarksState.empty.save(_bookmark('A1', line: null)).isEmpty,
        isTrue,
      );
    });

    test('an older save does not undo a newer one', () {
      final state = ZikrBookmarksState.empty
          .save(_bookmark('A1', line: 20, minute: 5))
          .save(_bookmark('A1', line: 3, minute: 1));
      expect(state['A1']!.lineIndex, 20);
    });

    test('a removal only takes out a bookmark placed before it', () {
      final state = ZikrBookmarksState.empty.save(_bookmark('A1', minute: 5));
      expect(
        state.remove('A1', DateTime.utc(2026, 9, 30, 12, 6)).isEmpty,
        isTrue,
      );
      expect(
        state.remove('A1', DateTime.utc(2026, 9, 30, 12, 4))['A1'],
        isNotNull,
        reason: 'the bookmark was placed again after this removal',
      );
    });

    test('plus keeps the later bookmark of each zikr, and can be retried', () {
      final account = ZikrBookmarksState.empty
          .save(_bookmark('A1', line: 1, minute: 9))
          .save(_bookmark('A2', line: 2, minute: 1));
      final guest = ZikrBookmarksState.empty
          .save(_bookmark('A1', line: 7, minute: 2))
          .save(_bookmark('A2', line: 8, minute: 3))
          .save(_bookmark('A3', line: 9));

      final merged = account.plus(guest).plus(guest);
      expect(merged['A1']!.lineIndex, 1);
      expect(merged['A2']!.lineIndex, 8);
      expect(merged['A3']!.lineIndex, 9);
    });

    test('survives the JSON round trip', () {
      final state = ZikrBookmarksState.empty
          .save(_bookmark('A1', line: 4, tab: 2))
          .save(_bookmark('B7', line: 0));
      final restored =
          ZikrBookmarksState.fromJson(jsonDecode(jsonEncode(state.toJson())));
      expect(restored.bookmarks.keys, unorderedEquals(['A1', 'B7']));
      expect(restored['A1']!.tabIndex, 2);
      expect(restored['A1']!.lineIndex, 4);
      expect(restored['B7']!.lineIndex, 0);
    });

    test('nonsense rows are dropped', () {
      final state = ZikrBookmarksState.fromJson({
        'bookmarks': [
          'not a map',
          {'uid': '', 'lineIndex': 3},
          {'uid': 'A1'},
          _bookmark('A2').toJson(),
        ],
      });
      expect(state.bookmarks.keys, ['A2']);
    });
  });

  group('zikr bookmark operations', () {
    test('round trip through JSON', () {
      final save = PendingZikrBookmarkOperation.fromJson(
        PendingZikrBookmarkOperation.save(_bookmark('A1', line: 6)).toJson(),
      )!;
      expect(save.kind, ZikrBookmarkOperationKind.save);
      expect(save.bookmark!.lineIndex, 6);

      final removedAt = DateTime.utc(2026, 9, 30, 13);
      final remove = PendingZikrBookmarkOperation.fromJson(
        PendingZikrBookmarkOperation.remove('A1', removedAt).toJson(),
      )!;
      expect(remove.kind, ZikrBookmarkOperationKind.remove);
      expect(remove.at, removedAt);
    });

    test('every change to one zikr shares an id', () {
      expect(
        PendingZikrBookmarkOperation.save(_bookmark('A1')).id,
        PendingZikrBookmarkOperation.remove('A1', DateTime.now()).id,
      );
    });
  });

  group('ZikrBookmarksManager, signed out', () {
    setUpAll(setUpFirebaseForRenderTests);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SP.init();
      ZikrBookmarksManager.instance.resetForTesting();
    });

    ZikrBookmarksManager manager() => ZikrBookmarksManager.instance;

    test('saves, reads back and removes a bookmark', () async {
      await manager().loadBookmarks();
      await manager().save(_bookmark('A1', line: 12));

      expect(manager().bookmarkFor('A1')!.lineIndex, 12);
      expect(manager().state['A1'], isNotNull);

      await manager().remove('A1');
      expect(manager().bookmarkFor('A1'), isNull);
    });

    test('moving a bookmark replaces it even if it was dated later', () async {
      // As when another device with a fast clock placed it.
      await manager().loadBookmarks();
      await manager().save(_bookmark('A1', line: 3, minute: 50));
      await manager().save(_bookmark('A1', line: 9, minute: 10));

      expect(manager().bookmarkFor('A1')!.lineIndex, 9);
    });

    test('removing a bookmark dated in the future still removes it', () async {
      await manager().loadBookmarks();
      await manager().save(
        _bookmark('A1').copyWith(updatedAt: DateTime.utc(2099)),
      );
      await manager().remove('A1');
      expect(manager().bookmarkFor('A1'), isNull);
    });

    test('a bookmark without a line stays on the device only', () async {
      await manager().loadBookmarks();
      await manager().save(_bookmark('A1', line: null));

      expect(manager().state.isEmpty, isTrue);
      expect(ZikrBookmarkStore.instance.read('A1'), isNotNull);
      expect(manager().bookmarkFor('A1'), isNotNull);

      // Once it learns its line it syncs, and the device copy goes.
      await manager().save(_bookmark('A1', line: 4));
      expect(manager().state['A1']!.lineIndex, 4);
      expect(ZikrBookmarkStore.instance.read('A1'), isNull);
    });

    test('moves device bookmarks that know their line on first load', () async {
      await ZikrBookmarkStore.instance.save(_bookmark('A1', line: 7));
      await ZikrBookmarkStore.instance.save(_bookmark('A2', line: null));

      await manager().loadBookmarks();

      expect(manager().state['A1']!.lineIndex, 7);
      expect(ZikrBookmarkStore.instance.read('A1'), isNull);
      expect(manager().state['A2'], isNull);
      expect(ZikrBookmarkStore.instance.read('A2'), isNotNull,
          reason: 'it has no line to sync by yet');
      expect(manager().bookmarkFor('A2'), isNotNull);

      // And they survive a restart, from the guest copy.
      manager().resetForTesting();
      await manager().loadBookmarks();
      expect(manager().bookmarkFor('A1')!.lineIndex, 7);
    });
  });
}
