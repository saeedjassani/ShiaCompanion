import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/services/zikr_audio_index.dart';

/// assets/zikr_audio.json is the only place recordings are listed, so these
/// guard its shape and keep audio from creeping back into other files.
void main() {
  final raw = jsonDecode(File(ZikrAudioIndex.assetPath).readAsStringSync())
      as Map<String, dynamic>;

  test('every zikr it names has a content file', () {
    final missing = [
      for (final uid in raw.keys)
        if (!File('assets/zikr/$uid').existsSync()) uid,
    ];
    expect(missing, isEmpty);
  });

  test('every track is a plain R2 file name with a label', () {
    final offenders = <String>[];
    raw.forEach((uid, tracks) {
      if (tracks is! List || tracks.isEmpty) {
        offenders.add('$uid: no tracks');
        return;
      }
      for (final track in tracks) {
        final map = track as Map<String, dynamic>;
        final file = map['file']?.toString() ?? '';
        if (!RegExp(r'^[A-Za-z0-9_.-]+\.mp3$').hasMatch(file)) {
          offenders.add('$uid: file "$file" is not a plain .mp3 name');
        }
        if ((map['label']?.toString().trim() ?? '').isEmpty) {
          offenders.add('$uid: $file has no label');
        }
        final unknown =
            map.keys.toSet().difference({'file', 'label', 'reciter'});
        if (unknown.isNotEmpty) offenders.add('$uid: $file has $unknown');
      }
    });
    expect(offenders, isEmpty);
  });

  test('parses to the same tracks the file lists', () {
    final parsed = ZikrAudioIndex.parse(raw);
    expect(parsed.keys.toSet(), raw.keys.toSet());
    for (final uid in raw.keys) {
      expect(parsed[uid], hasLength((raw[uid] as List).length), reason: uid);
    }
  });

  test('no content file or index entry carries audio of its own', () {
    final offenders = <String>[
      for (final file in Directory('assets/zikr').listSync().whereType<File>())
        if ((jsonDecode(file.readAsStringSync()) as Map).containsKey('audio'))
          file.path,
    ];
    final index =
        jsonDecode(File('assets/zikr.json').readAsStringSync()) as Map;
    index.forEach((uid, entry) {
      if (entry is Map && entry.containsKey('audio')) {
        offenders.add('assets/zikr.json: $uid');
      }
    });
    expect(offenders, isEmpty,
        reason: 'audio belongs in ${ZikrAudioIndex.assetPath} only');
  });
}
