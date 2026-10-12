import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import '../utils/quran_index.dart';
import 'activity_stats.dart';

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

/// Days of recitation kept session by session. Older sessions are folded
/// into one [RecitationDaySummary] per day and track (see
/// [RecitationTrackerState.compaction]), which keeps every stat, streak and
/// khatm's progress while the synced document - one Firestore doc, capped at
/// 1 MiB - stops growing with every surah read.
const int recitationSessionRetentionDays = 30;

/// How long past [recitationSessionRetentionDays] a session may wait to be
/// folded, so the folding is done in weekly batches - one write a week -
/// rather than one write on every launch as each day crosses the line.
const int recitationCompactionGraceDays = 7;

/// The most sessions folded in one pass, so a long history's first pass
/// stays a modest write; the rest follow on later launches.
const int recitationMaxSessionsPerCompaction = 500;

/// Days a day summary keeps the verses it covered. Past this only its counts
/// are needed - for streaks and totals - so its ranges move into its track's
/// lifetime [RecitationTrackerState.coverage], the one place khatm progress
/// needs them, and the archive grows by a few bytes a day rather than by
/// every surah read. Matches [activityRetentionDays], the furthest back any
/// chart looks.
const int recitationDayRangesRetentionDays = 400;

/// The most day summaries stripped of their ranges in one pass, for the
/// same reason as [recitationMaxSessionsPerCompaction].
const int recitationMaxSummariesPerCompaction = 500;

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

/// One track's recitation on one day, kept once the day's sessions are
/// older than [recitationSessionRetentionDays]: how many sessions and verses
/// there were, and which verses they covered. That is everything the stats,
/// streaks and khatm progress need from a session that is no longer listed.
@immutable
class RecitationDaySummary {
  const RecitationDaySummary({
    this.sessions = 0,
    this.verses = 0,
    this.ranges = const {},
  });

  static const empty = RecitationDaySummary();

  /// Reads [encode]'s form; null for anything else, so a corrupt summary is
  /// dropped rather than counted.
  static RecitationDaySummary? decode(dynamic value) {
    if (value is! String) return null;
    final parts = value.split('|');
    if (parts.length != 3) return null;
    final sessions = int.tryParse(parts[0]);
    final verses = int.tryParse(parts[1]);
    if (sessions == null || sessions < 1 || verses == null || verses < 1) {
      return null;
    }

    final ranges = decodeAyahRanges(parts[2]);
    if (ranges == null) return null;
    return RecitationDaySummary(
      sessions: sessions,
      verses: verses,
      ranges: ranges,
    );
  }

  final int sessions;

  /// Every verse read that day, re-reads included - the sum, as
  /// [RecitationEntry.versesRecited] adds up for the sessions themselves.
  final int verses;

  /// Merged ayah ranges covered that day, by surah.
  final Map<int, List<(int, int)>> ranges;

  /// This summary with [entry] folded in.
  RecitationDaySummary adding(RecitationEntry entry) {
    return RecitationDaySummary(
      sessions: sessions + 1,
      verses: verses + entry.versesRecited,
      ranges: {
        ...ranges,
        entry.surah: mergeAyahRanges([
          ...?ranges[entry.surah],
          (entry.fromAyah, entry.toAyah),
        ]),
      },
    );
  }

  /// Reconciles two copies of the same day: the larger counts and the union
  /// of the ranges. Never a sum, so meeting the same summary twice - a
  /// retried guest import - cannot double it.
  RecitationDaySummary union(RecitationDaySummary other) {
    return RecitationDaySummary(
      sessions: sessions > other.sessions ? sessions : other.sessions,
      verses: verses > other.verses ? verses : other.verses,
      ranges: unionAyahRanges(ranges, other.ranges),
    );
  }

  /// The same day with only its counts, once its ranges have moved into
  /// its track's [RecitationTrackerState.coverage].
  RecitationDaySummary get withoutRanges => ranges.isEmpty
      ? this
      : RecitationDaySummary(sessions: sessions, verses: verses);

  /// `sessions|verses|surah:from-to,from-to;surah:from-to` - one short
  /// string per day and track, rather than a map, so the synced doc holds
  /// one field for it instead of a dozen. The ranges are [encodeAyahRanges]'
  /// form, and empty once they have moved into the track's coverage.
  String encode() => '$sessions|$verses|${encodeAyahRanges(ranges)}';

