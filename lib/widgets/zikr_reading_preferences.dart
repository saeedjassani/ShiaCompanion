import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/analytics_service.dart';
import '../services/preferences_sync_service.dart';
import '../utils/font_preferences.dart';
import '../utils/shared_preferences.dart';
import 'language_settings.dart';
import '../l10n/l10n.dart';

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

/// One of the reader's on/off settings: where it is stored, its default,
/// the global the reader reads it through (if any), and the analytics event
/// a change is counted as. Shared by the Text & reading sheet and Settings,
/// so the two can never write a setting differently.
class ReadingSwitch {
  const ReadingSwitch._(
    this.key,
    this.defaultValue,
    this.feature,
    this.label, [
    this.apply,
  ]);

  final String key;
  final bool defaultValue;
  final String feature;
  final String label;
  final void Function(bool value)? apply;

  static final transliteration = ReadingSwitch._(
    'showTransliteration',
    true,
    'zikr_show_transliteration_toggled',
    'Show transliteration toggled',
    (v) => showTransliteration = v,
  );
  static final translation = ReadingSwitch._(
    'showTranslation',
    true,
    'zikr_show_translation_toggled',
    'Show translation toggled',
    (v) => showTranslation = v,
  );
  static final arabicParagraph = ReadingSwitch._(
    'showArabicAsParagraph',
    false,
    'zikr_show_arabic_as_paragraph_toggled',
    'Show Arabic as paragraph toggled',
    (v) => showArabicAsParagraph = v,
  );
  static const keepScreenOn = ReadingSwitch._(
    'keep_awake',
    true,
    'zikr_keep_awake_toggled',
    'Keep screen on toggled',
  );
  static const shareAsImage = ReadingSwitch._(
    'share_zikr_image',
    false,
    'zikr_share_as_image_toggled',
    'Share as image toggled',
  );
  static const focusMode = ReadingSwitch._(
    zikrFocusModeKey,
    zikrFocusModeDefault,
    'zikr_focus_mode_toggled',
    'Focus mode toggled',
  );

  /// The stored value; Focus mode also honours its legacy key.
  bool get value {
    if (identical(this, focusMode)) return zikrFocusModeEnabled();
    return SP.prefs.getBool(key) ?? defaultValue;
  }

  Future<void> save(bool value) async {
    apply?.call(value);
    await SP.prefs.setBool(key, value);
    unawaited(AnalyticsService.feature(
      feature,
      label: label,
      parameters: {'enabled': value ? 'on' : 'off'},
    ));
  }
}

/// Whether "Arabic as one paragraph" can be turned on: only with both
/// English aids hidden - see isArabicOnlyReadingView.
bool arabicParagraphAvailable() =>
    !ReadingSwitch.transliteration.value && !ReadingSwitch.translation.value;

const double minArabicFontSize = 20;
const double maxArabicFontSize = 44;
const double minEnglishFontSize = 10;
const double maxEnglishFontSize = 24;

/// Sets the Arabic size for this device right away; [commitArabicFontSize]
/// syncs and counts it once the reader has settled on one.
void setArabicFontSizePref(double size) {
  arabicFontSize = size;
  unawaited(SP.prefs.setDouble('ara_font_size', size));
}

void setEnglishFontSizePref(double size) {
  englishFontSize = size;
  unawaited(SP.prefs.setDouble('eng_font_size', size));
}

void commitArabicFontSize() {
  unawaited(AnalyticsService.feature('arabic_font_size_changed',
      label: 'Arabic font size changed'));
  unawaited(PreferencesSyncService.instance.pushArabicFontSize());
}

void commitEnglishFontSize() {
  unawaited(AnalyticsService.feature('english_font_size_changed',
      label: 'English font size changed'));
  unawaited(PreferencesSyncService.instance.pushEnglishFontSize());
}

