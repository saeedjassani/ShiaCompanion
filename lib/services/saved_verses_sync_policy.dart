import '../models/saved_verse.dart';

enum SavedVerseOperationKind { save, unsave }

extension SavedVerseOperationKindInfo on SavedVerseOperationKind {
  String get key => switch (this) {
        SavedVerseOperationKind.save => 'save',
        SavedVerseOperationKind.unsave => 'unsave',
      };
}

SavedVerseOperationKind? savedVerseOperationKindFromKey(String key) {
  for (final kind in SavedVerseOperationKind.values) {
    if (kind.key == key) return kind;
  }
  return null;
}

/// A save or unsave queued while offline (or while a Firestore write is in
/// flight), replayed against the remote doc once it succeeds.
///
/// Both are naturally idempotent - saving a verse twice sets the same key
/// twice, unsaving one already gone is a no-op - so the queue needs no merge
/// arithmetic.
///
/// Saving and unsaving the same verse share one [id]: the queue keeps only
/// the newest operation per id, so it holds whichever the reader did last
/// rather than replaying a save and an unsave in the wrong order.
class PendingSavedVerseOperation {
  const PendingSavedVerseOperation._({
    required this.kind,
    required this.verseKey,
    this.verse,
  });

  factory PendingSavedVerseOperation.save(SavedVerse verse) {
    return PendingSavedVerseOperation._(
      kind: SavedVerseOperationKind.save,
      verseKey: verse.key,
      verse: verse,
    );
  }

  factory PendingSavedVerseOperation.unsave(String verseKey) {
    return PendingSavedVerseOperation._(
      kind: SavedVerseOperationKind.unsave,
      verseKey: verseKey,
    );
  }

  final SavedVerseOperationKind kind;
  final String verseKey;

  /// The verse being saved; null for an unsave.
  final SavedVerse? verse;

  String get id => 'verse_$verseKey';

  Map<String, Object> toJson() => {
        'kind': kind.key,
        'verseKey': verseKey,
        if (verse != null) 'verse': verse!.toJson(),
      };

  static PendingSavedVerseOperation? fromJson(dynamic value) {
    if (value is! Map) return null;

    final kind =
        savedVerseOperationKindFromKey(value['kind']?.toString() ?? '');
    final verseKey = value['verseKey']?.toString().trim() ?? '';
    if (kind == null || verseKey.isEmpty) return null;

    switch (kind) {
      case SavedVerseOperationKind.save:
        final raw = value['verse'];
        if (raw is! Map) return null;
        final verse = SavedVerse.fromJson(Map<String, dynamic>.from(raw));
        if (!verse.isValid) return null;
        return PendingSavedVerseOperation.save(verse);
      case SavedVerseOperationKind.unsave:
        return PendingSavedVerseOperation.unsave(verseKey);
    }
  }
}

SavedVersesState applyPendingSavedVerseOperations(
  SavedVersesState state,
  Iterable<PendingSavedVerseOperation> operations,
) {
  var nextState = state;
  for (final operation in operations) {
    nextState = applyPendingSavedVerseOperation(nextState, operation);
  }
  return nextState;
}

SavedVersesState applyPendingSavedVerseOperation(
  SavedVersesState state,
  PendingSavedVerseOperation operation,
) {
  return switch (operation.kind) {
    SavedVerseOperationKind.save =>
      operation.verse == null ? state : state.save(operation.verse!),
    SavedVerseOperationKind.unsave => state.unsave(operation.verseKey),
  };
}
