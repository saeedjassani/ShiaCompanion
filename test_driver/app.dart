import 'package:flutter/material.dart';
import 'package:shia_companion/main.dart' as app;
import 'package:flutter_driver/driver_extension.dart';

main() {
  enableFlutterDriverExtension();
  WidgetsApp.debugAllowBannerOverride = false;
  app.main();
}
