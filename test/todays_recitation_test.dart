import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/todays_recitation.dart';

void main() {
  late Map originalItems;
  late Map<String, double> originalItemOrder;
  late Map<String, dynamic> originalItemMetadata;
  late int originalHijriDate;

  setUp(() {
    originalItems = Map.of(items);
    originalItemOrder = Map.of(itemOrder);
    originalItemMetadata = Map.of(itemMetadata);
    originalHijriDate = hijriDate;
  });

  tearDown(() {
    items = originalItems;
    itemOrder = originalItemOrder;
    itemMetadata = originalItemMetadata;
    hijriDate = originalHijriDate;
  });

  test('orders occasions before months, weekdays and daily recitations', () {
    final sunday = DateTime(2024, 6, 16);
    expect(sunday.weekday, DateTime.sunday);
    final hijriToday = HijriCalendar.fromDate(sunday);

    items = {
      'E18': 'Dua e Ahad',
      'G4': 'Ziyarat e Ashura',
      'L1': 'Sunday Recitation',
      'X2': 'Month Recitation',
      'Z99': 'Lunar Recitation',
      'Q1': 'Thursday Recitation',
    };
    itemOrder = {};
    itemMetadata = {
      'E18': {'day': '*-*'},
      'G4': {'day': '*-*'},
      'L1': {'day': '*-*-0'},
      'X2': {'day': '${hijriToday.hMonth}-*'},
      'Z99': {'day': '${hijriToday.hMonth}-${hijriToday.hDay}'},
      'Q1': {'day': '*-*-4'},
    };
    hijriDate = 0;

    final recitations = buildTodaysRecitationItems(now: sunday);

    expect(
      recitations.map((item) => item.uid),
      ['Z99', 'X2', 'L1', 'G4', 'E18'],
    );
  });

  test(
      'a recurring weekday match (e.g. Dua Simat on Friday) survives a '
      "moon-sighting hijri date adjustment", () {
    final friday = DateTime(2024, 6, 21);
    expect(friday.weekday, DateTime.friday);

    items = {
      'E26': 'Dua Simat',
    };
    itemOrder = {};
    itemMetadata = {
      'E26': {'day': '*-*-5'},
    };
    // A user with their Hijri calendar nudged by a day for local moon
    // sighting should still see Dua Simat on the actual Friday, not shifted
    // to the day next to it.
    hijriDate = 1;

    final recitations = buildTodaysRecitationItems(now: friday);

    expect(recitations.map((item) => item.uid), contains('E26'));
  });

  test('an alias never lists alongside its canonical (e.g. Dua Nudbah)', () {
    final friday = DateTime(2024, 6, 21);
    expect(friday.weekday, DateTime.friday);

    items = {
      'E34': 'Dua e Nudbah',
      'J2|E34': 'Dua-e-Nudbah',
    };
    itemOrder = {};
    // Only the canonical entry carries a `day` - see zikr_day_data_test.dart.
    itemMetadata = {
      'E34': {'day': '*-*-5'},
    };
    hijriDate = 0;

    final recitations = buildTodaysRecitationItems(now: friday);

    expect(recitations.map((item) => item.uid), ['E34']);
  });

  test('night aamal show up in the evening even without a location', () {
    final eve = HijriCalendar().hijriToGregorian(1446, 9, 22);
    final originalLat = lat;
    final originalLong = long;
    addTearDown(() {
      lat = originalLat;
      long = originalLong;
    });
    lat = null;
    long = null;

    items = {'AA34': '23rd Night of Ramazan'};
    itemOrder = {};
    itemMetadata = {
      'AA34': {'day': 'N09-23'},
    };
    hijriDate = 0;

    List<String> at(int hour) => buildTodaysRecitationItems(
          now: DateTime(eve.year, eve.month, eve.day, hour),
        ).map((item) => item.uid).toList();

    expect(at(12), isEmpty);
    expect(at(21), ['AA34']);
  });

  group('weekday recitations never drift with a Hijri adjustment', () {
    // Regression: Dua Simat showed up on Saturdays for people whose Hijri
    // date was adjusted by a day. Check the whole pipeline, day and night,
    // for every offset the setting allows and every day of a week.
    late double? originalLat;
    late double? originalLong;
    setUp(() {
      originalLat = lat;
      originalLong = long;
      lat = null; // night window falls back to 16:00 - 08:00
      long = null;
      items = {'E26': 'Dua Simat', 'Q9': 'Thursday Night'};
      itemOrder = {};
      itemMetadata = {
        'E26': {'day': '*-*-5'},
        'Q9': {'day': 'N*-*-5'},
      };
    });
    tearDown(() {
      lat = originalLat;
      long = originalLong;
    });

    for (final offset in [-2, -1, 0, 1, 2]) {
      test('offset $offset', () {
        hijriDate = offset;
        for (var i = 0; i < 7; i++) {
          final date = DateTime(2024, 6, 16).add(Duration(days: i));
          List<String> at(int hour) => buildTodaysRecitationItems(
                now: DateTime(date.year, date.month, date.day, hour),
              ).map((item) => item.uid).toList();

          final isFriday = date.weekday == DateTime.friday;
          final isThursday = date.weekday == DateTime.thursday;
          expect(at(12).contains('E26'), isFriday, reason: '$date noon');
          // Thursday evening through Friday morning is the night of Friday.
          expect(at(21).contains('Q9'), isThursday, reason: '$date evening');
          expect(at(6).contains('Q9'), isFriday, reason: '$date pre-dawn');
          expect(at(12).contains('Q9'), isFalse, reason: '$date noon');
        }
      });
    }
  });
}
