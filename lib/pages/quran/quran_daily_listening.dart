import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../models/quran_listening.dart';
import '../../models/zikr_playlist.dart';
import '../../services/playlist_audio_service.dart';
import '../../services/quran_listening_store.dart';
import '../../services/zikr_playlist_store.dart';
import '../../theme/shia_colors.dart';
import '../../utils/quran_index.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/choice_sheet.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import 'quran_navigation.dart';
import 'verse_position_picker.dart';

/// "Al-Baqarah 2:142", in the app's digits.
String describeListeningVerse(VerseKey verse, [AppLocalizations? l10n]) {
  final surah = surahInfoFor(verse.surah)?.displayName ?? '';
  return localizeDigits('$surah $verse', l10n ?? L10n.current).trim();
}

/// "15 min a day", "A juz a day", "No daily limit".
String quranDailyGoalLabel(QuranListeningGoal goal, [AppLocalizations? l10n]) {
  final strings = l10n ?? L10n.current;
  final minutes = goal.minutes;
  if (minutes != null) return strings.quranDailyGoalMinutes(minutes);
  return goal.juz ? strings.quranDailyGoalJuz : strings.quranDailyGoalOpen;
}

/// One line on where day-by-day listening stands: "Next: Al-Baqarah 2:142 ·
/// 15 min a day", or "Done for today · next: Al-Baqarah 2:200".
String quranDailyStatus(QuranListeningState state, [AppLocalizations? l10n]) {
  final strings = l10n ?? L10n.current;
  final next = describeListeningVerse(state.nextVerse, strings);
  if (state.goalMetToday) return strings.quranDailyDoneToday(next);
  return '${strings.quranDailyNext(next)} · '
      '${quranDailyGoalLabel(state.goal, strings)}';
}

/// Plays the Quran day by day: in the reader's "Quran, Day by Day" playlist
/// when they still have it, so the capsule's "Open playlist" has somewhere
/// to go, or on its own.
Future<void> playQuranDaily() async {
  final audio = PlaylistAudioService.instance;
  final current = audio.current;
  if (current != null && current.daily) {
    await audio.togglePlay();
    return;
  }
  final playlist =
      ZikrPlaylistStore.instance.byId(ZikrPlaylistStore.quranDayByDay.id) ??
      ZikrPlaylist(
        id: '${PlaylistAudioService.singleZikrIdPrefix}$quranDailyUid',
        name: L10n.current.playlistDefaultQuranDayByDay,
        zikrUids: const [quranDailyUid],
        updatedAt: DateTime.now().toUtc(),
      );
  final start = playlist.zikrUids.indexOf(quranDailyUid);
  final result = await audio.play(
    playlist,
    startZikrIndex: start < 0 ? 0 : start,
  );
  final message = result.message;
  if (message != null) showToast(message);
}

/// Where listening through the Quran stands, and its settings: how much a
/// day, and where it carries on from.
Future<void> showQuranDailySheet(BuildContext context) {
  return showRevampSheet<void>(
    context,
    title: context.l10n.quranDailySheetTitle,
    builder: (sheetContext) => const _QuranDailySheet(),
  );
}

class _QuranDailySheet extends StatelessWidget {
  const _QuranDailySheet();

  Future<void> _chooseGoal(BuildContext context, QuranListeningGoal current) {
    final l10n = context.l10n;
    return showChoiceSheet<QuranListeningGoal>(
      context,
      title: l10n.quranDailyAmount,
      body: l10n.quranDailyAmountHint,
      current: current,
      choices: [
        for (final goal in QuranListeningGoal.values)
          Choice(
            goal,
            quranDailyGoalLabel(goal, l10n),
            hint: goal.juz ? l10n.quranDailyGoalJuzHint : null,
          ),
      ],
    ).then((picked) {
      if (picked != null) QuranListeningStore.instance.setGoal(picked);
    });
  }

