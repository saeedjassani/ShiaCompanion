import 'package:flutter/foundation.dart';

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
    );
  }

  Map<String, Object> toJson() => {
        'id': id,
        'label': label,
        'recitedAt': recitedAt.toUtc().toIso8601String(),
        'surah': surah,
        'fromAyah': fromAyah,
        'toAyah': toAyah,
      };
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
  ])  : entries = Map.unmodifiable(entries ?? const {}),
        customLabels = Set.unmodifiable(customLabels ?? const {});

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

    return RecitationTrackerState(entries, customLabels);
  }

  static final empty = RecitationTrackerState();

  final Map<String, RecitationEntry> entries;

  /// Tracks the user has explicitly created, independent of whether they
  /// have recited anything under them yet — this is what lets a brand new
  /// label show up as a "start reading" card before its first entry.
  final Set<String> customLabels;

  bool get isEmpty => entries.isEmpty && customLabels.isEmpty;

  List<RecitationEntry> get mostRecentFirst {
    final list = entries.values.toList()
      ..sort((a, b) => b.recitedAt.compareTo(a.recitedAt));
    return list;
  }

  RecitationTrackerState setEntry(RecitationEntry entry) {
    final labels = entry.label == unlabeledRecitationLabel
        ? customLabels
        : {...customLabels, entry.label};
    return RecitationTrackerState({...entries, entry.id: entry}, labels);
  }

  RecitationTrackerState removeEntry(String id) {
    if (!entries.containsKey(id)) return this;
    final next = {...entries}..remove(id);
    return RecitationTrackerState(next, customLabels);
  }

  RecitationTrackerState addCustomLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed == unlabeledRecitationLabel) return this;
    if (customLabels.contains(trimmed)) return this;
    return RecitationTrackerState(entries, {...customLabels, trimmed});
  }

  /// Unions two states by id/label. Safe to call with the same addition
  /// twice — that is how a guest-to-user import survives being retried.
  RecitationTrackerState plus(RecitationTrackerState other) {
    if (other.isEmpty) return this;
    return RecitationTrackerState(
      {...entries, ...other.entries},
      {...customLabels, ...other.customLabels},
    );
  }

  Map<String, Object> toJson() => {
        'entries': {
          for (final entry in entries.entries) entry.key: entry.value.toJson(),
        },
        'labels': customLabels.toList(),
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
  VerseKey? resumePositionFor(String label) {
    RecitationEntry? latest;
    for (final entry in entries.values) {
      if (entry.label != label) continue;
      if (latest == null || entry.recitedAt.isAfter(latest.recitedAt)) {
        latest = entry;
      }
    }
    return latest == null ? null : VerseKey(latest.surah, latest.toAyah);
  }

  /// Merged, non-overlapping ayah ranges ever recited under [label], by
  /// surah — the union of every session's range, so re-reading the same
  /// verses repeatedly does not inflate how much of the Quran is "done".
  Map<int, List<(int, int)>> _mergedRangesForLabel(String label) {
    final bySurah = <int, List<(int, int)>>{};
    for (final entry in entries.values) {
      if (entry.label != label) continue;
      (bySurah[entry.surah] ??= []).add((entry.fromAyah, entry.toAyah));
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
