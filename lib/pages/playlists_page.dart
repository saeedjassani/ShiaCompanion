import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../constants.dart';
import '../data/uid_title_data.dart';
import '../models/zikr_playlist.dart';
import '../services/analytics_service.dart';
import '../services/playlist_audio_service.dart';
import '../services/zikr_audio_index.dart';
import '../services/zikr_playlist_store.dart';
import '../widgets/responsive_content.dart';
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
  final started = await PlaylistAudioService.instance
      .play(playlist, startZikrIndex: startZikrIndex);
  if (!started) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Nothing in this playlist has a recitation to play'),
    ));
  }
}

/// Adds a zikr to one of the reader's playlists, or to a new one - opened from
/// the recitation player on a zikr page.
Future<void> showAddToPlaylistSheet(
  BuildContext context, {
  required String zikrUid,
  required String zikrTitle,
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
                leading: const Icon(Icons.queue_music),
                title: Text(playlist.name),
                subtitle: Text(_countLabel(playlist.zikrUids.length)),
                trailing: playlist.zikrUids.contains(uid)
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
    await store.create(name, zikrUids: [uid]);
    messenger.showSnackBar(SnackBar(content: Text('Added to $name')));
  } else if (choice is ZikrPlaylist) {
    if (choice.zikrUids.contains(uid)) {
      messenger
          .showSnackBar(SnackBar(content: Text('Already in ${choice.name}')));
      return;
    }
    await store.addZikr(choice.id, uid);
    messenger.showSnackBar(SnackBar(content: Text('Added to ${choice.name}')));
  }
}

String _countLabel(int count) =>
    count == 1 ? '1 recitation' : '$count recitations';

/// The reader's audio playlists: a morning set of Dua Ahad and Ziyarat
/// Ashura, say, started with one tap and left playing in the background.
class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});

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

    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('New playlist'),
      ),
      bottomNavigationBar: const NowPlayingBar(),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, audio]),
        builder: (context, _) {
          final playlists = store.playlists;
          if (playlists.isEmpty) {
            return const _EmptyState(
              icon: Icons.queue_music,
              message: 'Make a playlist of the recitations you listen to '
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
                  subtitle: Text(_countLabel(playlist.zikrUids.length)),
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

class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({super.key, required this.playlistId});

  final String playlistId;

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${playlist.name}"?'),
        content: const Text('The duas themselves stay in the app.'),
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

    return ListenableBuilder(
      listenable: Listenable.merge([store, audio]),
      builder: (context, _) {
        final playlist = store.byId(playlistId);
        if (playlist == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const _EmptyState(
              icon: Icons.queue_music,
              message: 'This playlist has been deleted.',
            ),
          );
        }
        final isCurrent = audio.playlist?.id == playlist.id;
        final playingUid = isCurrent ? audio.current?.zikrUid : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(playlist.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') _rename(context, playlist);
                  if (value == 'delete') _delete(context, playlist);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
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
                  message: 'Tap Add to choose recitations. You can also add '
                      'one from the player on any dua with audio.',
                )
              : ResponsiveContent(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
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
                            return ListTile(
                              key: ValueKey('$uid@$index'),
                              selected: isPlaying,
                              leading: Icon(isPlaying
                                  ? Icons.graphic_eq
                                  : Icons.music_note_outlined),
                              title: Text(_zikrTitle(uid)),
                              onTap: () => _startPlaylist(context, playlist,
                                  startZikrIndex: index),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'open') _openZikr(context, uid);
                                  if (value == 'remove') {
                                    store.removeAt(playlist.id, index);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'open', child: Text('Open text')),
                                  PopupMenuItem(
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

/// Every zikr that has a recitation, to tick into a playlist.
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
        appBar: AppBar(title: const Text('Add recitations')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final store = ZikrPlaylistStore.instance;
    final query = _query.trim().toLowerCase();
    final uids = ZikrAudioIndex.instance.uids.toList()
      ..sort((a, b) =>
          _zikrTitle(a).toLowerCase().compareTo(_zikrTitle(b).toLowerCase()));
    final visible = query.isEmpty
        ? uids
        : uids
            .where((uid) => _zikrTitle(uid).toLowerCase().contains(query))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Add recitations')),
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
                      return CheckboxListTile(
                        value: at >= 0,
                        title: Text(_zikrTitle(uid)),
                        onChanged: (checked) => checked == true
                            ? store.addZikr(playlist.id, uid)
                            : store.removeAt(playlist.id, at),
                      );
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
                              '${(audio.currentIndex ?? 0) + 1} of '
                              '${audio.queue.length}',
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
