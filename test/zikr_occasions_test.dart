import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/zikr_occasions.dart';
import 'package:shia_companion/widgets/zikr_list_row.dart';

void main() {
  group('describeZikrOccasions', () {
    String? describe(List<String> patterns) => describeZikrOccasions(patterns);

    test('every day, and weekdays as plurals', () {
      expect(describe(['*-*']), 'Every day');
      expect(describe(['*-*-6']), 'Saturdays');
      expect(describe(['*-*-4', '*-*-5']), 'Thursdays and Fridays');
    });

    test('a weekday night is named after the day it follows', () {
      // "N*-*-5" is the night leading into Friday.
      expect(describe(['N*-*-5']), 'Thursday nights');
    });

    test('dates are grouped by month, in the zikr titles\' spelling', () {
      expect(describe(['02-20']), 'On 20 Safar');
      expect(
        describe(['02-17', '02-29', '11-11', '11-23']),
        "On 17 and 29 Safar, 11 and 23 Dhul Qa'dah",
      );
      expect(describe(['07-02', '07-03', '07-05']), 'On 2, 3 and 5 Rajab');
    });

    test('three or more days in a row read as a range', () {
      expect(describe(['09-13', '09-14', '09-15']), 'On 13–15 Ramazan');
      expect(
        describe([for (var d = 21; d <= 30; d++) 'N09-$d']),
        'Nights of 21–30 Ramazan',
      );
    });

    test('nights, and a date kept both night and day', () {
      expect(describe(['N08-15']), 'Night of 15 Shaban');
      expect(describe(['N09-19', 'N09-21', 'N09-23']),
          'Nights of 19, 21 and 23 Ramazan');
      expect(describe(['N11-25', '11-25']), "Night and day of 25 Dhul Qa'dah");
    });

    test('whole months and weekdays within one', () {
      expect(describe(['09-*']), 'Throughout Ramazan');
      expect(describe(['N09-*']), 'Every night of Ramazan');
      expect(describe(['11-*-0']), "Sundays in Dhul Qa'dah");
      expect(
        describe(['07-*-4#1', 'N07-*-5#1']),
        'First Thursday of Rajab · Night of the first Friday of Rajab',
      );
    });

    test('mixed kinds become clauses, the most frequent first', () {
      expect(
        describe(['10-01', '12-10', '12-18', '*-*-5']),
        'Fridays · On 1 Shawwal, 10 and 18 Dhul Hijjah',
      );
    });

    test('nothing to say without a pattern it can read', () {
      expect(describe([]), isNull);
      expect(describe(['13-01', 'nonsense']), isNull);
    });
  });

  test('isEveryDayOccasion only for "*-*"', () {
    expect(isEveryDayOccasion(['*-*']), isTrue);
    expect(isEveryDayOccasion(['*-*-5']), isFalse);
    expect(isEveryDayOccasion(['09-*']), isFalse);
  });

  group('splitTrailingArabic', () {
    test('moves the Arabic a title ends in to its own part', () {
      expect(
        splitTrailingArabic('Dua al-Hujjah اِلٰهِيْ بِحَقِّ مَنْ نَاجَاكَ'),
        (text: 'Dua al-Hujjah', arabic: 'اِلٰهِيْ بِحَقِّ مَنْ نَاجَاكَ'),
      );
      expect(
        splitTrailingArabic(
            'Dua of Imam al-Mahdi (a.t.f.s.) اَللّٰهُمَّ ادْفَعْ...'),
        (
          text: 'Dua of Imam al-Mahdi (a.t.f.s.)',
          arabic: 'اَللّٰهُمَّ ادْفَعْ...'
        ),
      );
    });

    test('leaves Arabic inside a title, and plain titles, alone', () {
      const inside = 'Ziyarat Rajabiyah (الحمد الله الذی اشهدنا)';
      expect(splitTrailingArabic(inside), (text: inside, arabic: null));
      expect(splitTrailingArabic('Dua Kumayl'),
          (text: 'Dua Kumayl', arabic: null));
    });

    test('keeps a title written wholly in Arabic script whole', () {
      // A translated title: splitting it would leave only "5:".
      expect(splitTrailingArabic('5: سورۃ المائدہ'),
          (text: '5: سورۃ المائدہ', arabic: null));
      expect(splitTrailingArabic('دعائے کمیل'),
          (text: 'دعائے کمیل', arabic: null));
    });
  });
}
