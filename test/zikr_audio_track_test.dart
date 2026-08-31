import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/zikr_audio_track.dart';

void main() {
  group('ZikrAudioTrack.listFrom', () {
    test('parses url and label', () {
      final tracks = ZikrAudioTrack.listFrom([
        {'url': 'https://mp3.duas.org/kumayl.mp3', 'label': 'Dua Kumayl'},
      ]);

      expect(tracks, [
        const ZikrAudioTrack(
          url: 'https://mp3.duas.org/kumayl.mp3',
          label: 'Dua Kumayl',
        ),
      ]);
    });

    test('keeps track order, which is the order duas.org lists them in', () {
      final tracks = ZikrAudioTrack.listFrom([
        {'url': 'https://mp3.duas.org/a.mp3', 'label': 'Salat'},
        {'url': 'https://mp3.duas.org/b.mp3', 'label': 'Dua after'},
      ]);

      expect(tracks.map((t) => t.label), ['Salat', 'Dua after']);
    });

    test('drops non-https urls, which cannot play on iOS or web', () {
      final tracks = ZikrAudioTrack.listFrom([
        {'url': 'http://mp3.duas.org/insecure.mp3'},
        {'url': 'https://mp3.duas.org/ok.mp3'},
      ]);

      expect(tracks.map((t) => t.url), ['https://mp3.duas.org/ok.mp3']);
    });

    test('de-duplicates repeated urls', () {
      final tracks = ZikrAudioTrack.listFrom([
        {'url': 'https://mp3.duas.org/same.mp3', 'label': 'First'},
        {'url': 'https://mp3.duas.org/same.mp3', 'label': 'Second'},
      ]);

      expect(tracks, hasLength(1));
      expect(tracks.single.label, 'First');
    });

    test('treats a blank label as absent so the chip falls back to a number',
        () {
      final tracks = ZikrAudioTrack.listFrom([
        {'url': 'https://mp3.duas.org/a.mp3', 'label': '   '},
      ]);

      expect(tracks.single.label, isNull);
    });

    test('ignores malformed entries rather than failing the whole zikr', () {
      final tracks = ZikrAudioTrack.listFrom([
        'not a map',
        42,
        {'label': 'no url at all'},
        {'url': ''},
        {'url': 'https://mp3.duas.org/good.mp3'},
      ]);

      expect(tracks.map((t) => t.url), ['https://mp3.duas.org/good.mp3']);
    });

    test('returns empty for a missing or non-list audio field', () {
      expect(ZikrAudioTrack.listFrom(null), isEmpty);
      expect(ZikrAudioTrack.listFrom('https://mp3.duas.org/a.mp3'), isEmpty);
      expect(ZikrAudioTrack.listFrom(const {}), isEmpty);
    });
  });
}
