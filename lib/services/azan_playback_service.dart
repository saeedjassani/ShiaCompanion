import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/l10n.dart';
import 'exclusive_audio.dart';

/// One Full Azan / Custom Audio alarm, as Android's native player takes it.
///
/// [id] is the paired prayer notification's id, so the two are replaced and
/// cancelled together.
@immutable
class AzanAlarm {
  const AzanAlarm({
    required this.id,
    required this.fireTime,
    required this.prayerName,
    this.customFilePath,
  });

  final int id;
  final DateTime fireTime;

  /// The prayer's key (e.g. `Zuhr`), not its localized name.
  final String prayerName;
  final String? customFilePath;

  Map<String, Object?> toChannelMap() => {
        'id': id,
        'fireAtMillis': fireTime.millisecondsSinceEpoch,
        'prayerName': prayerName,
        ..._titles(prayerName),
        'customFilePath': customFilePath,
      };
}

/// Plays the full Azan - or, on Android, a user's Custom Audio choice - as
/// real, app-controlled audio rather than a plain notification sound.
///
/// A notification's `sound:` field is a short OS ringtone: any other
/// notification, an incoming call, or the user simply touching the phone can
/// cut it off, and there is no player behind it to resume or stop. This plays
/// the recording through a real foreground media-playback service with its
/// own audio focus and a notification to pause or stop it, so it survives
/// being backgrounded, and can still be dismissed on purpose from that
/// notification or from [stopIfPlaying].
///
/// On Android, playback and its schedule are native (AzanPlayerService and
/// AzanSchedule in the app's Kotlin): an alarm at the exact prayer time
/// starts the player without starting Flutter at all. It used to run Dart in
/// an android_alarm_manager_plus isolate, which also woke audio_service's
/// cached engine - running the app's main() headless, where it hung behind
/// the alarm's own audio setup, so opening the app during an Azan stuck on
/// the splash screen and Android reported the app as not responding.
///
/// iOS has no equivalent (no background execution at an arbitrary future
/// time without the app already running), so there Full Azan instead starts
/// from [playNow] when the user taps the prayer notification, through
/// just_audio in this isolate; Custom Audio isn't offered on iOS at all.
class AzanPlaybackService {
  AzanPlaybackService._();

  static const String _stopPortName = 'shia_companion_azan_stop_port';
  static const String _playingPrefKey = 'azan_currently_playing';
  static const String _playingPrayerPrefKey = 'azan_currently_playing_prayer';
  static const String _pausedPrefKey = 'azan_currently_paused';

  static const MethodChannel _channel = MethodChannel('shia_companion/azan');

  static bool get _isNative => !kIsWeb && Platform.isAndroid;

