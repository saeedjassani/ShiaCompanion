import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../utils/font_preferences.dart';
import '../utils/shared_preferences.dart';

/// Preference key controlling the reading progress bar on the zikr page.
const String showZikrProgressKey = 'show_zikr_progress';

class ZikrReadingPreferencesControls extends StatefulWidget {
  const ZikrReadingPreferencesControls({
    Key? key,
    this.onChanged,
    this.showLeadingIcons = false,
  }) : super(key: key);

  final VoidCallback? onChanged;
  final bool showLeadingIcons;

  @override
  State<ZikrReadingPreferencesControls> createState() =>
      _ZikrReadingPreferencesControlsState();
}

class _ZikrReadingPreferencesControlsState
    extends State<ZikrReadingPreferencesControls> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: _withDividers([
        ListTile(
          leading: _leading(Icons.format_size),
          title: const Text('Arabic Font Size'),
          subtitle: Slider(
            activeColor: Theme.of(context).colorScheme.secondary,
            min: 20.0,
            max: 44.0,
            divisions: 12,
            onChanged: (newRating) {
              setState(() {
                arabicFontSize = newRating.toInt().toDouble();
              });
              _saveDoublePref('ara_font_size', arabicFontSize);
            },
            value: arabicFontSize,
          ),
          trailing: Text(arabicFontSize.toInt().toString()),
        ),
        ListTile(
          leading: _leading(Icons.text_fields),
          title: const Text('English Font Size'),
          subtitle: Slider(
            activeColor: Theme.of(context).colorScheme.secondary,
            min: 10.0,
            max: 24.0,
            divisions: 14,
            onChanged: (val) {
              setState(() {
                englishFontSize = val.toInt().toDouble();
              });
              _saveDoublePref('eng_font_size', englishFontSize);
            },
            value: englishFontSize,
          ),
          trailing: Text(englishFontSize.toInt().toString()),
        ),
        ListTile(
          leading: _leading(Icons.font_download_outlined),
          title: const Text('Arabic Font'),
          subtitle: Text(
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
            style: TextStyle(fontFamily: arabicFont),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(arabicFont),
          onTap: _showFontSelectionDialog,
        ),
        SwitchListTile(
          secondary: _leading(Icons.screen_lock_portrait),
          value: SP.prefs.getBool('keep_awake') ?? true,
          onChanged: (v) async {
            await _saveBooleanPref("keep_awake", v);
          },
          title: const Text("Keep screen on while reciting Zikr"),
        ),
        SwitchListTile(
          secondary: _leading(Icons.timelapse),
          value: SP.prefs.getBool(showZikrProgressKey) ?? true,
          onChanged: (v) async {
            await _saveBooleanPref(showZikrProgressKey, v);
          },
          title: const Text("Show Reading Progress"),
          subtitle: const Text("Progress bar and estimated reading time."),
        ),
        SwitchListTile(
          secondary: _leading(Icons.ios_share),
          value: SP.prefs.getBool('share_zikr_image') ?? true,
          onChanged: (v) async {
            await _saveBooleanPref('share_zikr_image', v);
          },
          title: const Text("Share Zikr as Image"),
          subtitle: const Text("Create a formatted image when sharing."),
        ),
        SwitchListTile(
          secondary: _leading(Icons.notes),
          value: SP.prefs.getBool('showTransliteration') ?? true,
          onChanged: (v) async {
            showTransliteration = v;
            await _saveBooleanPref("showTransliteration", v);
          },
          title: const Text("Show Transliteration"),
        ),
        SwitchListTile(
          secondary: _leading(Icons.translate),
          value: SP.prefs.getBool('showTranslation') ?? true,
          onChanged: (v) async {
            showTranslation = v;
            await _saveBooleanPref("showTranslation", v);
          },
          title: const Text("Show Translation"),
        ),
      ]),
    );
  }

  Widget? _leading(IconData icon) {
    if (!widget.showLeadingIcons) return null;
    return Icon(icon);
  }

  List<Widget> _withDividers(List<Widget> children) {
    final dividedChildren = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        dividedChildren.add(const Divider(height: 1));
      }
      dividedChildren.add(children[index]);
    }
    return dividedChildren;
  }

  void _saveDoublePref(String key, double value) {
    unawaited(SP.prefs.setDouble(key, value));
    widget.onChanged?.call();
  }

  Future<void> _saveBooleanPref(String key, bool value) async {
    await SP.prefs.setBool(key, value);
    widget.onChanged?.call();
    if (!mounted) return;
    setState(() {});
  }

  void _onFontChanged(String? font) async {
    if (font == null) return;

    setState(() {
      arabicFont = font;
    });
    await FontPreferences.setSelectedFont(font);
    widget.onChanged?.call();
  }

  Future<void> _showFontSelectionDialog() async {
    String? newFont = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Arabic Font'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: FontPreferences.validFonts.map((font) {
              return ListTile(
                leading: Icon(
                  font == arabicFont
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(font),
                subtitle: Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  style: TextStyle(fontFamily: font),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(context).pop(font);
                },
              );
            }).toList(),
          ),
        );
      },
    );

    if (newFont != null) {
      _onFontChanged(newFont);
    }
  }
}
