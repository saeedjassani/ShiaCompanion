import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../data/uid_title_data.dart';
import '../models/zikr_audio_track.dart';
import '../services/analytics_service.dart';
import '../services/audio_download_store.dart';
import '../services/exclusive_audio.dart';
import '../services/preferences_sync_service.dart';
import '../utils/network_utils.dart';
import '../utils/shared_preferences.dart';
import '../pages/playlists_page.dart';
import '../theme/shia_colors.dart';
import 'audio_download_button.dart';
import 'choice_sheet.dart';
import 'outline_icon.dart';
import '../l10n/l10n.dart';

/// Recitation player hosted inside [ZikrActionBar], in place of its action
/// row. It is only built once a reader taps Listen, so the ~95% of readings
/// that never touch audio pay nothing for it.
///
/// Many recordings come from duas.org, whose permission is conditional on
/// credit; that acknowledgement lives on the About page rather than here, so
/// this bar stays focused on playback.
///
/// Playback is streamed from the app's R2 bucket unless the reader has saved
/// the recitation for offline listening (the download button here, or a
/// playlist's Download all - see [AudioDownloadStore]): the corpus is about a
/// gigabyte and individual tracks run to 39 MB, so nothing is saved
/// unasked. Streaming works on web, where nothing can be saved, because just_audio drives a plain `<audio>` element, which is exempt
/// from CORS, so the bucket needs no `Access-Control-Allow-Origin` - anything
/// that read the bytes directly (`fetch`, or an element with `crossOrigin`
/// set) would need one.
///
/// Each track carries a [MediaItem] tag so just_audio_background can show a
/// lock-screen/notification control and keep playing once the app is
/// backgrounded - the point of a player at all for something like Dua Kumayl,
/// which runs half an hour.
class ZikrAudioPlayer extends StatefulWidget {
  final List<ZikrAudioTrack> tracks;
  final String zikrUid;
  final String zikrTitle;

  /// Dismisses the player and hands the bar back to the action row. Disposing
  /// this widget stops playback, so closing is also how a reader stops.
  final VoidCallback onClose;

  const ZikrAudioPlayer({
    Key? key,
    required this.tracks,
    required this.zikrUid,
    required this.zikrTitle,
    required this.onClose,
  }) : super(key: key);

  @override
  State<ZikrAudioPlayer> createState() => _ZikrAudioPlayerState();
}

class _ZikrAudioPlayerState extends State<ZikrAudioPlayer> {
  AudioPlayer? _player;
  int _trackIndex = 0;
  bool _failed = false;
  bool _hasCountedPlay = false;
  double? _dragValue;
  StreamSubscription<PlayerState>? _stateSub;

  // setAudioSource is what attaches the MediaItem tag (the zikr/track title)
  // that the notification and lock screen read. _togglePlay awaits this so a
  // tap on a page that just opened can never start playback - and so the
  // foreground-service notification - before that title is attached; without
  // it, Android has nothing to show but the notification channel's generic
  // name until the load catches up.
  Future<void> _loadFuture = Future.value();

  /// Where the recording the reader last chose for this zikr is kept, so a
  /// zikr with several opens on that one next time rather than the first.
  /// Keyed by content uid, so an alias shares its canonical's choice, and
  /// synced to the reader's other devices by [PreferencesSyncService].
  String get _contentUid => UidTitleData(widget.zikrUid, '').getFirstUId();

  /// The remembered recording's index, or the first when there is none or
  /// it is no longer among [ZikrAudioPlayer.tracks].
  int _savedTrackIndex() {
    if (widget.tracks.length < 2 || !SP.isInitialized) return 0;
    final file = SP.prefs
        .getString(PreferencesSyncService.audioTrackPrefKey(_contentUid));
    if (file == null) return 0;
    final index = widget.tracks.indexWhere((track) => track.file == file);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _trackIndex = _savedTrackIndex();
    _player = AudioPlayer();
    _stateSub = _player?.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _loadFuture = _load();
    // Tapping the headphones icon in the action bar is what mounts this
    // widget at all, so that tap should start the recitation, not just open
    // a paused player that needs a second tap.
    unawaited(_togglePlay());
  }

