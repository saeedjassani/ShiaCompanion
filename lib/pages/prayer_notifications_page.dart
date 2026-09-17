import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/models/azaan_option.dart';
import 'package:shia_companion/services/analytics_service.dart';
import 'package:shia_companion/services/azaan_opt_in_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/prayer_glyph.dart';

/// Every time the app can notify on, in the order the rest of the app shows
/// them.
///
/// Deliberately one flat chronological list rather than "prayers" and "other
/// times": splitting them reorders Sunrise, Sunset and Midnight to the end,
/// and that is an order nothing else in the app uses — not the prayer times
/// card, not the calendar, not the home screen widgets.
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

/// How long to wait after the last change before rebuilding the schedule.
///
/// Rescheduling walks up to twelve days x eight prayers, so doing it on every
/// tap made the switch itself feel stuck. Debouncing keeps a burst of toggles
/// to a single rebuild.
const Duration _kRescheduleDebounce = Duration(milliseconds: 400);

/// Opens the prayer notifications screen.
///
/// Returns nothing: every change is already written by the time the screen
/// closes, so callers simply re-read their summary rather than being told
/// whether to bother.
Future<void> showPrayerNotificationsPage(
  BuildContext context, {
  String? focusPrayer,
}) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => PrayerNotificationsPage(focusPrayer: focusPrayer),
    ),
  );
}

class PrayerNotificationsPage extends StatefulWidget {
  const PrayerNotificationsPage({super.key, this.focusPrayer});

  /// A prayer to scroll to and briefly highlight on open, for callers that
  /// already know which one the user was looking at.
  final String? focusPrayer;

  @override
  State<PrayerNotificationsPage> createState() =>
      _PrayerNotificationsPageState();
}

class _PrayerNotificationsPageState extends State<PrayerNotificationsPage> {
  final Map<String, GlobalKey> _rowKeys = {
    for (final prayer in kPrayerNotificationList) prayer: GlobalKey(),
  };

  Timer? _rescheduleTimer;
  String? _highlighted;

