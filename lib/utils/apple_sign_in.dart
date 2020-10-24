import 'dart:async';

class AppleSignInAvailable {
  AppleSignInAvailable(this.isAvailable);
  final bool isAvailable;

  static Future<bool> check() async {
    return false;
  }
}
