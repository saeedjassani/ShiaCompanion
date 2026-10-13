import '../models/verse_note.dart';

enum VerseNoteOperationKind { save, remove }

extension VerseNoteOperationKindInfo on VerseNoteOperationKind {
  String get key => switch (this) {
        VerseNoteOperationKind.save => 'save',
        VerseNoteOperationKind.remove => 'remove',
      };
}

VerseNoteOperationKind? verseNoteOperationKindFromKey(String key) {
  for (final kind in VerseNoteOperationKind.values) {
    if (kind.key == key) return kind;
  }
  return null;
}

/// A note written, edited or deleted while offline (or while a Firestore
/// write is in flight), replayed against the remote doc once it succeeds.
///
/// Both are idempotent and ordered by time rather than by arrival - see
/// [VerseNotesState.save] and [VerseNotesState.remove] - so replaying one
/// late, or twice, can never undo something newer.
///
/// Every change to one verse's note shares one [id]: the queue keeps only the
/// newest operation per id, so a note edited five times offline replays as
/// its last version.
class PendingVerseNoteOperation {
  const PendingVerseNoteOperation._({
    required this.kind,
    required this.verseKey,
    required this.at,
    this.note,
  });

  factory PendingVerseNoteOperation.save(VerseNote note) {
    return PendingVerseNoteOperation._(
      kind: VerseNoteOperationKind.save,
      verseKey: note.key,
      at: note.updatedAt,
      note: note,
    );
  }

  factory PendingVerseNoteOperation.remove(String verseKey, DateTime at) {
    return PendingVerseNoteOperation._(
      kind: VerseNoteOperationKind.remove,
      verseKey: verseKey,
      at: at,
    );
  }

  final VerseNoteOperationKind kind;
  final String verseKey;

  /// When the change was made: the note's own time for a save, the moment
  /// of deletion for a remove.
  final DateTime at;

  /// The note being saved; null for a remove.
  final VerseNote? note;

  String get id => 'note_$verseKey';

  Map<String, Object> toJson() => {
        'kind': kind.key,
        'verseKey': verseKey,
        'at': at.toUtc().toIso8601String(),
        if (note != null) 'note': note!.toJson(),
      };

  static PendingVerseNoteOperation? fromJson(dynamic value) {
    if (value is! Map) return null;

    final kind = verseNoteOperationKindFromKey(value['kind']?.toString() ?? '');
    final verseKey = value['verseKey']?.toString().trim() ?? '';
    if (kind == null || verseKey.isEmpty) return null;

    switch (kind) {
      case VerseNoteOperationKind.save:
        final raw = value['note'];
        if (raw is! Map) return null;
        final note = VerseNote.fromJson(Map<String, dynamic>.from(raw));
        if (!note.isValid) return null;
        return PendingVerseNoteOperation.save(note);
      case VerseNoteOperationKind.remove:
        final at = DateTime.tryParse(value['at']?.toString() ?? '');
        if (at == null) return null;
        return PendingVerseNoteOperation.remove(verseKey, at);
    }
  }
}

VerseNotesState applyPendingVerseNoteOperations(
  VerseNotesState state,
  Iterable<PendingVerseNoteOperation> operations,
) {
  var nextState = state;
  for (final operation in operations) {
    nextState = applyPendingVerseNoteOperation(nextState, operation);
  }
  return nextState;
}

VerseNotesState applyPendingVerseNoteOperation(
  VerseNotesState state,
  PendingVerseNoteOperation operation,
) {
  return switch (operation.kind) {
    VerseNoteOperationKind.save =>
      operation.note == null ? state : state.save(operation.note!),
    VerseNoteOperationKind.remove =>
      state.remove(operation.verseKey, operation.at),
  };
}
