import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants.dart';
import '../data/uid_title_data.dart';
import '../data/universal_data.dart';
import '../l10n/l10n.dart';
import '../services/analytics_service.dart';
import '../services/content_request_service.dart';
import '../services/library_service.dart';
import '../services/zikr_translations.dart';
import '../theme/shia_colors.dart';
import '../utils/data_search_filter.dart';
import '../utils/quran_index.dart';
import '../utils/shared_preferences.dart';
import '../utils/verse_query.dart';
import '../utils/zikr_lists.dart';
import '../widgets/content_request_dialog.dart';
import '../widgets/find_field.dart';
import '../widgets/glass_surface.dart';
import '../widgets/home_glyph.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import '../widgets/zikr_list_row.dart';
import 'list_items.dart';
import 'quran/quran_navigation.dart';

/// Opens search over every zikr, surah and book, starting from [query].
Future<void> openAppSearch(BuildContext context, {String query = ''}) async {
  final books = await LibraryService.loadBooks();
  if (!context.mounted) return;

  // Ties in search rank keep this order, so give it the one the lists use:
  // by category, then as each category's list shows it. Plain key order put
  // A117 (Al-Falaq) ahead of A5 (Al-Fatihah).
  final zikrEntries = items.entries
      .map((entry) => UidTitleData(entry.key, entry.value))
      .toList()
    ..sort(_compareSearchOrder);

  unawaited(AnalyticsService.searchOpened());
  await Navigator.of(context).push(_SearchRoute(
    SearchPage(
      entries: [...zikrEntries, ...books],
      libraryUids: books.map((book) => book.uid).toSet(),
      initialQuery: query,
    ),
  ));
}

final RegExp _categoryPattern = RegExp(r'^[A-Za-z]*');

int _compareSearchOrder(UidTitleData a, UidTitleData b) {
  final byCategory = _categoryPattern
      .stringMatch(a.uid)!
      .compareTo(_categoryPattern.stringMatch(b.uid)!);
  if (byCategory != 0) return byCategory;
  final byOrder = getItemOrderValue(a.uid).compareTo(getItemOrderValue(b.uid));
  if (byOrder != 0) return byOrder;
  final byId = a.getId().compareTo(b.getId());
  if (byId != 0) return byId;
  return a.uid.compareTo(b.uid);
}

/// Search fades in over the tab it was opened from, the field taking the
/// place of the button, rather than sliding in as a page from the side.
class _SearchRoute extends PageRouteBuilder<void> {
  _SearchRoute(Widget page)
      : super(
          pageBuilder: (context, _, __) => page,
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (context, animation, _, child) =>
              MediaQuery.disableAnimationsOf(context)
                  ? child
                  : FadeTransition(opacity: animation, child: child),
        );
}

/// The kinds of result search lists, each a section of the results.
enum SearchSource {
  zikr,
  quran,
  library;

  String label(AppLocalizations l10n) => switch (this) {
        SearchSource.zikr => l10n.searchSourceZikr,
        SearchSource.quran => l10n.searchSourceQuran,
        SearchSource.library => l10n.searchSourceLibrary,
      };

  HomeGlyphType get glyph => switch (this) {
        SearchSource.zikr => HomeGlyphType.duas,
        SearchSource.quran => HomeGlyphType.surahs,
        SearchSource.library => HomeGlyphType.library,
      };
}

