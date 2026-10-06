import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/zikr_reminder.dart';
import '../services/zikr_reminder_service.dart';
import '../theme/shia_colors.dart';
import '../utils/zikr_reminder_labels.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import '../widgets/prayer_glyph.dart';
import 'zikr_reminder_form_page.dart';
import '../l10n/l10n.dart';

/// Lists the user's zikr/dua reminders (Tawassul every Tuesday, Dua Kumail 30
/// minutes after Maghrib on Thursday, ...) and lets them add, edit or toggle
/// one (docs/DESIGN_SPEC.md, "Zikr reminders"; mockup `R3-Reminders`).
/// Removing one is on its edit page.
class ZikrRemindersPage extends StatefulWidget {
  const ZikrRemindersPage({super.key});

  @override
  State<ZikrRemindersPage> createState() => _ZikrRemindersPageState();
}

class _ZikrRemindersPageState extends State<ZikrRemindersPage> {
  final ZikrReminderService _service = ZikrReminderService.instance;

  @override
  void initState() {
    super.initState();
    trackScreen('Zikr Reminders Page');
    _service.addListener(_onChanged);
    if (!_service.hasLoaded) {
      unawaited(_service.load());
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _addReminder() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ZikrReminderFormPage()),
    );
  }

  Future<void> _editReminder(ZikrReminder reminder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ZikrReminderFormPage(existing: reminder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context);
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final reminders = List<ZikrReminder>.of(_service.reminders)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return LargeTitlePage(
      title: l10n.remindersTitle,
      subtitle: l10n.remindersSubtitle,
      slivers: [
        SliverPadding(
          padding: gutter.copyWith(bottom: 14),
          sliver: SliverToBoxAdapter(
            child: PageButton(
              filled: true,
              glyph: OutlineGlyph.plus,
              label: l10n.remindersAdd,
              onPressed: _addReminder,
            ),
          ),
        ),
        SliverPadding(
          padding: gutter.copyWith(bottom: 14),
          sliver: reminders.isEmpty
              ? SliverToBoxAdapter(
                  child: EmptyStateCard(
                    glyph: OutlineGlyph.clock,
                    title: l10n.reminderNone,
                    body: l10n.reminderNoneBody,
                  ),
                )
              : SliverCardList(
                  itemCount: reminders.length,
                  itemBuilder: (context, index) => _buildReminderRow(
                    context,
                    reminders[index],
                    firstDay: firstDay,
                    first: index == 0,
                    last: index == reminders.length - 1,
                  ),
                ),
        ),
        if (reminders.isNotEmpty)
          SliverPadding(
            padding: gutter,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l10n.remindersFootnote,
                  style: ShiaText.caption
                      .copyWith(height: 18 / 13, color: colors.textMuted),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// One reminder: the prayer's glyph when it is relative to a prayer, a
  /// clock otherwise; the title, "Thursdays · 15 min after Maghrib", and
  /// the switch. Tapping it edits it, which is where Remove is.
  Widget _buildReminderRow(
    BuildContext context,
    ZikrReminder reminder, {
    required int firstDay,
    required bool first,
    required bool last,
  }) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    return CardListRow(
      first: first,
      last: last,
      minHeight: 64,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.well,
          borderRadius: BorderRadius.circular(10),
        ),
        child: reminder.mode == ZikrReminderTimeMode.relativeToPrayer
            ? PrayerGlyph(
                name: reminder.prayerName, size: 22, color: colors.accent)
            : OutlineIcon(OutlineGlyph.clock, size: 20, color: colors.accent),
      ),
      title: Text(reminder.title),
      titleStyle: ShiaText.cardTitle,
      subtitle: Text(
        '${reminderDaysLabel(reminder.daysOfWeek, l10n, firstDayOfWeek: firstDay)}'
        ' · ${reminderWhenLabel(reminder)}',
      ),
      trailing: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
        child: Semantics(
          label: l10n.reminderSwitchLabel(reminder.title),
          child: Switch(
            value: reminder.enabled,
            onChanged: (value) => _service.setEnabled(reminder.id, value),
          ),
        ),
      ),
      onTap: () => _editReminder(reminder),
    );
  }
}
