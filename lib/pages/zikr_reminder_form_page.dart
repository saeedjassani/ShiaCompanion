import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../constants.dart';
import '../data/uid_title_data.dart';
import '../models/zikr_reminder.dart';
import '../services/zikr_reminder_service.dart';
import '../theme/shia_colors.dart';
import '../utils/zikr_lists.dart';
import '../utils/zikr_occasions.dart';
import '../utils/zikr_reminder_labels.dart';
import '../widgets/home_glyph.dart';
import '../widgets/outline_icon.dart';
import '../widgets/choice_sheet.dart';
import '../widgets/page_chrome.dart';
import '../widgets/prayer_glyph.dart';
import 'zikr_picker_page.dart';
import '../l10n/l10n.dart';
import '../widgets/app_toast.dart';

/// Add/edit form for a single [ZikrReminder].
///
/// Pass [existing] to edit a reminder in place; omit it to create a new one.
/// When creating one, [initialZikrUid]/[initialTitle] prefill the zikr link
/// and title — how the "Set Reminder" entry point on a zikr's own page opens
/// this already pointed at that zikr, rather than empty.
class ZikrReminderFormPage extends StatefulWidget {
  const ZikrReminderFormPage({
    super.key,
    this.existing,
    this.initialZikrUid,
    this.initialTitle,
  });

  final ZikrReminder? existing;
  final String? initialZikrUid;
  final String? initialTitle;

  @override
  State<ZikrReminderFormPage> createState() => _ZikrReminderFormPageState();
}

