import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/navigation/home_menu.dart';

void main() {
  test('home menu labels and icons come from the same definitions', () {
    final labels = homeMenuItems.map((item) => item.label).toList();
    final icons = homeMenuItems.map((item) => item.icon).toList();

    expect(labels.toSet(), hasLength(labels.length));
    expect(zikr, equals(labels));
    expect(zikrIcons, equals(icons));
  });

  test('all home menu labels resolve to a concrete page', () {
    for (final item in homeMenuItems) {
      expect(getPage(item.label), isNot(isA<Container>()), reason: item.label);
    }

    expect(getHomeMenuItem('Munajaat')?.label, 'Munajaat');
    expect(getHomeMenuItem('Munajaats'), isNull);
    expect(getPage('Munajaat'), isNot(isA<Container>()));
  });

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
