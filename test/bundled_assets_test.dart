import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Junk that tooling drops into a folder and that no build should ever ship.
const _junkNames = {'.DS_Store', 'Thumbs.db', 'desktop.ini'};

/// Guards what actually goes into the app bundle.
///
/// A directory entry in pubspec.yaml bundles every file sitting in that
/// directory at build time. Flutter does not consult .gitignore, so a
/// .DS_Store that Finder recreates locally is invisible to git and still ends
/// up inside the shipped app — which is exactly what happened: the deployed
/// web build carried an `assets/.DS_Store`.
///
/// Directories small enough to list file by file are listed that way in
/// pubspec.yaml instead. These tests cover the ones that cannot be, and catch
/// a junk file the moment it is committed.
void main() {
  late List<String> declarations;

  setUpAll(() {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
    final assets = (pubspec['flutter'] as Map)['assets'] as YamlList;
    declarations = assets.map((entry) => entry.toString()).toList();
  });

  test('no declared asset directory contains a junk file', () {
    final offenders = <String>[];

    for (final declaration in declarations) {
      if (!declaration.endsWith('/')) continue;

      final directory = Directory(declaration);
      if (!directory.existsSync()) continue;

      // Non-recursive on purpose: a directory entry bundles only that
      // directory's own files, not its subdirectories.
      for (final entity in directory.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (_junkNames.contains(name) || name.startsWith('._')) {
          offenders.add(entity.path);
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These would be bundled into the app. Delete them:\n'
          '${offenders.join('\n')}',
    );
  });

  test('every declared asset exists', () {
    final missing = declarations.where((declaration) {
      return declaration.endsWith('/')
          ? !Directory(declaration).existsSync()
          : !File(declaration).existsSync();
    }).toList();

    expect(
      missing,
      isEmpty,
      reason: 'pubspec.yaml declares assets that are not in the repo:\n'
          '${missing.join('\n')}',
    );
  });

  test('the sign-in logos are sized for the 24dp they are drawn at', () {
    // They were once 1080x1080 and 2000x2000, 161 KB between them, for a
    // 24-logical-pixel row leading. Anything past 4x that height is waste.
    for (final path in const [
      'assets/images/google_logo.png',
      'assets/images/apple_logo.png',
    ]) {
      final bytes = File(path).readAsBytesSync();
      expect(
        bytes.length,
        lessThan(20 * 1024),
        reason: '$path is larger than a 24dp icon has any need to be',
      );
    }
  });
}
