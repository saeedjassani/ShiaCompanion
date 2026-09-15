import 'package:flutter/material.dart';

import '../constants.dart';
import '../data/uid_title_data.dart';
import '../models/zikr_reminder.dart';
import '../services/zikr_reminder_service.dart';
import '../widgets/responsive_content.dart';
import 'zikr_picker_page.dart';

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
  static const List<String> _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const int _maxOffsetMinutes = 180;

  late final TextEditingController _titleController;
  late final TextEditingController _offsetController;
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
    _prayerName = existing != null &&
            availablePrayerNames.contains(existing.prayerName)
        ? existing.prayerName
        : (availablePrayerNames.contains('Maghrib')
            ? 'Maghrib'
            : availablePrayerNames.first);
    _offsetIsAfter = (existing?.offsetMinutes ?? 30) >= 0;
    _offsetController = TextEditingController(
      text: (existing?.offsetMinutes ?? 30).abs().toString(),
    );
    trackScreen(
        _isEditing ? 'Edit Zikr Reminder Page' : 'Add Zikr Reminder Page');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _offsetController.dispose();
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
      _titleController.text = picked.title;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _toggleDay(int weekday, bool selected) {
    setState(() {
      if (selected) {
        _selectedDays.add(weekday);
      } else {
        _selectedDays.remove(weekday);
      }
    });
  }

  int? _parsedOffsetMagnitude() {
    final value = int.tryParse(_offsetController.text.trim());
    if (value == null || value < 0 || value > _maxOffsetMinutes) return null;
    return value;
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Please enter a title for this reminder.');
      return;
    }
    if (_selectedDays.isEmpty) {
      _showMessage('Pick at least one day.');
      return;
    }

    int offsetMinutes = 0;
    if (_mode == ZikrReminderTimeMode.relativeToPrayer) {
      final magnitude = _parsedOffsetMagnitude();
      if (magnitude == null) {
        _showMessage('Enter a number of minutes between 0 and $_maxOffsetMinutes.');
        return;
      }
      offsetMinutes = _offsetIsAfter ? magnitude : -magnitude;
    }

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
      if (_mode == ZikrReminderTimeMode.relativeToPrayer &&
          (lat == null || long == null)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            "Saved. It'll start firing once your prayer-time location is available.",
          ),
        ));
      }
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Reminder' : 'New Reminder'),
      ),
      body: ResponsiveScrollableContent(
        maxWidth: compactContentWidth,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionLabel(theme, 'What'),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Dua Tawassul',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pickZikr,
                icon: const Icon(Icons.menu_book),
                label: Text(
                  _zikrUid == null
                      ? 'Choose from the zikr library'
                      : 'Change zikr',
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionLabel(theme, 'Repeat on'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < _weekdays.length; index++)
                  FilterChip(
                    label: Text(_weekdayLabels[index]),
                    selected: _selectedDays.contains(_weekdays[index]),
                    onSelected: (selected) =>
                        _toggleDay(_weekdays[index], selected),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionLabel(theme, 'When'),
            SegmentedButton<ZikrReminderTimeMode>(
              segments: const [
                ButtonSegment(
                  value: ZikrReminderTimeMode.fixedTime,
                  label: Text('Fixed time'),
                  icon: Icon(Icons.schedule),
                ),
                ButtonSegment(
                  value: ZikrReminderTimeMode.relativeToPrayer,
                  label: Text('Prayer-relative'),
                  icon: Icon(Icons.mosque),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) =>
                  setState(() => _mode = selection.first),
            ),
            const SizedBox(height: 16),
            if (_mode == ZikrReminderTimeMode.fixedTime)
              _buildFixedTimeControls(theme)
            else
              _buildPrayerRelativeControls(theme),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Add Reminder'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildFixedTimeControls(ThemeData theme) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.access_time),
      title: const Text('Time'),
      subtitle: Text(_time.format(context)),
      trailing: const Icon(Icons.edit),
      onTap: _pickTime,
    );
  }

  Widget _buildPrayerRelativeControls(ThemeData theme) {
    final prayerNames = getPrayerNotificationPrayerNames();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: prayerNames.contains(_prayerName)
              ? _prayerName
              : prayerNames.first,
          decoration: const InputDecoration(
            labelText: 'Prayer',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final name in prayerNames)
              DropdownMenuItem(value: name, child: Text(name)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _prayerName = value);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _offsetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minutes',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Before')),
                  ButtonSegment(value: true, label: Text('After')),
                ],
                selected: {_offsetIsAfter},
                onSelectionChanged: (selection) =>
                    setState(() => _offsetIsAfter = selection.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Prayer times shift with the calendar, so this schedules the next "
          "few weeks' occurrences and refreshes them each time you open the app.",
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}
