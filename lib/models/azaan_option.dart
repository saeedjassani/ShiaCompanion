import '../l10n/l10n.dart';

/// Represents an azaan (call to prayer) sound option for notifications
class AzaanOption {
  final String id;

  /// The English name and descriptions, shown as they are in English and
  /// for any option the app language has no translation of. [name] and
  /// [descriptionFor] give the text in the app language.
  final String englishName;
  final String englishDescription;
  // Shown instead of [englishDescription] on iOS, for options that behave
  // differently there.
  final String? englishIosDescription;
  final String? androidFile; // raw resource name (null when no channel sound)
  final String? iosFile; // asset filename (null for custom/default)
  final bool isCustom;

  const AzaanOption({
    required this.id,
    required this.englishName,
    required this.englishDescription,
    this.englishIosDescription,
    this.androidFile,
    this.iosFile,
    this.isCustom = false,
  });

  String get name => switch (id) {
        'takbir' => L10n.current.azaanTakbirName,
        'azaan' => L10n.current.azaanFullName,
        'system_default' => L10n.current.azaanSystemDefaultName,
        'silent' => L10n.current.azaanSilentName,
        'custom' => L10n.current.azaanCustomName,
        _ => englishName,
      };

  String get description => switch (id) {
        'takbir' => L10n.current.azaanTakbirDescription,
        'azaan' => L10n.current.azaanFullDescription,
        'system_default' => L10n.current.azaanSystemDefaultDescription,
        'silent' => L10n.current.azaanSilentDescription,
        'custom' => L10n.current.azaanCustomDescription,
        _ => englishDescription,
      };

  String? get iosDescription => switch (id) {
        'azaan' => L10n.current.azaanFullIosDescription,
        _ => englishIosDescription,
      };

  String descriptionFor({required bool isIOS}) =>
      isIOS ? iosDescription ?? description : description;
}

/// Predefined azaan options available to users
class AzaanOptions {
  // Short notification sound used historically on iOS.
  static const AzaanOption takbir = AzaanOption(
    id: 'takbir',
    englishName: 'Takbir Only',
    androidFile: 'takbir',
    // iOS caches notification sounds by file name, so a recording swapped in
    // under an existing name keeps playing the old one on updated installs.
    // A new recording needs a new file name, not just new contents.
    iosFile: 'takbir_halawaji.caf',
    englishDescription: 'Short takbir notification sound',
  );

  // Full azaan option (traditional Android default). The full recording
  // plays through an app-controlled player rather than the notification's
  // own (short, easily-interrupted) sound - see AzanPlaybackService. No
  // iosFile of its own: iOS's ~30s notification-sound cap rules out the full
  // recording there, so the notification itself always borrows
  // AzaanOptions.takbir.iosFile instead (see _iosPrayerNotificationDetails).
  static const AzaanOption azaan = AzaanOption(
    id: 'azaan',
    englishName: 'Full Azan',
    englishDescription: 'Full azan, played automatically',
    englishIosDescription: 'The notification plays the Takbir; '
        'tap it to hear the full azan',
  );

  // System default notification sound
  static const AzaanOption systemDefault = AzaanOption(
    id: 'system_default',
    englishName: 'System Default',
    englishDescription: 'Use your device\'s default notification sound',
  );

  // Silent notification (no sound)
  static const AzaanOption silent = AzaanOption(
    id: 'silent',
    englishName: 'Silent',
    englishDescription: 'Notification banner only (no sound)',
  );

  // Custom audio file (will be configured by user)
  static const AzaanOption custom = AzaanOption(
    id: 'custom',
    englishName: 'Custom Audio',
    englishDescription: 'Choose an audio file from your device',
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
