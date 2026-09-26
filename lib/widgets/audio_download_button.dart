import 'package:flutter/material.dart';

import '../models/zikr_audio_track.dart';
import '../services/audio_download_store.dart';

/// Saves [tracks] for offline listening, shows how far along that is, and
/// offers to delete them again once saved.
///
/// An icon button in the zikr page's player; a labelled button ("Download
/// all") beside a playlist's Play all when [labelled] is set. Renders nothing
/// on web, where there is nowhere to save to.
class AudioDownloadButton extends StatefulWidget {
  const AudioDownloadButton({
    super.key,
    required this.tracks,
    this.labelled = false,
  });

  final List<ZikrAudioTrack> tracks;
  final bool labelled;

  @override
  State<AudioDownloadButton> createState() => _AudioDownloadButtonState();
}

class _AudioDownloadButtonState extends State<AudioDownloadButton> {
  final AudioDownloadStore _store = AudioDownloadStore.instance;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  Future<void> _confirmRemove() async {
    final many = widget.tracks.length > 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(many ? 'Remove downloads?' : 'Remove download?'),
        content: Text(
          '${many ? 'These recitations' : 'This recitation'} will stream '
          'again next time, which needs a connection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _store.remove(widget.tracks);
  }

  @override
  Widget build(BuildContext context) {
    if (!AudioDownloadStore.isSupported || widget.tracks.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final tracks = widget.tracks;
        final downloading = _store.anyDownloading(tracks);
        final done = _store.allDownloaded(tracks);
        final failed = !downloading && !done && _store.anyFailed(tracks);
        final progress = _store.overallProgress(tracks);

        final VoidCallback onPressed;
        final Widget icon;
        final String label;
        final String tooltip;
        if (downloading) {
          onPressed = () => _store.cancel(tracks);
          icon = SizedBox(
            width: 22,
            height: 22,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2.5,
                  // Indeterminate until the first bytes give it a size.
                  value: progress > 0 ? progress : null,
                ),
                const Icon(Icons.stop_rounded, size: 14),
              ],
            ),
          );
          label = 'Downloading ${(progress * 100).floor()}%';
          tooltip = 'Stop downloading';
        } else if (done) {
          onPressed = _confirmRemove;
          icon = Icon(Icons.offline_pin,
              color: Theme.of(context).colorScheme.primary);
          label = 'Downloaded';
          tooltip = 'Saved for offline - tap to remove';
        } else if (failed) {
          onPressed = () => _store.download(tracks);
          icon = Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.error);
          label = 'Retry download';
          tooltip = 'Download failed - tap to retry';
        } else {
          onPressed = () => _store.download(tracks);
          icon = const Icon(Icons.download_for_offline_outlined);
          label = tracks.length > 1 ? 'Download all' : 'Download';
          tooltip = 'Download for offline listening';
        }

        if (!widget.labelled) {
          return IconButton(
            icon: icon,
            tooltip: tooltip,
            onPressed: onPressed,
          );
        }
        return Tooltip(
          message: tooltip,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: icon,
            label: Text(label),
          ),
        );
      },
    );
  }
}
