import 'dart:async';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../utils/font_preferences.dart';
import '../utils/shared_preferences.dart';

class ZikrSettingsPage extends StatefulWidget {
  final Function() callback;
  ZikrSettingsPage(this.callback);

  @override
  _ZikrSettingsPageState createState() => new _ZikrSettingsPageState();
}

class _ZikrSettingsPageState extends State<ZikrSettingsPage> {
  _ZikrSettingsPageState();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: <Widget>[
          Divider(),
          ListTile(
            title: Text('Arabic Font Size'),
            subtitle: Slider(
              activeColor: Theme.of(context).colorScheme.secondary,
              min: 20.0,
              max: 44.0,
              divisions: 12,
              onChanged: (newRating) {
                arabicFontSize = newRating.toInt().toDouble();
                saveDoublePref('ara_font_size', arabicFontSize);
              },
              value: arabicFontSize,
            ),
            trailing: Text(arabicFontSize.toInt().toString()),
          ),
          Divider(),
          ListTile(
            title: Text('English Font Size'),
            subtitle: Slider(
              activeColor: Theme.of(context).colorScheme.secondary,
              min: 10.0,
              max: 24.0,
              divisions: 14,
              onChanged: (val) {
                englishFontSize = val.toInt().toDouble();
                saveDoublePref('eng_font_size', englishFontSize);
              },
              value: englishFontSize,
            ),
            trailing: Text(englishFontSize.toInt().toString()),
          ),
          Divider(),
          ListTile(
            title: Text(
              'Arabic Font',
            ),
            trailing: Text(arabicFont),
            onTap: _showFontSelectionDialog,
          ),
          Divider(),
          SwitchListTile(
            value: SP.prefs.getBool('keep_awake') ?? true,
            onChanged: (v) async {
              await SP.prefs.setBool("keep_awake", v);
              widget.callback();
              setState(() {});
            },
            title: Text("Keep screen on while reciting Zikr"),
          ),
          ...showThreeLineSettings(),
        ],
      ),
    );
  }

  void _onFontChanged(String? font) async {
    if (font != null) {
      setState(() {
        arabicFont = font;
      });
      await FontPreferences.setSelectedFont(font);
      widget.callback();
    }
  }

  Future<void> _showFontSelectionDialog() async {
    String? newFont = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text('Qalam'),
                trailing: Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  style: TextStyle(fontFamily: 'Qalam'),
                ),
                onTap: () {
                  Navigator.of(context).pop('Qalam');
                },
              ),
              ListTile(
                title: Text('MeQuran'),
                trailing: Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  style: TextStyle(fontFamily: 'MeQuran'),
                ),
                onTap: () {
                  Navigator.of(context).pop('MeQuran');
                },
              ),
              ListTile(
                title: Text('Muhammadi'),
                trailing: Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  style: TextStyle(fontFamily: 'Muhammadi'),
                ),
                onTap: () {
                  Navigator.of(context).pop('Muhammadi');
                },
              ),
              ListTile(
                title: Text('Uthmani'),
                trailing: Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  style: TextStyle(fontFamily: 'Uthmani'),
                ),
                onTap: () {
                  Navigator.of(context).pop('Uthmani');
                },
              ),
            ],
          ),
        );
      },
    );

    if (newFont != null) {
      _onFontChanged(newFont);
    }
  }

  saveBooleanPref(String key, bool value) async {
    await SP.prefs.setBool(key, value);
    widget.callback();
    setState(() {});
  }

  saveDoublePref(String key, double value) async {
    await SP.prefs.setDouble(key, value);
    widget.callback();
    setState(() {});
  }

  showThreeLineSettings() {
    if (SP.prefs.getBool('three_line') ?? false) {
      return [
        Divider(),
        SwitchListTile(
          value: SP.prefs.getBool('showTransliteration') ?? true,
          onChanged: (v) async {
            showTransliteration = v;
            await SP.prefs.setBool("showTransliteration", v);
            widget.callback();
            setState(() {});
          },
          title: Text("Show Transliteration"),
        ),
        Divider(),
        SwitchListTile(
          value: SP.prefs.getBool('showTranslation') ?? true,
          onChanged: (v) async {
            showTranslation = v;
            await SP.prefs.setBool("showTranslation", v);
            widget.callback();
            setState(() {});
          },
          title: Text("Show Translation"),
        )
      ];
    }
    return [];
  }
}
