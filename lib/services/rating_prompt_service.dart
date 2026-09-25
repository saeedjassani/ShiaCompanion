import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';

import '../constants.dart' show appNavigatorKey;
import '../utils/external_launch.dart';
import '../utils/shared_preferences.dart';
import '../widgets/rating_prompt_dialog.dart';
import 'analytics_service.dart';
import 'azaan_opt_in_service.dart';
import 'azan_playback_service.dart';

/// How the "enjoying the app?" question gets put to the user, and how the
/// "not really" follow-up does. Injectable so tests can answer either
/// without pumping a real dialog - see [AzaanOptInPrompt] for the same idea.
typedef RatingPrompt = Future<bool?> Function(BuildContext context);
typedef RatingFeedbackPrompt = Future<bool> Function(BuildContext context);

/// Owns the "enjoying the app?" rating prompt: when it is fair to ask, and
/// handing off to the OS's own review sheet once someone says yes.
///
/// Never asks on a new install - [shouldAsk] requires an install old enough,
/// and enough real recitations behind it, to have an opinion worth asking
/// about - and never asks too often after that, tracked by [_lastAskedKey].
/// A "yes" stops it from ever asking again at all, tracked by
/// [_hasAcceptedKey] - see that field for why. It does not gate on how many
/// times the app has been opened: a real moment of engagement (see
/// [recordZikrCompleted] and zikr_page.dart's `_maybeRecordCompletion`, which
/// already tells a finished recitation apart from a stray tap, and
/// [recordPositiveAction]) is a far better signal than a raw launch count.
///
/// That moment earns the question but is never when it gets asked: reaching
/// the end of a zikr's scroll only means its last lines have come into view,
/// and someone saving or sharing a passage is usually still reading. Both
/// just leave an ask pending, and it is put to the user once no reader is
/// open any more - i.e. after they have left the zikr page and landed back
/// on a list or home. See [readerOpened]/[readerClosed].
///
/// The actual review UI is left entirely to the platform
/// ([InAppReview.requestReview]: `SKStoreReviewController` on iOS, the Play
/// In-App Review API on Android), which the OS throttles on its own and never
/// tells us whether it was shown or what was picked - so [markAsked] is the
/// only bookkeeping this side does, regardless of which button the caller's
/// own pre-screen dialog got.
///
/// [adoptExistingInstall] keeps an install that predates this feature from
/// having its clock reset to zero the moment it updates: without it, someone
/// who has had the app for years would be treated exactly like a fresh
/// install on the update that ships this file, and made to wait out the age
/// and completion thresholds all over again.
class RatingPromptService {
  const RatingPromptService._();

  static const String _firstSeenKey = 'rating_prompt_first_seen_at';
  static const String _completionCountKey = 'rating_prompt_completion_count';
  static const String _lastAskedKey = 'rating_prompt_last_asked_at';

  /// Set the moment someone taps "Yes!" - once true, [shouldAsk] refuses
  /// forever, cooldown or not. Neither StoreKit nor the Play In-App Review
  /// API ever tells us whether a rating was actually left, so this is the
  /// closest proxy we get: someone who already said yes has nothing to gain
  /// from being asked again, only annoyance to lose. A "no" or a dismissal
  /// leaves this unset, so [_cooldown] still applies to them - their answer
  /// might genuinely change after more time with the app.
  static const String _hasAcceptedKey = 'rating_prompt_has_accepted';

  /// However positive someone feels on day one, they have not used the app
  /// enough yet to have an opinion worth asking about.
  static const Duration _minAgeSinceInstall = Duration(days: 7);

  /// One finished recitation could still be a fluke of the length/duration
  /// heuristic in zikr_page.dart's `_maybeRecordCompletion`; a few in a row is
  /// a real pattern of use.
  static const int _minCompletions = 3;

  /// Roughly what Apple's own yearly cap on `requestReview` amounts to per
  /// ask, so this side never burns through more asks than the OS would honour
  /// anyway.
  static const Duration _cooldown = Duration(days: 120);

  /// App Store Connect > General > App Information > Apple ID. Only iOS/macOS
  /// need it - Android and Windows resolve the store listing from the app's
  /// own package id instead.
  static const String _appStoreId = '1492517189';