  @override
  void didUpdateWidget(covariant ZikrAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An admin edit can swap the track list under a live player.
    if (oldWidget.tracks != widget.tracks) {
      _trackIndex = _savedTrackIndex();
      _failed = false;
      _loadFuture = _load();
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    ExclusiveAudio.relinquish(this);
    _player?.dispose();
    _player = null;
    super.dispose();
  }

  /// Called when a playlist starts while this page's player is alive: only
  /// one player may exist at a time, so this one goes and the bar closes.
  Future<void> _releaseToOtherPlayer() async {
    await _stateSub?.cancel();
    _stateSub = null;
    final player = _player;
    _player = null;
    await player?.dispose();
    if (mounted) widget.onClose();
  }

  ZikrAudioTrack? get _currentTrack =>
      _trackIndex >= 0 && _trackIndex < widget.tracks.length
          ? widget.tracks[_trackIndex]
          : null;

  Future<void> _load() async {
    final track = _currentTrack;
    if (_player == null || track == null) return;

    // A playlist playing in the background owns the one player the app is
    // allowed; it has to be gone before this one loads.
    await ExclusiveAudio.claim(this, _releaseToOtherPlayer);
    await AudioDownloadStore.instance.load();
    final player = _player;
    if (player == null) return;

    try {
      await player.setAudioSource(AudioSource.uri(
        AudioDownloadStore.instance.sourceUri(track),
        tag: MediaItem(
          // Unique per zikr+track, not just the URL, so the notification
          // updates correctly if two zikrs ever happened to share a file.
          id: '${widget.zikrUid}#$_trackIndex',
          title: track.displayLabel ?? widget.zikrTitle,
          album: widget.zikrTitle,
          artist: track.artist,
        ),
      ));
      if (!mounted) return;
      setState(() => _failed = false);
    } catch (error) {
      // A recording that has moved or been removed must not leave a play
      // button that does nothing, so the player removes itself instead.
      debugPrint('Zikr audio failed to load: $error');
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null) return;

    if (player.playing) {
      await player.pause();
      return;
    }

    await _loadFuture;
    if (!mounted || _failed) return;

    // Restart rather than no-op when the track has run to the end.
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }
    if (!_hasCountedPlay) {
      _hasCountedPlay = true;
      unawaited(AnalyticsService.feature(
        'zikr_audio_play',
        label: 'Zikr audio played',
        parameters: {'zikr_uid': widget.zikrUid},
      ));
    }
    await player.play();
  }

  Future<void> _retry() async {
    setState(() => _failed = false);
    await (_loadFuture = _load());
    if (mounted && !_failed) unawaited(_togglePlay());
  }

  Future<void> _selectTrack(int index) async {
    if (index == _trackIndex) return;
    final wasPlaying = _player?.playing ?? false;
    setState(() {
      _trackIndex = index;
      _dragValue = null;
    });
    final track = _currentTrack;
    if (track != null) {
      unawaited(PreferencesSyncService.instance
          .setAudioTrack(_contentUid, track.file));
    }
    await _player?.stop();
    await (_loadFuture = _load());
    // Switching tracks mid-recitation should carry the "playing" state
    // across, the same as choosing a track was never a pause action.
    if (wasPlaying) unawaited(_togglePlay());
  }

