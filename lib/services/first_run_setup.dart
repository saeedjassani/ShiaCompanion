import 'package:flutter/foundation.dart';

import '../utils/shared_preferences.dart';
import '../utils/theme_mode.dart';
import 'azaan_opt_in_service.dart';
import 'whats_new_service.dart';

/// Whether this install still owes the person first-run setup (welcome,
/// location, azan, Arabic style, theme, back up; docs/DESIGN_SPEC.md,
/// "First-run setup").
///
/// Decided once, on the first launch of a build that has setup, and stored
/// in [stateKey]: a fresh install is [pending] until setup is finished or
/// skipped, and an install that has already run an earlier build is [done]
/// from the start - it was set up the old way. Storing the decision matters:
/// the markers it is read from are written during the very launch that shows
/// setup, so reading them again would mistake a half-finished setup for an
/// old install.
class FirstRunSetup {
  const FirstRunSetup._();

  static const String stateKey = 'first_run_setup';
  static const String pending = 'pending';
  static const String done = 'done';

  /// Preferences only an install that has run an earlier build can have:
  /// a location, an answer to the azan question (or the prayer switches and
  /// sound that predate it), a "What's new" baseline, a chosen theme or
  /// Arabic font.
  ///
  /// Not `buildNumber`, for the reason [AzaanOptInService.priorInstallMarkerKeys]
  /// gives.
  @visibleForTesting
  static const List<String> priorInstallMarkerKeys = [
    'lat',
    AzaanOptInService.askedKey,
    ...AzaanOptInService.priorInstallMarkerKeys,
    WhatsNewService.lastSeenBuildKey,
    ThemeModeProvider.prefsKey,
    ThemeModeProvider.legacyDarkModeKey,
    'arabic_font',
  ];

  /// Whether this launch opens on setup. Call once, after [SP.init] and
  /// before anything else this launch writes.
  ///
  /// Never on the web: the site keeps its first load quiet (no location
  /// request until the prayer card is tapped), has no azan, and is mostly
  /// reached through a shared link to one dua.
  static Future<bool> resolveOnLaunch({bool isWeb = kIsWeb}) async {
    if (isWeb || !SP.isInitialized) return false;
    switch (SP.prefs.getString(stateKey)) {
      case done:
        return false;
      case pending:
        return true;
    }
    final existingInstall = priorInstallMarkerKeys.any(SP.prefs.containsKey);
    if (existingInstall) await _keepEarlierReadingDefaults();
    await SP.prefs.setString(stateKey, existingInstall ? done : pending);
    return !existingInstall;
  }

  /// Transliteration used to be on by default and now is off. Someone who
  /// never touched the switch has been reading with it, so an install from
  /// before the change keeps it rather than losing it overnight.
  static Future<void> _keepEarlierReadingDefaults() async {
    if (!SP.prefs.containsKey(transliterationKey)) {
      await SP.prefs.setBool(transliterationKey, true);
    }
  }

  @visibleForTesting
  static const String transliterationKey = 'showTransliteration';

  /// Records setup as over, whether finished or skipped: it is offered once.
  static Future<void> markDone() async {
    if (!SP.isInitialized) return;
    await SP.prefs.setString(stateKey, done);
  }
}
