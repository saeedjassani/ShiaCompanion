import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart' show appScaffoldMessengerKey;
import '../models/zikr_audio_track.dart';
import '../services/audio_download_store.dart';
import '../utils/network_utils.dart';
import '../l10n/l10n.dart';

/// Where an [AudioDownloadButton] stands, worked out once per build so the
/// icon and the labelled forms can never disagree.
enum AudioDownloadState { idle, partial, downloading, done, failed }

AudioDownloadState audioDownloadStateOf(
  AudioDownloadStore store,
  List<ZikrAudioTrack> tracks,
) {
  if (store.anyDownloading(tracks)) return AudioDownloadState.downloading;
  if (store.allDownloaded(tracks)) return AudioDownloadState.done;
  if (store.anyFailed(tracks)) return AudioDownloadState.failed;
  if (store.anyDownloaded(tracks)) return AudioDownloadState.partial;
  return AudioDownloadState.idle;
}

/// Starts downloading [tracks], first making sure the reader is online and,
/// on mobile data, that they are happy to spend it. Returns whether the
/// download was started.
Future<bool> startAudioDownload(
  BuildContext context,
  List<ZikrAudioTrack> tracks, {
  String? label,
}) async {
  final store = AudioDownloadStore.instance;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final network = NetworkUtils();
  if (!await network.isDeviceOnline()) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(context.l10n.audioOfflineCannotDownload),
      ));
    return false;
  }
  if (await network.isOnMobileDataOnly()) {
    if (!context.mounted) return false;
    final size = store.bytesToDownload(tracks);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.signal_cellular_alt),
        title: Text(context.l10n.audioMobileDataTitle),
        content: Text(size == null
            ? context.l10n.audioMobileDataBody
            : context.l10n.audioMobileDataSizedBody(formatAudioBytes(size))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.audioDownload),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
  }
  await store.download(tracks, label: label);
  return true;
}

/// Asks before deleting [tracks]' saved audio, saying how much space it frees.
Future<void> confirmRemoveAudioDownload(
  BuildContext context,
  List<ZikrAudioTrack> tracks, {
  String? label,
}) async {
  final store = AudioDownloadStore.instance;
  final saved = tracks.where(store.isDownloaded).length;
  final bytes = store.savedBytesOf(tracks);
  final many = saved > 1;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(many
          ? context.l10n.audioRemoveDownloadsTitle
          : context.l10n.audioRemoveDownloadTitle),
      content: Text(
        context.l10n.audioRemoveBody(label == null
                ? (many
                    ? context.l10n.audioTheseRecitations
                    : context.l10n.audioThisRecitation)
                : context.l10n.audioQuotedName(label)) +
            (bytes > 0
                ? ' ${context.l10n.audioRemoveFrees(formatAudioBytes(bytes))}'
                : ''),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(context.l10n.commonRemove),
        ),
      ],
    ),
  );
  if (confirmed == true) await store.remove(tracks);
}

