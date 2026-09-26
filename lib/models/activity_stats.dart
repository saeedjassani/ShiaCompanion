import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Days of per-day history each device keeps. Older days are folded into
/// [DeviceActivity.archived] so lifetime totals survive, and the synced
/// document stays a fixed size however long someone has had the app.
const int activityRetentionDays = 400;

/// How many distinct zikrs a device remembers completion counts for. The
/// "most recited" list only ever shows a handful; the cap keeps a reader who
/// has been through the whole corpus from growing the synced document without
/// bound.
const int activityMaxTrackedZikrs = 150;

/// One day's worth of activity on one device.
@immutable
class DayActivity {
  const DayActivity({this.zikrs = 0, this.qaza = 0});

  static DayActivity fromJson(dynamic value) {
    if (value is! Map) return const DayActivity();
    return DayActivity(
      zikrs: _nonNegativeInt(value['z']),
      qaza: _nonNegativeInt(value['q']),
    );
  }

  /// Zikrs read to the end - the same "actually recited, not just opened"
  /// signal zikr_page.dart's `_maybeRecordCompletion` uses for analytics.
  final int zikrs;

  /// Qaza prayers marked as made up.
  final int qaza;

  bool get isActive => zikrs > 0 || qaza > 0;

  DayActivity copyWith({int? zikrs, int? qaza}) => DayActivity(
        zikrs: zikrs ?? this.zikrs,
        qaza: qaza ?? this.qaza,
      );

  DayActivity operator +(DayActivity other) =>
      DayActivity(zikrs: zikrs + other.zikrs, qaza: qaza + other.qaza);

  /// Field-wise max: how two copies of the *same* device's day are reconciled.
  /// A device's own counts only ever grow within a day (an undo aside), so the
  /// larger one is the newer one.
  DayActivity max(DayActivity other) => DayActivity(
        zikrs: math.max(zikrs, other.zikrs),
        qaza: math.max(qaza, other.qaza),
      );

  Map<String, int> toJson() => {
        if (zikrs > 0) 'z': zikrs,
        if (qaza > 0) 'q': qaza,
      };

  @override
  bool operator ==(Object other) =>
      other is DayActivity && other.zikrs == zikrs && other.qaza == qaza;

  @override
  int get hashCode => Object.hash(zikrs, qaza);
}

/// Everything one device has recorded.
///
/// Stats are kept per device rather than as one shared tally so that syncing
/// never needs a read-modify-write: each device only ever writes its own
/// entry, and the account-wide view is the sum over devices. Two phones used
/// on the same day both count, and the same device's data arriving twice
/// (a retry, a stale cache) is reconciled with [merge] instead of being
/// double counted.
@immutable
class DeviceActivity {
  const DeviceActivity({
    this.days = const {},
    this.zikrCounts = const {},
    this.archived = const DayActivity(),
    this.archivedActiveDays = 0,
    this.bestStreak = 0,
  });

  static DeviceActivity fromJson(dynamic value) {
    if (value is! Map) return const DeviceActivity();

    final days = <String, DayActivity>{};
    final rawDays = value['days'];
    if (rawDays is Map) {
      rawDays.forEach((key, day) {
        final dayKey = key.toString();
        if (parseActivityDay(dayKey) == null) return;
        final parsed = DayActivity.fromJson(day);
        if (parsed.isActive) days[dayKey] = parsed;
      });
    }

    final zikrCounts = <String, int>{};
    final rawZikrs = value['zikrs'];
    if (rawZikrs is Map) {
      rawZikrs.forEach((key, count) {
        final uid = key.toString().trim();
        final parsed = _nonNegativeInt(count);
        if (uid.isNotEmpty && parsed > 0) zikrCounts[uid] = parsed;
      });
    }

    return DeviceActivity(
      days: days,
      zikrCounts: zikrCounts,
      archived: DayActivity.fromJson(value['archived']),
      archivedActiveDays: _nonNegativeInt(value['archivedDays']),
      bestStreak: _nonNegativeInt(value['best']),
    );
  }

  /// Keyed by local `yyyy-MM-dd` (see [activityDayKey]).
  final Map<String, DayActivity> days;

  /// Canonical zikr uid → times completed on this device.
  final Map<String, int> zikrCounts;

  /// Totals from days that have aged out of [days].
  final DayActivity archived;
  final int archivedActiveDays;

  /// The longest streak this device has seen, so a streak that has partly
  /// aged out of [days] is not forgotten.
  final int bestStreak;