  @override
  void initState() {
    super.initState();
    trackScreen('Prayer Notifications Page');

    final focus = widget.focusPrayer;
    if (focus != null && _rowKeys.containsKey(focus)) {
      _highlighted = focus;
      // Actually bring it into view. The old sheet only tinted the row, which
      // did nothing for the bottom half of the list — the highlight sat off
      // screen and the parameter may as well not have existed.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final rowContext = _rowKeys[focus]?.currentContext;
        if (rowContext != null) {
          await Scrollable.ensureVisible(
            rowContext,
            duration: const Duration(milliseconds: 250),
            alignment: 0.3,
          );
        }
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) setState(() => _highlighted = null);
      });
    }
  }

  @override
  void dispose() {
    _rescheduleTimer?.cancel();
    // A pending rebuild must still happen — the preferences are already
    // written, so dropping it would leave the schedule disagreeing with them
    // until something else rescheduled.
    if (_rescheduleTimer?.isActive ?? false) {
      unawaited(setUpNotifications());
    }
    super.dispose();
  }

  /// Every write goes through here: preferences are saved immediately, and the
  /// expensive reschedule is coalesced. There is no Done button, so nothing
  /// can be lost by leaving the screen.
  void _scheduleReschedule() {
    _rescheduleTimer?.cancel();
    _rescheduleTimer = Timer(_kRescheduleDebounce, () {
      unawaited(setUpNotifications());
    });
  }

  Future<void> _togglePrayer(String prayer, bool value) async {
    final key = notificationPreferenceKeyForPrayer(prayer);
    await SP.prefs.setBool(key, value);
    // Any deliberate change counts as answering the first-run question.
    // Without this, someone who muted everything here could still be ambushed
    // by the opt-in dialog on the next launch.
    await SP.prefs.setBool(AzaanOptInService.askedKey, true);
    if (value) await requestNotificationPermissions();

    _scheduleReschedule();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openSound({String? prayer}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _SoundPickerPage(prayerName: prayer)),
    );
    if (changed == true) {
      _scheduleReschedule();
      if (mounted) setState(() {});
    }
  }

  /// What a row should say its sound is: the name of whatever will actually
  /// play, which for a prayer following the app default is the default's name.
  String _soundLabel(String prayer) => getAzaanOptionForPrayer(prayer).name;

  bool _isOverridden(String prayer) =>
      hasCustomAzaanPreferenceForPrayer(prayer);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer notifications')),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.volume_up, color: colorScheme.onSurfaceVariant),
            title: const Text('Default sound'),
            subtitle: Text(
              '${_defaultSoundName()} · used unless a time below overrides it',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSound(),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(
              'TIMES',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          for (final prayer in kPrayerNotificationList)
            _PrayerRow(
              key: _rowKeys[prayer],
              prayer: prayer,
              enabled: SP.isInitialized &&
                  (SP.prefs.getBool(notificationPreferenceKeyForPrayer(prayer)) ??
                      false),
              soundLabel: _soundLabel(prayer),
              overridden: _isOverridden(prayer),
              highlighted: _highlighted == prayer,
              onToggle: (value) => _togglePrayer(prayer, value),
              onOpenSound: () => _openSound(prayer: prayer),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _defaultSoundName() {
    final azaan = getSelectedAzaan();
    if (azaan.id == 'custom') {
      final path = SP.isInitialized
          ? SP.prefs.getString(azaanCustomFilePathKey)
          : null;
      if (path != null && path.isNotEmpty) {
        return 'Custom: ${path.split('/').last}';
      }
    }
    return azaan.name;
  }
}

/// One time in the list, as a split row: the left zone opens that time's sound,
/// the switch turns it on and off.
///
/// The divider is what makes the two targets legible as two. An earlier pass
/// put the sound behind a small chip, which reads as a status badge — people
/// don't press those.
class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    super.key,
    required this.prayer,
    required this.enabled,
    required this.soundLabel,
    required this.overridden,
    required this.highlighted,
    required this.onToggle,
    required this.onOpenSound,
  });

  final String prayer;
  final bool enabled;
  final String soundLabel;
  final bool overridden;
  final bool highlighted;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpenSound;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: highlighted
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpenSound,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      PrayerGlyph(
                        name: prayer,
                        size: 22,
                        color: enabled
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              prayer,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: enabled
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: enabled
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurface
                                        .withValues(alpha: 0.7),
                              ),
                            ),
                            if (enabled) ...[
                              const SizedBox(height: 2),
                              Text(
                                soundLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: overridden
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: overridden
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: colorScheme.outlineVariant,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: Center(
                // A plain Switch, not .adaptive: every other switch in the app
                // stays Material and picks up the brown ColorScheme. Adaptive
                // renders Cupertino green on iOS and would be the only one
                // that doesn't match.
                child: Switch(
                  value: enabled,
                  onChanged: onToggle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks the sound for one prayer, or — when [prayerName] is null — the app
/// default that every prayer follows unless it says otherwise.
class _SoundPickerPage extends StatefulWidget {
  const _SoundPickerPage({this.prayerName});

  final String? prayerName;

  @override
  State<_SoundPickerPage> createState() => _SoundPickerPageState();
}

class _SoundPickerPageState extends State<_SoundPickerPage> {
  bool _changed = false;
  bool _busy = false;

  bool get _isPerPrayer => widget.prayerName != null;

  String get _currentSelection {
    if (!SP.isInitialized) return 'app_default';
    if (!_isPerPrayer) return getSelectedAzaan().id;
    final stored =
        SP.prefs.getString(soundPreferenceKeyForPrayer(widget.prayerName!));
    if (stored == null || stored.isEmpty) return 'app_default';
    return stored;
  }

  Future<void> _select(String soundId) async {
    if (_busy) return;

    if (soundId == 'custom') {
      final picked = await _pickCustomAudio();
      if (!picked) return;
    } else if (_isPerPrayer) {
      await saveAzaanPreferenceForPrayer(widget.prayerName!, soundId);
    } else {
      await saveAzaanPreference(soundId);
    }

    _changed = true;
    unawaited(AnalyticsService.feature(
      'prayer_sound_set',
      label: 'Prayer notification sound set',
      parameters: {
        'scope': _isPerPrayer ? 'prayer' : 'default',
        'sound_id': soundId,
      },
    ));
    if (mounted) setState(() {});
  }

  /// Custom audio is Android-only (see isAzaanOptionAvailableOnCurrentPlatform),
  /// and each prayer now records its own file rather than sharing one global
  /// pointer.
  Future<bool> _pickCustomAudio() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.pickFiles(type: FileType.audio);
      final path = result?.files.single.path;
      if (path == null) return false;

      final file = File(path);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That audio file could not be read.')),
          );
        }
        return false;
      }

      if (_isPerPrayer) {
        await saveCustomAudioFilePathForPrayer(widget.prayerName!, path);
        await saveAzaanPreferenceForPrayer(widget.prayerName!, 'custom');
      } else {
        await saveCustomAudioFilePath(path);
        await saveAzaanPreference('custom');
      }
      return true;
    } catch (e) {
      debugPrint('Custom audio pick failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not pick that file. Try again.')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(String soundId) async {
    final plugin = flutterLocalNotificationsPlugin;
    if (plugin == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Playing a sample in a moment…'),
        duration: Duration(seconds: 2),
      ),
    );
    // Previews what this prayer will really sound like, override included —
    // the old global-only test button could never do that.
    await testNotification(
      plugin,
      azaanId: soundId == 'app_default' ? null : soundId,
      prayerName: soundId == 'app_default' ? null : widget.prayerName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selection = _currentSelection;
    final options = getAvailableAzaanOptions();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isPerPrayer ? '${widget.prayerName} sound' : 'Default sound',
          ),
        ),
        body: ListView(
          children: [
            if (_isPerPrayer)
              _SoundOptionTile(
                title: 'Use default',
                subtitle: 'Follows ${getSelectedAzaan().name}',
                selected: selection == 'app_default',
                onTap: () => _select('app_default'),
              ),
            for (final option in options)
              _SoundOptionTile(
                title: option.name,
                subtitle: _subtitleFor(option),
                selected: selection == option.id,
                onPreview: option.id == 'silent' ? null : () => _preview(option.id),
                onTap: () => _select(option.id),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: Text(
                _footnote(),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleFor(AzaanOption option) {
    if (option.isCustom) {
      final path = _isPerPrayer
          ? SP.prefs.getString(customAudioPathKeyForPrayer(widget.prayerName!))
          : SP.prefs.getString(azaanCustomFilePathKey);
      if (path != null && path.isNotEmpty) return path.split('/').last;
      return option.description;
    }
    return option.description;
  }

  String _footnote() {
    return _isPerPrayer
        ? 'This time keeps its own sound. Everything else follows the default.'
        : 'Every time follows this unless you give it a sound of its own.';
  }
}

class _SoundOptionTile extends StatelessWidget {
  const _SoundOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.onPreview,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? colorScheme.primary : colorScheme.outline,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: onPreview == null
          ? null
          : IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Preview',
              color: colorScheme.primary,
              onPressed: onPreview,
            ),
      onTap: onTap,
    );
  }
}
