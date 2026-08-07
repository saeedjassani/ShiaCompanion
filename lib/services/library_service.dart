import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';

import '../data/uid_title_data.dart';
import '../utils/network_utils.dart';

class LibraryService {
  LibraryService._();

  static const String _libraryBaseUrl =
      'https://raw.githubusercontent.com/saeedjassani/shiavault-library/master/books';

  static List<UidTitleData>? _cachedBooks;
  static final Map<String, List<UidTitleData>> _chapterCache = {};

  /// Recently fetched chapter markdown, keyed by `bookSlug/chapterSlug`. Kept
  /// small — it exists so paging across a chapter boundary (and prefetching the
  /// chapter ahead) doesn't re-hit the network, not as a full offline store.
  static final Map<String, String> _markdownCache = {};
  static const int _markdownCacheLimit = 8;

  static Future<List<UidTitleData>> loadBooks() async {
    final cached = _cachedBooks;
    if (cached != null) return cached;

    final encodedBooks = await rootBundle.loadString('assets/books.json');
    final decoded = json.decode(encodedBooks);
    if (decoded is! List) return const [];

    final books = decoded
        .whereType<Map>()
        .map((book) {
          final slug = book['slug']?.toString().trim() ?? '';
          final title = book['title']?.toString().trim() ?? '';
          if (slug.isEmpty || title.isEmpty) return null;
          return UidTitleData(slug, title);
        })
        .whereType<UidTitleData>()
        .toList(growable: false);

    _cachedBooks = books;
    return books;
  }

  static Future<List<UidTitleData>> loadChapters(String bookSlug) async {
    final cached = _chapterCache[bookSlug];
    if (cached != null) return cached;

    if (!NetworkUtils().isOnline) {
      // A book saved for offline reading carries its own chapter list, so
      // being offline shouldn't lock the reader out of it.
      final saved = await _savedChaptersOrNull(bookSlug);
      if (saved != null) {
        _chapterCache[bookSlug] = saved;
        return saved;
      }
      throw const LibraryLoadException(
        'Library browsing needs a network connection.',
      );
    }

    final response =
        await http.get(Uri.parse('$_libraryBaseUrl/$bookSlug/metadata.yml'));
    if (response.statusCode != 200) {
      final saved = await _savedChaptersOrNull(bookSlug);
      if (saved != null) {
        _chapterCache[bookSlug] = saved;
        return saved;
      }
      throw LibraryLoadException(
        'Unable to load chapters. Please try again.',
        statusCode: response.statusCode,
      );
    }

    final document = _yamlPayload(response.body);
    final mapData = loadYaml(document);
    final rawChapters = mapData is YamlMap ? mapData['chapters'] : null;
    if (rawChapters is! YamlList) return const [];

    final chapters = rawChapters
        .whereType<YamlMap>()
        .map((chapter) {
          final slug = chapter['slug']?.toString().trim() ?? '';
          final title = chapter['title']?.toString().trim() ?? '';
          if (slug.isEmpty || title.isEmpty) return null;
          return UidTitleData(slug, title);
        })
        .whereType<UidTitleData>()
        .toList(growable: false);

    _chapterCache[bookSlug] = chapters;
    return chapters;
  }

  static Future<String> loadChapterMarkdown(String slug) async {
    final cached = _markdownCache[slug];
    if (cached != null) return cached;

    final saved = await _readSavedChapterMarkdown(slug);
    if (saved != null) {
      _cacheMarkdown(slug, saved);
      return saved;
    }

    if (!NetworkUtils().isOnline) {
      throw const LibraryLoadException(
        'Reading books needs a network connection.',
      );
    }

    final response = await http.get(Uri.parse('$_libraryBaseUrl/$slug.md'));
    if (response.statusCode != 200) {
      throw LibraryLoadException(
        'Unable to load this chapter. Please try again.',
        statusCode: response.statusCode,
      );
    }
    _cacheMarkdown(slug, response.body);
    return response.body;
  }

  /// Loads a chapter into the cache in the background, ignoring failures. Used
  /// to have the next chapter ready before the reader swipes into it.
  static Future<void> prefetchChapterMarkdown(String slug) async {
    if (_markdownCache.containsKey(slug)) return;
    try {
      await loadChapterMarkdown(slug);
    } catch (_) {
      // A prefetch is best-effort; the real load will surface any error.
    }
  }

  static void _cacheMarkdown(String slug, String markdown) {
    if (_markdownCache.length >= _markdownCacheLimit) {
      _markdownCache.remove(_markdownCache.keys.first);
    }
    _markdownCache[slug] = markdown;
  }

