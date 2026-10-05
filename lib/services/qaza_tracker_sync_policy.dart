import '../models/qaza_tracker_state.dart';

enum QazaOperationKind {
  addMissed,
  markCompleted,
  undoCompleted,
  setCount,
  addCounts,
}

extension QazaOperationKindInfo on QazaOperationKind {
  String get key => switch (this) {
        QazaOperationKind.addMissed => 'add_missed',
        QazaOperationKind.markCompleted => 'mark_completed',
        QazaOperationKind.undoCompleted => 'undo_completed',
        QazaOperationKind.setCount => 'set_count',
        QazaOperationKind.addCounts => 'add_counts',
      };
}

QazaOperationKind? qazaOperationKindFromKey(String key) {
  for (final kind in QazaOperationKind.values) {
    if (kind.key == key) return kind;
  }
  return null;
}

class PendingQazaOperation {
  const PendingQazaOperation({
    required this.id,
    required this.kind,
    required this.type,
    this.count,
  });

  factory PendingQazaOperation.addMissed({
    required String id,
    required QazaEntryType type,
  }) {
    return PendingQazaOperation(
      id: id,
      kind: QazaOperationKind.addMissed,
      type: type,
    );
  }

  factory PendingQazaOperation.markCompleted({
    required String id,
    required QazaEntryType type,
  }) {
    return PendingQazaOperation(
      id: id,
      kind: QazaOperationKind.markCompleted,
      type: type,
    );
  }

  factory PendingQazaOperation.undoCompleted({
    required String id,
    required QazaEntryType type,
  }) {
    return PendingQazaOperation(
      id: id,
      kind: QazaOperationKind.undoCompleted,
      type: type,
    );
  }

  factory PendingQazaOperation.setCount({
    required String id,
    required QazaEntryType type,
    required QazaEntryCount count,
  }) {
    return PendingQazaOperation(
      id: id,
      kind: QazaOperationKind.setCount,
      type: type,
      count: count,
    );
  }

  /// Adds [count]'s remaining and completed to the existing ones. Used for
  /// bulk additions (the qaza estimate, a guest import), which must stack on
  /// whatever another device changed rather than overwrite it as
  /// [PendingQazaOperation.setCount] would.
  factory PendingQazaOperation.addCounts({
    required String id,
    required QazaEntryType type,
    required QazaEntryCount count,
  }) {
    return PendingQazaOperation(
      id: id,
      kind: QazaOperationKind.addCounts,
      type: type,
      count: count,
    );
  }

  final String id;
  final QazaOperationKind kind;
  final QazaEntryType type;
  final QazaEntryCount? count;

  Map<String, Object> toJson() => {
        'id': id,
        'kind': kind.key,
        'type': type.key,
        if (count != null) 'count': count!.toJson(),
      };

  static PendingQazaOperation? fromJson(dynamic value) {
    if (value is! Map) return null;

    final id = value['id']?.toString().trim() ?? '';
    final kind = qazaOperationKindFromKey(value['kind']?.toString() ?? '');
    final type = qazaEntryTypeFromKey(value['type']?.toString() ?? '');
    if (id.isEmpty || kind == null || type == null) return null;

    final count = QazaEntryCount.fromJson(value['count']);
    if (kind == QazaOperationKind.setCount) {
      return PendingQazaOperation.setCount(
        id: id,
        type: type,
        count: count,
      );
    }
    if (kind == QazaOperationKind.addCounts) {
      return PendingQazaOperation.addCounts(
        id: id,
        type: type,
        count: count,
      );
    }

    return PendingQazaOperation(
      id: id,
      kind: kind,
      type: type,
    );
  }
}

QazaTrackerState applyPendingQazaOperations(
  QazaTrackerState state,
  Iterable<PendingQazaOperation> operations,
) {
  var nextState = state;
  for (final operation in operations) {
    nextState = applyPendingQazaOperation(nextState, operation);
  }
  return nextState;
}

