import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/recitation_tracker_state.dart';

RecitationEntry _entry({
  required String id,
  String label = 'Family',
  required DateTime recitedAt,
  int surah = 2,
  int fromAyah = 1,
  int toAyah = 1,
}) {
  return RecitationEntry(
    id: id,
    label: label,
    recitedAt: recitedAt,
    surah: surah,
    fromAyah: fromAyah,
    toAyah: toAyah,
  );
}

void main() {
  group('RecitationEntry', () {
    test('versesRecited is the inclusive span of the range', () {
      final single = _entry(id: 'a', recitedAt: DateTime.utc(2026, 1, 1), fromAyah: 5, toAyah: 5);
      final range = _entry(id: 'b', recitedAt: DateTime.utc(2026, 1, 1), fromAyah: 1, toAyah: 20);

      expect(single.versesRecited, 1);
      expect(range.versesRecited, 20);
    });

    test('fromJson round trips via toJson', () {
      final entry = _entry(
        id: 'r_1',
        label: 'Family',
        recitedAt: DateTime.utc(2026, 1, 5, 9, 30),
        surah: 2,
        fromAyah: 1,
        toAyah: 20,
      );

      final restored = RecitationEntry.fromJson(entry.toJson());
      expect(restored, isNotNull);
      expect(restored!.id, 'r_1');
      expect(restored.label, 'Family');
      expect(restored.recitedAt, entry.recitedAt);
      expect(restored.surah, 2);
      expect(restored.fromAyah, 1);
      expect(restored.toAyah, 20);
    });

    test('fromJson rejects rows missing id, label, date or a valid range', () {
      expect(RecitationEntry.fromJson(null), isNull);
      expect(RecitationEntry.fromJson('garbage'), isNull);
      expect(
        RecitationEntry.fromJson({
          'label': 'Family',
          'recitedAt': '2026-01-01',
          'surah': 2,
          'fromAyah': 1,
          'toAyah': 1,
        }),
        isNull,
        reason: 'missing id',
      );
      expect(
        RecitationEntry.fromJson({
          'id': 'r_1',
          'recitedAt': '2026-01-01',
          'surah': 2,
          'fromAyah': 1,
          'toAyah': 1,
        }),
        isNull,
        reason: 'missing label',
      );
      expect(
        RecitationEntry.fromJson({
          'id': 'r_1',
          'label': 'Family',
          'recitedAt': 'nope',
          'surah': 2,
          'fromAyah': 1,
          'toAyah': 1,
        }),
        isNull,
        reason: 'unparseable date',
      );
      expect(
        RecitationEntry.fromJson({
          'id': 'r_1',
          'label': 'Family',
          'recitedAt': '2026-01-01',
          'fromAyah': 1,
          'toAyah': 1,
        }),
        isNull,
        reason: 'missing surah',
      );
      expect(
        RecitationEntry.fromJson({
          'id': 'r_1',
          'label': 'Family',
          'recitedAt': '2026-01-01',
          'surah': 2,
          'fromAyah': 20,
          'toAyah': 1,
        }),
        isNull,
        reason: 'toAyah before fromAyah',
      );
    });
  });

  group('RecitationTrackerState', () {
    test('empty state has no entries and zero totals', () {
      expect(RecitationTrackerState.empty.isEmpty, isTrue);
      expect(RecitationTrackerState.empty.totalSessions, 0);
      expect(RecitationTrackerState.empty.totalVersesRecited, 0);
      expect(RecitationTrackerState.empty.labels, isEmpty);
    });

    test('setEntry adds or overwrites by id; removeEntry deletes by id', () {
      final entry = _entry(id: 'r_1', recitedAt: DateTime.utc(2026, 1, 1), fromAyah: 1, toAyah: 1);
      final state = RecitationTrackerState.empty.setEntry(entry);
      expect(state.totalSessions, 1);
      expect(state.entries['r_1']!.label, 'Family');

      final overwritten = state.setEntry(
        _entry(id: 'r_1', label: 'Personal', recitedAt: entry.recitedAt, fromAyah: 1, toAyah: 5),
      );
      expect(overwritten.totalSessions, 1);
      expect(overwritten.entries['r_1']!.label, 'Personal');
      expect(overwritten.totalVersesRecited, 5);

      final removed = overwritten.removeEntry('r_1');
      expect(removed.isEmpty, isTrue);
      expect(identical(removed.removeEntry('r_1'), removed), isTrue);
    });

    test('plus unions by id and is safe to apply twice', () {
      final a = RecitationTrackerState.empty.setEntry(
        _entry(id: 'r_1', recitedAt: DateTime.utc(2026, 1, 1)),
      );
      final b = RecitationTrackerState.empty.setEntry(
        _entry(id: 'r_2', label: 'Personal', recitedAt: DateTime.utc(2026, 1, 2)),
      );

      final merged = a.plus(b);
      expect(merged.totalSessions, 2);

      final mergedAgain = merged.plus(b);
      expect(mergedAgain.totalSessions, 2, reason: 're-applying the same import must not duplicate');
    });

    test('toJson/fromJson round trip and drop corrupt rows', () {
      final state = RecitationTrackerState.empty
          .setEntry(_entry(id: 'r_1', recitedAt: DateTime.utc(2026, 1, 1), fromAyah: 1, toAyah: 10))
          .setEntry(_entry(id: 'r_2', label: 'Personal', recitedAt: DateTime.utc(2026, 1, 2)));

      final json = Map<String, dynamic>.from(state.toJson());
      json['r_3'] = {'id': 'r_3', 'label': ''};

      final restored = RecitationTrackerState.fromJson(json);
      expect(restored.totalSessions, 2);
      expect(restored.totalVersesRecited, 11);
      expect(RecitationTrackerState.fromJson('garbage').isEmpty, isTrue);
    });

    test('versesByLabel sums verse ranges, not tap counts', () {
      var state = RecitationTrackerState.empty
          .setEntry(_entry(id: 'a', recitedAt: DateTime.utc(2026, 1, 1), fromAyah: 1, toAyah: 5))
          .setEntry(_entry(id: 'b', recitedAt: DateTime.utc(2026, 1, 2), fromAyah: 6, toAyah: 10));
      state = state.setEntry(
        _entry(id: 'c', label: 'Personal', recitedAt: DateTime.utc(2026, 1, 3), fromAyah: 1, toAyah: 2),
      );

      expect(state.sessionsByLabel['Family'], 2);
      expect(state.versesByLabel['Family'], 10);
      expect(state.versesByLabel['Personal'], 2);
    });

    test('labels order by verses recited, most-recited first, ties alphabetical', () {
      var state = RecitationTrackerState.empty;
      state = state.setEntry(
        _entry(id: 'family', label: 'Family', recitedAt: DateTime.utc(2026, 1, 1), fromAyah: 1, toAyah: 50),
      );
      state = state
          .setEntry(_entry(id: 'zeta', label: 'Zeta', recitedAt: DateTime.utc(2026, 2, 1), fromAyah: 1, toAyah: 5))
          .setEntry(_entry(id: 'alpha', label: 'Alpha', recitedAt: DateTime.utc(2026, 2, 2), fromAyah: 1, toAyah: 5));

      expect(state.labels, ['Family', 'Alpha', 'Zeta']);
    });

    test('lastRecitedFor returns the most recent entry for that label only', () {
      final state = RecitationTrackerState.empty
          .setEntry(_entry(id: 'a', recitedAt: DateTime.utc(2026, 1, 1)))
          .setEntry(_entry(id: 'b', recitedAt: DateTime.utc(2026, 1, 10)))
          .setEntry(_entry(id: 'c', label: 'Personal', recitedAt: DateTime.utc(2026, 1, 20)));

      expect(state.lastRecitedFor('Family'), DateTime.utc(2026, 1, 10));
      expect(state.lastRecitedFor('Nonexistent'), isNull);
    });

    test('currentStreak counts consecutive local days ending today', () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty
          .setEntry(_entry(id: 'today', recitedAt: now))
          .setEntry(_entry(id: 'yesterday', recitedAt: now.subtract(const Duration(days: 1))))
          .setEntry(_entry(id: 'two_days_ago', recitedAt: now.subtract(const Duration(days: 2))));

      expect(state.currentStreak, 3);
    });

    test('currentStreak still counts when the most recent day is yesterday', () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty.setEntry(
        _entry(id: 'yesterday', recitedAt: now.subtract(const Duration(days: 1))),
      );

      expect(state.currentStreak, 1);
    });

    test('currentStreak is zero once a day is skipped', () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty.setEntry(
        _entry(id: 'two_days_ago', recitedAt: now.subtract(const Duration(days: 2))),
      );

      expect(state.currentStreak, 0);
    });

    test('longestStreak finds the best run even after it has since broken', () {
      final now = DateTime.now();
      var state = RecitationTrackerState.empty;
      for (final offset in [10, 11, 12]) {
        state = state.setEntry(
          _entry(id: 'run_$offset', recitedAt: now.subtract(Duration(days: offset))),
        );
      }
      state = state.setEntry(_entry(id: 'today', recitedAt: now));

      expect(state.longestStreak, 3);
      expect(state.currentStreak, 1);
    });

    test('sessionsSince/versesSince count entries on or after the given local moment', () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty
          .setEntry(_entry(id: 'recent', recitedAt: now, fromAyah: 1, toAyah: 9))
          .setEntry(
            _entry(id: 'old', recitedAt: now.subtract(const Duration(days: 30)), fromAyah: 1, toAyah: 1),
          );

      expect(state.sessionsSince(now.subtract(const Duration(days: 7))), 1);
      expect(state.versesSince(now.subtract(const Duration(days: 7))), 9);
      expect(state.sessionsSince(now.subtract(const Duration(days: 60))), 2);
      expect(state.versesSince(now.subtract(const Duration(days: 60))), 10);
    });

    test('dailyVerseCounts buckets verses by local calendar day within the window', () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty
          .setEntry(_entry(id: 'today_1', recitedAt: now, fromAyah: 1, toAyah: 5))
          .setEntry(_entry(id: 'today_2', label: 'Personal', recitedAt: now, fromAyah: 1, toAyah: 2))
          .setEntry(
            _entry(id: 'yesterday', recitedAt: now.subtract(const Duration(days: 1)), fromAyah: 1, toAyah: 3),
          )
          .setEntry(
            _entry(
              id: 'outside_window',
              recitedAt: now.subtract(const Duration(days: 10)),
              fromAyah: 1,
              toAyah: 100,
            ),
          );

      final counts = state.dailyVerseCounts(3);
      expect(counts.length, 3);
      final today = DateTime(now.year, now.month, now.day);
      expect(counts[today], 7);
      expect(counts[today.subtract(const Duration(days: 1))], 3);
      expect(counts[today.subtract(const Duration(days: 2))], 0);
    });
  });
}
