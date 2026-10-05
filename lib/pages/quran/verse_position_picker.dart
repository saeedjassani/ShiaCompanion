import 'package:flutter/material.dart';

import '../../utils/quran_index.dart';
import '../../l10n/l10n.dart';

/// Picks one verse of the Quran - where a recitation track starts, or where
/// it carries on from.
///
/// Three ways in, for three kinds of reader: type it (`33:33`, `33`,
/// `juz 22`), browse by surah, or browse by juz - each ending on a grid of
/// ayah numbers, which a juz splits into the surahs it runs across. Nothing
/// is chosen until the button at the bottom, which always says exactly what
/// will be chosen, so a stray tap in the grid costs nothing.
///
/// [describe] words a verse the way the caller shows it ("Juz 22 · Al-Ahzab
/// 33"), and [confirmVerb] heads the button ("Start at", "Continue from").
Future<VerseKey?> showVersePositionPicker(
  BuildContext context, {
  required VerseKey initial,
  required bool browseByJuz,
  required String Function(VerseKey verse) describe,
  required String confirmVerb,
}) {
  return showModalBottomSheet<VerseKey>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _VersePositionPicker(
      initial: initial,
      browseByJuz: browseByJuz,
      describe: describe,
      confirmVerb: confirmVerb,
    ),
  );
}

/// One surah's ayahs inside a unit being browsed - the whole surah, or the
/// part of it a juz covers.
class _AyahRun {
  const _AyahRun(this.surah, this.from, this.to);

  final int surah;
  final int from;
  final int to;

  int get length => to - from + 1;
}

/// A juz or a surah opened to its ayahs.
class _OpenUnit {
  const _OpenUnit({required this.isJuz, required this.number});

  final bool isJuz;
  final int number;

  List<_AyahRun> get runs {
    if (!isJuz) return [_AyahRun(number, 1, surahAyahCounts[number - 1])];
    final juz = allJuz()[number - 1];
    final start = juz.start;
    final end = juz.end;
    return [
      for (var surah = start.surah; surah <= end.surah; surah++)
        _AyahRun(
          surah,
          surah == start.surah ? start.ayah! : 1,
          surah == end.surah ? end.ayah! : surahAyahCounts[surah - 1],
        ),
    ];
  }

  bool contains(VerseKey verse) {
    final ayah = verse.ayah ?? 1;
    return isJuz ? juzOf(verse.surah, ayah) == number : verse.surah == number;
  }

  VerseKey get first {
    final run = runs.first;
    return VerseKey(run.surah, run.from);
  }
}

final RegExp _juzQueryPattern = RegExp(
    r'^(?:juz|para|parah|sipara|j|p)\s*(\d{1,2})$',
    caseSensitive: false);

class _VersePositionPicker extends StatefulWidget {
  const _VersePositionPicker({
    required this.initial,
    required this.browseByJuz,
    required this.describe,
    required this.confirmVerb,
  });

  final VerseKey initial;
  final bool browseByJuz;
  final String Function(VerseKey verse) describe;
  final String confirmVerb;

  @override
  State<_VersePositionPicker> createState() => _VersePositionPickerState();
}

class _VersePositionPickerState extends State<_VersePositionPicker> {
  final _queryController = TextEditingController();
  final _juzList = allJuz();
  final _surahs = allSurahs();

  late bool _browseByJuz = widget.browseByJuz;
  late VerseKey _selected =
      VerseKey(widget.initial.surah, widget.initial.ayah ?? 1);

  /// Always opens on the Surah / Juz list, with the unit holding the current
  /// choice highlighted and the choice itself - al-Fatihah on a new track -
  /// already in the bar, so "the beginning" is a single tap on Choose.
  _OpenUnit? _openUnit;
  String? _queryError;

  /// Bumped whenever the grid should bring [_selected] into view again - a
  /// typed verse landing in the unit already open, which builds no new grid.
  int _scrollRequest = 0;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  _OpenUnit _unitContaining(VerseKey verse) => _OpenUnit(
        isJuz: _browseByJuz,
        number:
            _browseByJuz ? juzOf(verse.surah, verse.ayah ?? 1) : verse.surah,
      );

  void _openUnitAt(_OpenUnit unit, {VerseKey? select}) {
    setState(() {
      _openUnit = unit;
      if (select != null) {
        _selected = select;
      } else if (!unit.contains(_selected)) {
        // Ready to confirm "the start of Juz 12" without a second tap.
        _selected = unit.first;
      }
      _scrollRequest++;
    });
  }

  void _closeUnit() => setState(() => _openUnit = null);

  void _setBrowseByJuz(bool byJuz) => setState(() => _browseByJuz = byJuz);

