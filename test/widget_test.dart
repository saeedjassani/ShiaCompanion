import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';

void main() {
  test('prayer time object exposes the expected prayer names', () {
    expect(getPrayerTimeObject().getTimeNames(), [
      'Fajr',
      'Sunrise',
      'Zuhr',
      'Asr',
      'Sunset',
      'Maghrib',
      'Isha',
    ]);
  });
}
