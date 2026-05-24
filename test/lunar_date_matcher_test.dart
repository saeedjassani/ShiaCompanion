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
