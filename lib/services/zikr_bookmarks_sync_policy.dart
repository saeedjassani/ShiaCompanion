import 'package:flutter/foundation.dart';

import 'zikr_bookmark_store.dart';

/// Every synced zikr bookmark, keyed by [ZikrBookmark.uid] - one per zikr,
/// as the reader has always had.
///
/// Only bookmarks that know their line are kept here. A scroll offset is a
/// distance in pixels on one screen at one text size, so it would land
/// somewhere else on any other device; a line is the same line everywhere.
/// See [ZikrBookmarksManager] for where the rest stay.
///
/// Two devices can change the same zikr's bookmark, so every change is
/// decided by [ZikrBookmark.updatedAt]: the later one wins, whichever order
/// they reach the document in.
@immutable
class ZikrBookmarksState {
  ZikrBookmarksState([Map<String, ZikrBookmark>? bookmarks])
      : bookmarks = Map.unmodifiable(bookmarks ?? const {});

  factory ZikrBookmarksState.fromJson(dynamic value) {
    if (value is! Map) return empty;
    final raw = value['bookmarks'];
    if (raw is! List) return empty;

    var state = empty;
    for (final entry in raw.whereType<Map>()) {
      state = state.save(
        ZikrBookmark.fromJson(Map<String, dynamic>.from(entry)),
      );
    }
    return state;
  }

  static final empty = ZikrBookmarksState();

  final Map<String, ZikrBookmark> bookmarks;

  bool get isEmpty => bookmarks.isEmpty;

  ZikrBookmark? operator [](String uid) => bookmarks[uid];

  /// Whether [bookmark] can be synced at all: it names a zikr and the line
  /// it sits on.
  static bool isSyncable(ZikrBookmark bookmark) =>
      bookmark.uid.isNotEmpty && bookmark.lineIndex != null;

  /// Keeps [bookmark] as its zikr's bookmark, unless that zikr already has
  /// one changed later - a stale save replayed from an offline queue must
  /// not undo a newer move made on another device.
  ZikrBookmarksState save(ZikrBookmark bookmark) {
    if (!isSyncable(bookmark)) return this;
    final existing = bookmarks[bookmark.uid];
    if (existing != null && bookmark.updatedAt.isBefore(existing.updatedAt)) {
      return this;
    }
    return ZikrBookmarksState({...bookmarks, bookmark.uid: bookmark});
  }

  /// Removes the bookmark on [uid], unless it was placed after [removedAt] -
  /// then it is a newer bookmark than the one the reader removed.
  ZikrBookmarksState remove(String uid, DateTime removedAt) {
    final existing = bookmarks[uid];
    if (existing == null || existing.updatedAt.isAfter(removedAt)) return this;
    return ZikrBookmarksState({...bookmarks}..remove(uid));
  }

  /// Unions two states by zikr, the later bookmark winning where both have
  /// one. Safe to call with the same addition twice - that is how a
  /// guest-to-user import survives being retried.
  ZikrBookmarksState plus(ZikrBookmarksState other) {
    var state = this;
    for (final bookmark in other.bookmarks.values) {
      state = state.save(bookmark);
    }
    return state;
  }

  Map<String, Object> toJson() => {
        'bookmarks': [
          for (final uid in bookmarks.keys.toList()..sort())
            bookmarks[uid]!.toJson(),
        ],
      };
}

enum ZikrBookmarkOperationKind { save, remove }

extension ZikrBookmarkOperationKindInfo on ZikrBookmarkOperationKind {
  String get key => switch (this) {
        ZikrBookmarkOperationKind.save => 'save',
        ZikrBookmarkOperationKind.remove => 'remove',
      };
}

ZikrBookmarkOperationKind? zikrBookmarkOperationKindFromKey(String key) {
  for (final kind in ZikrBookmarkOperationKind.values) {
    if (kind.key == key) return kind;
  }
  return null;
}

/// A bookmark saved, moved or removed while offline (or while a Firestore
/// write is in flight), replayed against the remote doc once it succeeds.
///
/// Both are idempotent and ordered by time rather than by arrival - see
/// [ZikrBookmarksState.save] and [ZikrBookmarksState.remove] - so replaying
/// one late, or twice, can never undo something newer.
///
/// Every change to one zikr's bookmark shares one [id]: the queue keeps only
/// the newest operation per id, so a bookmark placed, moved three times and
/// removed offline replays as just the removal.
class PendingZikrBookmarkOperation {
  const PendingZikrBookmarkOperation._({
    required this.kind,
    required this.uid,
    required this.at,
    this.bookmark,
  });

  factory PendingZikrBookmarkOperation.save(ZikrBookmark bookmark) {
    return PendingZikrBookmarkOperation._(
      kind: ZikrBookmarkOperationKind.save,
      uid: bookmark.uid,
      at: bookmark.updatedAt,
      bookmark: bookmark,
    );
  }

  factory PendingZikrBookmarkOperation.remove(String uid, DateTime at) {
    return PendingZikrBookmarkOperation._(
      kind: ZikrBookmarkOperationKind.remove,
      uid: uid,
      at: at,
    );
  }

  final ZikrBookmarkOperationKind kind;
  final String uid;

  /// When the change was made: the bookmark's own time for a save, the
  /// moment of removal for a remove.
  final DateTime at;

  /// The bookmark being saved; null for a remove.
  final ZikrBookmark? bookmark;

  String get id => 'bookmark_$uid';

  Map<String, Object> toJson() => {
        'kind': kind.key,
        'uid': uid,
        'at': at.toUtc().toIso8601String(),
        if (bookmark != null) 'bookmark': bookmark!.toJson(),
      };

  static PendingZikrBookmarkOperation? fromJson(dynamic value) {
    if (value is! Map) return null;

    final kind =
        zikrBookmarkOperationKindFromKey(value['kind']?.toString() ?? '');
    final uid = value['uid']?.toString().trim() ?? '';
    if (kind == null || uid.isEmpty) return null;

    switch (kind) {
      case ZikrBookmarkOperationKind.save:
        final raw = value['bookmark'];
        if (raw is! Map) return null;
        final bookmark = ZikrBookmark.fromJson(Map<String, dynamic>.from(raw));
        if (!ZikrBookmarksState.isSyncable(bookmark)) return null;
        return PendingZikrBookmarkOperation.save(bookmark);
      case ZikrBookmarkOperationKind.remove:
        final at = DateTime.tryParse(value['at']?.toString() ?? '');
        if (at == null) return null;
        return PendingZikrBookmarkOperation.remove(uid, at);
    }
  }
}

ZikrBookmarksState applyPendingZikrBookmarkOperations(
  ZikrBookmarksState state,
  Iterable<PendingZikrBookmarkOperation> operations,
) {
  var nextState = state;
  for (final operation in operations) {
    nextState = applyPendingZikrBookmarkOperation(nextState, operation);
  }
  return nextState;
}

ZikrBookmarksState applyPendingZikrBookmarkOperation(
  ZikrBookmarksState state,
  PendingZikrBookmarkOperation operation,
) {
  return switch (operation.kind) {
    ZikrBookmarkOperationKind.save =>
      operation.bookmark == null ? state : state.save(operation.bookmark!),
    ZikrBookmarkOperationKind.remove =>
      state.remove(operation.uid, operation.at),
  };
}
