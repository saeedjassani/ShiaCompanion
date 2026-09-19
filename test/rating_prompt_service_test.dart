import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
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
    Future<void> withAge(int days, {required int completions}) => withPrefs({
          'rating_prompt_first_seen_at':
              DateTime.now().millisecondsSinceEpoch - days * dayMs,
          'rating_prompt_completion_count': completions,
        });

    test('is not asked before the minimum age', () async {
      await withAge(6, completions: 10);
      expect(RatingPromptService.shouldAsk(), isFalse);
    });

    test('is not asked before the minimum completion count', () async {
      await withAge(30, completions: 2);
      expect(RatingPromptService.shouldAsk(), isFalse);
    });

    test('is asked once both thresholds are met', () async {
      await withAge(30, completions: 3);
      expect(RatingPromptService.shouldAsk(), isTrue);
    });
  });

  group('after being asked', () {
    test('is not asked again inside the cooldown', () async {
      await withPrefs({
        'rating_prompt_first_seen_at':
            DateTime.now().millisecondsSinceEpoch - 30 * dayMs,
        'rating_prompt_completion_count': 3,
      });
      await RatingPromptService.markAsked();
      expect(RatingPromptService.shouldAsk(), isFalse);
    });

    test('is asked again once the cooldown has elapsed', () async {
      await withPrefs({
        'rating_prompt_first_seen_at':
            DateTime.now().millisecondsSinceEpoch - 300 * dayMs,
        'rating_prompt_completion_count': 3,
        'rating_prompt_last_asked_at':
            DateTime.now().millisecondsSinceEpoch - 121 * dayMs,
      });
      expect(RatingPromptService.shouldAsk(), isTrue);
    });
  });

  group('recordZikrCompleted', () {
    test('counts towards the completion threshold', () async {
      await withPrefs({
        'rating_prompt_first_seen_at':
            DateTime.now().millisecondsSinceEpoch - 30 * dayMs,
      });

      await RatingPromptService.recordZikrCompleted();
      await RatingPromptService.recordZikrCompleted();
      expect(RatingPromptService.shouldAsk(), isFalse);

      await RatingPromptService.recordZikrCompleted();
      expect(RatingPromptService.shouldAsk(), isTrue);
    });
  });

  group('adoptExistingInstall', () {
    test('leaves a genuinely fresh install untouched', () async {
      await withPrefs({});
      await RatingPromptService.adoptExistingInstall();
      expect(SP.prefs.containsKey('rating_prompt_first_seen_at'), isFalse);
      expect(RatingPromptService.shouldAsk(), isFalse);
    });

    test('backfills an install that predates this feature as already '
        'past the thresholds', () async {
      await withPrefs({azaanPreferenceKey: 'makkah'});
      await RatingPromptService.adoptExistingInstall();
      expect(RatingPromptService.shouldAsk(), isTrue);
    });

    test('never overwrites a first-seen stamp this build already wrote',
        () async {
      await withPrefs({azaanPreferenceKey: 'makkah'});
      await RatingPromptService.recordLaunch();
      final stampFromThisBuild =
          SP.prefs.getInt('rating_prompt_first_seen_at');

      await RatingPromptService.adoptExistingInstall();
      expect(
        SP.prefs.getInt('rating_prompt_first_seen_at'),
        stampFromThisBuild,
      );
    });
  });

  test('recordLaunch only stamps first-seen once', () async {
    await withPrefs({});
    await RatingPromptService.recordLaunch();
    final firstStamp = SP.prefs.getInt('rating_prompt_first_seen_at');

    await RatingPromptService.recordLaunch();
    expect(SP.prefs.getInt('rating_prompt_first_seen_at'), firstStamp);
  });

  group('maybeAsk', () {
    // A "yes" hands off to RatingPromptService.requestNativeReview, which
    // reaches the in_app_review plugin's real platform channel. Without a
    // mock handler, flutter_test buffers the call rather than rejecting it,
    // so isAvailable() never completes and the test hangs until its timeout
    // instead of failing fast - this stands in for "no App Store on this
    // CI runner" and makes it resolve to false immediately, same as
    // production would on a device the plugin doesn't support.
    const inAppReviewChannel = MethodChannel('dev.britannio.in_app_review');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(inAppReviewChannel, (call) async {
        if (call.method == 'isAvailable') return false;
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(inAppReviewChannel, null);
    });

    Future<BuildContext> pumpContext(WidgetTester tester) async {
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        context = c;
        return const SizedBox();
      })));
      return context;
    }

    Future<void> withEligibleInstall() => withPrefs({
          'rating_prompt_first_seen_at':
              DateTime.now().millisecondsSinceEpoch - 30 * dayMs,
          'rating_prompt_completion_count': 3,
        });

    testWidgets('does nothing when shouldAsk is false', (tester) async {
      await withPrefs({});
      final context = await pumpContext(tester);

      var promptShown = false;
      await RatingPromptService.maybeAsk(
        context,
        prompt: (_) async {
          promptShown = true;
          return true;
        },
      );

      expect(promptShown, isFalse);
    });

    testWidgets('a "yes" starts the cooldown and skips the feedback prompt',
        (tester) async {
      await withEligibleInstall();
      final context = await pumpContext(tester);

      var feedbackPromptShown = false;
      await RatingPromptService.maybeAsk(
        context,
        prompt: (_) async => true,
        feedbackPrompt: (_) async {
          feedbackPromptShown = true;
          return false;
        },
      );

      expect(feedbackPromptShown, isFalse);
      expect(RatingPromptService.shouldAsk(), isFalse);
    });

    testWidgets('a "no" asks the feedback follow-up, and starts the cooldown '
        'either way', (tester) async {
      await withEligibleInstall();
      final context = await pumpContext(tester);

      var feedbackPromptShown = false;
      await RatingPromptService.maybeAsk(
        context,
        prompt: (_) async => false,
        feedbackPrompt: (_) async {
          feedbackPromptShown = true;
          return false;
        },
      );

      expect(feedbackPromptShown, isTrue);
      expect(RatingPromptService.shouldAsk(), isFalse);
    });

    testWidgets('a dismissal starts the cooldown without asking for feedback',
        (tester) async {
      await withEligibleInstall();
      final context = await pumpContext(tester);

      var feedbackPromptShown = false;
      await RatingPromptService.maybeAsk(
        context,
        prompt: (_) async => null,
        feedbackPrompt: (_) async {
          feedbackPromptShown = true;
          return false;
        },
      );

      expect(feedbackPromptShown, isFalse);
      expect(RatingPromptService.shouldAsk(), isFalse);
    });

    testWidgets('a past "yes" is never asked again, even once the cooldown '
        'would otherwise have elapsed', (tester) async {
      await withPrefs({
        'rating_prompt_first_seen_at':
            DateTime.now().millisecondsSinceEpoch - 300 * dayMs,
        'rating_prompt_completion_count': 3,
        'rating_prompt_last_asked_at':
            DateTime.now().millisecondsSinceEpoch - 121 * dayMs,
        'rating_prompt_has_accepted': true,
      });
      final context = await pumpContext(tester);

      var promptShown = false;
      await RatingPromptService.maybeAsk(
        context,
        prompt: (_) async {
          promptShown = true;
          return true;
        },
      );

      expect(promptShown, isFalse);
    });

    testWidgets('a past "no" is asked again once the cooldown elapses',
        (tester) async {
      await withPrefs({
        'rating_prompt_first_seen_at':
            DateTime.now().millisecondsSinceEpoch - 300 * dayMs,
        'rating_prompt_completion_count': 3,
        'rating_prompt_last_asked_at':
            DateTime.now().millisecondsSinceEpoch - 121 * dayMs,
      });
      final context = await pumpContext(tester);

      var promptShown = false;
      await RatingPromptService.maybeAsk(
        context,
        prompt: (_) async {
          promptShown = true;
          return false;
        },
        feedbackPrompt: (_) async => false,
      );

      expect(promptShown, isTrue);
    });
  });
}