class _ZikrReminderFormPageState extends State<ZikrReminderFormPage> {
  static const List<int> _weekdays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];
  static const int _maxOffsetMinutes = 180;
  static const int _offsetStep = 5;

  late final TextEditingController _titleController;
  late int _offsetMagnitude;
  String? _zikrUid;
  late Set<int> _selectedDays;
  late ZikrReminderTimeMode _mode;
  late TimeOfDay _time;
  late String _prayerName;
  late bool _offsetIsAfter;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(
      text: existing?.title ?? widget.initialTitle ?? '',
    );
    _zikrUid = existing?.zikrUid ?? widget.initialZikrUid;
    _selectedDays = existing != null ? Set.of(existing.daysOfWeek) : <int>{};
    _mode = existing?.mode ?? ZikrReminderTimeMode.fixedTime;
    _time = existing != null
        ? TimeOfDay(hour: existing.hour, minute: existing.minute)
        : const TimeOfDay(hour: 21, minute: 0);
    final availablePrayerNames = getPrayerNotificationPrayerNames();
    _prayerName =
        existing != null && availablePrayerNames.contains(existing.prayerName)
            ? existing.prayerName
            : (availablePrayerNames.contains('Maghrib')
                ? 'Maghrib'
                : availablePrayerNames.first);
    _offsetIsAfter = (existing?.offsetMinutes ?? 30) >= 0;
    _offsetMagnitude =
        (existing?.offsetMinutes ?? 30).abs().clamp(0, _maxOffsetMinutes);
    trackScreen(
        _isEditing ? 'Edit Zikr Reminder Page' : 'Add Zikr Reminder Page');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickZikr() async {
    final picked = await Navigator.push<UidTitleData>(
      context,
      MaterialPageRoute(builder: (context) => const ZikrPickerPage()),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _zikrUid = picked.uid;
      _titleController.text = picked.displayTitle;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _toggleDay(int weekday) {
    setState(() {
      if (!_selectedDays.remove(weekday)) _selectedDays.add(weekday);
    });
  }

  void _stepOffset(int by) {
    setState(() {
      _offsetMagnitude = (_offsetMagnitude + by).clamp(0, _maxOffsetMinutes);
    });
  }

  Future<void> _pickPrayer() async {
    final colors = ShiaColors.of(context);
    final names = getPrayerNotificationPrayerNames();
    final picked = await showRevampSheet<String>(
      context,
      title: context.l10n.reminderPrayer,
      builder: (sheetContext) => CardList(children: [
        for (final (i, name) in names.indexed)
          MergeSemantics(
            child: Semantics(
              selected: name == _prayerName,
              child: CardListRow(
                first: i == 0,
                last: i == names.length - 1,
                leading:
                    PrayerGlyph(name: name, size: 24, color: colors.accent),
                title: Text(localizedPrayerName(name, context.l10n)),
                trailing: SizedBox.square(
                  dimension: 44,
                  child: name == _prayerName
                      ? Center(
                          child: OutlineIcon(OutlineGlyph.check,
                              size: 22, color: colors.accent, strokeWidth: 2.4),
                        )
                      : null,
                ),
                onTap: () => Navigator.pop(sheetContext, name),
              ),
            ),
          ),
      ]),
    );
    if (picked != null && mounted) setState(() => _prayerName = picked);
  }

  Future<void> _confirmDelete() async {
    final reminder = widget.existing;
    if (reminder == null) return;
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.l10n.reminderRemoveTitle),
            content: Text(context.l10n.reminderRemoveBody(reminder.title)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  context.l10n.commonRemove,
                  style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete || !mounted) return;
    await ZikrReminderService.instance.deleteReminder(reminder.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage(context.l10n.reminderTitleRequired);
      return;
    }
    if (_selectedDays.isEmpty) {
      _showMessage(context.l10n.reminderPickDay);
      return;
    }

    final offsetMinutes = _mode == ZikrReminderTimeMode.relativeToPrayer
        ? (_offsetIsAfter ? _offsetMagnitude : -_offsetMagnitude)
        : 0;

    setState(() => _saving = true);
    try {
      final service = ZikrReminderService.instance;
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          title: title,
          zikrUid: _zikrUid,
          clearZikrUid: _zikrUid == null,
          daysOfWeek: _selectedDays,
          mode: _mode,
          hour: _time.hour,
          minute: _time.minute,
          prayerName: _prayerName,
          offsetMinutes: offsetMinutes,
        );
        await service.updateReminder(updated);
      } else {
        await service.addReminder(
          title: title,
          zikrUid: _zikrUid,
          daysOfWeek: _selectedDays,
          mode: _mode,
          hour: _time.hour,
          minute: _time.minute,
          prayerName: _prayerName,
          offsetMinutes: offsetMinutes,
        );
      }

      if (!mounted) return;
      final pendingLocation = _mode == ZikrReminderTimeMode.relativeToPrayer &&
          (lat == null || long == null);
      final message = context.l10n.reminderSavedPendingLocation;
      Navigator.pop(context);
      // After the pop, so it shows on the list the reminder was saved to.
      if (pendingLocation) showToast(message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    showToast(message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context);
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final days = orderedWeekdays(_weekdays, firstDay);
    final zikrUid = _zikrUid;
    final location = zikrUid == null ? null : _zikrLocation(zikrUid);

    Widget section(String label, Widget child, {Widget? action}) =>
        SliverPadding(
          padding: gutter.copyWith(bottom: 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: GroupLabel(label)),
                    if (action != null) action,
                  ],
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        );

    return LargeTitlePage(
      title: _isEditing ? l10n.reminderEditTitle : l10n.reminderNewTitle,
      bottomBar: _SaveBar(
        summary: _selectedDays.isEmpty
            ? null
            : reminderSummary(
                days: _selectedDays,
                mode: _mode,
                hour: _time.hour,
                minute: _time.minute,
                prayerName: _prayerName,
                offsetMinutes:
                    _offsetIsAfter ? _offsetMagnitude : -_offsetMagnitude,
                l10n: l10n,
                firstDayOfWeek: firstDay,
              ),
        label: _isEditing ? l10n.commonSaveChanges : l10n.reminderAdd,
        saving: _saving,
        onSave: _save,
      ),
      slivers: [
        section(
          l10n.reminderWhat,
          CardList(
            children: [
              CardListRow(
                first: true,
                minHeight: 60,
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.well,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: HomeGlyph(
                      type: HomeGlyphType.duas, size: 26, color: colors.accent),
                ),
                title: Text(zikrUid == null
                    ? l10n.reminderChooseZikr
                    : _zikrTitle(zikrUid)),
                titleStyle: ShiaText.cardTitle,
                subtitle:
                    location == null ? null : Text(l10n.reminderFrom(location)),
                trailing: const _Chevron(),
                onTap: _pickZikr,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: revampFieldDecoration(
                    context,
                    label: l10n.reminderTitleLabel,
                    hint: l10n.reminderTitleHint,
                  ),
                ),
              ),
            ],
          ),
        ),
        section(
          l10n.reminderRepeatOn,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in days)
                _DayButton(
                  letter: DateFormat('EEEEE')
                      .format(DateTime(2024, 6, 16 + day % 7)),
                  name: weekdayName(day % 7),
                  selected: _selectedDays.contains(day),
                  onTap: () => _toggleDay(day),
                ),
            ],
          ),
          action: PageTextAction(
            label: l10n.reminderEveryDayLink,
            onPressed: () => setState(() => _selectedDays = {..._weekdays}),
          ),
        ),
        section(
          l10n.reminderWhen,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedSwitcher<ZikrReminderTimeMode>(
                segments: [
                  Segment(
                      ZikrReminderTimeMode.fixedTime, l10n.reminderFixedTime),
                  Segment(ZikrReminderTimeMode.relativeToPrayer,
                      l10n.reminderPrayerRelative),
                ],
                selected: _mode,
                onChanged: (mode) => setState(() => _mode = mode),
              ),
              const SizedBox(height: 8),
              if (_mode == ZikrReminderTimeMode.fixedTime)
                _buildFixedTimeControls()
              else
                _buildPrayerRelativeControls(),
            ],
          ),
        ),
        if (_mode == ZikrReminderTimeMode.relativeToPrayer)
          SliverPadding(
            padding: gutter.copyWith(bottom: 16),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l10n.reminderPrayerRelativeNote,
                  style: ShiaText.caption
                      .copyWith(height: 18 / 13, color: colors.textMuted),
                ),
              ),
            ),
          ),
        if (_isEditing)
          SliverPadding(
            padding: gutter,
            sliver: SliverToBoxAdapter(
              child: Center(
                child: TextButton(
                  onPressed: _confirmDelete,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: colors.danger,
                    textStyle: buttonTextStyle(context, ShiaText.body)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  child: Text(l10n.reminderRemove),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _zikrTitle(String uid) {
    final title = items[uid];
    if (title is String && title.trim().isNotEmpty) {
      return UidTitleData(uid, title).displayTitle;
    }
    return _titleController.text.trim();
  }

  /// The list the reminder's zikr lives in, for "From Duas".
  String? _zikrLocation(String uid) {
    final l10n = context.l10n;
    return (_locations ??= zikrLocations(
      [
        ('E', l10n.menuDuas),
        ('G', l10n.menuZiyarats),
        ('C', l10n.menuAamaal),
        ('D', l10n.menuTaqeebat),
        ('F', l10n.menuNamaz),
        ('H', l10n.menuMunajaat),
        ('I', l10n.menuBaaqeyaat),
        ('A', l10n.shellTabQuran),
      ],
      join: l10n.searchLocation,
    ))[uid];
  }

  Map<String, String>? _locations;

  Widget _buildFixedTimeControls() {
    final colors = ShiaColors.of(context);
    return CardList(
      children: [
        CardListRow(
          first: true,
          last: true,
          leading:
              OutlineIcon(OutlineGlyph.clock, size: 22, color: colors.accent),
          title: Text(context.l10n.reminderTime),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                clockLabel(_time.hour, _time.minute),
                style: ShiaText.body.copyWith(color: colors.textMuted),
              ),
              const _Chevron(),
            ],
          ),
          onTap: _pickTime,
        ),
      ],
    );
  }

  Widget _buildPrayerRelativeControls() {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    return CardList(
      children: [
        CardListRow(
          first: true,
          leading:
              PrayerGlyph(name: _prayerName, size: 22, color: colors.accent),
          title: Text(l10n.reminderPrayer),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                localizedPrayerName(_prayerName, l10n),
                style: ShiaText.body.copyWith(color: colors.textMuted),
              ),
              const _Chevron(),
            ],
          ),
          onTap: _pickPrayer,
        ),
        CardListRow(
          minHeight: 56,
          title: Text(l10n.reminderMinutes),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoundIconButton(
                label: l10n.reminderMinutesFewer,
                icon: OutlineIcon(OutlineGlyph.minus,
                    size: 20, color: colors.accent, strokeWidth: 2),
                onPressed: _offsetMagnitude == 0
                    ? null
                    : () => _stepOffset(-_offsetStep),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$_offsetMagnitude',
                  textAlign: TextAlign.center,
                  style: ShiaText.sectionTitle.copyWith(color: colors.text),
                ),
              ),
              RoundIconButton(
                label: l10n.reminderMinutesMore,
                icon: OutlineIcon(OutlineGlyph.plus,
                    size: 20, color: colors.accent, strokeWidth: 2),
                onPressed: _offsetMagnitude >= _maxOffsetMinutes
                    ? null
                    : () => _stepOffset(_offsetStep),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: SegmentedSwitcher<bool>(
            segments: [
              Segment(false, l10n.reminderBefore),
              Segment(true, l10n.reminderAfter),
            ],
            selected: _offsetIsAfter,
            onChanged: (after) => setState(() => _offsetIsAfter = after),
          ),
        ),
      ],
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, end: 8),
      child: OutlineIcon(OutlineGlyph.chevronRight,
          size: 16, color: ShiaColors.of(context).chevron, strokeWidth: 2.4),
    );
  }
}

/// One of the seven 44 px day buttons, filled once chosen.
class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.letter,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? colors.accent : colors.surface,
        shape: CircleBorder(
          side: selected
              ? BorderSide.none
              : BorderSide(
                  color: Color.lerp(colors.line, colors.chevron, 0.25)!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Text(
                letter,
                style: ShiaText.body.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: selected ? colors.onAccent : colors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The summary in words and the save button, pinned under the form.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.summary,
    required this.label,
    required this.saving,
    required this.onSave,
  });

  final String? summary;
  final String label;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.ground,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: pageGutter(context).copyWith(top: 12, bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (summary != null) ...[
                Text(
                  summary!,
                  textAlign: TextAlign.center,
                  style: ShiaText.secondary.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 8),
              ],
              PageButton(
                filled: true,
                label: label,
                busy: saving,
                onPressed: onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
