import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

import '../data/uid_title_data.dart';

class LibraryService {
  LibraryService._();

  static const String _libraryBaseUrl =
      'https://raw.githubusercontent.com/saeedjassani/shiavault-library/master/books';

  static List<UidTitleData>? _cachedBooks;
  static final Map<String, List<UidTitleData>> _chapterCache = {};

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

    final response =
        await http.get(Uri.parse('$_libraryBaseUrl/$bookSlug/metadata.yml'));
    if (response.statusCode != 200) {
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
    final response = await http.get(Uri.parse('$_libraryBaseUrl/$slug.md'));
    if (response.statusCode != 200) {
      throw LibraryLoadException(
        'Unable to load this chapter. Please try again.',
        statusCode: response.statusCode,
      );
    }
    return response.body;
  }

  static String _yamlPayload(String body) {
    final parts = body.split('---');
    if (parts.length >= 3) return parts[1].trim();
    return body.trim();
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
