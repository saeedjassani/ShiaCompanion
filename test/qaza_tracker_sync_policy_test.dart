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
}