  Future<void> _showTrackPicker() async {
    final store = AudioDownloadStore.instance;
    final selected = await showChoiceSheet<int>(
      context,
      title: context.l10n.audioChooseRecording,
      current: _trackIndex,
      choices: [
        for (var i = 0; i < widget.tracks.length; i++)
          Choice(
            i,
            widget.tracks[i].displayLabel ?? context.l10n.audioTrackNumber(i + 1),
            hint: store.isDownloaded(widget.tracks[i])
                ? context.l10n.audioDownloaded
                : widget.tracks[i].artist,
          ),
      ],
    );
    if (selected != null) await _selectTrack(selected);
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (player == null || widget.tracks.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final close = PlayerIconButton(
      label: l10n.audioClosePlayer,
      icon: OutlineIcon(OutlineGlyph.close,
          size: 20, color: colors.textMuted, strokeWidth: 2),
      onPressed: widget.onClose,
    );

    // A track that will not load leaves the bar in place but says so, rather
    // than vanishing: the reader asked for audio and deserves an answer.
    // Closing returns them to the action row.
    if (_failed) {
      // Offline with nothing saved is the common case, and one the reader can
      // fix - so it says so, rather than implying the recording is gone.
      final track = _currentTrack;
      final offline = !NetworkUtils().isOnline &&
          track != null &&
          !AudioDownloadStore.instance.isDownloaded(track);
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: Row(
          children: [
            OutlineIcon(offline ? OutlineGlyph.cloud : OutlineGlyph.alert,
                size: 22, color: colors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                offline ? l10n.audioOfflineNotDownloaded : l10n.audioLoadFailed,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ShiaText.caption.copyWith(color: colors.text),
              ),
            ),
            PlayerIconButton(
              label: l10n.commonTryAgain,
              icon: OutlineIcon(OutlineGlyph.reset,
                  size: 20, color: colors.accent, strokeWidth: 2),
              onPressed: _retry,
            ),
            close,
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildPlayButton(player),
        const SizedBox(width: 8),
        Expanded(child: _buildBody(player)),
        PlayerIconButton(
          label: l10n.playlistAddTo,
          icon: OutlineIcon(OutlineGlyph.playlistAdd,
              size: 22, color: colors.accent),
          onPressed: () => showAddToPlaylistSheet(
            context,
            zikrUid: widget.zikrUid,
            zikrTitle: widget.zikrTitle,
            track: widget.tracks.length > 1 ? _currentTrack : null,
          ),
        ),
        if (AudioDownloadStore.isSupported)
          AudioDownloadButton(
            tracks: widget.tracks,
            label: widget.zikrTitle,
          ),
        close,
      ],
    );
  }

  /// The 48 px accent play/pause button, a spinner while it loads.
  Widget _buildPlayButton(AudioPlayer player) {
    final colors = ShiaColors.of(context);
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final waiting = state?.processingState == ProcessingState.loading ||
            state?.processingState == ProcessingState.buffering;
        final playing = state?.playing ?? false;
        final label = playing
            ? context.l10n.audioPauseRecitation
            : context.l10n.audioPlayRecitation;
        return Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            onTap: _togglePlay,
            child: Material(
              color: colors.accent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _togglePlay,
                child: SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: waiting
                        ? SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: colors.onAccent),
                          )
                        : OutlineIcon(
                            playing ? OutlineGlyph.pause : OutlineGlyph.play,
                            size: 22,
                            color: colors.onAccent,
                            strokeWidth: 2,
                            filled: true,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// What is playing - the recording's name, which opens the other
  /// recordings when there are some - over the seek bar.
  Widget _buildBody(AudioPlayer player) {
    final colors = ShiaColors.of(context);
    final track = _currentTrack;
    final several = widget.tracks.length > 1;
    final label = several
        ? (track?.displayLabel ?? context.l10n.audioRecitation)
        : context.l10n.audioRecitationAudio;
    final style = ShiaText.caption.copyWith(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w600,
      color: several ? colors.accent : colors.text,
    );

    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (several) ...[
          const SizedBox(width: 2),
          OutlineIcon(OutlineGlyph.chevronDown,
              size: 14, color: colors.accent, strokeWidth: 2.2),
        ],
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (several)
          Semantics(
            button: true,
            label: '${context.l10n.audioChooseRecording}: $label',
            excludeSemantics: true,
            onTap: _showTrackPicker,
            child: InkWell(
              onTap: _showTrackPicker,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: title,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: title,
          ),
        _buildProgress(player),
      ],
    );
  }

  Widget _buildProgress(AudioPlayer player) {
    final colors = ShiaColors.of(context);
    final timeStyle = ShiaText.caption.copyWith(
      fontSize: 11,
      height: 13 / 11,
      color: colors.textMuted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final duration = player.duration ?? Duration.zero;
        final position = snapshot.data ?? Duration.zero;
        final totalMs = duration.inMilliseconds.toDouble();
        final positionMs = position.inMilliseconds
            .clamp(0, duration.inMilliseconds)
            .toDouble();

        return Row(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Text(
                _formatDuration(
                    Duration(milliseconds: (_dragValue ?? positionMs).round())),
                style: timeStyle,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: colors.accent,
                  inactiveTrackColor: colors.divider,
                  thumbColor: colors.accent,
                  overlayColor: colors.accent.withValues(alpha: 0.12),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  min: 0,
                  // A zero max would make the Slider assert before duration
                  // arrives, which is a frame or two after the first build.
                  max: totalMs <= 0 ? 1 : totalMs,
                  value: totalMs <= 0 ? 0 : (_dragValue ?? positionMs),
                  onChanged: totalMs <= 0
                      ? null
                      : (value) => setState(() => _dragValue = value),
                  onChangeEnd: totalMs <= 0
                      ? null
                      : (value) {
                          _player?.seek(Duration(milliseconds: value.round()));
                          setState(() => _dragValue = null);
                        },
                ),
              ),
            ),
            Text(_formatDuration(duration), style: timeStyle),
          ],
        );
      },
    );
  }
}
