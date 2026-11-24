import 'package:flutter/foundation.dart';

import '../utils/quran_index.dart';
import 'zikr_audio_track.dart';

/// Who recites the verse-by-verse Quran in the app's bucket.
const String quranVerseReciter = 'Shahriar Parhizkar';

/// The recording of one verse: `quran-ayah/parhizkar/002255.mp3` is 2:255.
///
/// Verse 1 of every surah but at-Tawbah carries its Bismillah, and 1:1 is
/// the Bismillah itself, so playing the files in order is the whole surah as
/// it is recited - there is no separate Bismillah file to put in front.
String quranVerseAudioUrl(int surah, int ayah) =>
    '${zikrAudioBaseUrl}quran-ayah/parhizkar/'
    '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';

ZikrAudioTrack quranVerseTrack(int surah, int ayah) => ZikrAudioTrack(
  url: quranVerseAudioUrl(surah, ayah),
  reciter: quranVerseReciter,
);

/// Every verse in the Quran - the last ordinal [verseOrdinal] gives.
final int quranVerseTotal = verseOrdinal(
  surahCount,
  surahAyahCounts[surahCount - 1],
);

/// The verse at 1-based position [ordinal] across the whole Quran - the
/// inverse of [verseOrdinal]. Out-of-range positions are clamped.
VerseKey verseAtOrdinal(int ordinal) {
  var left = ordinal.clamp(1, quranVerseTotal);
  for (var i = 0; i < surahAyahCounts.length; i++) {
    final count = surahAyahCounts[i];
    if (left <= count) return VerseKey(i + 1, left);
    left -= count;
  }
  return VerseKey(surahCount, surahAyahCounts[surahCount - 1]);
}

int ordinalOfVerse(VerseKey verse) => verseOrdinal(verse.surah, verse.ayah ?? 1);

/// The playlist item that plays the Quran a portion a day, carrying on each
/// day from where the last one stopped. It sits among a playlist's zikr uids
/// - alone in "Quran, Day by Day", or after the duas of a morning playlist -
/// and turns into verses only when the playlist is played.
const String quranDailyUid = '~quran-daily';

/// How much of the Quran a day's listening is.
///
/// Minutes are what a habit is kept in; a juz a day is what a khatm in a
/// month is kept in. Either way playback stops only between two verses,
/// never in the middle of one.
@immutable
class QuranListeningGoal {
  const QuranListeningGoal._(this.code, {this.minutes, this.juz = false});

  final String code;

  /// Minutes of listening a day, for a time goal.
  final int? minutes;

  /// Whether the goal is a juz a day.
  final bool juz;

  /// No daily stop: it plays on until paused.
  bool get isOpen => minutes == null && !juz;

  static const QuranListeningGoal open = QuranListeningGoal._('open');
  static const QuranListeningGoal oneJuz = QuranListeningGoal._(
    'juz',
    juz: true,
  );
  static const QuranListeningGoal fifteenMinutes = QuranListeningGoal._(
    '15m',
    minutes: 15,
  );

  static const List<QuranListeningGoal> values = [
    QuranListeningGoal._('5m', minutes: 5),
    QuranListeningGoal._('10m', minutes: 10),
    fifteenMinutes,
    QuranListeningGoal._('20m', minutes: 20),
    QuranListeningGoal._('30m', minutes: 30),
    QuranListeningGoal._('45m', minutes: 45),
    QuranListeningGoal._('60m', minutes: 60),
    oneJuz,
    open,
  ];

  static const QuranListeningGoal standard = fifteenMinutes;

  static QuranListeningGoal fromCode(String? code) {
    for (final goal in values) {
      if (goal.code == code) return goal;
    }
    return standard;
  }

