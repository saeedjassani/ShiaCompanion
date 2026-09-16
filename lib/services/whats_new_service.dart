import 'package:package_info_plus/package_info_plus.dart';

import '../data/whats_new_notes.dart';
import '../utils/shared_preferences.dart';
import 'azaan_opt_in_service.dart';

/// Tracks which update a person has already been told about, and decides
/// whether this launch owes them a "what's new" dialog.
///
/// Meant to be reused release after release without changing this file: to
/// announce something new, add one [WhatsNewEntry] to [whatsNewNotes] in
/// lib/data/whats_new_notes.dart, keyed to the build number that ships it.
/// [pending] then returns every entry newer than what this install has
/// already seen (covering someone who skipped several versions), and
/// [markSeen] records that they have now been shown up to the current build.
///
/// Deliberately silent for a brand new install: nobody who has never used the
/// old behavior needs it explained to them, and a dialog piling on top of the
/// location and azan opt-in prompts a first run already shows would be one
/// too many. [priorInstallMarkerKeys] — the same signal
/// [AzaanOptInService.adoptChoiceFromExistingInstall] already uses to tell a
/// genuinely new install apart from one that merely predates a given
/// preference — is what keeps it that way.
class WhatsNewService {
  const WhatsNewService._();

  static const String _lastSeenBuildKey = 'whats_new_last_seen_build';

  static Future<int> _currentBuildNumber() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  /// The notes this launch should show, oldest first — empty when there is
  /// nothing new, this is a fresh install, or the install is already caught
  /// up. Call [markSeen] once this launch regardless of what comes back:
  /// that is what actually advances the "last seen" mark, for a fresh
  /// install as much as one that was just shown something.
  static Future<List<WhatsNewEntry>> pending() async {
    if (!SP.isInitialized) return const [];

    final currentBuild = await _currentBuildNumber();
    if (currentBuild <= 0) return const [];

    final lastSeenBuild = SP.prefs.getInt(_lastSeenBuildKey);
    if (lastSeenBuild == null) {
      final isExistingInstall =
          AzaanOptInService.priorInstallMarkerKeys.any(SP.prefs.containsKey);
      if (!isExistingInstall) return const [];
      // An existing install that predates this tracking has "seen" nothing,
      // so every note up to the current build is new to it.
      return whatsNewNotes
          .where((entry) => entry.buildNumber <= currentBuild)
          .toList(growable: false);
    }

    if (lastSeenBuild >= currentBuild) return const [];
    return whatsNewNotes
        .where((entry) =>
            entry.buildNumber > lastSeenBuild &&
            entry.buildNumber <= currentBuild)
        .toList(growable: false);
  }

  /// Records this install as caught up to the current build. Call once per
  /// launch, right after [pending] — unconditionally, so a fresh install
  /// establishes its baseline silently instead of being shown every note
  /// that ever shipped the day it finally updates again.
  static Future<void> markSeen() async {
    if (!SP.isInitialized) return;
    final currentBuild = await _currentBuildNumber();
    if (currentBuild <= 0) return;
    await SP.prefs.setInt(_lastSeenBuildKey, currentBuild);
  }
}
