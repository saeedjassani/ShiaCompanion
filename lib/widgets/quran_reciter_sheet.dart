import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../models/quran_listening.dart';
import '../models/zikr_audio_track.dart';
import 'choice_sheet.dart';

/// Asks who recites a surah: the verse-by-verse reciter or the surah's own
/// [recording]. Resolves to the choice, or null when dismissed. Opened from
/// Listen, from the recording's player and from the now-playing capsule, so
/// all three offer the same two names.
Future<QuranListenReciter?> showQuranReciterSheet(
  BuildContext context, {
  required ZikrAudioTrack recording,
  required QuranListenReciter current,
}) {
  final l10n = context.l10n;
  return showChoiceSheet<QuranListenReciter>(
    context,
    title: l10n.quranChooseReciter,
    current: current,
    choices: [
      Choice(
        QuranListenReciter.verses,
        quranVerseTrack(1, 1).artist,
        hint: l10n.quranReciterVerseByVerse,
      ),
      Choice(
        QuranListenReciter.recording,
        recording.artist,
        hint: l10n.quranReciterWholeSurah,
      ),
    ],
  );
}

/// The surah whose recording the reader chose from the now-playing capsule,
/// while its verses were being recited: the reader's page for that surah
/// opens its player on it and clears this. Null when nothing is asked for.
final ValueNotifier<int?> quranRecordingRequest = ValueNotifier(null);