  @override
  bool operator ==(Object other) =>
      other is QuranListeningGoal && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// The last verse of today's juz when listening starts at [startOrdinal]:
/// the end of the juz it falls in - or, when less than a quarter of that juz
/// is left, the end of the one after, so a day that starts just short of a
/// juz boundary is not a day of a dozen verses.
int juzPortionEnd(int startOrdinal) {
  final start = verseAtOrdinal(startOrdinal);
  final parts = allJuz();
  final juz = parts[juzOf(start.surah, start.ayah ?? 1) - 1];
  final juzStart = ordinalOfVerse(juz.start);
  final juzEnd = ordinalOfVerse(juz.end);
  final left = juzEnd - startOrdinal + 1;
  final size = juzEnd - juzStart + 1;
  if (left * 4 >= size || juz.number == parts.length) return juzEnd;
  return ordinalOfVerse(parts[juz.number].end);
}

/// "2026-11-23", the local calendar day [now] falls on.
String listeningDayKey(DateTime now) {
  final local = now.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

/// Where the reader is in listening through the Quran, and how today has
/// gone.
///
/// The position is the verse to play next: the one that was playing when
/// they stopped, so it starts again from its beginning rather than mid-word.
/// Kept on this device, like the playlists it plays in.
@immutable
class QuranListeningState {
  const QuranListeningState({
    this.next = 1,
    this.goal = QuranListeningGoal.standard,
    this.day,
    this.secondsToday = 0,
    this.dayStart = 1,
    this.dayEnd,
    this.goalMetToday = false,
    this.daysListened = 0,
    this.khatms = 0,
  });

  factory QuranListeningState.fromJson(Map<String, dynamic> json) {
    int read(String key, int fallback) =>
        int.tryParse(json[key]?.toString() ?? '') ?? fallback;
    int verse(String key) => read(key, 1).clamp(1, quranVerseTotal);
    final dayEnd = int.tryParse(json['dayEnd']?.toString() ?? '');
    return QuranListeningState(
      next: verse('next'),
      goal: QuranListeningGoal.fromCode(json['goal']?.toString()),
      day: json['day']?.toString(),
      secondsToday: read('secondsToday', 0).clamp(0, 1 << 30),
      dayStart: verse('dayStart'),
      dayEnd: dayEnd?.clamp(1, quranVerseTotal),
      goalMetToday: json['goalMetToday'] == true,
      daysListened: read('daysListened', 0).clamp(0, 1 << 30),
      khatms: read('khatms', 0).clamp(0, 1 << 30),
    );
  }

  /// The 1-based position across the Quran ([verseOrdinal]) to play next.
  final int next;
  final QuranListeningGoal goal;

  /// [listeningDayKey] of the day [secondsToday] and the rest belong to.
  final String? day;
  final int secondsToday;

  /// Where that day's listening started, and - for a juz goal - the last
  /// verse of its portion.
  final int dayStart;
  final int? dayEnd;
  final bool goalMetToday;

  /// Days with any listening at all, and whole Qurans listened through.
  final int daysListened;
  final int khatms;

  VerseKey get nextVerse => verseAtOrdinal(next);

  /// How far through the Quran [next] is, 0 to 1.
  double get progress => (next - 1) / quranVerseTotal;

  /// This state as of [now]: a new day starts today's count afresh from
  /// wherever the last one stopped.
  QuranListeningState forDay(DateTime now) {
    final today = listeningDayKey(now);
    if (day == today) return this;
    return _copy(
      day: today,
      secondsToday: 0,
      dayStart: next,
      dayEnd: goal.juz ? juzPortionEnd(next) : null,
      clearDayEnd: !goal.juz,
      goalMetToday: false,
    );
  }

  /// [listened] more of today's listening, now at [playing]. [finished] is
  /// the verse that just played to its end, when it did: finishing an-Nas
  /// completes a khatm.
  QuranListeningState recordPlayback({
    required int playing,
    Duration listened = Duration.zero,
    int? finished,
    required DateTime now,
  }) {
    final today = forDay(now);
    final seconds = today.secondsToday + listened.inMilliseconds ~/ 1000;
    final startedToday = today.secondsToday == 0 && seconds > 0;
    return today._copy(
      next: playing.clamp(1, quranVerseTotal),
      secondsToday: seconds,
      daysListened: today.daysListened + (startedToday ? 1 : 0),
      khatms: today.khatms + (finished == quranVerseTotal ? 1 : 0),
    );
  }

  /// Whether reaching verse [playing] means today's portion is done - asked
  /// as each verse starts, so a stop always falls between two verses.
  bool goalReachedAt(int playing) {
    if (goalMetToday) return false;
    final minutes = goal.minutes;
    if (minutes != null) return secondsToday >= minutes * 60;
    final end = dayEnd;
    if (!goal.juz || end == null) return false;
    // Past the end of the portion - or wrapped round to al-Fatihah after a
    // khatm that ended it.
    return playing > end || playing < dayStart;
  }

  QuranListeningState markGoalMet() => _copy(goalMetToday: true);

  /// Starts again from [ordinal], chosen by the reader; today's portion is
  /// measured from there.
  QuranListeningState startingAt(int ordinal, DateTime now) {
    final verse = ordinal.clamp(1, quranVerseTotal);
    final today = forDay(now);
    return today._copy(
      next: verse,
      dayStart: verse,
      dayEnd: goal.juz ? juzPortionEnd(verse) : null,
      clearDayEnd: !goal.juz,
    );
  }

  QuranListeningState withGoal(QuranListeningGoal value, DateTime now) {
    final today = forDay(now);
    return today._copy(
      goal: value,
      dayEnd: value.juz ? juzPortionEnd(today.dayStart) : null,
      clearDayEnd: !value.juz,
      // A goal changed after it was met is met again by its own measure.
      goalMetToday: false,
    );
  }

  /// Today's listening against a time goal, 0 to 1; null for any other.
  double? minutesProgress(DateTime now) {
    final minutes = goal.minutes;
    if (minutes == null) return null;
    final today = forDay(now);
    return (today.secondsToday / (minutes * 60)).clamp(0, 1).toDouble();
  }

  QuranListeningState _copy({
    int? next,
    QuranListeningGoal? goal,
    String? day,
    int? secondsToday,
    int? dayStart,
    int? dayEnd,
    bool clearDayEnd = false,
    bool? goalMetToday,
    int? daysListened,
    int? khatms,
  }) {
    return QuranListeningState(
      next: next ?? this.next,
      goal: goal ?? this.goal,
      day: day ?? this.day,
      secondsToday: secondsToday ?? this.secondsToday,
      dayStart: dayStart ?? this.dayStart,
      dayEnd: clearDayEnd ? null : dayEnd ?? this.dayEnd,
      goalMetToday: goalMetToday ?? this.goalMetToday,
      daysListened: daysListened ?? this.daysListened,
      khatms: khatms ?? this.khatms,
    );
  }

  Map<String, dynamic> toJson() => {
    'next': next,
    'goal': goal.code,
    if (day != null) 'day': day,
    'secondsToday': secondsToday,
    'dayStart': dayStart,
    if (dayEnd != null) 'dayEnd': dayEnd,
    'goalMetToday': goalMetToday,
    'daysListened': daysListened,
    'khatms': khatms,
  };

  @override
  bool operator ==(Object other) =>
      other is QuranListeningState &&
      mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}
