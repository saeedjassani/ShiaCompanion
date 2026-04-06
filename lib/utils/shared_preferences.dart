import 'package:shared_preferences/shared_preferences.dart';

class SP {
  static SharedPreferences? _prefs;

  static SharedPreferences get prefs => _prefs!;
  static bool get isInitialized => _prefs != null;

  static init() async {
    _prefs = await SharedPreferences.getInstance();
  }
}
