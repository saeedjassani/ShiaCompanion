import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../l10n/l10n.dart';
import '../../theme/shia_colors.dart';
import '../../utils/quran_index.dart';
import '../../utils/verse_query.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import '../../widgets/responsive_content.dart' show MouseDragScroll;

/// "Go to a verse" (docs/DESIGN_SPEC.md, "Quran"; mockups `Verse-B-surah`
/// and `Verse-B-verse`): step 1 picks a surah - by name or number, from four
/// quick picks or the list - and step 2 a verse, from a grid of numbers in
/// groups of 50. Nothing opens until the button that names the verse, so a
/// stray tap costs nothing; "Start of surah" skips the grid.
///
/// Typing a whole reference in step 1 (`2:255`, `baqarah 255`) offers that
/// verse straight away.
///
/// A bottom sheet on phones, a centred dialog from tablet width up. Returns
/// the verse to open - a bare surah for its start - or null if closed.
Future<VerseKey?> showGoToVerseSheet(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width >= 600;
  final colors = ShiaColors.of(context);

  if (wide) {
    return showDialog<VerseKey>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: math.min(760, MediaQuery.sizeOf(context).height * 0.88),
          ),
          child: const GoToVersePicker(inDialog: true),
        ),
      ),
    );
  }

  return showModalBottomSheet<VerseKey>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => const FractionallySizedBox(
      heightFactor: 0.94,
      child: GoToVersePicker(),
    ),
  );
}

/// The picker inside [showGoToVerseSheet]; public for tests.
class GoToVersePicker extends StatefulWidget {
  const GoToVersePicker({super.key, this.inDialog = false});

  /// No drag handle in a dialog.
  final bool inDialog;

  /// The four surahs most often opened at a verse, offered before typing.
  static const List<int> quickPicks = [36, 18, 55, 67];

  @override
  State<GoToVersePicker> createState() => _GoToVersePickerState();
}

class _GoToVersePickerState extends State<GoToVersePicker> {
  late final List<SurahInfo> _surahs = allSurahs();
  final TextEditingController _query = TextEditingController();

  /// The surah being picked a verse of; null on step 1.
  SurahInfo? _surah;

  /// The surah last opened in step 2, marked in the list on the way back.
  int? _lastSurah;

  /// The chosen verse in [_surah]; nothing is chosen on arrival.
  int? _verse;

  /// The first verse of the group of 50 on show.
  int _rangeStart = 1;

  static const int _rangeSize = 50;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _openSurah(SurahInfo surah) {
    setState(() {
      _surah = surah;
      _lastSurah = surah.number;
      _verse = null;
      _rangeStart = 1;
    });
  }

  void _backToSurahs() => setState(() => _surah = null);

  void _finish(VerseKey verse) => Navigator.of(context).pop(verse);

