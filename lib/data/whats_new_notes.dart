import 'package:flutter/foundation.dart';

/// One release's "what's new" entry, shown once to an *existing* install
/// that updates past [buildNumber] — never to a fresh install, which has
/// nothing to catch up on. See WhatsNewService.
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

  /// The version people see in the store (pubspec.yaml's `x.y.z`), used as
  /// the "Version x.y.z" heading when someone is shown more than one entry.
  final String versionName;

  /// Short, plain-language points shown on every platform — this is read by
  /// people who did not ask for a changelog, not a commit log entry. Say only
  /// what a person would notice.
  final List<String> bullets;

  /// Extra points shown only on iOS. Never mention the other platform in
  /// either list: the App Store rejects "What's New" text that does.
  final List<String> iosBullets;

  /// Extra points shown only on Android.
  final List<String> androidBullets;

  /// The points to show on [platform]: the shared [bullets] followed by that
  /// platform's own. Other platforms (web, desktop) get the shared ones only.
  List<String> bulletsFor(TargetPlatform platform) => [
        ...bullets,
        if (platform == TargetPlatform.iOS) ...iosBullets,
        if (platform == TargetPlatform.android) ...androidBullets,
      ];
}

/// Add one entry per release that changes something a person would notice —
/// most releases add nothing here. [WhatsNewService] takes care of who gets
/// shown what and when; this list is the only thing a future release should
/// need to touch.
final List<WhatsNewEntry> whatsNewNotes = <WhatsNewEntry>[
  const WhatsNewEntry(
    buildNumber: 114,
    versionName: '3.5.4',
    bullets: [
      'Zikr Reminders: get reminded about a zikr or dua on the days you '
          'choose.',
      'Azan now plays in full, without other notifications cutting it '
          'off, and has a Stop button on the home screen.',
      'You can now choose a notification sound for each prayer.',
    ],
    iosBullets: [
      'To hear the azan in full, tap its notification to start it.',
    ],
  ),
  const WhatsNewEntry(
    buildNumber: 122,
    versionName: '3.6.0',
    bullets: [
      'Playlists: line up your duas and ziyarats and listen to them back '
          'to back.',
      'Download recitations to listen offline.',
      'Bookmarks now sync across your devices when you are signed in, and '
          'you can drag a bookmark to move it.',
      'Qaza Tracker can estimate your missed prayers and log many at once.',
      'Easier reading: a Text Size setting for the whole app, a cleaner '
          'Focus mode, Arabic as a paragraph, and the Quran in IndoPak '
          'script with the Qalam font.',
      'The Quran now has Ali Quli Qarai\'s translation and transliteration '
          'for every surah.',
      'A new azan recording by Abather Al-Halawaji.',
      'Spotted a mistake? Select the text to report it. Missing a dua or '
          'book? Request it in Settings.',
    ],
    iosBullets: [
      'New widgets: an Islamic calendar (iPhone and Apple Watch) and the '
          'next prayer on the Lock Screen.',
    ],
    androidBullets: [
      'New Islamic calendar widget, and prayer widgets now resize to fit.',
      'Full Azan now plays properly.',
    ],
  ),
];
