import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../data/uid_title_data.dart';
import '../../services/analytics_service.dart';
import '../../utils/quran_index.dart';
import '../../utils/quran_portion.dart';
import '../zikr/zikr_page.dart';

/// Opens a surah, at a verse when one is named.
///
/// Every Quran entry point goes through here - the surah list, the juz list,
/// the go-to-verse box, a recitation label's resume card and the
/// `/quran/...` links - so they all open the same reader the same way, and a
/// surah with no document yet fails in one place rather than several.
///
/// [recitationLabel] names the recitation track this read belongs to (e.g.
/// "Family", "Personal") — set only when opened by tapping that label's
/// resume card. Left null for every other entry point, which is what routes
/// ordinary browsing into the reserved "Unlabeled" bucket instead of
/// silently picking a label for the reader.
///
/// [replace] swaps the current route instead of pushing - the reader's own
/// "Next surah" / "Previous surah" links use it so reading straight through
/// does not pile up a back stack, carrying [returnBrowserUri] forward so back
/// still lands where the chain started.
Future<void> openQuranVerse(
  BuildContext context,
  VerseKey verse, {
  String source = ZikrOpenSource.quran,
  String? recitationLabel,
  bool replace = false,
  Uri? returnBrowserUri,
}) async {
  final info = surahInfoFor(verse.surah);
  if (info == null) return;

  await (replace ? replacePageRoute : pushPageRoute)(
    context,
    ZikrPage(
      UidTitleData(info.uid, items[info.uid]?.toString() ?? info.fullTitle),
      source: source,
      initialVerse: verse,
      recitationLabel: recitationLabel,
      returnBrowserUri: returnBrowserUri,
    ),
  );
}

/// Opens a juz as one continuous reading, optionally at a verse inside it.
///
/// A juz is not a document in the corpus - 28 of the 30 run across two or more
/// surahs - so it is assembled first and then handed to the reader whole. That
/// is why this is async where [openQuranVerse] is not.
Future<void> openQuranJuz(
  BuildContext context,
  int juz, {
  VerseKey? at,
  String source = ZikrOpenSource.quran,
  String? recitationLabel,
  bool replace = false,
  Uri? returnBrowserUri,
}) async {
  final portion = await loadJuzPortion(juz, DefaultAssetBundle.of(context));
  if (portion == null || portion.isEmpty || !context.mounted) return;

  await (replace ? replacePageRoute : pushPageRoute)(
    context,
    ZikrPage(
      UidTitleData(quranJuzUid(juz), portion.title),
      source: source,
      portion: portion,
      initialVerse: at,
      recitationLabel: recitationLabel,
      returnBrowserUri: returnBrowserUri,
    ),
  );
}

/// The "Previous" / "Next" pair closing a surah or a juz.
///
/// Two quiet links at either edge rather than a pair of full-width boxes: the
/// end of a surah is a place to pause, and the way on only needs to be there
/// when wanted. Either side is left out when there is nothing that way - no
/// "Previous" on al-Fatihah, no "Next" on an-Nas - rather than shown disabled.
class QuranSequenceFooter extends StatelessWidget {
  const QuranSequenceFooter({
    super.key,
    this.unit,
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
  });

  /// What is being stepped through, for the captions ("Next surah"). Null
  /// when the label already says it - "Juz 3" needs no "Next juz" over it.
  final String? unit;
  final String? previousLabel;
  final String? nextLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final previous = previousLabel;
    final next = nextLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 40),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: previous == null
                  ? null
                  : _SequenceLink(
                      caption: unit == null ? 'Previous' : 'Previous $unit',
                      label: previous,
                      isNext: false,
                      onTap: onPrevious,
                    ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: next == null
                  ? null
                  : _SequenceLink(
                      caption: unit == null ? 'Next' : 'Next $unit',
                      label: next,
                      isNext: true,
                      onTap: onNext,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SequenceLink extends StatelessWidget {
  const _SequenceLink({
    required this.caption,
    required this.label,
    required this.isNext,
    required this.onTap,
  });

  final String caption;
  final String label;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = Icon(
      isNext ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
      size: 18,
      color: colorScheme.primary,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isNext) ...[icon, const SizedBox(width: 8)],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isNext ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    caption.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isNext) ...[const SizedBox(width: 8), icon],
          ],
        ),
      ),
    );
  }
}
