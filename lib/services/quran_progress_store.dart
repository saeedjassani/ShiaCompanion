import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

/// Where the reader had reached in their recitation.
@immutable
class QuranProgress {
  const QuranProgress({
    required this.surah,
    required this.ayah,
    required this.surahTitle,
    required this.updatedAt,
    this.version = QuranProgressStore.schemaVersion,
  });

  factory QuranProgress.fromJson(Map<String, dynamic> json) {
    return QuranProgress(
      version: json['version'] is int
          ? json['version'] as int
          : int.tryParse(json['version']?.toString() ?? '') ??
              QuranProgressStore.schemaVersion,
      surah: json['surah'] is int
          ? json['surah'] as int
          : int.tryParse(json['surah']?.toString() ?? '') ?? 0,
      ayah: json['ayah'] is int
          ? json['ayah'] as int
          : int.tryParse(json['ayah']?.toString() ?? '') ?? 0,
      surahTitle: json['surahTitle']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final int version;
  final int surah;
  final int ayah;
  final String surahTitle;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'surah': surah,
      'ayah': ayah,
      'surahTitle': surahTitle,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }
}

/// The reader's place in their daily recitation - one position for the whole
/// Quran, not one per surah.
///
/// Deliberately separate from [ZikrBookmarkStore], which stays what it is: an
/// explicit, per-zikr bookmark the reader sets by hand. This is the implicit
/// one, and only sequential reading moves it. Looking a verse up - from a
/// shared link, or the go-to-verse box - must not cost someone the place they
/// had reached, so the writes here are gated on a real scroll having happened
/// (see `QuranReadingPosition.fromUserScroll`).
class QuranProgressStore {
  QuranProgressStore._();

  static final QuranProgressStore instance = QuranProgressStore._();
  static const int schemaVersion = 1;

  static const String _storageKey = 'quran_progress_v1';

  QuranProgress? read() {
    if (!SP.isInitialized) return null;

    final encoded = SP.prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return null;

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;

      final progress = QuranProgress.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (progress.surah < 1 || progress.ayah < 1) return null;
      return progress;
    } catch (error) {
      debugPrint('Unable to read Quran progress: $error');
      return null;
    }
  }

  Future<void> save(QuranProgress progress) {
    if (!SP.isInitialized) return Future.value();
    return SP.prefs.setString(_storageKey, jsonEncode(progress.toJson()));
  }

  Future<void> clear() {
    if (!SP.isInitialized) return Future.value();
    return SP.prefs.remove(_storageKey);
  }
}
