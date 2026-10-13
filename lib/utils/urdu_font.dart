import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Urdu is written in Nastaliq, the script its readers know from print,
/// wherever the app shows Urdu: the menus when the app is in Urdu, and zikr
/// translations, titles and hadith when they are. There is no choice of
/// Urdu font.
///
/// The font is Google's Noto Nastaliq Urdu, as scripts/build_urdu_font.py
/// makes it: holding Arabic-script letters only, so English words and 0-9
/// in the same text still come from the system font, and drawn at 70% so its
/// tall letters fit the app's line heights.
///
/// It is loaded only once Urdu is in use rather than listed under `fonts:`
/// in pubspec.yaml: the web build downloads every font listed there before
/// its first frame, whatever the reader's language. Until it has loaded,
/// Urdu falls back to the system's Arabic-script font, and Flutter lays the
/// text out again when it arrives.
abstract final class UrduFont {
  /// Not "Noto Nastaliq Urdu": the file is a scaled copy, and must never be
  /// mistaken for a system font of that name, or the system one for it.
  static const String family = 'Urdu Nastaliq';
  static const String asset = 'assets/fonts/noto-nastaliq-urdu.ttf';

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
