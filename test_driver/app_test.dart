import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';
import 'package:screenshots/screenshots.dart';

final config = Config();

void main() {
  FlutterDriver driver;
  final textFinder = find.byValueKey('hadith-text');
  final calIcon = find.byValueKey('calendar-icon');
  final libIcon = find.byValueKey('library-icon');
  final prefIcon = find.byValueKey('prefs-icon');
  WidgetsApp.debugAllowBannerOverride = false;

  group('Full body test', () {
    setUpAll(
      () async {
        driver = await FlutterDriver.connect();
      },
    );
    test('Increment counter', () async {
      sleep(const Duration(seconds: 5));
      await screenshot(driver, config, 'home-page');
      expect(await driver.getText(textFinder), "Favorites");

      await driver.tap(calIcon);
      sleep(const Duration(seconds: 2));
      await screenshot(driver, config, 'cal-page');

      await driver.tap(libIcon);
      sleep(const Duration(seconds: 2));
      await screenshot(driver, config, 'lib-page');

      await driver.tap(prefIcon);
      sleep(const Duration(seconds: 2));
      await screenshot(driver, config, 'pref-page');
    });
    tearDownAll(() {
      if (driver != null) {
        driver.close();
      }
    });
  });
}
