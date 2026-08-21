import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/services/library_service.dart';

/// The bundled book list, and what happens to a slug that no longer exists.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<Map<String, dynamic>>> bundledBooks() async {
    final raw = await rootBundle.loadString('assets/books.json');
    return (json.decode(raw) as List).cast<Map<String, dynamic>>();
  }

  group('bundled book list', () {
    test('every entry has a slug, a title and a unique id', () async {
      final books = await bundledBooks();
      expect(books, isNotEmpty);

      final ids = <dynamic>{};
      final slugs = <String>{};
      for (final b in books) {
        expect(b['slug'], isA<String>().having((s) => s.isNotEmpty, 'set', true));
        expect(b['title'], isA<String>().having((s) => s.isNotEmpty, 'set', true));
        expect(ids.add(b['id']), isTrue, reason: 'duplicate id ${b['id']}');
        expect(slugs.add(b['slug'] as String), isTrue,
            reason: 'duplicate slug ${b['slug']}');
      }
    });

    test('most books name an author', () async {
      final books = await bundledBooks();
      final withAuthor = books
          .where((b) => (b['author'] as String?)?.trim().isNotEmpty ?? false)
          .length;

      // The library's metadata does not credit anyone for a few dozen books,
      // so this is a floor rather than a total.
      expect(withAuthor / books.length, greaterThan(0.9));
    });

    test('an author is never two names run together', () async {
      // Some source metadata concatenates authors with no separator, e.g.
      // "...As-SadrDr. Sachedina", which reads as one mangled name.
      final joined = RegExp(r'[a-z](?=[A-Z][a-z])');
      final offenders = <String>[];
      for (final b in await bundledBooks()) {
        final a = (b['author'] as String?) ?? '';
        // Names like MacIntyre and McElwain legitimately carry an inner
        // capital, so only flag a run that was not already separated.
        for (final part in a.split(' · ')) {
          if (joined.hasMatch(part) &&
              !RegExp(r'\b(Mac|Mc|De|El)[A-Z]').hasMatch(part)) {
            offenders.add('${b['slug']}: $a');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('loadBooks carries the author through', () async {
      final books = await LibraryService.loadBooks();
      expect(books, isNotEmpty);
      expect(books.any((b) => (b.author ?? '').isNotEmpty), isTrue);
    });
  });

  group('retired slugs', () {
    test('a retired slug resolves to the book that replaced it', () async {
      final raw = await rootBundle.loadString('assets/retired_slugs.json');
      final map = (json.decode(raw) as Map).cast<String, dynamic>();
      expect(map, isNotEmpty);

      for (final entry in map.entries) {
        expect(
          await LibraryService.resolveBookSlug(entry.key),
          entry.value,
          reason: '${entry.key} should redirect to ${entry.value}',
        );
      }
    });

    test('every redirect points at a book that still exists', () async {
      final raw = await rootBundle.loadString('assets/retired_slugs.json');
      final map = (json.decode(raw) as Map).cast<String, dynamic>();
      final slugs = (await bundledBooks()).map((b) => b['slug']).toSet();

      for (final entry in map.entries) {
        expect(slugs, contains(entry.value),
            reason: '${entry.key} redirects to a missing book');
        expect(slugs, isNot(contains(entry.key)),
            reason: '${entry.key} was retired but is still listed');
      }
    });

    test('a live slug resolves to itself', () async {
      expect(
        await LibraryService.resolveBookSlug('forty-ahadith-on-ghadir'),
        'forty-ahadith-on-ghadir',
      );
    });

    test('an unknown slug is returned untouched', () async {
      // Resolution must not invent a destination for a slug it has never seen;
      // the caller's own not-found handling should take it from here.
      expect(
        await LibraryService.resolveBookSlug('no-such-book'),
        'no-such-book',
      );
    });
  });
}
