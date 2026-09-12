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

  test('lunar date matches stay at the top of todays recitations', () {
    final now = DateTime(2024, 6, 16);
    final hijriToday = HijriCalendar.fromDate(now);

    items = {
      'E18': 'Dua e Ahad',
      'G6': 'Ziyarat e Waritha',
      'G4': 'Ziyarat e Ashura',
      'E37': 'Dua e Sanamay Quraish',
      'L1': 'Sunday Recitation',
      'Z99': 'Lunar Recitation',
    };
    itemOrder = {};
    itemMetadata = {
      'Z99': {'day': '${hijriToday.hMonth}-${hijriToday.hDay}'},
    };
    hijriDate = 0;

    final recitations = buildTodaysRecitationItems(now: now);

    expect(
      recitations.map((item) => item.uid).take(6),
      ['Z99', 'L1', 'E18', 'G6', 'G4', 'E37'],
    );
  });

  test(
      'a recurring weekday match (e.g. Dua Simat on Friday) survives a '
      "moon-sighting hijri date adjustment", () {
    final friday = DateTime(2024, 6, 21);
    expect(friday.weekday, DateTime.friday);

    items = {
      'E18': 'Dua e Ahad',
      'G6': 'Ziyarat e Waritha',
      'G4': 'Ziyarat e Ashura',
      'E37': 'Dua e Sanamay Quraish',
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
}