  @override
  bool operator ==(Object other) =>
      other is RecitationDaySummary && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// `surah:from-to,from-to;surah:from-to`, surahs in order and a one-verse
/// range as just its ayah: [RecitationDaySummary]'s ranges and a track's
/// [RecitationTrackerState.coverage] alike.
String encodeAyahRanges(Map<int, List<(int, int)>> ranges) {
  final surahs = ranges.keys.toList()..sort();
  return [
    for (final surah in surahs)
      if (ranges[surah]!.isNotEmpty)
        '$surah:${ranges[surah]!.map((r) => r.$1 == r.$2 ? '${r.$1}' : '${r.$1}-${r.$2}').join(',')}',
  ].join(';');
}

/// Reads [encodeAyahRanges]' form, merging each surah's ranges; null for
/// anything malformed, so a corrupt value is dropped rather than half read.
Map<int, List<(int, int)>>? decodeAyahRanges(String value) {
  final ranges = <int, List<(int, int)>>{};
  if (value.isEmpty) return ranges;
  for (final surahPart in value.split(';')) {
    final colon = surahPart.indexOf(':');
    if (colon < 0) return null;
    final surah = int.tryParse(surahPart.substring(0, colon));
    if (surah == null || surah < 1) return null;
    final list = <(int, int)>[];
    for (final rangePart in surahPart.substring(colon + 1).split(',')) {
      final bounds = rangePart.split('-');
      final from = int.tryParse(bounds.first);
      final to = bounds.length == 2 ? int.tryParse(bounds.last) : from;
      if (bounds.length > 2 || from == null || from < 1) return null;
      if (to == null || to < from) return null;
      list.add((from, to));
    }
    ranges[surah] = mergeAyahRanges([...?ranges[surah], ...list]);
  }
  return ranges;
}

/// [a] and [b] together, each surah's ranges merged.
Map<int, List<(int, int)>> unionAyahRanges(
  Map<int, List<(int, int)>> a,
  Map<int, List<(int, int)>> b,
) {
  final merged = <int, List<(int, int)>>{...a};
  b.forEach((surah, list) {
    merged[surah] = mergeAyahRanges([...?merged[surah], ...list]);
  });
  return merged;
}

/// The sessions [RecitationTrackerState.compaction] folds away, the day
/// summaries that replace them, and the tracks' coverage that old days'
/// ranges move into.
@immutable
class RecitationCompaction {
  const RecitationCompaction({
    required this.removedEntryIds,
    required this.summaries,
    this.coverage = const {},
  });

  final Set<String> removedEntryIds;

  /// The new value of every summary it touches: day key, then label.
  final Map<String, Map<String, RecitationDaySummary>> summaries;

  /// The new value of every track's coverage it touches, by label.
  final Map<String, Map<int, List<(int, int)>>> coverage;

