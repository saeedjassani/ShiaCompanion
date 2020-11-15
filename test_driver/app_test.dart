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
      await driver.waitFor(find.byValueKey("Mecca"));
      await screenshot(driver, config, 'home-page');
      expect(await driver.getText(textFinder), "Favorites");

      await driver.tap(calIcon);
      await driver.waitFor(find.byValueKey("cal-key"));
      await screenshot(driver, config, 'cal-page');

      await driver.tap(libIcon);
      await driver.waitFor(find.byValueKey("lib-key-0"));
      await screenshot(driver, config, 'lib-page');

      await driver.tap(prefIcon);
      await screenshot(driver, config, 'pref-page');
    }, timeout: Timeout.none);
    tearDownAll(() {
      if (driver != null) {
        driver.close();
      }
    });
  });
}
