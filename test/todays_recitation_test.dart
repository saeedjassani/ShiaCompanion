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
}
