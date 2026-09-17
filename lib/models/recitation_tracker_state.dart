import 'package:flutter/foundation.dart';

/// One logged recitation — a real verse range someone read, under a label of
/// their own choosing ("Family", "Personal", "Majlis"), so the same person
/// can keep separate counts and streaks for separate contexts.
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

  Map<String, Object> toJson() => {
        'id': id,
        'label': label,
        'recitedAt': recitedAt.toUtc().toIso8601String(),
        'surah': surah,
        'fromAyah': fromAyah,
        'toAyah': toAyah,
      };
}

/// Every recitation logged, keyed by [RecitationEntry.id].
///
/// A map keyed by id rather than a list: adding or removing the same entry
/// twice — the shape an offline retry or a replayed pending operation takes —
/// collapses to one change instead of a duplicate, with no separate
/// deduplication step needed.
@immutable
class RecitationTrackerState {
  RecitationTrackerState([Map<String, RecitationEntry>? entries])
      : entries = Map.unmodifiable(entries ?? const {});

  factory RecitationTrackerState.fromJson(dynamic value) {
    if (value is! Map) return empty;

    final entries = <String, RecitationEntry>{};
    for (final entry in value.entries) {
      final parsed = RecitationEntry.fromJson(entry.value);
      if (parsed != null) entries[parsed.id] = parsed;
    }
    return RecitationTrackerState(entries);
  }

  static final empty = RecitationTrackerState();

  final Map<String, RecitationEntry> entries;

  bool get isEmpty => entries.isEmpty;

  List<RecitationEntry> get mostRecentFirst {
    final list = entries.values.toList()
      ..sort((a, b) => b.recitedAt.compareTo(a.recitedAt));
    return list;
  }

  RecitationTrackerState setEntry(RecitationEntry entry) {
    return RecitationTrackerState({...entries, entry.id: entry});
  }

  RecitationTrackerState removeEntry(String id) {
    if (!entries.containsKey(id)) return this;
    final next = {...entries}..remove(id);
    return RecitationTrackerState(next);
  }

  /// Unions two states by id. Safe to call with the same addition twice —
  /// that is how a guest-to-user import survives being retried.
  RecitationTrackerState plus(RecitationTrackerState other) {
    if (other.isEmpty) return this;
    return RecitationTrackerState({...entries, ...other.entries});
  }

  Map<String, Object> toJson() => {
        for (final entry in entries.entries) entry.key: entry.value.toJson(),
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

  /// Distinct labels, most-recited first (by verses, not by tap count), so
  /// "Family" and "Personal" settle into a stable order instead of jumping
  /// around alphabetically.
  List<String> get labels {
    final verses = versesByLabel;
    return verses.keys.toList()
      ..sort((a, b) {
        final byVerses = verses[b]!.compareTo(verses[a]!);
        if (byVerses != 0) return byVerses;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
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

  Set<DateTime> get _recitedLocalDays => entries.values
      .map((entry) => _dateOnly(entry.recitedAt.toLocal()))
      .toSet();

  /// Consecutive days up to and including today (or yesterday, so logging
  /// tonight's recitation tomorrow morning does not reset it to zero) on
  /// which at least one verse was recited.
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
