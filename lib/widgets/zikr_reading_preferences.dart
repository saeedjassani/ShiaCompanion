import 'dart:async';

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
    false,
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
