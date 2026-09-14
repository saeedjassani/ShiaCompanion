import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/zikr_reminder.dart';
import '../services/zikr_reminder_service.dart';
import '../widgets/responsive_content.dart';
import 'zikr_reminder_form_page.dart';

/// Lists the user's zikr/dua reminders (Tawassul every Tuesday, Dua Kumail 30
/// minutes after Maghrib on Thursday, ...) and lets them add, edit, toggle or
/// remove one.
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

  Future<void> _confirmDelete(ZikrReminder reminder) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Remove reminder?'),
            content: Text(
              'This removes the reminder for "${reminder.title}". You can add it again any time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  'Remove',
                  style:
                      TextStyle(color: Theme.of(dialogContext).colorScheme.error),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) return;

    await _service.deleteReminder(reminder.id);
  }

  @override
  Widget build(BuildContext context) {
    final reminders = List<ZikrReminder>.of(_service.reminders)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: const Text('Zikr Reminders')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReminder,
        tooltip: 'Add reminder',
        child: const Icon(Icons.add),
      ),
      body: reminders.isEmpty
          ? _buildEmptyState(context)
          : ResponsiveContent(
              maxWidth: listContentWidth,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: reminders.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _buildReminderTile(context, reminders[index]),
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return ResponsiveContent(
      maxWidth: compactContentWidth,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 56,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'No reminders yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to get reminded about a zikr or dua on the days you choose — '
              'like Tawassul every Tuesday, or Dua Kumail after Maghrib on Thursday.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderTile(BuildContext context, ZikrReminder reminder) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: reminder.enabled
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          reminder.mode == ZikrReminderTimeMode.relativeToPrayer
              ? Icons.mosque
              : Icons.schedule,
          size: 20,
        ),
      ),
      title: Text(reminder.title),
      subtitle: Text('${reminder.daysLabel} · ${reminder.timeLabel}'),
      onTap: () => _editReminder(reminder),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: reminder.enabled,
            onChanged: (value) => _service.setEnabled(reminder.id, value),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove',
            onPressed: () => _confirmDelete(reminder),
          ),
        ],
      ),
    );
  }
}
