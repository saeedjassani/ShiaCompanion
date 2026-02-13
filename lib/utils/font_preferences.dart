import 'package:shared_preferences/shared_preferences.dart';

class FontPreferences {
  static const String _selectedFontKey = 'arabic_font';
  static const List<String> _validFonts = ['Qalam', 'MeQuran', 'Uthmani'];
  static const String _defaultFont = 'Qalam';

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

    await prefs.setString(_selectedFontKey, _defaultFont);
    return _defaultFont;
  }
}
