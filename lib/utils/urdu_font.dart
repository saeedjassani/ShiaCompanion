import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Urdu is written in Jameel Noori Nastaleeq, the Nastaliq its readers know
/// from print, wherever the app shows Urdu: the menus when the app is in
/// Urdu, and zikr translations, titles and hadith when they are. There is no
/// choice of Urdu font.
///
/// The bundled file (assets/fonts/jameel-noori-nastaleeq.ttf, see the
/// NOTICE beside it) is cut down to the Arabic-script letters, so English
/// words and 0-9 in the same text still come from the system font.
///
/// It is ~10 MB, so it is loaded only once Urdu is in use rather than listed
/// under `fonts:` in pubspec.yaml: the web build downloads every font listed
/// there before its first frame, whatever the reader's language. Until it
/// has loaded, Urdu falls back to the system's Arabic-script font, and
/// Flutter lays the text out again when it arrives.
abstract final class UrduFont {
  static const String family = 'Jameel Noori Nastaleeq';
  static const String asset = 'assets/fonts/jameel-noori-nastaleeq.ttf';

  static Future<void>? _loading;

  /// Loads the font, once; later calls return the same future. Never
  /// throws: on failure Urdu stays in the system font.
  static Future<void> ensureLoaded() => _loading ??= _load();

  static Future<void> _load() async {
    try {
      final loader = FontLoader(family)..addFont(rootBundle.load(asset));
      await loader.load();
    } catch (e) {
      debugPrint('Unable to load the Urdu font: $e');
    }
  }
}
