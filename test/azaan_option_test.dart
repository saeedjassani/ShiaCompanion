import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/azaan_option.dart';

void main() {
  test('all option ids are unique', () {
    final ids = AzaanOptions.all.map((option) => option.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('getById finds a known option and returns null for an unknown id', () {
    expect(AzaanOptions.getById('takbir'), same(AzaanOptions.takbir));
    expect(AzaanOptions.getById('custom'), same(AzaanOptions.custom));
    expect(AzaanOptions.getById('does-not-exist'), isNull);
  });

  test('getDefault returns the full azaan option', () {
    expect(AzaanOptions.getDefault(), same(AzaanOptions.azaan));
  });

  test('only the custom option is flagged as custom', () {
    expect(AzaanOptions.custom.isCustom, isTrue);
    for (final option in AzaanOptions.all.where((o) => o.id != 'custom')) {
      expect(option.isCustom, isFalse, reason: option.id);
    }
  });

  test('systemDefault has no bundled sound files', () {
    expect(AzaanOptions.systemDefault.androidFile, isNull);
    expect(AzaanOptions.systemDefault.iosFile, isNull);
  });

  test('only Full Azan, Al-Halawaji and Custom play via the service', () {
    final ids = AzaanOptions.all
        .where((o) => o.playsViaPlaybackService)
        .map((o) => o.id)
        .toList();
    expect(ids, ['azaan', 'azaan_halawaji', 'custom']);
  });

  test('every playback asset is on disk and declared in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final option in AzaanOptions.all) {
      final asset = option.playbackAsset;
      if (asset == null) continue;
      expect(File(asset).existsSync(), isTrue, reason: '${option.id}: $asset');
      expect(pubspec, contains('- $asset'), reason: option.id);
    }
  });

  test('every iOS notification sound is on disk and in the Xcode project', () {
    final pbxproj =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    for (final option in AzaanOptions.all) {
      final file = option.iosFile;
      if (file == null) continue;
      expect(File('ios/$file').existsSync(), isTrue,
          reason: '${option.id}: $file');
      expect(pbxproj, contains('$file in Resources'), reason: option.id);
    }
  });
}
