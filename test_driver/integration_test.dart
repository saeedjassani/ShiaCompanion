import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Pulls each screenshot taken via `binding.takeScreenshot(name)` in
/// integration_test/smoke_crawler_test.dart off the device and writes it to
/// build/integration_test_screenshots/<name>.png, so CI can upload them as a
/// downloadable artifact.
Future<void> main() => integrationDriver(
      onScreenshot: (String screenshotName, List<int> screenshotBytes,
          [Map<String, Object?>? args]) async {
        final directory = Directory('build/integration_test_screenshots');
        await directory.create(recursive: true);
        await File('${directory.path}/$screenshotName.png')
            .writeAsBytes(screenshotBytes);
        return true;
      },
    );
