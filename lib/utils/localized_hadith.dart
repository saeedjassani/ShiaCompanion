import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hadith_loader.dart';

/// Where the Arabic, Urdu and Persian hadith of the day come from. English
/// keeps its own, larger collection (assets/hadith/); these readers get the
/// Arabic itself, with a published (or carefully made) translation under it.
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
///      "ar": "...", "ur": "...", "fa": "...",
///      "source": {"ar": "...", "ur": "...", "fa": "..."}}
///   ]
/// }
/// ```
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

  /// Whether [languageCode] has a translation here: Arabic always does.
  bool covers(String languageCode) =>
      languageCode == 'ar' ||
      (general.isNotEmpty && general.first[languageCode] is String);

  /// The hadith for [day] (see [hadithDayNumber]), stepped through each
  /// range the same way as the English collection.
  LocalizedHadith? pick(
    String languageCode, {
    required bool useMuharramQuotes,
    required int day,
  }) {
    if (!covers(languageCode) || general.isEmpty) return null;
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
      source: source[languageCode] ?? source['ar'] ?? '',
    );
  }
}

/// Today's hadith in [languageCode], or null when the collection has no
/// translation into it (English, Gujarati), so the caller shows English.
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