  /// The on-disk copy of a chapter, if the book was saved for offline reading.
  /// Returns null on web (no application documents directory) and whenever the
  /// book simply isn't saved.
  static Future<String?> _readSavedChapterMarkdown(String slug) async {
    final separator = slug.lastIndexOf('/');
    if (separator <= 0) return null;

    try {
      return await loadSavedChapterMarkdown(
        slug.substring(0, separator),
        slug.substring(separator + 1),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<UidTitleData>?> _savedChaptersOrNull(
      String bookSlug) async {
    try {
      final saved = await loadSavedChapters(bookSlug);
      return saved.isEmpty ? null : saved;
    } catch (_) {
      return null;
    }
  }

  static String _yamlPayload(String body) {
    final parts = body.split('---');
    if (parts.length >= 3) return parts[1].trim();
    return body.trim();
  }

  static Future<void> saveBookForOffline(String bookSlug, String title) async {
    final chapters = await loadChapters(bookSlug);
    final dir = await _offlineLibraryDir();
    final bookDir = Directory('${dir.path}/$bookSlug');
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }

    final manifest = <String, dynamic>{
      'bookSlug': bookSlug,
      'title': title,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'chapters': chapters.map((c) => {'slug': c.uid, 'title': c.title}).toList(),
    };
    await File('${bookDir.path}/manifest.json')
        .writeAsString(jsonEncode(manifest));

    for (final chapter in chapters) {
      final markdown = await loadChapterMarkdown('$bookSlug/${chapter.uid}');
      await File('${bookDir.path}/${chapter.uid}.md').writeAsString(markdown);
    }
  }

  static Future<void> removeSavedBook(String bookSlug) async {
    final dir = await _offlineLibraryDir();
    final bookDir = Directory('${dir.path}/$bookSlug');
    if (await bookDir.exists()) {
      await bookDir.delete(recursive: true);
    }
  }

  static Future<List<SavedBook>> loadSavedBooks() async {
    final dir = await _offlineLibraryDir();
    if (!await dir.exists()) return const [];

    final entries = await dir.list().toList();
    final saved = <SavedBook>[];

    for (final entry in entries) {
      if (entry is Directory) {
        final manifestFile = File('${entry.path}/manifest.json');
        if (await manifestFile.exists()) {
          try {
            final content = await manifestFile.readAsString();
            final decoded = jsonDecode(content) as Map<String, dynamic>;
            saved.add(SavedBook(
              bookSlug: decoded['bookSlug']?.toString() ?? entry.path.split('/').last,
              title: decoded['title']?.toString() ?? 'Unknown',
              savedAt: DateTime.tryParse(decoded['savedAt']?.toString() ?? '') ?? DateTime.now(),
            ));
          } catch (_) {
            // skip corrupted manifest
          }
        }
      }
    }

    saved.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return saved;
  }

  static Future<bool> isBookSaved(String bookSlug) async {
    final dir = await _offlineLibraryDir();
    final bookDir = Directory('${dir.path}/$bookSlug');
    return await bookDir.exists();
  }

  static Future<String> loadSavedChapterMarkdown(String bookSlug, String chapterSlug) async {
    final dir = await _offlineLibraryDir();
    final file = File('${dir.path}/$bookSlug/$chapterSlug.md');
    if (!await file.exists()) {
      throw const LibraryLoadException('Saved chapter not found.');
    }
    return await file.readAsString();
  }

  static Future<List<UidTitleData>> loadSavedChapters(String bookSlug) async {
    final dir = await _offlineLibraryDir();
    final manifestFile = File('${dir.path}/$bookSlug/manifest.json');
    if (!await manifestFile.exists()) {
      return const [];
    }

    final content = await manifestFile.readAsString();
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    final rawChapters = decoded['chapters'];
    if (rawChapters is! List) return const [];

    return rawChapters
        .whereType<Map>()
        .map((chapter) {
          final slug = chapter['slug']?.toString().trim() ?? '';
          final title = chapter['title']?.toString().trim() ?? '';
          if (slug.isEmpty || title.isEmpty) return null;
          return UidTitleData(slug, title);
        })
        .whereType<UidTitleData>()
        .toList(growable: false);
  }

  static Future<Directory> _offlineLibraryDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/offline_library');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

class LibraryLoadException implements Exception {
  const LibraryLoadException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) return message;
    return '$message ($statusCode)';
  }
}

class SavedBook {
  const SavedBook({
    required this.bookSlug,
    required this.title,
    required this.savedAt,
  });

  final String bookSlug;
  final String title;
  final DateTime savedAt;
}
