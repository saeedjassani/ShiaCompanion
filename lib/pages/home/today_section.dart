import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../data/uid_title_data.dart';
import '../../data/universal_data.dart';
import '../../l10n/l10n.dart';
import '../../services/analytics_service.dart';
import '../../theme/shia_colors.dart';
import '../../utils/todays_recitation.dart';
import '../../widgets/home_glyph.dart';
import '../../widgets/responsive_content.dart' show MouseDragScroll;
import '../../widgets/zikr_list_row.dart' show splitTrailingArabic;
import '../todays_recitation_page.dart';
import 'home_section.dart';

/// One card of Home's Today section: a recitation and the occasion it is for.
typedef TodayPick = ({TodaysRecitationKind kind, UidTitleData entry});

/// What kind of recitation a zikr is, for Today's order and glyph.
enum TodayRecitationType { dua, ziyarat, munajat, other }

final RegExp _leadingLetters = RegExp(r'^[A-Za-z]+');

/// Duas, ziyarats and munajat by category (E, G, H) or, for those filed
/// with a month's aamal (Dua Iftitah, Ziyarat Rajabiyah, Munajat
/// Shabaniyah), by title. Everything else is aamal, rites and merits pages.
@visibleForTesting
TodayRecitationType todayRecitationType(UidTitleData entry) {
  final prefix = _leadingLetters.stringMatch(entry.uid) ?? '';
  final title = entry.title.trimLeft();
  if (prefix == 'G' || title.startsWith('Ziyarat ')) {
    return TodayRecitationType.ziyarat;
  }
  if (prefix == 'H' || title.startsWith('Munajat ')) {
    return TodayRecitationType.munajat;
  }
  if (prefix == 'E' || title.startsWith('Dua ')) return TodayRecitationType.dua;
  return TodayRecitationType.other;
}

/// What Home's Today shows, in order, from [groups] (most specific occasion
/// first, as [buildTodaysRecitationGroups] gives them):
///
/// 1. Tonight's and today's occasion (the Night of Qadr, 15 Shaban), all of
///    it, its duas and ziyarats first.
/// 2. Every dua, ziyarat and munajat of the month, the weekday and every
///    day - what centres recite (Kumayl on Thursday, Nudba on Friday,
///    Ziyarat Warith and Ashura daily) - none ever left off.
/// 3. The month's and weekday's other aamal and rites, only to make up
///    [minimum] cards; See all has the rest.
@visibleForTesting
List<TodayPick> todayPicks(
  List<TodaysRecitationGroup> groups, {
  int minimum = TodaySection.minimumCards,
}) {
  bool isRecitation(UidTitleData entry) =>
      todayRecitationType(entry) != TodayRecitationType.other;
  bool isCatalogued(UidTitleData entry) =>
      const {'E', 'G', 'H'}.contains(_leadingLetters.stringMatch(entry.uid));
  bool isOccasion(TodaysRecitationKind kind) =>
      kind == TodaysRecitationKind.night || kind == TodaysRecitationKind.date;

  final occasion = <TodayPick>[];
  final recitations = <TodayPick>[];
  final rest = <TodayPick>[];
  for (final group in groups) {
    final picks = [
      for (final entry in group.items) (kind: group.kind, entry: entry),
    ];
    // Within an occasion, the Duas, Ziyarats and Munajat categories' own
    // entries before ones known only by title: Dua Kumayl before the
    // Ziyarat on Thursday.
    final first = [
      ...picks.where((pick) => isCatalogued(pick.entry)),
      ...picks.where(
          (pick) => isRecitation(pick.entry) && !isCatalogued(pick.entry)),
    ];
    final others = picks.where((pick) => !isRecitation(pick.entry));
    if (isOccasion(group.kind)) {
      occasion
        ..addAll(first)
        ..addAll(others);
    } else {
      recitations.addAll(first);
      rest.addAll(others);
    }
  }

  final shown = [...occasion, ...recitations];
  for (final pick in rest) {
    if (shown.length >= minimum) break;
    shown.add(pick);
  }
  return shown;
}

