import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';
import 'package:screenshots/screenshots.dart';

final config = Config();

void main() {
  FlutterDriver driver;
  final textFinder = find.byValueKey('hadith-text');

  group('Full body test', () {
    setUpAll(
      () async {
        driver = await FlutterDriver.connect();
      },
    );
    test('Increment counter', () async {
      await screenshot(driver, config, 'testing');
      expect(await driver.getText(textFinder), "Favorites");
    });
    tearDownAll(() {
      if (driver != null) {
        driver.close();
      }
    });
  });
}
