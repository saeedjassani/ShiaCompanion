/// One release's "what's new" entry, shown once to an *existing* install
/// that updates past [buildNumber] — never to a fresh install, which has
/// nothing to catch up on. See WhatsNewService.
class WhatsNewEntry {
  const WhatsNewEntry({
    required this.buildNumber,
    required this.versionName,
    required this.bullets,
  });

  /// The Android/iOS build number (pubspec.yaml's `+N`) this entry ships
  /// with. Compared against what an install last saw, so it only has to be
  /// correct relative to the entries around it, not globally unique in any
  /// other sense.
  final int buildNumber;

  /// The version people see in the store (pubspec.yaml's `x.y.z`), shown as
  /// "What's new in x.y.z".
  final String versionName;

  /// Short, plain-language points — this is read by people who did not ask
  /// for a changelog, not a commit log entry. Say only what a person would
  /// notice, and name the platform when something is not the same on both.
  final List<String> bullets;
}

/// Add one entry per release that changes something a person would notice —
/// most releases add nothing here. [WhatsNewService] takes care of who gets
/// shown what and when; this list is the only thing a future release should
/// need to touch.
final List<WhatsNewEntry> whatsNewNotes = <WhatsNewEntry>[
  const WhatsNewEntry(
    buildNumber: 111,
    versionName: '3.5.0',
    bullets: [
      'Full Azan now plays as real audio. On Android it starts at prayer '
          'time even if the app is closed, and other notifications or '
          'touching your phone no longer cut it off. On iPhone it plays in '
          'full when you tap the prayer notification.',
      'While the Azan is playing, you can stop it from the Stop button on '
          'the home screen or from the playback notification.',
      'On Android, Custom Audio plays the same way, and you can now pick a '
          'different file for each prayer.',
      'Prayer notification settings are now on one page: Settings > Prayer '
          'notifications.',
    ],
  ),
  const WhatsNewEntry(
    buildNumber: 114,
    versionName: '3.5.4',
    bullets: [
      'The home screen has a redesigned set of icons.',
      'Zikr pages now separate each step with a thin divider, like the '
          'Quran does between verses.',
      'When you are signed in, your prayer notification and sound choices '
          'now follow your account to your other devices.',
      'Tapping a prayer notification now always takes you to the home '
          'screen, where the Stop button is.',
      'Fixed mix-ups in the transliteration and English text of a few '
          'duas, including Dua e Faraj.',
    ],
  ),
];
