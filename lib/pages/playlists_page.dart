import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../constants.dart';
import '../data/uid_title_data.dart';
import '../models/zikr_audio_track.dart';
import '../models/zikr_playlist.dart';
import '../services/analytics_service.dart';
import '../services/zikr_translations.dart';
import '../services/audio_download_store.dart';
import '../services/favorites_manager.dart';
import '../services/playlist_audio_service.dart';
import '../services/zikr_audio_index.dart';
import '../services/zikr_playlist_store.dart';
import '../theme/shia_colors.dart';
import '../widgets/audio_download_button.dart';
import '../widgets/choice_sheet.dart';
import '../widgets/find_field.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import 'downloaded_audio_page.dart';
import 'zikr/zikr_page.dart';
import '../l10n/l10n.dart';

/// The zikr's title as the index knows it, falling back to its uid while the
/// index is still loading.
String _zikrTitle(String uid) {
  final title = items[uid]?.toString().trim() ?? '';
  return title.isEmpty ? uid : zikrDisplayTitle(uid, title);
}

/// The content uid behind a possibly-aliased key: `G17|L4` plays `L4`.
String _contentUid(String uid) => UidTitleData(uid, '').getFirstUId();

Future<String?> _promptForName(
  BuildContext context, {
  required String title,
  String initial = '',
  required String action,
}) {
  return showRevampSheet<String>(
    context,
    title: title,
    closeLabel: context.l10n.commonCancel,
    builder: (_) => _NameForm(initial: initial, action: action),
  );
}

/// The name field of [_promptForName] and its button; pops the trimmed name.
class _NameForm extends StatefulWidget {
  const _NameForm({required this.initial, required this.action});

  final String initial;
  final String action;

  @override
  State<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends State<_NameForm> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: ShiaText.body.copyWith(color: colors.text),
          decoration: revampFieldDecoration(context,
              hint: context.l10n.playlistNameHint),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 14),
        PageButton(
          label: widget.action,
          filled: true,
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }
}

Future<void> _startPlaylist(
  BuildContext context,
  ZikrPlaylist playlist, {
  int startZikrIndex = 0,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await PlaylistAudioService.instance
      .play(playlist, startZikrIndex: startZikrIndex);
  final message = switch (result) {
    PlaylistStartResult.started => null,
    PlaylistStartResult.startedDownloadedOnly =>
      context.l10n.playlistOfflinePartial,
    PlaylistStartResult.nothingToPlay => context.l10n.playlistNothingToPlay,
    PlaylistStartResult.offlineNothingDownloaded =>
      context.l10n.playlistOfflineNothingDownloaded,
    PlaylistStartResult.failed => context.l10n.playlistStartFailed,
  };
  if (message == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// The recordings [playlist] plays, in order: the chosen ones of each zikr.
List<ZikrAudioTrack> _tracksOf(ZikrPlaylist playlist) => [
      for (final uid in playlist.zikrUids)
        ...playlist.tracksFor(uid, ZikrAudioIndex.instance.tracksFor(uid)),
    ];

String _trackLabel(ZikrAudioTrack track, int index) =>
    track.label ?? L10n.current.audioRecordingNumber(index + 1);

/// Lets the reader pick which of [uid]'s recordings [playlist] plays - at
/// least one, since a zikr with none picked would silently drop out.
Future<void> _chooseRecordings(
  BuildContext context,
  ZikrPlaylist playlist,
  String uid,
  List<ZikrAudioTrack> available,
) async {
  final chosen = {
    for (final track in playlist.tracksFor(uid, available)) track.file,
  };
  final picked = await showRevampSheet<List<String>>(
    context,
    title: _zikrTitle(uid),
    closeLabel: context.l10n.commonCancel,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final colors = ShiaColors.of(sheetContext);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                context.l10n.playlistChooseRecordingsHint,
                style: ShiaText.secondary.copyWith(color: colors.textMuted),
              ),
            ),
            const SizedBox(height: 10),
            CardList(children: [
              for (var i = 0; i < available.length; i++)
                Builder(builder: (context) {
                  final file = available[i].file;
                  final on = chosen.contains(file);
                  // Unticking the last one would leave nothing to play.
                  final locked = on && chosen.length == 1;
                  void toggle() => setSheetState(
                      () => on ? chosen.remove(file) : chosen.add(file));
                  return MergeSemantics(
                    child: CardListRow(
                      first: i == 0,
                      last: i == available.length - 1,
                      title: Text(_trackLabel(available[i], i)),
                      subtitle: available[i].reciter == null
                          ? null
                          : Text(available[i].reciter!),
                      trailing: Checkbox(
                        value: on,
                        activeColor: colors.accent,
                        onChanged: locked ? null : (_) => toggle(),
                      ),
                      onTap: locked ? null : toggle,
                    ),
                  );
                }),
            ]),
            const SizedBox(height: 14),
            PageButton(
              label: context.l10n.commonDone,
              filled: true,
              onPressed: () => Navigator.of(sheetContext).pop([
                for (final track in available)
                  if (chosen.contains(track.file)) track.file,
              ]),
            ),
          ],
        );
      },
    ),
  );
  if (picked == null || picked.isEmpty) return;
  await ZikrPlaylistStore.instance.setTrackFiles(playlist.id, uid, picked);
}

