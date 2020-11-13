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

  group('Full body test', () {
    setUpAll(
      () async {
        driver = await FlutterDriver.connect();
      },
    );
    test('Increment counter', () async {
      await driver.waitUntilNoTransientCallbacks();
      await screenshot(driver, config, 'home-page');
      expect(await driver.getText(textFinder), "Favorites");

      await driver.tap(calIcon);
      await driver.waitUntilNoTransientCallbacks();
      await screenshot(driver, config, 'cal-page');

      await driver.tap(libIcon);
      await driver.waitUntilNoTransientCallbacks();
      await screenshot(driver, config, 'lib-page');

      await driver.tap(prefIcon);
      await driver.waitUntilNoTransientCallbacks();
      await screenshot(driver, config, 'pref-page');
    });
    tearDownAll(() {
      if (driver != null) {
        driver.close();
      }
    });
  });
}
