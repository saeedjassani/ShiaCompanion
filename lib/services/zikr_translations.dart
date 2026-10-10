import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../l10n/app_language.dart';

/// Where a language's zikr translations live: `<root>/<code>/index.json` for
/// the titles and audio labels, and `<root>/<code>/<uid>.json` for each
/// translated zikr. See docs/TRANSLATIONS.md for the format.
const String zikrTranslationsRoot = 'assets/zikr_i18n';

String zikrTranslationIndexPath(String languageCode) =>
    '$zikrTranslationsRoot/$languageCode/index.json';

String zikrTranslationDocumentPath(String languageCode, String uid) =>
    '$zikrTranslationsRoot/$languageCode/$uid.json';

/// The translation of one zikr into another language.
///
/// A zikr is read as a run of numbered *segments* - see
/// [ParsedZikrContent.segments]: each Arabic verse is one, each line that
/// stands on its own (an instruction, a heading, a citation) is one, and so
/// is each tab's label. They are numbered 0, 1, 2... through the whole zikr,
/// tab after tab, and a translation is keyed by that number.
///
/// A verse's translation translates the Arabic, so it is keyed to the verse
/// and not to the English line it replaces: fixing the English never
/// orphans it. The numbering is pinned for every translated zikr in
/// scripts/zikr_i18n/segment_anchors.json, and test/zikr_translations_test.dart
/// fails when a corpus edit shifts it - `zikr_i18n.py rebase` renumbers the
/// translations to follow.
@immutable
class ZikrDocumentTranslation {
  const ZikrDocumentTranslation({
    required this.language,
    this.segments = const {},
    this.merits,
  });

  final AppLanguage language;

  /// Segment number -> its translation.
  final Map<int, String> segments;

  /// The whole merits text, translated as one piece of prose.
  final String? merits;

  /// The translation of segment [number], or null when it has none.
  String? segment(int number) {
    final translated = segments[number]?.trim();
    return translated == null || translated.isEmpty ? null : translated;
  }

  bool get isEmpty =>
      segments.isEmpty && (merits == null || merits!.trim().isEmpty);

  factory ZikrDocumentTranslation.fromJson(
    AppLanguage language,
    Map<String, dynamic> json,
  ) {
    final segments = <int, String>{};
    _stringMap(json['segments'], language).forEach((key, value) {
      final number = int.tryParse(key);
      if (number != null && number >= 0) segments[number] = value;
    });
    final rawMerits = json['merits'];
    return ZikrDocumentTranslation(
      language: language,
      segments: segments,
      merits: rawMerits is String && rawMerits.trim().isNotEmpty
          ? language.nativeDigits(rawMerits)
          : null,
    );
  }
}

/// One language's corpus-wide translation data: zikr titles, and the labels
/// and reciters of the recordings in assets/zikr_audio.json.
@immutable
class ZikrTranslationIndex {
  const ZikrTranslationIndex({
    required this.language,
    this.titles = const {},
    this.audioLabels = const {},
    this.reciters = const {},
  });

  final AppLanguage language;

  /// `assets/zikr.json` key -> translated title. An alias key
  /// (`"<uid>|<targetUid>"`) has its own entry, since an alias's title often
  /// differs from its canonical's.
  final Map<String, String> titles;

  /// A recording's `file` in assets/zikr_audio.json -> its translated label.
  final Map<String, String> audioLabels;

  /// A reciter's name as assets/zikr_audio.json spells it -> that name in
  /// this language's script.
  final Map<String, String> reciters;

  factory ZikrTranslationIndex.fromJson(
    AppLanguage language,
    Map<String, dynamic> json,
  ) {
    final audio = json['audio'];
    return ZikrTranslationIndex(
      language: language,
      titles: _stringMap(json['titles'], language),
      audioLabels:
          audio is Map ? _stringMap(audio['labels'], language) : const {},
      reciters: audio is Map ? _stringMap(audio['reciters']) : const {},
    );
  }
}

/// Loads the zikr translations for the reader's chosen translation language.
///
/// English is the corpus itself, so in English there is nothing to load and
/// every lookup returns null.
class ZikrTranslations extends ChangeNotifier {
  ZikrTranslations._();

  static final ZikrTranslations instance = ZikrTranslations._();

  AppLanguage _language = englishLanguage;
  ZikrTranslationIndex? _index;
  final Map<String, Future<ZikrDocumentTranslation?>> _documents = {};
  Future<Set<String>>? _translationAssets;

  /// The language translations are currently being shown in.
  AppLanguage get language => _language;

  bool get isEnglish => _language.code == englishLanguageCode;

  /// Codes of the languages that ship zikr translations, English included.
  ///
  /// Discovered from the bundle rather than listed in code, so adding a
  /// language's folder (and its pubspec entry) is all it takes.
  Future<Set<String>> availableLanguageCodes(AssetBundle bundle) async {
    final assets = await _bundledTranslations(bundle);
    return {
      englishLanguageCode,
      for (final language in appLanguages)
        if (assets.contains(zikrTranslationIndexPath(language.code)))
          language.code,
    };
  }

  /// Every translation file in the bundle, so a zikr nobody has translated
  /// yet is known to be missing without a failed load.
  Future<Set<String>> _bundledTranslations(AssetBundle bundle) {
    return _translationAssets ??= () async {
      try {
        final manifest = await AssetManifest.loadFromAssetBundle(bundle);
        return manifest
            .listAssets()
            .where((path) => path.startsWith('$zikrTranslationsRoot/'))
            .toSet();
      } catch (error) {
        debugPrint('Unable to list zikr translations: $error');
        return <String>{};
      }
    }();
  }

