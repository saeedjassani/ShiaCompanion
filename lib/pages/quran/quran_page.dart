import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../data/universal_data.dart';
import '../../models/recitation_tracker_state.dart';
import '../../services/analytics_service.dart';
import '../../services/recitation_tracker_manager.dart';
import '../../services/saved_verses_manager.dart';
import '../../models/saved_verse.dart';
import '../../utils/quran_index.dart';
import '../../utils/quran_text_index.dart';
import '../../theme/shia_colors.dart';
import '../../widgets/favorite_icon.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import '../my_stats_page.dart';
import 'go_to_verse_sheet.dart';
import 'listen_and_follow_sheet.dart';
import 'quran_collections_tab.dart';
import 'quran_navigation.dart';
import 'recent_recitations_page.dart';
import 'recitation_track_sheet.dart';
import '../../l10n/l10n.dart';
import '../../widgets/responsive_content.dart' show MouseDragScroll;

/// The Quran screen: your recitation tracks, a way to jump to any verse, the
/// two ways of browsing - by surah and by juz - and the collections (duas,
/// verses about Imam Ali (as) and Imam al-Mahdi (atfs), the prophets'
/// stories, saved verses).
class QuranPage extends StatefulWidget {
  const QuranPage({super.key, this.initialTabIndex = 0});

  /// Which list opens: 0 surahs, 1 juz, 2 collections.
  final int initialTabIndex;

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  late final List<SurahInfo> _surahs;
  late final List<Juz> _juz;
  late _QuranView _view;
  QuranCollection _collection = QuranCollection.readSelected();
  bool _prewarmed = false;

  @override
  void initState() {
    super.initState();
    trackScreen('Quran Page');
    _surahs = allSurahs();
    _juz = allJuz();
    _view = _QuranView.values[
        widget.initialTabIndex.clamp(0, _QuranView.values.length - 1)];
    unawaited(RecitationTrackerManager.instance.loadRecitations());
    unawaited(SavedVersesManager.instance.loadSavedVerses());
  }

