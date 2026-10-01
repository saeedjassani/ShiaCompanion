import 'package:flutter/foundation.dart';

import 'zikr_audio_track.dart';

/// A reader-made audio playlist: an ordered list of zikrs whose recitations
/// play back to back.
///
/// Items are whole zikrs, by content uid (the part after `|` for an alias
/// key), because a uid is the one identifier the corpus never changes. A zikr
/// with several recordings (a ziyarah with and without its dua, say) plays
/// only the ones the reader picked in [trackFiles] - its first, until they
/// pick otherwise.
@immutable
class ZikrPlaylist {
  const ZikrPlaylist({
    required this.id,
    required this.name,
    required this.zikrUids,
    required this.updatedAt,
    this.trackFiles = const {},
  });

  factory ZikrPlaylist.fromJson(Map<String, dynamic> json) {
    final rawUids = json['zikrUids'];
    final rawTracks = json['trackFiles'];
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
      trackFiles: rawTracks is Map
          ? Map.unmodifiable({
              for (final entry in rawTracks.entries)
                if (entry.value is List)
                  entry.key.toString(): List<String>.unmodifiable(
                      (entry.value as List).map((file) => file.toString())),
            })
          : const {},
    );
  }

  final String id;
  final String name;
  final List<String> zikrUids;
  final DateTime updatedAt;

  /// The recordings chosen for each zikr that has several, by
  /// [ZikrAudioTrack.file]. A zikr missing here plays its first recording.
  final Map<String, List<String>> trackFiles;

  /// Which of [available] - every recording of zikr [uid] - this playlist
  /// plays, in the zikr's own order. Falls back to the first when nothing was
  /// chosen or every chosen recording has since been removed.
  List<ZikrAudioTrack> tracksFor(String uid, List<ZikrAudioTrack> available) {
    final chosen = trackFiles[uid];
    if (chosen != null) {
      final picked = [
        for (final track in available)
          if (chosen.contains(track.file)) track,
      ];
      if (picked.isNotEmpty) return picked;
    }
    return available.take(1).toList();
  }

  ZikrPlaylist copyWith({
    String? name,
    List<String>? zikrUids,
    DateTime? updatedAt,
    Map<String, List<String>>? trackFiles,
  }) {
    return ZikrPlaylist(
      id: id,
      name: name ?? this.name,
      zikrUids: zikrUids == null ? this.zikrUids : List.unmodifiable(zikrUids),
      updatedAt: updatedAt ?? this.updatedAt,
      trackFiles: trackFiles == null
          ? this.trackFiles
          : Map.unmodifiable({
              for (final entry in trackFiles.entries)
                if (entry.value.isNotEmpty)
                  entry.key: List<String>.unmodifiable(entry.value),
            }),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'zikrUids': zikrUids,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (trackFiles.isNotEmpty) 'trackFiles': trackFiles,
      };
}
