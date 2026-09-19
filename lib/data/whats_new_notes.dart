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
    buildNumber: 114,
    versionName: '3.5.4',
    bullets: [
      'Zikr Reminders: get reminded about any zikr or dua on the days you '
          'choose, at a fixed time or a set number of minutes before or '
          'after a prayer. Find it in Settings, or tap the bell on a '
          "zikr's page. Not available on the website.",
      'Prayer notifications are now on one page, Settings > Prayer '
          'notifications, where each prayer has its own switch and its own '
          'sound.',
      'Full Azan now plays as real audio. On Android it starts at prayer '
          'time even if the app is closed, and other notifications or '
          'touching your phone no longer cut it off. On iPhone it plays in '
          'full when you tap the prayer notification. While it plays, stop '
          'it from the Stop button on the home screen or from the '
          'playback notification.',
      'On Android, Custom Audio plays the same way, and you can pick a '
          'different file for each prayer.',
      'When you are signed in, your prayer notification and sound choices '
          'now follow your account to your other devices.',
      'A redesigned set of home screen icons, thin dividers between the '
          'steps of a zikr, and corrected transliteration and English text '
          'in a few duas, including Dua e Faraj.',
    ],
  ),
];
