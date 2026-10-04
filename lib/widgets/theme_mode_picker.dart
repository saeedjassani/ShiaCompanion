import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/analytics_service.dart';
import '../utils/theme_mode.dart';

/// The Theme choices, in the order the sheet lists them.
const List<ThemeMode> themeModeChoices = [
  ThemeMode.light,
  ThemeMode.dark,
  ThemeMode.system,
];

/// Asks Light, Dark or Same as phone, and applies the answer straight away.
Future<void> showThemeModePicker(BuildContext context) async {
  final provider = context.read<ThemeModeProvider>();
  final current = provider.themeMode;
  final theme = Theme.of(context);

  final selected = await showModalBottomSheet<ThemeMode>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Theme', style: theme.textTheme.titleMedium),
            ),
          ),
          // A trailing check rather than RadioListTile, as in the audio
          // track picker: choosing closes the sheet.
          for (final mode in themeModeChoices)
            ListTile(
              leading: Icon(_iconFor(mode)),
              title: Text(ThemeModeProvider.label(mode)),
              subtitle: mode == ThemeMode.system
                  ? const Text('Light or dark, as your phone is set')
                  : null,
              trailing: mode == current
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              selected: mode == current,
              onTap: () => Navigator.of(sheetContext).pop(mode),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (selected == null || selected == current) return;
  await provider.setThemeMode(selected);
  unawaited(AnalyticsService.feature(
    'theme_mode_changed',
    label: 'Theme changed',
    parameters: {'theme_mode': selected.name},
  ));
}

IconData _iconFor(ThemeMode mode) => switch (mode) {
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
      ThemeMode.system => Icons.brightness_auto_outlined,
    };
