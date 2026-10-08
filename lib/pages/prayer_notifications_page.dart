import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/models/azaan_option.dart';
import 'package:shia_companion/services/analytics_service.dart';
import 'package:shia_companion/services/azaan_opt_in_service.dart';
import 'package:shia_companion/services/prayer_preferences_sync_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/theme/shia_colors.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/widgets/outline_icon.dart';
import 'package:shia_companion/widgets/page_chrome.dart';
import 'package:shia_companion/widgets/prayer_glyph.dart';
import '../l10n/l10n.dart';
import '../widgets/app_toast.dart';

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

    unawaited(
        PrayerPreferencesSyncService.instance.pushNotificationToggle(key));
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

  /// Today's time for each prayer, as the prayer card shows it ("5:25 am");
  /// empty without a location.
  Map<String, String> _todaysTimes() {
    final latitude = lat;
    final longitude = long;
    if (latitude == null || longitude == null) return const {};
    try {
      return {
        for (final entry in buildPrayerNotificationEntriesForDay(
          prayerTime: getPrayerTimeObject(),
          date: DateTime.now(),
          latitude: latitude,
          longitude: longitude,
        ))
          entry.name: localizeDigits(formatPrayerDateTime12(entry.dateTime)
              .replaceFirst(RegExp(r'^0(?=\d)'), '')),
      };
    } catch (_) {
      return const {};
    }
  }

  bool _isEnabled(String prayer) =>
      SP.isInitialized &&
      (SP.prefs.getBool(notificationPreferenceKeyForPrayer(prayer)) ?? false);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context);
    final times = _todaysTimes();
    final onCount = kPrayerNotificationList.where(_isEnabled).length;
    final isIOS = !kIsWeb && Platform.isIOS;

    return LargeTitlePage(
      title: l10n.azanTitle,
      subtitle: l10n.azanSubtitle,
      slivers: [
        SliverPadding(
          padding: gutter.copyWith(bottom: 14),
          sliver: SliverToBoxAdapter(
            child: CardList(
              children: [
                CardListRow(
                  first: true,
                  last: true,
                  leading: _IconTile(
                    child: OutlineIcon(OutlineGlyph.speaker,
                        size: 20, color: colors.accent),
                  ),
                  title: Text(l10n.notifDefaultSound),
                  subtitle: Text(l10n.azanDefaultSoundBody),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.35),
                        child: Text(
                          _defaultSoundName(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style:
                              ShiaText.body.copyWith(color: colors.textMuted),
                        ),
                      ),
                      const _Chevron(),
                    ],
                  ),
                  onTap: () => _openSound(),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: gutter.copyWith(bottom: 8),
          sliver:
              SliverToBoxAdapter(child: GroupLabel(l10n.azanTimesOn(onCount))),
        ),
        SliverPadding(
          padding: gutter.copyWith(bottom: 14),
          sliver: SliverToBoxAdapter(
            child: CardList(
              children: [
                for (var i = 0; i < kPrayerNotificationList.length; i++)
                  _PrayerRow(
                    key: _rowKeys[kPrayerNotificationList[i]],
                    prayer: kPrayerNotificationList[i],
                    time: times[kPrayerNotificationList[i]],
                    enabled: _isEnabled(kPrayerNotificationList[i]),
                    soundLabel: _soundLabel(kPrayerNotificationList[i]),
                    overridden: _isOverridden(kPrayerNotificationList[i]),
                    highlighted: _highlighted == kPrayerNotificationList[i],
                    last: i == kPrayerNotificationList.length - 1,
                    onToggle: (value) =>
                        _togglePrayer(kPrayerNotificationList[i], value),
                    onOpenSound: () =>
                        _openSound(prayer: kPrayerNotificationList[i]),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: gutter,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                isIOS
                    ? '${l10n.azanFootnote} ${l10n.azanFootnoteIos}'
                    : l10n.azanFootnote,
                style: ShiaText.caption
                    .copyWith(height: 18 / 13, color: colors.textMuted),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _defaultSoundName() {
    final azaan = getSelectedAzaan();
    if (azaan.id == 'custom') {
      final path =
          SP.isInitialized ? SP.prefs.getString(azaanCustomFilePathKey) : null;
      if (path != null && path.isNotEmpty) {
        return context.l10n.notifCustomSound(path.split('/').last);
      }
    }
    return azaan.name;
  }
}

/// A 34 px well holding a row's glyph.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ShiaColors.of(context).well,
        borderRadius: BorderRadius.circular(9),
      ),
      child: child,
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, end: 2),
      child: OutlineIcon(OutlineGlyph.chevronRight,
          size: 16, color: ShiaColors.of(context).chevron, strokeWidth: 2.4),
    );
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
    required this.time,
    required this.enabled,
    required this.soundLabel,
    required this.overridden,
    required this.highlighted,
    required this.last,
    required this.onToggle,
    required this.onOpenSound,
  });

  final String prayer;

  /// Today's time ("5:25 am"), when there is a location to work it out.
  final String? time;
  final bool enabled;
  final String soundLabel;
  final bool overridden;
  final bool highlighted;
  final bool last;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpenSound;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final name = localizedPrayerName(prayer, l10n);

    return Container(
      decoration: BoxDecoration(
        color: highlighted ? colors.selectedTint : null,
        border: last ? null : Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: l10n.notifPrayerSound(name),
                value: enabled ? soundLabel : l10n.azanOff,
                excludeSemantics: true,
                onTap: onOpenSound,
                child: InkWell(
                  onTap: onOpenSound,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 58),
                    child: Padding(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(14, 6, 8, 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 26,
                            child: Center(
                              child: PrayerGlyph(
                                  name: prayer, size: 22, color: colors.accent),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    text: name,
                                    children: [
                                      if (time != null)
                                        TextSpan(
                                          text: ' · $time',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w400,
                                            color: colors.textMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                  style: ShiaText.body.copyWith(
                                    fontWeight: enabled
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: colors.text,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  !enabled
                                      ? l10n.azanOff
                                      : overridden
                                          ? l10n.azanOwnSound(soundLabel)
                                          : soundLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ShiaText.caption.copyWith(
                                    color: enabled && overridden
                                        ? colors.accent
                                        : colors.textMuted,
                                    fontWeight: enabled && overridden
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const _Chevron(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: colors.divider,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                // A plain Switch, not .adaptive: every other switch in the app
                // stays Material and picks up the brown ColorScheme. Adaptive
                // renders Cupertino green on iOS and would be the only one
                // that doesn't match.
                child: Semantics(
                  label: l10n.azanNotifyAt(name),
                  child: Switch(
                    value: enabled,
                    onChanged: onToggle,
                  ),
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
      unawaited(
        PrayerPreferencesSyncService.instance
            .pushPrayerSound(widget.prayerName!),
      );
    } else {
      await saveAzaanPreference(soundId);
      unawaited(PrayerPreferencesSyncService.instance.pushAzaanSound());
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
      final picked = await FilePicker.pickFile(type: FileType.audio);
      final pickedPath = picked?.path;
      if (pickedPath == null) return false;

      final pickedFile = File(pickedPath);
      if (!await pickedFile.exists()) {
        if (mounted) {
          showToast(context.l10n.notifAudioUnreadable);
        }
        return false;
      }
      final path = await keepCustomAudioFile(
        pickedFile,
        scope: _isPerPrayer ? widget.prayerName! : 'default',
      );

      if (_isPerPrayer) {
        await saveCustomAudioFilePathForPrayer(widget.prayerName!, path);
        await saveAzaanPreferenceForPrayer(widget.prayerName!, 'custom');
        unawaited(
          PrayerPreferencesSyncService.instance
              .pushPrayerSound(widget.prayerName!),
        );
      } else {
        await saveCustomAudioFilePath(path);
        await saveAzaanPreference('custom');
        unawaited(PrayerPreferencesSyncService.instance.pushAzaanSound());
      }
      return true;
    } catch (e) {
      debugPrint('Custom audio pick failed: $e');
      if (mounted) {
        showToast(context.l10n.notifPickFailed);
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(String soundId) async {
    final plugin = flutterLocalNotificationsPlugin;
    if (plugin == null) return;
    showToast(
      context.l10n.notifPlayingSample,
      duration: const Duration(seconds: 2),
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
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context);
    final selection = _currentSelection;
    final options = getAvailableAzaanOptions();
    final rows = [
      if (_isPerPrayer)
        _SoundOptionRow(
          title: l10n.notifUseDefault,
          subtitle: l10n.notifFollows(getSelectedAzaan().name),
          selected: selection == 'app_default',
          onTap: () => _select('app_default'),
        ),
      for (final option in options)
        _SoundOptionRow(
          title: option.name,
          subtitle: _subtitleFor(option),
          selected: selection == option.id,
          onPreview: option.id == 'silent' ? null : () => _preview(option.id),
          onTap: () => _select(option.id),
        ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: LargeTitlePage(
        title: _isPerPrayer
            ? l10n
                .notifPrayerSound(localizedPrayerName(widget.prayerName!, l10n))
            : l10n.notifDefaultSound,
        slivers: [
          SliverPadding(
            padding: gutter.copyWith(bottom: 14),
            sliver: SliverToBoxAdapter(
              child: CardList(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    rows[i].copyWith(first: i == 0, last: i == rows.length - 1),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: gutter,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _footnote(),
                  style: ShiaText.caption
                      .copyWith(height: 18 / 13, color: colors.textMuted),
                ),
              ),
            ),
          ),
        ],
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
    return option.descriptionFor(isIOS: !kIsWeb && Platform.isIOS);
  }

  String _footnote() {
    return _isPerPrayer
        ? context.l10n.notifOwnSoundNote
        : context.l10n.notifDefaultNote;
  }
}

/// One sound to choose: a tick in a circle once chosen, its name and what
/// it is, and a button to hear it.
class _SoundOptionRow extends StatelessWidget {
  const _SoundOptionRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.onPreview,
    this.first = false,
    this.last = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onPreview;
  final bool first;
  final bool last;

  _SoundOptionRow copyWith({required bool first, required bool last}) =>
      _SoundOptionRow(
        title: title,
        subtitle: subtitle,
        selected: selected,
        onTap: onTap,
        onPreview: onPreview,
        first: first,
        last: last,
      );

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final preview = context.l10n.notifPreview;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: CardListRow(
        first: first,
        last: last,
        leading: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? colors.accent : null,
            border:
                selected ? null : Border.all(color: colors.chevron, width: 1.5),
          ),
          child: selected
              ? OutlineIcon(OutlineGlyph.check,
                  size: 16, color: colors.onAccent, strokeWidth: 2.6)
              : null,
        ),
        title: Text(title),
        titleStyle: ShiaText.body
            .copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
        subtitle: Text(subtitle),
        trailing: onPreview == null
            ? null
            : Tooltip(
                message: preview,
                excludeFromSemantics: true,
                child: Semantics(
                  container: true,
                  button: true,
                  label: '$preview $title',
                  excludeSemantics: true,
                  onTap: onPreview,
                  child: InkResponse(
                    onTap: onPreview,
                    radius: 22,
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(
                        child: OutlineIcon(OutlineGlyph.play,
                            size: 20, color: colors.accent, filled: true),
                      ),
                    ),
                  ),
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}