  bool get isEmpty =>
      removedEntryIds.isEmpty && summaries.isEmpty && coverage.isEmpty;
}

/// [ranges] sorted and merged, with touching ranges joined.
List<(int, int)> mergeAyahRanges(Iterable<(int, int)> ranges) {
  final sorted = ranges.toList()..sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(int, int)>[];
  for (final range in sorted) {
    if (merged.isNotEmpty && range.$1 <= merged.last.$2 + 1) {
      final last = merged.removeLast();
      merged.add((last.$1, range.$2 > last.$2 ? range.$2 : last.$2));
    } else {
      merged.add(range);
    }
  }
  return merged;
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
/// Sessions older than [recitationSessionRetentionDays] live on as
/// [archive]'s day summaries instead; every stat below counts both.
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
    Map<String, Map<String, RecitationDaySummary>>? archive,
    Map<String, Map<int, List<(int, int)>>>? coverage,
  ])  : entries = Map.unmodifiable(entries ?? const {}),
        customLabels = Set.unmodifiable(customLabels ?? const {}),
        trackSettings = Map.unmodifiable(trackSettings ?? const {}),
        archive = Map.unmodifiable(<String, Map<String, RecitationDaySummary>>{
          for (final day in (archive ?? const {}).entries)
            if (day.value.isNotEmpty)
              day.key:
                  Map<String, RecitationDaySummary>.unmodifiable(day.value),
        }),
        coverage = Map.unmodifiable(<String, Map<int, List<(int, int)>>>{
          for (final track in (coverage ?? const {}).entries)
            if (track.value.isNotEmpty)
              track.key: Map<int, List<(int, int)>>.unmodifiable(track.value),
        });

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

    final archive = <String, Map<String, RecitationDaySummary>>{};
    final rawArchive = value['archive'];
    if (rawArchive is Map) {
      for (final day in rawArchive.entries) {
        final dayKey = day.key.toString();
        if (parseActivityDay(dayKey) == null || day.value is! Map) continue;
        for (final summary in (day.value as Map).entries) {
          final label = summary.key.toString().trim();
          final parsed = RecitationDaySummary.decode(summary.value);
          if (label.isEmpty || parsed == null) continue;
          (archive[dayKey] ??= {})[label] = parsed;
        }
      }
    }

    final coverage = <String, Map<int, List<(int, int)>>>{};
    final rawCoverage = value['coverage'];
    if (rawCoverage is Map) {
      for (final track in rawCoverage.entries) {
        final label = track.key.toString().trim();
        final value = track.value;
        final parsed = value is String ? decodeAyahRanges(value) : null;
        if (label.isEmpty || parsed == null) continue;
        coverage[label] = parsed;
      }
    }

    return RecitationTrackerState(
      entries,
      customLabels,
      trackSettings,
      archive,
      coverage,
    );
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

  /// Sessions older than [recitationSessionRetentionDays], one summary per
  /// local day ([activityDayKey]) and label.
  final Map<String, Map<String, RecitationDaySummary>> archive;

  /// Every verse a track covered on days older than
  /// [recitationDayRangesRetentionDays], merged: by label, then surah. Those
  /// days' [archive] summaries keep only their counts.
  final Map<String, Map<int, List<(int, int)>>> coverage;

  bool get isEmpty =>
      entries.isEmpty &&
      customLabels.isEmpty &&
      trackSettings.isEmpty &&
      archive.isEmpty &&
      coverage.isEmpty;

  Iterable<(String, RecitationDaySummary)> get _archivedSummaries sync* {
    for (final day in archive.values) {
      for (final summary in day.entries) {
        yield (summary.key, summary.value);
      }
    }
  }

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
      archive,
      coverage,
    );
  }

  RecitationTrackerState removeEntry(String id) {
    if (!entries.containsKey(id)) return this;
    final next = {...entries}..remove(id);
    return RecitationTrackerState(
        next, customLabels, trackSettings, archive, coverage);
  }

  RecitationTrackerState addCustomLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed == unlabeledRecitationLabel) return this;
    if (customLabels.contains(trimmed)) return this;
    return RecitationTrackerState(
      entries,
      {...customLabels, trimmed},
      trackSettings,
      archive,
      coverage,
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
      archive,
      coverage,
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
      archiveUnion(other.archive),
      coverageUnion(other.coverage),
    );
  }

  /// [archive] with [other] folded in by [RecitationDaySummary.union].
  Map<String, Map<String, RecitationDaySummary>> archiveUnion(
    Map<String, Map<String, RecitationDaySummary>> other,
  ) {
    final merged = {
      for (final day in archive.entries) day.key: {...day.value},
    };
    for (final day in other.entries) {
      final into = merged[day.key] ??= {};
      day.value.forEach((label, summary) {
        final mine = into[label];
        into[label] = mine == null ? summary : mine.union(summary);
      });
    }
    return merged;
  }

  /// [coverage] with [other] folded in, each track's ranges merged - never
  /// more than the union, so meeting the same coverage twice changes nothing.
  Map<String, Map<int, List<(int, int)>>> coverageUnion(
    Map<String, Map<int, List<(int, int)>>> other,
  ) {
    final merged = {...coverage};
    other.forEach((label, ranges) {
      merged[label] = unionAyahRanges(merged[label] ?? const {}, ranges);
    });
    return merged;
  }

  /// The sessions due to be folded into day summaries as of [now], and the
  /// old summaries due to hand their ranges over to [coverage], or null when
  /// nothing is due.
  ///
  /// A session is due once its day is more than
  /// [recitationSessionRetentionDays] behind [now]'s, and the fold waits
  /// until one is [recitationCompactionGraceDays] past that so it happens in
  /// weekly batches. Each track's latest session is never folded: it is
  /// where the track resumes, and when it was read.
  ///
  /// Two devices folding the same sessions in the same time zone write the
  /// same summaries, so a fold replayed or repeated elsewhere changes
  /// nothing. Two devices in different time zones folding at the same moment
  /// could each file a session under its own local day and count it twice;
  /// folding only straight after a fresh read of the account keeps that
  /// window to a near-simultaneous launch. Likewise a session folded here
  /// and then re-sent raw by a device that was offline for over a month
  /// would be folded again on top - rare enough to leave be.
  ///
  /// A summary older than [recitationDayRangesRetentionDays] keeps only its
  /// counts: its ranges are united into its track's [coverage]. That too
  /// waits a week past the line, and is the same on every device that folds
  /// from the same read.
  RecitationCompaction? compaction(
    DateTime now, {
    int maxSessions = recitationMaxSessionsPerCompaction,
    int maxSummaries = recitationMaxSummariesPerCompaction,
  }) {
    final sessions = _sessionCompaction(now, maxSessions);
    final summaries = {
      for (final day in (sessions?.summaries ?? const {}).entries)
        day.key: {...day.value},
    };
    final coverage = _rangesCompaction(
      now,
      maxSummaries,
      summaries,
    );
    if (sessions == null && coverage == null) return null;
    return RecitationCompaction(
      removedEntryIds: sessions?.removedEntryIds ?? const {},
      summaries: summaries,
      coverage: coverage ?? const {},
    );
  }

  /// Moves the ranges of summaries older than
  /// [recitationDayRangesRetentionDays] into their tracks' coverage: strips
  /// them in [summaries] (which already holds this pass's folded days) and
  /// returns the new coverage, or null when none are due.
  Map<String, Map<int, List<(int, int)>>>? _rangesCompaction(
    DateTime now,
    int maxSummaries,
    Map<String, Map<String, RecitationDaySummary>> summaries,
  ) {
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day - recitationDayRangesRetentionDays,
    );
    final graceCutoff = DateTime(
        cutoff.year, cutoff.month, cutoff.day - recitationCompactionGraceDays);

    final due = <(DateTime, String, String, RecitationDaySummary)>[];
    for (final day in {...archive.keys, ...summaries.keys}) {
      final date = parseActivityDay(day);
      if (date == null || !date.isBefore(cutoff)) continue;
      final byLabel = {...?archive[day], ...?summaries[day]};
      byLabel.forEach((label, summary) {
        if (summary.ranges.isNotEmpty) due.add((date, day, label, summary));
      });
    }
    if (due.isEmpty) return null;
    due.sort((a, b) => a.$1.compareTo(b.$1));
    if (!due.first.$1.isBefore(graceCutoff)) return null;

    final next = <String, Map<int, List<(int, int)>>>{};
    for (final (_, day, label, summary) in due.take(maxSummaries)) {
      next[label] = unionAyahRanges(
        next[label] ?? coverage[label] ?? const {},
        summary.ranges,
      );
      (summaries[day] ??= {})[label] = summary.withoutRanges;
    }
    return next;
  }

  RecitationCompaction? _sessionCompaction(DateTime now, int maxSessions) {
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day - recitationSessionRetentionDays,
    );
    final graceCutoff = DateTime(
        cutoff.year, cutoff.month, cutoff.day - recitationCompactionGraceDays);

    final latestIds = <String>{
      for (final label in entries.values.map((entry) => entry.label).toSet())
        _latestEntryFor(label)!.id,
    };
    final due = entries.values
        .where((entry) =>
            !latestIds.contains(entry.id) &&
            entry.recitedAt.toLocal().isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.recitedAt.compareTo(b.recitedAt));
    if (due.isEmpty || !due.first.recitedAt.toLocal().isBefore(graceCutoff)) {
      return null;
    }

    final summaries = <String, Map<String, RecitationDaySummary>>{};
    final removed = <String>{};
    for (final entry in due.take(maxSessions)) {
      final day = activityDayKey(entry.recitedAt);
      final byLabel = summaries[day] ??= {};
      final current = byLabel[entry.label] ??
          archive[day]?[entry.label] ??
          RecitationDaySummary.empty;
      byLabel[entry.label] = current.adding(entry);
      removed.add(entry.id);
    }
    return RecitationCompaction(removedEntryIds: removed, summaries: summaries);
  }

  /// Removes [compaction]'s sessions and sets its summaries and coverage.
  RecitationTrackerState applyCompaction(RecitationCompaction compaction) {
    if (compaction.isEmpty) return this;
    final nextArchive = {
      for (final day in archive.entries) day.key: {...day.value},
    };
    compaction.summaries.forEach((day, byLabel) {
      (nextArchive[day] ??= {}).addAll(byLabel);
    });
    final nextLabels = {
      ...customLabels,
      for (final byLabel in compaction.summaries.values) ...byLabel.keys,
      ...compaction.coverage.keys,
    }..remove(unlabeledRecitationLabel);
    return RecitationTrackerState(
      {...entries}
        ..removeWhere((id, _) => compaction.removedEntryIds.contains(id)),
      nextLabels,
      trackSettings,
      nextArchive,
      {...coverage, ...compaction.coverage},
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
        if (archive.isNotEmpty)
          'archive': {
            for (final day in archive.entries)
              day.key: {
                for (final summary in day.value.entries)
                  summary.key: summary.value.encode(),
              },
          },
        if (coverage.isNotEmpty)
          'coverage': {
            for (final track in coverage.entries)
              track.key: encodeAyahRanges(track.value),
          },
      };

  // ---------------------------------------------------------------------
  // Stats — everything below is derived from the entries above, so the
  // dashboard never has to keep a counter in sync by hand, and every number
  // reflects verses actually recited rather than how many times a button was
  // tapped.
  // ---------------------------------------------------------------------

  int get totalSessions => _archivedSummaries.fold(
      entries.length, (sum, archived) => sum + archived.$2.sessions);

  int get totalVersesRecited => _archivedSummaries.fold(
      entries.values.fold(0, (sum, entry) => sum + entry.versesRecited),
      (sum, archived) => sum + archived.$2.verses);

  Map<String, int> get sessionsByLabel {
    final counts = <String, int>{};
    for (final entry in entries.values) {
      counts[entry.label] = (counts[entry.label] ?? 0) + 1;
    }
    for (final (label, summary) in _archivedSummaries) {
      counts[label] = (counts[label] ?? 0) + summary.sessions;
    }
    return counts;
  }

  Map<String, int> get versesByLabel {
    final counts = <String, int>{};
    for (final entry in entries.values) {
      counts[entry.label] = (counts[entry.label] ?? 0) + entry.versesRecited;
    }
    for (final (label, summary) in _archivedSummaries) {
      counts[label] = (counts[label] ?? 0) + summary.verses;
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
  /// surah — the union of every session's range (and every archived day's,
  /// and the track's [coverage] from before that),
  /// so re-reading the same verses repeatedly does not inflate how much of
  /// the Quran is "done".
  ///
  /// Includes what the track was set up as already having read
  /// ([RecitationTrackSettings.readBefore]): this is its progress, not a log.
  Map<int, List<(int, int)>> _mergedRangesForLabel(String label) {
    final bySurah = <int, List<(int, int)>>{};
    for (final entry in entries.values) {
      if (entry.label != label) continue;
      (bySurah[entry.surah] ??= []).add((entry.fromAyah, entry.toAyah));
    }
    for (final day in archive.values) {
      day[label]?.ranges.forEach((surah, ranges) {
        (bySurah[surah] ??= []).addAll(ranges);
      });
    }
    coverage[label]?.forEach((surah, ranges) {
      (bySurah[surah] ??= []).addAll(ranges);
    });
    if (label != unlabeledRecitationLabel) {
      final readBefore = trackSettings[label]?.readBeforeRanges ?? const {};
      for (final range in readBefore.entries) {
        (bySurah[range.key] ??= []).add(range.value);
      }
    }

    return {
      for (final surahEntry in bySurah.entries)
        surahEntry.key: mergeAyahRanges(surahEntry.value),
    };
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

  Set<DateTime> get _recitedLocalDays => {
        for (final entry in entries.values)
          _dateOnly(entry.recitedAt.toLocal()),
        for (final day in archive.keys)
          if (parseActivityDay(day) case final date?) date,
      };

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

  /// Archived days count whole when they fall on or after [sinceLocal]'s
  /// day - a summary no longer knows the time of day.
  int sessionsSince(DateTime sinceLocal) {
    return entries.values
            .where((entry) => !entry.recitedAt.toLocal().isBefore(sinceLocal))
            .length +
        _archivedSince(sinceLocal)
            .fold(0, (sum, summary) => sum + summary.sessions);
  }

  int versesSince(DateTime sinceLocal) {
    return entries.values
            .where((entry) => !entry.recitedAt.toLocal().isBefore(sinceLocal))
            .fold(0, (sum, entry) => sum + entry.versesRecited) +
        _archivedSince(sinceLocal)
            .fold(0, (sum, summary) => sum + summary.verses);
  }

  Iterable<RecitationDaySummary> _archivedSince(DateTime sinceLocal) sync* {
    final since = _dateOnly(sinceLocal);
    for (final day in archive.entries) {
      final date = parseActivityDay(day.key);
      if (date == null || date.isBefore(since)) continue;
      yield* day.value.values;
    }
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
    for (final archived in archive.entries) {
      final day = parseActivityDay(archived.key);
      if (day == null || day.isBefore(start) || day.isAfter(today)) continue;
      counts[day] = (counts[day] ?? 0) +
          archived.value.values.fold(0, (sum, summary) => sum + summary.verses);
    }
    return counts;
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
