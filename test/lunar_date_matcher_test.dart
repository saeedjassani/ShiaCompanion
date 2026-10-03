import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/lunar_date_matcher.dart';

void main() {
  test('fixed lunar date patterns match the provided Hijri date', () {
    final day = LunarDay(DateTime(2024, 6, 16));
    final date = day.hijri;

    expect(
      matchesLunarDatePattern('${date.hMonth}-${date.hDay}', day: day),
      isTrue,
    );
    expect(
      matchesLunarDatePattern(
        '${date.hMonth}-${date.hDay == 1 ? 2 : date.hDay - 1}',
        day: day,
      ),
      isFalse,
    );
  });

  test('recurring lunar date patterns treat Sunday as zero', () {
    final sunday = LunarDay(DateTime(2024, 5, 19));
    expect(sunday.civilDate.weekday, DateTime.sunday);

    expect(
      matchesLunarDatePattern('${sunday.hijri.hMonth}-*-0', day: sunday),
      isTrue,
    );
    expect(
      matchesLunarDatePattern('${sunday.hijri.hMonth}-*-6', day: sunday),
      isFalse,
    );
  });

  test('"*-*-D" recurs on that weekday in every lunar month', () {
    final friday = LunarDay(DateTime(2024, 5, 24));
    expect(friday.civilDate.weekday, DateTime.friday);

    expect(matchesLunarDatePattern('*-*-5', day: friday), isTrue);
    expect(matchesLunarDatePattern('*-*-4', day: friday), isFalse);
    // A wildcard month is meaningless for a fixed MM-DD date.
    expect(matchesLunarDatePattern('*-09', day: friday), isFalse);
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
          // The night window resolves to the civil day the night leads
          // into (see resolveNightLunarDay).
          final night = LunarDay(date, hijriOffsetDays: offset);
          expect(
            matchesLunarDatePattern(
              'N*-*-5',
              day: LunarDay(date.subtract(const Duration(days: 1)),
                  hijriOffsetDays: offset),
              night: night,
            ),
            date.weekday == DateTime.friday,
            reason: '$date',
          );
        }
      });
    }

    test('the offset still moves which lunar date it is', () {
      final date = DateTime(2024, 6, 16);
      final plain = LunarDay(date);
      final shifted = LunarDay(date, hijriOffsetDays: 1);
      expect(
        shifted.hijri.hDay,
        isNot(plain.hijri.hDay),
      );
      expect(shifted.weekday, plain.weekday);
    });
  });

  test('"MM-*" matches every day within that lunar month only', () {
    final day = LunarDay(DateTime(2024, 6, 16));
    final month = day.hijri.hMonth;

    expect(matchesLunarDatePattern('$month-*', day: day), isTrue);
    expect(matchesLunarDatePattern('${(month % 12) + 1}-*', day: day), isFalse);
    // A wildcard month needs a wildcard day ("*-*", every day); "*-15"
    // (the 15th of any month) isn't a supported pattern.
    expect(matchesLunarDatePattern('*-15', day: day), isFalse);
  });

  test('"*-*" matches every day of every month', () {
    for (final date in [DateTime(2024, 1, 1), DateTime(2024, 6, 16)]) {
      expect(matchesLunarDatePattern('*-*', day: LunarDay(date)), isTrue);
    }
    // Not a night pattern unless a night is open.
    expect(
      matchesLunarDatePattern('N*-*', day: LunarDay(DateTime(2024, 1, 1))),
      isFalse,
    );
  });

  test('pattern specificity ranks dates above months, weekdays and daily', () {
    expect(lunarPatternSpecificity('09-19'), 0);
    expect(lunarPatternSpecificity('N09-19'), 0);
    expect(lunarPatternSpecificity('09-*'), 1);
    expect(lunarPatternSpecificity('N09-*'), 1);
    expect(lunarPatternSpecificity('11-*-0'), 1);
    expect(lunarPatternSpecificity('*-*-5'), 2);
    expect(lunarPatternSpecificity('N*-*-5'), 2);
    expect(lunarPatternSpecificity('*-*'), 3);
  });

  test('"NMM-DD" only matches when a night window is supplied and open', () {
    final day = LunarDay(DateTime(2024, 6, 16));
    final pattern = 'N${day.hijri.hMonth}-${day.hijri.hDay}';

    // No night window supplied -> a plain "today" date is not enough.
    expect(matchesLunarDatePattern(pattern, day: day), isFalse);

    // The night window is open and lands on the matching date.
    expect(matchesLunarDatePattern(pattern, day: day, night: day), isTrue);

    // Open, but for a different date - still a miss.
    expect(
      matchesLunarDatePattern(
        pattern,
        day: day,
        night: LunarDay(DateTime(2024, 6, 17)),
      ),
      isFalse,
    );
  });

  test('todays zikrs can read comma strings and lists of lunar patterns', () {
    final day = LunarDay(DateTime(2024, 6, 16));
    final matchingPattern = '${day.hijri.hMonth}-${day.hijri.hDay}';

    expect(
      getTodaysZikrs(
        {
          'string-match': {'day': '01-01, $matchingPattern'},
          'list-match': {
            'day': ['01-01', matchingPattern],
          },
          'miss': {'day': '01-01'},
        },
        day: day,
      ),
      ['string-match', 'list-match'],
    );
  });
}
