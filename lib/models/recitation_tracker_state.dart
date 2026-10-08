import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import '../utils/quran_index.dart';

/// The reserved label for reading that was not opened through a recitation
/// track's resume card — browsing the Surahs/Juz list, search, a deep link.
///
/// Not a "no label" state: it is tracked and counted like any other label
/// (it has its own coverage, verse totals and place in the streak), it is
/// just the bucket for recitation nobody deliberately attributed. Reserved
/// rather than user-created, so it can never be renamed or removed out from
/// under the reader.
const String unlabeledRecitationLabel = 'Unlabeled';

/// [label] as a track is called on screen: [unlabeledRecitationLabel] is
/// "My reading", every other label is its own name.
///
/// The stored key stays 'Unlabeled' - it is in every reader's history and
/// sync - so this is the one place the two names meet.
String recitationTrackName(String label, [AppLocalizations? l10n]) =>
    label == unlabeledRecitationLabel
        ? (l10n ?? L10n.current).quranMyReading
        : label;

/// Whether [name], as someone typed it, means the default track - its stored
/// key or the name it is shown under, in any case. Such a name cannot be
/// given to a track of its own: there would be two "My reading"s.
bool isDefaultRecitationTrackName(String name, [AppLocalizations? l10n]) {
  final typed = name.trim().toLowerCase();
  return typed == unlabeledRecitationLabel.toLowerCase() ||
      typed == (l10n ?? L10n.current).quranMyReading.toLowerCase();
}

/// Total ayahs in the Quran, the denominator for "% of the Quran completed".
final int quranTotalAyahCount =
    surahAyahCounts.fold(0, (sum, count) => sum + count);

/// One logged recitation — a real verse range someone read, under a label of
/// their own choosing ("Family", "Personal", "Majlis"), so the same person
/// can keep separate counts, streaks and completion progress for separate
/// contexts.
///
/// Carrying the verse range rather than a bare "I recited today" checkbox is
/// deliberate: it is what lets every stat on the tracker answer "how many
/// verses", not just "how many times was this tapped".
@immutable
class RecitationEntry {
  const RecitationEntry({
    required this.id,
    required this.label,
    required this.recitedAt,
    required this.surah,
    required this.fromAyah,
    required this.toAyah,
    this.readInJuz = false,
  });

  /// Returns null rather than a placeholder entry, so a corrupt row is
  /// dropped instead of showing up as a blank one in the list.
  static RecitationEntry? fromJson(dynamic value) {
    if (value is! Map) return null;

    final id = value['id']?.toString().trim() ?? '';
    final label = value['label']?.toString().trim() ?? '';
    final recitedAt = DateTime.tryParse(value['recitedAt']?.toString() ?? '');
    final surah = int.tryParse(value['surah']?.toString() ?? '');
    final fromAyah = int.tryParse(value['fromAyah']?.toString() ?? '');
    final toAyah = int.tryParse(value['toAyah']?.toString() ?? '');

    if (id.isEmpty || label.isEmpty || recitedAt == null) return null;
    if (surah == null || surah < 1) return null;
    if (fromAyah == null || fromAyah < 1) return null;
    if (toAyah == null || toAyah < fromAyah) return null;

    return RecitationEntry(
      id: id,
      label: label,
      recitedAt: recitedAt,
      surah: surah,
      fromAyah: fromAyah,
      toAyah: toAyah,
      readInJuz: value['readInJuz'] == true,
    );
  }

  final String id;
  final String label;
  final DateTime recitedAt;

  /// The surah recited. A range is always within one surah — spanning a juz
  /// across surahs is logged as one entry per surah, the same way the reader
  /// itself treats a juz as several documents stitched together.
  final int surah;
  final int fromAyah;
  final int toAyah;

  /// Whether this was read in a juz rather than in its surah, so resuming
  /// the track reopens the same view it was left in.
  final bool readInJuz;

  int get versesRecited => toAyah - fromAyah + 1;

  RecitationEntry copyWith({
    String? label,
    int? fromAyah,
    int? toAyah,
  }) {
    return RecitationEntry(
      id: id,
      label: label ?? this.label,
      recitedAt: recitedAt,
      surah: surah,
      fromAyah: fromAyah ?? this.fromAyah,
      toAyah: toAyah ?? this.toAyah,
      readInJuz: readInJuz,
    );
  }

