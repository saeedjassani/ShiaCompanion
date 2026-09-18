import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import '../utils/shared_preferences.dart';
import 'azaan_opt_in_service.dart';

/// Owns the "enjoying the app?" rating prompt: when it is fair to ask, and
/// handing off to the OS's own review sheet once someone says yes.
///
/// Never asks on a new install - [shouldAsk] requires both some time and some
/// real use to have gone by - and never asks too often after that, tracked by
/// [_lastAskedKey]. The actual review UI is left entirely to the platform
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
/// and launch thresholds all over again.
class RatingPromptService {
  const RatingPromptService._();

  static const String _firstSeenKey = 'rating_prompt_first_seen_at';
  static const String _launchCountKey = 'rating_prompt_launch_count';
  static const String _lastAskedKey = 'rating_prompt_last_asked_at';

  /// However positive someone feels on day one, they have not used the app
  /// enough yet to have an opinion worth asking about.
  static const Duration _minAgeSinceInstall = Duration(days: 7);
  static const int _minLaunches = 5;

  /// Roughly what Apple's own yearly cap on `requestReview` amounts to per
  /// ask, so this side never burns through more asks than the OS would honour
  /// anyway.
  static const Duration _cooldown = Duration(days: 120);

  /// App Store Connect > General > App Information > Apple ID. Only iOS/macOS
  /// need it - Android and Windows resolve the store listing from the app's
  /// own package id instead.
  static const String _appStoreId = '1492517189';

  /// Backfills an install that predates this feature as already past the age
  /// and launch thresholds, using the same "has this install run a build
  /// older than mine" signal [AzaanOptInService.adoptChoiceFromExistingInstall]
  /// and [WhatsNewService] already rely on. A genuinely fresh install has none
  /// of those markers and is left alone, to start its clock at zero exactly
  /// as [recordLaunch] would anyway.
  ///
  /// Call once per launch, before [recordLaunch] - it only ever writes once,
  /// the first time this build's tracking keys don't exist yet.
  static Future<void> adoptExistingInstall() async {
    if (!SP.isInitialized) return;
    if (SP.prefs.containsKey(_firstSeenKey)) return;
    if (!AzaanOptInService.priorInstallMarkerKeys.any(SP.prefs.containsKey)) {
      return;
    }

    final backfilledFirstSeen =
        DateTime.now().subtract(_minAgeSinceInstall).millisecondsSinceEpoch;
    await SP.prefs.setInt(_firstSeenKey, backfilledFirstSeen);
    await SP.prefs.setInt(_launchCountKey, _minLaunches);
  }

  /// Records a cold start. Call once per launch, before [shouldAsk] - it is
  /// what [shouldAsk] measures "how long installed" and "how many launches"
  /// against.
  static Future<void> recordLaunch() async {
    if (!SP.isInitialized) return;
    if (!SP.prefs.containsKey(_firstSeenKey)) {
      await SP.prefs
          .setInt(_firstSeenKey, DateTime.now().millisecondsSinceEpoch);
    }
    final launches = SP.prefs.getInt(_launchCountKey) ?? 0;
    await SP.prefs.setInt(_launchCountKey, launches + 1);
  }

  /// Whether this launch may put the "enjoying the app?" question to the
  /// user.
  static bool shouldAsk() {
    if (!SP.isInitialized) return false;

    final firstSeenMs = SP.prefs.getInt(_firstSeenKey);
    if (firstSeenMs == null) return false;
    final firstSeen = DateTime.fromMillisecondsSinceEpoch(firstSeenMs);
    if (DateTime.now().difference(firstSeen) < _minAgeSinceInstall) {
      return false;
    }

    final launches = SP.prefs.getInt(_launchCountKey) ?? 0;
    if (launches < _minLaunches) return false;

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
    await SP.prefs
        .setInt(_lastAskedKey, DateTime.now().millisecondsSinceEpoch);
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

  @visibleForTesting
  static Future<void> resetForTest() async {
    if (!SP.isInitialized) return;
    await SP.prefs.remove(_firstSeenKey);
    await SP.prefs.remove(_launchCountKey);
    await SP.prefs.remove(_lastAskedKey);
  }
}
