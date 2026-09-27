import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../utils/shared_preferences.dart';

/// One zikr in the "most recited this week" list.
@immutable
class CommunityTopZikr {
  const CommunityTopZikr({
    required this.uid,
    required this.title,
    required this.recitations,
  });

  final String uid;
  final String title;
  final int recitations;
}

/// One day of the community sparkline.
@immutable
class CommunityDay {
  const CommunityDay({required this.day, required this.recitations});

  final DateTime day;
  final int recitations;
}

/// The anonymous, app-wide summary `publishCommunityStats` (functions/src)
/// publishes hourly to `public/community`.
///
/// "Recitations" here are zikr *opens* - the same counts the usage dashboard
/// ranks by, one per open from any entry point. The completion counts the
/// function also publishes (`c`) are left unread: they depend on the reading
/// heuristic in zikr_page.dart, which undercounted until it was revised.
@immutable
class CommunityStats {
  const CommunityStats({
    required this.updatedAt,
    required this.weekRecitations,
    required this.allTimeRecitations,
    required this.days,
    required this.top,
  });

  /// Null for anything unrecognisable, so a malformed or not-yet-published
  /// node hides the card rather than showing zeroes.
  static CommunityStats? fromJson(dynamic value) {
    if (value is! Map) return null;
    final updatedMs = _int(value['updatedAt']);
    if (updatedMs <= 0) return null;
    final week = value['week'];
    final allTime = value['allTime'];

    final days = <CommunityDay>[];
    final rawDays = value['days'];
    if (rawDays is List) {
      for (final raw in rawDays) {
        if (raw is! Map) continue;
        final parsed = DateTime.tryParse(raw['d']?.toString() ?? '');
        if (parsed == null) continue;
        days.add(CommunityDay(day: parsed, recitations: _int(raw['o'])));
      }
    }

    final top = <CommunityTopZikr>[];
    final rawTop = value['top'];
    if (rawTop is List) {
      for (final raw in rawTop) {
        if (raw is! Map) continue;
        final uid = raw['uid']?.toString() ?? '';
        final title = raw['title']?.toString().trim() ?? '';
        if (uid.isEmpty || title.isEmpty) continue;
        top.add(CommunityTopZikr(
          uid: uid,
          title: title,
          recitations: _int(raw['o']),
        ));
      }
    }

    return CommunityStats(
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedMs),
      weekRecitations: week is Map ? _int(week['o']) : 0,
      allTimeRecitations: allTime is Map ? _int(allTime['o']) : 0,
      days: days,
      top: top,
    );
  }

  final DateTime updatedAt;
  final int weekRecitations;
  final int allTimeRecitations;
  final List<CommunityDay> days;
  final List<CommunityTopZikr> top;

  static int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

/// Reads the public community summary, at most once per [refreshInterval].
///
/// The summary only changes hourly and nobody needs it to the minute, so
/// every other visit to the stats screen is served from SharedPreferences:
/// no network, and the card still shows offline.
class CommunityStatsService {
  CommunityStatsService({
    Future<Object?> Function()? fetch,
    DateTime Function()? clock,
  })  : _fetch = fetch ?? _fetchFromDatabase,
        _clock = clock ?? DateTime.now;

  static final CommunityStatsService instance = CommunityStatsService();

  static const String _cacheKey = 'community_stats_cache_v1';
  static const String _fetchedAtKey = 'community_stats_fetched_at_ms';
  static const Duration refreshInterval = Duration(hours: 6);

  final Future<Object?> Function() _fetch;
  final DateTime Function() _clock;
  Future<CommunityStats?>? _inFlight;

  CommunityStats? get cached {
    if (!SP.isInitialized) return null;
    final raw = SP.prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      return CommunityStats.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// The cached summary if it is fresh enough, otherwise one fetch. Falls back
  /// to whatever was cached when offline.
  Future<CommunityStats?> load({bool force = false}) {
    return _inFlight ??= _load(force).whenComplete(() => _inFlight = null);
  }

  Future<CommunityStats?> _load(bool force) async {
    if (!SP.isInitialized) return null;
    final fetchedAt = SP.prefs.getInt(_fetchedAtKey);
    if (!force && fetchedAt != null) {
      final age =
          _clock().difference(DateTime.fromMillisecondsSinceEpoch(fetchedAt));
      if (!age.isNegative && age < refreshInterval) return cached;
    }

    try {
      // No client-side timeout: the database SDK fails an offline get() on
      // its own, and the screen shows the cached summary while it waits.
      final value = await _fetch();
      // Recorded even when nothing is published yet, so a missing node is not
      // re-requested on every visit.
      await SP.prefs.setInt(_fetchedAtKey, _clock().millisecondsSinceEpoch);
      final parsed = CommunityStats.fromJson(value);
      if (parsed == null) return cached;
      await SP.prefs.setString(_cacheKey, jsonEncode(value));
      return parsed;
    } catch (error) {
      debugPrint('CommunityStatsService: fetch failed: $error');
      return cached;
    }
  }

  static Future<Object?> _fetchFromDatabase() async {
    if (Firebase.apps.isEmpty) return null;
    final snapshot =
        await FirebaseDatabase.instance.ref('public/community').get();
    return _plain(snapshot.value);
  }

  /// The database plugin hands back `Map<Object?, Object?>`, which
  /// [jsonEncode] rejects; normalise to string keys throughout.
  static Object? _plain(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _plain(entry.value),
      };
    }
    if (value is List) return value.map(_plain).toList();
    return value;
  }
}
