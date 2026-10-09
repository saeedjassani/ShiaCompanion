import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/shia_colors.dart';
import 'arabic_runs.dart';
import 'glass_surface.dart';
import 'page_chrome.dart';
import 'zikr_list_row.dart' show splitTrailingArabic;

/// The reader's frosted ground: [ShiaColors.readerGround] at 90 % over a
/// backdrop blur, or opaque where blur is off or more contrast is asked for.
/// Shared by the top bar, the status-bar band above it and the part chips
/// under it, so the three read as one surface.
class ReaderGlassBand extends StatelessWidget {
  const ReaderGlassBand({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final solid =
        !GlassSurface.blurEnabled || MediaQuery.highContrastOf(context);
    final band = ColoredBox(
      color: solid
          ? colors.readerGround
          : colors.readerGround.withValues(alpha: 0.9),
      child: child,
    );
    if (solid) return band;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: band,
      ),
    );
  }
}

/// The reader's top bar (docs/DESIGN_SPEC.md, "Reading"): the round Back
/// button, a one-line title with a small sub-line under it ("12% read",
/// "Part 3 of 4", "Verse 255 of 286 · My reading"), an optional round action
/// on the right (the reminder bell), and a 3 px progress line along its bottom
/// edge.
///
/// Excludes the status bar: the page paints that band itself, so the bar can
/// slide away under it in Focus mode while the system icons stay on ground.
class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.progress,
  });

  /// Height of the bar, the progress line included.
  static const double barHeight = 56;

  /// Height of the progress line.
  static const double progressLineHeight = 3;

  final String title;

  /// Usually a [Text]; styled here.
  final Widget? subtitle;

  /// A 44 px round button, or nothing.
  final Widget? trailing;

  /// Drawn as the line along the bottom edge; none when null - the part
  /// chips under the bar carry it instead with [ReaderProgressLine].
  final ValueListenable<double>? progress;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    // One line has no room for a title's trailing Arabic ("2: Al-Baqarah
    // البقرة", "Dua al-Hujjah اِلٰهِيْ …"); the page itself shows it.
    final english = splitTrailingArabic(title).text.trim();
    final shownTitle = english.isEmpty ? title : english;
    final side = width >= 600 ? 32.0 : 12.0;

    return ReaderGlassBand(
      child: SizedBox(
        height: barHeight,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(side, 4, side, 4 + 3),
              child: Row(
                children: [
                  const PageBackButton(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Semantics(
                          header: true,
                          // Qalam only on Arabic runs: in the whole line's
                          // fallback it drew the English ("2: Al-Baqarah")
                          // too wherever the UI font is not registered.
                          child: Text.rich(
                            TextSpan(
                              children: arabicRunSpans(shownTitle) ??
                                  [TextSpan(text: shownTitle)],
                            ),
                            semanticsLabel: title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: ShiaText.cardTitle.copyWith(
                              color: colors.text,
                            ),
                          ),
                        ),
                        if (subtitle != null)
                          DefaultTextStyle.merge(
                            style: ShiaText.caption.copyWith(
                              fontSize: 12,
                              height: 16 / 12,
                              color: colors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            child: subtitle!,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Keeps the title centred on the screen when there is no
                  // action to balance the Back button.
                  trailing ?? const SizedBox(width: 44),
                ],
              ),
            ),
            if (progress != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ReaderProgressLine(progress: progress!),
              ),
          ],
        ),
      ),
    );
  }
}

/// The 3 px reading-progress line: the accent over the divider tone.
/// Informational only, so it never takes a tap from the text under it.
class ReaderProgressLine extends StatelessWidget {
  const ReaderProgressLine({super.key, required this.progress});

  final ValueListenable<double> progress;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          height: ReaderTopBar.progressLineHeight,
          child: ColoredBox(
            color: colors.divider,
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (context, value, _) => Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0).toDouble(),
                  heightFactor: 1,
                  child: ColoredBox(color: colors.accent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