  Future<void> _chooseStart(BuildContext context, VerseKey current) async {
    final l10n = context.l10n;
    final picked = await showVersePositionPicker(
      context,
      initial: current,
      browseByJuz: false,
      describe: (verse) => describeListeningVerse(verse, l10n),
      confirmVerb: l10n.trackContinueFrom,
    );
    if (picked == null) return;
    QuranListeningStore.instance.startAt(ordinalOfVerse(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final store = QuranListeningStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final state = store.state;
        final percent = state.progress * 100;
        final minutesProgress = state.minutesProgress(store.now());
        final stats = [
          l10n.quranPercentRead(
            localizeDigits(
              percent.toStringAsFixed(percent > 0 && percent < 10 ? 1 : 0),
              l10n,
            ),
          ),
          if (state.daysListened > 0)
            l10n.quranDailyDaysListened(state.daysListened),
          if (state.khatms > 0) l10n.quranDailyKhatms(state.khatms),
        ].join(' · ');
        final minutes = state.goal.minutes;
        final today = state.goalMetToday
            ? l10n.quranDailyDoneTodayShort
            : minutes != null
            ? l10n.quranDailyTodayMinutes(state.secondsToday ~/ 60, minutes)
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.quranDailySheetHint,
                style: ShiaText.secondary.copyWith(color: colors.textMuted),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.quranDailyNext(
                  describeListeningVerse(state.nextVerse, l10n),
                ),
                style: ShiaText.cardTitle.copyWith(color: colors.text),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 6,
                color: colors.accent,
                backgroundColor: colors.well,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                stats,
                style: ShiaText.caption.copyWith(color: colors.textMuted),
              ),
            ),
            if (today != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (minutesProgress != null && !state.goalMetToday) ...[
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        value: minutesProgress,
                        strokeWidth: 3,
                        color: colors.accent,
                        backgroundColor: colors.well,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (state.goalMetToday) ...[
                    OutlineIcon(
                      OutlineGlyph.check,
                      size: 18,
                      color: colors.accent,
                      strokeWidth: 2.4,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      today,
                      style: ShiaText.secondary.copyWith(color: colors.text),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            CardList(
              children: [
                CardListRow(
                  first: true,
                  title: Text(l10n.quranDailyAmount),
                  subtitle: Text(quranDailyGoalLabel(state.goal, l10n)),
                  trailing: OutlineIcon(
                    OutlineGlyph.chevronRight,
                    size: 16,
                    color: colors.chevron,
                  ),
                  onTap: () => _chooseGoal(context, state.goal),
                ),
                CardListRow(
                  title: Text(l10n.quranDailyStartFrom),
                  trailing: OutlineIcon(
                    OutlineGlyph.chevronRight,
                    size: 16,
                    color: colors.chevron,
                  ),
                  onTap: () => _chooseStart(context, state.nextVerse),
                ),
                CardListRow(
                  last: state.next <= 1,
                  title: Text(l10n.quranDailyOpenReader),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(openQuranVerse(context, state.nextVerse));
                  },
                ),
                if (state.next > 1)
                  CardListRow(
                    last: true,
                    title: Text(l10n.quranDailyStartOver),
                    onTap: () => store.startAt(1),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ListenableBuilder(
              listenable: PlaylistAudioService.instance,
              builder: (context, _) {
                final audio = PlaylistAudioService.instance;
                final playing =
                    (audio.current?.daily ?? false) && audio.isPlaying;
                return PageButton(
                  filled: true,
                  glyph: playing ? OutlineGlyph.pause : OutlineGlyph.play,
                  label: playing ? l10n.commonPause : l10n.quranDailyListen,
                  busy: audio.isStarting,
                  onPressed: playQuranDaily,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// The Quran screen's way into listening day by day: where it carries on
/// from, a play button, and the settings behind a tap.
class QuranDailyListeningCard extends StatelessWidget {
  const QuranDailyListeningCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        QuranListeningStore.instance,
        PlaylistAudioService.instance,
      ]),
      builder: (context, _) {
        final audio = PlaylistAudioService.instance;
        final current = audio.current;
        final daily = current != null && current.daily;
        final playing = daily && audio.isPlaying;
        final state = QuranListeningStore.instance.state;
        return CardList(
          children: [
            CardListRow(
              first: true,
              last: true,
              minHeight: 68,
              leading: Semantics(
                button: true,
                label: playing ? l10n.commonPause : l10n.quranDailyListen,
                excludeSemantics: true,
                onTap: playQuranDaily,
                child: Material(
                  color: colors.accent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: playQuranDaily,
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(
                        child: OutlineIcon(
                          playing ? OutlineGlyph.pause : OutlineGlyph.play,
                          size: 20,
                          color: colors.onAccent,
                          strokeWidth: 2.2,
                          filled: !playing,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              title: Text(l10n.playlistDefaultQuranDayByDay),
              titleStyle: ShiaText.cardTitle,
              subtitle: Text(
                daily ? current.title : quranDailyStatus(state, l10n),
                style: daily ? TextStyle(color: colors.accent) : null,
              ),
              trailing: OutlineIcon(
                OutlineGlyph.chevronRight,
                size: 16,
                color: colors.chevron,
              ),
              onTap: () => showQuranDailySheet(context),
            ),
          ],
        );
      },
    );
  }
}
