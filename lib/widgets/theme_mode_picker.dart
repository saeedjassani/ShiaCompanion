import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/analytics_service.dart';
import '../utils/theme_mode.dart';
import 'choice_sheet.dart';

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
  final l10n = context.l10n;

  final selected = await showChoiceSheet<ThemeMode>(
    context,
    title: l10n.settingsTheme,
    current: current,
    choices: [
      for (final mode in themeModeChoices)
        Choice(
          mode,
          ThemeModeProvider.label(mode, l10n),
          hint: mode == ThemeMode.system ? l10n.themeSameAsPhoneSubtitle : null,
        ),
    ],
  );

  if (selected == null || selected == current) return;
  await provider.setThemeMode(selected);
  unawaited(AnalyticsService.feature(
    'theme_mode_changed',
    label: 'Theme changed',
    parameters: {'theme_mode': selected.name},
  ));
}
