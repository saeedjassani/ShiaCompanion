import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/services/rating_prompt_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

void main() {
  Future<void> withPrefs(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    await SP.init();
  }

  const dayMs = 24 * 60 * 60 * 1000;

  group('a fresh install', () {
    test('is never asked before recordLaunch has run once', () async {
      await withPrefs({});
      expect(RatingPromptService.shouldAsk(), isFalse);
    });

    test('is still not asked right after its first launch', () async {
      await withPrefs({});
      await RatingPromptService.recordLaunch();
      expect(RatingPromptService.shouldAsk(), isFalse);
    });
  });

  group('an install old and used enough', () {
    Future<void> withAge(int days, {required int launches}) => withPrefs({
          'rating_prompt_first_seen_at':
              DateTime.now().millisecondsSinceEpoch - days * dayMs,
          'rating_prompt_launch_count': launches,
        });

    test('is not asked before the minimum age', () async {
      await withAge(6, launches: 10);
      expect(RatingPromptService.shouldAsk(), isFalse);
    });

    test('is not asked before the minimum launch count', () async {
      await withAge(30, launches: 4);
      expect(RatingPromptService.shouldAsk(), isFalse);
    });

    test('is asked once both thresholds are met', () async {
      await withAge(30, launches: 10);
      expect(RatingPromptService.shouldAsk(), isTrue);
    });
  });

  group('after being asked', () {
    test('is not asked again inside the cooldown', () async {
      await withPrefs({
        'rating_prompt_first_seen_at':
            DateTime.now().millisecondsSinceEpoch - 30 * dayMs,
        'rating_prompt_launch_count': 10,
      });
      await RatingPromptService.markAsked();
      expect(RatingPromptService.shouldAsk(), isFalse);
    });

    test('is asked again once the cooldown has elapsed', () async {
      await withPrefs({
        'rating_prompt_first_seen_at':
            DateTime.now().millisecondsSinceEpoch - 300 * dayMs,
        'rating_prompt_launch_count': 10,
        'rating_prompt_last_asked_at':
            DateTime.now().millisecondsSinceEpoch - 121 * dayMs,
      });
      expect(RatingPromptService.shouldAsk(), isTrue);
    });
  });

  test('recordLaunch only stamps first-seen once', () async {
    await withPrefs({});
    await RatingPromptService.recordLaunch();
    final firstStamp = SP.prefs.getInt('rating_prompt_first_seen_at');

    await RatingPromptService.recordLaunch();
    expect(SP.prefs.getInt('rating_prompt_first_seen_at'), firstStamp);
    expect(SP.prefs.getInt('rating_prompt_launch_count'), 2);
  });
}
