import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';

/// One point of a release's notes, read from the ARB files
/// (`whatsNew<build><Topic>`) so it shows in the reader's language.
typedef WhatsNewNote = String Function(AppLocalizations l10n);

/// One release's entry on the What's new page (Settings › What's new). An
/// install that updates past [buildNumber] without having opened the page
/// since gets a dot on Home's profile button and on the Settings row until
/// it does. See WhatsNewService.
class WhatsNewEntry {
  const WhatsNewEntry({
    required this.buildNumber,
    required this.versionName,
    required this.bullets,
    this.iosBullets = const [],
    this.androidBullets = const [],
  });

  /// The build number (pubspec.yaml's `+N`) this entry ships
  /// with. Compared against what an install last saw, so it only has to be
  /// correct relative to the entries around it, not globally unique in any
  /// other sense.
  final int buildNumber;

  /// The version people see in the store (pubspec.yaml's `x.y.z`), shown as
  /// the entry's "Version x.y.z" heading.
  final String versionName;

  /// Short, plain-language points shown on every platform - this is read by
  /// people who did not ask for a changelog, not a commit log entry. Say only
  /// what a person would notice.
  final List<WhatsNewNote> bullets;

  /// Extra points shown only on iOS. Never mention the other platform in
  /// either list: the App Store rejects "What's New" text that does.
  final List<WhatsNewNote> iosBullets;

  /// Extra points shown only on Android.
  final List<WhatsNewNote> androidBullets;

  /// The points to show on [platform]: the shared [bullets] followed by that
  /// platform's own. Other platforms (web, desktop) get the shared ones only.
  List<WhatsNewNote> bulletsFor(TargetPlatform platform) => [
        ...bullets,
        if (platform == TargetPlatform.iOS) ...iosBullets,
        if (platform == TargetPlatform.android) ...androidBullets,
      ];
}

/// Add one entry per release that changes something a person would notice,
/// oldest first - most releases add nothing here. Each point is a key in
/// every `app_<code>.arb`. [WhatsNewService] takes care of who gets a dot
/// and when; this list (and the ARB files) is the only thing a future
/// release should need to touch.
final List<WhatsNewEntry> whatsNewNotes = <WhatsNewEntry>[
  WhatsNewEntry(
    buildNumber: 139,
    versionName: '4.1.0',
    bullets: [
      (l10n) => l10n.whatsNew139Colors,
      (l10n) => l10n.whatsNew139Sections,
      (l10n) => l10n.whatsNew139Playlists,
      (l10n) => l10n.whatsNew139SoundPreview,
      (l10n) => l10n.whatsNew139Library,
      (l10n) => l10n.whatsNew139Content,
    ],
    androidBullets: [
      (l10n) => l10n.whatsNew139PrayerWidget,
    ],
  ),
];
