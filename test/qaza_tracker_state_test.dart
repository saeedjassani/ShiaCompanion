import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/qaza_tracker_state.dart';

void main() {
  test('entry type keys and labels are distinct and round trip via key', () {
    for (final type in QazaEntryType.values) {
      expect(qazaEntryTypeFromKey(type.key), type);
    }
    expect(
      QazaEntryType.values.map((t) => t.key).toSet(),
      hasLength(QazaEntryType.values.length),
    );
    expect(qazaEntryTypeFromKey('not-a-real-key'), isNull);
  });

  test('fast is the only non-prayer entry type', () {
    expect(QazaEntryType.fast.isPrayer, isFalse);
    for (final type in QazaEntryType.values.where((t) => t != QazaEntryType.fast)) {
      expect(type.isPrayer, isTrue, reason: type.name);
    }
  });

  group('QazaEntryCount', () {
    test('copyWith clamps negative values to zero', () {
      const count = QazaEntryCount(remaining: 3, completed: 2);
      expect(count.copyWith(remaining: -5).remaining, 0);
      expect(count.copyWith(completed: -1).completed, 0);
      expect(count.copyWith(remaining: 7).completed, 2);
    });

    test('plus adds both fields without clamping', () {
      const a = QazaEntryCount(remaining: 3, completed: 1);
      const b = QazaEntryCount(remaining: 2, completed: 4);
      final result = a.plus(b);
      expect(result.remaining, 5);
      expect(result.completed, 5);
    });

    test('applyDelta clamps below zero and reflects total/isEmpty', () {
      const count = QazaEntryCount(remaining: 1, completed: 0);
      final result = count.applyDelta(
        const QazaEntryDelta(remaining: -5, completed: 3),
      );
      expect(result.remaining, 0);
      expect(result.completed, 3);
      expect(result.total, 3);
      expect(result.isEmpty, isFalse);
      expect(QazaEntryCount.zero.isEmpty, isTrue);
    });

    test('toJson/fromJson round trip and fromJson tolerates bad input', () {
      const count = QazaEntryCount(remaining: 4, completed: 6);
      final restored = QazaEntryCount.fromJson(count.toJson());
      expect(restored.remaining, 4);
      expect(restored.completed, 6);

      expect(QazaEntryCount.fromJson(null), QazaEntryCount.zero);
      expect(QazaEntryCount.fromJson('garbage'), QazaEntryCount.zero);
      expect(
        QazaEntryCount.fromJson({'remaining': '9', 'completed': -3}).remaining,
        9,
      );
      expect(
        QazaEntryCount.fromJson({'remaining': '9', 'completed': -3}).completed,
        0,
      );
    });
  });

  group('QazaEntryDelta', () {
    test('plus, minus, and inverse compose as expected', () {
      const a = QazaEntryDelta(remaining: 5, completed: -2);
      const b = QazaEntryDelta(remaining: 1, completed: 3);

      final sum = a.plus(b);
      expect(sum.remaining, 6);
      expect(sum.completed, 1);

      final diff = a.minus(b);
      expect(diff.remaining, 4);
      expect(diff.completed, -5);

      final inverse = a.inverse();
      expect(inverse.remaining, -5);
      expect(inverse.completed, 2);

      expect(QazaEntryDelta.zero.isZero, isTrue);
      expect(a.isZero, isFalse);
    });

    test('toJson/fromJson round trip signed values', () {
      const delta = QazaEntryDelta(remaining: -3, completed: 4);
      final restored = QazaEntryDelta.fromJson(delta.toJson());
      expect(restored.remaining, -3);
      expect(restored.completed, 4);
      expect(QazaEntryDelta.fromJson(null), QazaEntryDelta.zero);
    });
  });

  group('QazaTrackerDelta', () {
    test('constructor drops zero deltas but keeps them accessible as zero', () {
      final delta = QazaTrackerDelta({
        QazaEntryType.fajr: const QazaEntryDelta(remaining: 1),
        QazaEntryType.asr: QazaEntryDelta.zero,
      });

      expect(delta.deltas.containsKey(QazaEntryType.asr), isFalse);
      expect(delta.deltaFor(QazaEntryType.asr), QazaEntryDelta.zero);
      expect(delta.deltaFor(QazaEntryType.fajr).remaining, 1);
      expect(delta.isZero, isFalse);
      expect(QazaTrackerDelta.zero.isZero, isTrue);
    });

    test('single builds a one-entry delta', () {
      final delta = QazaTrackerDelta.single(
        QazaEntryType.isha,
        const QazaEntryDelta(completed: 2),
      );
      expect(delta.deltaFor(QazaEntryType.isha).completed, 2);
      expect(delta.deltaFor(QazaEntryType.fajr), QazaEntryDelta.zero);
    });

    test('between computes the per-type diff from previous to next', () {
      final previous = QazaTrackerState({
        QazaEntryType.fajr: const QazaEntryCount(remaining: 5, completed: 0),
      });
      final next = previous.setCount(
        QazaEntryType.fajr,
        const QazaEntryCount(remaining: 3, completed: 2),
      );

      final delta = QazaTrackerDelta.between(previous, next);
      expect(delta.deltaFor(QazaEntryType.fajr).remaining, -2);
      expect(delta.deltaFor(QazaEntryType.fajr).completed, 2);
      final reconstructed = previous.applyDelta(delta).countFor(QazaEntryType.fajr);
      expect(reconstructed.remaining, next.countFor(QazaEntryType.fajr).remaining);
      expect(reconstructed.completed, next.countFor(QazaEntryType.fajr).completed);
    });

    test('plus and minus combine deltas per type', () {
      final a = QazaTrackerDelta.single(
        QazaEntryType.dhuhr,
        const QazaEntryDelta(remaining: 2, completed: 1),
      );
      final b = QazaTrackerDelta.single(
        QazaEntryType.dhuhr,
        const QazaEntryDelta(remaining: 1, completed: 1),
      );

      final sum = a.plus(b).deltaFor(QazaEntryType.dhuhr);
      expect(sum.remaining, 3);
      expect(sum.completed, 2);

      final diff = a.minus(b).deltaFor(QazaEntryType.dhuhr);
      expect(diff.remaining, 1);
      expect(diff.completed, 0);
    });

    test('toJson/fromJson round trip and ignore unknown keys', () {
      final delta = QazaTrackerDelta({
        QazaEntryType.fast: const QazaEntryDelta(remaining: 2, completed: 1),
      });
      final json = Map<String, dynamic>.from(delta.toJson())
        ..['unknown_key'] = {'remaining': 9, 'completed': 9};

      final restored = QazaTrackerDelta.fromJson(json);
      expect(restored.deltaFor(QazaEntryType.fast).remaining, 2);
      expect(restored.deltas.length, 1);
      expect(QazaTrackerDelta.fromJson('garbage').isZero, isTrue);
    });
  });

  group('QazaTrackerState', () {
    test('empty state has zero counts for every type and is empty', () {
      expect(QazaTrackerState.empty.isEmpty, isTrue);
      for (final type in QazaEntryType.values) {
        expect(QazaTrackerState.empty.countFor(type), QazaEntryCount.zero);
      }
    });

    test('setCount updates a single type and leaves others untouched', () {
      final state = QazaTrackerState.empty.setCount(
        QazaEntryType.maghrib,
        const QazaEntryCount(remaining: 10, completed: 5),
      );

      expect(state.countFor(QazaEntryType.maghrib).remaining, 10);
      expect(state.countFor(QazaEntryType.fajr), QazaEntryCount.zero);
      expect(state.isEmpty, isFalse);
      expect(state.totalRemaining, 10);
      expect(state.totalCompleted, 5);
    });

    test('plus sums counts across all entry types', () {
      final a = QazaTrackerState.empty.setCount(
        QazaEntryType.asr,
        const QazaEntryCount(remaining: 2, completed: 1),
      );
      final b = QazaTrackerState.empty.setCount(
        QazaEntryType.asr,
        const QazaEntryCount(remaining: 1, completed: 3),
      );

      final sum = a.plus(b);
      expect(sum.countFor(QazaEntryType.asr).remaining, 3);
      expect(sum.countFor(QazaEntryType.asr).completed, 4);
    });

    test('applyDelta is a no-op for a zero delta and clamps below zero', () {
      final state = QazaTrackerState.empty.setCount(
        QazaEntryType.fast,
        const QazaEntryCount(remaining: 1, completed: 0),
      );

      expect(identical(state.applyDelta(QazaTrackerDelta.zero), state), isTrue);

      final applied = state.applyDelta(
        QazaTrackerDelta.single(
          QazaEntryType.fast,
          const QazaEntryDelta(remaining: -10, completed: 4),
        ),
      );
      expect(applied.countFor(QazaEntryType.fast).remaining, 0);
      expect(applied.countFor(QazaEntryType.fast).completed, 4);
    });

    test('toJson/fromJson round trip and ignore unknown keys', () {
      final state = QazaTrackerState.empty
          .setCount(QazaEntryType.other, const QazaEntryCount(remaining: 6, completed: 2));
      final json = Map<String, dynamic>.from(state.toJson())
        ..['unknown_key'] = {'remaining': 1, 'completed': 1};

      final restored = QazaTrackerState.fromJson(json);
      expect(restored.countFor(QazaEntryType.other).remaining, 6);
      expect(restored.countFor(QazaEntryType.other).completed, 2);
      expect(QazaTrackerState.fromJson('garbage').isEmpty, isTrue);
    });
  });
}