  /// `33:33` lands on that verse, a bare `33` on the surah, `juz 22` on the
  /// juz - each opened in whichever browse mode fits what was typed.
  void _submitQuery(String raw) {
    final query = raw.trim();
    if (query.isEmpty) return;

    final juzMatch = _juzQueryPattern.firstMatch(query);
    if (juzMatch != null) {
      final juz = int.parse(juzMatch.group(1)!);
      if (juz < 1 || juz > _juzList.length) {
        setState(() => _queryError = context.l10n.pickerThirtyJuz);
        return;
      }
      _browseByJuz = true;
      _finishQuery(_OpenUnit(isJuz: true, number: juz));
      return;
    }

    final verse = VerseKey.tryParse(query);
    if (verse == null) {
      setState(() => _queryError = context.l10n.pickerTryVerse);
      return;
    }
    final ayah = verse.ayah;
    if (ayah == null) {
      _browseByJuz = false;
      _finishQuery(_OpenUnit(isJuz: false, number: verse.surah));
      return;
    }
    final exact = VerseKey(verse.surah, ayah);
    _finishQuery(_unitContaining(exact), select: exact);
  }

  void _finishQuery(_OpenUnit unit, {VerseKey? select}) {
    FocusScope.of(context).unfocus();
    _queryController.clear();
    _queryError = null;
    _openUnitAt(unit, select: select);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = _openUnit;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(theme, unit),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _queryController,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: context.l10n.pickerSearchHint,
                errorText: _queryError,
                filled: true,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) {
                if (_queryError != null) setState(() => _queryError = null);
              },
              onSubmitted: _submitQuery,
            ),
          ),
          if (unit == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(context.l10n.trackBySurah)),
                  ButtonSegment(value: true, label: Text(context.l10n.trackByJuz)),
                ],
                selected: {_browseByJuz},
                onSelectionChanged: (selection) =>
                    _setBrowseByJuz(selection.first),
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: unit == null
                  ? _UnitList(
                      key: ValueKey('units-$_browseByJuz'),
                      byJuz: _browseByJuz,
                      selected: _selected,
                      onOpen: (number) => _openUnitAt(
                        _OpenUnit(isJuz: _browseByJuz, number: number),
                      ),
                    )
                  : _AyahGrid(
                      key: ValueKey('grid-${unit.isJuz}-${unit.number}'),
                      unit: unit,
                      selected: _selected,
                      scrollRequest: _scrollRequest,
                      onSelect: (verse) => setState(() => _selected = verse),
                    ),
            ),
          ),
          _buildConfirmBar(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, _OpenUnit? unit) {
    final String title;
    final String? subtitle;
    if (unit == null) {
      title = context.l10n.pickerChooseVerse;
      subtitle = null;
    } else if (unit.isJuz) {
      final juz = _juzList[unit.number - 1];
      title = context.l10n.quranJuzNumber(unit.number);
      subtitle = context.l10n.pickerJuzRange(
          context.l10n.quranSurahAyah(
              _surahName(juz.start.surah), juz.start.ayah ?? 1),
          context.l10n.quranSurahAyah(
              _surahName(juz.end.surah), juz.end.ayah ?? 1));
    } else {
      final info = _surahs[unit.number - 1];
      title = '${info.number}. ${info.englishName}';
      final firstJuz = juzOf(info.number, 1);
      final lastJuz = juzOf(info.number, info.ayahCount);
      subtitle = context.l10n.pickerSurahDetails(
          context.l10n.quranAyahCount(info.ayahCount),
          firstJuz == lastJuz ? '$firstJuz' : '$firstJuz–$lastJuz');
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(unit == null ? 20 : 4, 0, 20, 4),
      child: Row(
        children: [
          if (unit != null)
            IconButton(
              tooltip: _browseByJuz ? context.l10n.pickerAllJuz : context.l10n.pickerAllSurahs,
              icon: const Icon(Icons.arrow_back),
              onPressed: _closeUnit,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmBar(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.confirmVerb,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      widget.describe(_selected),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: Text(context.l10n.pickerChoose),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _surahName(int surah) => _surahNameOf(surah);
}

String _surahNameOf(int surah) =>
    surahInfoFor(surah)?.englishName ?? L10n.current.quranSurahNumber(surah);

/// Every surah or every juz, opening onto the one [selected] falls in.
class _UnitList extends StatefulWidget {
  const _UnitList({
    super.key,
    required this.byJuz,
    required this.selected,
    required this.onOpen,
  });

  final bool byJuz;
  final VerseKey selected;
  final ValueChanged<int> onOpen;

  @override
  State<_UnitList> createState() => _UnitListState();
}

class _UnitListState extends State<_UnitList> {
  static const double _rowExtent = 64;

  final _juzList = allJuz();
  final _surahs = allSurahs();

  int get _selectedIndex => widget.byJuz
      ? juzOf(widget.selected.surah, widget.selected.ayah ?? 1) - 1
      : widget.selected.surah - 1;

  /// Opens with the current choice in view, a couple of rows down.
  late final _controller = ScrollController(
    initialScrollOffset: (_selectedIndex - 2).clamp(0, 200) * _rowExtent,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final byJuz = widget.byJuz;
    final selectedIndex = _selectedIndex;

    return ListView.builder(
      controller: _controller,
      itemExtent: _rowExtent,
      itemCount: byJuz ? _juzList.length : _surahs.length,
      itemBuilder: (context, index) {
        final isSelected = index == selectedIndex;
        final String title;
        final String subtitle;
        String? arabicName;
        if (byJuz) {
          final juz = _juzList[index];
          title = context.l10n.quranJuzNumber(juz.number);
          subtitle = context.l10n.pickerJuzFrom(context.l10n
              .quranSurahAyah(_surahNameOf(juz.start.surah), juz.start.ayah ?? 1));
        } else {
          final surah = _surahs[index];
          title = surah.englishName;
          subtitle = context.l10n.quranAyahCount(surah.ayahCount);
          if (surah.arabicName.isNotEmpty) arabicName = surah.arabicName;
        }
        return ListTile(
          selected: isSelected,
          selectedTileColor:
              colorScheme.secondaryContainer.withValues(alpha: 0.6),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: isSelected
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            foregroundColor:
                isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            child: Text('${index + 1}', style: const TextStyle(fontSize: 13)),
          ),
          title: Text(title),
          subtitle: Text(subtitle, maxLines: 1),
          trailing: arabicName == null
              ? const Icon(Icons.chevron_right)
              : Text(
                  arabicName,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 18),
                ),
          onTap: () => widget.onOpen(index + 1),
        );
      },
    );
  }
}

/// A unit's ayahs as a grid of numbers - one block for a surah, one per
/// surah it runs across for a juz.
class _AyahGrid extends StatefulWidget {
  const _AyahGrid({
    super.key,
    required this.unit,
    required this.selected,
    required this.scrollRequest,
    required this.onSelect,
  });

  final _OpenUnit unit;
  final VerseKey selected;
  final int scrollRequest;
  final ValueChanged<VerseKey> onSelect;

  @override
  State<_AyahGrid> createState() => _AyahGridState();
}

class _AyahGridState extends State<_AyahGrid> {
  static const double _cellExtent = 48;
  static const double _cellSpacing = 8;
  static const double _runHeaderExtent = 44;
  static const double _padding = 16;

  final _controller = ScrollController();
  late final List<_AyahRun> _runs = widget.unit.runs;

  @override
  void initState() {
    super.initState();
    _scrollToSelectedAfterLayout();
  }

  @override
  void didUpdateWidget(_AyahGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollRequest != widget.scrollRequest) {
      _scrollToSelectedAfterLayout();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static int _columnsFor(double width) {
    final usable = width - 2 * _padding + _cellSpacing;
    return (usable / (_cellExtent + _cellSpacing)).floor().clamp(4, 12);
  }

  /// Brings the chosen ayah into view, a row below the top. Worked out from
  /// the fixed cell sizes rather than by finding the cell, since a long
  /// surah's grid only builds the rows on screen.
  void _scrollToSelectedAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final columns = _columnsFor(context.size?.width ?? 360);
      final header = widget.unit.isJuz ? _runHeaderExtent : 0.0;
      const row = _cellExtent + _cellSpacing;
      final selected = widget.selected;

      var offset = 0.0;
      for (final run in _runs) {
        if (run.surah == selected.surah) {
          final index = (selected.ayah ?? 1) - run.from;
          offset += header + (index ~/ columns) * row - row;
          break;
        }
        offset += header + (run.length / columns).ceil() * row + _padding;
      }

      final position = _controller.position;
      _controller.jumpTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);
        return CustomScrollView(
          controller: _controller,
          slivers: [
            for (final run in _runs) ...[
              if (widget.unit.isJuz)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: _runHeaderExtent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _padding),
                      child: Row(
                        children: [
                          Text(
                            '${run.surah}. ${_surahNameOf(run.surah)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            run.from == run.to
                                ? context.l10n.pickerAyahSingle(run.from)
                                : context.l10n.pickerAyahRange(run.from, run.to),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(_padding, 0, _padding, _padding),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: _cellExtent,
                    mainAxisSpacing: _cellSpacing,
                    crossAxisSpacing: _cellSpacing,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    childCount: run.length,
                    (context, index) {
                      final verse = VerseKey(run.surah, run.from + index);
                      return _AyahCell(
                        ayah: verse.ayah!,
                        isSelected: verse == widget.selected,
                        onTap: () => widget.onSelect(verse),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AyahCell extends StatelessWidget {
  const _AyahCell({
    required this.ayah,
    required this.isSelected,
    required this.onTap,
  });

  final int ayah;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      selected: isSelected,
      button: true,
      label: 'Ayah $ayah',
      excludeSemantics: true,
      child: Material(
        color: isSelected
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              '$ayah',
              style: theme.textTheme.labelLarge?.copyWith(
                color:
                    isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
