import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/zikr_reading_preferences.dart';

void main() {
  // Must run before any test in this file calls SP.init() - there is no way
  // to un-initialize the SP singleton, so this is the one place this check
  // can be made at all.
  test('zikrFocusModeEnabled reports the default before SP is initialized', () {
    expect(zikrFocusModeEnabled(), zikrFocusModeDefault);
  });

  group('resolveZikrFocusMode', () {
    test('with nothing set, reports the default', () {
      expect(resolveZikrFocusMode(), zikrFocusModeDefault);
    });

    test('a legacy "progress off" reads as focus on', () {
      // Someone who turned the old progress strip off wanted less permanent
      // chrome over the text - Focus on is the closer of the two states.
      expect(
        resolveZikrFocusMode(legacyShowProgress: false),
        isTrue,
      );
    });

    test('a legacy "progress on" falls through to the default', () {
      expect(
        resolveZikrFocusMode(legacyShowProgress: true),
        zikrFocusModeDefault,
      );
    });

    test('an explicit choice always wins over the legacy key', () {
      expect(
        resolveZikrFocusMode(focusMode: false, legacyShowProgress: false),
        isFalse,
      );
      expect(
        resolveZikrFocusMode(focusMode: true, legacyShowProgress: true),
        isTrue,
      );
    });
  });

  group('migrateZikrFocusModePreference', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('does nothing when the legacy key was never set', () async {
      await SP.init();
      await migrateZikrFocusModePreference();

      expect(SP.prefs.containsKey(zikrFocusModeKey), isFalse);
    });

    test('turns a legacy "progress off" into an explicit focus-on', () async {
      SharedPreferences.setMockInitialValues({
        legacyShowZikrProgressKey: false,
      });
      await SP.init();

      await migrateZikrFocusModePreference();

      expect(SP.prefs.getBool(zikrFocusModeKey), isTrue);
      expect(SP.prefs.containsKey(legacyShowZikrProgressKey), isFalse);
    });

    test('turns a legacy "progress on" into an explicit focus-off', () async {
      // Not "no change" - the legacy key defaulted true and unconditionally
      // pinned the strip, so removing it without writing anything would
      // silently flip that reader onto the new default (on) instead.
      SharedPreferences.setMockInitialValues({
        legacyShowZikrProgressKey: true,
      });
      await SP.init();

      await migrateZikrFocusModePreference();

      expect(SP.prefs.getBool(zikrFocusModeKey), isFalse);
      expect(SP.prefs.containsKey(legacyShowZikrProgressKey), isFalse);
    });

    test('is idempotent - running it twice changes nothing further', () async {
      SharedPreferences.setMockInitialValues({
        legacyShowZikrProgressKey: false,
      });
      await SP.init();

      await migrateZikrFocusModePreference();
      await migrateZikrFocusModePreference();

      expect(SP.prefs.getBool(zikrFocusModeKey), isTrue);
      expect(SP.prefs.containsKey(legacyShowZikrProgressKey), isFalse);
    });

    test('an explicit focus_mode already on disk survives the migration',
        () async {
      SharedPreferences.setMockInitialValues({
        legacyShowZikrProgressKey: false,
        zikrFocusModeKey: false,
      });
      await SP.init();

      await migrateZikrFocusModePreference();

      expect(SP.prefs.getBool(zikrFocusModeKey), isFalse);
      expect(SP.prefs.containsKey(legacyShowZikrProgressKey), isFalse);
    });
  });
}
