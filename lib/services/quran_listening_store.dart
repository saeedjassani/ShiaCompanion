import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/quran_listening.dart';
import '../utils/shared_preferences.dart';

/// Where the reader is in listening through the Quran a portion a day -
/// [QuranListeningState] - kept on this device under one key, like the
/// playlists that play it.
class QuranListeningStore extends ChangeNotifier {
  QuranListeningStore._();

  static final QuranListeningStore instance = QuranListeningStore._();

  static const String storageKey = 'quran_listening_v1';

  /// The clock: what "today" is. Tests set their own.
  DateTime Function() now = DateTime.now;

  QuranListeningState? _state;

  /// The state as of today: a new day has its count started afresh.
  QuranListeningState get state => (_state ??= _read()).forDay(now());

  @visibleForTesting
  void resetForTest() => _state = null;

  QuranListeningState _read() {
    if (!SP.isInitialized) return const QuranListeningState();
    final encoded = SP.prefs.getString(storageKey);
    if (encoded == null || encoded.isEmpty) return const QuranListeningState();
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        return QuranListeningState.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (error) {
      debugPrint('Unable to read Quran listening: $error');
    }
    return const QuranListeningState();
  }

  /// Applies [edit] to today's state and saves it.
  void update(
    QuranListeningState Function(QuranListeningState state) edit,
  ) {
    final before = state;
    final next = edit(before);
    if (next == _state) return;
    _state = next;
    notifyListeners();
    if (!SP.isInitialized) return;
    unawaited(SP.prefs.setString(storageKey, jsonEncode(next.toJson())));
  }

  void recordPlayback({
    required int playing,
    Duration listened = Duration.zero,
    int? finished,
  }) => update(
    (state) => state.recordPlayback(
      playing: playing,
      listened: listened,
      finished: finished,
      now: now(),
    ),
  );

  void markGoalMet() => update((state) => state.markGoalMet());

  void startAt(int ordinal) =>
      update((state) => state.startingAt(ordinal, now()));

  void setGoal(QuranListeningGoal goal) =>
      update((state) => state.withGoal(goal, now()));
}