  bool get isEmpty =>
      days.isEmpty &&
      zikrCounts.isEmpty &&
      archived == const DayActivity() &&
      archivedActiveDays == 0 &&
      bestStreak == 0;

  DeviceActivity copyWith({
    Map<String, DayActivity>? days,
    Map<String, int>? zikrCounts,
    DayActivity? archived,
    int? archivedActiveDays,
    int? bestStreak,
  }) =>
      DeviceActivity(
        days: days ?? this.days,
        zikrCounts: zikrCounts ?? this.zikrCounts,
        archived: archived ?? this.archived,
        archivedActiveDays: archivedActiveDays ?? this.archivedActiveDays,
        bestStreak: bestStreak ?? this.bestStreak,
      );

  DeviceActivity recordZikr(String uid, DateTime now) {
    final key = activityDayKey(now);
    final today = days[key] ?? const DayActivity();
    final nextCounts = Map<String, int>.of(zikrCounts);
    if (uid.isNotEmpty) nextCounts[uid] = (nextCounts[uid] ?? 0) + 1;
    return copyWith(
      days: {...days, key: today.copyWith(zikrs: today.zikrs + 1)},
      zikrCounts: _capZikrCounts(nextCounts),
    ).pruned(now);
  }

  DeviceActivity recordQaza(DateTime now, {int delta = 1}) {
    final key = activityDayKey(now);
    final today = days[key] ?? const DayActivity();
    final next = math.max(0, today.qaza + delta);
    if (next == today.qaza) return this;
    final updated = today.copyWith(qaza: next);
    final nextDays = Map<String, DayActivity>.of(days);
    if (updated.isActive) {
      nextDays[key] = updated;
    } else {
      nextDays.remove(key);
    }
    return copyWith(days: nextDays).pruned(now);
  }

  /// Folds days older than [activityRetentionDays] into the archive.
  DeviceActivity pruned(DateTime now) {
    final cutoff =
        DateTime(now.year, now.month, now.day - (activityRetentionDays - 1));
    var archived = this.archived;
    var archivedDays = archivedActiveDays;
    final kept = <String, DayActivity>{};
    var changed = false;
    days.forEach((key, day) {
      final date = parseActivityDay(key);
      if (date == null) {
        changed = true;
        return;
      }
      if (date.isBefore(cutoff)) {
        archived = archived + day;
        if (day.isActive) archivedDays++;
        changed = true;
      } else {
        kept[key] = day;
      }
    });
    if (!changed) return this;
    return copyWith(
      days: kept,
      archived: archived,
      archivedActiveDays: archivedDays,
    );
  }

  /// Reconciles two copies of the same device's data.
  DeviceActivity merge(DeviceActivity other) {
    final mergedDays = Map<String, DayActivity>.of(days);
    other.days.forEach((key, day) {
      final mine = mergedDays[key];
      mergedDays[key] = mine == null ? day : mine.max(day);
    });
    final mergedZikrs = Map<String, int>.of(zikrCounts);
    other.zikrCounts.forEach((uid, count) {
      mergedZikrs[uid] = math.max(mergedZikrs[uid] ?? 0, count);
    });
    return DeviceActivity(
      days: mergedDays,
      zikrCounts: _capZikrCounts(mergedZikrs),
      archived: archived.max(other.archived),
      archivedActiveDays:
          math.max(archivedActiveDays, other.archivedActiveDays),
      bestStreak: math.max(bestStreak, other.bestStreak),
    );
  }

  Map<String, Object> toJson() => {
        'v': 1,
        'days': {
          for (final entry in days.entries)
            if (entry.value.isActive) entry.key: entry.value.toJson(),
        },
        'zikrs': zikrCounts,
        'archived': archived.toJson(),
        'archivedDays': archivedActiveDays,
        'best': bestStreak,
      };

  @override
  bool operator ==(Object other) =>
      other is DeviceActivity &&
      mapEquals(other.days, days) &&
      mapEquals(other.zikrCounts, zikrCounts) &&
      other.archived == archived &&
      other.archivedActiveDays == archivedActiveDays &&
      other.bestStreak == bestStreak;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(
            days.entries.map((e) => Object.hash(e.key, e.value))),
        Object.hashAllUnordered(
            zikrCounts.entries.map((e) => Object.hash(e.key, e.value))),
        archived,
        archivedActiveDays,
        bestStreak,
      );
}

