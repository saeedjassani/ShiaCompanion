import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/quran/go_to_verse_sheet.dart'
    show SurahArabicName;
import 'package:shia_companion/services/zikr_translations.dart';
import 'package:shia_companion/pages/search_page.dart';
import 'package:shia_companion/utils/data_search_filter.dart';
import 'package:shia_companion/utils/lunar_date_matcher.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/todays_recitation.dart';
import 'package:shia_companion/utils/zikr_lists.dart';
import 'package:shia_companion/utils/zikr_occasions.dart';
import 'package:shia_companion/widgets/favorite_icon.dart';
import 'package:shia_companion/widgets/find_field.dart';
import 'package:shia_companion/widgets/outline_icon.dart';
import 'package:shia_companion/widgets/page_chrome.dart';
import 'package:shia_companion/widgets/zikr_list_row.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import 'package:shia_companion/services/analytics_service.dart';

/// A zikr list - Duas, Ziyarats, Surahs and the rest, and the groups inside
/// them (docs/DESIGN_SPEC.md, "Lists"; mockups `R3-List`, `R3-List-group`):
/// a large title with the count, one card list in the list's own order, and
/// a find field at the bottom that narrows it.
class ItemList extends StatefulWidget {
  final String item, title;

  ItemList(this.item, this.title);

  @override
  _ItemListState createState() => new _ItemListState();
}

class _ItemListState extends State<ItemList> {
  List<UidTitleData> workingItems = [];
  final TextEditingController _find = TextEditingController();

  /// Today, for the Today pills; read once, as the list opens.
  final ({LunarDay day, LunarDay? night}) _today = todaysLunarDays();

  void _refreshWorkingItems() {
    workingItems = zikrListEntries(widget.item);
  }

  @override
  void initState() {
    super.initState();
    trackScreen('List Item Page');
    _refreshWorkingItems();
    _find.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _find.dispose();
    super.dispose();
  }

  bool get _isSurahList => widget.item == 'A';

  /// The rows the find field leaves: the whole list until something is
  /// typed, then what matches, best match first (as search ranks them).
  List<UidTitleData> get _shownItems {
    final query = _find.text;
    if (query.trim().isEmpty) return workingItems;
    return filterDataSearchResults(
      workingItems,
      query,
      matchUid: isUserAdmin,
      translatedTitleFor: (uid) => ZikrTranslations.instance.titleFor(uid),
      slugsFor: (uid) => [
        if (itemSlugs[uid] != null) itemSlugs[uid]!,
        ...?itemSlugAliases[uid],
      ],
    );
  }

  String _countLabel(AppLocalizations l10n) {
    final count = _isSurahList
        ? workingItems.where((e) => surahForUid(e.uid) != null).length
        : workingItems.length;
    return switch (widget.item) {
      'A' => l10n.listCountSurahs(count),
      'E' => l10n.listCountDuas(count),
      'G' => l10n.listCountZiyarats(count),
      'F' => l10n.listCountPrayers(count),
      'H' => l10n.listCountMunajat(count),
      _ => l10n.listCountSections(count),
    };
  }

  String _findHint(AppLocalizations l10n) => switch (widget.item) {
        'A' => l10n.listFindSurah,
        'E' => l10n.listFindDua,
        'G' => l10n.listFindZiyarat,
        'F' => l10n.listFindPrayer,
        'H' => l10n.listFindMunajat,
        _ => l10n.listFindIn(widget.title),
      };

