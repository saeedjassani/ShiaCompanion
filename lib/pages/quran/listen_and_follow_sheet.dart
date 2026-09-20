import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../services/analytics_service.dart';
import '../../services/recitation_recognizer.dart';
import '../../utils/quran_index.dart';
import '../../utils/quran_text_index.dart';
import '../../utils/verse_matcher.dart';
import '../zikr/zikr_content_parser.dart';

/// Listens to a recitation and offers the verse being recited.
///
/// Opens a sheet, listens once, and either jumps straight to the verse or - when
/// the match is not clear-cut - shows the few it could be so the reader picks.
/// Asking is the right default here: a reader who wanted verse 55:13 and is
/// thrown to one of its thirty identical twins has been moved somewhere wrong in
/// a Quran, which is worse than a tap.
///
/// Returns the chosen verse, or null if nothing was chosen.
///
/// [recognizer] is the speech engine, defaulting to the OS one. Injected rather
/// than reached for so the sheet's own behaviour - which verse it jumps to, when
/// it asks instead - is testable without a microphone, and so that swapping in a
/// Quran-tuned model later is a one-line change here.
Future<VerseKey?> showListenAndFollowSheet(
  BuildContext context, {
  VerseKey? readingAt,
  RecitationRecognizer? recognizer,
}) {
  return showModalBottomSheet<VerseKey>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _ListenAndFollowSheet(
      readingAt: readingAt,
      recognizer: recognizer ?? OsSpeechRecitationRecognizer.instance,
    ),
  );
}

/// What the sheet is doing.
enum _Stage { preparing, listening, matching, candidates, empty, error }

class _ListenAndFollowSheet extends StatefulWidget {
  const _ListenAndFollowSheet({required this.recognizer, this.readingAt});

  final RecitationRecognizer recognizer;
  final VerseKey? readingAt;

  @override
  State<_ListenAndFollowSheet> createState() => _ListenAndFollowSheetState();
}

class _ListenAndFollowSheetState extends State<_ListenAndFollowSheet> {
  RecitationRecognizer get _recognizer => widget.recognizer;
  StreamSubscription<RecitationTranscript>? _subscription;

  _Stage _stage = _Stage.preparing;
  String _transcript = '';
  String _message = '';
  List<VerseMatch> _candidates = const [];
  QuranTextIndex? _index;

