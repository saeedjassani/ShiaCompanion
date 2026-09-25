/// Where every zikr recording is hosted: the app's own Cloudflare R2 bucket.
///
/// assets/zikr_audio.json names each track by its file name alone, so moving
/// the bucket (to a custom domain, say) is this one line.
const String zikrAudioBaseUrl =
    'https://pub-ee9041af06e644c2932c50c137c28aef.r2.dev/';

/// One recitation recording attached to a zikr.
///
/// A zikr can carry several — Salat Jafar-e-Tayyar, for instance, has a
/// separate recording for the dua after the salat.
class ZikrAudioTrack {
  final String url;
  final String? label;

  /// Who recites it, when known - shown under the title on the lock screen.
  final String? reciter;

  const ZikrAudioTrack({required this.url, this.label, this.reciter});

  /// The lock screen's second line: the reciter, or the app when unknown.
  String get artist => reciter ?? 'Shia Companion';

  /// Parses one zikr's entry in assets/zikr_audio.json - a list of
  /// `{"file": ..., "label": ..., "reciter": ...}` - tolerating anything that is not the
  /// expected shape: a malformed entry should cost the player, not the whole
  /// page.
  static List<ZikrAudioTrack> listFrom(dynamic raw) {
    if (raw is! List) return const [];

    final tracks = <ZikrAudioTrack>[];
    final seen = <String>{};
    for (final entry in raw) {
      if (entry is! Map) continue;
      final file = entry['file']?.toString().trim() ?? '';
      if (file.isEmpty) continue;
      final url = '$zikrAudioBaseUrl${Uri.encodeComponent(file)}';
      if (!seen.add(url)) continue;

      tracks.add(ZikrAudioTrack(
        url: url,
        label: _optional(entry['label']),
        reciter: _optional(entry['reciter']),
      ));
    }
    return tracks;
  }

  static String? _optional(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  @override
  bool operator ==(Object other) =>
      other is ZikrAudioTrack &&
      other.url == url &&
      other.label == label &&
      other.reciter == reciter;

  @override
  int get hashCode => Object.hash(url, label, reciter);

  @override
  String toString() =>
      'ZikrAudioTrack(url: $url, label: $label, reciter: $reciter)';
}
