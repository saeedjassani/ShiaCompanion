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
  await choosePalette(context, selected, source: 'settings');
}

/// Saves [palette] and logs the change, with where it was picked
/// ([source]: settings, setup, home_card); for the swatches in setup and on
/// Home too.
Future<void> choosePalette(
  BuildContext context,
  AppPalette palette, {
  required String source,
}) async {
  final provider = context.read<ThemePaletteProvider>();
  if (provider.palette == palette) return;
  await provider.setPalette(palette);
  unawaited(AnalyticsService.feature(
    'theme_palette_changed',
    label: 'Color changed',
    parameters: {'theme_palette': palette.name, 'source': source},
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

/// One color to pick: its [PaletteSwatch] in a 48 px target, ringed in the
/// accent while it is the one chosen. Setup's theme step and Home's color
/// card lay out a row of these.
class PaletteDot extends StatelessWidget {
  const PaletteDot({
    super.key,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  /// The tap target's side.
  static const double size = 48;

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: palette.label(context.l10n),
      child: Tooltip(
        message: palette.label(context.l10n),
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? colors.accent : Colors.transparent,
                width: 2.4,
              ),
            ),
            child: PaletteSwatch(palette),
          ),
        ),
      ),
    );
  }
}
