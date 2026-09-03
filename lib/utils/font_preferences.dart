import 'package:shared_preferences/shared_preferences.dart';

class FontPreferences {
  static const String _selectedFontKey = 'arabic_font';
  static const List<String> _validFonts = ['Qalam', 'Scheherazade'];
  static const String _defaultFont = 'Qalam';

  /// Fonts that used to ship here, and what a reader who chose one now gets.
  ///
  /// MeQuran and KFGQPC Uthmani were both retired because neither could draw
  /// the Indo-Pak letterforms the corpus is written in. MeQuran simply has
  /// none of them — ڪ ٮ ی ک ہ ھ ؕ are all absent from its 275-glyph file.
  /// Uthmani is worse: it maps 172 Arabic codepoints onto a single placeholder
  /// glyph with a full letter advance, so its character map claims coverage it
  /// does not have and the text renders as ink dots with letter-wide holes.
  ///
  /// Anyone who had picked either of them wanted something other than Qalam,
  /// so they land on the replacement rather than being silently reset to the
  /// default they had already declined.
  static const Map<String, String> _retiredFonts = {
    'MeQuran': 'Scheherazade',
    'Uthmani': 'Scheherazade',
  };

  static List<String> get validFonts => _validFonts;
  static String get defaultFont => _defaultFont;

  static Future<void> setSelectedFont(String font) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedFontKey, font);
  }

  static Future<String?> getSelectedFont() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedFont = prefs.getString(_selectedFontKey);

    if (savedFont == null) {
      return null;
    }

    if (_validFonts.contains(savedFont)) {
      return savedFont;
    }

    final replacement = _retiredFonts[savedFont] ?? _defaultFont;
    await prefs.setString(_selectedFontKey, replacement);
    return replacement;
  }
}
