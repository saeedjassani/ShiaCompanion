import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/continuous_reading.dart';
import 'package:shia_companion/models/recitation_tracker_state.dart';
import 'package:shia_companion/utils/quran_index.dart';

/// One everyday session: [surah] [from]-[to] on day [day] of November.
RecitationEntry _read(int day, int surah, int from, int to,
        {String label = unlabeledRecitationLabel, bool inJuz = false}) =>
    RecitationEntry(
      id: 'r_${day}_${surah}_$from',
      label: label,
      recitedAt: DateTime(2026, 11, day, 21),
      surah: surah,
      fromAyah: from,
      toAyah: to,
      readInJuz: inJuz,
    );

RecitationTrackerState _state(
  List<RecitationEntry> reads, {
  Set<String> labels = const {},
  Map<String, Map<String, RecitationDaySummary>> archive = const {},
  Map<String, Map<int, List<(int, int)>>> coverage = const {},
}) =>
    RecitationTrackerState(
      {for (final read in reads) read.id: read},
      labels,
      const {},
      archive,
      coverage,
    );

/// Al-Fatihah, then al-Baqarah through the end of juz 1 and a little past,
/// over four evenings - the old "My reading" card picking up each time.
final _throughJuz1 = [
  _read(1, 1, 1, 7),
  _read(2, 2, 1, 80),
  _read(3, 2, 80, 141),
  _read(4, 2, 142, 200),
];

void main() {
  test('reading straight through is found, and carries on after it', () {
    final reading = findContinuousReading(_state(_throughJuz1))!;

    expect(reading.start, const VerseKey(1, 1));
    expect(reading.end, const VerseKey(2, 200));
    expect(reading.resumeAt, const VerseKey(2, 201));
    expect(reading.continuations, 3);
    expect(reading.days, 4);
    expect(reading.readInJuz, isFalse);
    expect(reading.ranges, {
      1: [(1, 7)],
      2: [(1, 200)],
    });
  });

  test('the favourite surahs read every week are never a khatm', () {
    // Months of Ya-Sin on Thursdays, al-Kahf on Fridays, al-Waqiah and
    // al-Mulk at night: a good share of the Quran, never read through.
    final reads = <RecitationEntry>[];
    for (var week = 0; week < 4; week++) {
      final day = 1 + week * 7;
      reads
        ..add(_read(day, 36, 1, 83))
        ..add(_read(day + 1, 18, 1, 110))
        ..add(_read(day + 2, 56, 1, 96))
        ..add(_read(day + 3, 67, 1, 30))
        ..add(_read(day + 4, 55, 1, 78));
    }
    expect(findContinuousReading(_state(reads)), isNull);
  });

  test('a surah read in between does not break the reading through', () {
    final reading = findContinuousReading(_state([
      _read(1, 1, 1, 7),
      _read(2, 2, 1, 80),
      _read(2, 36, 1, 83), // Ya-Sin, from the list.
      _read(3, 2, 80, 141),
      _read(4, 67, 1, 30), // Al-Mulk.
      _read(5, 2, 142, 200),
    ]))!;

    expect(reading.end, const VerseKey(2, 200));
    expect(reading.resumeAt, const VerseKey(2, 201));
  });

  test('a session may start a verse or two past where the last stopped', () {
    final reading = findContinuousReading(_state([
      _read(1, 1, 1, 7),
      _read(2, 2, 2, 80),
      _read(3, 2, 82, 141),
      _read(4, 2, 143, 200),
    ]));
    expect(reading?.resumeAt, const VerseKey(2, 201));
  });

  test('too little read in order is not enough', () {
    // Two continuations, not three.
    expect(findContinuousReading(_state(_throughJuz1.take(3).toList())),
        isNull);
    // All on one day.
    expect(
      findContinuousReading(_state([
        for (final read in _throughJuz1) _read(1, read.surah, read.fromAyah,
            read.toAyah),
      ])),
      isNull,
    );
    // Four sittings in order, but short of a whole juz.
    expect(
      findContinuousReading(_state([
        _read(1, 2, 1, 20),
        _read(2, 2, 21, 40),
        _read(3, 2, 41, 60),
        _read(4, 2, 61, 80),
      ])),
      isNull,
    );
  });

  test('a finished khatm leaves no place to keep', () {
    // Juz 30 read through to the last verse of an-Nas.
    final juz30 = allJuz().last;
    expect(
      findContinuousReading(_state([
        _read(1, juz30.start.surah, 1, 40),
        _read(2, 79, 1, 46),
        _read(3, 80, 1, 42),
        for (var surah = 81; surah <= 114; surah++)
          _read(4, surah, 1, surahAyahCounts[surah - 1]),
      ])),
      isNull,
    );
  });

  test('days older than a month count too, from their day summaries', () {
    final reading = findContinuousReading(_state(
      [_read(4, 2, 142, 200)],
      archive: {
        '2026-09-01': {
          unlabeledRecitationLabel: const RecitationDaySummary(
              sessions: 1, verses: 7, ranges: {1: [(1, 7)]}),
        },
        '2026-09-02': {
          unlabeledRecitationLabel: const RecitationDaySummary(
              sessions: 1, verses: 80, ranges: {2: [(1, 80)]}),
        },
        '2026-09-03': {
          unlabeledRecitationLabel: const RecitationDaySummary(
              sessions: 1, verses: 62, ranges: {2: [(80, 141)]}),
        },
      },
    ))!;
    expect(reading.start, const VerseKey(1, 1));
    expect(reading.resumeAt, const VerseKey(2, 201));
  });

  test('read a juz at a time, it carries on by juz', () {
    final reading = findContinuousReading(_state([
      for (final read in _throughJuz1)
        _read(read.recitedAt.day, read.surah, read.fromAyah, read.toAyah,
            inJuz: true),
    ]))!;
    expect(reading.readInJuz, isTrue);
  });

  test('only the everyday reading is looked at', () {
    expect(
      findContinuousReading(_state([
        for (final read in _throughJuz1)
          _read(read.recitedAt.day, read.surah, read.fromAyah, read.toAyah,
              label: 'Family'),
      ], labels: {
        'Family'
      })),
      isNull,
    );
  });

  group('planMyReadingPort', () {
    test('plans the move when nothing holds the reading yet', () {
      expect(planMyReadingPort(_state(_throughJuz1), 'My reading'),
          isNotNull);
    });

    test('not again once a Khatm has the name - another device moved it', () {
      expect(
        planMyReadingPort(
            _state(_throughJuz1, labels: {'my reading'}), 'My reading'),
        isNull,
      );
    });

    test('not when a Khatm already holds the same reading', () {
      expect(
        planMyReadingPort(
          _state(_throughJuz1, labels: {
            'میری تلاوت'
          }, coverage: {
            'میری تلاوت': {
              1: [(1, 7)],
              2: [(1, 200)],
            },
          }),
          'My reading',
        ),
        isNull,
      );
    });
  });
}
