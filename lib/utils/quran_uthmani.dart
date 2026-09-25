import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../pages/zikr/zikr_content_parser.dart';

/// The Uthmani (Madinah) Quran script, shown in place of the Indo-Pak surah
/// text when the reader has picked Scheherazade.
///
/// The font picks the script (see `quran_script.dart`). Scheherazade is a Naskh
/// face, and the readers who choose it are mostly reading from an Arab-world
/// mushaf. There is no separate setting.
///
/// The text is the Tanzil Project's Uthmani 1.1, CC BY 3.0, bundled verbatim
/// with its notice at `assets/quran/tanzil-uthmani.txt`. Its terms forbid
/// changing it, so nothing here touches a letter or a mark: a verse is looked
/// up by number and dropped into the line the corpus already has for it. The
/// transliteration and translation lines, the verse numbers the reader indexes
/// by, and the recitation tracker's index (built from the Indo-Pak text by
/// `quran_text_index.dart`) are all unchanged.

const String uthmaniAsset = 'assets/quran/tanzil-uthmani.txt';

/// Whether surahs should be shown in the Uthmani script in [font].
bool usesUthmaniScript(String font) => font == 'Scheherazade';

/// The Tanzil text, verse by verse.
class UthmaniQuran {
  UthmaniQuran._(this._verses, this.bismillah);

  /// `surah -> [ayah 1, ayah 2, ...]`, 1-based surah, 0-based list.
  final Map<int, List<String>> _verses;

  /// Tanzil's own Bismillah, verse 1:1.
  final String bismillah;

  /// The text of [surah]:[ayah], or null if there is no such verse.
  String? verse(int surah, int ayah) {
    final verses = _verses[surah];
    if (verses == null || ayah < 1 || ayah > verses.length) return null;
    return verses[ayah - 1];
  }

  static final RegExp _line = RegExp(r'^(\d+)\|(\d+)\|(.*)$');

  /// Parses Tanzil's `surah|ayah|text` format, skipping the notice.
  ///
  /// Tanzil opens verse 1 of every surah but al-Fatiha and at-Tawbah with the
  /// Bismillah. The corpus gives it a header line of its own, so it is taken
  /// off verse 1 here and served as [bismillah] instead - the same Bismillah,
  /// in the same place on the page, not a change to the text.
  @visibleForTesting
  static UthmaniQuran parse(String raw) {
    final verses = <int, List<String>>{};
    for (final line in raw.split('\n')) {
      final match = _line.firstMatch(line.trimRight());
      if (match == null) continue;
      verses
          .putIfAbsent(int.parse(match.group(1)!), () => [])
          .add(match.group(3)!);
    }
    final bismillah = verses[1]?.first ?? '';
    for (final entry in verses.entries) {
      if (entry.key == 1 || entry.value.isEmpty) continue;
      final first = entry.value.first;
      if (first.startsWith('$bismillah ')) {
        entry.value[0] = first.substring(bismillah.length + 1);
      }
    }
    return UthmaniQuran._(verses, bismillah);
  }

  static Future<UthmaniQuran>? _cached;

  /// Loads and parses the text once per process.
  static Future<UthmaniQuran> load(AssetBundle bundle) {
    return _cached ??= bundle
        .loadString(uthmaniAsset)
        .then(parse)
        .catchError((Object error) {
      _cached = null;
      throw error;
    });
  }
}

// Tanzil sets a space before each pause mark (`عَصَاكَ ۖ`). A mark sitting
// on an ordinary space is a line-break opportunity, so a line could open with
// a stranded ۖ; a no-break space keeps it with its word. Whitespace only.
final RegExp _spaceBeforeMark = RegExp('[ ](?=[ۖ-ۜ])');

/// [data] - a surah document's `data` - with each Arabic verse line swapped
/// for its Tanzil text and the header Bismillah for Tanzil's.
///
/// A verse keeps its trailing ` (N)`, so the reader's medallion and every
/// ayah lookup work exactly as they do on the Indo-Pak text. Any line Tanzil
/// has no verse for is left as it was.
String toUthmani(int surah, String data, UthmaniQuran quran) {
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
    if (text != null) lines[i] = text.replaceAll(_spaceBeforeMark, ' ');
  }
  return lines.join('\n');
}
