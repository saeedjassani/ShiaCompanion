import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/zikr_audio_track.dart';

void main() {
  group('ZikrAudioTrack.listFrom', () {
    test('resolves a file name against the R2 bucket', () {
      final tracks = ZikrAudioTrack.listFrom([
        {'file': 'dua_kumayl_96k.mp3', 'label': 'Dua Kumayl'},
      ]);

      expect(tracks, [
        const ZikrAudioTrack(
          url: '${zikrAudioBaseUrl}dua_kumayl_96k.mp3',
          label: 'Dua Kumayl',
        ),
      ]);
    });

    test('keeps track order', () {
      final tracks = ZikrAudioTrack.listFrom([
        {'file': 'a.mp3', 'label': 'Salat'},
        {'file': 'b.mp3', 'label': 'Dua after'},
      ]);

      expect(tracks.map((t) => t.label), ['Salat', 'Dua after']);
    });

    test('reads the reciter, which the lock screen shows under the title', () {
      final tracks = ZikrAudioTrack.listFrom([
        {'file': 'a.mp3', 'label': 'Dua Ahad', 'reciter': 'Ali Fani'},
        {'file': 'b.mp3', 'label': 'Dua Kumayl'},
      ]);

      expect(tracks.first.reciter, 'Ali Fani');
      expect(tracks.first.artist, 'Ali Fani');
      expect(tracks.last.reciter, isNull);
      expect(tracks.last.artist, 'Shia Companion',
          reason: 'no reciter falls back to the app, never a source site');
    });

    test('url-encodes the file name', () {
      final tracks = ZikrAudioTrack.listFrom([
        {'file': 'with space.mp3'},
      ]);

      expect(tracks.single.url, '${zikrAudioBaseUrl}with%20space.mp3');
    });

    test('de-duplicates repeated files', () {
      final tracks = ZikrAudioTrack.listFrom([
        {'file': 'same.mp3', 'label': 'First'},
        {'file': 'same.mp3', 'label': 'Second'},
      ]);

      expect(tracks, hasLength(1));
      expect(tracks.single.label, 'First');
    });

    test('treats a blank label or reciter as absent', () {
      final tracks = ZikrAudioTrack.listFrom([
        {'file': 'a.mp3', 'label': '   ', 'reciter': ''},
      ]);

      expect(tracks.single.label, isNull);
      expect(tracks.single.reciter, isNull);
    });

    test('ignores malformed entries rather than failing the whole zikr', () {
      final tracks = ZikrAudioTrack.listFrom([
        'not a map',
        42,
        {'label': 'no file at all'},
        {'file': ''},
        // A full URL is not a file name: all audio is on the R2 bucket.
        {'url': 'https://mp3.duas.org/hotlinked.mp3'},
        {'file': 'good.mp3'},
      ]);

      expect(tracks.map((t) => t.url), ['${zikrAudioBaseUrl}good.mp3']);
    });

    test('returns empty for a missing or non-list entry', () {
      expect(ZikrAudioTrack.listFrom(null), isEmpty);
      expect(ZikrAudioTrack.listFrom('a.mp3'), isEmpty);
      expect(ZikrAudioTrack.listFrom(const {}), isEmpty);
    });
  });
}