void _openDownloads(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => const DownloadedAudioPage(),
  ));
}

/// Adds a zikr to one of the reader's playlists, or to a new one - opened from
/// the recitation player on a zikr page. [track] is the recording the player
/// has selected when the zikr has several: that is the one the playlist
/// gets, rather than all of them.
Future<void> showAddToPlaylistSheet(
  BuildContext context, {
  required String zikrUid,
  required String zikrTitle,
  ZikrAudioTrack? track,
}) async {
  final uid = _contentUid(zikrUid);
  final store = ZikrPlaylistStore.instance;
  final messenger = ScaffoldMessenger.of(context);

  final choice = await showRevampSheet<Object>(
    context,
    title: context.l10n.playlistAddTo,
    builder: (sheetContext) {
      final colors = ShiaColors.of(sheetContext);
      final playlists = store.playlists;
      Widget well(OutlineGlyph glyph) => Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.well,
              borderRadius: BorderRadius.circular(12),
            ),
            child: OutlineIcon(glyph, size: 20, color: colors.accent),
          );
      return CardList(children: [
        CardListRow(
          first: true,
          last: playlists.isEmpty,
          leading: well(OutlineGlyph.plus),
          title: Text(
            context.l10n.playlistNew,
            style: TextStyle(color: colors.accent, fontWeight: FontWeight.w600),
          ),
          onTap: () => Navigator.of(sheetContext).pop(true),
        ),
        for (final (i, playlist) in playlists.indexed)
          CardListRow(
            last: i == playlists.length - 1,
            leading: well(OutlineGlyph.playlist),
            title: Text(playlist.name),
            subtitle: Text(_countLabel(playlist.zikrUids.length)),
            trailing: SizedBox.square(
              dimension: 44,
              child: _hasRecording(playlist, uid, track)
                  ? Center(
                      child: OutlineIcon(OutlineGlyph.check,
                          size: 22, color: colors.accent, strokeWidth: 2.4),
                    )
                  : null,
            ),
            onTap: () => Navigator.of(sheetContext).pop(playlist),
          ),
      ]);
    },
  );
  if (!context.mounted) return;

  if (choice == true) {
    final name = await _promptForName(
      context,
      title: context.l10n.playlistNew,
      action: context.l10n.commonCreate,
    );
    if (name == null) return;
    await store.create(
      name,
      zikrUids: [uid],
      trackFiles: track == null
          ? const {}
          : {
              uid: [track.file]
            },
    );
    messenger.showSnackBar(
        SnackBar(content: Text(L10n.current.playlistAddedTo(name))));
  } else if (choice is ZikrPlaylist) {
    if (_hasRecording(choice, uid, track)) {
      messenger.showSnackBar(
          SnackBar(content: Text(L10n.current.playlistAlreadyIn(choice.name))));
      return;
    }
    if (choice.zikrUids.contains(uid) && track != null) {
      // The zikr is there with other recordings: add this one alongside.
      final available = ZikrAudioIndex.instance.tracksFor(uid);
      final current = {
        for (final chosen in choice.tracksFor(uid, available)) chosen.file,
        track.file,
      };
      await store.setTrackFiles(choice.id, uid, [
        for (final recording in available)
          if (current.contains(recording.file)) recording.file,
      ]);
    } else {
      await store.addZikr(choice.id, uid, trackFile: track?.file);
    }
    messenger.showSnackBar(
        SnackBar(content: Text(L10n.current.playlistAddedTo(choice.name))));
  }
}

/// Whether [playlist] already plays zikr [uid] - and, when a particular
/// recording is being added, that recording of it.
bool _hasRecording(ZikrPlaylist playlist, String uid, ZikrAudioTrack? track) {
  if (!playlist.zikrUids.contains(uid)) return false;
  if (track == null) return true;
  return playlist
      .tracksFor(uid, ZikrAudioIndex.instance.tracksFor(uid))
      .any((chosen) => chosen.file == track.file);
}

// "Zikr" is its own plural here, the way the rest of the app uses it.
String _countLabel(int count) => L10n.current.zikrCount(count);

