import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../data/uid_title_data.dart';
import '../models/zikr_audio_track.dart';
import '../services/analytics_service.dart';
import '../services/audio_download_store.dart';
import '../services/zikr_audio_index.dart';
import '../widgets/audio_download_button.dart';
import '../widgets/responsive_content.dart';
import 'zikr/zikr_page.dart';

String _zikrTitle(String uid) {
  final title = items[uid]?.toString().trim() ?? '';
  return title.isEmpty ? uid : title;
}

/// Every recitation saved for offline listening, how much room each takes,
/// and the way to clear them - one at a time or all at once.
///
/// Reached from Settings and from the Playlists screen.
class DownloadedAudioPage extends StatefulWidget {
  const DownloadedAudioPage({super.key});

  @override
  State<DownloadedAudioPage> createState() => _DownloadedAudioPageState();
}

class _DownloadedAudioPageState extends State<DownloadedAudioPage> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future.wait([
      ZikrAudioIndex.instance.load(),
      AudioDownloadStore.instance.load(),
    ]).then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  Future<void> _removeAll(BuildContext context, int bytes) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove all downloads?'),
        content: Text(
          "Every recitation will stream again, so you'll need a connection "
          'to listen. Frees ${formatAudioBytes(bytes)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove all'),
          ),
        ],
      ),
    );
    if (confirmed == true) await AudioDownloadStore.instance.removeAll();
  }

  void _open(BuildContext context, String uid) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ZikrPage(
        UidTitleData(uid, _zikrTitle(uid)),
        source: ZikrOpenSource.downloads,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = AudioDownloadStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: store,
              builder: (context, _) => _buildBody(context, store),
            ),
    );
  }

  Widget _buildBody(BuildContext context, AudioDownloadStore store) {
    final theme = Theme.of(context);
    final index = ZikrAudioIndex.instance;

    // Each zikr with anything saved or on its way, and which saved files
    // belong to one - the rest are left over from a recording since renamed.
    final entries = <(String, List<ZikrAudioTrack>)>[];
    final claimed = <String>{};
    for (final uid in index.uids) {
      final tracks = index.tracksFor(uid);
      if (!store.anyDownloaded(tracks) && !store.anyDownloading(tracks)) {
        continue;
      }
      entries.add((uid, tracks));
      claimed.addAll(tracks.map(AudioDownloadStore.fileNameFor));
    }
    entries.sort((a, b) => _zikrTitle(a.$1)
        .toLowerCase()
        .compareTo(_zikrTitle(b.$1).toLowerCase()));
    final orphans =
        store.savedFileNames.where((name) => !claimed.contains(name)).toList();
    final totalBytes = store.totalSavedBytes;

    if (entries.isEmpty && orphans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_for_offline_outlined,
                  size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'No downloads yet',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Download a recitation to listen without a connection - '
                'tap the download button in a dua\'s audio player, or '
                'Download all on a playlist.',
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

    return ResponsiveContent(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Icon(Icons.sd_storage_outlined,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${formatAudioBytes(totalBytes)} used on this device',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (totalBytes > 0)
                  TextButton(
                    onPressed: () => _removeAll(context, totalBytes),
                    child: const Text('Remove all'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final (uid, tracks) in entries)
            _DownloadedZikrTile(
              title: _zikrTitle(uid),
              tracks: tracks,
              onOpen: () => _open(context, uid),
            ),
          if (orphans.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.audio_file_outlined),
              title: const Text('Older recordings'),
              subtitle: Text(
                '${orphans.length} no longer used by any dua · '
                '${formatAudioBytes(_orphanBytes(store, orphans))}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove older recordings',
                onPressed: () =>
                    unawaited(store.remove(_orphanTracks(orphans))),
              ),
            ),
        ],
      ),
    );
  }

  /// Saved files no zikr names any more, as tracks the store can act on.
  static List<ZikrAudioTrack> _orphanTracks(List<String> names) => [
        for (final name in names) ZikrAudioTrack(url: '$zikrAudioBaseUrl$name'),
      ];

  static int _orphanBytes(AudioDownloadStore store, List<String> names) =>
      store.savedBytesOf(_orphanTracks(names));
}

class _DownloadedZikrTile extends StatelessWidget {
  const _DownloadedZikrTile({
    required this.title,
    required this.tracks,
    required this.onOpen,
  });

  final String title;
  final List<ZikrAudioTrack> tracks;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final store = AudioDownloadStore.instance;
    final saved = tracks.where(store.isDownloaded).length;
    final downloading = store.anyDownloading(tracks);

    final String subtitle;
    if (downloading) {
      final percent = (store.overallProgress(tracks) * 100).floor();
      subtitle = 'Downloading $percent%';
    } else {
      final count = tracks.length > 1
          ? (saved == tracks.length
              ? '${tracks.length} recordings'
              : '$saved of ${tracks.length} recordings')
          : null;
      subtitle = [
        if (count != null) count,
        formatAudioBytes(store.savedBytesOf(tracks)),
      ].join(' · ');
    }

    return ListTile(
      leading: Icon(
        downloading ? Icons.downloading_rounded : Icons.offline_pin_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onOpen,
      trailing: downloading
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Stop downloading',
              onPressed: () => store.cancel(tracks),
            )
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove download',
              onPressed: () =>
                  confirmRemoveAudioDownload(context, tracks, label: title),
            ),
    );
  }
}
