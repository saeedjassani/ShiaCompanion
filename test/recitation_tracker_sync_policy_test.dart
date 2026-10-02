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
        surah: 2,
        fromAyah: 1,
        toAyah: 20,
      );
      final operation = PendingRecitationOperation.add(entry);
      final restored = PendingRecitationOperation.fromJson(operation.toJson());

      expect(restored, isNotNull);
      expect(restored!.kind, RecitationOperationKind.add);
      expect(restored.entryId, 'r_1');
      expect(restored.entry?.label, 'Family');
      expect(restored.entry?.versesRecited, 20);
    });

    test('remove serializes with no entry payload', () {
      final operation = PendingRecitationOperation.remove('r_1');
      final restored = PendingRecitationOperation.fromJson(operation.toJson());

      expect(restored, isNotNull);
      expect(restored!.kind, RecitationOperationKind.remove);
      expect(restored.entryId, 'r_1');
      expect(restored.entry, isNull);
    });

    test('addLabel serializes and restores the label name', () {
      final operation = PendingRecitationOperation.addLabel('Family');
      final restored = PendingRecitationOperation.fromJson(operation.toJson());

      expect(restored, isNotNull);
      expect(restored!.kind, RecitationOperationKind.addLabel);
      expect(restored.labelName, 'Family');
      expect(restored.entryId, isNull);
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
        surah: 2,
        fromAyah: 1,
        toAyah: 1,
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
        RecitationEntry(
          id: 'r_1',
          label: 'Family',
          recitedAt: DateTime.utc(2026, 1, 1),
          surah: 2,
          fromAyah: 1,
          toAyah: 1,
        ),
      );
      final operation = PendingRecitationOperation.remove('r_1');

      final once = applyPendingRecitationOperation(state, operation);
      final twice = applyPendingRecitationOperation(once, operation);

      expect(once.entries, isEmpty);
      expect(twice.entries, isEmpty);
    });

    test('addLabel is idempotent — replaying it twice registers the track once', () {
      final operation = PendingRecitationOperation.addLabel('Family');

      final once = applyPendingRecitationOperation(
        RecitationTrackerState.empty,
        operation,
      );
      final twice = applyPendingRecitationOperation(once, operation);

      expect(once.labels, ['Family']);
      expect(twice.labels, ['Family']);
    });

    test('applyPendingRecitationOperations applies a queue of add/remove in order', () {
      final entryA = RecitationEntry(
        id: 'a',
        label: 'Family',
        recitedAt: DateTime.utc(2026, 1, 1),
        surah: 2,
        fromAyah: 1,
        toAyah: 1,
      );
      final entryB = RecitationEntry(
        id: 'b',
        label: 'Personal',
        recitedAt: DateTime.utc(2026, 1, 2),
        surah: 2,
        fromAyah: 1,
        toAyah: 1,
      );

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

  group('recitationRemoteChangesFor', () {
    RecitationEntry entry(String id, {String label = 'Family', int toAyah = 7}) {
      return RecitationEntry(
        id: id,
        label: label,
        recitedAt: DateTime.utc(2026, 1, 1),
        surah: 1,
        fromAyah: 1,
        toAyah: toAyah,
      );
    }

    test('folds a whole visit into one set of writes', () {
      // Leaving a juz logs every surah in it at once.
      final changes = recitationRemoteChangesFor([
        for (var i = 0; i < 37; i++)
          PendingRecitationOperation.add(entry('auto_$i', label: 'Unlabeled')),
      ]);

      expect(changes.entries.length, 37);
      expect(changes.removedEntryIds, isEmpty);
      expect(changes.labels, isEmpty,
          reason: 'Unlabeled is reserved, never a stored track');
    });

    test('the last operation on an entry id wins, as replaying in order would',
        () {
      final readded = recitationRemoteChangesFor([
        PendingRecitationOperation.add(entry('a', toAyah: 3)),
        PendingRecitationOperation.remove('a'),
        PendingRecitationOperation.add(entry('a', toAyah: 7)),
      ]);
      expect(readded.entries['a']?.toAyah, 7);
      expect(readded.removedEntryIds, isEmpty);

      final removed = recitationRemoteChangesFor([
        PendingRecitationOperation.add(entry('a')),
        PendingRecitationOperation.remove('a'),
      ]);
      expect(removed.entries, isEmpty);
      expect(removed.removedEntryIds, {'a'});
    });

    test('registers the label of every written entry, like setEntry does', () {
      final ops = [
        PendingRecitationOperation.addLabel('Majlis'),
        PendingRecitationOperation.add(entry('a', label: 'Family')),
        PendingRecitationOperation.add(entry('b', label: 'Unlabeled')),
      ];
      final changes = recitationRemoteChangesFor(ops);

      expect(changes.labels, {'Majlis', 'Family'});
      expect(
        changes.labels,
        applyPendingRecitationOperations(RecitationTrackerState.empty, ops)
            .customLabels,
      );
    });

    test('a queue with nothing to write is empty', () {
      expect(recitationRemoteChangesFor(const []).isEmpty, isTrue);
      expect(
        recitationRemoteChangesFor([PendingRecitationOperation.remove('a')])
            .isEmpty,
        isFalse,
        reason: 'a removal is still a write',
      );
    });
  });
}