  /// Switches to [code], loading its index. A language with no translations
  /// shipped (or an unknown code) leaves the reader in English.
  ///
  /// In any other language the reader sees no English at all: a zikr shows
  /// its Arabic and whatever of it has been translated, and the English of
  /// everything else is hidden rather than shown in its place.
  Future<void> setLanguage(String code, AssetBundle bundle) async {
    final language = appLanguageFor(code) ?? englishLanguage;
    if (language.code == _language.code && (_index != null || isEnglish)) {
      return;
    }

    _language = language;
    _index = null;
    _documents.clear();
    if (language.code != englishLanguageCode) {
      final index = await _loadIndex(language, bundle);
      // Another switch may have landed while this one was loading.
      if (_language.code != language.code) return;
      _index = index;
      // A language with nothing shipped is not one zikrs can be read in:
      // reading in it would hide all the English and leave nothing in its
      // place.
      if (index == null) _language = englishLanguage;
    }
    notifyListeners();
  }

  Future<ZikrTranslationIndex?> _loadIndex(
    AppLanguage language,
    AssetBundle bundle,
  ) async {
    final available = await availableLanguageCodes(bundle);
    if (!available.contains(language.code)) return null;
    try {
      final raw =
          await bundle.loadString(zikrTranslationIndexPath(language.code));
      final decoded = json.decode(raw);
      if (decoded is! Map) return null;
      return ZikrTranslationIndex.fromJson(
        language,
        Map<String, dynamic>.from(decoded),
      );
    } catch (error) {
      debugPrint('Unable to load ${language.code} zikr translations: $error');
      return null;
    }
  }

  /// The translated title for `assets/zikr.json` key [key], or null to show
  /// the English one.
  String? titleFor(String key) {
    final title = _index?.titles[key]?.trim();
    return title == null || title.isEmpty ? null : title;
  }

  /// [englishTitle], translated when a translation for [key] exists.
  String displayTitle(String key, String englishTitle) =>
      titleFor(key) ?? englishTitle;

  /// The translation of zikr [uid] (the uid whose content file is read, i.e.
  /// an alias's target), or null when the reader is in English or nothing of
  /// this zikr has been translated.
  Future<ZikrDocumentTranslation?> documentFor(
    String uid,
    AssetBundle bundle,
  ) {
    final index = _index;
    if (index == null) return Future.value(null);
    return _documents[uid] ??= _loadDocument(index, uid, bundle);
  }

  Future<ZikrDocumentTranslation?> _loadDocument(
    ZikrTranslationIndex index,
    String uid,
    AssetBundle bundle,
  ) async {
    final path = zikrTranslationDocumentPath(index.language.code, uid);
    try {
      // No file for this zikr means it is untranslated.
      if (!(await _bundledTranslations(bundle)).contains(path)) return null;
      final decoded = json.decode(await bundle.loadString(path));
      if (decoded is! Map) return null;
      final translation = ZikrDocumentTranslation.fromJson(
        index.language,
        Map<String, dynamic>.from(decoded),
      );
      return translation.isEmpty ? null : translation;
    } catch (error) {
      debugPrint('Unable to load ${index.language.code} translation of '
          '$uid: $error');
      return null;
    }
  }

  /// The label of recording [file] as the reader is shown it: in English,
  /// [englishLabel]; in another language, its translation, or null while it
  /// has none - the caller then names the recording some other way (the
  /// zikr's title, "Recording 2"), never in English.
  String? audioLabelFor(String file, String? englishLabel) {
    if (englishLabel == null || isEnglish) return englishLabel;
    final label = _index?.audioLabels[file]?.trim();
    return label == null || label.isEmpty ? null : label;
  }

  /// Reciter [englishName] as the reader is shown it: in English, as is; in
  /// another language, written in that language's script, or null while
  /// nobody has.
  String? reciterName(String englishName) {
    if (isEnglish) return englishName;
    final name = _index?.reciters[englishName]?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  @visibleForTesting
  void debugReset() {
    _language = englishLanguage;
    _index = null;
    _documents.clear();
    _translationAssets = null;
  }
}

/// [raw]'s string entries; with a [language], their values in its digits
/// (a translator's "رمضان کی 13ویں رات" reads "۱۳" in Urdu).
Map<String, String> _stringMap(Object? raw, [AppLanguage? language]) {
  if (raw is! Map) return const {};
  final result = <String, String>{};
  raw.forEach((key, value) {
    if (key is String && value is String && value.trim().isNotEmpty) {
      result[key.trim()] = language?.nativeDigits(value) ?? value;
    }
  });
  return result;
}

/// [englishTitle] of `assets/zikr.json` entry [uid], in the reader's
/// translation language when it has been translated.
///
/// Titles are translated where they are shown, never in the `items` index
/// itself: several things read structure out of the English titles (a surah's
/// number, a deep link's slug), and must keep seeing them.
String zikrDisplayTitle(String uid, String englishTitle) =>
    ZikrTranslations.instance.displayTitle(uid, englishTitle);

/// Whether the reader shows transliteration lines: the reader's own setting,
/// and only while zikrs are read in English. Transliteration is the Arabic
/// spelled out in English letters - an aid for English readers that someone
/// reading in Urdu, Persian, Arabic or Gujarati has no use for.
bool get transliterationShown =>
    showTransliteration && ZikrTranslations.instance.isEnglish;
