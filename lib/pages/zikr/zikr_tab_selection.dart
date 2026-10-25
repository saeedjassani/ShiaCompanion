import '../../constants.dart';
import '../../data/retired_zikr_redirects.dart';
import '../../services/zikr_translations.dart';
import 'zikr_content_parser.dart';

/// The only tabs zikr [uid] shows of the content it opens, as positions among
/// the tabs the reader shows for that content (0 = the first), or null when it
/// shows them all.
///
/// Two kinds of uid stand for part of another entry: an alias whose
/// `assets/zikr.json` entry names `"tabs"` of its target (see [itemTabs]), and
/// a retired uid whose redirect names [RetiredZikrRedirect.tabs].
List<int>? shownZikrTabs(String uid) {
  final aliasTabs = itemTabs[uid];
  if (aliasTabs != null) return [for (final number in aliasTabs) number - 1];

  final redirectTabs = retiredZikrRedirects[uid.split('|').last]?.tabs;
  // The main `data` slot is the reader's first tab, so `tabs[i]` is the
  // reader's (i + 1)th - as [RetiredZikrRedirect.tabIndex] lands.
  if (redirectTabs != null) return [for (final i in redirectTabs) i + 1];
  return null;
}

/// [shown] cut down to positions that [tabCount] tabs actually have, each
/// once, or null when that leaves none: a list naming no real tab shows the
/// whole zikr rather than nothing.
List<int>? effectiveShownZikrTabs(List<int>? shown, int tabCount) {
  if (shown == null) return null;
  final valid = {
    for (final i in shown)
      if (i >= 0 && i < tabCount) i,
  }.toList();
  return valid.isEmpty ? null : valid;
}

/// The tabs at [shown] of [allTabs], as a zikr of their own.
///
/// Where more than one tab was, each tab's first line is its label, drawn on
/// the tab strip rather than in the text. A tab left on its own has no strip,
/// so that line is dropped instead of turning into its first line of text:
/// the page's own title names it.
List<String> shownZikrTabContents(List<String> allTabs, List<int> shown) {
  if (shown.length == 1 && allTabs.length > 1) {
    return [_withoutLabel(allTabs[shown.single])];
  }
  return [for (final i in shown) allTabs[i]];
}

/// [content] without its first line - as [ZikrContentParser.parseContent]
/// drops it, so the lines that remain are segmented exactly as before.
String _withoutLabel(String content) {
  final lines = content.split('\n');
  return lines.skip(1).join('\n');
}

/// [translation], numbered over all of [allTabs], renumbered for
/// [shownZikrTabContents] of [shown].
///
/// Segments are numbered over the tabs that show (see
/// [ZikrContentParser.segmentOffsets]), so a verse gets another number once
/// the tabs before it are hidden. Each tab keeps its own segments in order;
/// only a lone tab's label, dropped along with its line, has none.
ZikrDocumentTranslation translationForShownZikrTabs(
  ZikrDocumentTranslation translation,
  List<String> allTabs,
  List<int> shown,
) {
  final allOffsets = ZikrContentParser.segmentOffsets(allTabs);
  final shownTabs = shownZikrTabContents(allTabs, shown);
  final shownOffsets = ZikrContentParser.segmentOffsets(shownTabs);
  final labelDropped = allTabs.length > 1 && shownTabs.length == 1;

  final segments = <int, String>{};
  for (var j = 0; j < shown.length; j++) {
    final from = allOffsets[shown[j]] + (labelDropped ? 1 : 0);
    final to = shownOffsets[j];
    final count = (shownTabs.length > 1 ? 1 : 0) +
        ZikrContentParser.parseContent(shownTabs[j],
                hideHeaderLine: shownTabs.length > 1)
            .segments
            .length;
    for (var k = 0; k < count; k++) {
      final text = translation.segments[from + k];
      if (text != null) segments[to + k] = text;
    }
  }

  return ZikrDocumentTranslation(
    language: translation.language,
    segments: segments,
    merits: translation.merits,
  );
}
