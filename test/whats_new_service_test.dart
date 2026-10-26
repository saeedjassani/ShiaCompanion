import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/data/whats_new_notes.dart';
import 'package:shia_companion/services/whats_new_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

/// These pin WhatsNewService's *rules* (who gets a dot, what counts as new)
/// rather than any one release's content: the list is swapped for a small
/// fixed one in every test.
void main() {
  const key = WhatsNewService.lastSeenBuildKey;
  final original = List<WhatsNewEntry>.of(whatsNewNotes);

  setUp(() {
    whatsNewNotes
      ..clear()
      ..addAll([
        WhatsNewEntry(
            buildNumber: 100, versionName: '1.0.0', bullets: [(_) => 'a']),
        WhatsNewEntry(
            buildNumber: 105,
            versionName: '1.0.5',
            bullets: const [],
            androidBullets: [(_) => 'android only']),
        WhatsNewEntry(
            buildNumber: 110, versionName: '1.1.0', bullets: [(_) => 'b']),
        // Not shipped yet in a build-108 install.
        WhatsNewEntry(
            buildNumber: 120, versionName: '1.2.0', bullets: [(_) => 'c']),
      ]);
    WhatsNewService.hasUnread.value = false;
    WhatsNewService.debugCurrentBuild = 0;
  });

  tearDownAll(() {
    whatsNewNotes
      ..clear()
      ..addAll(original);
  });

  Future<void> launch(
    Map<String, Object> prefs, {
    int build = 110,
    bool freshInstall = false,
    bool isWeb = false,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    await SP.init();
    PackageInfo.setMockInitialValues(
      appName: 'Shia Companion',
      packageName: 'com.developer110.shia_companion',
      version: '1.0.0',
      buildNumber: '$build',
      buildSignature: '',
    );
    await WhatsNewService.resolveOnLaunch(
        freshInstall: freshInstall, isWeb: isWeb);
  }

  test('a fresh install starts caught up', () async {
    await launch({}, freshInstall: true);

    expect(SP.prefs.getInt(key), 110);
    expect(WhatsNewService.hasUnread.value, isFalse);
    // The notes are still there to read.
    expect(WhatsNewService.entries(platform: TargetPlatform.iOS), isNotEmpty);
  });

  test('an older install with no baseline has seen nothing', () async {
    await launch({}, freshInstall: false);

    expect(SP.prefs.getInt(key), 0);
    expect(WhatsNewService.hasUnread.value, isTrue);
    expect(
        WhatsNewService.unseenBuilds(platform: TargetPlatform.iOS), {100, 110});
  });

  test('an update past a note turns the dot on, and markSeen turns it off',
      () async {
    await launch({key: 100});

    expect(WhatsNewService.hasUnread.value, isTrue);
    expect(WhatsNewService.unseenBuilds(platform: TargetPlatform.android),
        {105, 110});

    await WhatsNewService.markSeen();

    expect(WhatsNewService.hasUnread.value, isFalse);
    expect(SP.prefs.getInt(key), 110);
    expect(WhatsNewService.unseenBuilds(platform: TargetPlatform.android),
        isEmpty);
  });

  test('a later launch keeps the mark it has', () async {
    await launch({key: 110}, freshInstall: true);

    expect(SP.prefs.getInt(key), 110);
    expect(WhatsNewService.hasUnread.value, isFalse);
  });

  test('entries are newest first, shipped only, and per platform', () async {
    await launch({key: 110});

    List<int> builds(TargetPlatform platform) =>
        WhatsNewService.entries(platform: platform)
            .map((e) => e.buildNumber)
            .toList();
    expect(builds(TargetPlatform.android), [110, 105, 100]);
    expect(builds(TargetPlatform.iOS), [110, 100]);
  });

  test('the web has no notes and no dot', () async {
    await launch({}, isWeb: true);

    expect(SP.prefs.containsKey(key), isFalse);
    expect(WhatsNewService.hasUnread.value, isFalse);
    expect(WhatsNewService.entries(), isEmpty);
  });
}
