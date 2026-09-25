import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import 'quran_index.dart';
import 'quran_indopak.dart';
import 'quran_uthmani.dart';

/// Which Quran script the surahs are shown in. The Arabic font decides:
///
/// - Qalam: QuranWBW's IndoPak text, drawn in QuranWBW's own font
///   (`quran_indopak.dart`).
/// - Scheherazade: Tanzil's Uthmani text (`quran_uthmani.dart`).
///
/// Either way only the Arabic verse lines change. Transliteration, translation,
/// verse numbers and the recitation tracker's index (built from the corpus
/// text by `quran_text_index.dart`) are the same in every script.

/// The key a document carries the font its Arabic must be drawn in under,
/// when that is not simply [arabicFont].
const String arabicFontFamilyKey = 'arabicFontFamily';

/// The key a document records the [arabicFont] its script was chosen for
/// under, so the reader can tell when a font change calls for a reload.
const String quranScriptFontKey = 'quranScriptFont';

/// A Quran script, loaded and ready to swap into surah documents.
class QuranScript {
  const QuranScript._(this.font, this.fontFamily, this._swap);

  /// The [arabicFont] this script is shown for.
  final String font;

  /// The font family this script's text must be drawn in.
  final String fontFamily;

  final String Function(int surah, String data) _swap;

  /// [data], a surah document's `data`, in this script.
  String apply(int surah, String data) => _swap(surah, data);

  /// [document], surah [surah], in this script and tagged with its font.
  Map<String, dynamic> applyTo(int surah, Map<String, dynamic> document) => {
        ...document,
        'data': apply(surah, document['data']?.toString() ?? ''),
        arabicFontFamilyKey: fontFamily,
        quranScriptFontKey: font,
      };
}

/// The script [font] (by default the current [arabicFont]) shows surahs in,
/// or null to show the corpus text as authored.
///
/// Also null when the script's asset fails to load: the corpus text is still
/// a complete Quran, so it is shown rather than nothing.
Future<QuranScript?> loadQuranScript(AssetBundle bundle, {String? font}) async {
  final selected = font ?? arabicFont;
  try {
    if (usesIndoPakScript(selected)) {
      final quran = await IndoPakQuran.load(bundle);
      return QuranScript._(selected, quranWbwFontFamily,
          (surah, data) => toIndoPak(surah, data, quran));
    }
    if (usesUthmaniScript(selected)) {
      final quran = await UthmaniQuran.load(bundle);
      return QuranScript._(
          selected, selected, (surah, data) => toUthmani(surah, data, quran));
    }
  } catch (error) {
    debugPrint('Quran script for $selected unavailable, showing the corpus '
        'text: $error');
  }
  return null;
}

/// [document] as the reader should show it in the current [arabicFont]:
/// untouched unless [uid] is a surah.
Future<Map<String, dynamic>> applyQuranScript(
  String uid,
  Map<String, dynamic> document,
  AssetBundle bundle,
) async {
  final surah = surahForUid(uid);
  if (surah == null) return document;
  final script = await loadQuranScript(bundle);
  return script == null ? document : script.applyTo(surah, document);
}

/// The font family [document]'s Arabic is drawn in.
String arabicFontFamilyOf(Map<String, dynamic>? document) {
  final family = document?[arabicFontFamilyKey];
  return family is String && family.isNotEmpty ? family : arabicFont;
}
