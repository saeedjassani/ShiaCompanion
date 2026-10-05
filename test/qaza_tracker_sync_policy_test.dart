import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/qaza_tracker_state.dart';
import 'package:shia_companion/services/qaza_tracker_sync_policy.dart';

void main() {
  test('entry metadata includes Namaz e Ayat as a prayer', () {
    expect(QazaEntryType.ayat.key, 'namaz_e_ayat');
    expect(QazaEntryType.ayat.label, 'Namaz e Ayat');
    expect(QazaEntryType.ayat.isPrayer, isTrue);
    expect(qazaEntryTypeFromKey('namaz_e_ayat'), QazaEntryType.ayat);
  });

  test('state json round trips all qaza counts including Namaz e Ayat', () {
    final state = QazaTrackerState({
      QazaEntryType.fajr: const QazaEntryCount(remaining: 2, completed: 3),
      QazaEntryType.ayat: const QazaEntryCount(remaining: 4, completed: 5),
      QazaEntryType.fast: const QazaEntryCount(remaining: 6, completed: 7),
    });

    final decoded = QazaTrackerState.fromJson({
      ...state.toJson(),
      'unknown_future_key': {'remaining': 99, 'completed': 99},
    });

    expect(decoded.countFor(QazaEntryType.fajr).remaining, 2);
    expect(decoded.countFor(QazaEntryType.fajr).completed, 3);
    expect(decoded.countFor(QazaEntryType.ayat).remaining, 4);
    expect(decoded.countFor(QazaEntryType.ayat).completed, 5);
    expect(decoded.countFor(QazaEntryType.fast).remaining, 6);
    expect(decoded.countFor(QazaEntryType.fast).completed, 7);
    expect(decoded.totalRemaining, 12);
    expect(decoded.totalCompleted, 15);
  });

  test('mark completed moves one remaining count and does not over-complete',
      () {
    final initial = QazaTrackerState({
      QazaEntryType.dhuhr: const QazaEntryCount(remaining: 1, completed: 9),
    });

    final completedOnce = applyPendingQazaOperation(
      initial,
      PendingQazaOperation.markCompleted(
        id: 'complete-1',
        type: QazaEntryType.dhuhr,
      ),
    );
    final completedTwice = applyPendingQazaOperation(
      completedOnce,
      PendingQazaOperation.markCompleted(
        id: 'complete-2',
        type: QazaEntryType.dhuhr,
      ),
    );

    expect(completedOnce.countFor(QazaEntryType.dhuhr).remaining, 0);
    expect(completedOnce.countFor(QazaEntryType.dhuhr).completed, 10);
    expect(completedTwice.countFor(QazaEntryType.dhuhr).remaining, 0);
    expect(completedTwice.countFor(QazaEntryType.dhuhr).completed, 10);
  });

  test('undo completed moves one completed count and does not create debt', () {
    final initial = QazaTrackerState({
      QazaEntryType.asr: const QazaEntryCount(remaining: 1, completed: 1),
    });

    final undoneOnce = applyPendingQazaOperation(
      initial,
      PendingQazaOperation.undoCompleted(
        id: 'undo-1',
        type: QazaEntryType.asr,
      ),
    );
    final undoneTwice = applyPendingQazaOperation(
      undoneOnce,
      PendingQazaOperation.undoCompleted(
        id: 'undo-2',
        type: QazaEntryType.asr,
      ),
    );

    expect(undoneOnce.countFor(QazaEntryType.asr).remaining, 2);
    expect(undoneOnce.countFor(QazaEntryType.asr).completed, 0);
    expect(undoneTwice.countFor(QazaEntryType.asr).remaining, 2);
    expect(undoneTwice.countFor(QazaEntryType.asr).completed, 0);
  });

  test('stale duplicate complete operations cannot inflate synced counts', () {
    final remote = QazaTrackerState({
      QazaEntryType.maghrib: const QazaEntryCount(remaining: 1, completed: 0),
    });

    final reconciled = applyPendingQazaOperations(remote, [
      PendingQazaOperation.markCompleted(
        id: 'device-a-complete',
        type: QazaEntryType.maghrib,
      ),
      PendingQazaOperation.markCompleted(
        id: 'device-b-complete',
        type: QazaEntryType.maghrib,
      ),
    ]);

    expect(reconciled.countFor(QazaEntryType.maghrib).remaining, 0);
    expect(reconciled.countFor(QazaEntryType.maghrib).completed, 1);
  });

  test('operation serialization preserves order and exact set counts', () {
    final operations = [
      PendingQazaOperation.addMissed(
        id: 'add',
        type: QazaEntryType.isha,
      ),
      PendingQazaOperation.setCount(
        id: 'set',
        type: QazaEntryType.ayat,
        count: const QazaEntryCount(remaining: 3, completed: 2),
      ),
    ];

    final decoded = operations
        .map((operation) => PendingQazaOperation.fromJson(operation.toJson()))
        .nonNulls
        .toList();
    final state = applyPendingQazaOperations(QazaTrackerState.empty, decoded);

    expect(decoded.map((operation) => operation.id), ['add', 'set']);
    expect(state.countFor(QazaEntryType.isha).remaining, 1);
    expect(state.countFor(QazaEntryType.ayat).remaining, 3);
    expect(state.countFor(QazaEntryType.ayat).completed, 2);
  });

  group('remote document', () {
    QazaTrackerState twentyFiveOfEach() => QazaTrackerState({
          for (final type in qazaDailyPrayers)
            type: const QazaEntryCount(remaining: 25),
        });

    List<PendingQazaOperation> fullDay(String prefix) => [
          for (final type in qazaDailyPrayers)
            PendingQazaOperation.markCompleted(
              id: '$prefix-${type.key}',
              type: type,
            ),
        ];

    test('a full day applied twice still only counts once', () {
      final doc = QazaRemoteDoc(state: twentyFiveOfEach());
      final operations = fullDay('day');

      final once = applyQazaOperationsToRemote(doc, operations);
      // A replay, an overlapping flush or a retry after a crash.
      final twice = applyQazaOperationsToRemote(once, operations);
      final partlyAgain = applyQazaOperationsToRemote(
        twice,
        operations.sublist(1, 4),
      );

      for (final result in [once, twice, partlyAgain]) {
        for (final type in qazaDailyPrayers) {
          expect(result.state.countFor(type).remaining, 24, reason: '$type');
          expect(result.state.countFor(type).completed, 1, reason: '$type');
        }
      }
    });

    test('two separate full days count twice', () {
      final doc = applyQazaOperationsToRemote(
        applyQazaOperationsToRemote(
          QazaRemoteDoc(state: twentyFiveOfEach()),
          fullDay('first'),
        ),
        fullDay('second'),
      );

      for (final type in qazaDailyPrayers) {
        expect(doc.state.countFor(type).remaining, 23);
        expect(doc.state.countFor(type).completed, 2);
      }
    });

    test('visible state does not double count applied pending operations', () {
      final operations = fullDay('day');
      final remote = applyQazaOperationsToRemote(
        QazaRemoteDoc(state: twentyFiveOfEach()),
        operations.sublist(0, 3),
      );

      // All five still queued locally; three already reached the server.
      final visible = visibleQazaState(remote, operations);

      for (final type in qazaDailyPrayers) {
        expect(visible.countFor(type).remaining, 24, reason: '$type');
        expect(visible.countFor(type).completed, 1, reason: '$type');
      }
    });

    test('round trips through Firestore data and trims old ids', () {
      var doc = QazaRemoteDoc(state: QazaTrackerState.empty);
      for (var i = 0; i < qazaAppliedOperationIdLimit + 5; i++) {
        doc = applyQazaOperationsToRemote(doc, [
          PendingQazaOperation.addMissed(id: 'op-$i', type: QazaEntryType.fast),
        ]);
      }
      final decoded = QazaRemoteDoc.fromData(doc.toData());

      expect(decoded.state.countFor(QazaEntryType.fast).remaining,
          qazaAppliedOperationIdLimit + 5);
      expect(decoded.appliedOperationIds.length, qazaAppliedOperationIdLimit);
      expect(
          decoded.hasApplied('op-${qazaAppliedOperationIdLimit + 4}'), isTrue);
      expect(decoded.hasApplied('op-0'), isFalse);
    });

    test('reads documents written before applied ids existed', () {
      final doc = QazaRemoteDoc.fromData({
        'version': 1,
        'entries': {
          'asr': {'remaining': 3, 'completed': 1},
        },
      });

      expect(doc.appliedOperationIds, isEmpty);
      expect(doc.state.countFor(QazaEntryType.asr).remaining, 3);
    });

    test('add counts stacks on the current counts', () {
      final operation = PendingQazaOperation.addCounts(
        id: 'estimate',
        type: QazaEntryType.fajr,
        count: const QazaEntryCount(remaining: 354),
      );
      final decoded = PendingQazaOperation.fromJson(operation.toJson())!;
      final state = applyPendingQazaOperation(
        QazaTrackerState({
          QazaEntryType.fajr: const QazaEntryCount(remaining: 2, completed: 7),
        }),
        decoded,
      );

      expect(decoded.kind, QazaOperationKind.addCounts);
      expect(state.countFor(QazaEntryType.fajr).remaining, 356);
      expect(state.countFor(QazaEntryType.fajr).completed, 7);
    });
  });
}
