import 'package:flutter/material.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import '../services/event_notification_service.dart';
import '../theme/shia_colors.dart';
import '../utils/event_notification_planning.dart';
import '../utils/zikr_reminder_labels.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';

/// Opts into notifications of the Islamic calendar's events, and says which
/// kinds and when: wiladat and Eids, shahadat and days of mourning, the other
/// days; on the day or the day before, at a time of the reader's choosing.
///
/// Every change is saved and rescheduled as it is made; there is no Done.
class EventNotificationsPage extends StatefulWidget {
  const EventNotificationsPage({super.key});

  @override
  State<EventNotificationsPage> createState() => _EventNotificationsPageState();
}

class _EventNotificationsPageState extends State<EventNotificationsPage> {
  final EventNotificationService _service = EventNotificationService.instance;

  @override
  void initState() {
    super.initState();
    trackScreen('Event Notifications Page');
    _service.addListener(_changed);
  }

  @override
  void dispose() {
    _service.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _pickTime() async {
    final minutes = _service.timeMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    await _service.setTimeMinutes(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context);
    final enabled = _service.enabled;
    final kinds = _service.kinds;
    final dayBefore = _service.dayBefore;
    final minutes = _service.timeMinutes;

    Widget group(String label, List<Widget> rows) => SliverPadding(
          padding: gutter.copyWith(bottom: 14),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GroupLabel(label),
                const SizedBox(height: 8),
                CardList(children: rows),
              ],
            ),
          ),
        );

    Widget kindRow(EventNotificationKind kind, String label,
            {String? hint, bool last = false}) =>
        CardSwitchRow(
          label: label,
          hint: hint,
          value: kinds.contains(kind),
          onChanged: enabled ? (on) => _service.setKind(kind, on) : null,
          last: last,
        );

    Widget timingRow(bool value, String label, {String? hint}) {
      final selected = dayBefore == value;
      return Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: CardListRow(
          first: !value,
          title: Text(label),
          subtitle: hint == null ? null : Text(hint),
          trailing: selected
              ? OutlineIcon(OutlineGlyph.check, size: 20, color: colors.accent)
              : const SizedBox(width: 20),
          onTap: enabled ? () => _service.setDayBefore(value) : null,
        ),
      );
    }

    return LargeTitlePage(
      title: l10n.eventNotificationsTitle,
      subtitle: l10n.eventNotificationsSubtitle,
      slivers: [
        SliverPadding(
          padding: gutter.copyWith(bottom: 14),
          sliver: SliverToBoxAdapter(
            child: CardList(
              children: [
                CardSwitchRow(
                  label: l10n.eventNotificationsSwitch,
                  hint: l10n.eventNotificationsSwitchHint,
                  value: enabled,
                  onChanged: _service.setEnabled,
                  last: true,
                ),
              ],
            ),
          ),
        ),
        group(l10n.eventKindsLabel, [
          kindRow(EventNotificationKind.celebration, l10n.eventKindCelebration),
          kindRow(EventNotificationKind.mourning, l10n.eventKindMourning),
          kindRow(
            EventNotificationKind.other,
            l10n.eventKindOther,
            hint: l10n.eventKindOtherHint,
            last: true,
          ),
        ]),
        if (enabled && kinds.isEmpty)
          SliverPadding(
            padding: gutter.copyWith(bottom: 14),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l10n.eventKindsNoneChosen,
                  style: ShiaText.caption.copyWith(color: colors.accent),
                ),
              ),
            ),
          ),
        group(l10n.eventTimingLabel, [
          Opacity(
            opacity: enabled ? 1 : 0.55,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                timingRow(false, l10n.eventTimingOnDay),
                timingRow(true, l10n.eventTimingDayBefore,
                    hint: l10n.eventTimingDayBeforeHint),
                CardListRow(
                  last: true,
                  leading: OutlineIcon(OutlineGlyph.clock,
                      size: 22, color: colors.accent),
                  title: Text(l10n.reminderTime),
                  trailing: Text(
                    clockLabel(minutes ~/ 60, minutes % 60),
                    style: ShiaText.body.copyWith(color: colors.textMuted),
                  ),
                  onTap: enabled ? _pickTime : null,
                ),
              ],
            ),
          ),
        ]),
        SliverPadding(
          padding: gutter,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.eventNotificationsFootnote,
                style: ShiaText.caption
                    .copyWith(height: 18 / 13, color: colors.textMuted),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
