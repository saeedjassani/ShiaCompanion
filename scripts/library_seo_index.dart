// Turns a checkout of the shiavault-library repo into the one JSON file
// scripts/generate_zikr_seo_pages.js reads to write the /library pages.
//
// The book metadata is YAML with block scalars and wrapped plain scalars, so
// it goes through package:yaml - the same parser LibraryService reads it with
// in the app - rather than a hand-rolled one in the Node generator.
//
// Usage: dart run scripts/library_seo_index.dart <library-checkout> <out.json>
//
// Only books/*/metadata.yml is read, so a sparse checkout is enough:
//   git clone --depth 1 --filter=blob:none --sparse \
//     https://github.com/saeedjassani/shiavault-library <dir>
//   git -C <dir> sparse-checkout set --no-cone '/books/*/metadata.yml'
import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

const _bookFields = [
  'title',
  'subtitle',
  'author',
  'translator',
  'compiler',
  'publisher',
  'description',
  'source_url',
];

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

/// The front matter, cut out exactly as LibraryService._yamlPayload does, so
/// the chapter list is the one the app shows (some files carry a second
/// document after it).
String _yamlPayload(String body) {
  final parts = body.split('---');
  if (parts.length >= 3) return parts[1].trim();
  return body.trim();
}

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
        'Usage: dart run scripts/library_seo_index.dart <library-checkout> <out.json>');
    exit(64);
  }

  final booksDir = Directory('${args[0]}/books');
  if (!booksDir.existsSync()) {
    stderr.writeln('No books/ directory in ${args[0]}');
    exit(66);
  }

  final books = <String, Map<String, Object>>{};
  final dirs = booksDir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final dir in dirs) {
    final file = File('${dir.path}/metadata.yml');
    if (!file.existsSync()) continue;

    final slug = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final yaml = loadYaml(_yamlPayload(file.readAsStringSync()));
    if (yaml is! Map) {
      throw FormatException('$slug/metadata.yml is not a map');
    }

    final book = <String, Object>{};
    for (final field in _bookFields) {
      final value = _text(yaml[field]);
      if (value != null) book[field] = value;
    }
    final chapters = yaml['chapters'];
    book['chapters'] = [
      if (chapters is List)
        for (final chapter in chapters)
          // A chapter without a slug is dropped by the app too.
          if (chapter is Map &&
              _text(chapter['slug']) != null &&
              _text(chapter['title']) != null)
            _text(chapter['title'])!,
    ];
    books[slug] = book;
  }

  File(args[1]).writeAsStringSync(jsonEncode(books));
  stdout.writeln('Wrote ${books.length} books to ${args[1]}');
}