/// The account-wide (or, signed out, device-wide) view the stats screen shows:
/// every device's activity summed, plus the days on which Quran recitation was
/// logged, which the recitation tracker already keeps and syncs on its own.
class ActivitySummary {
  ActivitySummary({
    required Iterable<DeviceActivity> devices,
    Map<DateTime, int> quranVersesByDay = const {},
    this.quranVersesTotal = 0,
    DateTime? now,
  }) : _now = _dateOnly(now ?? DateTime.now()) {
    final days = <DateTime, DayActivity>{};
    final zikrCounts = <String, int>{};
    var archived = const DayActivity();
    var archivedActiveDays = 0;
    var best = 0;

    for (final device in devices) {
      device.days.forEach((key, day) {
        final date = parseActivityDay(key);
        if (date == null) return;
        days[date] = (days[date] ?? const DayActivity()) + day;
      });
      device.zikrCounts.forEach((uid, count) {
        zikrCounts[uid] = (zikrCounts[uid] ?? 0) + count;
      });
      archived = archived + device.archived;
      archivedActiveDays =
          math.max(archivedActiveDays, device.archivedActiveDays);
      best = math.max(best, device.bestStreak);
    }

    _days = days;
    _quranVersesByDay = {
      for (final entry in quranVersesByDay.entries)
        if (entry.value > 0) _dateOnly(entry.key): entry.value,
    };
    this.zikrCounts = Map.unmodifiable(zikrCounts);
    totalZikrs =
        archived.zikrs + days.values.fold(0, (sum, day) => sum + day.zikrs);
    totalQaza =
        archived.qaza + days.values.fold(0, (sum, day) => sum + day.qaza);
    activeDayCount = archivedActiveDays + _activeDays.length;
    longestStreak = math.max(best, _longestRun(_activeDays));
  }

  final DateTime _now;
  late final Map<DateTime, DayActivity> _days;
  late final Map<DateTime, int> _quranVersesByDay;

  late final Map<String, int> zikrCounts;
  late final int totalZikrs;
  late final int totalQaza;
  final int quranVersesTotal;
  late final int activeDayCount;
  late final int longestStreak;

  late final Set<DateTime> _activeDays = {
    for (final entry in _days.entries)
      if (entry.value.isActive) entry.key,
    ..._quranVersesByDay.keys,
  };

  bool get isEmpty =>
      totalZikrs == 0 && totalQaza == 0 && quranVersesTotal == 0;

  bool isActiveOn(DateTime day) => _activeDays.contains(_dateOnly(day));

  bool get isActiveToday => isActiveOn(_now);

  /// Consecutive active days up to and including today - or up to yesterday,
  /// so a streak is not shown as broken in the morning before the day's first
  /// recitation. Same rule as the recitation tracker's own streak.
  int get currentStreak {
    var cursor = _now;
    if (!_activeDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!_activeDays.contains(cursor)) return 0;
    }
    var streak = 0;
    while (_activeDays.contains(cursor)) {
      streak++;
      cursor = _previousDay(cursor);
    }
    return streak;
  }

  /// How many of the last [days] days (today included) were active.
  int activeDaysInLast(int days) {
    var count = 0;
    for (var i = 0; i < days; i++) {
      if (_activeDays.contains(DateTime(_now.year, _now.month, _now.day - i))) {
        count++;
      }
    }
    return count;
  }

  /// Most-completed zikrs, highest first.
  List<MapEntry<String, int>> topZikrs(int count) {
    final sorted = zikrCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return sorted.take(count).toList();
  }
}

String activityDayKey(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)}';
}

DateTime? parseActivityDay(String key) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  // Reject rollovers like 2026-02-31.
  if (date.month != month || date.day != day) return null;
  return date;
}

int _longestRun(Set<DateTime> days) {
  if (days.isEmpty) return 0;
  final sorted = days.toList()..sort();
  var longest = 1;
  var current = 1;
  for (var i = 1; i < sorted.length; i++) {
    current = _previousDay(sorted[i]) == sorted[i - 1] ? current + 1 : 1;
    if (current > longest) longest = current;
  }
  return longest;
}

/// Calendar-day arithmetic rather than subtracting 24 hours, which lands on
/// 23:00 the previous day across a DST change and would break a streak.
DateTime _previousDay(DateTime day) =>
    DateTime(day.year, day.month, day.day - 1);

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

Map<String, int> _capZikrCounts(Map<String, int> counts) {
  if (counts.length <= activityMaxTrackedZikrs) return counts;
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {
    for (final entry in sorted.take(activityMaxTrackedZikrs))
      entry.key: entry.value,
  };
}

int _nonNegativeInt(dynamic value) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null || parsed < 0) return 0;
  return parsed;
}