QazaTrackerState applyPendingQazaOperation(
  QazaTrackerState state,
  PendingQazaOperation operation,
) {
  final count = state.countFor(operation.type);

  final nextCount = switch (operation.kind) {
    QazaOperationKind.addMissed => count.copyWith(
        remaining: count.remaining + 1,
      ),
    QazaOperationKind.markCompleted => count.remaining <= 0
        ? count
        : count.copyWith(
            remaining: count.remaining - 1,
            completed: count.completed + 1,
          ),
    QazaOperationKind.undoCompleted => count.completed <= 0
        ? count
        : count.copyWith(
            remaining: count.remaining + 1,
            completed: count.completed - 1,
          ),
    QazaOperationKind.setCount =>
      operation.count?.copyWith() ?? QazaEntryCount.zero,
    QazaOperationKind.addCounts =>
      count.plus(operation.count ?? QazaEntryCount.zero),
  };

  if (nextCount.remaining == count.remaining &&
      nextCount.completed == count.completed) {
    return state;
  }

  return state.setCount(operation.type, nextCount);
}

/// How many applied operation ids the remote document remembers. An id only
/// needs to stay long enough for the device that applied it to drop it from
/// its pending queue, which happens right after the write lands.
const qazaAppliedOperationIdLimit = 300;

/// The synced qaza document: the counts plus the ids of the operations
/// already folded into them.
///
/// Operations are deltas ("one fewer Asr owed"), so applying one twice
/// silently corrupts the counts. The applied ids are what make applying
/// idempotent: a retry after a crash, an overlapping replay or a duplicate
/// in the queue all find their id here and are skipped.
class QazaRemoteDoc {
  QazaRemoteDoc({
    required this.state,
    List<String> appliedOperationIds = const [],
  }) : appliedOperationIds = List.unmodifiable(appliedOperationIds);

  factory QazaRemoteDoc.fromData(Map<String, dynamic>? data) {
    final ids = data?['appliedOperationIds'];
    return QazaRemoteDoc(
      state: QazaTrackerState.fromJson(data?['entries']),
      appliedOperationIds: ids is List
          ? [
              for (final id in ids)
                if (id != null && id.toString().isNotEmpty) id.toString(),
            ]
          : const [],
    );
  }

  static final empty = QazaRemoteDoc(state: QazaTrackerState.empty);

  final QazaTrackerState state;
  final List<String> appliedOperationIds;

  bool hasApplied(String operationId) =>
      appliedOperationIds.contains(operationId);

  Map<String, Object> toData() => {
        'version': 1,
        'entries': state.toJson(),
        'appliedOperationIds': appliedOperationIds,
      };
}

/// Folds [operations] into [doc] in order, skipping any already applied.
QazaRemoteDoc applyQazaOperationsToRemote(
  QazaRemoteDoc doc,
  Iterable<PendingQazaOperation> operations,
) {
  var state = doc.state;
  final appliedIds = [...doc.appliedOperationIds];
  final seenIds = appliedIds.toSet();
  for (final operation in operations) {
    if (!seenIds.add(operation.id)) continue;
    state = applyPendingQazaOperation(state, operation);
    appliedIds.add(operation.id);
  }
  final overflow = appliedIds.length - qazaAppliedOperationIdLimit;
  return QazaRemoteDoc(
    state: state,
    appliedOperationIds:
        overflow > 0 ? appliedIds.sublist(overflow) : appliedIds,
  );
}

/// What to show: the remote counts plus the local operations that have not
/// reached them yet. Pending operations the remote already applied (written,
/// but not yet dropped from the local queue) are not counted again.
QazaTrackerState visibleQazaState(
  QazaRemoteDoc doc,
  Iterable<PendingQazaOperation> pendingOperations,
) {
  return applyPendingQazaOperations(
    doc.state,
    pendingOperations.where((operation) => !doc.hasApplied(operation.id)),
  );
}
