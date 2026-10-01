import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/quran_prophet_stories.dart';
import 'package:shia_companion/utils/quran_index.dart';

void main() {
  group('quranProphetStories', () {
    test('every story starts and ends on a real ayah of its surah', () {
      for (final story in quranProphetStories) {
        final count = ayahCountOf(story.verse.surah);
        expect(count, isNotNull,
            reason: 'surah ${story.verse.surah} does not exist');
        expect(
          story.verse.ayah,
          allOf(isNotNull, greaterThanOrEqualTo(1), lessThanOrEqualTo(count!)),
          reason: '${story.title} starts out of range',
        );
        expect(
          story.endAyah,
          allOf(greaterThanOrEqualTo(story.verse.ayah!),
              lessThanOrEqualTo(count)),
          reason: '${story.title} ends out of range',
        );
      }
    });

    test("each prophet's stories sit together, so each gets one heading", () {
      final seen = <String>{};
      String? previous;
      for (final story in quranProphetStories) {
        if (story.prophet != previous) {
          expect(seen.add(story.prophet), isTrue,
              reason: '${story.prophet} appears in two separate runs');
          previous = story.prophet;
        }
      }
    });

    test('every story has a title', () {
      for (final story in quranProphetStories) {
        expect(story.title.trim(), isNotEmpty);
      }
    });
  });
}
