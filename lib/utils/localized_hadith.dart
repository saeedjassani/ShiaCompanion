import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hadith_loader.dart';

/// Where the hadith of the day comes from outside English. English keeps its
/// own, larger collection (assets/hadith/); these readers get the Arabic
/// itself, with a published (or carefully made) translation under it.
const String localizedHadithAsset = 'assets/hadith_i18n/hadith.json';

/// A hadith of the day in [languageCode]: the Arabic as narrated, and - for a
/// language other than Arabic - its translation.
@immutable
class LocalizedHadith {
  const LocalizedHadith({
    required this.languageCode,
    required this.arabic,
    required this.attribution,
    required this.translation,
    required this.source,
  });

  final String languageCode;

  /// The saying itself, without "قال ...".
  final String arabic;

  /// Who said it, in [languageCode]: "قال أمير المؤمنين (ع)",
  /// "امیر المومنین (ع) نے فرمایا".
  final String attribution;

  /// The saying in [languageCode]; null in Arabic, where [arabic] is it.
  final String? translation;

  /// The reference in [languageCode]: "نهج البلاغة، الحكمة 147".
  final String source;

  /// What Share sends: everything the card shows.
  String get shareText => [
        if (translation == null) '$attribution:\n$arabic' else arabic,
        if (translation != null) '$attribution: $translation',
        '[$source]',
      ].join('\n\n');
}

/// The collection in assets/hadith_i18n/hadith.json.
///
/// ```json
/// {
///   "speakers": {"ali": {"ar": "قال أمير المؤمنين (ع)", "ur": "...", "fa": "..."}},
///   "hadith": [
///     {"id": "nb-h-147", "muharram": false, "speaker": "ali",
///      "ar": "...", "ur": "...", "fa": "...", "gu": "...",
///      "source": {"ar": "...", "ur": "...", "fa": "...", "gu": "..."}}
///   ]
/// }
/// ```
///
/// Every hadith has Urdu and Persian; Gujarati only has the ones a
/// published Gujarati translation covers, so a Gujarati reader is only ever
/// shown those.
@immutable
class LocalizedHadithCollection {
  const LocalizedHadithCollection({
    required this.speakers,
    required this.general,
    required this.muharram,
  });

  factory LocalizedHadithCollection.fromJson(Map<String, dynamic> json) {
    final items = (json['hadith'] as List).cast<Map<String, dynamic>>();
    return LocalizedHadithCollection(
      speakers: {
        for (final entry in (json['speakers'] as Map<String, dynamic>).entries)
          entry.key: (entry.value as Map).cast<String, String>(),
      },
      general: [
        for (final item in items)
          if (item['muharram'] != true) item,
      ],
      muharram: [
        for (final item in items)
          if (item['muharram'] == true) item,
      ],
    );
  }

  /// Speaker id ("ali") -> language code -> attribution.
  final Map<String, Map<String, String>> speakers;
  final List<Map<String, dynamic>> general;
  final List<Map<String, dynamic>> muharram;

  /// Whether [item] can be shown in [languageCode]: Arabic always, any
  /// other language only with its translation and reference.
  static bool _has(Map<String, dynamic> item, String languageCode) {
    if (languageCode == 'ar') return true;
    final text = item[languageCode];
    final source = item['source'];
    return text is String &&
        text.trim().isNotEmpty &&
        source is Map &&
        source[languageCode] is String;
  }

  /// Whether [languageCode] has any hadith here.
  bool covers(String languageCode) =>
      general.any((item) => _has(item, languageCode));

  /// The hadith for [day] (see [hadithDayNumber]), stepped through each
  /// range the same way as the English collection, among those translated
  /// into [languageCode].
  LocalizedHadith? pick(
    String languageCode, {
    required bool useMuharramQuotes,
    required int day,
  }) {
    final general = [
      for (final item in this.general)
        if (_has(item, languageCode)) item,
    ];
    final muharram = [
      for (final item in this.muharram)
        if (_has(item, languageCode)) item,
    ];
    if (general.isEmpty) return null;
    final all = [...general, ...muharram];
    final index = selectHadithIndex(
      HadithManifest(
        shardSize: all.length,
        totalQuotes: all.length,
        muharramStart: general.length,
      ),
      useMuharramQuotes: useMuharramQuotes && muharram.isNotEmpty,
      day: day,
    );
    final item = all[index];
    final source = (item['source'] as Map).cast<String, String>();
    return LocalizedHadith(
      languageCode: languageCode,
      arabic: item['ar'] as String,
      attribution: speakers[item['speaker']]?[languageCode] ?? '',
      translation: languageCode == 'ar' ? null : item[languageCode] as String?,
      source: source[languageCode] ?? '',
    );
  }
}

/// Today's hadith in [languageCode], or null in English (which has its own
/// collection) or when the collection cannot be read.
Future<LocalizedHadith?> loadLocalizedHadith(
  AssetBundle bundle, {
  required String languageCode,
  required bool useMuharramQuotes,
  required int day,
}) async {
  if (languageCode == 'en') return null;
  try {
    final collection = LocalizedHadithCollection.fromJson(
      json.decode(await bundle.loadString(localizedHadithAsset))
          as Map<String, dynamic>,
    );
    return collection.pick(
      languageCode,
      useMuharramQuotes: useMuharramQuotes,
      day: day,
    );
  } catch (e) {
    debugPrint('Unable to load the $languageCode hadith: $e');
    return null;
  }
}
