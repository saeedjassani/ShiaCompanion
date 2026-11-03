import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `res/xml/shortcuts.xml` names the app's package, which a debug build
/// changes, so the debug build has its own copy; and its actions and labels
/// are wired by hand to `SmartActions.kt` and the string resources.
void main() {
  const main = 'android/app/src/main/res/xml/shortcuts.xml';
  const debug = 'android/app/src/debug/res/xml/shortcuts.xml';
  const releasePackage =
      'android:targetPackage="com.developer110.shiacompanion"';
  const debugPackage =
      'android:targetPackage="com.developer110.shiacompanion.debug"';

  final shortcuts = File(main).readAsStringSync();

  test('the debug copy is the release one with the debug package', () {
    expect(shortcuts, contains(releasePackage));
    expect(
      File(debug).readAsStringSync(),
      shortcuts.replaceAll(releasePackage, debugPackage),
      reason: 'Copy $main to $debug with the .debug package.',
    );
  });

  test('every action is one SmartActions.kt carries out', () {
    final kotlin = File(
      'android/app/src/main/kotlin/com/developer110/shiacompanion/'
      'smartactions/SmartActions.kt',
    ).readAsStringSync();
    final actions = RegExp(r'action\.([A-Z_]+)"')
        .allMatches(shortcuts)
        .map((match) => match.group(1)!)
        .toSet();
    expect(actions, isNotEmpty);
    for (final action in actions) {
      expect(kotlin, contains('ACTION_PREFIX + "$action"'), reason: action);
    }
  });

  test('every shortcut label is in every language', () {
    final labels = RegExp(r'@string/(\w+)')
        .allMatches(shortcuts)
        .map((match) => match.group(1)!)
        .toSet();
    expect(labels, isNotEmpty);
    for (final dir in [
      'values',
      'values-ur',
      'values-fa',
      'values-ar',
      'values-gu'
    ]) {
      final strings =
          File('android/app/src/main/res/$dir/strings.xml').readAsStringSync();
      for (final label in labels) {
        expect(strings, contains('name="$label"'), reason: '$dir: $label');
      }
    }
  });
}
