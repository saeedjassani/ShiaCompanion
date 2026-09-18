/// Represents an azaan (call to prayer) sound option for notifications
class AzaanOption {
  final String id;
  final String name;
  final String description;
  final String? androidFile; // raw resource name (null for custom/default)
  final String? iosFile; // asset filename (null for custom/default)
  final bool isCustom;

  const AzaanOption({
    required this.id,
    required this.name,
    required this.description,
    this.androidFile,
    this.iosFile,
    this.isCustom = false,
  });
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
    description: 'Full azan, played automatically on Android; '
        'on iOS, the notification plays the Takbir sound and the full azan '
        'plays when you open it',
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