/// The app-wide message when a download finishes, shown wherever the reader
/// has got to by then. Registered once in main().
void showAudioDownloadResult(AudioDownloadResult result) {
  final messenger = appScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  final name = result.label;
  final total = result.saved + result.failed;

  final String message;
  SnackBarAction? action;
  if (result.succeeded) {
    final l10n = L10n.current;
    message = name == null
        ? l10n.audioDownloadDone
        : l10n.audioDownloadDoneNamed(name);
  } else {
    final l10n = L10n.current;
    final what = name ??
        (total > 1
            ? l10n.audioTheseRecitationsLower
            : l10n.audioThisRecitationLower);
    final partial = result.saved > 0
        ? l10n.audioDownloadPartial(result.saved, total)
        : l10n.audioDownloadFailedNamed(what);
    final reason = switch (result.failure) {
      AudioDownloadFailure.storage => l10n.audioDownloadOutOfSpace,
      AudioDownloadFailure.unavailable => l10n.audioDownloadUnavailable,
      _ => l10n.audioDownloadCheckConnection,
    };
    message = '$partial $reason';
    if (result.failure != AudioDownloadFailure.unavailable) {
      action = SnackBarAction(
        label: l10n.commonRetry,
        onPressed: () => unawaited(AudioDownloadStore.instance
            .download(result.tracks, label: result.label)),
      );
    }
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

/// Saves [tracks] for offline listening, shows how far along that is, and
/// offers to delete them again once saved.
///
/// An icon button in the zikr page's player; a labelled button ("Download ·
/// 42 MB") beside a playlist's Play all when [labelled] is set. [label] names
/// what is being downloaded in the messages. Renders nothing on web, where
/// there is nowhere to save to.
class AudioDownloadButton extends StatefulWidget {
  const AudioDownloadButton({
    super.key,
    required this.tracks,
    this.label,
    this.labelled = false,
  });

  final List<ZikrAudioTrack> tracks;
  final String? label;
  final bool labelled;

  @override
  State<AudioDownloadButton> createState() => _AudioDownloadButtonState();
}

class _AudioDownloadButtonState extends State<AudioDownloadButton> {
  final AudioDownloadStore _store = AudioDownloadStore.instance;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant AudioDownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracks.length != widget.tracks.length ||
        !oldWidget.tracks.every(widget.tracks.contains)) {
      _prepare();
    }
  }

  void _prepare() {
    if (!AudioDownloadStore.isSupported) return;
    // The size goes on the button, so the reader knows what they are
    // agreeing to before they tap.
    unawaited(_store.fetchSizes(widget.tracks));
  }

  void _onPressed(AudioDownloadState state) {
    final tracks = widget.tracks;
    switch (state) {
      case AudioDownloadState.downloading:
        _store.cancel(tracks);
      case AudioDownloadState.done:
        unawaited(
            confirmRemoveAudioDownload(context, tracks, label: widget.label));
      case AudioDownloadState.idle:
      case AudioDownloadState.partial:
      case AudioDownloadState.failed:
        unawaited(startAudioDownload(context, tracks, label: widget.label));
    }
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
        final colorScheme = Theme.of(context).colorScheme;
        final state = audioDownloadStateOf(_store, tracks);
        final progress = _store.overallProgress(tracks);
        final percent = (progress * 100).floor();
        final toDownload = _store.bytesToDownload(tracks);
        final sizeSuffix =
            toDownload == null ? '' : ' · ${formatAudioBytes(toDownload)}';
        final remaining = tracks.where((t) => !_store.isDownloaded(t)).length;

        final Widget icon;
        final String label;
        final String tooltip;
        switch (state) {
          case AudioDownloadState.downloading:
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
                    semanticsLabel: context.l10n.audioDownloading,
                    semanticsValue: context.l10n.commonPercent(percent),
                  ),
                  const Icon(Icons.stop_rounded, size: 14),
                ],
              ),
            );
            label = progress > 0
                ? context.l10n.audioDownloadingPercent(percent)
                : context.l10n.audioDownloadingEllipsis;
            tooltip = context.l10n.audioStopDownloading;
          case AudioDownloadState.done:
            icon = Icon(Icons.offline_pin_rounded, color: colorScheme.primary);
            label = context.l10n.audioDownloaded;
            tooltip = context.l10n.audioDownloadedTooltip;
          case AudioDownloadState.failed:
            icon = Icon(Icons.sync_problem_rounded, color: colorScheme.error);
            label = context.l10n.audioRetryDownload;
            tooltip = context.l10n.audioDownloadFailedTooltip;
          case AudioDownloadState.partial:
            icon = const Icon(Icons.download_for_offline_outlined);
            label = context.l10n.audioDownloadMore(remaining) + sizeSuffix;
            tooltip = context.l10n.audioDownloadRestTooltip;
          case AudioDownloadState.idle:
            icon = const Icon(Icons.download_for_offline_outlined);
            label = (tracks.length > 1
                    ? context.l10n.audioDownloadAll
                    : context.l10n.audioDownload) +
                sizeSuffix;
            tooltip = context.l10n.audioDownloadForOffline + sizeSuffix;
        }

        if (!widget.labelled) {
          return IconButton(
            icon: icon,
            tooltip: tooltip,
            onPressed: () => _onPressed(state),
          );
        }
        return Tooltip(
          message: tooltip,
          child: OutlinedButton.icon(
            onPressed: () => _onPressed(state),
            icon: icon,
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
