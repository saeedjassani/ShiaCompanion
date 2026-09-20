import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Turns recited Arabic heard through the microphone into text, for
/// [matchRecitation] to identify.
///
/// Behind an interface on purpose. The speech engine is the replaceable half of
/// "listen and follow": the OS recogniser ships first because it is free and
/// adds no download, but it is trained on conversational Arabic and will
/// struggle with tajweed. If the numbers this feature reports say so, the
/// upgrade is a Quran-tuned Whisper running on-device, and it lands here -
/// [VerseMatch], the matcher and the sheet all stay as they are.

/// Why listening cannot start, or that it can.
enum RecognizerAvailability {
  ready,

  /// The microphone was refused. Recoverable only in Settings.
  permissionDenied,

  /// No speech recogniser on the device at all - a Google-less Android build,
  /// or a platform the plugin does not cover.
  unsupported,

  /// There is a recogniser, but it does not speak Arabic.
  noArabicLocale,

  /// Initialising the engine failed for some other reason.
  failed,
}

/// One transcript, partial or settled.
@immutable
class RecitationTranscript {
  const RecitationTranscript({
    required this.text,
    required this.isFinal,
    this.confidence,
  });

  final String text;

  /// Whether the engine considers this its answer rather than a guess in
  /// progress.
  final bool isFinal;

  /// The engine's own confidence, where it reports one. Not used for matching -
  /// the matcher's own scoring is the judge - but worth recording.
  final double? confidence;
}

abstract class RecitationRecognizer {
  /// Asks for whatever the engine needs - permission, an Arabic locale - and
  /// says whether listening is possible.
  Future<RecognizerAvailability> ensureAvailable();

  /// Listens, emitting transcripts as they firm up, and closes when the engine
  /// stops or [stop] is called.
  Stream<RecitationTranscript> listen();

  Future<void> stop();

  /// Whether the last session ran without a network round trip. Recorded
  /// because on-device and server recognition differ in accuracy, and mixing
  /// the two would make the measurements unreadable.
  bool get ranOnDevice;
}

/// How long to listen for, and how much silence ends it.
///
/// Both deliberately generous. Recognition accuracy on recitation rises sharply
/// with clip length - published work has the same model at 0.70 WER on ten-second
/// clips and 0.075 on thirty - and a reciter pausing for breath at the end of an
/// ayah is not finished speaking.
const Duration _listenFor = Duration(seconds: 20);
const Duration _pauseFor = Duration(seconds: 3);

class OsSpeechRecitationRecognizer implements RecitationRecognizer {
  OsSpeechRecitationRecognizer._();

  static final OsSpeechRecitationRecognizer instance =
      OsSpeechRecitationRecognizer._();

  final SpeechToText _speech = SpeechToText();

  bool _initialized = false;
  String? _arabicLocaleId;
  bool _ranOnDevice = false;
  StreamController<RecitationTranscript>? _controller;

  @override
  bool get ranOnDevice => _ranOnDevice;

  @override
  Future<RecognizerAvailability> ensureAvailable() async {
    try {
      if (!_initialized) {
        _initialized = await _speech.initialize(
          onError: _onError,
          onStatus: _onStatus,
        );
      }
    } catch (error) {
      debugPrint('RecitationRecognizer: initialize failed: $error');
      return RecognizerAvailability.failed;
    }

    if (!_initialized) {
      // The plugin folds "no recogniser" and "permission refused" into the same
      // false, so the permission flag is what tells them apart.
      final permitted = await _speech.hasPermission;
      return permitted
          ? RecognizerAvailability.unsupported
          : RecognizerAvailability.permissionDenied;
    }

    _arabicLocaleId ??= await _findArabicLocale();
    if (_arabicLocaleId == null) return RecognizerAvailability.noArabicLocale;

    return RecognizerAvailability.ready;
  }

