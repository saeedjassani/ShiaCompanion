import 'package:flutter/foundation.dart';

/// A reader-made audio playlist: an ordered list of zikrs whose recitations
/// play back to back.
///
/// Items are whole zikrs, by content uid (the part after `|` for an alias
/// key), because a uid is the one identifier the corpus never changes. A zikr
/// with several recordings contributes all of them, in its own order.
@immutable
class ZikrPlaylist {
  const ZikrPlaylist({
    required this.id,
    required this.name,
    required this.zikrUids,
    required this.updatedAt,
  });

  factory ZikrPlaylist.fromJson(Map<String, dynamic> json) {
    final rawUids = json['zikrUids'];
    return ZikrPlaylist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      zikrUids: rawUids is List
          ? List.unmodifiable(rawUids
              .map((uid) => uid?.toString().trim() ?? '')
              .where((uid) => uid.isNotEmpty))
          : const [],
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final String name;
  final List<String> zikrUids;
  final DateTime updatedAt;

  ZikrPlaylist copyWith({
    String? name,
    List<String>? zikrUids,
    DateTime? updatedAt,
  }) {
    return ZikrPlaylist(
      id: id,
      name: name ?? this.name,
      zikrUids:
          zikrUids == null ? this.zikrUids : List.unmodifiable(zikrUids),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'zikrUids': zikrUids,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}