  @override
  Widget build(BuildContext context) {
    final surah = _surah;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.inDialog)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Color.lerp(ShiaColors.of(context).line,
                    ShiaColors.of(context).chevron, 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        Expanded(
          child: surah == null ? _buildSurahStep() : _buildVerseStep(surah),
        ),
      ],
    );
  }

  Widget _header({
    required String title,
    required String subtitle,
    VoidCallback? onBack,
  }) {
    final colors = ShiaColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, widget.inDialog ? 16 : 12, 16, 0),
      child: Row(
        children: [
          if (onBack != null) ...[
            _WellButton(
              glyph: OutlineGlyph.chevronLeft,
              label: context.l10n.goToVerseBackToSurahs,
              onPressed: onBack,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 28 / 22,
                      fontWeight: FontWeight.w700,
                    ).copyWith(color: colors.text),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: ShiaText.secondary.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _WellButton(
            glyph: OutlineGlyph.close,
            label: context.l10n.commonClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // Step 1 - a surah.

  Widget _buildSurahStep() {
    final colors = ShiaColors.of(context);
    final query = _query.text.trim();
    final typedVerse = parseVerseQuery(query, surahs: _surahs);
    final matches = _filter(query);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          title: context.l10n.goToVerseTitle,
          subtitle: context.l10n.goToVerseStepSurah,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _SearchField(
            controller: _query,
            hint: context.l10n.goToVerseSurahHint,
            onChanged: (_) => setState(() {}),
            onSubmitted: () {
              if (typedVerse != null) {
                _finish(typedVerse);
              } else if (matches.length == 1) {
                _openSurah(matches.single);
              }
            },
          ),
        ),
        if (query.isEmpty) ...[
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _QuickPicksLabel(),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 44,
            child: MouseDragScroll(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: GoToVersePicker.quickPicks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final surah = _surahs[GoToVersePicker.quickPicks[index] - 1];
                  return ChoicePill(
                    label: '${surah.number} ${surah.englishName}',
                    onTap: () => _openSurah(surah),
                  );
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: matches.isEmpty && typedVerse == null
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Text(
                    context.l10n.goToVerseNoSurah(query),
                    textAlign: TextAlign.center,
                    style: ShiaText.body.copyWith(color: colors.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                      16, 0, 16, 16 + MediaQuery.paddingOf(context).bottom),
                  itemCount: matches.length + (typedVerse == null ? 0 : 1),
                  itemBuilder: (context, index) {
                    if (typedVerse != null) {
                      if (index == 0) {
                        return _TypedVerseRow(
                          verse: typedVerse,
                          surah: _surahs[typedVerse.surah - 1],
                          onTap: () => _finish(typedVerse),
                        );
                      }
                      index--;
                    }
                    final surah = matches[index];
                    return _SurahRow(
                      surah: surah,
                      selected: surah.number == _lastSurah,
                      onTap: () => _openSurah(surah),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// The surahs [query] picks out: by number (`2`, `11`...) or by name, as
  /// loosely spelled as [matchSurahNames] allows plus anywhere in the name.
  List<SurahInfo> _filter(String query) {
    if (query.isEmpty) return _surahs;
    final number = int.tryParse(query);
    if (number != null) {
      return [
        for (final surah in _surahs)
          if ('${surah.number}'.startsWith(query)) surah,
      ];
    }

    final loose = matchSurahNames(query, surahs: _surahs);
    final needle = query.toLowerCase();
    return [
      for (final surah in _surahs)
        if (loose.contains(surah) ||
            surah.englishName.toLowerCase().contains(needle) ||
            (surah.arabicName.isNotEmpty && surah.arabicName.contains(query)))
          surah,
    ];
  }

  // Step 2 - a verse of it.

  Widget _buildVerseStep(SurahInfo surah) {
    final colors = ShiaColors.of(context);
    final count = surah.ayahCount;
    final rangeEnd = math.min(_rangeStart + _rangeSize - 1, count);
    final verse = _verse;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          title: surah.englishName,
          subtitle: context.l10n.goToVerseStepVerse(count),
          onBack: _backToSurahs,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: OutlinedButton(
            onPressed: () => _finish(VerseKey(surah.number)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              foregroundColor: colors.text,
              side: BorderSide(
                  color: Color.lerp(colors.line, colors.chevron, 0.25)!),
              shape: const StadiumBorder(),
              textStyle: buttonTextStyle(context, ShiaText.body)
                  .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            child: Text(context.l10n.goToVerseStartOfSurah),
          ),
        ),
        if (count > _rangeSize) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: MouseDragScroll(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: (count / _rangeSize).ceil(),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final from = index * _rangeSize + 1;
                  final to = math.min(from + _rangeSize - 1, count);
                  return ChoicePill(
                    label: '$from–$to',
                    semanticsLabel: context.l10n.goToVerseRange(from, to),
                    selected: from == _rangeStart,
                    onTap: () => setState(() => _rangeStart = from),
                  );
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Six across on a phone, as many 56 px columns as fit wider.
              final columns =
                  math.max(6, ((constraints.maxWidth - 32 + 8) / 64).floor());
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 48,
                ),
                itemCount: rangeEnd - _rangeStart + 1,
                itemBuilder: (context, index) {
                  final number = _rangeStart + index;
                  return _VerseCell(
                    number: number,
                    selected: number == verse,
                    onTap: () => setState(() => _verse = number),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
          child: FilledButton(
            onPressed: verse == null
                ? null
                : () => _finish(VerseKey(surah.number, verse)),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
              shape: const StadiumBorder(),
              textStyle: buttonTextStyle(context, ShiaText.body)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            child: Text(
              verse == null
                  ? context.l10n.pickerChooseVerse
                  : context.l10n.goToVerseOpen(
                      surah.englishName, '${surah.number}:$verse'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickPicksLabel extends StatelessWidget {
  const _QuickPicksLabel();

  @override
  Widget build(BuildContext context) =>
      GroupLabel(context.l10n.goToVerseQuickPicks);
}

/// The 40 px round buttons in the picker's header (Back, Close).
class _WellButton extends StatelessWidget {
  const _WellButton({
    required this.glyph,
    required this.label,
    required this.onPressed,
  });

  final OutlineGlyph glyph;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: InkResponse(
          onTap: onPressed,
          radius: 22,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: colors.well, shape: BoxShape.circle),
                child: OutlineIcon(glyph,
                    size: 20, color: colors.accent, strokeWidth: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.well,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          OutlineIcon(OutlineGlyph.search,
              size: 20, color: colors.textMuted, strokeWidth: 2),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted(),
              textInputAction: TextInputAction.go,
              style: ShiaText.body.copyWith(color: colors.text),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: ShiaText.body.copyWith(color: colors.textMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({
    required this.surah,
    required this.selected,
    required this.onTap,
  });

  final SurahInfo surah;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: Row(
          children: [
            NumberWell(surah.number, selected: selected, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surah.englishName,
                      style: ShiaText.body.copyWith(
                        color: colors.text,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    Text(
                      context.l10n.quranVerseCount(surah.ayahCount),
                      style: ShiaText.secondary.copyWith(
                          fontSize: 14,
                          height: 18 / 14,
                          color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            if (surah.arabicName.isNotEmpty) ...[
              const SizedBox(width: 8),
              SurahArabicName(surah.arabicName, fontSize: 22),
            ],
          ],
        ),
      ),
    );
  }
}

/// A surah's Arabic name at the end of its row, in the reader's font.
class SurahArabicName extends StatelessWidget {
  const SurahArabicName(this.name, {super.key, this.fontSize = 21});

  final String name;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      textDirection: TextDirection.rtl,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: arabicFont,
        fontFamilyFallback: const ['Qalam'],
        fontSize: fontSize,
        height: 1.6,
        color: ShiaColors.of(context).text,
      ),
    );
  }
}

/// The row offering a verse typed in full, above the surah list.
class _TypedVerseRow extends StatelessWidget {
  const _TypedVerseRow({
    required this.verse,
    required this.surah,
    required this.onTap,
  });

  final VerseKey verse;
  final SurahInfo surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: colors.accent, shape: BoxShape.circle),
              child: OutlineIcon(OutlineGlyph.chevronRight,
                  size: 20, color: colors.onAccent, strokeWidth: 2.2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.goToVerseJump(surah.englishName, '$verse'),
                style: ShiaText.body.copyWith(
                    color: colors.accent, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerseCell extends StatelessWidget {
  const _VerseCell({
    required this.number,
    required this.selected,
    required this.onTap,
  });

  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.goToVerseVerseLabel(number),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        // Between the well and the sheet (#F6F1EA in light).
        color: selected
            ? colors.accent
            : Color.lerp(colors.surface, colors.well, 0.55),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 17,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.onAccent : colors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
