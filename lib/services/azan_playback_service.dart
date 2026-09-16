import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plays the full Azan - or, on Android, a user's Custom Audio choice - as
/// real, app-controlled audio rather than a plain notification sound.
///
/// A notification's `sound:` field is a short OS ringtone: any other
/// notification, an incoming call, or the user simply touching the phone can
/// cut it off, and there is no player behind it to resume or stop. This
/// service instead runs the recording through the same just_audio +
/// just_audio_background pipeline `ZikrAudioPlayer` already uses for
/// recitation - a real foreground media-playback service with its own audio
/// focus and a lock-screen/notification media control - so it survives being
/// backgrounded, and can still be dismissed on purpose from that
/// notification or from [stopIfPlaying].
///
/// On Android, playback is triggered at the exact prayer time by
/// [alarmCallback], scheduled through android_alarm_manager_plus (see
/// [schedule]) - the one mechanism on this platform that can run Dart code
/// at a precise wall-clock time even if the app was never opened. iOS has no
/// equivalent (no background execution at an arbitrary future time without
/// the app already running), so there Full Azan instead starts from
/// [playNow] when the user taps the prayer notification; Custom Audio isn't
/// offered on iOS at all.
class AzanPlaybackService {
  AzanPlaybackService._();

  static const String _stopPortName = 'shia_companion_azan_stop_port';
  static const String _playingPrefKey = 'azan_currently_playing';
  static const String _playingPrayerPrefKey = 'azan_currently_playing_prayer';

