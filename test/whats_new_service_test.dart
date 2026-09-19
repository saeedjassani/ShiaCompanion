import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/whats_new_notes.dart';
import 'package:shia_companion/services/whats_new_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

/// These run against the real [whatsNewNotes] list - like
/// AzaanOptInService's tests running against its real allPrayerKeys, this
/// pins WhatsNewService's *rules* (who gets asked, what counts as new)
/// rather than any one release's content.
void main() {
  final latestBuild =
      whatsNewNotes.map((e) => e.buildNumber).reduce((a, b) => a > b ? a : b);

  Future<void> withPrefs(Map<String, Object> initial, {int? build}) async {
    SharedPreferences.setMockInitialValues(initial);
    await SP.init();
    PackageInfo.setMockInitialValues(
      appName: 'Shia Companion',
      packageName: 'com.developer110.shia_companion',
      version: '1.0.0',
      buildNumber: '${build ?? latestBuild}',
      buildSignature: '',
    );
  }

  group('a fresh install', () {
    test('is never shown anything', () async {
      await withPrefs({});
      expect(await WhatsNewService.pending(), isEmpty);
    });

    test('markSeen establishes a baseline without being shown anything',
        () async {
      await withPrefs({});
      await WhatsNewService.markSeen();
      expect(SP.prefs.getInt('whats_new_last_seen_build'), latestBuild);
    });
  });

  group('an existing install', () {
    test('sees every note up to the current build the first time this runs',
        () async {
      await withPrefs({azaanPreferenceKey: 'makkah'});
      final pending = await WhatsNewService.pending();
      expect(pending, isNotEmpty);
      expect(pending.every((e) => e.buildNumber <= latestBuild), isTrue);
    });

    test('sees nothing once markSeen has caught it up', () async {
      await withPrefs({azaanPreferenceKey: 'makkah'});
      await WhatsNewService.pending();
      await WhatsNewService.markSeen();
      expect(await WhatsNewService.pending(), isEmpty);
    });

    test('sees nothing once it was already caught up on its own', () async {
      await withPrefs({
        azaanPreferenceKey: 'makkah',
        'whats_new_last_seen_build': latestBuild,
      });
      expect(await WhatsNewService.pending(), isEmpty);
    });

    test('skipping straight past a note still surfaces it, not just the latest',
        () async {
      final original = List<WhatsNewEntry>.of(whatsNewNotes);
      whatsNewNotes
        ..clear()
        ..addAll(const [
          WhatsNewEntry(
              buildNumber: 100,
              versionName: '1.0.0',
              bullets: [WhatsNewBullet('a')]),
          WhatsNewEntry(
              buildNumber: 105,
              versionName: '1.0.5',
              bullets: [WhatsNewBullet('b')]),
        ]);
      addTearDown(() {
        whatsNewNotes
          ..clear()
          ..addAll(original);
      });

      await withPrefs({
        azaanPreferenceKey: 'makkah',
        'whats_new_last_seen_build': 99,
      }, build: 105);

      final pending = await WhatsNewService.pending();
      expect(pending.map((e) => e.buildNumber), [100, 105]);
    });
  });

  group('on the web', () {
    late List<WhatsNewEntry> original;

    setUp(() {
      original = List<WhatsNewEntry>.of(whatsNewNotes);
      whatsNewNotes
        ..clear()
        ..addAll(const [
          WhatsNewEntry(buildNumber: 100, versionName: '1.0.0', bullets: [
            WhatsNewBullet('shared'),
            WhatsNewBullet('app only', appOnly: true),
          ]),
          WhatsNewEntry(buildNumber: 105, versionName: '1.0.5', bullets: [
            WhatsNewBullet('only for the app', appOnly: true),
          ]),
        ]);
    });

    tearDown(() {
      whatsNewNotes
        ..clear()
        ..addAll(original);
    });

    test('app-only bullets are left out and emptied entries dropped', () async {
      await withPrefs({
        azaanPreferenceKey: 'makkah',
        'whats_new_last_seen_build': 99,
      }, build: 105);

      final pending = await WhatsNewService.pending(isWeb: true);
      expect(pending.map((e) => e.buildNumber), [100]);
      expect(pending.single.bullets.map((b) => b.text), ['shared']);
    });

    test('the app still sees every bullet', () async {
      await withPrefs({
        azaanPreferenceKey: 'makkah',
        'whats_new_last_seen_build': 99,
      }, build: 105);

      final pending = await WhatsNewService.pending(isWeb: false);
      expect(pending.map((e) => e.buildNumber), [100, 105]);
      expect(pending.first.bullets, hasLength(2));
    });
  });
}
