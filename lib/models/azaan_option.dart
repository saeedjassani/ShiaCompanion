/// Represents an azaan (call to prayer) sound option for notifications
class AzaanOption {
  final String id;
  final String name;
  final String description;
  final String? androidFile; // raw resource name (null for custom/default)
  final String? iosFile; // asset filename (null for custom/default)
  // Bundled full recording played through AzanPlaybackService (null for
  // options that are just a notification sound).
  final String? playbackAsset;
  final bool isCustom;

  const AzaanOption({
    required this.id,
    required this.name,
    required this.description,
    this.androidFile,
    this.iosFile,
    this.playbackAsset,
    this.isCustom = false,
  });

  /// Whether the audio is real app-controlled playback rather than the
  /// notification's own sound.
  bool get playsViaPlaybackService => playbackAsset != null || isCustom;
}

/// Predefined azaan options available to users
class AzaanOptions {
  // Short notification sound used historically on iOS.
  static const AzaanOption takbir = AzaanOption(
    id: 'takbir',
    name: 'Takbir Only',
    androidFile: 'takbir',
    iosFile: 'azan.caf',
    description: 'Short takbir notification sound',
  );

  // Full azaan option (traditional Android default). The full recording
  // plays through an app-controlled player rather than the notification's
  // own (short, easily-interrupted) sound - see AzanPlaybackService. No
  // iosFile of its own: iOS's ~30s notification-sound cap rules out the full
  // recording there, so the notification itself always borrows
  // AzaanOptions.takbir.iosFile instead (see _iosPrayerNotificationDetails).
  static const AzaanOption azaan = AzaanOption(
    id: 'azaan',
    name: 'Full Azan',
    androidFile: 'sharif',
    playbackAsset: 'assets/sounds/full_azan.mp3',
    description: 'Full azan, played automatically on Android; '
        'on iOS, the notification plays the Takbir sound and the full azan '
        'plays when you open it',
  );

  // Abather Al-Halawaji's recording (shiasource.com/adhan). Its four takbirs
  // run ~36s, so iosFile is a pause-shortened, 1.14x clip of just those
  // (29.3s) to stay under iOS's 30s notification-sound cap; the full
  // recording then plays on tap, like Full Azan.
  static const AzaanOption azaanHalawaji = AzaanOption(
    id: 'azaan_halawaji',
    name: 'Full Azan (Al-Halawaji)',
    iosFile: 'azan_halawaji.caf',
    playbackAsset: 'assets/sounds/azan_halawaji.mp3',
    description: 'Abather Al-Halawaji\'s full azan, played automatically on '
        'Android; on iOS, the notification plays his takbirs and the full '
        'azan plays when you open it',
  );

  // System default notification sound
  static const AzaanOption systemDefault = AzaanOption(
    id: 'system_default',
    name: 'System Default',
    description: 'Use your device\'s default notification sound',
  );

  // Silent notification (no sound)
  static const AzaanOption silent = AzaanOption(
    id: 'silent',
    name: 'Silent',
    description: 'Notification banner only (no sound)',
  );

  // Custom audio file (will be configured by user)
  static const AzaanOption custom = AzaanOption(
    id: 'custom',
    name: 'Custom Audio',
    description: 'Choose an audio file from your device',
    isCustom: true,
  );

  /// All available azaan options
  static const List<AzaanOption> all = [
    takbir,
    azaan,
    azaanHalawaji,
    systemDefault,
    silent,
    custom,
  ];

  /// Get azaan option by ID
  static AzaanOption? getById(String id) {
    try {
      return all.firstWhere((option) => option.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get default azaan option
  static AzaanOption getDefault() => azaan;
}
