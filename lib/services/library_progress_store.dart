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

class LibraryProgressStore {
  LibraryProgressStore._();

  static final LibraryProgressStore instance = LibraryProgressStore._();
  static const int schemaVersion = 1;

  static const String _lastReadKey = 'library_last_read_v1';

  LibraryProgress? readLast() {
    if (!SP.isInitialized) return null;

    final encoded = SP.prefs.getString(_lastReadKey);
    if (encoded == null || encoded.isEmpty) return null;

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;

      final progress = LibraryProgress.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (progress.bookSlug.isEmpty || progress.chapterSlug.isEmpty) {
        return null;
      }
      return progress;
    } catch (error) {
      debugPrint('Unable to read library progress: $error');
      return null;
    }
  }

  Future<void> save(LibraryProgress progress) {
    if (!SP.isInitialized) return Future.value();

    return SP.prefs.setString(
      _lastReadKey,
      jsonEncode(progress.toJson()),
    );
  }

  Future<void> removeLast() {
    if (!SP.isInitialized) return Future.value();
    return SP.prefs.remove(_lastReadKey);
  }
}