  /// Starts building the verse text index while the surah list is being read.
  ///
  /// Only for admins, since that is who can reach context.l10n.listenTitle - nobody
  /// else should pay 114 document reads for a button they cannot see. Doing it
  /// here rather than on the tap moves the wait off the path between tapping the
  /// microphone and the microphone actually listening, which matters most on web
  /// where every document is a separate request.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prewarmed || !isUserAdmin) return;
    _prewarmed = true;
    prewarmQuranTextIndex(DefaultAssetBundle.of(context));
  }

  Future<void> _open(VerseKey verse,
      {String source = ZikrOpenSource.quran}) async {
    await openQuranVerse(context, verse, source: source);
  }

  /// Listens to a recitation and opens the verse it turns out to be.
  ///
  /// Where the reader most recently was is handed to the matcher as context:
  /// someone following a recitation in al-Baqarah is most likely still in
  /// al-Baqarah, and a tie between two verses that read alike should break
  /// towards where they are. Deliberately not label-scoped - a recitation heard
  /// through the microphone belongs to whoever is reciting, not to a track.
  Future<void> _listenAndFollow() async {
    final verse = await showListenAndFollowSheet(
      context,
      readingAt: RecitationTrackerManager.instance.state.mostRecentPosition,
    );
    if (verse == null || !mounted) return;

    await _open(verse, source: ZikrOpenSource.quranListenAndFollow);
  }

  Future<void> _goToVerse() async {
    final verse = await showGoToVerseSheet(context);
    if (verse == null || !mounted) return;
    await _open(verse);
  }

  Future<void> _openJuz(int juz) async {
    await openQuranJuz(context, juz);
  }

  Future<void> _removeSaved(SavedVerse saved) {
    return SavedVersesManager.instance.unsave(saved.verse);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context, maxWidth: widePageWidth);

    return LargeTitlePage(
      maxWidth: widePageWidth,
      title: context.l10n.quranTitle,
      actions: [
        // The sessions themselves stay here, beside the reading they
        // record; the stats built from them live on My Stats with the rest
        // of the reader's stats.
        RoundIconButton(
          label: context.l10n.quranRecentSessions,
          icon: OutlineIcon(OutlineGlyph.history,
              size: 22, color: colors.accent),
          onPressed: () =>
              pushPageRoute(context, const RecentRecitationsPage()),
        ),
        RoundIconButton(
          label: context.l10n.statsTitle,
          icon:
              OutlineIcon(OutlineGlyph.stats, size: 22, color: colors.accent),
          onPressed: () => pushPageRoute(context, const MyStatsPage()),
        ),
        // Dark-launched alongside the rest of the Quran reading experience
        // (see zikr_page.dart's _surahNumber and home_menu.dart), so the
        // microphone prompt reaches nobody until the matching is known to be
        // worth the interruption.
        if (isUserAdmin)
          RoundIconButton(
            label: context.l10n.listenTitle,
            icon: Icon(Icons.mic_none, size: 22, color: colors.accent),
            onPressed: _listenAndFollow,
          ),
      ],
      slivers: [
        // Runs to the screen's edge, so the cards scroll out from under the
        // gutter rather than being cut off at it.
        SliverToBoxAdapter(child: _RecitationTrackCards(gutter: gutter)),
        SliverPadding(
          padding: gutter.copyWith(top: 14, bottom: 14),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(builder: (context, constraints) {
              final goToVerse = _GoToVerseButton(onPressed: _goToVerse);
              final switcher = SegmentedSwitcher<_QuranView>(
                segments: [
                  Segment(_QuranView.surahs, context.l10n.quranTabSurahs),
                  Segment(_QuranView.juz, context.l10n.quranTabJuz),
                  Segment(
                      _QuranView.collections, context.l10n.quranTabCollections),
                ],
                selected: _view,
                onChanged: (view) => setState(() => _view = view),
              );
              // Where the list goes two columns, neither needs the whole
              // width: they share a line, the switcher over the list's
              // first column.
              if (WideColumns.splits(constraints.maxWidth)) {
                return Row(
                  children: [
                    Expanded(child: switcher),
                    const SizedBox(width: 32),
                    Expanded(child: goToVerse),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [goToVerse, const SizedBox(height: 14), switcher],
              );
            }),
          ),
        ),
        SliverPadding(
          padding: gutter,
          sliver: switch (_view) {
            _QuranView.surahs => _SurahList(surahs: _surahs, onOpen: _open),
            _QuranView.juz => _JuzList(juz: _juz, onOpenJuz: _openJuz),
            // Saved verses sync, so the list follows them - including a
            // verse saved on another device.
            _QuranView.collections => ListenableBuilder(
                listenable: SavedVersesManager.instance,
                builder: (context, _) => QuranCollectionsSliver(
                  selected: _collection,
                  onSelect: (collection) {
                    setState(() => _collection = collection);
                    collection.remember();
                  },
                  saved: SavedVersesManager.instance.state.inMushafOrder,
                  onOpenVerse: _open,
                  onRemoveSaved: _removeSaved,
                ),
              ),
          },
        ),
      ],
    );
  }
}

/// The three ways the Quran screen lists the Quran.
enum _QuranView { surahs, juz, collections }

/// One resume card per recitation track - the default track first, as "My
/// reading" - and a card to start a new one.
///
/// This is what replaced the old single "Continue reciting" card: instead of
/// one global place to resume, every track keeps its own, since where you
/// left off reading with family and where you left off reading alone are not
/// the same place.
class _RecitationTrackCards extends StatelessWidget {
  const _RecitationTrackCards({required this.gutter});

  final EdgeInsets gutter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RecitationTrackerManager.instance,
      builder: (context, _) {
        final state = RecitationTrackerManager.instance.state;
        final labels = [unlabeledRecitationLabel, ...state.labels];

        return MouseDragScroll(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: gutter,
            // Every card as tall as the tallest, whatever the text size.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final label in labels) ...[
                    _TrackCard(label: label, state: state),
                    const SizedBox(width: 10),
                  ],
                  _AddTrackCard(onTap: () => showRecitationTrackSheet(context)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.label, required this.state});

  final String label;
  final RecitationTrackerState state;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final isDefault = label == unlabeledRecitationLabel;
    final target = state.resumeTargetFor(label);
    final percent = state.percentCompleteFor(label);
    final position = describeRecitationPosition(
      target.verse,
      byJuz: target.inJuz,
      compact: true,
    );
    final progress = percent > 0
        ? context.l10n
            .quranPercentRead(percent.toStringAsFixed(percent < 10 ? 1 : 0))
        : target.isStart
            ? context.l10n.quranStartReading
            : null;
    final name = isDefault ? context.l10n.quranMyReading : label;

