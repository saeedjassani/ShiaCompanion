import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

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
    this.version = SavedVersesStore.schemaVersion,
  });

  factory SavedVerse.fromJson(Map<String, dynamic> json) {
    return SavedVerse(
      version: json['version'] is int
          ? json['version'] as int
          : int.tryParse(json['version']?.toString() ?? '') ??
              SavedVersesStore.schemaVersion,
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

/// Verses the reader kept, as a collection rather than a marker.
///
/// Deliberately not [ZikrBookmarkStore]: that holds one record per document and
/// is a "where I left off" marker, so saving a second verse of a surah would
/// destroy the first. These are meant to be kept, so the store is keyed by
/// verse and unbounded, and resuming stays [QuranProgressStore]'s job.
///
/// Stored as one self-describing JSON list rather than a key per verse, so
/// giving it Firestore sync later is a wiring change rather than a migration.
class SavedVersesStore {
  SavedVersesStore._();

  static final SavedVersesStore instance = SavedVersesStore._();
  static const int schemaVersion = 1;

  static const String _storageKey = 'quran_saved_verses_v1';

  /// Every saved verse, in mushaf order.
  ///
  /// Mushaf order rather than most-recent-first: this is a reference list
  /// someone builds up and comes back to, so it should read like an index of
  /// their own Quran, not a feed.
  List<SavedVerse> readAll() {
    if (!SP.isInitialized) return const [];

    final encoded = SP.prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return const [];

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];

      final verses = decoded
          .whereType<Map>()
          .map((entry) => SavedVerse.fromJson(Map<String, dynamic>.from(entry)))
          .where((verse) => verse.isValid)
          .toList();

      _sort(verses);
      return List.unmodifiable(verses);
    } catch (error) {
      debugPrint('Unable to read saved verses: $error');
      return const [];
    }
  }

  bool contains(VerseKey verse) =>
      readAll().any((saved) => saved.verse == verse);

  /// Saves [verse], replacing any earlier record of the same one so saving
  /// twice cannot produce a duplicate row.
  Future<void> add(SavedVerse verse) {
    if (!verse.isValid) return Future.value();

    final verses = readAll().toList()
      ..removeWhere((saved) => saved.verse == verse.verse)
      ..add(verse);
    return _write(verses);
  }

  Future<void> remove(VerseKey verse) {
    final verses = readAll().toList()
      ..removeWhere((saved) => saved.verse == verse);
    return _write(verses);
  }

  Future<void> clear() {
    if (!SP.isInitialized) return Future.value();
    return SP.prefs.remove(_storageKey);
  }

  Future<void> _write(List<SavedVerse> verses) {
    if (!SP.isInitialized) return Future.value();

    _sort(verses);
    return SP.prefs.setString(
      _storageKey,
      jsonEncode(verses.map((verse) => verse.toJson()).toList()),
    );
  }

  static void _sort(List<SavedVerse> verses) {
    verses.sort((a, b) {
      final bySurah = a.surah.compareTo(b.surah);
      return bySurah != 0 ? bySurah : a.ayah.compareTo(b.ayah);
    });
  }
}
