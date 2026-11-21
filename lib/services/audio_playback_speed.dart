import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../utils/shared_preferences.dart';
import '../widgets/choice_sheet.dart';
import 'analytics_service.dart';

/// How fast recitations play: one setting for the zikr page's player and
/// the playlist player alike, kept on the device so the next recitation
/// opens at the pace the reader last chose. Someone following a dua line by
/// line slows it down; someone who knows it by heart speeds it up.
///
/// The Azan is not affected: it is a call, not something to study.
class AudioPlaybackSpeed {
  AudioPlaybackSpeed._();

  /// Where the chosen speed is kept.
  static const String prefKey = 'audio_playback_speed';

  static const double normal = 1.0;

  /// What the speed picker offers. just_audio keeps the pitch as the pace
  /// changes, so a slowed recitation still sounds like the reciter.
  static const List<double> choices = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  /// The chosen speed, followed by every live player.
  static final ValueNotifier<double> current = ValueNotifier(_stored());

  static double _stored() {
    if (!SP.isInitialized) return normal;
    final value = SP.prefs.getDouble(prefKey);
    return value != null && choices.contains(value) ? value : normal;
  }

  static Future<void> set(double speed) async {
    if (!choices.contains(speed) || speed == current.value) return;
    current.value = speed;
    unawaited(
      AnalyticsService.feature(
        'audio_speed_changed',
        label: 'Audio speed changed',
        parameters: {'speed': '$speed'},
      ),
    );
    if (SP.isInitialized) await SP.prefs.setDouble(prefKey, speed);
  }

  /// Keeps [player] at the chosen speed until the returned callback is
  /// called (or the player is disposed, after which changes are ignored).
  static VoidCallback follow(AudioPlayer player) {
    void apply() {
      unawaited(
        player.setSpeed(current.value).catchError((Object error) {
          debugPrint('Audio speed not applied: $error');
        }),
      );
    }

    apply();
    current.addListener(apply);
    return () => current.removeListener(apply);
  }

  /// "1.25×", in the app language's digits and decimal mark.
  static String label(double speed, [AppLocalizations? l10n]) =>
      (l10n ?? L10n.current).audioSpeedValue(speed);

  /// Asks for a speed and applies it.
  static Future<void> pick(BuildContext context) async {
    final l10n = context.l10n;
    final selected = await showChoiceSheet<double>(
      context,
      title: l10n.audioPlaybackSpeed,
      current: current.value,
      choices: [
        for (final speed in choices)
          Choice(
            speed,
            label(speed, l10n),
            hint: speed == normal ? l10n.audioSpeedNormal : null,
          ),
      ],
    );
    if (selected != null) await set(selected);
  }
}
