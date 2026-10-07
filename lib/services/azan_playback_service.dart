import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:isolate';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/l10n.dart';
import 'exclusive_audio.dart';

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
///
/// The class needs its own entry-point pragma, not just [alarmCallback]: in a
/// release (AOT) build the alarm plugin can't reach a static method of a class
/// that isn't itself annotated, and the Azan silently never starts.
@pragma('vm:entry-point')
class AzanPlaybackService {
  AzanPlaybackService._();

  static const String _stopPortName = 'shia_companion_azan_stop_port';
  static const String _playingPrefKey = 'azan_currently_playing';
  static const String _playingPrayerPrefKey = 'azan_currently_playing_prayer';
  static const String _pausedPrefKey = 'azan_currently_paused';

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

  static const MethodChannel _alarmsChannel =
      MethodChannel('shia_companion/azan_alarms');

  /// Whether Android still holds a scheduled alarm for any of [alarmIds].
  ///
  /// A force-stop or reboot deletes these alarms while flutter_local_notifications
  /// keeps its own record of the paired notifications, so that record alone
  /// can't say whether the Azan will actually play. Answers true when it can't
  /// tell, so a failed check never turns into rescheduling on every launch.
  static Future<bool> isAnyScheduled(List<int> alarmIds) async {
    if (kIsWeb || !Platform.isAndroid || alarmIds.isEmpty) return true;
    try {
      return await _alarmsChannel.invokeMethod<bool>('anyScheduled', alarmIds) ??
          true;
    } catch (e) {
      debugPrint('Could not check Azan alarms: $e');
      return true;
    }
  }

  /// Entry point android_alarm_manager_plus runs, in its own headless
  /// isolate, at the exact prayer time - including when the app was never
  /// opened. Must stay a top-level/static function and keep this pragma: the
  /// plugin looks it up by callback handle after a restart, not by
  /// reference.
  /// Per isolate, like every static: set once [alarmCallback] has initialised
  /// background audio in the alarm isolate.
  static bool _alarmIsolateAudioReady = false;

  @pragma('vm:entry-point')
  static Future<void> alarmCallback(
      int id, Map<String, dynamic>? params) async {
    WidgetsFlutterBinding.ensureInitialized();
    // android_alarm_manager_plus runs this headless, in its own isolate where
    // main()'s JustAudioBackground.init() never ran - but it keeps that
    // isolate alive and reuses it for every later alarm while the process
    // lives, so this must run once per isolate, not once per Azan. A second
    // init() wraps the plugin around itself and every Azan after the first
    // fails with "supports only a single player instance". [playNow] never
    // needs this: it only ever runs in the main isolate, where main() already
    // did it once - see the crash note on [_startPlayback].
    if (!_alarmIsolateAudioReady) {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.developer110.shia_companion.azan',
        androidNotificationChannelName: 'Azan playback',
        androidNotificationOngoing: true,
      );
      _alarmIsolateAudioReady = true;
    }
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

  /// Set while [_startPlayback] waits for another player to let go, so a
  /// second request in that gap cannot start a second Azan.
  static bool _starting = false;

  /// What [ExclusiveAudio] knows the Azan's claim by.
  static final Object _audioOwner = Object();
  static ReceivePort? _stopPort;
  static StreamSubscription<PlayerState>? _completionSub;

