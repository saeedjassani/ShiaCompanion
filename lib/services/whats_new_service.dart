import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/whats_new_notes.dart';
import '../utils/shared_preferences.dart';

/// Tracks which release notes a person has already opened, for the What's
/// new page and the dot that points to it (Home's profile button, the
/// Settings row).
///
/// Meant to be reused release after release without changing this file: to
/// announce something new, add one [WhatsNewEntry] to [whatsNewNotes] in
/// lib/data/whats_new_notes.dart, keyed to the build number that ships it.
/// [hasUnread] then turns on for every install that last opened the page
/// before that build, and [markSeen] - opening the page - turns it off.
///
/// A brand new install starts caught up: nobody who has never used the old
/// app needs its changes pointed out. Nothing on the web either: these notes
/// describe the app, and the site keeps its quiet first load.
class WhatsNewService {
  const WhatsNewService._();

  /// The build whose notes this install has seen. Public because
  /// FirstRunSetup reads it as a sign that this install has already run an
  /// earlier build.
  static const String lastSeenBuildKey = 'whats_new_last_seen_build';

  /// Whether there are notes this install hasn't opened yet.
  static final ValueNotifier<bool> hasUnread = ValueNotifier(false);

  static int _currentBuild = 0;

  /// Sets the baseline on the first launch that has none - the current
  /// build for a [freshInstall], nothing seen for an older one - and works
  /// out [hasUnread]. Call once, after FirstRunSetup.resolveOnLaunch.
  ///
  /// [isWeb] exists only so tests can exercise the web.
  static Future<void> resolveOnLaunch({
    required bool freshInstall,
    bool isWeb = kIsWeb,
  }) async {
    if (isWeb || !SP.isInitialized) return;
    final info = await PackageInfo.fromPlatform();
    _currentBuild = int.tryParse(info.buildNumber) ?? 0;
    if (_currentBuild <= 0) return;

    if (!SP.prefs.containsKey(lastSeenBuildKey)) {
      await SP.prefs.setInt(lastSeenBuildKey, freshInstall ? _currentBuild : 0);
    }
    hasUnread.value = unseenBuilds().isNotEmpty;
  }

  /// Every entry this build has shipped that has something to say on
  /// [platform], newest first. Empty before [resolveOnLaunch], and on the
  /// web.
  static List<WhatsNewEntry> entries({TargetPlatform? platform}) {
    final target = platform ?? defaultTargetPlatform;
    return [
      for (final entry in whatsNewNotes.reversed)
        if (entry.buildNumber <= _currentBuild &&
            entry.bulletsFor(target).isNotEmpty)
          entry,
    ];
  }

  /// The builds among [entries] that came after the notes this install last
  /// opened.
  static Set<int> unseenBuilds({TargetPlatform? platform}) {
    final lastSeen = SP.isInitialized
        ? SP.prefs.getInt(lastSeenBuildKey) ?? _currentBuild
        : _currentBuild;
    return {
      for (final entry in entries(platform: platform))
        if (entry.buildNumber > lastSeen) entry.buildNumber,
    };
  }

  /// Records this install as caught up to the current build: the What's new
  /// page has been opened.
  static Future<void> markSeen() async {
    hasUnread.value = false;
    if (!SP.isInitialized || _currentBuild <= 0) return;
    await SP.prefs.setInt(lastSeenBuildKey, _currentBuild);
  }

  /// Lets tests set the running build without PackageInfo.
  @visibleForTesting
  static set debugCurrentBuild(int build) => _currentBuild = build;
}