Future<void> saveArabicFontChoice(String font) async {
  arabicFont = font;
  await FontPreferences.setSelectedFont(font);
  unawaited(AnalyticsService.feature(
    'arabic_font_changed',
    label: 'Arabic font changed',
    parameters: {'font': font},
  ));
  unawaited(PreferencesSyncService.instance.pushArabicFont());
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
    // The paragraph flow only ever shows up once both English aids are
    // hidden - see isArabicOnlyReadingView - so the switch is disabled until
    // then rather than letting the reader turn it on with nothing to show
    // for it.
    final bothAidsOff = arabicParagraphAvailable();

    return Column(
      children: _withDividers([
        // Without this, someone who has already raised App text size sees
        // zikr text larger than these sliders suggest and has no way to know
        // why. The two multiply; neither one rewrites the other.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            context.l10n.readingFineTune,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        if (TranslationLanguageTile.isOffered(context))
          TranslationLanguageTile(leading: _leading(Icons.translate)),
        ListTile(
          leading: _leading(Icons.format_size),
          title: Text(context.l10n.readingArabicFontSize),
          subtitle: Slider(
            activeColor: Theme.of(context).colorScheme.secondary,
            min: minArabicFontSize,
            max: maxArabicFontSize,
            divisions: 12,
            onChanged: (newRating) {
              setState(() {
                setArabicFontSizePref(newRating.toInt().toDouble());
              });
              widget.onChanged?.call();
            },
            // Not onChanged: that fires on every pixel of the drag, which is
            // fine for the local write but would spam the analytics counter
            // and the synced document with dozens of writes for one gesture.
            onChangeEnd: (_) => commitArabicFontSize(),
            value: arabicFontSize,
          ),
          trailing: Text(arabicFontSize.toInt().toString()),
        ),
        ListTile(
          leading: _leading(Icons.text_fields),
          title: Text(context.l10n.readingEnglishFontSize),
          subtitle: Slider(
            activeColor: Theme.of(context).colorScheme.secondary,
            min: minEnglishFontSize,
            max: maxEnglishFontSize,
            divisions: 14,
            onChanged: (val) {
              setState(() {
                setEnglishFontSizePref(val.toInt().toDouble());
              });
              widget.onChanged?.call();
            },
            onChangeEnd: (_) => commitEnglishFontSize(),
            value: englishFontSize,
          ),
          trailing: Text(englishFontSize.toInt().toString()),
        ),
        ListTile(
          leading: _leading(Icons.font_download_outlined),
          title: Text(context.l10n.readingArabicFont),
          subtitle: Text(
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
            style: TextStyle(fontFamily: arabicFont),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(arabicFont),
          onTap: _showFontSelectionDialog,
        ),
        _switchTile(ReadingSwitch.keepScreenOn,
            icon: Icons.screen_lock_portrait,
            title: context.l10n.readingKeepScreenOn),
        _switchTile(ReadingSwitch.focusMode,
            icon: Icons.center_focus_strong,
            title: context.l10n.readingFocusMode,
            subtitle: context.l10n.readingFocusModeSubtitle),
        _switchTile(ReadingSwitch.shareAsImage,
            icon: Icons.ios_share,
            title: context.l10n.readingShareAsImage,
            subtitle: context.l10n.readingShareAsImageSubtitle),
        _switchTile(ReadingSwitch.transliteration,
            icon: Icons.notes,
            title: context.l10n.readingShowTransliteration),
        _switchTile(ReadingSwitch.translation,
            icon: Icons.translate,
            title: context.l10n.readingShowTranslation),
        _switchTile(ReadingSwitch.arabicParagraph,
            icon: Icons.wrap_text,
            title: context.l10n.readingArabicParagraph,
            subtitle: bothAidsOff
                ? context.l10n.readingArabicParagraphOn
                : context.l10n.readingArabicParagraphOff,
            enabled: bothAidsOff),
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
      // Index 1 is the Arabic slider, which the caption above introduces.
      if (index > 1) {
        dividedChildren.add(const Divider(height: 1));
      }
      dividedChildren.add(children[index]);
    }
    return dividedChildren;
  }

  Widget _switchTile(
    ReadingSwitch setting, {
    required IconData icon,
    required String title,
    String? subtitle,
    bool enabled = true,
  }) {
    return SwitchListTile(
      secondary: _leading(icon),
      value: setting.value,
      onChanged: !enabled
          ? null
          : (v) async {
              await setting.save(v);
              widget.onChanged?.call();
              if (!mounted) return;
              setState(() {});
            },
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
    );
  }

  void _onFontChanged(String? font) async {
    if (font == null) return;
    setState(() {
      arabicFont = font;
    });
    await saveArabicFontChoice(font);
    widget.onChanged?.call();
  }

  Future<void> _showFontSelectionDialog() async {
    String? newFont = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.readingArabicFont),
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
