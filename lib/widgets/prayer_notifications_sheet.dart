import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/models/azaan_option.dart';
import 'package:shia_companion/services/analytics_service.dart';
import 'package:shia_companion/services/azaan_opt_in_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/prayer_glyph.dart';

const List<String> kPrayerNotificationList = [
  'Fajr',
  'Sunrise',
  'Zuhr',
  'Asr',
  'Sunset',
  'Maghrib',
  'Isha',
  'Midnight',
];

const Set<String> kObligatoryPrayers = {
  'Fajr',
  'Zuhr',
  'Asr',
  'Maghrib',
  'Isha',
};

/// Shows the bottom sheet modal for configuring which prayers raise notifications
/// and what sound (Azan, Takbir, System Default, Silent) each one uses.
Future<bool> showPrayerNotificationsSheet(
  BuildContext context, {
  String? highlightPrayer,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => PrayerNotificationsSheet(
      highlightPrayer: highlightPrayer,
    ),
  );
  return result ?? false;
}

class PrayerNotificationsSheet extends StatefulWidget {
  const PrayerNotificationsSheet({
    super.key,
    this.highlightPrayer,
  });

  final String? highlightPrayer;

  @override
  State<PrayerNotificationsSheet> createState() =>
      _PrayerNotificationsSheetState();
}

class _PrayerNotificationsSheetState extends State<PrayerNotificationsSheet> {
  late final Map<String, bool> _enabled;
  late final Map<String, String> _sounds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _enabled = {};
    _sounds = {};
    for (final prayer in kPrayerNotificationList) {
      final notifKey = notificationPreferenceKeyForPrayer(prayer);
      _enabled[prayer] = SP.isInitialized
          ? (SP.prefs.getBool(notifKey) ?? false)
          : false;

      final soundKey = soundPreferenceKeyForPrayer(prayer);
      _sounds[prayer] = SP.isInitialized
          ? (SP.prefs.getString(soundKey) ?? 'app_default')
          : 'app_default';
    }
  }

  void _applyPreset(Set<String> prayersToEnable) {
    setState(() {
      for (final prayer in kPrayerNotificationList) {
        _enabled[prayer] = prayersToEnable.contains(prayer);
      }
    });
  }

  Future<void> _pickSoundForPrayer(String prayer) async {
    // Custom Audio is excluded here: there is only ever one custom sound file
    // on disk — the one backing the global azaan preference — so a per-prayer
    // "custom" choice has no file of its own to point at. Picking it would
    // silently play no sound instead of the file the user expects (see
    // getAzaanOptionForPrayer). Custom stays a global-only option.
    final availableOptions = getAvailableAzaanOptions()
        .where((option) => !option.isCustom)
        .toList(growable: false);
    final globalOption = getSelectedAzaan();
    final currentSound = _sounds[prayer] ?? 'app_default';

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text('$prayer Notification Sound'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'app_default'),
              child: Row(
                children: [
                  Icon(
                    currentSound == 'app_default'
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'App Default',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Follows global setting (${globalOption.name})',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            for (final option in availableOptions)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, option.id),
                child: Row(
                  children: [
                    Icon(
                      currentSound == option.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            option.description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _sounds[prayer] = selected;
      });
    }
  }

  String _soundLabelFor(String prayer) {
    final soundId = _sounds[prayer] ?? 'app_default';
    if (soundId == 'app_default') {
      return 'Default (${getSelectedAzaan().name})';
    }
    final option = AzaanOptions.getById(soundId);
    return option?.name ?? soundId;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    var anyEnabled = false;
    for (final prayer in kPrayerNotificationList) {
      final isEnabled = _enabled[prayer] ?? false;
      if (isEnabled) anyEnabled = true;

      final notifKey = notificationPreferenceKeyForPrayer(prayer);
      await SP.prefs.setBool(notifKey, isEnabled);

      final soundId = _sounds[prayer] ?? 'app_default';
      await saveAzaanPreferenceForPrayer(prayer, soundId);
    }

    if (anyEnabled) {
      await SP.prefs.setBool(AzaanOptInService.askedKey, true);
      await requestNotificationPermissions();
    }

    await setUpNotifications();

    unawaited(AnalyticsService.feature(
      'prayer_notifications_sheet_saved',
      label: 'Prayer notifications configured',
      parameters: {
        'enabled_count':
            _enabled.values.where((v) => v).length.toString(),
      },
    ));

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Prayer Notifications',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Done',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose which prayers notify and customize sound alerts.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Presets bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Obligatory Only'),
                    onPressed: () => _applyPreset(kObligatoryPrayers),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.done_all, size: 16),
                    label: const Text('All Prayers'),
                    onPressed: () =>
                        _applyPreset(kPrayerNotificationList.toSet()),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.notifications_off_outlined,
                        size: 16),
                    label: const Text('Mute All'),
                    onPressed: () => _applyPreset({}),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: kPrayerNotificationList.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 64),
                itemBuilder: (context, index) {
                  final prayer = kPrayerNotificationList[index];
                  final isEnabled = _enabled[prayer] ?? false;
                  final isHighlighted = widget.highlightPrayer == prayer;

                  return Container(
                    color: isHighlighted
                        ? colorScheme.primaryContainer.withValues(alpha: 0.2)
                        : null,
                    child: ListTile(
                      leading: PrayerGlyph(
                        name: prayer,
                        size: 24,
                        color: isEnabled
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                      title: Text(
                        prayer,
                        style: TextStyle(
                          fontWeight:
                              isEnabled ? FontWeight.w600 : FontWeight.normal,
                          color: isEnabled
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      subtitle: isEnabled
                          ? InkWell(
                              onTap: () => _pickSoundForPrayer(prayer),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _sounds[prayer] == 'silent'
                                          ? Icons.volume_off
                                          : Icons.music_note,
                                      size: 14,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        _soundLabelFor(prayer),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      size: 16,
                                      color: colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Text(
                              'Off',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                      trailing: Switch.adaptive(
                        value: isEnabled,
                        onChanged: (bool val) {
                          setState(() {
                            _enabled[prayer] = val;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