/// Search (docs/DESIGN_SPEC.md, "Search"; mockups `R3-Search`,
/// `R3-Search-results`, `R3-Search-none`): a full-screen page whose only
/// control is the field at the bottom, where the search button was, with a
/// round Close beside it.
///
/// Before anything is typed it offers example searches and the last few
/// searches made here. Results come as one section per kind - duas & more,
/// the Quran, the Library - best match first, each of which can be folded
/// to a single row; the Library starts folded.
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.entries,
    this.libraryUids = const {},
    this.initialQuery = '',
  });

  /// Everything searchable: zikr and surahs, then books.
  final List<UidTitleData> entries;

  /// Which of [entries] are books.
  final Set<String> libraryUids;

  final String initialQuery;

  /// Remembers which sections are open, the rest folded. It held which
  /// sources the old filter chips had on, and means the same thing.
  static const String sourcesPrefKey = 'search_sources';

  /// The last few searches made on this device, newest first.
  static const String recentPrefKey = 'search_recent';

  /// Duas & more and the Quran open: most searches are for a dua, ziyarat
  /// or surah, and a hundred book titles matching a common word like
  /// "prayer" would bury them.
  static const Set<SearchSource> defaultSources = {
    SearchSource.zikr,
    SearchSource.quran,
  };

  static const int recentCount = 3;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _query =
      TextEditingController(text: widget.initialQuery);
  Set<SearchSource> _openSources = _loadSources();
  List<String> _recent = _loadRecent();

  /// Where each zikr sits in the lists, for its row's sub-line.
  Map<String, String>? _locations;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
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
    // A closed search is a finished search: flush whatever is pending
    // instead of leaving a timer to fire for a page nobody is looking at.
    _recordSearch();
    _query.dispose();
    super.dispose();
  }

  static Set<SearchSource> _loadSources() {
    final saved = SP.isInitialized
        ? SP.prefs.getStringList(SearchPage.sourcesPrefKey)
        : null;
    if (saved == null) return {...SearchPage.defaultSources};
    return {
      for (final source in SearchSource.values)
        if (saved.contains(source.name)) source,
    };
  }

  static List<String> _loadRecent() =>
      (SP.isInitialized
          ? SP.prefs.getStringList(SearchPage.recentPrefKey)
          : null) ??
      const [];

  void _setOpen(SearchSource source, bool open) {
    setState(() {
      _openSources = {..._openSources};
      open ? _openSources.add(source) : _openSources.remove(source);
    });
    if (SP.isInitialized) {
      unawaited(SP.prefs.setStringList(
          SearchPage.sourcesPrefKey, [for (final s in _openSources) s.name]));
    }
  }

  void _onQueryChanged() {
    setState(() {});
    _scheduleSearchRecord();
  }

  void _fill(String text) {
    _query.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  // --- Recording ----------------------------------------------------------

  /// How long the query has to stop changing before it counts as a search.
  /// Long enough that "kum" on the way to "kumayl" is not a search of its
  /// own, short enough that someone who types and then reads the list is
  /// counted.
  static const Duration _searchRecordDelay = Duration(milliseconds: 900);

  Timer? _recordTimer;
  String? _recordedTerm;

  void _scheduleSearchRecord() {
    _recordTimer?.cancel();
    if (_query.text.trim().isEmpty) return;
    _recordTimer = Timer(_searchRecordDelay, _recordSearch);
  }

  /// Counts the search once (see [isNewSearchTerm]) and keeps it among the
  /// recent ones.
  void _recordSearch() {
    _recordTimer?.cancel();
    final term = _query.text.trim();
    if (term.isEmpty) return;
    _remember(term);
    if (!isNewSearchTerm(previous: _recordedTerm, term: term)) return;
    _recordedTerm = term;
    unawaited(AnalyticsService.search(term));
  }

  /// Puts [term] first among the recent searches. A search it refines
  /// ("kum" on the way to "kumayl") makes way for it rather than taking a
  /// place of its own.
  void _remember(String term) {
    final recent = [
      term,
      for (final previous in _recent)
        if (isNewSearchTerm(previous: previous, term: term)) previous,
    ].take(SearchPage.recentCount).toList();
    _recent = recent;
    if (SP.isInitialized) {
      unawaited(SP.prefs.setStringList(SearchPage.recentPrefKey, recent));
    }
  }

  void _clearRecent() {
    setState(() => _recent = const []);
    if (SP.isInitialized) {
      unawaited(SP.prefs.remove(SearchPage.recentPrefKey));
    }
  }

  // --- Results ------------------------------------------------------------

  SearchSource _sourceOf(UidTitleData entry) {
    if (widget.libraryUids.contains(entry.uid)) return SearchSource.library;
    if (surahForUid(entry.uid) != null) return SearchSource.quran;
    return SearchSource.zikr;
  }

  List<UidTitleData> _results(String query) => filterDataSearchResults(
        widget.entries,
        query,
        matchUid: isUserAdmin,
        translatedTitleFor: (uid) => widget.libraryUids.contains(uid)
            ? null
            : ZikrTranslations.instance.titleFor(uid),
        slugsFor: (uid) => [
          if (itemSlugs[uid] != null) itemSlugs[uid]!,
          ...?itemSlugAliases[uid],
        ],
      );

  /// The verse the query names (`2:255`, `baqarah 255`, `yasin 1`), offered
  /// above every other result.
  ///
  /// Only where the reader can open at a verse: that is part of the Quran
  /// revamp dark-launched to admins (see ZikrPage._surahNumber), and for
  /// everyone else "Go to 2:255" would open al-Baqarah at its first verse.
  VerseKey? _verseQuery(String query) {
    if (!isUserAdmin) return null;
    return parseVerseQuery(query);
  }

  void _open(UidTitleData entry) {
    // Acting on a result is the clearest evidence a search happened, and
    // the query is still exactly what was searched for.
    _recordSearch();
    final isBook = widget.libraryUids.contains(entry.uid);
    final item = UniversalData(entry.uid, entry.title, isBook ? 1 : 0);
    if (!isBook && isZikrGroup(entry)) {
      pushPageRoute(
          context, ItemList(entry.getUId().split("~")[1], item.displayTitle));
    } else {
      handleUniversalDataClick(context, item, source: ZikrOpenSource.search);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final insets = MediaQuery.paddingOf(context);
    final gutter = pageGutter(context);
    final bottomOffset = floatingBottomOffset(context);
    final query = _query.text.trim();

    return Scaffold(
      backgroundColor: colors.ground,
      body: Stack(
        children: [
          CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(padding: EdgeInsets.only(top: insets.top + 14)),
              ...query.isEmpty
                  ? _buildStart(context, gutter)
                  : _buildResults(context, gutter, query),
              SliverPadding(
                padding: EdgeInsets.only(
                    bottom: bottomOffset + FindField.height + 24),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomOffset + FindField.height + 62,
            child: const BottomFade(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomOffset,
            child: Padding(
              padding: gutter,
              child: Row(
                children: [
                  Expanded(
                    child: FindField(
                      controller: _query,
                      autofocus: true,
                      hint: isUserAdmin
                          ? context.l10n.searchTitleOrUid
                          : context.l10n.searchHint,
                      onSubmitted: (_) => _recordSearch(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const _CloseButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Before anything is typed: the title, examples to try, recent searches.
  List<Widget> _buildStart(BuildContext context, EdgeInsets gutter) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final examples = [
      (l10n.searchTryDuaLabel, l10n.searchTryDua),
      (l10n.searchTrySurahLabel, l10n.searchTrySurah),
      // Verse search is admin-only for now (see _verseQuery); for everyone
      // else "2:255" would find nothing.
      if (isUserAdmin)
        (l10n.searchTryVerseLabel, l10n.searchTryVerse)
      else
        (l10n.searchTryOccasionLabel, l10n.searchTryOccasion),
      (l10n.searchTryBookLabel, l10n.searchTryBook),
    ];

    return [
      SliverPadding(
        padding: gutter.copyWith(bottom: 16),
        sliver: SliverToBoxAdapter(
          child: Semantics(
            header: true,
            child: Text(
              l10n.commonSearch,
              style: ShiaText.largeTitle.copyWith(color: colors.text),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: gutter.copyWith(bottom: 8),
        sliver: SliverToBoxAdapter(child: GroupLabel(l10n.searchTry)),
      ),
      SliverPadding(
        padding: gutter.copyWith(bottom: 16),
        sliver: SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, example) in examples)
                    SizedBox(
                      width: width,
                      child: _ExampleCard(
                        label: label,
                        example: example,
                        onTap: () => _fill(example),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      if (_recent.isNotEmpty) ...[
        SliverPadding(
          padding: gutter.copyWith(bottom: 8),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              label: l10n.searchRecent,
              action: l10n.commonClear,
              actionSemantics: l10n.searchRecentClear,
              onAction: _clearRecent,
            ),
          ),
        ),
        SliverPadding(
          padding: gutter,
          sliver: SliverToBoxAdapter(
            child: CardList(
              children: [
                for (var i = 0; i < _recent.length; i++)
                  _RecentRow(
                    term: _recent[i],
                    last: i == _recent.length - 1,
                    onTap: () => _fill(_recent[i]),
                  ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildResults(
      BuildContext context, EdgeInsets gutter, String query) {
    final l10n = context.l10n;
    final results = _results(query);
    final bySource = {
      for (final source in SearchSource.values) source: <UidTitleData>[],
    };
    for (final entry in results) {
      bySource[_sourceOf(entry)]!.add(entry);
    }

    final open = [
      for (final source in SearchSource.values)
        if (_openSources.contains(source) && bySource[source]!.isNotEmpty)
          source,
    ];
    // The section with the better match goes first. Results arrive ranked,
    // so a section's first entry is its best; ties keep the order above.
    final lowered = query.toLowerCase();
    final bestRank = {
      for (final source in open)
        source: searchMatchRank(bySource[source]!.first.title, lowered),
    };
    open.sort((a, b) => bestRank[a] != bestRank[b]
        ? bestRank[a]! - bestRank[b]!
        : a.index - b.index);
    // Folded sections still say they have matches, after the open ones -
    // otherwise a search only a book matches would look like it found
    // nothing.
    final folded = [
      for (final source in SearchSource.values)
        if (!_openSources.contains(source) && bySource[source]!.isNotEmpty)
          source,
    ];
    final verse = _verseQuery(query);

    if (results.isEmpty && verse == null) {
      return [
        SliverPadding(
          padding: gutter,
          sliver: SliverToBoxAdapter(
            child: _NoResults(
              query: query,
              onRequest: () => showContentRequestDialog(
                context,
                initialType: _openSources.length == 1 &&
                        _openSources.contains(SearchSource.library)
                    ? ContentRequestType.book
                    : ContentRequestType.zikr,
                initialTitle: query,
                source: 'search',
              ),
            ),
          ),
        ),
      ];
    }

    return [
      if (verse != null)
        SliverPadding(
          padding: gutter.copyWith(bottom: 14),
          sliver: SliverToBoxAdapter(
            child: _GoToVerseCard(
              verse: verse,
              onOpen: () {
                _recordSearch();
                openQuranVerse(context, verse, source: ZikrOpenSource.search);
              },
            ),
          ),
        ),
      for (final source in open) ...[
        SliverPadding(
          padding: gutter.copyWith(bottom: 8),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              label: l10n.searchSection(
                  source.label(l10n), bySource[source]!.length),
              action: l10n.searchHide,
              actionSemantics: l10n.searchHideSource(source.label(l10n)),
              onAction: () => _setOpen(source, false),
            ),
          ),
        ),
        SliverPadding(
          padding: gutter.copyWith(bottom: 14),
          sliver: SliverCardList(
            itemCount: bySource[source]!.length,
            itemBuilder: (context, i) => _buildRow(
              bySource[source]![i],
              source,
              query: query,
              first: i == 0,
              last: i == bySource[source]!.length - 1,
            ),
          ),
        ),
      ],
      for (final source in folded)
        SliverPadding(
          padding: gutter.copyWith(bottom: 14),
          sliver: SliverToBoxAdapter(
            child: _FoldedSection(
              source: source,
              count: bySource[source]!.length,
              onShow: () => _setOpen(source, true),
            ),
          ),
        ),
    ];
  }

  Widget _buildRow(
    UidTitleData entry,
    SearchSource source, {
    required String query,
    required bool first,
    required bool last,
  }) {
    final isBook = source == SearchSource.library;
    final item = UniversalData(entry.uid, entry.title, isBook ? 1 : 0);
    final title = isUserAdmin ? '${entry.uid} ${item.displayTitle}' : null;

    if (!isBook && isZikrGroup(entry)) {
      return ZikrGroupRow(
        first: first,
        last: last,
        title: title ?? item.displayTitle,
        subtitle: _locations?[entry.uid],
        onTap: () => _open(entry),
      );
    }

    final subtitle = switch (source) {
      // Several books share near-identical titles (translations of the same
      // work, mostly), so the author is what tells them apart.
      SearchSource.library => entry.author,
      SearchSource.quran => context.l10n.quranVerseCount(
          surahInfoFor(surahForUid(entry.uid)!)?.ayahCount ?? 0),
      SearchSource.zikr => _locations?[entry.uid],
    };

    return ZikrListRow(
      item: item,
      title: title,
      subtitle: subtitle,
      highlight: query,
      first: first,
      last: last,
      onTap: () => _open(entry),
    );
  }
}

/// The round × beside the field that closes search.
class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final label = context.l10n.searchClose;
    void close() => Navigator.of(context).maybePop();

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: close,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: FindField.height,
          child: GlassSurface(
            borderRadius: BorderRadius.circular(FindField.height / 2),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: close,
                customBorder: const CircleBorder(),
                child: Center(
                  child: OutlineIcon(OutlineGlyph.close,
                      size: 22, color: colors.text, strokeWidth: 2.2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small upper-case heading with a text action on the right: "RECENT ·
/// Clear", "DUAS & MORE · 6 · Hide".
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.action,
    required this.actionSemantics,
    required this.onAction,
  });

  final String label;
  final String action;
  final String actionSemantics;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Row(
      children: [
        Expanded(child: GroupLabel(label)),
        Semantics(
          button: true,
          label: actionSemantics,
          excludeSemantics: true,
          onTap: onAction,
          child: InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              // The row is short, but the target is not.
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    action,
                    style: ShiaText.secondary.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One example under **Try**: what it finds, and the words that find it.
class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.label,
    required this.example,
    required this.onTap,
  });

  final String label;
  final String example;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: ShiaText.caption.copyWith(color: colors.textMuted)),
                const SizedBox(height: 1),
                Text(
                  example,
                  style: ShiaText.cardTitle.copyWith(color: colors.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A recent search, which fills the field again when tapped.
class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.term,
    required this.last,
    required this.onTap,
  });

  final String term;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                OutlineIcon(OutlineGlyph.clock,
                    size: 20, color: colors.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(term,
                      style: ShiaText.body.copyWith(color: colors.text)),
                ),
                OutlineIcon(OutlineGlyph.arrowRight,
                    size: 18, color: colors.chevron, strokeWidth: 2),
              ],
            ),
          ),
          // Under the text, clear of the clock.
          if (!last) Divider(height: 1, indent: 46, color: colors.divider),
        ],
      ),
    );
  }
}

/// A folded section: how many matches it has, and **Show**.
class _FoldedSection extends StatelessWidget {
  const _FoldedSection({
    required this.source,
    required this.count,
    required this.onShow,
  });

  final SearchSource source;
  final int count;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final label = source.label(l10n);

    return Semantics(
      button: true,
      label: count == 1
          ? l10n.searchOneMatch(label)
          : l10n.searchMatches(count, label),
      hint: l10n.searchShowSource(label),
      excludeSemantics: true,
      onTap: onShow,
      child: CardList(
        children: [
          CardListRow(
            first: true,
            last: true,
            minHeight: 56,
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.well,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  HomeGlyph(type: source.glyph, size: 22, color: colors.accent),
            ),
            title: Text(count == 1
                ? l10n.searchOneMatch(label)
                : l10n.searchMatches(count, label)),
            trailing: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
              child: Text(
                l10n.searchShow,
                style: ShiaText.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ),
            onTap: onShow,
          ),
        ],
      ),
    );
  }
}

/// The verse a query names, offered first: its surah and number, and a
/// button that opens it.
class _GoToVerseCard extends StatelessWidget {
  const _GoToVerseCard({required this.verse, required this.onOpen});

  final VerseKey verse;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final surah = surahInfoFor(verse.surah);
    final name = surah?.englishName ?? l10n.quranSurahNumber(verse.surah);
    final ayah = verse.ayah ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupLabel(l10n.searchGoToVerse),
        const SizedBox(height: 8),
        Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.accent, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.well,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: HomeGlyph(
                          type: HomeGlyphType.surahs,
                          size: 28,
                          color: colors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.searchVerseTitle(name, '$verse'),
                            style: ShiaText.cardTitle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.text,
                            ),
                          ),
                          if (surah != null)
                            Text(
                              l10n.searchVerseOf(ayah, surah.ayahCount),
                              style: ShiaText.caption
                                  .copyWith(color: colors.textMuted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
                    shape: const StadiumBorder(),
                    textStyle: buttonTextStyle(context, ShiaText.body)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  child: Text(l10n.searchOpenVerse(ayah)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// What a search that found nothing shows: where it looked, how to search
/// differently, and a way to ask for what is missing.
class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.onRequest});

  final String query;
  final VoidCallback onRequest;

  /// The word to suggest searching for alone: the longest, which is the
  /// least likely to be a word every title has ("dua").
  String? get _word {
    final words = query.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.length < 2) return null;
    return words.reduce((a, b) => b.length > a.length ? b : a);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final word = _word;
    final muted = ShiaText.secondary.copyWith(
      height: 21 / 15,
      color: colors.textMuted,
    );

    Widget tip;
    if (word == null) {
      tip = Text(
        '${l10n.searchNoneLooked} ${l10n.searchNoneTipSpelling}',
        textAlign: TextAlign.center,
        style: muted,
      );
    } else {
      // The suggested word in bold, wherever the sentence puts it.
      final sentence = l10n.searchNoneTipWord(word);
      final at = sentence.indexOf(word);
      tip = Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${l10n.searchNoneLooked} '),
            if (at < 0)
              TextSpan(text: sentence)
            else ...[
              TextSpan(text: sentence.substring(0, at)),
              TextSpan(
                text: word,
                style:
                    TextStyle(fontWeight: FontWeight.w700, color: colors.text),
              ),
              TextSpan(text: sentence.substring(at + word.length)),
            ],
          ],
        ),
        textAlign: TextAlign.center,
        style: muted,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 64, 12, 22),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.well,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: OutlineIcon(OutlineGlyph.search,
                    size: 30, color: colors.accent),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  l10n.searchNoneTitle(query),
                  textAlign: TextAlign.center,
                  style: ShiaText.sectionTitle.copyWith(
                    height: 25 / 20,
                    color: colors.text,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              tip,
            ],
          ),
        ),
        Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: colors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.well,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: OutlineIcon(OutlineGlyph.playlistAdd,
                          color: colors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.searchStillMissing,
                            style:
                                ShiaText.cardTitle.copyWith(color: colors.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.searchStillMissingBody,
                            style: ShiaText.secondary
                                .copyWith(color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: onRequest,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    foregroundColor: colors.accent,
                    backgroundColor: colors.surface,
                    side: BorderSide(
                        color: Color.lerp(colors.line, colors.chevron, 0.25)!),
                    shape: const StadiumBorder(),
                    textStyle: buttonTextStyle(context, ShiaText.body)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  child: Text(
                    l10n.searchRequest(
                        query.substring(0, math.min(query.length, 60))),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
