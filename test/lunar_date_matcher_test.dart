import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/utils/lunar_date_matcher.dart';

/// The civil day on which Hijri date [year]-[month]-[day] falls (no offset).
DateTime _civil(int year, int month, int day) {
  final date = HijriCalendar().hijriToGregorian(year, month, day);
  final check = HijriCalendar.fromDate(date);
  // Guard the fixtures themselves against a calendar-table surprise.
  if (check.hYear != year || check.hMonth != month || check.hDay != day) {
    throw StateError('$year-$month-$day does not round-trip ($date)');
  }
  return DateTime(date.year, date.month, date.day);
}

LunarDay _hijri(int year, int month, int day) =>
    LunarDay(_civil(year, month, day));

/// Every day of a Hijri month, in order.
List<LunarDay> _month(int year, int month) {
  final first = _civil(year, month, 1);
  return [
    for (var i = 0; i < HijriCalendar().getDaysInMonth(year, month); i++)
      LunarDay(first.add(Duration(days: i))),
  ];
}

/// The civil dates among [days] that [pattern] matches as a day pattern.
List<DateTime> _matching(String pattern, Iterable<LunarDay> days) => [
      for (final day in days)
        if (matchesLunarDatePattern(pattern, day: day)) day.civilDate,
    ];

/// The civil dates among [nights] that [pattern] matches as a night - each
/// night given as the civil day it leads into, as resolveNightLunarDay does.
List<DateTime> _matchingNights(String pattern, Iterable<LunarDay> nights) => [
      for (final night in nights)
        if (matchesLunarDatePattern(
          pattern,
          day: LunarDay(night.civilDate.subtract(const Duration(days: 1))),
          night: night,
        ))
          night.civilDate,
    ];

