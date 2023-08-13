import 'package:shared_preferences/shared_preferences.dart';

class FontPreferences {
  static const String _selectedFontKey = 'arabic_font';

  static Future<void> setSelectedFont(String font) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedFontKey, font);
  }

  static Future<String?> getSelectedFont() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedFontKey);
  }
}
