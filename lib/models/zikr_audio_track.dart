/// One recitation recording attached to a zikr.
///
/// Tracks are hot-linked from duas.org rather than mirrored, so a track is
/// just a URL plus the label duas.org gives it. A zikr can carry several —
/// Salat Jafar-e-Tayyar, for instance, has a separate recording for the dua
/// after the salat.
class ZikrAudioTrack {
  final String url;
  final String? label;

  const ZikrAudioTrack({required this.url, this.label});

  /// Parses the `audio` field of a zikr document, tolerating anything that is
  /// not the expected shape — a malformed entry should cost the player, not
  /// the whole page.
  static List<ZikrAudioTrack> listFrom(dynamic raw) {
    if (raw is! List) return const [];

    final tracks = <ZikrAudioTrack>[];
    final seen = <String>{};
    for (final entry in raw) {
      if (entry is! Map) continue;
      final url = entry['url']?.toString().trim() ?? '';
      // Mirrors buildAudioPayload in scripts/build_zikr_release.js: iOS blocks
      // cleartext and the web build is served over https, so an http track
      // could never play anyway.
      if (!url.startsWith('https://')) continue;
      if (!seen.add(url)) continue;

      final label = entry['label']?.toString().trim();
      tracks.add(ZikrAudioTrack(
        url: url,
        label: label == null || label.isEmpty ? null : label,
      ));
    }
    return tracks;
  }

  @override
  bool operator ==(Object other) =>
      other is ZikrAudioTrack && other.url == url && other.label == label;

  @override
  int get hashCode => Object.hash(url, label);

  @override
  String toString() => 'ZikrAudioTrack(url: $url, label: $label)';
}