/// The 48 px round play / pause button at the start of a playlist's row.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.label,
    required this.onPressed,
  });

  final bool playing;

  /// What a screen reader says: "Play Every morning".
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Tooltip(
      message: playing ? context.l10n.commonPause : context.l10n.commonPlay,
      excludeFromSemantics: true,
      child: Semantics(
        container: true,
        button: true,
        enabled: onPressed != null,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: Material(
          color: onPressed == null
              ? colors.accent.withValues(alpha: 0.4)
              : colors.accent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: OutlineIcon(
                  playing ? OutlineGlyph.pause : OutlineGlyph.play,
                  size: 22,
                  color: colors.onAccent,
                  strokeWidth: 2.2,
                  filled: !playing,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The reader's audio playlists (docs/DESIGN_SPEC.md, "Playlists and
/// downloads"; mockup `R3-Playlists`): a morning set of Dua Ahad and
/// Ziyarat Ashura, say, started with one tap and left playing in the
/// background.
class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  // Which playlists are downloaded needs every zikr's recordings.
  bool _audioReady = ZikrAudioIndex.instance.isLoaded;

  @override
  void initState() {
    super.initState();
    AudioDownloadStore.instance.load();
    if (_audioReady) return;
    ZikrAudioIndex.instance.load().then((_) {
      if (mounted) setState(() => _audioReady = true);
    });
  }

  Future<void> _create(BuildContext context) async {
    final name = await _promptForName(
      context,
      title: context.l10n.playlistNew,
      action: context.l10n.commonCreate,
    );
    if (name == null || !context.mounted) return;
    final playlist = await ZikrPlaylistStore.instance.create(name);
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaylistDetailPage(playlistId: playlist.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context);
    final store = ZikrPlaylistStore.instance;
    final audio = PlaylistAudioService.instance;
    final downloads = AudioDownloadStore.instance;

    final newPlaylist = PageButton(
      filled: true,
      glyph: OutlineGlyph.plus,
      label: l10n.playlistNew,
      onPressed: () => _create(context),
    );

    return ListenableBuilder(
      listenable: Listenable.merge([store, audio, downloads]),
      builder: (context, _) {
        final playlists = store.playlists;
        return LargeTitlePage(
          title: l10n.playlistsTitle,
          subtitle: l10n.playlistsSubtitle,
          bottomBar: const NowPlayingBar(),
          slivers: [
            SliverPadding(
              padding: gutter.copyWith(bottom: 14),
              sliver: SliverToBoxAdapter(
                child: AudioDownloadStore.isSupported
                    ? Row(
                        children: [
                          Expanded(child: newPlaylist),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PageButton(
                              glyph: OutlineGlyph.download,
                              label: l10n.playlistDownloads,
                              onPressed: () => _openDownloads(context),
                            ),
                          ),
                        ],
                      )
                    : newPlaylist,
              ),
            ),
            SliverPadding(
              padding: gutter.copyWith(bottom: 14),
              sliver: playlists.isEmpty
                  ? SliverToBoxAdapter(
                      child: EmptyStateCard(
                        glyph: OutlineGlyph.playlist,
                        title: l10n.playlistsNoneTitle,
                        body: l10n.playlistsEmpty,
                      ),
                    )
                  : SliverCardList(
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        final isCurrent = audio.playlist?.id == playlist.id;
                        final playing = isCurrent && audio.isPlaying;
                        final nowPlaying = isCurrent ? audio.current : null;
                        return CardListRow(
                          first: index == 0,
                          last: index == playlists.length - 1,
                          minHeight: 72,
                          leading: _PlayButton(
                            playing: playing,
                            label: playing
                                ? l10n.playlistPauseNamed(playlist.name)
                                : l10n.playlistPlayNamed(playlist.name),
                            onPressed: playlist.zikrUids.isEmpty
                                ? null
                                : () => isCurrent
                                    ? audio.togglePlay()
                                    : _startPlaylist(context, playlist),
                          ),
                          title: Text(playlist.name),
                          titleStyle: ShiaText.cardTitle,
                          subtitle: nowPlaying != null
                              ? Text(
                                  l10n.playlistPlayingNow(nowPlaying.title,
                                      audio.zikrPosition ?? 1, audio.zikrCount),
                                  style: TextStyle(color: colors.accent),
                                )
                              : Text(_playlistSummary(
                                  playlist,
                                  _audioReady
                                      ? _tracksOf(playlist)
                                      : const <ZikrAudioTrack>[],
                                )),
                          trailing: const _Chevron(),
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                PlaylistDetailPage(playlistId: playlist.id),
                          )),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// What a playlist holds - its zikr by name when there are one or two, or
/// how many - and, once any of it is saved, how much is offline.
String _playlistSummary(ZikrPlaylist playlist, List<ZikrAudioTrack> tracks) {
  final l10n = L10n.current;
  final uids = playlist.zikrUids;
  final summary = uids.isNotEmpty && uids.length <= 2
      ? uids.map(_zikrTitle).join(l10n.listSeparator)
      : _countLabel(uids.length);
  if (!AudioDownloadStore.isSupported || tracks.isEmpty) return summary;

  final downloads = AudioDownloadStore.instance;
  return switch (audioDownloadStateOf(downloads, tracks)) {
    AudioDownloadState.done => l10n.playlistSummaryDownloaded(summary),
    AudioDownloadState.downloading => l10n.playlistSummaryDownloading(
        summary, (downloads.overallProgress(tracks) * 100).floor()),
    AudioDownloadState.partial => l10n.playlistSummaryNotDownloaded(
        summary,
        uids
            .where((uid) => !downloads.allDownloaded(playlist.tracksFor(
                uid, ZikrAudioIndex.instance.tracksFor(uid))))
            .length,
      ),
    _ => summary,
  };
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
      child: OutlineIcon(OutlineGlyph.chevronRight,
          size: 16, color: ShiaColors.of(context).chevron, strokeWidth: 2.4),
    );
  }
}

/// One playlist (mockup `R3-Playlist`): what is in it and how much is
/// downloaded, Play all / Pause and Add zikr, then its zikr as numbered
/// rows - the playing one with a speaker and how far through it is - each
/// with a ⋯ menu, and a button to download what is not yet saved.
class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  // Download all needs every zikr's recordings, which live in the audio
  // index - loaded here rather than waiting for the first Play.
  bool _audioReady = ZikrAudioIndex.instance.isLoaded;

  String get playlistId => widget.playlistId;

  @override
  void initState() {
    super.initState();
    AudioDownloadStore.instance.load();
    if (_audioReady) return;
    ZikrAudioIndex.instance.load().then((_) {
      if (mounted) setState(() => _audioReady = true);
    });
  }

  Future<void> _rename(BuildContext context, ZikrPlaylist playlist) async {
    final name = await _promptForName(
      context,
      title: context.l10n.playlistRename,
      initial: playlist.name,
      action: context.l10n.commonSave,
    );
    if (name == null) return;
    await ZikrPlaylistStore.instance.rename(playlist.id, name);
  }

  Future<void> _delete(BuildContext context, ZikrPlaylist playlist) async {
    // Downloads are shared with the zikr pages and other playlists, so
    // deleting a playlist leaves them - and says where to clear them.
    final hasDownloads = _audioReady &&
        AudioDownloadStore.instance.anyDownloaded(_tracksOf(playlist));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.playlistDeleteConfirm(playlist.name)),
        content: Text(hasDownloads
            ? context.l10n.playlistDeleteKeepsDuasAndAudio
            : context.l10n.playlistDeleteKeepsDuas),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final audio = PlaylistAudioService.instance;
    if (audio.playlist?.id == playlist.id) await audio.stop();
    await ZikrPlaylistStore.instance.delete(playlist.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  void _openZikr(BuildContext context, String uid) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ZikrPage(
        UidTitleData(uid, _zikrTitle(uid)),
        source: ZikrOpenSource.playlist,
      ),
    ));
  }

  void _addZikr(BuildContext context, ZikrPlaylist playlist) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddRecitationsPage(playlistId: playlist.id),
    ));
  }

  Future<void> _showOptions(
    BuildContext anchor,
    ZikrPlaylist playlist,
    List<ZikrAudioTrack> allTracks,
  ) async {
    final l10n = anchor.l10n;
    final value = await showMenuAt<String>(anchor, [
      PopupMenuItem(value: 'rename', child: Text(l10n.commonRename)),
      if (AudioDownloadStore.instance.anyDownloaded(allTracks))
        PopupMenuItem(
            value: 'remove-downloads',
            child: Text(l10n.playlistRemoveDownloads)),
      if (AudioDownloadStore.isSupported)
        PopupMenuItem(
            value: 'downloads', child: Text(l10n.playlistAllDownloads)),
      PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete)),
    ]);
    if (!mounted || value == null) return;
    switch (value) {
      case 'rename':
        await _rename(context, playlist);
      case 'delete':
        await _delete(context, playlist);
      case 'remove-downloads':
        await confirmRemoveAudioDownload(context, allTracks,
            label: playlist.name);
      case 'downloads':
        _openDownloads(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context);
    final store = ZikrPlaylistStore.instance;
    final audio = PlaylistAudioService.instance;
    final downloads = AudioDownloadStore.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([store, audio, downloads]),
      builder: (context, _) {
        final playlist = store.byId(playlistId);
        if (playlist == null) {
          return LargeTitlePage(
            title: l10n.playlistsTitle,
            slivers: [
              SliverPadding(
                padding: gutter,
                sliver: SliverToBoxAdapter(
                  child: EmptyStateCard(
                    glyph: OutlineGlyph.playlist,
                    title: l10n.playlistDeleted,
                  ),
                ),
              ),
            ],
          );
        }
        final isCurrent = audio.playlist?.id == playlist.id;
        final playingUid = isCurrent ? audio.current?.zikrUid : null;
        final allTracks =
            _audioReady ? _tracksOf(playlist) : const <ZikrAudioTrack>[];
        final showDownload =
            AudioDownloadStore.isSupported && allTracks.isNotEmpty;
        final downloadedCount = !showDownload
            ? 0
            : playlist.zikrUids
                .where((uid) => downloads.allDownloaded(playlist.tracksFor(
                    uid, ZikrAudioIndex.instance.tracksFor(uid))))
                .length;
        final count = _countLabel(playlist.zikrUids.length);

        return LargeTitlePage(
          title: playlist.name,
          subtitle: downloadedCount > 0
              ? '$count · ${l10n.playlistDownloadedCount(downloadedCount)}'
              : count,
          actions: [
            Builder(
              builder: (anchor) => RoundIconButton(
                label: l10n.playlistOptions,
                icon: OutlineIcon(OutlineGlyph.more,
                    size: 22, color: colors.accent, strokeWidth: 2.6),
                onPressed: () => _showOptions(anchor, playlist, allTracks),
              ),
            ),
          ],
          bottomBar: const NowPlayingBar(),
          slivers: [
            SliverPadding(
              padding: gutter.copyWith(bottom: 14),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    if (playlist.zikrUids.isNotEmpty) ...[
                      Expanded(
                        child: PageButton(
                          filled: true,
                          glyph: isCurrent && audio.isPlaying
                              ? OutlineGlyph.pause
                              : OutlineGlyph.play,
                          label: isCurrent && audio.isPlaying
                              ? l10n.commonPause
                              : isCurrent
                                  ? l10n.playlistResume
                                  : l10n.playlistPlayAll,
                          busy: audio.isStarting,
                          onPressed: () => isCurrent
                              ? audio.togglePlay()
                              : _startPlaylist(context, playlist),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: PageButton(
                        glyph: OutlineGlyph.plus,
                        label: l10n.playlistAddZikr,
                        onPressed: () => _addZikr(context, playlist),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: gutter.copyWith(bottom: 14),
              sliver: playlist.zikrUids.isEmpty
                  ? SliverToBoxAdapter(
                      child: EmptyStateCard(
                        glyph: OutlineGlyph.playlistAdd,
                        title: l10n.playlistEmptyTitle,
                        body: l10n.playlistEmpty,
                      ),
                    )
                  : SliverCardList(
                      itemCount: playlist.zikrUids.length,
                      itemBuilder: (context, index) => _buildRow(
                        context,
                        playlist,
                        index,
                        playing: playlist.zikrUids[index] == playingUid,
                        showDownload: showDownload,
                      ),
                    ),
            ),
            if (showDownload)
              SliverPadding(
                padding: gutter,
                sliver: SliverToBoxAdapter(
                  child: AudioDownloadButton(
                    tracks: allTracks,
                    label: playlist.name,
                    labelled: true,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRow(
    BuildContext context,
    ZikrPlaylist playlist,
    int index, {
    required bool playing,
    required bool showDownload,
  }) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final store = ZikrPlaylistStore.instance;
    final downloads = AudioDownloadStore.instance;
    final uid = playlist.zikrUids[index];
    final available = _audioReady
        ? ZikrAudioIndex.instance.tracksFor(uid)
        : const <ZikrAudioTrack>[];
    final tracks = playlist.tracksFor(uid, available);
    // Which recordings play, for a zikr with a choice. A zikr playing one
    // of its several recordings goes by that recording's label alone - the
    // labels name the zikr too ("Ziyarat Aal e Yasin with Dua"). Playing
    // more than one, it keeps its title and says how many.
    final single =
        available.length > 1 && tracks.length == 1 ? tracks.single.label : null;
    final recordings = available.length < 2 || single != null
        ? null
        : l10n.audioRecordingsChosen(tracks.length, available.length);
    final downloadState = audioDownloadStateOf(downloads, tracks);
    final status = !showDownload || tracks.isEmpty
        ? null
        : switch (downloadState) {
            AudioDownloadState.done => recordings == null
                ? l10n.audioDownloaded
                : l10n.playlistRecordingDownloaded(recordings),
            AudioDownloadState.downloading => l10n.audioDownloadingPercent(
                (downloads.overallProgress(tracks) * 100).floor()),
            AudioDownloadState.failed => l10n.audioDownloadFailed,
            AudioDownloadState.partial => l10n.audioPartlyDownloaded,
            AudioDownloadState.idle => l10n.playlistNotDownloaded,
          };
    final subtitle = [
      if (recordings != null && downloadState != AudioDownloadState.done)
        recordings,
      if (status != null) status,
    ].join(' · ');
    final title = single ?? _zikrTitle(uid);

    return CardListRow(
      first: index == 0,
      last: index == playlist.zikrUids.length - 1,
      minHeight: 60,
      leading: playing
          ? Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: colors.accent, shape: BoxShape.circle),
              child: OutlineIcon(OutlineGlyph.speaker,
                  size: 18, color: colors.onAccent),
            )
          : NumberWell(index + 1, size: 32),
      title: Text(title),
      titleStyle: ShiaText.body
          .copyWith(fontWeight: playing ? FontWeight.w600 : FontWeight.w400),
      subtitle: playing
          ? _PlayingPosition(color: colors.accent)
          : subtitle.isEmpty
              ? null
              : Text(
                  subtitle,
                  style: downloadState == AudioDownloadState.failed
                      ? TextStyle(color: colors.danger)
                      : null,
                ),
      trailing: Builder(
        builder: (anchor) => MoreButton(
          label: l10n.playlistMoreFor(title),
          onPressed: () async {
            final value = await showMenuAt<String>(anchor, [
              PopupMenuItem(value: 'open', child: Text(l10n.playlistOpenText)),
              if (available.length > 1)
                PopupMenuItem(
                    value: 'recordings',
                    child: Text(l10n.playlistChooseRecordings)),
              if (showDownload && tracks.isNotEmpty)
                switch (downloadState) {
                  AudioDownloadState.downloading => PopupMenuItem(
                      value: 'stop-download',
                      child: Text(l10n.audioStopDownloading)),
                  AudioDownloadState.done => PopupMenuItem(
                      value: 'remove-download',
                      child: Text(l10n.audioRemoveDownload)),
                  _ => PopupMenuItem(
                      value: 'download', child: Text(l10n.audioDownload)),
                },
              if (index > 0)
                PopupMenuItem(value: 'up', child: Text(l10n.playlistMoveUp)),
              if (index < playlist.zikrUids.length - 1)
                PopupMenuItem(
                    value: 'down', child: Text(l10n.playlistMoveDown)),
              PopupMenuItem(
                  value: 'remove', child: Text(l10n.playlistRemoveZikr)),
            ]);
            if (!context.mounted) return;
            switch (value) {
              case 'open':
                _openZikr(context, uid);
              case 'recordings':
                await _chooseRecordings(context, playlist, uid, available);
              case 'remove':
                await store.removeAt(playlist.id, index);
              case 'up':
                await store.move(playlist.id, index, index - 1);
              case 'down':
                await store.move(playlist.id, index, index + 1);
              case 'download':
                await startAudioDownload(context, tracks, label: title);
              case 'stop-download':
                downloads.cancel(tracks);
              case 'remove-download':
                await confirmRemoveAudioDownload(context, tracks, label: title);
            }
          },
        ),
      ),
      onTap: () => _startPlaylist(context, playlist, startZikrIndex: index),
    );
  }
}

/// "Playing · 3:12 of 9:40", kept up to date as the recording plays.
class _PlayingPosition extends StatelessWidget {
  const _PlayingPosition({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final player = PlaylistAudioService.instance.player;
    final style = TextStyle(color: color, fontWeight: FontWeight.w600);
    if (player == null) {
      return Text(context.l10n.playlistPlaying, style: style);
    }
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final duration = player.duration;
        if (duration == null || duration <= Duration.zero) {
          return Text(context.l10n.playlistPlaying, style: style);
        }
        return Text(
          context.l10n.playlistPlayingAt(
            NowPlayingBar.format(snapshot.data ?? Duration.zero),
            NowPlayingBar.format(duration),
          ),
          style: style,
        );
      },
    );
  }
}

/// The list prefixes Aamaal ("C") leads to through its menu entries
/// (`C~AA5` opens the Ramazan list, `AA`), and theirs in turn - the months
/// and occasions. Aliases filed there (Ziyarat Ashura under Muharram) don't
/// count: their own list is where they live.
Set<String> _aamaalPrefixes() {
  String prefix(String uid) => uid.replaceAll(RegExp('[0-9].*'), '');
  final children = <String, Set<String>>{};
  for (final key in items.keys) {
    final at = key.indexOf('~');
    if (at < 0) continue;
    children
        .putIfAbsent(key.substring(0, at), () => {})
        .add(prefix(key.substring(at + 1)));
  }
  final found = <String>{};
  final pending = ['C'];
  while (pending.isNotEmpty) {
    for (final child in children[pending.removeLast()] ?? const <String>{}) {
      if (found.add(child)) pending.add(child);
    }
  }
  return found;
}

/// Every zikr that has a recording, to tick into a playlist, narrowed by
/// the find field at the bottom.
class AddRecitationsPage extends StatefulWidget {
  const AddRecitationsPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  State<AddRecitationsPage> createState() => _AddRecitationsPageState();
}

class _AddRecitationsPageState extends State<AddRecitationsPage> {
  final TextEditingController _find = TextEditingController();
  bool _audioReady = ZikrAudioIndex.instance.isLoaded;

  @override
  void initState() {
    super.initState();
    _find.addListener(() => setState(() {}));
    if (_audioReady) return;
    ZikrAudioIndex.instance.load().then((_) {
      if (mounted) setState(() => _audioReady = true);
    });
  }

  @override
  void dispose() {
    _find.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gutter = pageGutter(context);
    // Ticks save as they are made; Done is the obvious way back to the
    // playlist, so it doesn't feel like the ticks need confirming.
    final done = PageTextAction(
      label: l10n.commonDone,
      onPressed: () => Navigator.of(context).maybePop(),
    );

    if (!_audioReady) {
      return LargeTitlePage(
        title: l10n.playlistAddZikr,
        actions: [done],
        slivers: const [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      );
    }
    final store = ZikrPlaylistStore.instance;
    final query = _find.text.trim().toLowerCase();
    final favorites = {
      // FavoritesManager reaches for Firebase as it is built; skip it
      // where Firebase isn't set up (tests).
      if (Firebase.apps.isNotEmpty)
        for (final favorite in FavoritesManager.instance.favorites)
          if (favorite.type == 0) favorite.canonicalUid,
    };
    final aamaal = _aamaalPrefixes();
    // Playlists are for what's recited regularly: the reader's favorites
    // first, then the rest, with Aamaal's month and occasion ones last.
    int rank(String uid) => favorites.contains(_contentUid(uid))
        ? 0
        : aamaal.contains(uid.replaceAll(RegExp('[0-9].*'), ''))
            ? 2
            : 1;
    final uids = ZikrAudioIndex.instance.uids.toList()
      ..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        if (byRank != 0) return byRank;
        return _zikrTitle(a)
            .toLowerCase()
            .compareTo(_zikrTitle(b).toLowerCase());
      });
    final visible = query.isEmpty
        ? uids
        : uids.where((uid) {
            if (_zikrTitle(uid).toLowerCase().contains(query)) return true;
            // Recording labels name what they are ("Dua after Ziyarat
            // Warith"), so they are worth finding by too.
            return ZikrAudioIndex.instance.tracksFor(uid).any(
                (track) => track.label?.toLowerCase().contains(query) ?? false);
          }).toList();

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final playlist = store.byId(widget.playlistId);
        return LargeTitlePage(
          title: l10n.playlistAddZikr,
          subtitle: playlist?.name,
          actions: [done],
          bottom: FindField(controller: _find, hint: l10n.listFindDua),
          slivers: [
            if (playlist != null)
              SliverPadding(
                padding: gutter,
                sliver: visible.isEmpty
                    ? SliverToBoxAdapter(
                        child: EmptyStateCard(
                          glyph: OutlineGlyph.search,
                          title: l10n.listFindNone(_find.text.trim()),
                        ),
                      )
                    : SliverCardList(
                        itemCount: visible.length,
                        itemBuilder: (context, index) => _buildPickRow(
                          playlist,
                          visible[index],
                          first: index == 0,
                          last: index == visible.length - 1,
                        ),
                      ),
              ),
          ],
        );
      },
    );
  }
}

/// A zikr to tick into [playlist]. One with several recordings gets a row
/// of its own that adds or removes all of them, and one per recording
/// underneath to pick them individually - the same choice as the playlist
/// page's Choose recordings.
Widget _buildPickRow(
  ZikrPlaylist playlist,
  String uid, {
  required bool first,
  required bool last,
}) {
  final store = ZikrPlaylistStore.instance;
  final at = playlist.zikrUids.indexOf(uid);
  final available = ZikrAudioIndex.instance.tracksFor(uid);

  if (available.length < 2) {
    return CardListRow(
      first: first,
      last: last,
      leading: _Tick(at >= 0),
      title: Text(_zikrTitle(uid)),
      onTap: () => at >= 0
          ? store.removeAt(playlist.id, at)
          : store.addZikr(playlist.id, uid),
    );
  }

  final chosen = at < 0
      ? const <String>{}
      : {for (final track in playlist.tracksFor(uid, available)) track.file};
  final allFiles = [for (final track in available) track.file];

  Future<void> setChosen(Set<String> files) async {
    if (files.isEmpty) {
      await store.removeAt(playlist.id, at);
      return;
    }
    final ordered = [
      for (final file in allFiles)
        if (files.contains(file)) file,
    ];
    if (at < 0) await store.addZikr(playlist.id, uid);
    await store.setTrackFiles(playlist.id, uid, ordered);
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CardListRow(
        first: first,
        leading: _Tick(chosen.isEmpty
            ? false
            : chosen.length == available.length
                ? true
                : null),
        title: Text(_zikrTitle(uid)),
        subtitle: Text(L10n.current.audioRecordingsCount(available.length)),
        // Ticking a partly-chosen zikr fills in the rest; ticking a full
        // one takes it out.
        onTap: () => setChosen(
            chosen.length == available.length ? {} : allFiles.toSet()),
      ),
      for (var i = 0; i < available.length; i++)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 32),
          child: CardListRow(
            last: last && i == available.length - 1,
            minHeight: 48,
            leading: _Tick(chosen.contains(available[i].file)),
            title: Text(_trackLabel(available[i], i)),
            titleStyle: ShiaText.secondary,
            onTap: () => setChosen(chosen.contains(available[i].file)
                ? ({...chosen}..remove(available[i].file))
                : {...chosen, available[i].file}),
          ),
        ),
    ],
  );
}

/// A rounded tick box: filled with a tick when [value] is true, with a dash
/// when it is part-chosen (null), empty otherwise.
class _Tick extends StatelessWidget {
  const _Tick(this.value);

  final bool? value;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final on = value != false;
    return Semantics(
      checked: value == true,
      mixed: value == null,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? colors.accent : null,
          borderRadius: BorderRadius.circular(7),
          border: on ? null : Border.all(color: colors.chevron, width: 1.5),
        ),
        child: !on
            ? null
            : OutlineIcon(
                value == true ? OutlineGlyph.check : OutlineGlyph.minus,
                size: 16,
                color: colors.onAccent,
                strokeWidth: 2.6,
              ),
      ),
    );
  }
}

