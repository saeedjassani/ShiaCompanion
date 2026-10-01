import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shia_companion/constants.dart';

void main() {
  late Directory root;
  late Directory pickerCache;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('custom_audio_test');
    pickerCache = await Directory('${root.path}/cache/file_picker/1')
        .create(recursive: true);
    PathProviderPlatform.instance = _TempDirPathProvider('${root.path}/support');
  });

  tearDown(() => root.delete(recursive: true));

  Future<File> pick(String name, String content) =>
      File('${pickerCache.path}/$name').writeAsString(content);

  test('the copy lives outside the picker cache, under its original name',
      () async {
    final kept = await keepCustomAudioFile(
      await pick('my azan.mp3', 'audio'),
      scope: 'Zuhr',
    );

    expect(kept, startsWith('${root.path}/support/custom_azan/Zuhr/'));
    expect(kept.split('/').last, 'my azan.mp3');
    expect(await File(kept).readAsString(), 'audio');

    // Clearing the picker's cache, as Android may, leaves the copy intact.
    await pickerCache.delete(recursive: true);
    expect(await File(kept).exists(), isTrue);
  });

  test('picking again replaces that scope\'s file with a new path', () async {
    final first = await keepCustomAudioFile(
      await pick('a.mp3', 'first'),
      scope: 'Zuhr',
    );
    // A different path every time, even for the same name, so a cached
    // notification sound keyed on the path is never reused for new audio.
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final second = await keepCustomAudioFile(
      await pick('a.mp3', 'second'),
      scope: 'Zuhr',
    );

    expect(second, isNot(first));
    expect(await File(first).exists(), isFalse);
    expect(await File(second).readAsString(), 'second');
  });

  test('each scope keeps its own file', () async {
    final zuhr = await keepCustomAudioFile(
      await pick('zuhr.mp3', 'z'),
      scope: 'Zuhr',
    );
    final appDefault = await keepCustomAudioFile(
      await pick('default.mp3', 'd'),
      scope: 'default',
    );

    expect(await File(zuhr).exists(), isTrue);
    expect(await File(appDefault).exists(), isTrue);
  });
}

class _TempDirPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempDirPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
