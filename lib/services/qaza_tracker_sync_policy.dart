import '../models/qaza_tracker_state.dart';

enum QazaOperationKind {
  addMissed,
  markCompleted,
  undoCompleted,
  setCount,
}

extension QazaOperationKindInfo on QazaOperationKind {
  String get key => switch (this) {
        QazaOperationKind.addMissed => 'add_missed',
        QazaOperationKind.markCompleted => 'mark_completed',
        QazaOperationKind.undoCompleted => 'undo_completed',
        QazaOperationKind.setCount => 'set_count',
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
  };

  if (nextCount.remaining == count.remaining &&
      nextCount.completed == count.completed) {
    return state;
  }

  return state.setCount(operation.type, nextCount);
}
