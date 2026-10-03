import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../constants.dart';
import '../data/uid_title_data.dart';
import '../models/zikr_audio_track.dart';
import '../models/zikr_playlist.dart';
import '../services/analytics_service.dart';
import '../services/audio_download_store.dart';
import '../services/favorites_manager.dart';
import '../services/playlist_audio_service.dart';
import '../services/zikr_audio_index.dart';
import '../services/zikr_playlist_store.dart';
import '../widgets/audio_download_button.dart';
import '../widgets/responsive_content.dart';
import 'downloaded_audio_page.dart';
import 'zikr/zikr_page.dart';

/// The zikr's title as the index knows it, falling back to its uid while the
/// index is still loading.
String _zikrTitle(String uid) {
  final title = items[uid]?.toString().trim() ?? '';
  return title.isEmpty ? uid : title;
}

/// The content uid behind a possibly-aliased key: `G17|L4` plays `L4`.
String _contentUid(String uid) => UidTitleData(uid, '').getFirstUId();

Future<String?> _promptForName(
  BuildContext context, {
  required String title,
  String initial = '',
  required String action,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      void submit() {
        final name = controller.text.trim();
        if (name.isNotEmpty) Navigator.of(dialogContext).pop(name);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Morning'),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: submit, child: Text(action)),
        ],
      );
    },
  ).whenComplete(controller.dispose);
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
      "You're offline - playing only the downloaded recordings",
    PlaylistStartResult.nothingToPlay =>
      'Nothing in this playlist has a recording to play',
    PlaylistStartResult.offlineNothingDownloaded =>
      "You're offline and nothing in this playlist is downloaded yet",
    PlaylistStartResult.failed => "Couldn't start the playlist. Try again.",
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
    track.label ?? 'Recording ${index + 1}';

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
  final picked = await showModalBottomSheet<List<String>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(_zikrTitle(uid),
                    style: Theme.of(sheetContext).textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Choose the recordings to play in this playlist',
                    style: Theme.of(sheetContext).textTheme.bodySmall),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var i = 0; i < available.length; i++)
                      CheckboxListTile(
                        value: chosen.contains(available[i].file),
                        title: Text(_trackLabel(available[i], i)),
                        subtitle: available[i].reciter == null
                            ? null
                            : Text(available[i].reciter!),
                        // Unticking the last one would leave nothing to play.
                        onChanged: chosen.length == 1 &&
                                chosen.contains(available[i].file)
                            ? null
                            : (on) => setSheetState(() => on == true
                                ? chosen.add(available[i].file)
                                : chosen.remove(available[i].file)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop([
                    for (final track in available)
                      if (chosen.contains(track.file)) track.file,
                  ]),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
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

  final choice = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Add to playlist',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New playlist'),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            for (final playlist in store.playlists)
              ListTile(
                leading: const Icon(Icons.playlist_play_rounded),
                title: Text(playlist.name),
                subtitle: Text(_countLabel(playlist.zikrUids.length)),
                trailing: _hasRecording(playlist, uid, track)
                    ? Icon(Icons.check,
                        color: Theme.of(sheetContext).colorScheme.primary)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(playlist),
              ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;

  if (choice == true) {
    final name = await _promptForName(
      context,
      title: 'New playlist',
      action: 'Create',
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
    messenger.showSnackBar(SnackBar(content: Text('Added to $name')));
  } else if (choice is ZikrPlaylist) {
    if (_hasRecording(choice, uid, track)) {
      messenger
          .showSnackBar(SnackBar(content: Text('Already in ${choice.name}')));
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
    messenger.showSnackBar(SnackBar(content: Text('Added to ${choice.name}')));
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
String _countLabel(int count) => '$count zikr';

/// The reader's audio playlists: a morning set of Dua Ahad and Ziyarat
/// Ashura, say, started with one tap and left playing in the background.
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
      title: 'New playlist',
      action: 'Create',
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
    final store = ZikrPlaylistStore.instance;
    final audio = PlaylistAudioService.instance;
    final downloads = AudioDownloadStore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          if (AudioDownloadStore.isSupported)
            IconButton(
              icon: const Icon(Icons.download_for_offline_outlined),
              tooltip: 'Downloads',
              onPressed: () => _openDownloads(context),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('New playlist'),
      ),
      bottomNavigationBar: const NowPlayingBar(),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, audio, downloads]),
        builder: (context, _) {
          final playlists = store.playlists;
          if (playlists.isEmpty) {
            return const _EmptyState(
              icon: Icons.playlist_play_rounded,
              message: 'Make a playlist of the zikr you listen to '
                  'every day - Dua Ahad and Ziyarat Ashura each morning, say '
                  '- and start them all with one tap.',
            );
          }
          return ResponsiveContent(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                final isCurrent = audio.playlist?.id == playlist.id;
                return ListTile(
                  leading: IconButton.filledTonal(
                    icon: Icon(isCurrent && audio.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                    tooltip: isCurrent && audio.isPlaying ? 'Pause' : 'Play',
                    onPressed: playlist.zikrUids.isEmpty
                        ? null
                        : () => isCurrent
                            ? audio.togglePlay()
                            : _startPlaylist(context, playlist),
                  ),
                  title: Text(playlist.name),
                  subtitle: _PlaylistSubtitle(
                    playlist: playlist,
                    tracks: _audioReady
                        ? _tracksOf(playlist)
                        : const <ZikrAudioTrack>[],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PlaylistDetailPage(playlistId: playlist.id),
                  )),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

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
      title: 'Rename playlist',
      initial: playlist.name,
      action: 'Save',
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
        title: Text('Delete "${playlist.name}"?'),
        content: Text(hasDownloads
            ? 'The duas themselves stay in the app, and so does their '
                'downloaded audio - remove it from Downloads to free space.'
            : 'The duas themselves stay in the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
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

  @override
  Widget build(BuildContext context) {
    final store = ZikrPlaylistStore.instance;
    final audio = PlaylistAudioService.instance;
    final downloads = AudioDownloadStore.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([store, audio, downloads]),
      builder: (context, _) {
        final playlist = store.byId(playlistId);
        if (playlist == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const _EmptyState(
              icon: Icons.playlist_play_rounded,
              message: 'This playlist has been deleted.',
            ),
          );
        }
        final isCurrent = audio.playlist?.id == playlist.id;
        final playingUid = isCurrent ? audio.current?.zikrUid : null;
        final allTracks =
            _audioReady ? _tracksOf(playlist) : const <ZikrAudioTrack>[];
        final showDownload =
            AudioDownloadStore.isSupported && allTracks.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(playlist.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') _rename(context, playlist);
                  if (value == 'delete') _delete(context, playlist);
                  if (value == 'remove-downloads') {
                    confirmRemoveAudioDownload(context, allTracks,
                        label: playlist.name);
                  }
                  if (value == 'downloads') _openDownloads(context);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  if (downloads.anyDownloaded(allTracks))
                    const PopupMenuItem(
                        value: 'remove-downloads',
                        child: Text('Remove downloads')),
                  if (AudioDownloadStore.isSupported)
                    const PopupMenuItem(
                        value: 'downloads', child: Text('All downloads')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AddRecitationsPage(playlistId: playlist.id),
            )),
            icon: const Icon(Icons.playlist_add),
            label: const Text('Add'),
          ),
          bottomNavigationBar: const NowPlayingBar(),
          body: playlist.zikrUids.isEmpty
              ? const _EmptyState(
                  icon: Icons.playlist_add,
                  message: 'Tap Add to choose zikr. You can also add one from '
                      'the player on any dua with audio.',
                )
              : ResponsiveContent(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton.icon(
                              onPressed: audio.isStarting
                                  ? null
                                  : () => isCurrent
                                      ? audio.togglePlay()
                                      : _startPlaylist(context, playlist),
                              icon: Icon(isCurrent && audio.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded),
                              label: Text(isCurrent && audio.isPlaying
                                  ? 'Pause'
                                  : isCurrent
                                      ? 'Resume'
                                      : 'Play all'),
                            ),
                            if (showDownload) ...[
                              const SizedBox(height: 8),
                              AudioDownloadButton(
                                tracks: allTracks,
                                label: playlist.name,
                                labelled: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: ReorderableListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: playlist.zikrUids.length,
                          onReorderItem: (from, to) =>
                              store.move(playlist.id, from, to),
                          itemBuilder: (context, index) {
                            final uid = playlist.zikrUids[index];
                            final isPlaying = uid == playingUid;
                            final available = _audioReady
                                ? ZikrAudioIndex.instance.tracksFor(uid)
                                : const <ZikrAudioTrack>[];
                            final tracks = playlist.tracksFor(uid, available);
                            // Which recordings play, for a zikr with a choice.
                            // A zikr playing one of its several recordings
                            // goes by that recording's label alone - the
                            // labels name the zikr too ("Ziyarat Aal e Yasin
                            // with Dua"). Playing more than one, it keeps its
                            // title and says how many.
                            final single =
                                available.length > 1 && tracks.length == 1
                                    ? tracks.single.label
                                    : null;
                            final recordings =
                                available.length < 2 || single != null
                                    ? null
                                    : '${tracks.length} of '
                                        '${available.length} recordings';
                            final downloadState =
                                audioDownloadStateOf(downloads, tracks);
                            final subtitle = !showDownload || tracks.isEmpty
                                ? null
                                : switch (downloadState) {
                                    AudioDownloadState.done => 'Downloaded',
                                    AudioDownloadState.downloading =>
                                      'Downloading '
                                          '${(downloads.overallProgress(tracks) * 100).floor()}%',
                                    AudioDownloadState.failed =>
                                      "Download didn't finish",
                                    _ => null,
                                  };
                            return ListTile(
                              key: ValueKey('$uid@$index'),
                              selected: isPlaying,
                              leading: Icon(isPlaying
                                  ? Icons.graphic_eq
                                  : Icons.headphones_outlined),
                              title: Text(single ?? _zikrTitle(uid)),
                              subtitle: subtitle == null && recordings == null
                                  ? null
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (recordings != null)
                                          Text(recordings,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                        if (subtitle != null)
                                          Row(
                                            children: [
                                              Icon(
                                                switch (downloadState) {
                                                  AudioDownloadState.done =>
                                                    Icons.offline_pin_rounded,
                                                  AudioDownloadState.failed =>
                                                    Icons.sync_problem_rounded,
                                                  _ =>
                                                    Icons.downloading_rounded,
                                                },
                                                size: 14,
                                                color: downloadState ==
                                                        AudioDownloadState
                                                            .failed
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .error
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(child: Text(subtitle)),
                                            ],
                                          ),
                                      ],
                                    ),
                              onTap: () => _startPlaylist(context, playlist,
                                  startZikrIndex: index),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  final title = _zikrTitle(uid);
                                  switch (value) {
                                    case 'open':
                                      _openZikr(context, uid);
                                    case 'recordings':
                                      _chooseRecordings(
                                          context, playlist, uid, available);
                                    case 'remove':
                                      store.removeAt(playlist.id, index);
                                    case 'download':
                                      startAudioDownload(context, tracks,
                                          label: title);
                                    case 'stop-download':
                                      downloads.cancel(tracks);
                                    case 'remove-download':
                                      confirmRemoveAudioDownload(
                                          context, tracks,
                                          label: title);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: 'open', child: Text('Open text')),
                                  if (available.length > 1)
                                    const PopupMenuItem(
                                        value: 'recordings',
                                        child: Text('Choose recordings')),
                                  if (showDownload && tracks.isNotEmpty)
                                    switch (downloadState) {
                                      AudioDownloadState.downloading =>
                                        const PopupMenuItem(
                                            value: 'stop-download',
                                            child: Text('Stop downloading')),
                                      AudioDownloadState.done =>
                                        const PopupMenuItem(
                                            value: 'remove-download',
                                            child: Text('Remove download')),
                                      _ => const PopupMenuItem(
                                          value: 'download',
                                          child: Text('Download')),
                                    },
                                  const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Remove from playlist')),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

/// Recordings tied to a date or season (Muharram, Arafah, Dhul Hijjah,
/// Ramazan, Shaban, Safar), listed after the everyday ones when adding to a
/// playlist. Keep in step with assets/zikr_audio.json.
const _occasionUids = {
  'R1', 'AC10', 'AC11', 'AC12', 'AC5', 'G75', 'G14', // Muharram, Arafah, Qadr
  'AA11', 'AA12', 'AA13', 'AA14', 'AA10', // Ramazan
  'Y3', 'Y4', 'S1', // Shaban, Safar
};

/// Every zikr that has a recording, to tick into a playlist.
class AddRecitationsPage extends StatefulWidget {
  const AddRecitationsPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  State<AddRecitationsPage> createState() => _AddRecitationsPageState();
}

class _AddRecitationsPageState extends State<AddRecitationsPage> {
  String _query = '';
  bool _audioReady = ZikrAudioIndex.instance.isLoaded;

  @override
  void initState() {
    super.initState();
    if (_audioReady) return;
    ZikrAudioIndex.instance.load().then((_) {
      if (mounted) setState(() => _audioReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_audioReady) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add zikr')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final store = ZikrPlaylistStore.instance;
    final query = _query.trim().toLowerCase();
    final favorites = {
      // FavoritesManager reaches for Firebase as it is built; skip it
      // where Firebase isn't set up (tests).
      if (Firebase.apps.isNotEmpty)
        for (final favorite in FavoritesManager.instance.favorites)
          if (favorite.type == 0) favorite.canonicalUid,
    };
    // Playlists are for what's recited regularly: the reader's favorites
    // first, then everyday recitations, with the once-a-year ones last.
    int rank(String uid) => favorites.contains(_contentUid(uid))
        ? 0
        : _occasionUids.contains(uid)
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

    return Scaffold(
      appBar: AppBar(title: const Text('Add zikr')),
      // Ticks save as they are made; Done is the obvious way back to the
      // playlist, so it doesn't feel like the ticks need confirming.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Done'),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final playlist = store.byId(widget.playlistId);
          if (playlist == null) return const SizedBox.shrink();
          return ResponsiveContent(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final uid = visible[index];
                      final at = playlist.zikrUids.indexOf(uid);
                      final available = ZikrAudioIndex.instance.tracksFor(uid);
                      if (available.length < 2) {
                        return CheckboxListTile(
                          value: at >= 0,
                          title: Text(_zikrTitle(uid)),
                          onChanged: (checked) => checked == true
                              ? store.addZikr(playlist.id, uid)
                              : store.removeAt(playlist.id, at),
                        );
                      }
                      return _buildRecordings(playlist, uid, at, available);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A zikr with several recordings: its own checkbox adds or removes all of
/// them, and one per recording underneath picks them individually - the
/// same choice as the playlist page's "Choose recordings".
Widget _buildRecordings(
  ZikrPlaylist playlist,
  String uid,
  int at,
  List<ZikrAudioTrack> available,
) {
  final store = ZikrPlaylistStore.instance;
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
      CheckboxListTile(
        tristate: true,
        value: chosen.isEmpty
            ? false
            : chosen.length == available.length
                ? true
                : null,
        title: Text(_zikrTitle(uid)),
        subtitle: Text('${available.length} recordings'),
        // Ticking a partly-chosen zikr fills in the rest; ticking a full
        // one takes it out.
        onChanged: (_) => setChosen(
            chosen.length == available.length ? {} : allFiles.toSet()),
      ),
      for (var i = 0; i < available.length; i++)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 32),
          child: CheckboxListTile(
            dense: true,
            value: chosen.contains(available[i].file),
            title: Text(_trackLabel(available[i], i)),
            onChanged: (checked) => setChosen(checked == true
                ? {...chosen, available[i].file}
                : ({...chosen}..remove(available[i].file))),
          ),
        ),
    ],
  );
}

/// A playlist's size and, once any of it is saved, how much is offline.
class _PlaylistSubtitle extends StatelessWidget {
  const _PlaylistSubtitle({required this.playlist, required this.tracks});

  final ZikrPlaylist playlist;
  final List<ZikrAudioTrack> tracks;

  @override
  Widget build(BuildContext context) {
    final count = Text(_countLabel(playlist.zikrUids.length));
    if (!AudioDownloadStore.isSupported || tracks.isEmpty) return count;
    final downloads = AudioDownloadStore.instance;
    final state = audioDownloadStateOf(downloads, tracks);
    final String? status = switch (state) {
      AudioDownloadState.done => 'Downloaded',
      AudioDownloadState.downloading =>
        'Downloading ${(downloads.overallProgress(tracks) * 100).floor()}%',
      AudioDownloadState.partial => 'Partly downloaded',
      _ => null,
    };
    if (status == null) return count;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Flexible(child: Text('${_countLabel(playlist.zikrUids.length)} · ')),
        Icon(
          state == AudioDownloadState.downloading
              ? Icons.downloading_rounded
              : Icons.offline_pin_rounded,
          size: 14,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 3),
        Flexible(child: Text(status, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

/// What the playlist is playing, with the controls to steer it. Shows
/// nothing while no playlist is playing.
class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({super.key});

  static String _format(Duration d) {
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
        final theme = Theme.of(context);

        return Material(
          color: theme.colorScheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
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
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              '${audio.playlist?.name ?? ''} · '
                              '${audio.zikrPosition ?? 1} of '
                              '${audio.zikrCount}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.repeat,
                            color: audio.isRepeating
                                ? theme.colorScheme.primary
                                : null),
                        tooltip: audio.isRepeating
                            ? 'Repeat is on'
                            : 'Repeat playlist',
                        onPressed: audio.toggleRepeat,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded),
                        tooltip: 'Previous',
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
                          return IconButton.filled(
                            icon: Icon(playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                            tooltip: playing ? 'Pause' : 'Play',
                            onPressed: audio.togglePlay,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded),
                        tooltip: 'Next',
                        onPressed: player.hasNext ? audio.next : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Stop',
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
                          Text(_format(position),
                              style: theme.textTheme.bodySmall),
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
                          Text(_format(duration),
                              style: theme.textTheme.bodySmall),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
