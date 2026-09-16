import '../models/recitation_tracker_state.dart';

enum RecitationOperationKind { add, remove }

extension RecitationOperationKindInfo on RecitationOperationKind {
  String get key => switch (this) {
        RecitationOperationKind.add => 'add',
        RecitationOperationKind.remove => 'remove',
      };
}

RecitationOperationKind? recitationOperationKindFromKey(String key) {
  for (final kind in RecitationOperationKind.values) {
    if (kind.key == key) return kind;
  }
  return null;
}

/// A mutation queued while offline (or while a Firestore write is in
/// flight), replayed against the remote doc once it succeeds.
///
/// Both kinds are naturally idempotent because entries are keyed by id: an
/// [add] replayed twice just sets the same id twice, and a [remove] replayed
/// against an id that is already gone is a no-op. So unlike the qaza
/// tracker's delta queue, this one needs no separate merge arithmetic.
class PendingRecitationOperation {
  const PendingRecitationOperation({
    required this.id,
    required this.kind,
    required this.entryId,
    this.entry,
  });

  factory PendingRecitationOperation.add(RecitationEntry entry) {
    return PendingRecitationOperation(
      id: entry.id,
      kind: RecitationOperationKind.add,
      entryId: entry.id,
      entry: entry,
    );
  }

  factory PendingRecitationOperation.remove(String entryId) {
    return PendingRecitationOperation(
      id: '${entryId}_remove',
      kind: RecitationOperationKind.remove,
      entryId: entryId,
    );
  }

  final String id;
  final RecitationOperationKind kind;
  final String entryId;
  final RecitationEntry? entry;

  Map<String, Object> toJson() => {
        'id': id,
        'kind': kind.key,
        'entryId': entryId,
        if (entry != null) 'entry': entry!.toJson(),
      };

  static PendingRecitationOperation? fromJson(dynamic value) {
    if (value is! Map) return null;

    final id = value['id']?.toString().trim() ?? '';
    final kind = recitationOperationKindFromKey(value['kind']?.toString() ?? '');
    final entryId = value['entryId']?.toString().trim() ?? '';
    if (id.isEmpty || kind == null || entryId.isEmpty) return null;

    if (kind == RecitationOperationKind.add) {
      final entry = RecitationEntry.fromJson(value['entry']);
      if (entry == null) return null;
      return PendingRecitationOperation.add(entry);
    }

    return PendingRecitationOperation.remove(entryId);
  }
}

RecitationTrackerState applyPendingRecitationOperations(
  RecitationTrackerState state,
  Iterable<PendingRecitationOperation> operations,
) {
  var nextState = state;
  for (final operation in operations) {
    nextState = applyPendingRecitationOperation(nextState, operation);
  }
  return nextState;
}

RecitationTrackerState applyPendingRecitationOperation(
  RecitationTrackerState state,
  PendingRecitationOperation operation,
) {
  return switch (operation.kind) {
    RecitationOperationKind.add =>
      operation.entry == null ? state : state.setEntry(operation.entry!),
    RecitationOperationKind.remove => state.removeEntry(operation.entryId),
  };
}
