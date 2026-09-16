import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/recitation_tracker_state.dart';

void main() {
  group('RecitationEntry', () {
    test('fromJson round trips via toJson', () {
      final entry = RecitationEntry(
        id: 'r_1',
        label: 'Family',
        recitedAt: DateTime.utc(2026, 1, 5, 9, 30),
      );

      final restored = RecitationEntry.fromJson(entry.toJson());
      expect(restored, isNotNull);
      expect(restored!.id, 'r_1');
      expect(restored.label, 'Family');
      expect(restored.recitedAt, entry.recitedAt);
    });

    test('fromJson rejects rows missing id, label or a parseable date', () {
      expect(RecitationEntry.fromJson(null), isNull);
      expect(RecitationEntry.fromJson('garbage'), isNull);
      expect(
        RecitationEntry.fromJson({'label': 'Family', 'recitedAt': '2026-01-01'}),
        isNull,
      );
      expect(
        RecitationEntry.fromJson({'id': 'r_1', 'recitedAt': '2026-01-01'}),
        isNull,
      );
      expect(
        RecitationEntry.fromJson({'id': 'r_1', 'label': 'Family', 'recitedAt': 'nope'}),
        isNull,
      );
    });
  });

  group('RecitationTrackerState', () {
    test('empty state has no entries and zero totals', () {
      expect(RecitationTrackerState.empty.isEmpty, isTrue);
      expect(RecitationTrackerState.empty.totalSessions, 0);
      expect(RecitationTrackerState.empty.labels, isEmpty);
    });

    test('setEntry adds or overwrites by id; removeEntry deletes by id', () {
      final entry = RecitationEntry(
        id: 'r_1',
        label: 'Family',
        recitedAt: DateTime.utc(2026, 1, 1),
      );
      final state = RecitationTrackerState.empty.setEntry(entry);
      expect(state.totalSessions, 1);
      expect(state.entries['r_1']!.label, 'Family');

      final overwritten = state.setEntry(
        RecitationEntry(id: 'r_1', label: 'Personal', recitedAt: entry.recitedAt),
      );
      expect(overwritten.totalSessions, 1);
      expect(overwritten.entries['r_1']!.label, 'Personal');

      final removed = overwritten.removeEntry('r_1');
      expect(removed.isEmpty, isTrue);
      expect(identical(removed.removeEntry('r_1'), removed), isTrue);
    });

    test('plus unions by id and is safe to apply twice', () {
      final a = RecitationTrackerState.empty.setEntry(
        RecitationEntry(id: 'r_1', label: 'Family', recitedAt: DateTime.utc(2026, 1, 1)),
      );
      final b = RecitationTrackerState.empty.setEntry(
        RecitationEntry(id: 'r_2', label: 'Personal', recitedAt: DateTime.utc(2026, 1, 2)),
      );

      final merged = a.plus(b);
      expect(merged.totalSessions, 2);

      final mergedAgain = merged.plus(b);
      expect(mergedAgain.totalSessions, 2, reason: 're-applying the same import must not duplicate');
    });

    test('toJson/fromJson round trip and drop corrupt rows', () {
      final state = RecitationTrackerState.empty
          .setEntry(RecitationEntry(id: 'r_1', label: 'Family', recitedAt: DateTime.utc(2026, 1, 1)))
          .setEntry(RecitationEntry(id: 'r_2', label: 'Personal', recitedAt: DateTime.utc(2026, 1, 2)));

      final json = Map<String, dynamic>.from(state.toJson());
      json['r_3'] = {'id': 'r_3', 'label': ''};

      final restored = RecitationTrackerState.fromJson(json);
      expect(restored.totalSessions, 2);
      expect(RecitationTrackerState.fromJson('garbage').isEmpty, isTrue);
    });

    test('countsByLabel and labels order by usage, ties broken alphabetically', () {
      var state = RecitationTrackerState.empty;
      for (var i = 0; i < 3; i++) {
        state = state.setEntry(RecitationEntry(
          id: 'family_$i',
          label: 'Family',
          recitedAt: DateTime.utc(2026, 1, 1 + i),
        ));
      }
      state = state
          .setEntry(RecitationEntry(id: 'zeta_1', label: 'Zeta', recitedAt: DateTime.utc(2026, 2, 1)))
          .setEntry(RecitationEntry(id: 'alpha_1', label: 'Alpha', recitedAt: DateTime.utc(2026, 2, 2)));

      expect(state.countsByLabel['Family'], 3);
      expect(state.labels, ['Family', 'Alpha', 'Zeta']);
    });

    test('lastRecitedFor returns the most recent entry for that label only', () {
      final state = RecitationTrackerState.empty
          .setEntry(RecitationEntry(id: 'a', label: 'Family', recitedAt: DateTime.utc(2026, 1, 1)))
          .setEntry(RecitationEntry(id: 'b', label: 'Family', recitedAt: DateTime.utc(2026, 1, 10)))
          .setEntry(RecitationEntry(id: 'c', label: 'Personal', recitedAt: DateTime.utc(2026, 1, 20)));

      expect(state.lastRecitedFor('Family'), DateTime.utc(2026, 1, 10));
      expect(state.lastRecitedFor('Nonexistent'), isNull);
    });

    test('currentStreak counts consecutive local days ending today', () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty
          .setEntry(RecitationEntry(id: 'today', label: 'Family', recitedAt: now))
          .setEntry(
            RecitationEntry(
              id: 'yesterday',
              label: 'Family',
              recitedAt: now.subtract(const Duration(days: 1)),
            ),
          )
          .setEntry(
            RecitationEntry(
              id: 'two_days_ago',
              label: 'Family',
              recitedAt: now.subtract(const Duration(days: 2)),
            ),
          );

      expect(state.currentStreak, 3);
    });

    test('currentStreak still counts when the most recent day is yesterday', () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty.setEntry(
        RecitationEntry(
          id: 'yesterday',
          label: 'Family',
          recitedAt: now.subtract(const Duration(days: 1)),
        ),
      );

      expect(state.currentStreak, 1);
    });

    test('currentStreak is zero once a day is skipped', () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty.setEntry(
        RecitationEntry(
          id: 'two_days_ago',
          label: 'Family',
          recitedAt: now.subtract(const Duration(days: 2)),
        ),
      );

      expect(state.currentStreak, 0);
    });

    test('longestStreak finds the best run even after it has since broken', () {
      final now = DateTime.now();
      var state = RecitationTrackerState.empty;
      // A 3-day run 10-12 days ago, then a gap, then just today.
      for (final offset in [10, 11, 12]) {
        state = state.setEntry(RecitationEntry(
          id: 'run_$offset',
          label: 'Family',
          recitedAt: now.subtract(Duration(days: offset)),
        ));
      }
      state = state.setEntry(
        RecitationEntry(id: 'today', label: 'Family', recitedAt: now),
      );

      expect(state.longestStreak, 3);
      expect(state.currentStreak, 1);
    });

    test('countSince counts entries on or after the given local moment', () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty
          .setEntry(RecitationEntry(id: 'recent', label: 'Family', recitedAt: now))
          .setEntry(
            RecitationEntry(
              id: 'old',
              label: 'Family',
              recitedAt: now.subtract(const Duration(days: 30)),
            ),
          );

      expect(state.countSince(now.subtract(const Duration(days: 7))), 1);
      expect(state.countSince(now.subtract(const Duration(days: 60))), 2);
    });

    test('dailyCounts buckets entries by local calendar day within the window', () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty
          .setEntry(RecitationEntry(id: 'today_1', label: 'Family', recitedAt: now))
          .setEntry(RecitationEntry(id: 'today_2', label: 'Personal', recitedAt: now))
          .setEntry(
            RecitationEntry(
              id: 'yesterday',
              label: 'Family',
              recitedAt: now.subtract(const Duration(days: 1)),
            ),
          )
          .setEntry(
            RecitationEntry(
              id: 'outside_window',
              label: 'Family',
              recitedAt: now.subtract(const Duration(days: 10)),
            ),
          );

      final counts = state.dailyCounts(3);
      expect(counts.length, 3);
      final today = DateTime(now.year, now.month, now.day);
      expect(counts[today], 2);
      expect(counts[today.subtract(const Duration(days: 1))], 1);
      expect(counts[today.subtract(const Duration(days: 2))], 0);
    });
  });
}
