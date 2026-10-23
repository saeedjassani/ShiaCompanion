import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/analytics_service.dart';
import '../theme/app_palette.dart';
import '../theme/shia_colors.dart';
import '../utils/theme_palette.dart';
import 'choice_sheet.dart';

/// Asks which [AppPalette] to draw the app in, and applies it straight
/// away.
Future<void> showThemePalettePicker(BuildContext context) async {
  final provider = context.read<ThemePaletteProvider>();
  final current = provider.palette;
  final l10n = context.l10n;

  final selected = await showChoiceSheet<AppPalette>(
    context,
    title: l10n.settingsColor,
    current: current,
    choices: [
      for (final palette in AppPalette.values)
        Choice(
          palette,
          palette.label(l10n),
          leading: PaletteSwatch(palette),
        ),
    ],
  );

  if (selected == null || selected == current) return;
  await choosePalette(context, selected);
}

/// Saves [palette] and logs the change; for the setup step's swatches too.
Future<void> choosePalette(BuildContext context, AppPalette palette) async {
  final provider = context.read<ThemePaletteProvider>();
  if (provider.palette == palette) return;
  await provider.setPalette(palette);
  unawaited(AnalyticsService.feature(
    'theme_palette_changed',
    label: 'Color changed',
    parameters: {'theme_palette': palette.name},
  ));
}

/// [palette] as a circle, in the brightness on screen: its page ground on
/// the start half, its prayer card on the end half.
class PaletteSwatch extends StatelessWidget {
  const PaletteSwatch(this.palette, {super.key, this.size = 34});

  final AppPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shown = palette.colors(Theme.of(context).brightness);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ShiaColors.of(context).line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: ColoredBox(color: shown.ground)),
            Expanded(child: ColoredBox(color: shown.prayerCard)),
          ],
        ),
      ),
    );
  }
}