  /// Listens for the native player starting and stopping on its own (an
  /// alarm, the notification's Stop), so a recitation playing at the same
  /// time stops for the Azan, and starting one later stops the Azan - the
  /// same hand-over [ExclusiveAudio] gives every other player. Android only;
  /// call once from main().
  static void initialize() {
    if (!_isNative) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'stateChanged') return;
      final playing = (call.arguments as Map?)?['playing'] == true;
      if (playing) {
        if (!ExclusiveAudio.isOwnedBy(_audioOwner)) {
          await ExclusiveAudio.claim(_audioOwner, _stopNative);
        }
      } else {
        ExclusiveAudio.relinquish(_audioOwner);
      }
    });
  }

  /// Replaces Android's whole Azan schedule with [alarms]: any alarm not in
  /// it is cancelled, so one can never outlive the schedule that made it.
  static Future<void> replaceSchedule(List<AzanAlarm> alarms) async {
    if (!_isNative) return;
    await _channel.invokeMethod<void>('replaceSchedule', {
      'alarms': [for (final alarm in alarms) alarm.toChannelMap()],
      'labels': _labels(),
    });
  }

  /// Cancels every scheduled Azan, including any android_alarm_manager_plus
  /// armed for [legacyIds] before native playback replaced it.
  static Future<void> clearSchedule({required List<int> legacyIds}) async {
    if (!_isNative) return;
    await _invoke('clearSchedule', {'legacyIds': legacyIds});
  }

  /// Re-arms the stored schedule. Android drops every alarm on a force-stop
  /// (and on a revoked exact-alarm permission) without telling the app, so
  /// this runs at every launch; arming an alarm that already exists is
  /// harmless.
  static Future<void> rearm() async {
    if (!_isNative) return;
    await _invoke('rearm');
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
    if (_isNative) {
      // A recitation still playing stops for the Azan the reader asked for.
      try {
        await ExclusiveAudio.claim(_audioOwner, _stopNative);
      } catch (e) {
        debugPrint('Could not stop the other player for the Azan: $e');
      }
      await _invoke('play', {
        'prayerName': prayerName,
        ..._titles(prayerName),
        'customFilePath': customFilePath,
        'labels': _labels(),
      });
      return;
    }
    await _startPlayback(prayerName, customFilePath: customFilePath);
  }

  static Future<void> _stopNative() => _invoke('stop');

  /// Calls the native player, logging rather than throwing when it can't be
  /// reached - from an engine without the activity (audio_service's, run
  /// headless) the channel isn't registered. Only [replaceSchedule] lets
  /// failures through, so its caller knows to try again.
  static Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      debugPrint('Native Azan unavailable for $method');
    } on PlatformException catch (e) {
      debugPrint('Native Azan $method failed: $e');
    }
    return null;
  }

  static Map<String, String> _labels() => {
        'pause': L10n.current.commonPause,
        'resume': L10n.current.playlistResume,
        'stop': L10n.current.commonStop,
        'channel': L10n.current.notificationChannelAzanPlayback,
      };

  static Future<Map<Object?, Object?>> _nativeState() async =>
      await _invoke<Map<Object?, Object?>>('state') ?? const {};

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
    // A duplicate request while one Azan is still playing must
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
    } else if (_playingPort() != null) {
      // Another isolate is playing right now.
      return;
    }

    // just_audio_background's single player slot is why this claims the
    // audio first: a
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

  /// The port of whichever isolate is playing, or null when none is. Web has
  /// a single isolate and no [IsolateNameServer], so there it is always null
  /// and callers fall back to this isolate's own player.
  static SendPort? _playingPort() =>
      kIsWeb ? null : IsolateNameServer.lookupPortByName(_stopPortName);

  static void _registerStopPort() {
    if (kIsWeb) return;
    IsolateNameServer.removePortNameMapping(_stopPortName);
    final port = ReceivePort();
    _stopPort = port;
    IsolateNameServer.registerPortWithName(port.sendPort, _stopPortName);
    port.listen((message) {
      if (message == 'stop') unawaited(_stopPlayback());
      if (message == 'resume') _resumeActive();
      if (message == 'pause') unawaited(_activePlayer?.pause());
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
    if (!kIsWeb) IsolateNameServer.removePortNameMapping(_stopPortName);
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
  /// already carries. On Android that is the native player. Elsewhere the
  /// request goes over a named port, so it reaches whichever isolate started
  /// playback, and falls back to just clearing the "is playing" flag if that
  /// isolate is already gone, so the UI never gets stuck showing a stop
  /// control for audio that in fact stopped on its own.
  static Future<void> stopIfPlaying() async {
    if (_isNative) return _stopNative();
    final port = _playingPort();
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

  /// Pauses the Azan, in whichever isolate is holding it.
  static Future<void> pauseIfPlaying() async {
    if (_isNative) return _invoke('pause');
    final port = _playingPort();
    if (port != null) {
      port.send('pause');
      return;
    }
    await _activePlayer?.pause();
  }

  /// Resumes an Azan paused from its notification, in whichever isolate is
  /// holding it - see [stopIfPlaying] for why this goes over a named port.
  static Future<void> resumeIfPaused() async {
    if (_isNative) return _invoke('resume');
    final port = _playingPort();
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

  // On Android the native player answers these directly. Elsewhere they
  // reload() first: SharedPreferences.getInstance() is a singleton cached in
  // memory per isolate, so without a reload an isolate that didn't start
  // playback would keep answering with whatever it last saw of its own.
  //
  // The flag alone can also be stale - left true by an Azan whose process
  // was killed mid-playback. Whichever isolate is really playing always has
  // [_stopPortName] registered, and that registration dies with the process,
  // so a true flag with no port behind it is cleared rather than believed.
  static Future<bool> isPlaying() async {
    if (_isNative) return (await _nativeState())['playing'] == true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final flagged = prefs.getBool(_playingPrefKey) ?? false;
    if (!flagged) return false;
    if (_playingPort() == null && _activePlayer == null) {
      await _clearPlaying();
      return false;
    }
    return true;
  }

  /// Whether the Azan [isPlaying] reports is currently paused rather than
  /// audible - only meaningful while [isPlaying] is true.
  static Future<bool> isPaused() async {
    if (_isNative) return (await _nativeState())['paused'] == true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_pausedPrefKey) ?? false;
  }

  static Future<String?> currentPrayerName() async {
    if (_isNative) return (await _nativeState())['prayerName'] as String?;
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

/// The playback notification's title while the Azan for [prayerName] plays
/// and while it is paused, in the reader's language.
Map<String, String> _titles(String prayerName) {
  final name = localizedPrayerName(prayerName);
  return {
    'title': L10n.current.azanPlaying(name),
    'pausedTitle': L10n.current.azanPaused(name),
  };
}