  Map<String, Object> toJson() => {
        'id': id,
        'label': label,
        'recitedAt': recitedAt.toUtc().toIso8601String(),
        'surah': surah,
        'fromAyah': fromAyah,
        'toAyah': toAyah,
        if (readInJuz) 'readInJuz': true,
      };
}

/// How a recitation track reads, chosen when it is created and changeable
/// later: by surah or by juz, and optionally where to pick up from.
///
/// [startAt] is a place the reader set by hand - where a khatm begins, or
/// where it has got to when some of it was read away from the app. It is
/// only honoured over the track's own history while it is the newer of the
/// two, which is what [startSetAt] is for: reading on from there moves the
/// track along as usual, and setting it again moves the track again.
///
/// [readBefore] is for a khatm begun part-way through that was already read
/// up to there: every verse before it counts towards the track's progress -
/// its percentage and juz map - without ever being logged as recited, so the
/// stats (verses, sessions, streaks) only hold what was read in the app.
@immutable
class RecitationTrackSettings {
  const RecitationTrackSettings({
    this.readByJuz = false,
    this.startAt,
    this.startSetAt,
    this.readBefore,
  });

  static RecitationTrackSettings? fromJson(dynamic value) {
    if (value is! Map) return null;

    final surah = int.tryParse(value['startSurah']?.toString() ?? '');
    final ayah = int.tryParse(value['startAyah']?.toString() ?? '');
    final setAt = DateTime.tryParse(value['startSetAt']?.toString() ?? '');
    final isValidStart = surah != null &&
        surah >= 1 &&
        surah <= surahAyahCounts.length &&
        ayah != null &&
        ayah >= 1 &&
        ayah <= surahAyahCounts[surah - 1] &&
        setAt != null;

    final readBeforeSurah =
        int.tryParse(value['readBeforeSurah']?.toString() ?? '');
    final readBeforeAyah =
        int.tryParse(value['readBeforeAyah']?.toString() ?? '');
    final isValidReadBefore = readBeforeSurah != null &&
        readBeforeSurah >= 1 &&
        readBeforeSurah <= surahAyahCounts.length &&
        readBeforeAyah != null &&
        readBeforeAyah >= 1 &&
        readBeforeAyah <= surahAyahCounts[readBeforeSurah - 1];

    return RecitationTrackSettings(
      readByJuz: value['readByJuz'] == true,
      startAt: isValidStart ? VerseKey(surah, ayah) : null,
      startSetAt: isValidStart ? setAt : null,
      readBefore:
          isValidReadBefore ? VerseKey(readBeforeSurah, readBeforeAyah) : null,
    );
  }

  final bool readByJuz;

  /// Always carries an ayah.
  final VerseKey? startAt;
  final DateTime? startSetAt;

  /// Always carries an ayah. Exclusive: this verse itself is still to read.
  final VerseKey? readBefore;

  /// Merged ayah ranges, by surah, that [readBefore] marks as read.
  Map<int, (int, int)> get readBeforeRanges {
    final before = readBefore;
    if (before == null) return const {};
    final ayah = before.ayah ?? 1;
    return {
      for (var surah = 1; surah < before.surah; surah++)
        surah: (1, surahAyahCounts[surah - 1]),
      if (ayah > 1) before.surah: (1, ayah - 1),
    };
  }

  Map<String, Object> toJson() => {
        'readByJuz': readByJuz,
        if (startAt != null && startSetAt != null) ...{
          'startSurah': startAt!.surah,
          'startAyah': startAt!.ayah ?? 1,
          'startSetAt': startSetAt!.toUtc().toIso8601String(),
        },
        if (readBefore != null) ...{
          'readBeforeSurah': readBefore!.surah,
          'readBeforeAyah': readBefore!.ayah ?? 1,
        },
      };

  @override
  bool operator ==(Object other) =>
      other is RecitationTrackSettings &&
      other.readByJuz == readByJuz &&
      other.startAt == startAt &&
      other.startSetAt == startSetAt &&
      other.readBefore == readBefore;

  @override
  int get hashCode => Object.hash(readByJuz, startAt, startSetAt, readBefore);
}