  /// Registers android_alarm_manager_plus's own background dispatch. Must
  /// run in the main isolate before any [schedule] call - pairs with
  /// `JustAudioBackground.init` in main.dart. Android-only: there is no
  /// alarm manager to register on iOS/web.
  static Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await AndroidAlarmManager.initialize();
  }

  /// Schedules the actual Azan audio for one prayer notification, alongside
  /// (not instead of) the ordinary local notification banner.
  ///
  /// [alarmId] reuses the id `schedulePrayerTimeNotification` gives that
  /// paired notification - android_alarm_manager_plus keeps an entirely
  /// separate id namespace from flutter_local_notifications, so there is no
  /// collision between the two.
  static Future<void> schedule({
    required int alarmId,
    required DateTime fireTime,
    required String prayerName,
    required bool exact,
    String? customFilePath,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (fireTime.isBefore(DateTime.now())) return;
    await AndroidAlarmManager.oneShotAt(
      fireTime,
      alarmId,
      alarmCallback,
      // Mirrors schedulePrayerTimeNotification's own AndroidScheduleMode
      // choice for the paired notification: `exact` needs the user to have
      // granted the SCHEDULE_EXACT_ALARM special access on Android 12+, and
      // Android throws rather than falling back if it's requested without
      // that - so this always stays a real degrade-gracefully choice, never
      // hardcoded true.
      exact: exact,
      allowWhileIdle: true,
      wakeup: true,
      rescheduleOnReboot: false,
      params: {
        'prayerName': prayerName,
        if (customFilePath != null) 'customFilePath': customFilePath,
      },
    );
  }

  static Future<void> cancel(int alarmId) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await AndroidAlarmManager.cancel(alarmId);
  }

  /// Entry point android_alarm_manager_plus runs, in its own headless
  /// isolate, at the exact prayer time - including when the app was never
  /// opened. Must stay a top-level/static function and keep this pragma: the
  /// plugin looks it up by callback handle after a restart, not by
  /// reference.
  @pragma('vm:entry-point')
  static Future<void> alarmCallback(
      int id, Map<String, dynamic>? params) async {
    WidgetsFlutterBinding.ensureInitialized();
    final prayerName = params?['prayerName'] as String? ?? 'Prayer';
    final customFilePath = params?['customFilePath'] as String?;
    await _startPlayback(prayerName, customFilePath: customFilePath);
  }

  /// Starts the Azan on demand from the running app - the only trigger
  /// available on iOS (fired from a tap on the prayer notification, since
  /// iOS has no background alarm callback), and a replay/preview affordance
  /// on Android.
  ///
  /// [customFilePath] plays that file (the Custom Audio option) in place of
  /// the bundled Full Azan recording - null plays the bundled recording.
  static Future<void> playNow({
    required String prayerName,
    String? customFilePath,
  }) async {
    await _startPlayback(prayerName, customFilePath: customFilePath);
  }

  static AudioPlayer? _activePlayer;
  static ReceivePort? _stopPort;
  static StreamSubscription<PlayerState>? _completionSub;

  static Future<void> _startPlayback(
    String prayerName, {
    String? customFilePath,
  }) async {
    // A stale or duplicate alarm firing while one Azan is still playing must
    // not start overlapping audio.
    if (await isPlaying()) return;

    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.developer110.shia_companion.azan',
        androidNotificationChannelName: 'Azan playback',
        androidNotificationOngoing: true,
      );
    } catch (_) {
      // Already initialized in this isolate - true whenever playNow() runs
      // from the main app, which already called this in main(). The alarm
      // callback isolate is always fresh, so there init is the one that
      // actually takes effect.
    }

    final player = AudioPlayer();
    _activePlayer = player;
    _registerStopPort();
    await _setPlaying(prayerName);

    unawaited(_completionSub?.cancel());
    _completionSub = player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(_stopPlayback());
      }
    });

    // This notification, not the app, is what a reader actually sees at the
    // moment audio starts unprompted - often with the phone locked, having
    // never opened the app. Its title is the one place that can tell them
    // what is happening and that pause/stop is right there, so it reads as a
    // sentence rather than a music-player-style track name.
    final tag = MediaItem(
      id: 'azan-$prayerName',
      title: '$prayerName Azan is playing',
      album: 'Shia Companion',
    );

    try {
      await player.setAudioSource(customFilePath != null
          ? AudioSource.uri(Uri.file(customFilePath), tag: tag)
          : AudioSource.asset('assets/sounds/full_azan.mp3', tag: tag));
      await player.play();
    } catch (e) {
      debugPrint('Azan playback failed: $e');
      await _stopPlayback();
    }
  }

  static void _registerStopPort() {
    IsolateNameServer.removePortNameMapping(_stopPortName);
    final port = ReceivePort();
    _stopPort = port;
    IsolateNameServer.registerPortWithName(port.sendPort, _stopPortName);
    port.listen((message) {
      if (message == 'stop') unawaited(_stopPlayback());
    });
  }

  static Future<void> _stopPlayback() async {
    await _completionSub?.cancel();
    _completionSub = null;
    final player = _activePlayer;
    _activePlayer = null;
    await player?.stop();
    await player?.dispose();
    _stopPort?.close();
    _stopPort = null;
    IsolateNameServer.removePortNameMapping(_stopPortName);
    await _clearPlaying();
  }

  /// Stops whatever Azan is currently playing - the manual dismiss a reader
  /// asked for, on top of the pause/stop control the playback notification
  /// already carries. Works regardless of which isolate started playback
  /// (the alarm callback that starts it is very often not the isolate the
  /// app UI is running in), so the request goes over a named port rather
  /// than a shared Dart object. Falls back to just clearing the "is
  /// playing" flag if that isolate is already gone, so the UI never gets
  /// stuck showing a stop control for audio that in fact stopped on its own.
  static Future<void> stopIfPlaying() async {
    final port = IsolateNameServer.lookupPortByName(_stopPortName);
    if (port != null) {
      port.send('stop');
      return;
    }
    if (_activePlayer != null) {
      await _stopPlayback();
    } else {
      await _clearPlaying();
    }
  }

  // Both reload() first: SharedPreferences.getInstance() is a singleton
  // cached in memory per isolate, and playback is usually started by a
  // *different* isolate than the one asking (the alarm callback vs. the app
  // UI). Without a reload, this isolate's cache would just keep answering
  // with whatever it last saw of its own, never picking up the other
  // isolate's write to the same underlying native store.
  static Future<bool> isPlaying() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_playingPrefKey) ?? false;
  }

  static Future<String?> currentPrayerName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_playingPrayerPrefKey);
  }

  static Future<void> _setPlaying(String prayerName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_playingPrefKey, true);
    await prefs.setString(_playingPrayerPrefKey, prayerName);
  }

  static Future<void> _clearPlaying() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_playingPrefKey, false);
    await prefs.remove(_playingPrayerPrefKey);
  }
}
