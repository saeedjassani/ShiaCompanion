import '../models/recitation_tracker_state.dart';

enum RecitationOperationKind { add, remove, addLabel }

extension RecitationOperationKindInfo on RecitationOperationKind {
  String get key => switch (this) {
        RecitationOperationKind.add => 'add',
        RecitationOperationKind.remove => 'remove',
        RecitationOperationKind.addLabel => 'add_label',
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
/// All three kinds are naturally idempotent: an [add] replayed twice just
/// sets the same entry id twice, a [remove] replayed against an id that is
/// already gone is a no-op, and [addLabel] replayed twice unions into the
/// same set entry. So unlike the qaza tracker's delta queue, this one needs
/// no separate merge arithmetic.
class PendingRecitationOperation {
  const PendingRecitationOperation({
    required this.id,
    required this.kind,
    this.entryId,
    this.entry,
    this.labelName,
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

  factory PendingRecitationOperation.addLabel(String labelName) {
    return PendingRecitationOperation(
      id: 'add_label_$labelName',
      kind: RecitationOperationKind.addLabel,
      labelName: labelName,
    );
  }

  final String id;
  final RecitationOperationKind kind;
  final String? entryId;
  final RecitationEntry? entry;
  final String? labelName;

  Map<String, Object> toJson() => {
        'id': id,
        'kind': kind.key,
        if (entryId != null) 'entryId': entryId!,
        if (entry != null) 'entry': entry!.toJson(),
        if (labelName != null) 'labelName': labelName!,
      };

  static PendingRecitationOperation? fromJson(dynamic value) {
    if (value is! Map) return null;

    final id = value['id']?.toString().trim() ?? '';
    final kind = recitationOperationKindFromKey(value['kind']?.toString() ?? '');
    if (id.isEmpty || kind == null) return null;

    switch (kind) {
      case RecitationOperationKind.add:
        final entry = RecitationEntry.fromJson(value['entry']);
        if (entry == null) return null;
        return PendingRecitationOperation.add(entry);
      case RecitationOperationKind.remove:
        final entryId = value['entryId']?.toString().trim() ?? '';
        if (entryId.isEmpty) return null;
        return PendingRecitationOperation.remove(entryId);
      case RecitationOperationKind.addLabel:
        final labelName = value['labelName']?.toString().trim() ?? '';
        if (labelName.isEmpty) return null;
        return PendingRecitationOperation.addLabel(labelName);
    }
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
    RecitationOperationKind.remove => operation.entryId == null
        ? state
        : state.removeEntry(operation.entryId!),
    RecitationOperationKind.addLabel => operation.labelName == null
        ? state
        : state.addCustomLabel(operation.labelName!),
  };
}
