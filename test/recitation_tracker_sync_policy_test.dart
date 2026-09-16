import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/recitation_tracker_state.dart';
import 'package:shia_companion/services/recitation_tracker_sync_policy.dart';

void main() {
  group('PendingRecitationOperation', () {
    test('add serializes and restores the entry it carries', () {
      final entry = RecitationEntry(
        id: 'r_1',
        label: 'Family',
        recitedAt: DateTime.utc(2026, 1, 1),
      );
      final operation = PendingRecitationOperation.add(entry);
      final restored = PendingRecitationOperation.fromJson(operation.toJson());

      expect(restored, isNotNull);
      expect(restored!.kind, RecitationOperationKind.add);
      expect(restored.entryId, 'r_1');
      expect(restored.entry?.label, 'Family');
    });

    test('remove serializes with no entry payload', () {
      final operation = PendingRecitationOperation.remove('r_1');
      final restored = PendingRecitationOperation.fromJson(operation.toJson());

      expect(restored, isNotNull);
      expect(restored!.kind, RecitationOperationKind.remove);
      expect(restored.entryId, 'r_1');
      expect(restored.entry, isNull);
    });

    test('fromJson rejects malformed rows', () {
      expect(PendingRecitationOperation.fromJson(null), isNull);
      expect(PendingRecitationOperation.fromJson('garbage'), isNull);
      expect(
        PendingRecitationOperation.fromJson({'kind': 'add', 'entryId': 'r_1'}),
        isNull,
        reason: 'an add with no entry payload cannot be replayed',
      );
      expect(
        PendingRecitationOperation.fromJson({'id': 'x', 'kind': 'not-a-kind', 'entryId': 'r_1'}),
        isNull,
      );
    });
  });

  group('applyPendingRecitationOperation', () {
    test('add is idempotent — replaying it twice does not duplicate', () {
      final entry = RecitationEntry(
        id: 'r_1',
        label: 'Family',
        recitedAt: DateTime.utc(2026, 1, 1),
      );
      final operation = PendingRecitationOperation.add(entry);

      final once = applyPendingRecitationOperation(
        RecitationTrackerState.empty,
        operation,
      );
      final twice = applyPendingRecitationOperation(once, operation);

      expect(once.totalSessions, 1);
      expect(twice.totalSessions, 1);
    });

    test('remove is idempotent — replaying it after the id is gone is a no-op', () {
      final state = RecitationTrackerState.empty.setEntry(
        RecitationEntry(id: 'r_1', label: 'Family', recitedAt: DateTime.utc(2026, 1, 1)),
      );
      final operation = PendingRecitationOperation.remove('r_1');

      final once = applyPendingRecitationOperation(state, operation);
      final twice = applyPendingRecitationOperation(once, operation);

      expect(once.isEmpty, isTrue);
      expect(twice.isEmpty, isTrue);
    });

    test('applyPendingRecitationOperations applies a queue of add/remove in order', () {
      final entryA = RecitationEntry(id: 'a', label: 'Family', recitedAt: DateTime.utc(2026, 1, 1));
      final entryB = RecitationEntry(id: 'b', label: 'Personal', recitedAt: DateTime.utc(2026, 1, 2));

      final state = applyPendingRecitationOperations(RecitationTrackerState.empty, [
        PendingRecitationOperation.add(entryA),
        PendingRecitationOperation.add(entryB),
        PendingRecitationOperation.remove('a'),
      ]);

      expect(state.totalSessions, 1);
      expect(state.entries.containsKey('b'), isTrue);
      expect(state.entries.containsKey('a'), isFalse);
    });
  });
}
