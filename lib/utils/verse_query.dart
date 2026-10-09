import 'quran_index.dart';

/// Reads a typed verse reference: `2:255`, `2 255`, `2/255`, or a surah name
/// and an ayah number - `baqarah 255`, `Al-Baqarah 255`, `surah yasin 1`,
/// `yaseen:1`.
///
/// Both parts are needed: a bare `36` or `yasin` is a surah, which search
/// already finds by its title, not a verse. Null when the text is not a
/// reference, the name matches no surah (or more than one), or the ayah is
/// past the end of the surah.
VerseKey? parseVerseQuery(String input, {List<SurahInfo>? surahs}) {
  final text = input.trim();
  if (text.isEmpty) return null;

  final byNumber = _numericPattern.firstMatch(text);
  if (byNumber != null) {
    return _verse(int.parse(byNumber.group(1)!), byNumber.group(2)!);
  }

  final byName = _namedPattern.firstMatch(text);
  if (byName == null) return null;
  final matches = matchSurahNames(byName.group(1)!, surahs: surahs);
  if (matches.length != 1) return null;
  return _verse(matches.single.number, byName.group(2)!);
}

VerseKey? _verse(int surah, String rawAyah) {
  if (!isSurahNumber(surah)) return null;
  final ayah = int.tryParse(rawAyah);
  if (ayah == null || ayah < 1 || ayah > surahAyahCounts[surah - 1]) {
    return null;
  }
  return VerseKey(surah, ayah);
}

final RegExp _numericPattern = RegExp(r'^(\d{1,3})\s*[:/.\-\s]\s*(\d{1,3})$');
final RegExp _namedPattern =
    RegExp(r'^(\D*[^\d\s:/.\-])[\s:/.\-]*(\d{1,3})$', unicode: true);

/// The surahs whose name [query] spells, as loosely as people type them:
/// with or without the article (`baqarah`, `al-baqarah`), with doubled or
/// single vowels (`yaseen`, `yasin`), the old app spelling kept in each
/// surah's slug (`al-faatehah`), or only the name's last word (`imran`).
///
/// Exact spellings win; failing those, a surah whose name starts with the
/// query (three letters or more, so `baq` finds al-Baqarah). Empty when
/// nothing matches.
List<SurahInfo> matchSurahNames(String query, {List<SurahInfo>? surahs}) {
  final words = _words(query);
  if (words.isNotEmpty && _surahWords.contains(words.first)) {
    words.removeAt(0);
  }
  final key = _key(words);
  if (key.isEmpty) return const [];

  final all = surahs ?? allSurahs();
  final exact = [
    for (final surah in all)
      if (_keysFor(surah).contains(key)) surah,
  ];
  if (exact.isNotEmpty || key.length < 3) return exact;

  return [
    for (final surah in all)
      if (_keysFor(surah).any((candidate) => candidate.startsWith(key))) surah,
  ];
}

/// Every spelling of [surah]'s name [matchSurahNames] accepts, normalised.
Set<String> _keysFor(SurahInfo surah) {
  final name = _words(surah.englishName);
  final slug = _words(surah.slug ?? '');
  // A slug starts with the surah's number ("36-yaseen"), dropped here.
  final keys = {_key(name), _key(slug)};
  // "Ali 'Imran" is often typed as just "imran".
  if (name.length > 1 && name.last.length >= 4) keys.add(_key([name.last]));
  return keys..remove('');
}

/// Lower-case runs of letters: `Ali 'Imran` -> `[ali, imran]`.
List<String> _words(String text) => _letters
    .allMatches(text.toLowerCase())
    .map((match) => match.group(0)!)
    .toList();

final RegExp _letters = RegExp(r'[a-z]+');

const Set<String> _surahWords = {'surah', 'surat', 'sura', 'soorah'};

/// The articles a surah's name may start with (`Al-`, `An-`, `Ash-`...).
const Set<String> _articles = {
  'al',
  'an',
  'ar',
  'as',
  'ash',
  'at',
  'az',
  'ad',
  'adh',
  'ath',
  'el',
};

/// One spelling-insensitive key for a name: the article dropped, long
/// vowels and doubled letters folded, `e` read as `i` and a final `h`
/// dropped, so `Al-Faatehah`, `al fatiha` and `Fatihah` share `fatiha`.
String _key(List<String> words) {
  final rest = words.length > 1 && _articles.contains(words.first)
      ? words.sublist(1)
      : words;
  var key = rest
      .join()
      .replaceAll('ee', 'i')
      .replaceAll('oo', 'u')
      .replaceAll('ou', 'u')
      .replaceAll('e', 'i');
  key = key.replaceAllMapped(_doubled, (match) => match.group(1)!);
  if (key.length > 3 && key.endsWith('h')) {
    key = key.substring(0, key.length - 1);
  }
  return key;
}

final RegExp _doubled = RegExp(r'([a-z])\1+');
