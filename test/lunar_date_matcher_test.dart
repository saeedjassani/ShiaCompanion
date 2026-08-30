import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/utils/lunar_date_matcher.dart';

void main() {
  test('fixed lunar date patterns match the provided Hijri date', () {
    final date = HijriCalendar.fromDate(DateTime(2024, 6, 16));

    expect(
      matchesLunarDatePattern(
        '${date.hMonth}-${date.hDay}',
        currentDate: date,
      ),
      isTrue,
    );
    expect(
      matchesLunarDatePattern(
        '${date.hMonth}-${date.hDay == 1 ? 2 : date.hDay - 1}',
        currentDate: date,
      ),
      isFalse,
    );
  });

  test('recurring lunar date patterns treat Sunday as zero', () {
    final sunday = HijriCalendar.fromDate(DateTime(2024, 5, 19));

    expect(sunday.weekDay(), DateTime.sunday);
    expect(
      matchesLunarDatePattern('${sunday.hMonth}-*-0', currentDate: sunday),
      isTrue,
    );
    expect(
      matchesLunarDatePattern('${sunday.hMonth}-*-6', currentDate: sunday),
      isFalse,
    );
  });

  test('"*-*-D" recurs on that weekday in every lunar month', () {
    final friday = HijriCalendar.fromDate(DateTime(2024, 5, 24));
    expect(friday.weekDay(), DateTime.friday);

    // Matches regardless of the current lunar month.
    expect(matchesLunarDatePattern('*-*-5', currentDate: friday), isTrue);
    // Wrong weekday still misses.
    expect(matchesLunarDatePattern('*-*-4', currentDate: friday), isFalse);
    // A wildcard month is meaningless for a fixed MM-DD date.
    expect(matchesLunarDatePattern('*-09', currentDate: friday), isFalse);
  });

  test('"MM-*" matches every day within that lunar month only', () {
    final date = HijriCalendar.fromDate(DateTime(2024, 6, 16));

    expect(matchesLunarDatePattern('${date.hMonth}-*', currentDate: date),
        isTrue);
    final otherMonth = (date.hMonth % 12) + 1;
    expect(
        matchesLunarDatePattern('$otherMonth-*', currentDate: date), isFalse);
    // A wildcard month with a wildcard day is meaningless.
    expect(matchesLunarDatePattern('*-*', currentDate: date), isFalse);
  });

  test('"NMM-DD" only matches when a night window is supplied and open', () {
    final date = HijriCalendar.fromDate(DateTime(2024, 6, 16));
    final pattern = 'N${date.hMonth}-${date.hDay}';

    // No night window supplied -> a plain "today" date is not enough.
    expect(matchesLunarDatePattern(pattern, currentDate: date), isFalse);

    // The night window is open and lands on the matching date.
    expect(
      matchesLunarDatePattern(pattern, currentDate: date, nightDate: date),
      isTrue,
    );

    // Open, but for a different date - still a miss.
    final otherNight = HijriCalendar.fromDate(DateTime(2024, 6, 17));
    expect(
      matchesLunarDatePattern(
        pattern,
        currentDate: date,
        nightDate: otherNight,
      ),
      isFalse,
    );
  });

  test('todays zikrs can read comma strings and lists of lunar patterns', () {
    final date = HijriCalendar.fromDate(DateTime(2024, 6, 16));
    final matchingPattern = '${date.hMonth}-${date.hDay}';

    expect(
      getTodaysZikrs(
        {
          'string-match': {'day': '01-01, $matchingPattern'},
          'list-match': {
            'day': ['01-01', matchingPattern],
          },
          'miss': {'day': '01-01'},
        },
        currentDate: date,
      ),
      ['string-match', 'list-match'],
    );
  });
}