    // The default track is the one most people only ever use, so it is the
    // dark card; the rest sit on the surface.
    final fill = isDefault ? colors.prayerCard : colors.surface;
    final border = isDefault ? colors.prayerCardBorder : colors.line;
    final labelColor =
        isDefault ? colors.onPrayerCardMuted : colors.textMuted;
    final titleColor = isDefault ? colors.onPrayerCard : colors.text;
    final progressColor = isDefault ? colors.gold : colors.textMuted;

    return SizedBox(
      width: 200,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _resume(context),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShiaText.caption
                            .copyWith(fontSize: 13, color: labelColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        position,
                        style: ShiaText.cardTitle.copyWith(color: titleColor),
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          progress,
                          style:
                              ShiaText.caption.copyWith(color: progressColor),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isDefault)
                  Tooltip(
                    message: context.l10n.quranEditTrack(label),
                    excludeFromSemantics: true,
                    child: Semantics(
                      button: true,
                      label: context.l10n.quranEditTrack(label),
                      excludeSemantics: true,
                      onTap: () =>
                          showRecitationTrackSheet(context, label: label),
                      child: InkResponse(
                        onTap: () =>
                            showRecitationTrackSheet(context, label: label),
                        radius: 20,
                        child: SizedBox.square(
                          dimension: 40,
                          child: Icon(Icons.more_horiz,
                              size: 20, color: labelColor),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resume(BuildContext context) async {
    final target = state.resumeTargetFor(label);
    if (target.inJuz) {
      await openQuranJuz(
        context,
        target.juz,
        at: target.verse,
        source: ZikrOpenSource.quranResume,
        recitationLabel: label,
      );
      return;
    }
    await openQuranVerse(
      context,
      target.verse,
      source: ZikrOpenSource.quranResume,
      recitationLabel: label,
    );
  }
}

class _AddTrackCard extends StatelessWidget {
  const _AddTrackCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);

    return SizedBox(
      width: 120,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlineIcon(OutlineGlyph.plus,
                    size: 22, color: colors.accent, strokeWidth: 2),
                const SizedBox(height: 4),
                Text(
                  context.l10n.quranNewTrack,
                  textAlign: TextAlign.center,
                  style: ShiaText.caption.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens [showGoToVerseSheet].
class _GoToVerseButton extends StatelessWidget {
  const _GoToVerseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: OutlineIcon(OutlineGlyph.search,
          size: 20, color: colors.accent, strokeWidth: 2),
      label: Text(context.l10n.goToVerseTitle),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: colors.surface,
        foregroundColor: colors.accent,
        side: BorderSide(color: colors.accent),
        shape: const StadiumBorder(),
        textStyle: buttonTextStyle(context, ShiaText.body)
            .copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SurahList extends StatelessWidget {
  const _SurahList({required this.surahs, required this.onOpen});

  final List<SurahInfo> surahs;
  final void Function(VerseKey verse) onOpen;

  @override
  Widget build(BuildContext context) {
    return SliverCardList(
      itemCount: surahs.length,
      itemBuilder: (context, index) {
        final surah = surahs[index];
        // The same UniversalData shape the category lists build, so
        // favouriting a surah here is the same favourite as anywhere else.
        final itemData = UniversalData(
          surah.uid,
          items[surah.uid]?.toString() ?? surah.fullTitle,
          0,
        );

        return CardListRow(
          first: index == 0,
          last: index == surahs.length - 1,
          minHeight: 60,
          leading: NumberWell(surah.number),
          title: Text(surah.englishName),
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
              FavoriteHeartButton(favorite: itemData),
            ],
          ),
          onTap: () => onOpen(VerseKey(surah.number)),
        );
      },
    );
  }
}

class _JuzList extends StatelessWidget {
  const _JuzList({required this.juz, required this.onOpenJuz});

  final List<Juz> juz;
  final void Function(int juz) onOpenJuz;

  @override
  Widget build(BuildContext context) {
    return SliverCardList(
      itemCount: juz.length,
      itemBuilder: (context, index) {
        final part = juz[index];
        return CardListRow(
          first: index == 0,
          last: index == juz.length - 1,
          minHeight: 60,
          leading: NumberWell(part.number),
          title: Text(context.l10n.quranJuzNumber(part.number)),
          subtitle: Text(
            '${_verseLabel(part.start)} → ${_verseLabel(part.end)}',
          ),
          onTap: () => onOpenJuz(part.number),
        );
      },
    );
  }

  String _verseLabel(VerseKey verse) {
    final name = surahInfoFor(verse.surah)?.englishName ??
        L10n.current.quranSurahNumber(verse.surah);
    return L10n.current.quranSurahAyah(name, verse.ayah ?? 1);
  }
}
