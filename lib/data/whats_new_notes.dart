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

  /// The version people see in the store (pubspec.yaml's `x.y.z`), used as
  /// the "Version x.y.z" heading when someone is shown more than one entry.
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
      'Zikr Reminders: get reminded about a zikr or dua on the days you '
          'choose.',
      'Azan now plays in full, without other notifications cutting it '
          'off, and has a Stop button on the home screen. On iPhone, tap '
          'the notification to start it.',
      'You can now choose a notification sound for each prayer.',
    ],
  ),
];