  static Future<void> _startPlayback(
    String prayerName, {
    String? customFilePath,
  }) async {
    // A stale or duplicate alarm firing while one Azan is still playing must
    // not start overlapping audio. This checks for a live player, never the
    // persisted flag [isPlaying] reads: that flag outlives the process, so an
    // Azan cut short by the app being killed (swiped away, or reclaimed by
    // iOS) left it stuck at true and every later tap on a prayer
    // notification silently did nothing.
    if (_starting) return;
    final existing = _activePlayer;
    if (existing != null) {
      // One this isolate started but that is now paused (e.g. from the
      // lock-screen control) or finished is not a reason to ignore an
      // explicit request to play - replace it.
      if (existing.playing &&
          existing.processingState != ProcessingState.completed) {
        return;
      }
      await _stopPlayback();
    } else if (IsolateNameServer.lookupPortByName(_stopPortName) != null) {
      // Another isolate (Android's alarm callback) is playing right now.
      return;
    }

    // JustAudioBackground.init() must never run a second time in an isolate
    // that already called it - on iOS this isn't a catchable Dart exception
    // but a native crash, which previously took the whole app down the
    // instant a reader tapped a prayer notification or a sound preview
    // (playNow's only callers), since main() already initializes it before
    // runApp(). The alarm-callback isolate is the one place that genuinely
    // needs its own call - see [alarmCallback], Android-only and always a
    // fresh isolate.
    //
    // The same single player slot is why this claims the audio first: a
    // recitation player that is still alive - a playlist that finished or
    // was paused, a zikr with Listen open - made the Azan's player throw
    // "supports only a single player instance" on load, so a tap on the
    // prayer notification played nothing. On iOS, where the app is
    // suspended rather than closed, such a player can sit there for hours.
    // The Azan is what the reader asked for, so the recitation stops.
    _starting = true;
    try {
      await ExclusiveAudio.claim(_audioOwner, _stopPlayback);
    } catch (e) {
      debugPrint('Could not stop the other player for the Azan: $e');
    } finally {
      _starting = false;
    }
    final player = AudioPlayer();
    _activePlayer = player;
    _registerStopPort();
    await _setPlaying(prayerName);

    // Stopping the Azan player from its notification, or swiping it away,
    // never completes this player: just_audio_background releases the native
    // player underneath it, whose last word is an `idle` event. Listening for
    // `completed` alone left the stop port and the "is playing" flag behind,
    // so the app kept showing a Stop banner for an Azan that had already gone
    // quiet. A pause is just a pause - the player stays ready to resume, and
    // a separate flag lets the banner offer Resume instead of pretending the
    // Azan is still audible.
    var started = false;
    bool? lastPlaying;
    unawaited(_completionSub?.cancel());
    _completionSub = player.playerStateStream.listen((state) {
      final processing = state.processingState;
      if (processing == ProcessingState.completed ||
          (started && processing == ProcessingState.idle)) {
        unawaited(_stopPlayback());
        return;
      }
      if (state.playing && processing != ProcessingState.idle) started = true;
      if (!started || state.playing == lastPlaying) return;
      lastPlaying = state.playing;
      unawaited(_setPaused(!state.playing));
    });

    // This notification, not the app, is what a reader actually sees at the
    // moment audio starts unprompted - often with the phone locked, having
    // never opened the app. Its title is the one place that can tell them
    // what is happening and that pause/stop is right there, so it reads as a
    // sentence rather than a music-player-style track name.
    final tag = MediaItem(
      id: 'azan-$prayerName',
      title: L10n.current.azanPlaying(localizedPrayerName(prayerName)),
      album: 'Shia Companion',
    );

    // The prayer notification is deliberately silent (this player is the
    // sound), so a custom file that has since disappeared - deleted, or an
    // older pick that still points into a cache Android has cleared - must
    // not leave the reader with nothing. The bundled Azan is the next best.
    if (customFilePath != null && !File(customFilePath).existsSync()) {
      debugPrint('Custom Azan file missing, playing the bundled one instead');
      customFilePath = null;
    }

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
      if (message == 'resume') _resumeActive();
    });
  }

  static Future<void> _stopPlayback() async {
    await _completionSub?.cancel();
    _completionSub = null;
    final player = _activePlayer;
    _activePlayer = null;
    ExclusiveAudio.relinquish(_audioOwner);
    // The shared state goes first: when the notification already stopped
    // the native player, tearing down this wrapper is best-effort and must
    // not be able to leave the UI showing a Stop control.
    _stopPort?.close();
    _stopPort = null;
    IsolateNameServer.removePortNameMapping(_stopPortName);
    await _clearPlaying();
    try {
      // dispose() also releases just_audio_background's single player slot,
      // without which the next Azan in this isolate could never start.
      await player?.stop().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Azan player stop failed: $e');
    }
    try {
      await player?.dispose().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Azan player dispose failed: $e');
    }
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
      // The stop lands in the playing isolate asynchronously; clear the flag
      // now so the banner hides at once rather than on its next poll. That
      // isolate's own _stopPlayback clears it again - harmless.
      await _clearPlaying();
      return;
    }
    if (_activePlayer != null) {
      await _stopPlayback();
    } else {
      await _clearPlaying();
    }
  }

  /// Resumes an Azan paused from its notification, in whichever isolate is
  /// holding it - see [stopIfPlaying] for why this goes over a named port.
  static Future<void> resumeIfPaused() async {
    final port = IsolateNameServer.lookupPortByName(_stopPortName);
    if (port != null) {
      port.send('resume');
      return;
    }
    _resumeActive();
  }

  static void _resumeActive() {
    final player = _activePlayer;
    if (player == null || player.playing) return;
    // Unawaited: play()'s future only completes when playback stops again.
    unawaited(player.play());
  }

  // Both reload() first: SharedPreferences.getInstance() is a singleton
  // cached in memory per isolate, and playback is usually started by a
  // *different* isolate than the one asking (the alarm callback vs. the app
  // UI). Without a reload, this isolate's cache would just keep answering
  // with whatever it last saw of its own, never picking up the other
  // isolate's write to the same underlying native store.
  //
  // The flag alone can also be stale - left true by an Azan whose process
  // was killed mid-playback. Whichever isolate is really playing always has
  // [_stopPortName] registered, and that registration dies with the process,
  // so a true flag with no port behind it is cleared rather than believed.
  static Future<bool> isPlaying() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final flagged = prefs.getBool(_playingPrefKey) ?? false;
    if (!flagged) return false;
    if (IsolateNameServer.lookupPortByName(_stopPortName) == null) {
      await _clearPlaying();
      return false;
    }
    return true;
  }

  /// Whether the Azan [isPlaying] reports is currently paused rather than
  /// audible - only meaningful while [isPlaying] is true.
  static Future<bool> isPaused() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_pausedPrefKey) ?? false;
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
    await prefs.setBool(_pausedPrefKey, false);
  }

  static Future<void> _setPaused(bool paused) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pausedPrefKey, paused);
  }

  static Future<void> _clearPlaying() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_playingPrefKey, false);
    await prefs.remove(_playingPrayerPrefKey);
    await prefs.remove(_pausedPrefKey);
  }
}
