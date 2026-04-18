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
  // Azaan option
  static const AzaanOption azaan = AzaanOption(
    id: 'azaan',
    name: 'Azaan',
    androidFile: 'sharif',
    iosFile: 'azan.caf',
    description: 'Traditional azaan notification',
  );

  // Default notification sound (system default - silent)
  static const AzaanOption silent = AzaanOption(
    id: 'silent',
    name: 'Silent',
    description: 'No notification sound',
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
    azaan,
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


