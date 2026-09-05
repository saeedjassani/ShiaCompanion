import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

@immutable
class ZikrBookmark {
  const ZikrBookmark({
    required this.uid,
    required this.title,
    required this.tabIndex,
    required this.scrollOffset,
    required this.updatedAt,
    this.tabTitle,
    this.lineIndex,
    this.version = ZikrBookmarkStore.schemaVersion,
  });

  factory ZikrBookmark.fromJson(Map<String, dynamic> json) {
    return ZikrBookmark(
      version: json['version'] is int
          ? json['version'] as int
          : int.tryParse(json['version']?.toString() ?? '') ??
              ZikrBookmarkStore.schemaVersion,
      uid: json['uid']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      tabIndex: json['tabIndex'] is int
          ? json['tabIndex'] as int
          : int.tryParse(json['tabIndex']?.toString() ?? '') ?? 0,
      tabTitle: json['tabTitle']?.toString(),
      scrollOffset: json['scrollOffset'] is num
          ? (json['scrollOffset'] as num).toDouble()
          : double.tryParse(json['scrollOffset']?.toString() ?? '') ?? 0,
      lineIndex: json['lineIndex'] is int
          ? json['lineIndex'] as int
          : int.tryParse(json['lineIndex']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final int version;
  final String uid;
  final String title;
  final int tabIndex;
  final String? tabTitle;
  final double scrollOffset;

  /// The content line that was at the top of the view when the bookmark was
  /// taken - the very line the [scrollOffset] was read off, measured from the
  /// laid-out list rather than estimated from it. This is what the "you left
  /// off here" marker is drawn on, so the marker stays put no matter what
  /// later changes the layout: showing the audio player, hiding the reading
  /// chrome, or turning transliteration off.
  ///
  /// Null for bookmarks saved before this was recorded; those adopt a line
  /// the first time the bookmark is restored, and are rewritten with it.
  final int? lineIndex;
  final DateTime updatedAt;

  ZikrBookmark copyWith({int? lineIndex}) {
    return ZikrBookmark(
      uid: uid,
      title: title,
      tabIndex: tabIndex,
      tabTitle: tabTitle,
      scrollOffset: scrollOffset,
      lineIndex: lineIndex ?? this.lineIndex,
      updatedAt: updatedAt,
      version: version,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'uid': uid,
      'title': title,
      'tabIndex': tabIndex,
      if (tabTitle != null && tabTitle!.trim().isNotEmpty) 'tabTitle': tabTitle,
      'scrollOffset': scrollOffset,
      if (lineIndex != null) 'lineIndex': lineIndex,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class ZikrBookmarkStore {
  ZikrBookmarkStore._();

  static final ZikrBookmarkStore instance = ZikrBookmarkStore._();
  static const int schemaVersion = 2;

  // The key is deliberately still v1: v2 only added an optional field, so old
  // records stay readable and must keep being read rather than orphaned.
  static const String _storagePrefix = 'zikr_bookmark_v1';

  String _keyForUid(String uid) => '${_storagePrefix}_$uid';

  ZikrBookmark? read(String uid) {
    if (!SP.isInitialized) return null;

    final encoded = SP.prefs.getString(_keyForUid(uid));
    if (encoded == null || encoded.isEmpty) return null;

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;

      final bookmark = ZikrBookmark.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (bookmark.uid.isEmpty) return null;
      return bookmark;
    } catch (error) {
      debugPrint('Unable to read zikr bookmark for $uid: $error');
      return null;
    }
  }

  Future<void> save(ZikrBookmark bookmark) {
    return SP.prefs.setString(
      _keyForUid(bookmark.uid),
      jsonEncode(bookmark.toJson()),
    );
  }

  Future<void> remove(String uid) {
    return SP.prefs.remove(_keyForUid(uid));
  }
}
