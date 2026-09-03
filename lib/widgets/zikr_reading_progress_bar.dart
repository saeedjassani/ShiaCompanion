import 'package:flutter/material.dart';

import 'responsive_content.dart';

/// The reading-progress strip pinned under the app bar on a zikr.
///
/// It lives in the page's Stack rather than in `AppBar.bottom`, so it can
/// slide away with the bottom action bar in Focus mode — `AppBar.bottom` is
/// laid out as part of the app bar and cannot animate independently of it.
/// That move is also why it carries its own surface colours instead of
/// borrowing the app bar's foreground: it now sits over the reading text and
/// has to be opaque.
///
/// Takes pre-formatted labels rather than a stats object: widgets under
/// `lib/widgets/` never import from `lib/pages/`, and the label formatting
/// (`zikrReadingTimeLabel` / `zikrProgressLabel`) lives with the page's own
/// reading-stats model.
class ZikrReadingProgressBar extends StatelessWidget {
  /// Height of the strip's content, excluding the 1px divider below it.
  /// Callers pad the reading column by this much so the first line clears it.
  static const double barHeight = 29;

  final double progress;
  final String readingTimeLabel;
  final String progressLabel;

  const ZikrReadingProgressBar({
    Key? key,
    required this.progress,
    required this.readingTimeLabel,
    required this.progressLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: barHeight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
                Expanded(
                  child: Center(
                    // The reading column is centred on wide screens, so the
                    // strip's contents follow it rather than spanning the
                    // full width and misaligning with the text it describes.
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: readingContentWidth),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 3, 16, 4),
                        child: DefaultTextStyle(
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                readingTimeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Larger than the reading time beside it: this
                              // is the number people glance down to check
                              // progress by, so it carries the weight the
                              // row is there for.
                              Text(
                                progressLabel,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Divider on the content-facing edge, mirroring the action bar's on
          // its own — that one sits above its content since the bar is at
          // the bottom of the screen; this one sits below since the strip is
          // at the top. Neither needs a divider on the app-bar-facing edge:
          // two opaque painted surfaces simply meet there.
          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
        ],
      ),
    );
  }
}