  /// Backfills an install that predates this feature as already past the age
  /// and completion thresholds, using the same "has this install run a build
  /// older than mine" signal [AzaanOptInService.adoptChoiceFromExistingInstall]
  /// and [WhatsNewService] already rely on. A genuinely fresh install has none
  /// of those markers and is left alone, to start its clock at zero exactly
  /// as [recordLaunch] would anyway.
  ///
  /// Call once per launch, before [recordLaunch] - it only ever writes once,
  /// the first time this build's tracking key doesn't exist yet.
  static Future<void> adoptExistingInstall() async {
    if (!SP.isInitialized) return;
    if (SP.prefs.containsKey(_firstSeenKey)) return;
    if (!AzaanOptInService.priorInstallMarkerKeys.any(SP.prefs.containsKey)) {
      return;
    }

    final backfilledFirstSeen =
        DateTime.now().subtract(_minAgeSinceInstall).millisecondsSinceEpoch;
    await SP.prefs.setInt(_firstSeenKey, backfilledFirstSeen);
    await SP.prefs.setInt(_completionCountKey, _minCompletions);
  }

  /// Records a real, finished recitation - not just a zikr opened - so
  /// [shouldAsk] can count up towards [_minCompletions], and leaves an ask
  /// pending for when the reader is left (see [readerClosed]). Never asks by
  /// itself: the reader is very likely still on the last lines.
  static Future<void> recordZikrCompleted() async {
    if (!SP.isInitialized) return;
    final completions = SP.prefs.getInt(_completionCountKey) ?? 0;
    // Set before the write's await, so a completion recorded from a reader's
    // dispose is already pending when that same dispose calls [readerClosed].
    _pendingAsk = true;
    await SP.prefs.setInt(_completionCountKey, completions + 1);
  }

