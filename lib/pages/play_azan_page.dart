import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import '../services/azan_playback_service.dart';
import '../theme/shia_colors.dart';
import '../widgets/page_chrome.dart';

/// One button that plays the bundled Azan, and stops it again. The pinned
/// banner in the app shell carries the same stop control.
class PlayAzanPage extends StatefulWidget {
  const PlayAzanPage({super.key});

  @override
  State<PlayAzanPage> createState() => _PlayAzanPageState();
}

class _PlayAzanPageState extends State<PlayAzanPage> {
  Timer? _poll;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    unawaited(trackScreen('Play Azan Page'));
    unawaited(_check());
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final playing = await AzanPlaybackService.isPlaying();
    if (mounted && playing != _playing) setState(() => _playing = playing);
  }

  Future<void> _toggle() async {
    if (_playing) {
      await AzanPlaybackService.stopIfPlaying();
    } else {
      await AzanPlaybackService.playNow(
        prayerName: context.l10n.azanPrayerFallback,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final label =
        _playing ? context.l10n.commonStop : context.l10n.menuPlayAzan;

    return LargeTitlePage(
      title: context.l10n.menuPlayAzan,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              child: Material(
                color: colors.surface,
                shape: CircleBorder(side: BorderSide(color: colors.line)),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _toggle,
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Icon(
                      _playing
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
