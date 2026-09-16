/// One release's "what's new" entry, shown once to an *existing* install
/// that updates past [buildNumber] — never to a fresh install, which has
/// nothing to catch up on. See WhatsNewService.
class WhatsNewEntry {
  const WhatsNewEntry({
    required this.buildNumber,
    required this.title,
    required this.bullets,
  });

  /// The Android/iOS build number (pubspec.yaml's `+N`) this entry ships
  /// with. Compared against what an install last saw, so it only has to be
  /// correct relative to the entries around it, not globally unique in any
  /// other sense.
  final int buildNumber;
  final String title;

  /// Short, plain-language points — this is read by people who did not ask
  /// for a changelog, not a commit log entry. Two or three is plenty.
  final List<String> bullets;
}

/// Add one entry per release that changes something a person would notice —
/// most releases add nothing here. [WhatsNewService] takes care of who gets
/// shown what and when; this list is the only thing a future release should
/// need to touch.
final List<WhatsNewEntry> whatsNewNotes = <WhatsNewEntry>[
  const WhatsNewEntry(
    buildNumber: 111,
    title: 'Azan now plays in full',
    bullets: [
      'Full Azan and Custom Audio now keep playing even if another '
          'notification arrives or you pick up your phone — they no longer '
          'cut off partway through.',
      'A Stop button is always available, in the notification and in the '
          'app, to end it early whenever you want.',
    ],
  ),
];
