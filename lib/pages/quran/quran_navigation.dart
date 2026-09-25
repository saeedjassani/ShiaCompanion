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
/// Either side is left out when there is nothing that way - no "Previous" on
/// al-Fatihah, no "Next" on an-Nas - rather than shown disabled.
class QuranSequenceFooter extends StatelessWidget {
  const QuranSequenceFooter({
    super.key,
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
  });

  final String? previousLabel;
  final String? nextLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final previous = previousLabel;
    final next = nextLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      child: Row(
        children: [
          Expanded(
            child: previous == null
                ? const SizedBox.shrink()
                : _SequenceButton(
                    label: previous,
                    caption: 'Previous',
                    isNext: false,
                    onTap: onPrevious,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: next == null
                ? const SizedBox.shrink()
                : _SequenceButton(
                    label: next,
                    caption: 'Next',
                    isNext: true,
                    onTap: onNext,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SequenceButton extends StatelessWidget {
  const _SequenceButton({
    required this.label,
    required this.caption,
    required this.isNext,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = Icon(
      isNext ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
      color: colorScheme.primary,
    );

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          if (!isNext) icon,
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isNext ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  caption,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ),
          if (isNext) icon,
        ],
      ),
    );
  }
}
