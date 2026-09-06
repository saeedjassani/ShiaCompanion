import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/analytics_service.dart';
import '../services/preferences_sync_service.dart';
import '../utils/font_preferences.dart';
import '../utils/shared_preferences.dart';

/// Whether the reading chrome (progress strip + bottom action bar) auto-hides
/// while reading. Replaces the old [legacyShowZikrProgressKey] switch, which
/// controlled only the progress strip while the action bar auto-hid
/// unconditionally — the two are now one behaviour, so read this through
/// [zikrFocusModeEnabled] rather than the raw key, which does not know about
/// the legacy fallback.
const String zikrFocusModeKey = 'zikr_focus_mode';

/// Focus mode is off for new installs and for anyone who has never touched
/// either setting: chrome that comes and goes on its own is a surprise to a
/// first-time reader, who has no way to know the progress strip and the
/// action bar exist at all once they have slid away. It stays a deliberate
/// opt-in from the reading settings.
const bool zikrFocusModeDefault = false;

/// Superseded by [zikrFocusModeKey]. Kept only so [resolveZikrFocusMode] can
/// translate whatever a returning user had it set to; never read directly
/// elsewhere, and removed from storage by [migrateZikrFocusModePreference].
const String legacyShowZikrProgressKey = 'show_zikr_progress';

/// Pure translation from the old and new keys to one answer, so the
/// migration logic is testable without SharedPreferences.
///
/// Someone who turned the old progress strip off wanted less permanent
/// chrome over the text, so they land on Focus on. It is not a perfect
/// translation — the strip now reappears on a scroll up rather than being
/// gone for good — but it is the closer of the two available states.
bool resolveZikrFocusMode({bool? focusMode, bool? legacyShowProgress}) {
  if (focusMode != null) return focusMode;
  if (legacyShowProgress == false) return true;
  return zikrFocusModeDefault;
}

/// Live read of whether Focus mode is on. Safe to call before [SP.init] —
/// the zikr page can be built from a deep link before preferences finish
/// hydrating — in which case it simply reports the default.
bool zikrFocusModeEnabled() {
  if (!SP.isInitialized) return zikrFocusModeDefault;
  return resolveZikrFocusMode(
    focusMode: SP.prefs.getBool(zikrFocusModeKey),
    legacyShowProgress: SP.prefs.getBool(legacyShowZikrProgressKey),
  );
}

/// One-way, idempotent: folds [legacyShowZikrProgressKey] into
/// [zikrFocusModeKey] and drops the old key. Deliberately safe to skip or run
/// twice — [resolveZikrFocusMode] falls back to the legacy key on its own, so
/// correctness never depends on this having run; it only makes the choice
/// durable and lets the old key be retired. Call once, at startup.
Future<void> migrateZikrFocusModePreference() async {
  if (!SP.isInitialized) return;
  if (!SP.prefs.containsKey(legacyShowZikrProgressKey)) return;

  if (!SP.prefs.containsKey(zikrFocusModeKey)) {
    await SP.prefs.setBool(
      zikrFocusModeKey,
      SP.prefs.getBool(legacyShowZikrProgressKey) == false,
    );
  }
  await SP.prefs.remove(legacyShowZikrProgressKey);
}

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
            // Not onChanged: that fires on every pixel of the drag, which is
            // fine for the local write but would spam the analytics counter
            // and the synced document with dozens of writes for one gesture.
            onChangeEnd: (_) => _onFontSizeChangeEnd(
              feature: 'arabic_font_size_changed',
              label: 'Arabic font size changed',
              push: PreferencesSyncService.instance.pushArabicFontSize,
            ),
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
            onChangeEnd: (_) => _onFontSizeChangeEnd(
              feature: 'english_font_size_changed',
              label: 'English font size changed',
              push: PreferencesSyncService.instance.pushEnglishFontSize,
            ),
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
            await _saveBooleanPref(
              "keep_awake",
              v,
              feature: 'zikr_keep_awake_toggled',
              label: 'Keep screen on toggled',
            );
          },
          title: const Text("Keep screen on while reciting Zikr"),
        ),
        SwitchListTile(
          secondary: _leading(Icons.center_focus_strong),
          value: resolveZikrFocusMode(
            focusMode: SP.prefs.getBool(zikrFocusModeKey),
            legacyShowProgress: SP.prefs.getBool(legacyShowZikrProgressKey),
          ),
          onChanged: (v) async {
            await _saveBooleanPref(
              zikrFocusModeKey,
              v,
              feature: 'zikr_focus_mode_toggled',
              label: 'Focus mode toggled',
            );
          },
          title: const Text("Focus mode"),
          subtitle:
              const Text("Hide the progress bar and action bar while reading. "
                  "Scroll up or tap to bring them back."),
        ),
        SwitchListTile(
          secondary: _leading(Icons.ios_share),
          value: SP.prefs.getBool('share_zikr_image') ?? true,
          onChanged: (v) async {
            await _saveBooleanPref(
              'share_zikr_image',
              v,
              feature: 'zikr_share_as_image_toggled',
              label: 'Share as image toggled',
            );
          },
          title: const Text("Share Zikr as Image"),
          subtitle: const Text("Create a formatted image when sharing."),
        ),
        SwitchListTile(
          secondary: _leading(Icons.notes),
          value: SP.prefs.getBool('showTransliteration') ?? true,
          onChanged: (v) async {
            showTransliteration = v;
            await _saveBooleanPref(
              "showTransliteration",
              v,
              feature: 'zikr_show_transliteration_toggled',
              label: 'Show transliteration toggled',
            );
          },
          title: const Text("Show Transliteration"),
        ),
        SwitchListTile(
          secondary: _leading(Icons.translate),
          value: SP.prefs.getBool('showTranslation') ?? true,
          onChanged: (v) async {
            showTranslation = v;
            await _saveBooleanPref(
              "showTranslation",
              v,
              feature: 'zikr_show_translation_toggled',
              label: 'Show translation toggled',
            );
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

  void _onFontSizeChangeEnd({
    required String feature,
    required String label,
    required Future<void> Function() push,
  }) {
    unawaited(AnalyticsService.feature(feature, label: label));
    unawaited(push());
  }

  Future<void> _saveBooleanPref(
    String key,
    bool value, {
    required String feature,
    required String label,
  }) async {
    await SP.prefs.setBool(key, value);
    unawaited(AnalyticsService.feature(
      feature,
      label: label,
      parameters: {'enabled': value ? 'on' : 'off'},
    ));
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
    unawaited(AnalyticsService.feature(
      'arabic_font_changed',
      label: 'Arabic font changed',
      parameters: {'font': font},
    ));
    unawaited(PreferencesSyncService.instance.pushArabicFont());
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
