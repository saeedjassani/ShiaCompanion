import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_page.dart';
import 'package:shia_companion/utils/quran_index.dart';

void main() {
  group('resolveInitialVerse', () {
    test('opens at the verse when one is named', () {
      expect(
        resolveInitialVerse(const VerseKey(5, 81)),
        const VerseKey(5, 81),
      );
    });

    test('a surah with no ayah opens at the top, not somewhere else', () {
      // The list passes VerseKey(5) meaning "this surah". It is not a verse
      // destination, and resuming is the Continue reciting card's job.
      expect(resolveInitialVerse(const VerseKey(5)), isNull);
    });

    test('nothing asked for is nowhere to go', () {
      expect(resolveInitialVerse(null), isNull);
    });
  });
}
