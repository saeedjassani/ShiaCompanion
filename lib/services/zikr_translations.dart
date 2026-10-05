import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/app_language.dart';

/// Where a language's zikr translations live: `<root>/<code>/index.json` for
/// the titles and the lines shared across the corpus, and
/// `<root>/<code>/<uid>.json` for each translated zikr. See
/// docs/TRANSLATIONS.md for the format.
const String zikrTranslationsRoot = 'assets/zikr_i18n';

String zikrTranslationIndexPath(String languageCode) =>
    '$zikrTranslationsRoot/$languageCode/index.json';

String zikrTranslationDocumentPath(String languageCode, String uid) =>
    '$zikrTranslationsRoot/$languageCode/$uid.json';

/// The translation of one zikr's English into another language.
///
/// Lines are matched by their English text, not by position: the corpus is
/// still being edited (restored zikrs, Arabic proofreading), and an inserted
/// verse would shift every positional translation after it onto the wrong
/// line. Matched by text, an English line that changes simply shows in
/// English until its translation is updated - see
/// scripts/zikr_i18n/zikr_i18n.py, which reports those.
@immutable
class ZikrDocumentTranslation {
  const ZikrDocumentTranslation({
    required this.language,
    this.lines = const {},
    this.sharedLines = const {},
    this.merits,
  });

  final AppLanguage language;

  /// English line (trimmed, exactly as in the zikr's `data` or `tabs`) ->
  /// its translation, for this zikr alone.
  final Map<String, String> lines;

  /// Lines translated once for the whole corpus - the Bismillah, the salawat -
  /// consulted when [lines] has no entry of its own.
  final Map<String, String> sharedLines;

  /// The whole merits text, translated as one piece of prose.
  final String? merits;

  /// The translation of [englishLine], or null to keep the English.
  String? lineFor(String englishLine) {
    final key = englishLine.trim();
    if (key.isEmpty) return null;
    final translated = lines[key] ?? sharedLines[key];
    if (translated == null || translated.trim().isEmpty) return null;
    return translated.trim();
  }

  bool get isEmpty =>
      lines.isEmpty &&
      sharedLines.isEmpty &&
      (merits == null || merits!.trim().isEmpty);
}

/// One language's corpus-wide translation data: zikr titles and the lines
/// many zikrs share.
@immutable
class ZikrTranslationIndex {
  const ZikrTranslationIndex({
    required this.language,
    this.titles = const {},
    this.sharedLines = const {},
  });

  final AppLanguage language;

  /// `assets/zikr.json` key -> translated title. An alias key
  /// (`"<uid>|<targetUid>"`) has its own entry, since an alias's title often
  /// differs from its canonical's.
  final Map<String, String> titles;

  final Map<String, String> sharedLines;

  factory ZikrTranslationIndex.fromJson(
    AppLanguage language,
    Map<String, dynamic> json,
  ) {
    return ZikrTranslationIndex(
      language: language,
      titles: _stringMap(json['titles']),
      sharedLines: _stringMap(json['lines']),
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
  /// this zikr has been translated - not even a line the corpus shares.
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
    var lines = const <String, String>{};
    String? merits;
    final path = zikrTranslationDocumentPath(index.language.code, uid);
    try {
      // No file for this zikr means it is untranslated, apart from whatever
      // shared lines it happens to contain.
      if ((await _bundledTranslations(bundle)).contains(path)) {
        final decoded = json.decode(await bundle.loadString(path));
        if (decoded is Map) {
          lines = _stringMap(decoded['lines']);
          final rawMerits = decoded['merits'];
          if (rawMerits is String && rawMerits.trim().isNotEmpty) {
            merits = rawMerits;
          }
        }
      }
    } catch (error) {
      debugPrint('Unable to load ${index.language.code} translation of '
          '$uid: $error');
    }

    final translation = ZikrDocumentTranslation(
      language: index.language,
      lines: lines,
      sharedLines: index.sharedLines,
      merits: merits,
    );
    return translation.isEmpty ? null : translation;
  }

  @visibleForTesting
  void debugReset() {
    _language = englishLanguage;
    _index = null;
    _documents.clear();
    _translationAssets = null;
  }
}

Map<String, String> _stringMap(Object? raw) {
  if (raw is! Map) return const {};
  final result = <String, String>{};
  raw.forEach((key, value) {
    if (key is String && value is String && value.trim().isNotEmpty) {
      result[key.trim()] = value;
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