/// "Today": today's recitations as a sideways strip of cards, in
/// [todayPicks]' order, each with what it is for, and See all for the full
/// Today's Recitations. Hidden until the zikr index has loaded, and when
/// nothing is for today.
///
/// Checked once a minute, so it moves on by itself at Maghrib (tonight's
/// recitations) and at midnight.
class TodaySection extends StatefulWidget {
  const TodaySection({
    super.key,
    required this.onSeeAll,
    this.topSpacing = 0,
    this.horizontalPadding = 16,
  });

  final VoidCallback onSeeAll;

  /// The page gutter, drawn inside the strip so its cards scroll to the
  /// screen's edge, as Continue's do.
  final double horizontalPadding;

  /// Space above the section, only when it shows.
  final double topSpacing;

  /// How many cards Home tops up to with aamal and rites when the day has
  /// few duas and ziyarats.
  static const int minimumCards = 6;

  /// How wide a card is: narrower than Continue's, so a phone shows two
  /// and the start of a third, saying there is more to scroll.
  static const double cardWidth = 164;

  /// Lets tests pin "now".
  @visibleForTesting
  static DateTime Function() debugNow = DateTime.now;

  @override
  State<TodaySection> createState() => _TodaySectionState();
}

class _TodaySectionState extends State<TodaySection> {
  Timer? _timer;

  /// What the section last showed, to rebuild only when the day moves on.
  String _shown = '';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _signature(_rows(context.l10n)) != _shown) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<(TodayPick, String)> _rows(AppLocalizations l10n) {
    if (!zikrIndexReady.value) return const [];
    final now = TodaySection.debugNow();
    final today = todaysLunarDays(now: now);
    return [
      for (final pick in todayPicks(buildTodaysRecitationGroups(now: now)))
        (pick, todaysRecitationGroupLabel(pick.kind, today, l10n)),
    ];
  }

  static String _signature(List<(TodayPick, String)> rows) =>
      rows.map((row) => '${row.$2}\u0000${row.$1.entry.uid}').join('\u0001');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: zikrIndexReady,
      builder: (context, _, __) {
        final l10n = context.l10n;
        final rows = _rows(l10n);
        _shown = _signature(rows);
        if (rows.isEmpty) return const SizedBox.shrink();
        final gutter =
            EdgeInsets.symmetric(horizontal: widget.horizontalPadding);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: widget.topSpacing),
            Padding(
              padding: gutter,
              child: HomeSectionHeader(
                title: l10n.homeTodayTitle,
                actionLabel: l10n.homeTodaySeeAll,
                actionSemanticsLabel: l10n.homeTodaySeeAllSemantics,
                onAction: widget.onSeeAll,
              ),
            ),
            const SizedBox(height: 10),
            MouseDragScroll(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: gutter,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        SizedBox(
                          width: TodaySection.cardWidth,
                          child: _TodayCard(pick: rows[i].$1, when: rows[i].$2),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.pick, required this.when});

  final TodayPick pick;

  /// "For Thursday", "Night of 15 Shaban".
  final String when;

  static HomeGlyphType _glyph(UidTitleData entry) =>
      switch (todayRecitationType(entry)) {
        TodayRecitationType.dua => HomeGlyphType.duas,
        TodayRecitationType.ziyarat => HomeGlyphType.ziyaraat,
        TodayRecitationType.munajat => HomeGlyphType.munajaat,
        TodayRecitationType.other => HomeGlyphType.aamaal,
      };

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final entry = pick.entry;
    final title = splitTrailingArabic(
            UniversalData(entry.uid, entry.title, 0).displayTitle)
        .text;
    // Tonight's or today's occasion, the one thing the day is about.
    final occasion = pick.kind == TodaysRecitationKind.night ||
        pick.kind == TodaysRecitationKind.date;

    return HomeCard(
      child: InkWell(
        onTap: () => openTodaysRecitation(context, entry,
            source: ZikrOpenSource.homeToday),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeGlyph(type: _glyph(entry), size: 22, color: colors.accent),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ShiaText.cardTitle.copyWith(
                  height: 21 / 17,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              const SizedBox(height: 8),
              Text(
                when,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ShiaText.caption.copyWith(
                  height: 16 / 13,
                  fontWeight: occasion ? FontWeight.w700 : null,
                  color: occasion ? colors.accent : colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
