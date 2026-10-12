import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/activity_stats.dart';
import 'package:shia_companion/models/recitation_tracker_state.dart';
import 'package:shia_companion/utils/quran_index.dart';

RecitationEntry _entry({
  required String id,
  String label = 'Family',
  required DateTime recitedAt,
  int surah = 2,
  int fromAyah = 1,
  int toAyah = 1,
  bool readInJuz = false,
}) {
  return RecitationEntry(
    id: id,
    label: label,
    recitedAt: recitedAt,
    surah: surah,
    fromAyah: fromAyah,
    toAyah: toAyah,
    readInJuz: readInJuz,
  );
}

void main() {
  group('RecitationEntry', () {
    test('versesRecited is the inclusive span of the range', () {
      final single = _entry(
          id: 'a', recitedAt: DateTime.utc(2026, 1, 1), fromAyah: 5, toAyah: 5);
      final range = _entry(
          id: 'b',
          recitedAt: DateTime.utc(2026, 1, 1),
          fromAyah: 1,
          toAyah: 20);

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
      final entry = _entry(
          id: 'r_1',
          recitedAt: DateTime.utc(2026, 1, 1),
          fromAyah: 1,
          toAyah: 1);
      final state = RecitationTrackerState.empty.setEntry(entry);
      expect(state.totalSessions, 1);
      expect(state.entries['r_1']!.label, 'Family');

      final overwritten = state.setEntry(
        _entry(
            id: 'r_1',
            label: 'Personal',
            recitedAt: entry.recitedAt,
            fromAyah: 1,
            toAyah: 5),
      );
      expect(overwritten.totalSessions, 1);
      expect(overwritten.entries['r_1']!.label, 'Personal');
      expect(overwritten.totalVersesRecited, 5);

      final removed = overwritten.removeEntry('r_1');
      expect(removed.entries, isEmpty);
      expect(
        removed.customLabels,
        {'Family', 'Personal'},
        reason: 'a label stays registered as a track after its entries are '
            'removed, so it can still be resumed from empty',
      );
      expect(identical(removed.removeEntry('r_1'), removed), isTrue);
    });

    test('plus unions by id and is safe to apply twice', () {
      final a = RecitationTrackerState.empty.setEntry(
        _entry(id: 'r_1', recitedAt: DateTime.utc(2026, 1, 1)),
      );
      final b = RecitationTrackerState.empty.setEntry(
        _entry(
            id: 'r_2', label: 'Personal', recitedAt: DateTime.utc(2026, 1, 2)),
      );

      final merged = a.plus(b);
      expect(merged.totalSessions, 2);

      final mergedAgain = merged.plus(b);
      expect(mergedAgain.totalSessions, 2,
          reason: 're-applying the same import must not duplicate');
    });

    test('toJson/fromJson round trip and drop corrupt rows', () {
      final state = RecitationTrackerState.empty
          .setEntry(_entry(
              id: 'r_1',
              recitedAt: DateTime.utc(2026, 1, 1),
              fromAyah: 1,
              toAyah: 10))
          .setEntry(_entry(
              id: 'r_2',
              label: 'Personal',
              recitedAt: DateTime.utc(2026, 1, 2)))
          .addCustomLabel('Majlis');

      final json = Map<String, dynamic>.from(state.toJson());
      (json['entries'] as Map)['r_3'] = {'id': 'r_3', 'label': ''};

      final restored = RecitationTrackerState.fromJson(json);
      expect(restored.totalSessions, 2);
      expect(restored.totalVersesRecited, 11);
      expect(restored.customLabels, {'Family', 'Personal', 'Majlis'});
      expect(RecitationTrackerState.fromJson('garbage').isEmpty, isTrue);
    });

    test('addCustomLabel registers a track with no history, idempotently', () {
      final state = RecitationTrackerState.empty.addCustomLabel('Family');
      expect(state.isEmpty, isFalse);
      expect(state.labels, ['Family']);
      expect(state.resumePositionFor('Family'), isNull);

      final again = state.addCustomLabel('Family');
      expect(identical(again, state), isTrue);

      expect(
        identical(state.addCustomLabel(unlabeledRecitationLabel), state),
        isTrue,
        reason: 'the reserved bucket cannot become a custom label',
      );
    });

    test(
        'setEntry registers a brand new label automatically, but not Unlabeled',
        () {
      final withCustom = RecitationTrackerState.empty.setEntry(
        _entry(id: 'a', label: 'Tahajjud', recitedAt: DateTime.utc(2026, 1, 1)),
      );
      expect(withCustom.customLabels, {'Tahajjud'});

      final withUnlabeled = RecitationTrackerState.empty.setEntry(
        _entry(
            id: 'b',
            label: unlabeledRecitationLabel,
            recitedAt: DateTime.utc(2026, 1, 1)),
      );
      expect(withUnlabeled.customLabels, isEmpty);
      expect(withUnlabeled.labels, isEmpty);
    });

    test('plus unions custom labels too', () {
      final a = RecitationTrackerState.empty.addCustomLabel('Family');
      final b = RecitationTrackerState.empty.addCustomLabel('Personal');
      expect(a.plus(b).customLabels, {'Family', 'Personal'});
    });

    test('versesByLabel sums verse ranges, not tap counts', () {
      var state = RecitationTrackerState.empty
          .setEntry(_entry(
              id: 'a',
              recitedAt: DateTime.utc(2026, 1, 1),
              fromAyah: 1,
              toAyah: 5))
          .setEntry(_entry(
              id: 'b',
              recitedAt: DateTime.utc(2026, 1, 2),
              fromAyah: 6,
              toAyah: 10));
      state = state.setEntry(
        _entry(
            id: 'c',
            label: 'Personal',
            recitedAt: DateTime.utc(2026, 1, 3),
            fromAyah: 1,
            toAyah: 2),
      );

      expect(state.sessionsByLabel['Family'], 2);
      expect(state.versesByLabel['Family'], 10);
      expect(state.versesByLabel['Personal'], 2);
    });

    test(
        'labels order by verses recited, most-recited first, ties alphabetical',
        () {
      var state = RecitationTrackerState.empty;
      state = state.setEntry(
        _entry(
            id: 'family',
            label: 'Family',
            recitedAt: DateTime.utc(2026, 1, 1),
            fromAyah: 1,
            toAyah: 50),
      );
      state = state
          .setEntry(_entry(
              id: 'zeta',
              label: 'Zeta',
              recitedAt: DateTime.utc(2026, 2, 1),
              fromAyah: 1,
              toAyah: 5))
          .setEntry(_entry(
              id: 'alpha',
              label: 'Alpha',
              recitedAt: DateTime.utc(2026, 2, 2),
              fromAyah: 1,
              toAyah: 5));

      expect(state.labels, ['Family', 'Alpha', 'Zeta']);
    });

    test('lastRecitedFor returns the most recent entry for that label only',
        () {
      final state = RecitationTrackerState.empty
          .setEntry(_entry(id: 'a', recitedAt: DateTime.utc(2026, 1, 1)))
          .setEntry(_entry(id: 'b', recitedAt: DateTime.utc(2026, 1, 10)))
          .setEntry(_entry(
              id: 'c',
              label: 'Personal',
              recitedAt: DateTime.utc(2026, 1, 20)));

      expect(state.lastRecitedFor('Family'), DateTime.utc(2026, 1, 10));
      expect(state.lastRecitedFor('Nonexistent'), isNull);
    });

    test('currentStreak counts consecutive local days ending today', () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty
          .setEntry(_entry(id: 'today', recitedAt: now))
          .setEntry(_entry(
              id: 'yesterday',
              recitedAt: now.subtract(const Duration(days: 1))))
          .setEntry(_entry(
              id: 'two_days_ago',
              recitedAt: now.subtract(const Duration(days: 2))));

      expect(state.currentStreak, 3);
    });

    test('currentStreak still counts when the most recent day is yesterday',
        () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty.setEntry(
        _entry(
            id: 'yesterday', recitedAt: now.subtract(const Duration(days: 1))),
      );

      expect(state.currentStreak, 1);
    });

    test('currentStreak is zero once a day is skipped', () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty.setEntry(
        _entry(
            id: 'two_days_ago',
            recitedAt: now.subtract(const Duration(days: 2))),
      );

      expect(state.currentStreak, 0);
    });

    test('longestStreak finds the best run even after it has since broken', () {
      final now = DateTime.now();
      var state = RecitationTrackerState.empty;
      for (final offset in [10, 11, 12]) {
        state = state.setEntry(
          _entry(
              id: 'run_$offset',
              recitedAt: now.subtract(Duration(days: offset))),
        );
      }
      state = state.setEntry(_entry(id: 'today', recitedAt: now));

      expect(state.longestStreak, 3);
      expect(state.currentStreak, 1);
    });

    test(
        'sessionsSince/versesSince count entries on or after the given local moment',
        () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty
          .setEntry(
              _entry(id: 'recent', recitedAt: now, fromAyah: 1, toAyah: 9))
          .setEntry(
            _entry(
                id: 'old',
                recitedAt: now.subtract(const Duration(days: 30)),
                fromAyah: 1,
                toAyah: 1),
          );

      expect(state.sessionsSince(now.subtract(const Duration(days: 7))), 1);
      expect(state.versesSince(now.subtract(const Duration(days: 7))), 9);
      expect(state.sessionsSince(now.subtract(const Duration(days: 60))), 2);
      expect(state.versesSince(now.subtract(const Duration(days: 60))), 10);
    });

    test('resumePositionFor points at the tail of the most recent entry', () {
      final state = RecitationTrackerState.empty
          .setEntry(_entry(
              id: 'a',
              recitedAt: DateTime.utc(2026, 1, 1),
              surah: 2,
              fromAyah: 1,
              toAyah: 20))
          .setEntry(_entry(
              id: 'b',
              recitedAt: DateTime.utc(2026, 1, 10),
              surah: 3,
              fromAyah: 5,
              toAyah: 9));

      expect(state.resumePositionFor('Family'), const VerseKey(3, 9));
      expect(state.resumePositionFor('Nonexistent'), isNull);
    });

    test('resumePositionFor moves on to the next surah once one is finished',
        () {
      final fatiha = RecitationTrackerState.empty.setEntry(_entry(
          id: 'a',
          recitedAt: DateTime.utc(2026, 1, 1),
          surah: 1,
          fromAyah: 1,
          toAyah: 7));
      expect(fatiha.resumePositionFor('Family'), const VerseKey(2, 1));

      final nas = RecitationTrackerState.empty.setEntry(_entry(
          id: 'b',
          recitedAt: DateTime.utc(2026, 1, 1),
          surah: 114,
          fromAyah: 1,
          toAyah: 6));
      expect(nas.resumePositionFor('Family'), const VerseKey(1, 1));
    });

    test('resumeTargetFor uses the track setting, Unlabeled the last read', () {
      final state = RecitationTrackerState(
        {
          'a': _entry(id: 'a', recitedAt: DateTime.utc(2026, 1, 1), toAyah: 5),
          'u': _entry(
            id: 'u',
            label: unlabeledRecitationLabel,
            recitedAt: DateTime.utc(2026, 1, 2),
            surah: 4,
            toAyah: 30,
            readInJuz: true,
          ),
        },
        {'Family'},
        {'Family': const RecitationTrackSettings(readByJuz: true)},
      );

      final family = state.resumeTargetFor('Family');
      expect(family.verse, const VerseKey(2, 5));
      expect(family.inJuz, isTrue);
      expect(family.juz, 1);
      expect(family.isStart, isFalse);

      final unlabeled = state.resumeTargetFor(unlabeledRecitationLabel);
      expect(unlabeled.inJuz, isTrue);
      expect(unlabeled.juz, 5);
    });

    test('a new track opens at its start point, or the beginning', () {
      final state = RecitationTrackerState(
        const {},
        {'Khatm', 'Plain'},
        {
          'Khatm': RecitationTrackSettings(
            readByJuz: true,
            startAt: const VerseKey(12, 53),
            startSetAt: DateTime.utc(2026, 1, 1),
          ),
        },
      );

      final khatm = state.resumeTargetFor('Khatm');
      expect(khatm.verse, const VerseKey(12, 53));
      expect(khatm.juz, 13);
      expect(khatm.isStart, isTrue);

      final plain = state.resumeTargetFor('Plain');
      expect(plain.verse, const VerseKey(1, 1));
      expect(plain.inJuz, isFalse);
      expect(plain.isStart, isTrue);
    });

    test('a start point only wins while it is newer than the last reading', () {
      final settings = RecitationTrackSettings(
        startAt: const VerseKey(18, 1),
        startSetAt: DateTime.utc(2026, 1, 2),
      );
      final readBefore = RecitationTrackerState(
        {'a': _entry(id: 'a', recitedAt: DateTime.utc(2026, 1, 1), toAyah: 5)},
        {'Family'},
        {'Family': settings},
      );
      expect(readBefore.resumeTargetFor('Family').verse, const VerseKey(18, 1));

      final readAfter = readBefore.setEntry(_entry(
        id: 'b',
        recitedAt: DateTime.utc(2026, 1, 3),
        surah: 18,
        toAyah: 10,
      ));
      expect(readAfter.resumeTargetFor('Family').verse, const VerseKey(18, 10));
      expect(readAfter.resumeTargetFor('Family').isStart, isFalse);
    });

    test('a juz read to its end resumes at the next juz', () {
      RecitationTrackerState endingAt(int surah, int ayah) =>
          RecitationTrackerState(
            {
              'a': _entry(
                id: 'a',
                recitedAt: DateTime.utc(2026, 1, 1),
                surah: surah,
                toAyah: ayah,
              ),
            },
            {'Family'},
            {'Family': const RecitationTrackSettings(readByJuz: true)},
          );

      // Juz 1 ends at al-Baqarah 141, mid-surah.
      expect(endingAt(2, 141).resumeTargetFor('Family').verse,
          const VerseKey(2, 142));
      expect(endingAt(2, 140).resumeTargetFor('Family').verse,
          const VerseKey(2, 140));
      // Juz 30 wraps round to juz 1 for the next khatm.
      expect(endingAt(114, 6).resumeTargetFor('Family').verse,
          const VerseKey(1, 1));
    });

    test('a khatm started part-way counts what came before as progress only',
        () {
      final state = RecitationTrackerState(
        {
          'a': _entry(
            id: 'a',
            label: 'Khatm',
            recitedAt: DateTime.utc(2026, 1, 1),
            surah: 2,
            fromAyah: 10,
            toAyah: 20,
          ),
        },
        {'Khatm'},
        {
          'Khatm': RecitationTrackSettings(
            startAt: const VerseKey(2, 10),
            startSetAt: DateTime.utc(2025, 12, 31),
            readBefore: const VerseKey(2, 10),
          ),
        },
      );

      // Al-Fatihah's 7 and al-Baqarah 1-9 marked, 10-20 read.
      expect(state.distinctVersesRecitedFor('Khatm'), 7 + 9 + 11);
      expect(state.juzCoverageFor('Khatm').first, greaterThan(0));
      // The stats only see what was read.
      expect(state.versesByLabel['Khatm'], 11);
      expect(state.totalVersesRecited, 11);

      final restored = RecitationTrackerState.fromJson(state.toJson());
      expect(restored.settingsFor('Khatm').readBefore, const VerseKey(2, 10));
    });

    test('track settings survive a JSON round trip', () {
      final state = RecitationTrackerState(
        const {},
        {'Khatm'},
        {
          'Khatm': RecitationTrackSettings(
            readByJuz: true,
            startAt: const VerseKey(12, 53),
            startSetAt: DateTime.utc(2026, 1, 1),
          ),
        },
      );
      final restored = RecitationTrackerState.fromJson(state.toJson());

      expect(restored.settingsFor('Khatm'), state.settingsFor('Khatm'));
      expect(restored.settingsFor('Other'), const RecitationTrackSettings());
      expect(
        RecitationTrackSettings.fromJson({
          'readByJuz': true,
          'startSurah': 2,
          'startAyah': 999,
          'startSetAt': '2026-01-01T00:00:00Z',
        })?.startAt,
        isNull,
        reason: 'an out-of-range start is dropped, not clamped somewhere odd',
      );
    });

    test('readInJuz survives a JSON round trip and is omitted when false', () {
      final juz =
          _entry(id: 'j', recitedAt: DateTime.utc(2026, 1, 1), readInJuz: true);
      final surah = _entry(id: 's', recitedAt: DateTime.utc(2026, 1, 1));

      expect(RecitationEntry.fromJson(juz.toJson())!.readInJuz, isTrue);
      expect(surah.toJson().containsKey('readInJuz'), isFalse);
      expect(RecitationEntry.fromJson(surah.toJson())!.readInJuz, isFalse);
    });

    test('mostRecentPosition ignores labels, unlike resumePositionFor', () {
      // What "Listen and follow" hands the matcher as context: whoever is
      // reciting nearby is not reciting under one of the reader's track labels.
      final state = RecitationTrackerState.empty
          .setEntry(_entry(
              id: 'a',
              label: 'Family',
              recitedAt: DateTime.utc(2026, 1, 10),
              surah: 2,
              fromAyah: 1,
              toAyah: 20))
          .setEntry(_entry(
              id: 'b',
              label: 'Personal',
              recitedAt: DateTime.utc(2026, 1, 20),
              surah: 3,
              fromAyah: 5,
              toAyah: 9));

      expect(state.mostRecentPosition, const VerseKey(3, 9));
      // The per-track answers are unchanged and still differ from it.
      expect(state.resumePositionFor('Family'), const VerseKey(2, 20));
    });

    test('mostRecentPosition is null when nothing has been recited', () {
      expect(RecitationTrackerState.empty.mostRecentPosition, isNull);
      expect(
        RecitationTrackerState.empty
            .addCustomLabel('Family')
            .mostRecentPosition,
        isNull,
      );
    });

    test(
        'distinctVersesRecitedFor merges overlapping and adjacent ranges, not raw sums',
        () {
      final state = RecitationTrackerState.empty
          .setEntry(_entry(
              id: 'a',
              recitedAt: DateTime.utc(2026, 1, 1),
              surah: 1,
              fromAyah: 1,
              toAyah: 5))
          // Overlaps 3-5 from the first entry: only 6-10 is new.
          .setEntry(_entry(
              id: 'b',
              recitedAt: DateTime.utc(2026, 1, 2),
              surah: 1,
              fromAyah: 3,
              toAyah: 10))
          // A separate surah entirely, so it adds on top rather than merging.
          .setEntry(_entry(
              id: 'c',
              recitedAt: DateTime.utc(2026, 1, 3),
              surah: 2,
              fromAyah: 1,
              toAyah: 3));

      // versesByLabel counts every re-read: 5 + 8 + 3 = 16.
      expect(state.versesByLabel['Family'], 16);
      // distinct coverage is deduplicated: surah 1 is 1-10 (10) once merged,
      // plus surah 2's 1-3 (3) = 13, not 16.
      expect(state.distinctVersesRecitedFor('Family'), 13);
    });

    test('percentCompleteFor is distinct verses over the whole Quran', () {
      final state = RecitationTrackerState.empty.setEntry(
        _entry(
            id: 'a',
            recitedAt: DateTime.utc(2026, 1, 1),
            surah: 1,
            fromAyah: 1,
            toAyah: 7),
      );
      expect(
        state.percentCompleteFor('Family'),
        closeTo(7 / quranTotalAyahCount * 100, 0.0001),
      );
      expect(state.percentCompleteFor('Nonexistent'), 0);
    });

    test(
        'dailyVerseCounts buckets verses by local calendar day within the window',
        () {
      final now = DateTime.now();
      final state = RecitationTrackerState.empty
          .setEntry(
              _entry(id: 'today_1', recitedAt: now, fromAyah: 1, toAyah: 5))
          .setEntry(_entry(
              id: 'today_2',
              label: 'Personal',
              recitedAt: now,
              fromAyah: 1,
              toAyah: 2))
          .setEntry(
            _entry(
                id: 'yesterday',
                recitedAt: now.subtract(const Duration(days: 1)),
                fromAyah: 1,
                toAyah: 3),
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

  group('juz progress', () {
    test('juzOf finds the juz a verse falls in, boundaries included', () {
      expect(juzOf(1, 1), 1);
      expect(juzOf(2, 141), 1);
      expect(juzOf(2, 142), 2);
      expect(juzOf(77, 50), 29);
      expect(juzOf(78, 1), 30);
      expect(juzOf(114, 6), 30);
    });

    test('juzCoverageFor counts distinct verses inside each juz', () {
      final state = RecitationTrackerState({
        // All of juz 1 (1:1-7 and 2:1-141), read twice over in places.
        'a': _entry(
            id: 'a',
            recitedAt: DateTime.utc(2026, 1, 1),
            surah: 1,
            fromAyah: 1,
            toAyah: 7),
        'b': _entry(
            id: 'b',
            recitedAt: DateTime.utc(2026, 1, 2),
            surah: 2,
            fromAyah: 1,
            toAyah: 141),
        'c': _entry(
            id: 'c',
            recitedAt: DateTime.utc(2026, 1, 3),
            surah: 2,
            fromAyah: 100,
            toAyah: 141),
        // Straddles into juz 2.
        'd': _entry(
            id: 'd',
            recitedAt: DateTime.utc(2026, 1, 4),
            surah: 2,
            fromAyah: 142,
            toAyah: 152),
      });

      final coverage = state.juzCoverageFor('Family');
      expect(coverage, hasLength(30));
      expect(coverage[0], 1.0);
      expect(coverage[1], greaterThan(0));
      expect(coverage[1], lessThan(1));
      expect(coverage.skip(2).every((f) => f == 0), isTrue);
      expect(state.completedJuzCountFor('Family'), 1);
      expect(state.completedJuzCountFor('Personal'), 0);
    });

    test('lastRecitedVerseFor is where the latest session ended', () {
      final state = RecitationTrackerState({
        'a': _entry(
            id: 'a',
            recitedAt: DateTime.utc(2026, 1, 2),
            surah: 77,
            fromAyah: 1,
            toAyah: 50),
        'b': _entry(
            id: 'b',
            recitedAt: DateTime.utc(2026, 1, 1),
            surah: 78,
            fromAyah: 1,
            toAyah: 40),
      });

      expect(state.lastRecitedVerseFor('Family'), const VerseKey(77, 50));
      expect(state.lastRecitedVerseFor('Personal'), isNull);
    });
  });

  group('the default track\'s name', () {
    test('shows as My reading; other tracks keep their own name', () {
      expect(recitationTrackName(unlabeledRecitationLabel), 'My reading');
      expect(recitationTrackName('Family'), 'Family');
    });

    test('is taken by both of its names, in any case', () {
      expect(isDefaultRecitationTrackName('My reading'), isTrue);
      expect(isDefaultRecitationTrackName('  my READING '), isTrue);
      expect(isDefaultRecitationTrackName('unlabeled'), isTrue);
      expect(isDefaultRecitationTrackName('My reading list'), isFalse);
    });
  });

  group('folding old sessions into day summaries', () {
    // Local times throughout: a summary is filed under the reader's own day.
    final now = DateTime(2026, 10, 12, 9);
    final old = DateTime(2026, 8, 1, 7);

    RecitationTrackerState history() => RecitationTrackerState({
          // Two old sessions on one day, re-reading part of the first.
          'a': _entry(id: 'a', recitedAt: old, surah: 36, toAyah: 40),
          'b': _entry(
              id: 'b',
              recitedAt: old.add(const Duration(hours: 12)),
              surah: 36,
              fromAyah: 30,
              toAyah: 83),
          // An old session the next day under another track.
          'c': _entry(
              id: 'c',
              label: unlabeledRecitationLabel,
              recitedAt: old.add(const Duration(days: 1)),
              surah: 67,
              toAyah: 30),
          // Recent sessions, one per track, which stay as they are.
          'd': _entry(
              id: 'd',
              recitedAt: now.subtract(const Duration(days: 2)),
              surah: 56,
              toAyah: 96),
          'e': _entry(
              id: 'e',
              label: unlabeledRecitationLabel,
              recitedAt: now.subtract(const Duration(days: 1)),
              surah: 1,
              toAyah: 7),
        }, {
          'Family'
        });

    test('folds only sessions past the retention window', () {
      final compaction = history().compaction(now)!;

      expect(compaction.removedEntryIds, {'a', 'b', 'c'});
      final family = compaction.summaries['2026-08-01']!['Family']!;
      expect(family.sessions, 2);
      expect(family.verses, 40 + 54);
      expect(family.ranges, {
        36: [(1, 83)]
      });
      expect(
        compaction.summaries['2026-08-02']![unlabeledRecitationLabel]!.verses,
        30,
      );
    });

    test('keeps every stat, streak day and khatm progress the same', () {
      final before = history();
      final after = before.applyCompaction(before.compaction(now)!);

      expect(after.entries.keys, unorderedEquals(['d', 'e']));
      expect(after.totalSessions, before.totalSessions);
      expect(after.totalVersesRecited, before.totalVersesRecited);
      expect(after.sessionsByLabel, before.sessionsByLabel);
      expect(after.versesByLabel, before.versesByLabel);
      expect(after.labels, before.labels);
      expect(after.distinctVersesRecitedFor('Family'),
          before.distinctVersesRecitedFor('Family'));
      expect(after.juzCoverageFor(unlabeledRecitationLabel),
          before.juzCoverageFor(unlabeledRecitationLabel));
      expect(after.longestStreak, before.longestStreak);
      expect(after.dailyVerseCounts(400), before.dailyVerseCounts(400));
      expect(after.sessionsSince(DateTime(2026, 8, 2)),
          before.sessionsSince(DateTime(2026, 8, 2)));
      expect(after.resumeTargetFor('Family').verse,
          before.resumeTargetFor('Family').verse);
    });

    test('never folds a track\'s latest session, however old', () {
      final state = RecitationTrackerState({
        'a': _entry(id: 'a', recitedAt: old, surah: 18, toAyah: 10),
        'b': _entry(
            id: 'b',
            recitedAt: old.add(const Duration(days: 1)),
            surah: 18,
            fromAyah: 11,
            toAyah: 20),
      });
      final after = state.applyCompaction(state.compaction(now)!);

      expect(after.entries.keys, ['b']);
      expect(after.lastRecitedFor('Family'), old.add(const Duration(days: 1)));
      expect(after.resumePositionFor('Family'), const VerseKey(18, 20));
      expect(after.compaction(now), isNull);
    });

    test('waits a week past the window, then folds in one batch', () {
      RecitationTrackerState withOldest(int daysAgo) => RecitationTrackerState({
            'a': _entry(
                id: 'a', recitedAt: now.subtract(Duration(days: daysAgo))),
            'b': _entry(id: 'b', recitedAt: now),
          });

      expect(withOldest(32).compaction(now), isNull);
      expect(withOldest(39).compaction(now)?.removedEntryIds, {'a'});
    });

    test('adds a late session to the day it was read, not over it', () {
      final first = history();
      final folded = first.applyCompaction(first.compaction(now)!);
      // A session from that old day turns up later - synced from a device
      // that was offline.
      final late = folded.setEntry(
          _entry(id: 'late', recitedAt: old, surah: 2, fromAyah: 1, toAyah: 5));
      final after = late.applyCompaction(late.compaction(now)!);

      final family = after.archive['2026-08-01']!['Family']!;
      expect(family.sessions, 3);
      expect(family.verses, 40 + 54 + 5);
      expect(family.ranges.keys, unorderedEquals([2, 36]));
    });

    test('folds at most the given number of sessions, oldest first', () {
      final compaction = history().compaction(now, maxSessions: 2)!;
      expect(compaction.removedEntryIds, {'a', 'b'});
    });

    test('summaries round trip through the stored JSON', () {
      final before = history();
      final after = before.applyCompaction(before.compaction(now)!);
      final restored = RecitationTrackerState.fromJson(after.toJson());

      expect(restored.archive, after.archive);
      expect(restored.totalVersesRecited, before.totalVersesRecited);
    });

    test('a summary encodes compactly and rejects anything malformed', () {
      final summary = RecitationDaySummary.empty
          .adding(_entry(id: 'a', recitedAt: old, surah: 36, toAyah: 12))
          .adding(_entry(
              id: 'b', recitedAt: old, surah: 2, fromAyah: 5, toAyah: 5));

      expect(summary.encode(), '2|13|2:5;36:1-12');
      expect(RecitationDaySummary.decode(summary.encode()), summary);
      for (final bad in [null, 3, '', '1|2', '0|5|', '1|5|2:9-3', '1|5|x:1']) {
        expect(RecitationDaySummary.decode(bad), isNull, reason: '$bad');
      }
    });

    test('a union never adds the same day twice', () {
      final a = RecitationDaySummary.decode('2|20|2:1-20')!;
      final b = RecitationDaySummary.decode('1|5|2:15-19;3:1-5')!;

      expect(a.union(b).encode(), '2|20|2:1-20;3:1-5');
      expect(a.union(a), a);
      final state = RecitationTrackerState(null, null, null, {
        '2026-08-01': {'Family': a},
      });
      expect(state.plus(state).totalSessions, 2);
    });
  });

  group('moving old days\' ranges into the track\'s coverage', () {
    final now = DateTime(2026, 10, 12, 9);
    // Well past recitationDayRangesRetentionDays and its week of grace.
    final ancient = DateTime(2025, 6, 1);
    final ancientKey = activityDayKey(ancient);
    final recentKey = activityDayKey(DateTime(2026, 8, 1));

    RecitationTrackerState archived() => RecitationTrackerState(
          {
            // Keeps Family's resume point; nothing to fold.
            'latest': _entry(
                id: 'latest',
                recitedAt: now.subtract(const Duration(days: 1)),
                surah: 1,
                toAyah: 7),
          },
          {'Family'},
          null,
          {
            ancientKey: {
              'Family': RecitationDaySummary.decode('2|120|36:1-83;67:1-30')!,
              unlabeledRecitationLabel:
                  RecitationDaySummary.decode('1|5|2:1-5')!,
            },
            activityDayKey(ancient.add(const Duration(days: 1))): {
              'Family': RecitationDaySummary.decode('1|40|36:40-83;56:1-1')!,
            },
            recentKey: {
              'Family': RecitationDaySummary.decode('1|10|18:1-10')!,
            },
          },
        );

    test('strips old summaries to their counts and unites their ranges', () {
      final compaction = archived().compaction(now)!;

      expect(compaction.removedEntryIds, isEmpty);
      expect(compaction.summaries[ancientKey]!['Family']!.encode(), '2|120|');
      expect(compaction.summaries.containsKey(recentKey), isFalse);
      expect(encodeAyahRanges(compaction.coverage['Family']!),
          '36:1-83;56:1;67:1-30');
      expect(encodeAyahRanges(compaction.coverage[unlabeledRecitationLabel]!),
          '2:1-5');
    });

    test('keeps every stat, streak day and khatm progress the same', () {
      final before = archived();
      final after = before.applyCompaction(before.compaction(now)!);

      expect(after.archive[recentKey]!['Family']!.ranges, isNotEmpty);
      expect(after.totalSessions, before.totalSessions);
      expect(after.totalVersesRecited, before.totalVersesRecited);
      expect(after.sessionsByLabel, before.sessionsByLabel);
      expect(after.versesByLabel, before.versesByLabel);
      expect(after.labels, before.labels);
      expect(after.distinctVersesRecitedFor('Family'),
          before.distinctVersesRecitedFor('Family'));
      expect(after.juzCoverageFor('Family'), before.juzCoverageFor('Family'));
      expect(after.percentCompleteFor(unlabeledRecitationLabel),
          before.percentCompleteFor(unlabeledRecitationLabel));
      expect(after.longestStreak, before.longestStreak);
      expect(after.dailyVerseCounts(400), before.dailyVerseCounts(400));
      expect(after.compaction(now), isNull);
    });

    test('waits a week past the line, then moves them in one batch', () {
      RecitationTrackerState withDay(int daysAgo) =>
          RecitationTrackerState(null, null, null, {
            activityDayKey(now.subtract(Duration(days: daysAgo))): {
              'Family': RecitationDaySummary.decode('1|10|18:1-10')!,
            },
          });

      expect(withDay(recitationDayRangesRetentionDays + 2).compaction(now),
          isNull);
      expect(
          withDay(recitationDayRangesRetentionDays + 9)
              .compaction(now)
              ?.coverage
              .keys,
          ['Family']);
    });

    test('a late session folded into an old day goes to coverage too', () {
      final folded = archived().applyCompaction(archived().compaction(now)!);
      final late = folded.setEntry(_entry(
          id: 'late', recitedAt: ancient, surah: 2, fromAyah: 1, toAyah: 9));
      final after = late.applyCompaction(late.compaction(now)!);

      expect(after.entries.containsKey('late'), isFalse);
      expect(after.archive[ancientKey]!['Family']!.encode(), '3|129|');
      expect(encodeAyahRanges(after.coverage['Family']!),
          '2:1-9;36:1-83;56:1;67:1-30');
    });

    test('adds to coverage that is already there', () {
      final state = RecitationTrackerState(null, null, null, {
        ancientKey: {'Family': RecitationDaySummary.decode('1|5|2:6-10')!},
      }, {
        'Family': {
          2: [(1, 5)],
        },
      });
      final after = state.applyCompaction(state.compaction(now)!);

      expect(encodeAyahRanges(after.coverage['Family']!), '2:1-10');
    });

    test('moves at most the given number of summaries, oldest first', () {
      final compaction = archived().compaction(now, maxSummaries: 2)!;
      expect(compaction.summaries.keys, [ancientKey]);
    });

    test('coverage round trips through the stored JSON', () {
      final before = archived();
      final after = before.applyCompaction(before.compaction(now)!);
      final restored = RecitationTrackerState.fromJson(after.toJson());

      expect(restored.coverage, after.coverage);
      expect(restored.archive, after.archive);
      expect(restored.distinctVersesRecitedFor('Family'),
          before.distinctVersesRecitedFor('Family'));
    });

    test('a union of coverage never counts a verse twice', () {
      final state = RecitationTrackerState(null, null, null, null, {
        'Family': {
          36: [(1, 83)],
        },
      });
      final doubled = state.plus(state);

      expect(doubled.coverage, state.coverage);
      expect(doubled.distinctVersesRecitedFor('Family'), 83);
    });

    test('ranges encode compactly and reject anything malformed', () {
      final ranges = {
        2: [(5, 5), (7, 9)],
        36: [(1, 12)],
      };
      expect(encodeAyahRanges(ranges), '2:5,7-9;36:1-12');
      expect(decodeAyahRanges(encodeAyahRanges(ranges)), ranges);
      expect(decodeAyahRanges(''), isEmpty);
      for (final bad in ['2', '2:', 'x:1', '2:9-3', '0:1', '2:1-2-3']) {
        expect(decodeAyahRanges(bad), isNull, reason: bad);
      }
    });
  });
}
