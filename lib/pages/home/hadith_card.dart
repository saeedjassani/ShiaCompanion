import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/l10n.dart';
import '../../services/rating_prompt_service.dart';
import '../../theme/shia_colors.dart';
import '../../widgets/outline_icon.dart';
import 'home_section.dart';

/// A hadith split into what was said and where it is from.
@immutable
class HadithParts {
  const HadithParts(this.text, this.source);

  final String text;

  /// "Ghurar al-Hikam, no. 3725", or null when the hadith names none in the
  /// usual trailing brackets.
  final String? source;
}

/// Splits the trailing `[source]` off a hadith from assets/hadith.
///
/// Most end with their reference in square brackets, usually on a line of
/// its own. Brackets also mark honorifics ("[a.s.]") and editorial
/// insertions ("[instead]"), so a bracket that is not on its own line only
/// counts as the source when it holds a number - every reference has one (a
/// saying, page or verse), no honorific does.
HadithParts splitHadith(String hadith) {
  final trimmed = hadith.trim();
  final match = RegExp(r'(\n\s*)?\[([^\[\]]+)\]\s*$').firstMatch(trimmed);
  if (match != null) {
    final source = match.group(2)!.trim();
    final ownLine = match.group(1) != null;
    if (source.isNotEmpty && (ownLine || RegExp(r'\d').hasMatch(source))) {
      return HadithParts(trimmed.substring(0, match.start).trim(), source);
    }
  }
  return HadithParts(trimmed, null);
}

/// Hadith of the day: the full text, its source, and a Share button.
class HadithOfTheDayCard extends StatelessWidget {
  const HadithOfTheDayCard({super.key, required this.hadith});

  final String hadith;

  Future<void> _share(BuildContext context) async {
    final size = MediaQuery.sizeOf(context);
    final result = await SharePlus.instance.share(ShareParams(
      text:
          '$hadith\n\n${context.l10n.hadithSharedVia('https://shia-companion.web.app/')}',
      sharePositionOrigin: Rect.fromLTWH(size.width / 2, 0, 2, 2),
    ));
    if (result.status == ShareResultStatus.success) {
      RatingPromptService.recordPositiveAction('share_hadith');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final parts = splitHadith(hadith);

    return Semantics(
      container: true,
      label: 'Hadith of the day',
      child: HomeCard(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hadith of the day',
              style: ShiaText.caption.copyWith(
                fontSize: 14,
                height: 18 / 14,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            // The one serif in the app: the platform's own (New York on
            // Apple platforms, Noto Serif on Android).
            Text(
              parts.text,
              style: TextStyle(
                fontFamily: 'serif',
                fontFamilyFallback: const [
                  '.New York',
                  'New York',
                  'Georgia',
                  'Noto Serif',
                  'Times New Roman',
                ],
                fontSize: 18,
                height: 26 / 18,
                color: colors.text,
              ),
            ),
            if (parts.source != null) ...[
              const SizedBox(height: 10),
              Text(
                parts.source!,
                style: ShiaText.caption.copyWith(
                  fontSize: 14,
                  height: 18 / 14,
                  color: colors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _share(context),
              icon: OutlineIcon(
                OutlineGlyph.share,
                size: 18,
                color: colors.accent,
              ),
              label: const Text('Share'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.accent,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                side: BorderSide(color: colors.line),
                shape: const StadiumBorder(),
                textStyle: ShiaText.secondary.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
