import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/ziyarat_guide.dart';

const String ziyaratGuideAssetPath = 'assets/ziyarat_guide.json';

String ziyaratGuideTranslationPath(String languageCode) =>
    'assets/ziyarat_guide_i18n/$languageCode.json';

/// Loads the Ziyarat Guide once per language for the life of the app: the
/// files never change under a running build.
class ZiyaratGuideRepository {
  ZiyaratGuideRepository._();

  static final Map<String, Future<ZiyaratGuide>> _cache = {};

  /// The guide in [languageCode] (the app language when omitted). A
  /// [bundle] (tests) bypasses the cache.
  static Future<ZiyaratGuide> load({
    String? languageCode,
    AssetBundle? bundle,
  }) {
    final code = languageCode ?? L10n.current.localeName;
    if (bundle != null) return _load(code, bundle);
    return _cache[code] ??= _load(code, rootBundle);
  }

  static Future<ZiyaratGuide> _load(String code, AssetBundle bundle) async {
    final source =
        json.decode(await bundle.loadString(ziyaratGuideAssetPath)) as Map;
    return ZiyaratGuide.fromJson(
      source.cast<String, dynamic>(),
      languageCode: code,
      translations: code == 'en' ? const {} : await _overlay(code, bundle),
    );
  }

  static Future<Map<String, String>> _overlay(
      String code, AssetBundle bundle) async {
    try {
      final decoded = json
          .decode(await bundle.loadString(ziyaratGuideTranslationPath(code)));
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is String)
            entry.key.toString(): entry.value as String,
      };
    } catch (error) {
      // No overlay for this language yet: names fall back, prose is hidden.
      debugPrint('Ziyarat guide: no $code overlay ($error)');
      return const {};
    }
  }

  @visibleForTesting
  static void clearCache() => _cache.clear();
}
