import 'package:flutter/foundation.dart';

/// One logged recitation — someone reciting Quran under a label of their own
/// choosing ("Family", "Personal", "Majlis"), so the same person can keep
/// separate counts and streaks for separate contexts.
@immutable
class RecitationEntry {
  const RecitationEntry({
    required this.id,
    required this.label,
    required this.recitedAt,
  });

  /// Returns null rather than a placeholder entry, so a corrupt row is
  /// dropped instead of showing up as a blank one in the list.
  static RecitationEntry? fromJson(dynamic value) {
    if (value is! Map) return null;

    final id = value['id']?.toString().trim() ?? '';
    final label = value['label']?.toString().trim() ?? '';
    final recitedAt = DateTime.tryParse(value['recitedAt']?.toString() ?? '');
    if (id.isEmpty || label.isEmpty || recitedAt == null) return null;

    return RecitationEntry(id: id, label: label, recitedAt: recitedAt);
  }

  final String id;
  final String label;
  final DateTime recitedAt;

  Map<String, Object> toJson() => {
        'id': id,
        'label': label,
        'recitedAt': recitedAt.toUtc().toIso8601String(),
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
  // dashboard never has to keep a counter in sync by hand.
  // ---------------------------------------------------------------------

  int get totalSessions => entries.length;

  Map<String, int> get countsByLabel {
    final counts = <String, int>{};
    for (final entry in entries.values) {
      counts[entry.label] = (counts[entry.label] ?? 0) + 1;
    }
    return counts;
  }

  /// Distinct labels, most-logged first, so "Family" and "Personal" settle
  /// into a stable order instead of jumping around alphabetically.
  List<String> get labels {
    final counts = countsByLabel;
    return counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        if (byCount != 0) return byCount;
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
  /// tonight's recitation tomorrow morning does not reset it to zero).
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

  int countSince(DateTime sinceLocal) {
    return entries.values
        .where((entry) => !entry.recitedAt.toLocal().isBefore(sinceLocal))
        .length;
  }

  /// Sessions per local calendar day for the trailing [days] days (today
  /// included), for a GitHub-style contribution heatmap.
  Map<DateTime, int> dailyCounts(int days) {
    final today = _dateOnly(DateTime.now());
    final start = today.subtract(Duration(days: days - 1));
    final counts = <DateTime, int>{
      for (var i = 0; i < days; i++) start.add(Duration(days: i)): 0,
    };

    for (final entry in entries.values) {
      final day = _dateOnly(entry.recitedAt.toLocal());
      if (day.isBefore(start) || day.isAfter(today)) continue;
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
