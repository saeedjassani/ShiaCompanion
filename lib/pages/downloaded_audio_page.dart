import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../data/uid_title_data.dart';
import '../models/zikr_audio_track.dart';
import '../services/analytics_service.dart';
import '../services/zikr_translations.dart';
import '../services/audio_download_store.dart';
import '../services/zikr_audio_index.dart';
import '../theme/shia_colors.dart';
import '../widgets/audio_download_button.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import 'zikr/zikr_page.dart';
import '../l10n/l10n.dart';

String _zikrTitle(String uid) {
  final title = items[uid]?.toString().trim() ?? '';
  return title.isEmpty ? uid : zikrDisplayTitle(uid, title);
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
        title: Text(context.l10n.downloadsRemoveAllTitle),
        content: Text(
          context.l10n.downloadsRemoveAllBody(formatAudioBytes(bytes)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.downloadsRemoveAll),
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
    if (!_ready) {
      return LargeTitlePage(
        title: context.l10n.playlistDownloads,
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
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => _buildPage(context, store),
    );
  }

  Widget _buildPage(BuildContext context, AudioDownloadStore store) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context);
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
    final empty = entries.isEmpty && orphans.isEmpty;

    return LargeTitlePage(
      title: l10n.playlistDownloads,
      subtitle:
          empty ? null : l10n.downloadsSubtitle(formatAudioBytes(totalBytes)),
      slivers: [
        if (empty)
          SliverPadding(
            padding: gutter,
            sliver: SliverToBoxAdapter(
              child: EmptyStateCard(
                glyph: OutlineGlyph.download,
                title: l10n.downloadsEmpty,
                body: l10n.downloadsEmptyBody,
              ),
            ),
          ),
        if (entries.isNotEmpty)
          SliverPadding(
            padding: gutter.copyWith(bottom: 14),
            sliver: SliverCardList(
              itemCount: entries.length,
              itemBuilder: (context, i) => _DownloadedZikrRow(
                title: _zikrTitle(entries[i].$1),
                tracks: entries[i].$2,
                first: i == 0,
                last: i == entries.length - 1,
                onOpen: () => _open(context, entries[i].$1),
              ),
            ),
          ),
        if (orphans.isNotEmpty)
          SliverPadding(
            padding: gutter.copyWith(bottom: 14),
            sliver: SliverToBoxAdapter(
              child: _OlderRecordingsCard(
                count: orphans.length,
                size: formatAudioBytes(_orphanBytes(store, orphans)),
                onRemove: () => unawaited(store.remove(_orphanTracks(orphans))),
              ),
            ),
          ),
        if (totalBytes > 0)
          SliverPadding(
            padding: gutter,
            sliver: SliverToBoxAdapter(
              child: Center(
                child: TextButton(
                  onPressed: () => _removeAll(context, totalBytes),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: colors.danger,
                    textStyle: buttonTextStyle(context, ShiaText.body)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  child: Text(l10n.downloadsRemoveAllButton),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Saved files no zikr names any more, as tracks the store can act on.
  static List<ZikrAudioTrack> _orphanTracks(List<String> names) => [
        for (final name in names) ZikrAudioTrack(url: '$zikrAudioBaseUrl$name'),
      ];

  static int _orphanBytes(AudioDownloadStore store, List<String> names) =>
      store.savedBytesOf(_orphanTracks(names));
}

/// One downloaded zikr: what is saved and how big it is, with a remove
/// button; while it is downloading, how far along it is, and Stop.
class _DownloadedZikrRow extends StatelessWidget {
  const _DownloadedZikrRow({
    required this.title,
    required this.tracks,
    required this.first,
    required this.last,
    required this.onOpen,
  });

  final String title;
  final List<ZikrAudioTrack> tracks;
  final bool first;
  final bool last;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final store = AudioDownloadStore.instance;
    final saved = tracks.where(store.isDownloaded).length;
    final downloading = store.anyDownloading(tracks);

    if (downloading) {
      final progress = store.overallProgress(tracks);
      return CardListRow(
        first: first,
        last: last,
        minHeight: 58,
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.audioDownloadingPercent((progress * 100).floor()),
              style: TextStyle(color: colors.accent),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                // Indeterminate until the first bytes give it a size.
                value: progress > 0 ? progress : null,
                minHeight: 4,
                color: colors.accent,
                backgroundColor: colors.divider,
              ),
            ),
          ],
        ),
        trailing: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
          child: OutlinedButton(
            onPressed: () => store.cancel(tracks),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(44, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foregroundColor: colors.accent,
              side: BorderSide(
                  color: Color.lerp(colors.line, colors.chevron, 0.25)!),
              shape: const StadiumBorder(),
              textStyle: buttonTextStyle(context, ShiaText.secondary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            child: Text(l10n.commonStop),
          ),
        ),
        onTap: onOpen,
      );
    }

    final count = tracks.length > 1
        ? (saved == tracks.length
            ? l10n.audioRecordingsCount(tracks.length)
            : l10n.audioRecordingsChosen(saved, tracks.length))
        : null;
    final subtitle = [
      if (count != null) count,
      formatAudioBytes(store.savedBytesOf(tracks)),
    ].join(' · ');

    void remove() => confirmRemoveAudioDownload(context, tracks, label: title);

    return CardListRow(
      first: first,
      last: last,
      minHeight: 58,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Tooltip(
        message: l10n.audioRemoveDownload,
        excludeFromSemantics: true,
        child: Semantics(
          container: true,
          button: true,
          label: l10n.downloadsRemoveNamed(title),
          excludeSemantics: true,
          onTap: remove,
          child: InkResponse(
            onTap: remove,
            radius: 22,
            child: SizedBox.square(
              dimension: 44,
              child: Center(
                child: OutlineIcon(OutlineGlyph.trash,
                    size: 22, color: colors.accent),
              ),
            ),
          ),
        ),
      ),
      onTap: onOpen,
    );
  }
}

/// Saved recordings no dua plays any more - replaced by newer ones - and
/// the button that clears them.
class _OlderRecordingsCard extends StatelessWidget {
  const _OlderRecordingsCard({
    required this.count,
    required this.size,
    required this.onRemove,
  });

  final int count;
  final String size;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SliverCardList.radius),
        side: BorderSide(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.well,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: OutlineIcon(OutlineGlyph.repeat,
                      size: 20, color: colors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.downloadsOlderCount(count),
                        style: ShiaText.cardTitle.copyWith(color: colors.text),
                      ),
                      Text(
                        l10n.downloadsOlderBody(size),
                        style:
                            ShiaText.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PageButton(
              label: l10n.downloadsRemoveOlder,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
