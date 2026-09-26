import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../pages/zikr/zikr_content_parser.dart';

/// QuranWBW's IndoPak Quran script, shown in place of the corpus's own surah
/// text when the reader has picked Qalam.
///
/// The text is quranwbw.com's "Madinah Edition" IndoPak text. It is bundled
/// verbatim at `assets/quran/quranwbw-indopak.json` with QuranWBW's written
/// permission (see `assets/fonts/QuranWBW-IndoPak-NOTICE.txt`). The Madinah
/// edition numbers verses exactly as the corpus does, with al-Fatiha's
/// Bismillah as verse 1. QuranWBW's Hanafi edition does not number that
/// Bismillah, so it is not used.
///
/// The text only works in [quranWbwFontFamily]. Pause marks, rukuʿ signs and
/// ayah numbers are private-use codepoints that only this font draws. Qalam
/// uses the same private-use range for different signs, so this text must never
/// be drawn in Qalam.

const String indoPakAsset = 'assets/quran/quranwbw-indopak.json';

/// The font family, as registered in pubspec.yaml.
const String quranWbwFontFamily = 'QuranWBW IndoPak';

/// Whether surahs should be shown in QuranWBW's IndoPak script in [font].
bool usesIndoPakScript(String font) => font == 'Qalam';

/// The QuranWBW text, verse by verse.
class IndoPakQuran {
  IndoPakQuran._(this._verses, this.bismillah);

  /// `surah -> ayah -> text`: the words joined by spaces, then a narrow
  /// no-break space and the verse's end glyphs verbatim (its ayah medallion,
  /// and any rukuʿ sign before it).
  final Map<int, Map<int, String>> _verses;

  /// The Bismillah that heads every surah but al-Fatiha and at-Tawbah:
  /// al-Fatiha's verse 1, without its medallion.
  final String bismillah;

  /// The text of [surah]:[ayah], or null if there is no such verse.
  String? verse(int surah, int ayah) => _verses[surah]?[ayah];

  /// Parses QuranWBW's words file.
  ///
  /// Each verse is `[words, _, [endGlyphs], _]`, keyed by surah and then by
  /// ayah. The two unused fields are always empty in this edition.
  @visibleForTesting
  static IndoPakQuran parse(String raw) {
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final verses = <int, Map<int, String>>{};
    var bismillah = '';
    for (final surahEntry in decoded.entries) {
      final surah = int.parse(surahEntry.key);
      final ayahs = surahEntry.value as Map<String, dynamic>;
      for (final ayahEntry in ayahs.entries) {
        final ayah = int.parse(ayahEntry.key);
        final fields = ayahEntry.value as List<dynamic>;
        final words = (fields[0] as List<dynamic>).cast<String>().join(' ');
        final end = (fields[2] as List<dynamic>).cast<String>().join();
        if (surah == 1 && ayah == 1) bismillah = words;
        // A no-break space holds the medallion to the verse's last word, so
        // it cannot wrap onto a line of its own. The narrow one, U+202F: this
        // font draws U+00A0 with no width at all, and U+202F almost as wide
        // as an ordinary space.
        verses.putIfAbsent(surah, () => {})[ayah] =
            end.isEmpty ? words : '$words\u202F$end';
      }
    }
    return IndoPakQuran._(verses, bismillah);
  }

  static Future<IndoPakQuran>? _cached;

  /// Loads and parses the text once per process.
  static Future<IndoPakQuran> load(AssetBundle bundle) {
    return _cached ??= bundle
        .loadString(indoPakAsset)
        .then(parse)
        .catchError((Object error) {
      _cached = null;
      throw error;
    });
  }
}

/// [data], a surah document's `data`, with each Arabic verse line swapped for
/// its QuranWBW text and the header Bismillah swapped for QuranWBW's.
///
/// A verse keeps its trailing ` (N)`, so every ayah lookup works as it does on
/// the corpus text. [ZikrContentParser.formatArabicText] hides it at display
/// time, because QuranWBW's own medallion already shows the number. Any line
/// QuranWBW has no verse for is left as it was.
String toIndoPak(int surah, String data, IndoPakQuran quran) {
  final lines = data.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!ZikrContentParser.isArabic(line.trim())) continue;
    final ayah = ZikrContentParser.ayahNumberOf(line);
    final String? text;
    if (ayah != null) {
      final verse = quran.verse(surah, ayah);
      text = verse == null ? null : '$verse ($ayah)';
    } else {
      // The one unnumbered Arabic line a surah document carries is its header
      // Bismillah; al-Fatiha numbers its own and at-Tawbah has none.
      text = surah == 1 || surah == 9 ? null : quran.bismillah;
    }
    if (text != null) lines[i] = text;
  }
  return lines.join('\n');
}

// Every private-use codepoint QuranWBW's text carries: pause marks, rukuʿ
// signs, ayah medallions. None of it means anything outside its own font.
final RegExp _privateUse = RegExp('[-]');
final RegExp _runOfSpaces = RegExp(' {2,}');

/// [line] of QuranWBW text as plain Unicode, for copying and sharing: its
/// private-use signs removed, its letters and harakat untouched, its ` (N)`
/// kept.
String indoPakPlainText(String line) => line
    .replaceAll(_privateUse, '')
    .replaceAll('\u202F', ' ')
    .replaceAll(_runOfSpaces, ' ')
    .trim();