  /// Guards the one-time start. The asset bundle is an inherited widget, so
  /// reaching it belongs here rather than in `initState`, which runs before
  /// dependencies are available.
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _start();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _recognizer.stop();
    super.dispose();
  }

  Future<void> _start() async {
    // "Listen again" comes back through here, so the previous attempt's stream
    // is let go of before a second one is opened.
    await _subscription?.cancel();
    _subscription = null;

    if (!mounted) return;
    setState(() {
      _stage = _Stage.preparing;
      _transcript = '';
      _candidates = const [];
    });

    // Both halves of the setup are slow the first time and cached after, so they
    // run together rather than one behind the other: the index parses 114
    // documents while the engine asks for the microphone.
    final indexFuture = loadQuranTextIndex(DefaultAssetBundle.of(context));
    final availability = await _recognizer.ensureAvailable();
    if (!mounted) return;

    if (availability != RecognizerAvailability.ready) {
      setState(() {
        _stage = _Stage.error;
        _message = _explain(availability);
      });
      return;
    }

    try {
      _index = await indexFuture;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _message = 'Could not read the Quran text on this device.';
      });
      return;
    }
    if (!mounted) return;

    setState(() => _stage = _Stage.listening);

    _subscription = _recognizer.listen().listen(
      (transcript) {
        if (!mounted) return;
        setState(() => _transcript = transcript.text);
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _stage = _Stage.error;
          _message = 'The recogniser stopped unexpectedly. Try again.';
        });
      },
      onDone: _match,
    );
  }

  /// Ends listening early, on the reader's say-so, and matches what came in.
  Future<void> _stopAndMatch() async {
    await _recognizer.stop();
  }

  void _match() {
    if (!mounted) return;
    final index = _index;
    if (index == null) return;

    setState(() => _stage = _Stage.matching);

    final matches = matchRecitation(
      _transcript,
      index: index,
      context: widget.readingAt,
    );

    _report(matches);

    final best = matches.best;
    if (best == null) {
      setState(() {
        _stage = _Stage.empty;
        _message = matches.matchedTokens == 0
            ? 'Nothing recognisable came through. Try again, a little closer to '
                'the reciter.'
            : 'Could not place that in the Quran. Try reciting a little more.';
      });
      return;
    }

    if (matches.isConfident) {
      Navigator.of(context).pop(best.verse);
      return;
    }

    setState(() {
      _stage = _Stage.candidates;
      _candidates = matches.candidates;
    });
  }

  /// Records how well the match went.
  ///
  /// This is the instrument that decides whether the OS recogniser is good
  /// enough or whether a Quran-tuned model has to be bundled: what matters is
  /// not that people tapped the button but whether the verse it offered was the
  /// one they wanted. No audio and no verse text leaves the device.
  void _report(RecitationMatches matches) {
    AnalyticsService.feature(
      _featureKey,
      label: 'Quran listen and follow',
      parameters: {
        'words': quranTokens(_transcript).length,
        'matched_words': matches.matchedTokens,
        'top_score': (matches.best?.score ?? 0).toStringAsFixed(2),
        'margin': matches.margin.toStringAsFixed(2),
        'auto_jumped': matches.isConfident.toString(),
        'on_device': _recognizer.ranOnDevice.toString(),
      },
    );
  }

  /// Records which candidate was actually wanted - the honest accuracy signal,
  /// since rank 1 being right is what "it works" means.
  void _choose(int rank, VerseKey verse) {
    AnalyticsService.feature(
      '${_featureKey}_chosen',
      label: 'Quran listen and follow: candidate chosen',
      parameters: {'rank': rank},
    );
    Navigator.of(context).pop(verse);
  }

  String _explain(RecognizerAvailability availability) {
    switch (availability) {
      case RecognizerAvailability.permissionDenied:
        return 'Listening needs microphone access. You can grant it in your '
            'device settings.';
      case RecognizerAvailability.unsupported:
        return 'This device has no speech recogniser available.';
      case RecognizerAvailability.noArabicLocale:
        return 'This device has no Arabic speech recognition installed. Adding '
            'Arabic in your device\'s language settings enables it.';
      case RecognizerAvailability.failed:
        return 'Could not start listening. Try again.';
      case RecognizerAvailability.ready:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Listen and follow',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._buildStage(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStage(ThemeData theme) {
    switch (_stage) {
      case _Stage.preparing:
        return [
          const _Status(
            icon: Icons.mic_none,
            text: 'Getting ready…',
            busy: true,
          ),
        ];

      case _Stage.listening:
        return [
          const _Status(icon: Icons.mic, text: 'Listening…', busy: true),
          const SizedBox(height: 12),
          Text(
            _transcript.isEmpty
                ? 'Hold the phone towards the recitation.'
                : _transcript,
            textAlign: _transcript.isEmpty ? TextAlign.start : TextAlign.end,
            textDirection:
                _transcript.isEmpty ? TextDirection.ltr : TextDirection.rtl,
            style: _transcript.isEmpty
                ? theme.textTheme.bodyMedium
                : TextStyle(
                    fontFamily: arabicFont,
                    fontFamilyFallback: const ['Qalam'],
                    fontSize: 18,
                  ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.stop),
            label: const Text('Find the verse now'),
            onPressed: _transcript.isEmpty ? null : _stopAndMatch,
          ),
        ];

      case _Stage.matching:
        return [
          const _Status(
            icon: Icons.search,
            text: 'Finding the verse…',
            busy: true,
          ),
        ];

      case _Stage.candidates:
        return [
          Text(
            'Which verse was it?',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _candidates.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final match = _candidates[index];
                return _CandidateRow(
                  match: match,
                  onTap: () => _choose(index + 1, match.verse),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Listen again'),
            onPressed: _start,
          ),
        ];

      case _Stage.empty:
      case _Stage.error:
        return [
          _Status(
            icon: _stage == _Stage.error
                ? Icons.error_outline
                : Icons.hearing_disabled,
            text: _message,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
            onPressed: _start,
          ),
        ];
    }
  }
}

const String _featureKey = 'quran_listen_and_follow';

class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.text, this.busy = false});

  final IconData icon;
  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

/// One verse the recitation might have been.
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.match, required this.onTap});

  final VerseMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = surahInfoFor(match.verse.surah);
    final name = info?.englishName ?? 'Surah ${match.verse.surah}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '$name ${match.verse.ayah}',
        style: theme.textTheme.labelLarge,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Text(
            ZikrContentParser.formatArabicText(match.arabic),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: arabicFont,
              fontFamilyFallback: const ['Qalam'],
              fontSize: 18,
            ),
          ),
          if (match.translation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              match.translation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
