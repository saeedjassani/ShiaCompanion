import 'package:flutter/material.dart';
import 'package:shia_companion/services/zikr_translations.dart';

import '../constants.dart';
import '../data/uid_title_data.dart';
import '../theme/shia_colors.dart';
import '../utils/data_search_filter.dart';
import '../utils/zikr_lists.dart';
import '../widgets/find_field.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import '../widgets/zikr_list_row.dart';
import '../l10n/l10n.dart';

/// A search-and-pick list over the zikr library, used to prefill a
/// reminder's title from an existing zikr: search scoped to the zikr, with
/// the same field at the bottom (docs/design/mockups/README.md, "Zikr
/// picker"). Pops the picked [UidTitleData], or null if the user backs out -
/// it never navigates into the zikr itself, so it can be reused anywhere a
/// caller just wants a selection back.
class ZikrPickerPage extends StatefulWidget {
  const ZikrPickerPage({super.key});

  @override
  State<ZikrPickerPage> createState() => _ZikrPickerPageState();
}

class _ZikrPickerPageState extends State<ZikrPickerPage> {
  late final List<UidTitleData> _allZikr = items.entries
      .map((entry) => UidTitleData(entry.key, entry.value))
      .where((entry) => !entry.uid.contains('|') && !isZikrGroup(entry))
      .toList(growable: false)
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  final TextEditingController _controller = TextEditingController();

  /// Where each zikr lives, for its row's sub-line.
  Map<String, String>? _locations;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = context.l10n;
    _locations ??= zikrLocations(
      [
        ('E', l10n.menuDuas),
        ('G', l10n.menuZiyarats),
        ('C', l10n.menuAamaal),
        ('D', l10n.menuTaqeebat),
        ('F', l10n.menuNamaz),
        ('H', l10n.menuMunajaat),
        ('I', l10n.menuBaaqeyaat),
        ('A', l10n.shellTabQuran),
      ],
      join: l10n.searchLocation,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<UidTitleData> get _results {
    if (_controller.text.trim().isEmpty) return _allZikr;
    return filterDataSearchResults(
      _allZikr,
      _controller.text,
      translatedTitleFor: ZikrTranslations.instance.titleFor,
      slugsFor: (uid) => [
        if (itemSlugs[uid] != null) itemSlugs[uid]!,
        ...?itemSlugAliases[uid],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final results = _results;
    final query = _controller.text.trim();

    return LargeTitlePage(
      maxWidth: widePageWidth,
      title: l10n.pickerChooseZikr,
      bottom: FindField(
        controller: _controller,
        autofocus: true,
        hint: l10n.pickerSearchZikrHint,
      ),
      slivers: [
        SliverPadding(
          padding: pageGutter(context, maxWidth: widePageWidth),
          sliver: results.isEmpty
              ? SliverToBoxAdapter(
                  child: EmptyStateCard(
                    glyph: OutlineGlyph.search,
                    title: l10n.listFindNone(query),
                    body: l10n.listFindNoneBody,
                  ),
                )
              : SliverCardList(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final entry = results[index];
                    final parts = splitTrailingArabic(entry.displayTitle);
                    final location = _locations?[entry.uid];
                    return CardListRow(
                      first: index == 0,
                      last: index == results.length - 1,
                      title: highlightedText(parts.text, query),
                      subtitle: location == null ? null : Text(location),
                      trailing: Padding(
                        padding:
                            const EdgeInsetsDirectional.only(start: 8, end: 8),
                        child: OutlineIcon(OutlineGlyph.chevronRight,
                            size: 16, color: colors.chevron, strokeWidth: 2.4),
                      ),
                      onTap: () => Navigator.pop(context, entry),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