  Future<void> _open(UidTitleData entry) async {
    if (isZikrGroup(entry)) {
      await pushPageRoute(
          context,
          ItemList(entry.getUId().split("~")[1],
              UniversalData(entry.uid, entry.title, 0).displayTitle));
    } else {
      await handleUniversalDataClick(
          context, UniversalData(entry.uid, entry.title, 0),
          source: ZikrOpenSource.list);
    }
    if (!mounted) return;
    setState(_refreshWorkingItems);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // On a tab root (the Quran tab, for everyone the Quran screen is not
    // open to yet) the tab bar holds the bottom and its search button finds
    // a surah; the field is for pushed lists.
    final pushed = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final shown = _shownItems;
    final query = _find.text.trim();

    return LargeTitlePage(
      maxWidth: widePageWidth,
      title: widget.title,
      subtitle: workingItems.isEmpty ? null : _countLabel(l10n),
      bottom: pushed && workingItems.isNotEmpty
          ? FindField(controller: _find, hint: _findHint(l10n))
          : null,
      slivers: [
        SliverPadding(
          padding: pageGutter(context, maxWidth: widePageWidth),
          sliver: shown.isEmpty && query.isNotEmpty
              ? SliverToBoxAdapter(
                  child: EmptyStateCard(
                    glyph: OutlineGlyph.search,
                    title: l10n.listFindNone(query),
                    body: l10n.listFindNoneBody,
                    actionLabel: l10n.listSearchEverywhere,
                    onAction: () => openAppSearch(context, query: query),
                  ),
                )
              : SliverCardList(
                  itemCount: shown.length,
                  itemBuilder: (context, i) => _buildRow(
                    shown[i],
                    first: i == 0,
                    last: i == shown.length - 1,
                    query: query,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRow(
    UidTitleData entry, {
    required bool first,
    required bool last,
    required String query,
  }) {
    final itemData = UniversalData(entry.uid, entry.title, 0);
    final title = isUserAdmin
        ? '${itemData.uid} ${itemData.displayTitle}'
        : itemData.displayTitle;

    if (isZikrGroup(entry)) {
      return ZikrGroupRow(
        first: first,
        last: last,
        title: title,
        subtitle: _groupContents(entry),
        onTap: () => _open(entry),
      );
    }

    final surah = surahInfoFor(surahForUid(entry.uid) ?? 0);
    if (surah != null) {
      return _SurahRow(
        surah: surah,
        item: itemData,
        first: first,
        last: last,
        onTap: () => _open(entry),
      );
    }

    // An alias carries no `day` of its own; its target's says when.
    final patterns = lunarPatternsFrom(
        (itemMetadata[entry.uid] ?? itemMetadata[entry.getFirstUId()])?['day']);
    final today = patterns.isNotEmpty &&
        !isEveryDayOccasion(patterns) &&
        matchesAnyLunarPattern(patterns, day: _today.day, night: _today.night);

    return ZikrListRow(
      item: itemData,
      title: title,
      subtitle: describeZikrOccasions(patterns, context.l10n),
      today: today,
      highlight: query,
      first: first,
      last: last,
      onTap: () => _open(entry),
    );
  }

  /// What a group holds: the groups inside it by name, and how many rows.
  String _groupContents(UidTitleData group) {
    final l10n = context.l10n;
    final children = zikrListEntries(group.getUId().split("~")[1]);
    final names = [
      for (final child in children.where(isZikrGroup))
        UniversalData(child.uid, child.title, 0).displayTitle,
    ];
    if (names.isEmpty) return l10n.listCountSections(children.length);
    final shown = names.length > 3 ? [...names.take(3), '…'] : names;
    return l10n.listGroupContents(
        shown.join(l10n.listSeparator), children.length);
  }
}

/// A surah's row, as on the Quran screen: its number in a well, its name
/// and verse count, the Arabic name on the right, and the heart.
class _SurahRow extends StatelessWidget {
  const _SurahRow({
    required this.surah,
    required this.item,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final SurahInfo surah;
  final UniversalData item;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CardListRow(
      first: first,
      last: last,
      minHeight: 60,
      leading: NumberWell(surah.number),
      title: Text(
          isUserAdmin ? '${item.uid} ${surah.displayName}' : surah.displayName),
      subtitle: Text(context.l10n.quranVerseCount(surah.ayahCount)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (surah.arabicName.isNotEmpty)
            // Capped, so a long name can never push the heart off.
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.4),
              child: SurahArabicName(surah.arabicName),
            ),
          FavoriteHeartButton(favorite: item),
        ],
      ),
      onTap: onTap,
    );
  }
}
