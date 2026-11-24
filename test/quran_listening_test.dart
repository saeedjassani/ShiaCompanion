import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/models/quran_listening.dart';
import 'package:shia_companion/models/zikr_audio_track.dart';
import 'package:shia_companion/services/playlist_audio_service.dart';
import 'package:shia_companion/services/quran_listening_store.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

void main() {
  final monday = DateTime(2026, 11, 23, 9);
  final tuesday = DateTime(2026, 11, 24, 9);

  group('verse audio', () {
    test('names a verse by its zero-padded surah and ayah', () {
      expect(
        quranVerseAudioUrl(2, 255),
        '${zikrAudioBaseUrl}quran-ayah/parhizkar/002255.mp3',
      );
      expect(quranVerseAudioUrl(1, 1), endsWith('/001001.mp3'));
      expect(quranVerseTrack(114, 6).reciter, quranVerseReciter);
    });

    test('a position across the Quran and a verse map onto each other', () {
      expect(quranVerseTotal, 6236);
      expect(verseAtOrdinal(1), const VerseKey(1, 1));
      expect(verseAtOrdinal(8), const VerseKey(2, 1));
      expect(verseAtOrdinal(quranVerseTotal), const VerseKey(114, 6));
      for (final ordinal in [1, 7, 8, 148, 149, 3000, 6230, 6236]) {
        expect(ordinalOfVerse(verseAtOrdinal(ordinal)), ordinal);
      }
      expect(verseAtOrdinal(0), const VerseKey(1, 1), reason: 'clamped');
      expect(verseAtOrdinal(99999), const VerseKey(114, 6));
    });
  });

  group('a juz a day', () {
    // Juz 1 is 1:1-2:141 (positions 1-148); juz 2 starts at 2:142.
    test('runs to the end of the juz it starts in', () {
      expect(juzPortionEnd(1), 148);
      expect(juzPortionEnd(100), 148);
    });

    test('starting near the end of a juz runs on through the next', () {
      final juz2End = ordinalOfVerse(allJuz()[1].end);
      expect(juzPortionEnd(140), juz2End);
    });

    test('the last juz ends at an-Nas', () {
      expect(juzPortionEnd(quranVerseTotal - 2), quranVerseTotal);
    });
  });

  group('QuranListeningState', () {
    test('a new day starts its count afresh from where the last stopped', () {
      final yesterday = const QuranListeningState()
          .recordPlayback(
            playing: 50,
            listened: const Duration(minutes: 16),
            now: monday,
          )
          .markGoalMet();
      expect(yesterday.secondsToday, 16 * 60);
      expect(yesterday.goalMetToday, isTrue);

      final today = yesterday.forDay(tuesday);
      expect(today.day, listeningDayKey(tuesday));
      expect(today.secondsToday, 0);
      expect(today.goalMetToday, isFalse);
      expect(today.dayStart, 50);
      expect(today.next, 50);
    });

    test('counts a day listened once, however many times it plays', () {
      var state = const QuranListeningState();
      for (var i = 0; i < 3; i++) {
        state = state.recordPlayback(
          playing: 10 + i,
          listened: const Duration(seconds: 30),
          now: monday,
        );
      }
      expect(state.daysListened, 1);
      state = state.recordPlayback(
        playing: 20,
        listened: const Duration(seconds: 30),
        now: tuesday,
      );
      expect(state.daysListened, 2);
    });

    test('moving the place without listening is not a day listened', () {
      final state = const QuranListeningState().recordPlayback(
        playing: 30,
        now: monday,
      );
      expect(state.next, 30);
      expect(state.daysListened, 0);
    });

    test('finishing an-Nas is a khatm', () {
      final state = const QuranListeningState(next: quranVerseTotalForTest)
          .recordPlayback(playing: 1, finished: quranVerseTotal, now: monday);
      expect(state.khatms, 1);
      expect(state.next, 1);
    });

    test('a time goal is reached once its minutes are listened', () {
      var state = const QuranListeningState().forDay(monday);
      state = state.recordPlayback(
        playing: 5,
        listened: const Duration(minutes: 14),
        now: monday,
      );
      expect(state.goalReachedAt(6), isFalse);
      state = state.recordPlayback(
        playing: 6,
        listened: const Duration(minutes: 1),
        now: monday,
      );
      expect(state.goalReachedAt(7), isTrue);
      expect(
        state.markGoalMet().goalReachedAt(8),
        isFalse,
        reason: 'today does not stop twice',
      );
      expect(state.minutesProgress(monday), 1);
    });

    test('a juz goal is reached past its portion, or on wrapping round', () {
      final state = const QuranListeningState().withGoal(
        QuranListeningGoal.oneJuz,
        monday,
      );
      expect(state.dayEnd, 148);
      expect(state.goalReachedAt(148), isFalse);
      expect(state.goalReachedAt(149), isTrue);

      final late = state.startingAt(quranVerseTotal - 2, monday);
      expect(late.dayEnd, quranVerseTotal);
      expect(late.goalReachedAt(1), isTrue, reason: 'wrapped to al-Fatihah');
      expect(state.minutesProgress(monday), isNull);
    });

    test('no daily limit never stops', () {
      final state = const QuranListeningState()
          .withGoal(QuranListeningGoal.open, monday)
          .recordPlayback(
            playing: 10,
            listened: const Duration(hours: 3),
            now: monday,
          );
      expect(state.goalReachedAt(11), isFalse);
    });

    test('changing the goal after meeting it starts it over', () {
      final state = const QuranListeningState()
          .forDay(monday)
          .markGoalMet()
          .withGoal(QuranListeningGoal.oneJuz, monday);
      expect(state.goalMetToday, isFalse);
      expect(state.goal, QuranListeningGoal.oneJuz);
    });

    test('survives JSON, and clamps what it cannot trust', () {
      final state = const QuranListeningState()
          .withGoal(QuranListeningGoal.oneJuz, monday)
          .recordPlayback(
            playing: 200,
            listened: const Duration(minutes: 3),
            now: monday,
          );
      expect(QuranListeningState.fromJson(state.toJson()), state);

      final odd = QuranListeningState.fromJson({
        'next': 999999,
        'goal': 'nonsense',
        'secondsToday': -4,
        'dayStart': 'x',
      });
      expect(odd.next, quranVerseTotal);
      expect(odd.goal, QuranListeningGoal.standard);
      expect(odd.secondsToday, 0);
      expect(odd.dayStart, 1);
    });
  });

  group('QuranListeningStore', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SP.init();
      QuranListeningStore.instance.now = () => monday;
      QuranListeningStore.instance.resetForTest();
    });

    tearDown(() => QuranListeningStore.instance.now = DateTime.now);

    test('keeps the place and goal across a reload', () {
      final store = QuranListeningStore.instance
        ..setGoal(QuranListeningGoal.oneJuz)
        ..recordPlayback(playing: 300, listened: const Duration(minutes: 2));
      final saved = jsonDecode(
        SP.prefs.getString(QuranListeningStore.storageKey)!,
      );
      expect(saved['next'], 300);

      store.resetForTest();
      expect(store.state.next, 300);
      expect(store.state.goal, QuranListeningGoal.oneJuz);
      expect(store.state.secondsToday, 120);

      store.now = () => tuesday;
      expect(store.state.secondsToday, 0, reason: 'a new day');
      expect(store.state.next, 300);
    });

    test('unreadable storage starts at al-Fatihah', () async {
      SharedPreferences.setMockInitialValues({
        QuranListeningStore.storageKey: 'not json',
      });
      await SP.init();
      QuranListeningStore.instance.resetForTest();
      expect(QuranListeningStore.instance.state.next, 1);
    });
  });

  group('the day-by-day queue', () {
    test('a playlist turns its daily item into verses from the place', () {
      final queue = PlaylistAudioService.buildQueue(
        ['E18', quranDailyUid, 'G4'],
        tracksFor: (uid) => [ZikrAudioTrack(url: '$uid.mp3')],
        titleFor: (uid) => uid,
        dailyQuran: () => PlaylistAudioService.dailyVerses(8, count: 3),
      );
      expect(queue.map((entry) => entry.zikrUid), [
        'E18',
        quranDailyUid,
        quranDailyUid,
        quranDailyUid,
        'G4',
      ]);
      expect(queue[1].verse, const VerseKey(2, 1));
      expect(queue[1].daily, isTrue);
      expect(queue[1].track.url, endsWith('/002001.mp3'));
      expect(queue.first.verse, isNull);
    });

    test('a window stops at an-Nas', () {
      final verses = PlaylistAudioService.dailyVerses(quranVerseTotal - 1);
      expect(verses.map((entry) => entry.verse), [
        const VerseKey(114, 5),
        const VerseKey(114, 6),
      ]);
    });

    test('a verse is titled by its surah and number', () {
      final entry = PlaylistQueueEntry.verse(const VerseKey(2, 255));
      expect(entry.title, endsWith('2:255'));
      expect(entry.daily, isFalse);
      expect(entry.zikrUid, uidForSurah(2));
    });
  });
}

/// An-Nas 114:6, as a const for the state's constructor.
const int quranVerseTotalForTest = 6236;
