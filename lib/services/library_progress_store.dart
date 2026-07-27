import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

@immutable
class LibraryProgress {
  const LibraryProgress({
    required this.bookSlug,
    required this.bookTitle,
    required this.chapterSlug,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.pageIndex,
    required this.pageCount,
    required this.fontSize,
    required this.updatedAt,
    this.version = LibraryProgressStore.schemaVersion,
  });

  factory LibraryProgress.fromJson(Map<String, dynamic> json) {
    return LibraryProgress(
      version: json['version'] is int
          ? json['version'] as int
          : int.tryParse(json['version']?.toString() ?? '') ??
              LibraryProgressStore.schemaVersion,
      bookSlug: json['bookSlug']?.toString() ?? '',
      bookTitle: json['bookTitle']?.toString() ?? '',
      chapterSlug: json['chapterSlug']?.toString() ?? '',
      chapterTitle: json['chapterTitle']?.toString() ?? '',
      chapterIndex: json['chapterIndex'] is int
          ? json['chapterIndex'] as int
          : int.tryParse(json['chapterIndex']?.toString() ?? '') ?? -1,
      pageIndex: json['pageIndex'] is int
          ? json['pageIndex'] as int
          : int.tryParse(json['pageIndex']?.toString() ?? '') ?? 0,
      pageCount: json['pageCount'] is int
          ? json['pageCount'] as int
          : int.tryParse(json['pageCount']?.toString() ?? '') ?? 1,
      fontSize: json['fontSize'] is num
          ? (json['fontSize'] as num).toDouble()
          : double.tryParse(json['fontSize']?.toString() ?? '') ?? 18,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final int version;
  final String bookSlug;
  final String bookTitle;
  final String chapterSlug;
  final String chapterTitle;
  final int chapterIndex;
  final int pageIndex;
  final int pageCount;
  final double fontSize;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'bookSlug': bookSlug,
      'bookTitle': bookTitle,
      'chapterSlug': chapterSlug,
      'chapterTitle': chapterTitle,
      'chapterIndex': chapterIndex,
      'pageIndex': pageIndex,
      'pageCount': pageCount,
      'fontSize': fontSize,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }
}

/// Tracks reading progress for the most recently read books, so a reader
/// working through more than one book at a time can resume any of them.
class LibraryProgressStore {
  LibraryProgressStore._();

  static final LibraryProgressStore instance = LibraryProgressStore._();
  static const int schemaVersion = 1;

  /// How many books to keep progress for. Kept small so "Continue Reading"
  /// stays a quick-resume shortcut rather than growing into a full history.
  static const int maxEntries = 3;

  static const String _recentReadsKey = 'library_recent_reads_v1';
  static const String _legacyLastReadKey = 'library_last_read_v1';

  /// The most recently read books, newest first.
  List<LibraryProgress> readAll() {
    if (!SP.isInitialized) return const [];

    final encoded = SP.prefs.getString(_recentReadsKey);
    if (encoded == null || encoded.isEmpty) {
      return _migrateLegacyEntry();
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];

      final entries = decoded
          .whereType<Map>()
          .map((json) => LibraryProgress.fromJson(Map<String, dynamic>.from(json)))
          .where((p) => p.bookSlug.isNotEmpty && p.chapterSlug.isNotEmpty)
          .toList();
      entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return entries;
    } catch (error) {
      debugPrint('Unable to read library progress: $error');
      return const [];
    }
  }

  /// One-time migration from the old single-entry key, so upgrading users
  /// don't lose whatever book they were already resuming.
  List<LibraryProgress> _migrateLegacyEntry() {
    final legacyEncoded = SP.prefs.getString(_legacyLastReadKey);
    if (legacyEncoded == null || legacyEncoded.isEmpty) return const [];

    try {
      final decoded = jsonDecode(legacyEncoded);
      if (decoded is! Map) return const [];
      final progress = LibraryProgress.fromJson(Map<String, dynamic>.from(decoded));
      if (progress.bookSlug.isEmpty || progress.chapterSlug.isEmpty) return const [];

      SP.prefs.setString(_recentReadsKey, jsonEncode([progress.toJson()]));
      SP.prefs.remove(_legacyLastReadKey);
      return [progress];
    } catch (error) {
      debugPrint('Unable to migrate legacy library progress: $error');
      return const [];
    }
  }

  /// Upserts [progress] by book slug (so re-reading a book updates its
  /// existing entry instead of duplicating it), keeping only the
  /// [maxEntries] most recently updated books.
  Future<void> save(LibraryProgress progress) {
    if (!SP.isInitialized) return Future.value();

    final entries = readAll().where((p) => p.bookSlug != progress.bookSlug).toList()
      ..add(progress);
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final capped = entries.take(maxEntries).toList();

    return SP.prefs.setString(
      _recentReadsKey,
      jsonEncode(capped.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> remove(String bookSlug) {
    if (!SP.isInitialized) return Future.value();

    final entries = readAll().where((p) => p.bookSlug != bookSlug).toList();
    return SP.prefs.setString(
      _recentReadsKey,
      jsonEncode(entries.map((p) => p.toJson()).toList()),
    );
  }
}
