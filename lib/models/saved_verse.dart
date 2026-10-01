import 'package:flutter/foundation.dart';

import '../utils/quran_index.dart';

const int savedVerseSchemaVersion = 1;

/// The key a saved verse is stored under, `"2:255"`.
String savedVerseKey(VerseKey verse) => '${verse.surah}:${verse.ayah}';

/// A verse someone chose to keep.
///
/// The surah name and a short excerpt are denormalised deliberately: the saved
/// list has to render without loading a surah document per row, and someone
/// with forty saved verses would otherwise pull in most of the corpus to draw
/// one screen.
@immutable
class SavedVerse {
  const SavedVerse({
    required this.surah,
    required this.ayah,
    required this.surahName,
    required this.excerpt,
    required this.savedAt,
    this.version = savedVerseSchemaVersion,
  });

  factory SavedVerse.fromJson(Map<String, dynamic> json) {
    return SavedVerse(
      version: json['version'] is int
          ? json['version'] as int
          : int.tryParse(json['version']?.toString() ?? '') ??
              savedVerseSchemaVersion,
      surah: json['surah'] is int
          ? json['surah'] as int
          : int.tryParse(json['surah']?.toString() ?? '') ?? 0,
      ayah: json['ayah'] is int
          ? json['ayah'] as int
          : int.tryParse(json['ayah']?.toString() ?? '') ?? 0,
      surahName: json['surahName']?.toString() ?? '',
      excerpt: json['excerpt']?.toString() ?? '',
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final int version;
  final int surah;
  final int ayah;
  final String surahName;

  /// The opening of the verse, for the list. Empty is fine - the reference
  /// alone still identifies it.
  final String excerpt;

  final DateTime savedAt;

  VerseKey get verse => VerseKey(surah, ayah);

  /// How the verse is keyed wherever a set of them is stored: `"2:255"`.
  String get key => savedVerseKey(verse);

  bool get isValid => surah >= 1 && surah <= surahCount && ayah >= 1;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'surah': surah,
      'ayah': ayah,
      'surahName': surahName,
      if (excerpt.isNotEmpty) 'excerpt': excerpt,
      'savedAt': savedAt.toUtc().toIso8601String(),
    };
  }
}

/// Every verse the reader kept, keyed by [SavedVerse.key].
///
/// Keyed rather than listed so saving or unsaving the same verse twice - the
/// shape an offline retry takes - collapses to one change, with no separate
/// deduplication step.
@immutable
class SavedVersesState {
  SavedVersesState([Map<String, SavedVerse>? verses])
      : verses = Map.unmodifiable(verses ?? const {});

  factory SavedVersesState.fromJson(dynamic value) {
    if (value is! Map) return empty;
    final raw = value['verses'];
    if (raw is! List) return empty;

    final verses = <String, SavedVerse>{};
    for (final entry in raw.whereType<Map>()) {
      final verse = SavedVerse.fromJson(Map<String, dynamic>.from(entry));
      if (verse.isValid) verses[verse.key] = verse;
    }
    return SavedVersesState(verses);
  }

  static final empty = SavedVersesState();

  final Map<String, SavedVerse> verses;

  bool get isEmpty => verses.isEmpty;

  bool contains(VerseKey verse) => verses.containsKey(savedVerseKey(verse));

  /// Every saved verse in mushaf order - a reference list someone builds up
  /// and comes back to, so it reads like an index of their own Quran, not a
  /// feed.
  List<SavedVerse> get inMushafOrder {
    final list = verses.values.toList()
      ..sort((a, b) {
        final bySurah = a.surah.compareTo(b.surah);
        return bySurah != 0 ? bySurah : a.ayah.compareTo(b.ayah);
      });
    return list;
  }

  /// Keeps [verse], replacing an earlier save of the same one so saving
  /// twice cannot produce a duplicate row.
  SavedVersesState save(SavedVerse verse) {
    if (!verse.isValid) return this;
    return SavedVersesState({...verses, verse.key: verse});
  }

  SavedVersesState unsave(String key) {
    if (!verses.containsKey(key)) return this;
    return SavedVersesState({...verses}..remove(key));
  }

  /// Unions two states by verse. Safe to call with the same addition twice -
  /// that is how a guest-to-user import survives being retried.
  SavedVersesState plus(SavedVersesState other) {
    if (other.isEmpty) return this;
    return SavedVersesState({...verses, ...other.verses});
  }

  Map<String, Object> toJson() => {
        'verses': [for (final verse in inMushafOrder) verse.toJson()],
      };
}
