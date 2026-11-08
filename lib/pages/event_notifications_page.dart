import 'package:flutter/material.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import '../services/event_notification_service.dart';
import '../theme/shia_colors.dart';
import '../utils/event_notification_planning.dart';
import '../utils/zikr_reminder_labels.dart';
import '../widgets/page_chrome.dart';

/// Opts into notifications of the Islamic calendar's events, and says which
/// kinds: wiladat and Eids, shahadat and days of mourning, the other days.
///
/// No choice of when: every event is told at Maghrib on its eve, when its
/// Islamic day begins (see [EventNotificationService]). Every change is saved
/// and rescheduled as it is made; there is no Done.
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context);
    final enabled = _service.enabled;
    final kinds = _service.kinds;
    final fallback = eventNotificationFallbackTime(DateTime(2000));

    Widget kindRow(EventNotificationKind kind, String label,
            {String? hint, bool last = false}) =>
        CardSwitchRow(
          label: label,
          hint: hint,
          value: kinds.contains(kind),
          onChanged: enabled ? (on) => _service.setKind(kind, on) : null,
          last: last,
        );

    Widget note(String text, Color color) => SliverPadding(
          padding: gutter.copyWith(bottom: 14),
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                text,
                style: ShiaText.caption.copyWith(height: 18 / 13, color: color),
              ),
            ),
          ),
        );

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
        SliverPadding(
          padding: gutter.copyWith(bottom: 8),
          sliver: SliverToBoxAdapter(child: GroupLabel(l10n.eventKindsLabel)),
        ),
        SliverPadding(
          padding: gutter.copyWith(bottom: 14),
          sliver: SliverToBoxAdapter(
            child: CardList(
              children: [
                kindRow(EventNotificationKind.celebration,
                    l10n.eventKindCelebration),
                kindRow(EventNotificationKind.mourning, l10n.eventKindMourning),
                kindRow(
                  EventNotificationKind.other,
                  l10n.eventKindOther,
                  hint: l10n.eventKindOtherHint,
                  last: true,
                ),
              ],
            ),
          ),
        ),
        if (enabled && kinds.isEmpty)
          note(l10n.eventKindsNoneChosen, colors.accent),
        note(
          l10n.eventNotificationsFootnote(
              clockLabel(fallback.hour, fallback.minute)),
          colors.textMuted,
        ),
      ],
    );
  }
}