/// Where a track's resume card opens: a verse, and whether in its juz.
@immutable
class RecitationResumeTarget {
  const RecitationResumeTarget(
    this.verse, {
    required this.inJuz,
    required this.isStart,
  });

  /// Always carries an ayah.
  final VerseKey verse;
  final bool inJuz;

  /// Nothing has been read from [verse] yet: a fresh track, or a start point
  /// set more recently than the last reading.
  final bool isStart;

  /// The juz [verse] falls in.
  int get juz => juzOf(verse.surah, verse.ayah ?? 1);
}

/// Every recitation logged, keyed by [RecitationEntry.id], plus the set of
/// recitation tracks (labels) that exist even before their first entry.
///
/// Entries are keyed by id rather than held in a list: adding or removing the
/// same entry twice — the shape an offline retry or a replayed pending
/// operation takes — collapses to one change instead of a duplicate, with no
/// separate deduplication step needed.
@immutable
class RecitationTrackerState {
  RecitationTrackerState([
    Map<String, RecitationEntry>? entries,
    Set<String>? customLabels,
    Map<String, RecitationTrackSettings>? trackSettings,
  ])  : entries = Map.unmodifiable(entries ?? const {}),
        customLabels = Set.unmodifiable(customLabels ?? const {}),
        trackSettings = Map.unmodifiable(trackSettings ?? const {});

  factory RecitationTrackerState.fromJson(dynamic value) {
    if (value is! Map) return empty;

    final entries = <String, RecitationEntry>{};
    final rawEntries = value['entries'];
    if (rawEntries is Map) {
      for (final entry in rawEntries.entries) {
        final parsed = RecitationEntry.fromJson(entry.value);
        if (parsed != null) entries[parsed.id] = parsed;
      }
    }

    final customLabels = <String>{};
    final rawLabels = value['labels'];
    if (rawLabels is List) {
      for (final label in rawLabels) {
        final trimmed = label?.toString().trim() ?? '';
        if (trimmed.isNotEmpty && trimmed != unlabeledRecitationLabel) {
          customLabels.add(trimmed);
        }
      }
    }

    final trackSettings = <String, RecitationTrackSettings>{};
    final rawSettings = value['trackSettings'];
    if (rawSettings is Map) {
      for (final setting in rawSettings.entries) {
        final label = setting.key.toString().trim();
        final parsed = RecitationTrackSettings.fromJson(setting.value);
        if (label.isEmpty || label == unlabeledRecitationLabel) continue;
        if (parsed != null) trackSettings[label] = parsed;
      }
    }

    return RecitationTrackerState(entries, customLabels, trackSettings);
  }

  static final empty = RecitationTrackerState();

  final Map<String, RecitationEntry> entries;

  /// Tracks the user has explicitly created, independent of whether they
  /// have recited anything under them yet — this is what lets a brand new
  /// label show up as a "start reading" card before its first entry.
  final Set<String> customLabels;

  /// How each named track reads, by label. A track with none reads by surah
  /// from the beginning; [unlabeledRecitationLabel] never has any.
  final Map<String, RecitationTrackSettings> trackSettings;

  bool get isEmpty =>
      entries.isEmpty && customLabels.isEmpty && trackSettings.isEmpty;

  RecitationTrackSettings settingsFor(String label) =>
      trackSettings[label] ?? const RecitationTrackSettings();

  List<RecitationEntry> get mostRecentFirst {
    final list = entries.values.toList()
      ..sort((a, b) => b.recitedAt.compareTo(a.recitedAt));
    return list;
  }

  RecitationTrackerState setEntry(RecitationEntry entry) {
    final labels = entry.label == unlabeledRecitationLabel
        ? customLabels
        : {...customLabels, entry.label};
    return RecitationTrackerState(
      {...entries, entry.id: entry},
      labels,
      trackSettings,
    );
  }

  RecitationTrackerState removeEntry(String id) {
    if (!entries.containsKey(id)) return this;
    final next = {...entries}..remove(id);
    return RecitationTrackerState(next, customLabels, trackSettings);
  }

