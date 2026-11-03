import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/shia_colors.dart';
import '../../utils/shared_preferences.dart';
import '../../utils/theme_palette.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/theme_palette_picker.dart';
import 'home_section.dart';

/// Offers the Color setting on Home, under the prayer card, to someone who
/// updated from a build without it: setup's theme step is where a new
/// install chooses, and an install from before setup never sees that step.
/// Every color is one tap away on the card itself; ✕ puts it away for good.
///
/// Decided once a launch ([shouldShow]), so the card stays put while
/// someone tries one color after another; once they have picked one it is
/// gone from the next launch on.
class HomeColorCard extends StatelessWidget {
  const HomeColorCard({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  /// Set once the card has been put away - or, on a fresh install, before
  /// it could ever show, since setup asked.
  static const String dismissedKey = 'home_color_card_dismissed';

  /// Whether this launch shows the card: not on the web, which has no
  /// setup to have missed, nor once a color has been chosen or the card
  /// dismissed.
  static bool shouldShow({bool isWeb = kIsWeb}) =>
      !isWeb &&
      SP.isInitialized &&
      !SP.prefs.containsKey(dismissedKey) &&
      !SP.prefs.containsKey(ThemePaletteProvider.prefsKey);

  /// Records that the card is not to show again.
  static Future<void> markDismissed() async {
    if (!SP.isInitialized) return;
    await SP.prefs.setBool(dismissedKey, true);
  }

  void _dismiss() {
    unawaited(markDismissed());
    unawaited(AnalyticsService.feature(
      'home_color_card_dismissed',
      label: 'Home color card dismissed',
    ));
    onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final palette = context.watch<ThemePaletteProvider>().palette;

    return Semantics(
      container: true,
      child: HomeCard(
        radius: 20,
        padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Text(
                            l10n.whatsNewUnread.toUpperCase(),
                            style: ShiaText.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: colors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.homeColorCardTitle,
                            style:
                                ShiaText.cardTitle.copyWith(color: colors.text),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.homeColorCardBody,
                          style: ShiaText.secondary
                              .copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonClose,
                  onPressed: _dismiss,
                  icon: OutlineIcon(OutlineGlyph.close,
                      size: 18, color: colors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              // Level with the text above rather than the close button.
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: _Swatches(
                selected: palette,
                onTap: (choice) =>
                    choosePalette(context, choice, source: 'home_card'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every palette as a [PaletteDot]: one row where there is room for all
/// eight, otherwise two even rows of four, so none is left alone on a line.
class _Swatches extends StatelessWidget {
  const _Swatches({required this.selected, required this.onTap});

  final AppPalette selected;
  final ValueChanged<AppPalette> onTap;

  @override
  Widget build(BuildContext context) {
    const all = AppPalette.values;
    return LayoutBuilder(builder: (context, constraints) {
      const minGap = 6.0;
      final oneRow = constraints.maxWidth >=
          all.length * PaletteDot.size + (all.length - 1) * minGap;
      final perRow = oneRow ? all.length : (all.length / 2).ceil();
      return Column(
        children: [
          for (var start = 0; start < all.length; start += perRow) ...[
            if (start > 0) const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final choice in all.skip(start).take(perRow))
                  PaletteDot(
                    palette: choice,
                    selected: choice == selected,
                    onTap: () => onTap(choice),
                  ),
              ],
            ),
          ],
        ],
      );
    });
  }
}