/// What the playlist is playing, with the controls to steer it, docked
/// under the page. Shows nothing while no playlist is playing.
class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({super.key});

  /// "3:12", "1:02:45".
  static String format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
        : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final audio = PlaylistAudioService.instance;
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final player = audio.player;
        final current = audio.current;
        if (player == null || current == null) return const SizedBox.shrink();
        final colors = ShiaColors.of(context);
        final caption = ShiaText.caption.copyWith(color: colors.textMuted);

        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.line)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              current.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ShiaText.cardTitle
                                  .copyWith(color: colors.text),
                            ),
                            Text(
                              context.l10n.playlistNowPlayingPosition(
                                  audio.playlist?.name ?? '',
                                  audio.zikrPosition ?? 1,
                                  audio.zikrCount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: caption,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: OutlineIcon(OutlineGlyph.repeat,
                            size: 22,
                            color: audio.isRepeating
                                ? colors.accent
                                : colors.chevron),
                        tooltip: audio.isRepeating
                            ? context.l10n.playlistRepeatOn
                            : context.l10n.playlistRepeat,
                        onPressed: audio.toggleRepeat,
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_previous_rounded,
                            color: colors.accent),
                        tooltip: context.l10n.commonPrevious,
                        onPressed: audio.previous,
                      ),
                      StreamBuilder<PlayerState>(
                        stream: player.playerStateStream,
                        builder: (context, snapshot) {
                          final state = snapshot.data;
                          final loading = state?.processingState ==
                                  ProcessingState.loading ||
                              state?.processingState ==
                                  ProcessingState.buffering;
                          if (loading) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            );
                          }
                          final playing = state?.playing ?? false;
                          return _PlayButton(
                            playing: playing,
                            label: playing
                                ? context.l10n.commonPause
                                : context.l10n.commonPlay,
                            onPressed: audio.togglePlay,
                          );
                        },
                      ),
                      IconButton(
                        icon:
                            Icon(Icons.skip_next_rounded, color: colors.accent),
                        tooltip: context.l10n.commonNext,
                        onPressed: player.hasNext ? audio.next : null,
                      ),
                      IconButton(
                        icon: OutlineIcon(OutlineGlyph.close,
                            size: 20, color: colors.textMuted, strokeWidth: 2),
                        tooltip: context.l10n.commonStop,
                        onPressed: audio.stop,
                      ),
                    ],
                  ),
                  StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (context, snapshot) {
                      final duration = player.duration ?? Duration.zero;
                      final position = snapshot.data ?? Duration.zero;
                      final total = duration.inMilliseconds.toDouble();
                      return Row(
                        children: [
                          Text(format(position), style: caption),
                          Expanded(
                            child: Slider(
                              max: total <= 0 ? 1 : total,
                              value: total <= 0
                                  ? 0
                                  : position.inMilliseconds
                                      .clamp(0, duration.inMilliseconds)
                                      .toDouble(),
                              onChanged: total <= 0
                                  ? null
                                  : (value) => audio.seek(
                                      Duration(milliseconds: value.round())),
                            ),
                          ),
                          Text(format(duration), style: caption),
                          const SizedBox(width: 8),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