  /// The best Arabic locale the device offers.
  ///
  /// `ar-SA` first because it is the variety closest to what is being recited,
  /// then any Arabic at all - a device set up for Arabic anywhere still
  /// recognises Quranic vocabulary far better than a fallback to English would.
  Future<String?> _findArabicLocale() async {
    try {
      final locales = await _speech.locales();
      if (locales.isEmpty) return null;

      for (final locale in locales) {
        final id = locale.localeId.toLowerCase().replaceAll('-', '_');
        if (id == 'ar_sa') return locale.localeId;
      }
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase();
        if (id == 'ar' || id.startsWith('ar_') || id.startsWith('ar-')) {
          return locale.localeId;
        }
      }
    } catch (error) {
      debugPrint('RecitationRecognizer: could not read locales: $error');
    }
    return null;
  }

  @override
  Stream<RecitationTranscript> listen() {
    // One session at a time: a second tap replaces the first rather than
    // stacking two recognisers on one microphone.
    _controller?.close();

    final controller = StreamController<RecitationTranscript>(
      onCancel: () => _speech.cancel(),
    );
    _controller = controller;
    _sawResult = false;
    _fellBack = false;

    _startListening(onDevice: true);
    return controller.stream;
  }

  bool _sawResult = false;

  /// Whether the networked engine has already been tried, so the fallback
  /// happens once and a silent session ends rather than looping.
  bool _fellBack = false;

  /// Whether a session is being wired up right now. The engine reports the old
  /// session ending while the new one is starting, and that report must not be
  /// mistaken for the new session finishing.
  bool _restarting = false;

  /// Starts the engine, preferring recognition that needs no network.
  ///
  /// On-device Arabic works only where the user has installed that language
  /// pack, which the app cannot do for them, so a refusal falls back to the
  /// networked recogniser rather than failing the feature.
  Future<void> _startListening({required bool onDevice}) async {
    _ranOnDevice = onDevice;
    if (!onDevice) _fellBack = true;
    _restarting = true;

    try {
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: _arabicLocaleId,
          partialResults: true,
          onDevice: onDevice,
          // Dictation, not confirmation: a continuous stretch of speech that
          // should not be cut off at the first plausible phrase.
          listenMode: ListenMode.dictation,
          listenFor: _listenFor,
          pauseFor: _pauseFor,
          cancelOnError: true,
        ),
      );
      _restarting = false;
    } catch (error) {
      _restarting = false;
      if (onDevice && !_fellBack) {
        await _startListening(onDevice: false);
        return;
      }
      _fail(error.toString());
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    _sawResult = true;
    final controller = _controller;
    if (controller == null || controller.isClosed) return;

    controller.add(RecitationTranscript(
      text: result.recognizedWords,
      isFinal: result.finalResult,
      confidence: result.hasConfidenceRating ? result.confidence : null,
    ));

    if (result.finalResult) controller.close();
  }

  void _onError(SpeechRecognitionError error) {
    // An on-device engine that cannot serve Arabic reports it as an error once
    // listening has already begun, so the fallback also has to live here.
    if (_shouldFallBack) {
      _startListening(onDevice: false);
      return;
    }
    _fail(error.errorMsg);
  }

  void _onStatus(String status) {
    if (status != SpeechToText.doneStatus &&
        status != SpeechToText.notListeningStatus) {
      return;
    }
    // The old session's ending, arriving while the replacement is being set up.
    if (_restarting) return;

    // An on-device session that heard nothing is indistinguishable from one
    // that could not serve Arabic, so it gets the same fallback as an outright
    // error rather than being reported as silence.
    if (_shouldFallBack) {
      _startListening(onDevice: false);
      return;
    }

    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    // The engine can finish without a final result - all silence, or a stop
    // while the transcript was still partial. Closing lets the sheet act on
    // whatever it has rather than waiting for a result that is not coming.
    controller.close();
  }

  /// Whether the networked engine is still worth a try: the on-device one was
  /// asked, produced nothing, and has not already been fallen back from.
  bool get _shouldFallBack => _ranOnDevice && !_sawResult && !_fellBack;

  void _fail(String message) {
    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    controller.addError(RecitationRecognizerException(message));
    controller.close();
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (error) {
      debugPrint('RecitationRecognizer: stop failed: $error');
    }
    final controller = _controller;
    if (controller != null && !controller.isClosed) await controller.close();
  }
}

class RecitationRecognizerException implements Exception {
  const RecitationRecognizerException(this.message);

  final String message;

  @override
  String toString() => 'RecitationRecognizerException: $message';
}