  /// Records a cold start. Call once per launch, before [shouldAsk] - it is
  /// what [shouldAsk] measures "how long installed" against.
  static Future<void> recordLaunch() async {
    if (!SP.isInitialized) return;
    if (!SP.prefs.containsKey(_firstSeenKey)) {
      await SP.prefs
          .setInt(_firstSeenKey, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Whether this is a fair moment to put the "enjoying the app?" question to
  /// the user - called right before [maybeAsk] actually does.
  static bool shouldAsk() {
    if (!SP.isInitialized) return false;
    if (SP.prefs.getBool(_hasAcceptedKey) == true) return false;

    final firstSeenMs = SP.prefs.getInt(_firstSeenKey);
    if (firstSeenMs == null) return false;
    final firstSeen = DateTime.fromMillisecondsSinceEpoch(firstSeenMs);
    if (DateTime.now().difference(firstSeen) < _minAgeSinceInstall) {
      return false;
    }

    final completions = SP.prefs.getInt(_completionCountKey) ?? 0;
    if (completions < _minCompletions) return false;

    final lastAskedMs = SP.prefs.getInt(_lastAskedKey);
    if (lastAskedMs != null) {
      final lastAsked = DateTime.fromMillisecondsSinceEpoch(lastAskedMs);
      if (DateTime.now().difference(lastAsked) < _cooldown) return false;
    }

    return true;
  }

  /// Records that the question was put to the user this launch, whichever way
  /// (or whether) it was answered. Starts the cooldown before the next ask.
  static Future<void> markAsked() async {
    if (!SP.isInitialized) return;
    await SP.prefs.setInt(_lastAskedKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Puts the "enjoying the app?" pre-screen to the user if [shouldAsk] says
  /// this is a fair moment, then routes to whichever follow-up the answer
  /// earns: the OS review sheet for a "yes", a second, skippable ask before a
  /// feedback email for a "no" - jumping straight to the mail app the moment
  /// someone admits they aren't enjoying it would be its own bad experience.
  /// A dismissal counts as neither and just starts the cooldown, same as an
  /// explicit "not now" would.
  static Future<void> maybeAsk(
    BuildContext context, {
    RatingPrompt prompt = showRatingPromptDialog,
    RatingFeedbackPrompt feedbackPrompt = showRatingFeedbackDialog,
  }) async {
    if (!shouldAsk()) return;
    if (!context.mounted) return;

    final enjoying = await prompt(context);
    await markAsked();
    unawaited(AnalyticsService.feature(
      'rating_prompt',
      label: 'Rating prompt',
      parameters: {
        'choice': switch (enjoying) {
          true => 'enjoying',
          false => 'not_enjoying',
          null => 'dismissed',
        },
      },
    ));

    if (enjoying == true) {
      await SP.prefs.setBool(_hasAcceptedKey, true);
      await requestNativeReview();
      return;
    }
    if (enjoying == false && context.mounted) {
      final sendFeedback = await feedbackPrompt(context);
      unawaited(AnalyticsService.feature(
        'rating_prompt_feedback',
        label: 'Rating prompt feedback follow-up',
        parameters: {'choice': sendFeedback ? 'sent' : 'declined'},
      ));
      if (sendFeedback) {
        await launchSupportEmail(subject: 'Shia Companion | Feedback');
      }
    }
  }

  /// Hands off to the platform's own review sheet. A no-op wherever the OS
  /// doesn't support one (web, desktop, an unsupported OS version) - checked
  /// by the plugin itself via [InAppReview.isAvailable].
  static Future<void> requestNativeReview() async {
    final inAppReview = InAppReview.instance;
    if (!await inAppReview.isAvailable()) return;
    try {
      await inAppReview.requestReview();
    } catch (error) {
      debugPrint('RatingPromptService: requestReview failed: $error');
    }
  }

  /// Opens the store listing directly - no quota, no cooldown, no gating on
  /// [shouldAsk]. This is the permanent "Rate us" entry point in Settings,
  /// which the plugin's own guidance calls for precisely because
  /// [requestNativeReview] can never be relied on to actually show anything.
  static Future<void> openStoreListing() async {
    if (kIsWeb) return;
    try {
      await InAppReview.instance.openStoreListing(appStoreId: _appStoreId);
    } catch (error) {
      debugPrint('RatingPromptService: openStoreListing failed: $error');
    }
  }

  /// How many zikr readers are alive right now. Nested readers (a link from
  /// one zikr to another) each count, so backing out of the inner one lands
  /// on another reader and must not ask yet.
  static int _openReaders = 0;

  /// Whether something since the last ask has earned one. In memory only:
  /// a pending ask left over when the app is killed is not worth carrying
  /// into a cold start, which is exactly the moment never to ask.
  static bool _pendingAsk = false;

  /// Long enough for the reader's pop transition to finish, so the dialog
  /// lands on the settled list/home screen instead of mid-animation.
  @visibleForTesting
  static Duration settleDelay = const Duration(milliseconds: 600);

  @visibleForTesting
  static bool get hasPendingAsk => _pendingAsk;

  @visibleForTesting
  static int get openReaders => _openReaders;

  /// Call from a zikr reader's `initState`.
  static void readerOpened() => _openReaders++;

  /// Call from a zikr reader's `dispose`, after anything that might record a
  /// completion. Leaving the last open reader is what finally puts a pending
  /// ask to the user.
  static void readerClosed() {
    if (_openReaders > 0) _openReaders--;
    if (_openReaders == 0 && _pendingAsk) _scheduleAskIfPending();
  }

  /// Something that says the user is getting value out of the app - a zikr
  /// shared, bookmarked, saved or favourited. Asked right away (after
  /// [settleDelay]) when no reader is open, otherwise held until the reader
  /// is left, same as a completion.
  static void recordPositiveAction(String action) {
    unawaited(AnalyticsService.feature(
      'rating_positive_action',
      label: 'Rating positive action',
      parameters: {'action': action},
    ));
    if (!shouldAsk()) return;
    _pendingAsk = true;
    if (_openReaders == 0) _scheduleAskIfPending();
  }

  static void _scheduleAskIfPending() {
    unawaited(Future<void>.delayed(settleDelay, () async {
      final context = appNavigatorKey.currentState?.overlay?.context;
      if (context == null) return;
      await askIfPending(context);
    }));
  }

  /// Puts a pending ask to the user if nothing makes this a bad moment:
  /// a reader was reopened in the meantime, the app is backgrounded, or an
  /// Azan is playing. Any of those keeps the ask pending for the next time a
  /// reader is left, rather than dropping it.
  static Future<void> askIfPending(
    BuildContext context, {
    Future<bool> Function()? isAzanPlaying,
    RatingPrompt prompt = showRatingPromptDialog,
    RatingFeedbackPrompt feedbackPrompt = showRatingFeedbackDialog,
  }) async {
    if (!_pendingAsk || _openReaders > 0) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    if (!kIsWeb && await (isAzanPlaying ?? AzanPlaybackService.isPlaying)()) {
      return;
    }
    // Re-checked: the Azan lookup is async, and a reader could have been
    // opened, or another scheduled ask could have run, while it was pending.
    if (!_pendingAsk || _openReaders > 0) return;
    if (!context.mounted) return;
    _pendingAsk = false;
    await maybeAsk(context, prompt: prompt, feedbackPrompt: feedbackPrompt);
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    _openReaders = 0;
    _pendingAsk = false;
    if (!SP.isInitialized) return;
    await SP.prefs.remove(_firstSeenKey);
    await SP.prefs.remove(_completionCountKey);
    await SP.prefs.remove(_lastAskedKey);
    await SP.prefs.remove(_hasAcceptedKey);
  }
}