  RecitationTrackerState addCustomLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed == unlabeledRecitationLabel) return this;
    if (customLabels.contains(trimmed)) return this;
    return RecitationTrackerState(
      entries,
      {...customLabels, trimmed},
      trackSettings,
    );
  }

  /// Sets how [label] reads, registering it as a track if it was not one.
  RecitationTrackerState setTrackSettings(
    String label,
    RecitationTrackSettings settings,
  ) {
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed == unlabeledRecitationLabel) return this;
    if (trackSettings[trimmed] == settings && customLabels.contains(trimmed)) {
      return this;
    }
    return RecitationTrackerState(
      entries,
      {...customLabels, trimmed},
      {...trackSettings, trimmed: settings},
    );
  }

  /// Unions two states by id/label. Safe to call with the same addition
  /// twice — that is how a guest-to-user import survives being retried.
  RecitationTrackerState plus(RecitationTrackerState other) {
    if (other.isEmpty) return this;
    return RecitationTrackerState(
      {...entries, ...other.entries},
      {...customLabels, ...other.customLabels},
      {...trackSettings, ...other.trackSettings},
    );
  }

  Map<String, Object> toJson() => {
        'entries': {
          for (final entry in entries.entries) entry.key: entry.value.toJson(),
        },
        'labels': customLabels.toList(),
        if (trackSettings.isNotEmpty)
          'trackSettings': {
            for (final setting in trackSettings.entries)
              setting.key: setting.value.toJson(),
          },
      };

  // ---------------------------------------------------------------------
  // Stats — everything below is derived from the entries above, so the
  // dashboard never has to keep a counter in sync by hand, and every number
  // reflects verses actually recited rather than how many times a button was
  // tapped.
  // ---------------------------------------------------------------------

  int get totalSessions => entries.length;

  int get totalVersesRecited =>
      entries.values.fold(0, (sum, entry) => sum + entry.versesRecited);

  Map<String, int> get sessionsByLabel {
    final counts = <String, int>{};
    for (final entry in entries.values) {
      counts[entry.label] = (counts[entry.label] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> get versesByLabel {
    final counts = <String, int>{};
    for (final entry in entries.values) {
      counts[entry.label] = (counts[entry.label] ?? 0) + entry.versesRecited;
    }
    return counts;
  }

  /// Every recitation track there is — the labels the user created plus any
  /// that only ever showed up on an entry (defensive) — most-recited first
  /// (by verses, not by tap count), with [unlabeledRecitationLabel] always
  /// last since it is a catch-all rather than a deliberate track.
  List<String> get labels {
    final verses = versesByLabel;
    final all = {...customLabels, ...verses.keys}
      ..remove(unlabeledRecitationLabel);
    final sorted = all.toList()
      ..sort((a, b) {
        final byVerses = (verses[b] ?? 0).compareTo(verses[a] ?? 0);
        if (byVerses != 0) return byVerses;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return sorted;
  }

  DateTime? lastRecitedFor(String label) {
    DateTime? latest;
    for (final entry in entries.values) {
      if (entry.label != label) continue;
      if (latest == null || entry.recitedAt.isAfter(latest)) {
        latest = entry.recitedAt;
      }
    }
    return latest;
  }

  /// Where to resume [label]: the tail end of its most recently recited
  /// entry, or null when nothing has been recited under it yet.
  ///
  /// A surah recited to its last verse resumes at the start of the next one
  /// (and an-Nas at al-Fatihah, for the next khatm) - otherwise finishing a
  /// surah would leave the track parked on its final verse.
  VerseKey? resumePositionFor(String label) {
    final latest = _latestEntryFor(label);
    if (latest == null) return null;

    final surah = latest.surah;
    final isKnownSurah = surah >= 1 && surah <= surahAyahCounts.length;
    if (isKnownSurah && latest.toAyah >= surahAyahCounts[surah - 1]) {
      return surah == surahAyahCounts.length
          ? const VerseKey(1, 1)
          : VerseKey(surah + 1, 1);
    }
    return VerseKey(surah, latest.toAyah);
  }

  /// Where [label]'s resume card opens, and whether in a juz.
  ///
  /// The place is [resumePositionFor], unless a start point was set on the
  /// track more recently than anything was read under it - a new khatm set to
  /// begin at juz 12, or a track moved on by hand. The view is the track's
  /// own choice; [unlabeledRecitationLabel], which has no settings, reopens
  /// in whichever view it was last read.
  RecitationResumeTarget resumeTargetFor(String label) {
    final latest = _latestEntryFor(label);
    final isUnlabeled = label == unlabeledRecitationLabel;
    final settings = isUnlabeled ? null : trackSettings[label];
    final inJuz = settings?.readByJuz ?? latest?.readInJuz ?? false;

    final start = settings?.startAt;
    final startSetAt = settings?.startSetAt;
    if (start != null &&
        startSetAt != null &&
        (latest == null || startSetAt.isAfter(latest.recitedAt))) {
      return RecitationResumeTarget(start, inJuz: inJuz, isStart: true);
    }
    var verse = resumePositionFor(label) ?? const VerseKey(1, 1);
    // A juz read to its last verse moves on to the next one (and juz 30 to
    // juz 1), the same way a finished surah does in [resumePositionFor] -
    // most juz end mid-surah, where that rule never fires.
    if (inJuz) {
      final juzList = allJuz();
      final juz = juzOf(verse.surah, verse.ayah ?? 1);
      if (juzList[juz - 1].end == VerseKey(verse.surah, verse.ayah ?? 1)) {
        verse = juzList[juz % juzList.length].start;
      }
    }
    return RecitationResumeTarget(
      verse,
      inJuz: inJuz,
      isStart: latest == null,
    );
  }

  RecitationEntry? _latestEntryFor(String label) {
    RecitationEntry? latest;
    for (final entry in entries.values) {
      if (entry.label != label) continue;
      if (latest == null || entry.recitedAt.isAfter(latest.recitedAt)) {
        latest = entry;
      }
    }
    return latest;
  }

  /// Where the reader most recently was, on whichever track.
  ///
  /// Not label-scoped, unlike [resumePositionFor]: matching a recitation heard
  /// through the microphone wants "where is this person in the Quran" rather
  /// than "where is this track", since whoever is reciting nearby is not
  /// reciting under a label.
  VerseKey? get mostRecentPosition {
    RecitationEntry? latest;
    for (final entry in entries.values) {
      if (latest == null || entry.recitedAt.isAfter(latest.recitedAt)) {
        latest = entry;
      }
    }
    return latest == null ? null : VerseKey(latest.surah, latest.toAyah);
  }

  /// Merged, non-overlapping ayah ranges ever recited under [label], by
  /// surah — the union of every session's range, so re-reading the same
  /// verses repeatedly does not inflate how much of the Quran is "done".
  ///
  /// Includes what the track was set up as already having read
  /// ([RecitationTrackSettings.readBefore]): this is its progress, not a log.
  Map<int, List<(int, int)>> _mergedRangesForLabel(String label) {
    final bySurah = <int, List<(int, int)>>{};
    for (final entry in entries.values) {
      if (entry.label != label) continue;
      (bySurah[entry.surah] ??= []).add((entry.fromAyah, entry.toAyah));
    }
    if (label != unlabeledRecitationLabel) {
      final readBefore = trackSettings[label]?.readBeforeRanges ?? const {};
      for (final range in readBefore.entries) {
        (bySurah[range.key] ??= []).add(range.value);
      }
    }

    final merged = <int, List<(int, int)>>{};
    for (final surahEntry in bySurah.entries) {
      final ranges = surahEntry.value..sort((a, b) => a.$1.compareTo(b.$1));
      final mergedRanges = <(int, int)>[];
      for (final range in ranges) {
        if (mergedRanges.isNotEmpty && range.$1 <= mergedRanges.last.$2 + 1) {
          final last = mergedRanges.removeLast();
          final upperBound = range.$2 > last.$2 ? range.$2 : last.$2;
          mergedRanges.add((last.$1, upperBound));
        } else {
          mergedRanges.add(range);
        }
      }
      merged[surahEntry.key] = mergedRanges;
    }
    return merged;
  }

  /// Distinct ayahs ever recited under [label] — the deduplicated count that
  /// "% of the Quran completed" is built from, as opposed to
  /// [versesByLabel]'s sum, which counts every re-read.
  int distinctVersesRecitedFor(String label) {
    var total = 0;
    for (final ranges in _mergedRangesForLabel(label).values) {
      for (final range in ranges) {
        total += range.$2 - range.$1 + 1;
      }
    }
    return total;
  }

  /// How much of each of the thirty juz, 0.0-1.0, has been recited at least
  /// once under [label] - the "map" of a khatm in progress, where gaps left
  /// by reading out of order stay visible instead of hiding in one percentage.
  List<double> juzCoverageFor(String label) {
    final juzList = allJuz();
    final covered = List<int>.filled(juzList.length, 0);
    final bounds = [
      for (final juz in juzList)
        (
          verseOrdinal(juz.start.surah, juz.start.ayah!),
          verseOrdinal(juz.end.surah, juz.end.ayah!),
        ),
    ];
    for (final surahEntry in _mergedRangesForLabel(label).entries) {
      final surah = surahEntry.key;
      if (!isSurahNumber(surah)) continue;
      final maxAyah = surahAyahCounts[surah - 1];
      for (final range in surahEntry.value) {
        if (range.$1 > maxAyah) continue;
        final from = verseOrdinal(surah, range.$1);
        final to = verseOrdinal(surah, range.$2 > maxAyah ? maxAyah : range.$2);
        for (var i = 0; i < bounds.length; i++) {
          final (start, end) = bounds[i];
          final lo = from > start ? from : start;
          final hi = to < end ? to : end;
          if (hi >= lo) covered[i] += hi - lo + 1;
        }
      }
    }
    return [
      for (var i = 0; i < bounds.length; i++)
        covered[i] / (bounds[i].$2 - bounds[i].$1 + 1),
    ];
  }

  /// Juz recited end to end under [label].
  int completedJuzCountFor(String label) =>
      juzCoverageFor(label).where((fraction) => fraction >= 1).length;

  /// The last verse of [label]'s most recent session - "recited till" - or
  /// null before its first.
  VerseKey? lastRecitedVerseFor(String label) {
    RecitationEntry? latest;
    for (final entry in entries.values) {
      if (entry.label != label) continue;
      if (latest == null || entry.recitedAt.isAfter(latest.recitedAt)) {
        latest = entry;
      }
    }
    return latest == null ? null : VerseKey(latest.surah, latest.toAyah);
  }

  /// How much of the Quran, 0–100, has been recited at least once under
  /// [label].
  double percentCompleteFor(String label) {
    if (quranTotalAyahCount == 0) return 0;
    return distinctVersesRecitedFor(label) / quranTotalAyahCount * 100;
  }

  Set<DateTime> get _recitedLocalDays => entries.values
      .map((entry) => _dateOnly(entry.recitedAt.toLocal()))
      .toSet();

  /// Consecutive days up to and including today (or yesterday, so logging
  /// tonight's recitation tomorrow morning does not reset it to zero) on
  /// which at least one verse was recited, across every label.
  int get currentStreak {
    final days = _recitedLocalDays;
    if (days.isEmpty) return 0;

    var cursor = _dateOnly(DateTime.now());
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }

    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int get longestStreak {
    final days = _recitedLocalDays.toList()..sort();
    if (days.isEmpty) return 0;

    var longest = 1;
    var current = 1;
    for (var i = 1; i < days.length; i++) {
      current = days[i].difference(days[i - 1]).inDays == 1 ? current + 1 : 1;
      if (current > longest) longest = current;
    }
    return longest;
  }

  int sessionsSince(DateTime sinceLocal) {
    return entries.values
        .where((entry) => !entry.recitedAt.toLocal().isBefore(sinceLocal))
        .length;
  }

  int versesSince(DateTime sinceLocal) {
    return entries.values
        .where((entry) => !entry.recitedAt.toLocal().isBefore(sinceLocal))
        .fold(0, (sum, entry) => sum + entry.versesRecited);
  }

  /// Verses recited per local calendar day for the trailing [days] days
  /// (today included), for a GitHub-style contribution heatmap — a heavy
  /// day of recitation reads darker than a two-verse glance.
  Map<DateTime, int> dailyVerseCounts(int days) {
    final today = _dateOnly(DateTime.now());
    final start = today.subtract(Duration(days: days - 1));
    final counts = <DateTime, int>{
      for (var i = 0; i < days; i++) start.add(Duration(days: i)): 0,
    };

    for (final entry in entries.values) {
      final day = _dateOnly(entry.recitedAt.toLocal());
      if (day.isBefore(start) || day.isAfter(today)) continue;
      counts[day] = (counts[day] ?? 0) + entry.versesRecited;
    }
    return counts;
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
