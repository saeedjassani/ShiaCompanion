import 'package:flutter/material.dart';

import 'zikr_reading_preferences.dart';

class ZikrSettingsPage extends StatelessWidget {
  const ZikrSettingsPage(this.callback, {Key? key}) : super(key: key);

  final VoidCallback callback;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ZikrReadingPreferencesControls(onChanged: callback),
          ],
        ),
      ),
    );
  }
}