void main() {
  // Rajab fixtures for the ordinal ("#K") cases (Umm al-Qura):
  //   1440: 1 Rajab is a Friday   (2019-03-08)
  //   1445: 1 Rajab is a Saturday (2024-01-13)
  //   1448: 1 Rajab is a Thursday (2026-12-10)

  group('LunarDay', () {
    test('drops the time of day but keeps local vs UTC', () {
      final local = LunarDay(DateTime(2024, 6, 16, 21, 30));
      expect(local.civilDate, DateTime(2024, 6, 16));
      expect(local.civilDate.isUtc, isFalse);

      final utc = LunarDay(DateTime.utc(2024, 6, 16, 21, 30));
      expect(utc.civilDate, DateTime.utc(2024, 6, 16));
      expect(utc.civilDate.isUtc, isTrue);
    });

    test('numbers weekdays from Sunday = 0 to Saturday = 6', () {
      final sunday = DateTime(2024, 5, 19);
      for (var i = 0; i < 7; i++) {
        expect(LunarDay(sunday.add(Duration(days: i))).weekday, i);
      }
    });

    test('an offset moves the Hijri date but never the weekday', () {
      final date = DateTime(2024, 6, 16);
      final plain = LunarDay(date);
      for (final offset in [-2, -1, 1, 2]) {
        final shifted = LunarDay(date, hijriOffsetDays: offset);
        expect(shifted.civilDate, plain.civilDate);
        expect(shifted.weekday, plain.weekday);
        expect(
          shifted.hijri.hDay,
          HijriCalendar.fromDate(date.add(Duration(days: offset))).hDay,
        );
      }
    });
  });

  group('"MM-DD" fixed date', () {
    test('matches only that Hijri date', () {
      final ramazan = _month(1446, 9);
      expect(_matching('09-19', ramazan), [_civil(1446, 9, 19)]);
      expect(_matching('09-01', ramazan), [_civil(1446, 9, 1)]);
      expect(_matching('10-19', ramazan), isEmpty);
    });

    test('accepts unpadded numbers', () {
      expect(matchesLunarDatePattern('9-1', day: _hijri(1446, 9, 1)), isTrue);
    });

    test('a 30th never matches in a 29-day month', () {
      // Rajab 1440 has 29 days.
      expect(HijriCalendar().getDaysInMonth(1440, 7), 29);
      expect(_matching('07-30', _month(1440, 7)), isEmpty);
      expect(_matching('07-29', _month(1440, 7)), [_civil(1440, 7, 29)]);
    });

    test('ignores surrounding whitespace', () {
      expect(
        matchesLunarDatePattern(' 09-19 ', day: _hijri(1446, 9, 19)),
        isTrue,
      );
    });
  });

  group('"MM-*" whole month', () {
    test('matches every day of that month and none either side', () {
      final days = [
        ..._month(1446, 8),
        ..._month(1446, 9),
        ..._month(1446, 10),
      ];
      expect(
        _matching('09-*', days),
        [for (final day in _month(1446, 9)) day.civilDate],
      );
    });
  });

  group('"MM-*-D" weekday within a month', () {
    test('every Sunday of Zilqad, and only Sundays of Zilqad', () {
      final days = [..._month(1446, 10), ..._month(1446, 11)];
      final matched = _matching('11-*-0', days);
      expect(
        matched,
        [
          for (final day in _month(1446, 11))
            if (day.weekday == 0) day.civilDate,
        ],
      );
      expect(matched.length, inInclusiveRange(4, 5));
    });
  });

  group('"*-*-D" weekday in every month', () {
    test('matches that weekday all year round', () {
      final days = [for (var m = 1; m <= 12; m++) ..._month(1446, m)];
      final fridays = _matching('*-*-5', days);
      expect(fridays.every((d) => d.weekday == DateTime.friday), isTrue);
      expect(
        fridays.length,
        days.where((d) => d.weekday == 5).length,
      );
    });
  });

  group('"*-*" every day', () {
    test('matches every day of the year', () {
      final days = [for (var m = 1; m <= 12; m++) ..._month(1446, m)];
      expect(_matching('*-*', days).length, days.length);
    });
  });

  group('"#K" ordinal weekday', () {
    test('first Thursday of Rajab, whatever weekday the month starts on', () {
      expect(_matching('07-*-4#1', _month(1440, 7)), [_civil(1440, 7, 7)]);
      expect(_matching('07-*-4#1', _month(1445, 7)), [_civil(1445, 7, 6)]);
      expect(_matching('07-*-4#1', _month(1448, 7)), [_civil(1448, 7, 1)]);
    });

    test('second, third and fourth occurrences', () {
      final rajab = _month(1445, 7); // Fridays: 7, 14, 21, 28
      expect(_matching('07-*-5#1', rajab), [_civil(1445, 7, 7)]);
      expect(_matching('07-*-5#2', rajab), [_civil(1445, 7, 14)]);
      expect(_matching('07-*-5#3', rajab), [_civil(1445, 7, 21)]);
      expect(_matching('07-*-5#4', rajab), [_civil(1445, 7, 28)]);
    });

    test('a fifth occurrence only when the month has one', () {
      // Rajab 1448 starts on a Thursday and has 30 days, so its 29th and
      // 30th are its fifth Thursday and fifth Friday; Saturday has no fifth.
      expect(HijriCalendar().getDaysInMonth(1448, 7), 30);
      expect(_matching('07-*-4#5', _month(1448, 7)), [_civil(1448, 7, 29)]);
      expect(_matching('07-*-5#5', _month(1448, 7)), [_civil(1448, 7, 30)]);
      expect(_matching('07-*-6#5', _month(1448, 7)), isEmpty);
    });

    test('stays inside its month', () {
      final days = [..._month(1445, 6), ..._month(1445, 7), ..._month(1445, 8)];
      expect(_matching('07-*-5#1', days), [_civil(1445, 7, 7)]);
    });

    test('"*-*-D#K" picks that occurrence in every month', () {
      for (var m = 1; m <= 12; m++) {
        final matched = _matching('*-*-5#1', _month(1446, m));
        expect(matched, hasLength(1), reason: 'month $m');
        expect(matched.single.weekday, DateTime.friday);
        expect(HijriCalendar.fromDate(matched.single).hDay, lessThan(8));
      }
    });

    test('is counted by lunar day, with the weekday from the civil date', () {
      // With a +1 offset, 6 Rajab 1445's civil day (a Thursday) is read as
      // 7 Rajab: still the first Thursday of Rajab, still a Thursday.
      final civilThursday = _civil(1445, 7, 6);
      expect(civilThursday.weekday, DateTime.thursday);
      final shifted = LunarDay(civilThursday, hijriOffsetDays: 1);
      expect(shifted.hijri.hDay, 7);
      expect(matchesLunarDatePattern('07-*-4#1', day: shifted), isTrue);
      expect(matchesLunarDatePattern('07-*-5#1', day: shifted), isFalse);
    });
  });

  group('"N" night patterns', () {
    test('never match without an open night', () {
      final day = _hijri(1446, 9, 19);
      for (final pattern in ['N09-19', 'N09-*', 'N*-*', 'N*-*-0']) {
        expect(matchesLunarDatePattern(pattern, day: day), isFalse,
            reason: pattern);
      }
    });

    test('read the night, not the day', () {
      // Evening of 22 Ramazan: the day is the 22nd, the night the 23rd's.
      final day = _hijri(1446, 9, 22);
      final night = _hijri(1446, 9, 23);
      expect(matchesLunarDatePattern('N09-23', day: day, night: night), isTrue);
      expect(
          matchesLunarDatePattern('N09-22', day: day, night: night), isFalse);
      // The plain day pattern still follows the day.
      expect(matchesLunarDatePattern('09-22', day: day, night: night), isTrue);
      expect(matchesLunarDatePattern('09-23', day: day, night: night), isFalse);
    });

    test('"NMM-*" covers every night of the month, from its first eve', () {
      final nights = [..._month(1446, 8), ..._month(1446, 9)];
      expect(
        _matchingNights('N09-*', nights),
        [for (final night in _month(1446, 9)) night.civilDate],
      );
    });

    test('"N*-*-5" is Thursday night, the night into Friday', () {
      final nights = _month(1446, 9);
      final matched = _matchingNights('N*-*-5', nights);
      expect(matched, isNotEmpty);
      expect(matched.every((d) => d.weekday == DateTime.friday), isTrue);
    });

    test(
        'Laylat al-Raghaib ("N07-*-5#1") is the night into Rajab\'s first '
        'Friday', () {
      // 1440: Rajab starts on a Friday, so Laylat al-Raghaib is the Thursday
      // night immediately before it - the last evening of Jumada al-Akhirah.
      // Rajab's first Thursday (the fast, "07-*-4#1") is still 7 Rajab.
      final nights1440 = [..._month(1440, 6), ..._month(1440, 7)];
      expect(_matchingNights('N07-*-5#1', nights1440), [_civil(1440, 7, 1)]);
      final eve = LunarDay(
        _civil(1440, 7, 1).subtract(const Duration(days: 1)),
      );
      expect(eve.civilDate.weekday, DateTime.thursday);
      expect(eve.hijri.hMonth, 6);
      expect(_matching('07-*-4#1', nights1440), [_civil(1440, 7, 7)]);

      expect(
        _matchingNights('N07-*-5#1', _month(1445, 7)),
        [_civil(1445, 7, 7)],
      );
      expect(
        _matchingNights('N07-*-5#1', _month(1448, 7)),
        [_civil(1448, 7, 2)],
      );
    });

    test('"N*-*" is every night', () {
      final nights = _month(1446, 9);
      expect(_matchingNights('N*-*', nights).length, nights.length);
    });
  });

  group('a moon-sighting Hijri offset never moves a weekday', () {
    // Regression: Dua Simat ("*-*-5") once showed up on Saturdays for people
    // whose Hijri date was adjusted by a day, because the weekday was read
    // off the offset Hijri date. Weekdays now only ever come from the civil
    // date, for day and night patterns alike.
    final week = [
      for (var i = 0; i < 7; i++) DateTime(2024, 5, 19).add(Duration(days: i)),
    ];

    for (final offset in [-2, -1, 0, 1, 2]) {
      test('offset $offset: "*-*-5" matches only the civil Friday', () {
        for (final date in week) {
          expect(
            matchesLunarDatePattern(
              '*-*-5',
              day: LunarDay(date, hijriOffsetDays: offset),
            ),
            date.weekday == DateTime.friday,
            reason: '$date',
          );
        }
      });

      test('offset $offset: "N*-*-5" matches only the night into Friday', () {
        for (final date in week) {
          expect(
            matchesLunarDatePattern(
              'N*-*-5',
              day: LunarDay(date.subtract(const Duration(days: 1)),
                  hijriOffsetDays: offset),
              night: LunarDay(date, hijriOffsetDays: offset),
            ),
            date.weekday == DateTime.friday,
            reason: '$date',
          );
        }
      });
    }
  });

  group('malformed patterns never match', () {
    final days = [for (var m = 1; m <= 12; m++) ..._month(1446, m)];
    const malformed = [
      '',
      ' ',
      '*',
      '09',
      '-',
      '09-',
      '-19',
      'x-y',
      '00-01',
      '13-01',
      '09-00',
      '09-31',
      '09-x',
      '*-15',
      '*-*-*',
      '*-*-7',
      '*-*--1',
      '09-*-7',
      '09-*-x',
      '09-19-3',
      '*-*-5-1',
      '09-*-5-1',
      '07-*-5#0',
      '07-*-5#6',
      '07-*-5#',
      '07-*-5#x',
      '07-*-5#1#2',
      'NN09-19',
      'N',
      'n09-19',
    ];
    for (final pattern in malformed) {
      test('"$pattern"', () {
        for (final day in days) {
          expect(
            matchesLunarDatePattern(pattern, day: day, night: day),
            isFalse,
            reason: '${day.civilDate}',
          );
        }
      });
    }
  });

  group('lunarPatternSpecificity', () {
    test('ranks once-a-year above monthly, weekly and daily', () {
      const expected = {
        '09-19': 0,
        'N09-19': 0,
        '07-*-5#1': 0,
        'N07-*-5#1': 0,
        '09-*': 1,
        'N09-*': 1,
        '11-*-0': 1,
        '*-*-5#1': 1,
        '*-*-5': 2,
        'N*-*-5': 2,
        '*-*': 3,
        'N*-*': 3,
      };
      expected.forEach((pattern, rank) {
        expect(lunarPatternSpecificity(pattern), rank, reason: pattern);
      });
    });
  });

  group('matchTodaysZikrs', () {
    final day = _hijri(1446, 9, 19);

    test('reads comma strings and lists of patterns', () {
      expect(
        getTodaysZikrs(
          {
            'string-match': {'day': '01-01, 09-19'},
            'list-match': {
              'day': ['01-01', '09-19'],
            },
            'miss': {'day': '01-01'},
          },
          day: day,
        ),
        ['string-match', 'list-match'],
      );
    });

    test('skips entries without a day, or that are not maps', () {
      expect(
        getTodaysZikrs(
          {
            'no-day': <String, dynamic>{'title': 'x'},
            'null-day': <String, dynamic>{'day': null},
            'not-a-map': 'x',
            'match': <String, dynamic>{'day': '*-*'},
          },
          day: day,
        ),
        ['match'],
      );
    });

    test('keeps the most specific matching pattern', () {
      final matches = matchTodaysZikrs(
        {
          'kumayl': <String, dynamic>{
            'day': ['*-*', '09-*', '09-19'],
          },
          'daily': <String, dynamic>{'day': '*-*'},
        },
        day: day,
      );
      expect(matches, {'kumayl': 0, 'daily': 3});
    });

    test('matches night patterns only while the night is open', () {
      final data = <String, dynamic>{
        'qadr-night': <String, dynamic>{'day': 'N09-19'},
      };
      final eve = _hijri(1446, 9, 18);
      expect(matchTodaysZikrs(data, day: eve), isEmpty);
      expect(matchTodaysZikrs(data, day: eve, night: day), {'qadr-night': 0});
    });
  });
}
