import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/zikr_audio_track.dart';
import 'analytics_service.dart';

/// Recitations the reader has saved to the device for offline listening.
///
/// Streaming stays the default - the whole corpus is about a gigabyte - so
/// nothing is downloaded until the reader asks, one zikr from its player or a
/// whole playlist at once. A saved track lives under the app support
/// directory as `zikr_audio/<file name>`, the same name it has in the R2
/// bucket, so what is on disk is simply what is in that folder: no separate
/// index to fall out of step with it.
///
/// Players ask [sourceUri] for each track and get the local file when there
/// is one, the bucket URL otherwise, so a saved track plays with no signal
/// and an unsaved one still streams.
///
/// Not available on web, where there is no file system to save to.
class AudioDownloadStore extends ChangeNotifier {
  AudioDownloadStore._();

  static final AudioDownloadStore instance = AudioDownloadStore._();

  static const String folderName = 'zikr_audio';

  /// Whether this platform can save recitations at all.
  static bool get isSupported => !kIsWeb;

  Directory? _dir;
  Future<void>? _loading;
  final Set<String> _saved = {};

  /// url -> fraction downloaded (null while the size is unknown) for every
  /// track currently downloading or waiting its turn.
  final Map<String, double?> _progress = {};
  final List<ZikrAudioTrack> _queue = [];
  final Set<String> _cancelled = {};

  /// urls whose last download attempt failed, until they are retried.
  final Set<String> _failed = {};
  bool _isRunning = false;
  HttpClient? _client;

  /// Scans the download folder once; later calls return the same future.
  Future<void> load() {
    if (!isSupported) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final root = await getApplicationSupportDirectory();
      await _useDirectory(Directory('${root.path}/$folderName'));
    } catch (error) {
      debugPrint('Unable to open the audio download folder: $error');
      _loading = null;
    }
  }

  Future<void> _useDirectory(Directory dir) async {
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    _saved.clear();
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      // A .part file is a download the app was killed in the middle of.
      if (name.endsWith('.part')) {
        unawaited(entity.delete().catchError((_) => entity));
        continue;
      }
      _saved.add(name);
    }
    notifyListeners();
  }

  @visibleForTesting
  Future<void> useDirectoryForTest(Directory dir) {
    _progress.clear();
    _queue.clear();
    _cancelled.clear();
    _failed.clear();
    return _loading = _useDirectory(dir);
  }

  /// The name [track] is saved under: its file name in the bucket, with
  /// anything a file system might object to replaced.
  static String fileNameFor(ZikrAudioTrack track) {
    final segments = Uri.parse(track.url).pathSegments;
    final name = segments.isEmpty ? track.url : segments.last;
    return name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  File? _fileFor(ZikrAudioTrack track) {
    final dir = _dir;
    return dir == null ? null : File('${dir.path}/${fileNameFor(track)}');
  }

  bool isDownloaded(ZikrAudioTrack track) =>
      _saved.contains(fileNameFor(track));

  bool isDownloading(ZikrAudioTrack track) => _progress.containsKey(track.url);

  /// How far along [track]'s download is, 0-1, or null when it is queued or
  /// its size is not known yet.
  double? progressOf(ZikrAudioTrack track) => _progress[track.url];

  bool allDownloaded(Iterable<ZikrAudioTrack> tracks) =>
      tracks.isNotEmpty && tracks.every(isDownloaded);

  bool anyDownloaded(Iterable<ZikrAudioTrack> tracks) =>
      tracks.any(isDownloaded);

  bool anyDownloading(Iterable<ZikrAudioTrack> tracks) =>
      tracks.any(isDownloading);

  /// Whether any of [tracks] failed to download last time it was tried - no
  /// signal, say, or a file gone from the bucket.
  bool anyFailed(Iterable<ZikrAudioTrack> tracks) =>
      tracks.any((track) => _failed.contains(track.url));

  /// Overall progress across [tracks], 0-1, counting saved tracks as done
  /// and each in-flight one by how far it has got.
  double overallProgress(List<ZikrAudioTrack> tracks) {
    if (tracks.isEmpty) return 0;
    var done = 0.0;
    for (final track in tracks) {
      if (isDownloaded(track)) {
        done += 1;
      } else {
        done += _progress[track.url] ?? 0;
      }
    }
    return done / tracks.length;
  }

  /// Where a player should load [track] from: the saved file when there is
  /// one, the bucket otherwise.
  Uri sourceUri(ZikrAudioTrack track) {
    final file = isDownloaded(track) ? _fileFor(track) : null;
    return file == null ? Uri.parse(track.url) : Uri.file(file.path);
  }

  /// Queues every track in [tracks] not already saved or on its way. They
  /// download one at a time, so a playlist does not open a dozen connections
  /// at once and the first zikr is ready soonest.
  Future<void> download(Iterable<ZikrAudioTrack> tracks) async {
    if (!isSupported) return;
    await load();
    if (_dir == null) return;
    var added = 0;
    for (final track in tracks) {
      if (isDownloaded(track) || isDownloading(track)) continue;
      _cancelled.remove(track.url);
      _failed.remove(track.url);
      _progress[track.url] = null;
      _queue.add(track);
      added++;
    }
    if (added == 0) return;
    notifyListeners();
    unawaited(AnalyticsService.feature(
      'zikr_audio_download',
      label: 'Zikr audio downloaded',
      parameters: {'track_count': added},
    ));
    unawaited(_drain());
  }

  /// Stops [tracks] downloading, dropping any still queued.
  void cancel(Iterable<ZikrAudioTrack> tracks) {
    var changed = false;
    for (final track in tracks) {
      if (!_progress.containsKey(track.url)) continue;
      _progress.remove(track.url);
      _cancelled.add(track.url);
      _queue.removeWhere((queued) => queued.url == track.url);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Deletes [tracks]' saved files; they stream again from then on.
  Future<void> remove(Iterable<ZikrAudioTrack> tracks) async {
    final list = tracks.toList();
    cancel(list);
    for (final track in list) {
      final file = _fileFor(track);
      if (file == null) continue;
      _saved.remove(fileNameFor(track));
      try {
        if (await file.exists()) await file.delete();
      } catch (error) {
        debugPrint('Unable to delete saved audio ${file.path}: $error');
      }
    }
    notifyListeners();
  }

  /// Every saved recording's size in bytes, for the reader deciding what to
  /// clear.
  Future<int> totalBytes() async {
    await load();
    final dir = _dir;
    if (dir == null) return 0;
    var total = 0;
    for (final name in _saved) {
      try {
        total += await File('${dir.path}/$name').length();
      } catch (_) {}
    }
    return total;
  }

  Future<void> _drain() async {
    if (_isRunning) return;
    _isRunning = true;
    try {
      while (_queue.isNotEmpty) {
        final track = _queue.removeAt(0);
        await _fetch(track);
      }
    } finally {
      _isRunning = false;
      _client?.close();
      _client = null;
    }
  }

  Future<void> _fetch(ZikrAudioTrack track) async {
    final file = _fileFor(track);
    if (file == null || isDownloaded(track)) {
      _progress.remove(track.url);
      notifyListeners();
      return;
    }
    final part = File('${file.path}.part');
    IOSink? sink;
    try {
      final client = _client ??= HttpClient();
      final request = await client.getUrl(Uri.parse(track.url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}',
            uri: Uri.parse(track.url));
      }
      final total = response.contentLength;
      var received = 0;
      var lastReported = -1.0;
      sink = part.openWrite();
      await for (final chunk in response) {
        if (_cancelled.contains(track.url)) break;
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          final fraction = received / total;
          // A notification per 1% is plenty for a progress ring.
          if (fraction - lastReported >= 0.01) {
            lastReported = fraction;
            _progress[track.url] = fraction;
            notifyListeners();
          }
        }
      }
      await sink.close();
      sink = null;

      if (_cancelled.remove(track.url)) {
        await part.delete();
        return;
      }
      if (total > 0 && received != total) {
        throw HttpException('Download cut short ($received of $total bytes)',
            uri: Uri.parse(track.url));
      }
      await part.rename(file.path);
      _saved.add(fileNameFor(track));
    } catch (error) {
      debugPrint('Audio download failed for ${track.url}: $error');
      if (!_cancelled.contains(track.url)) _failed.add(track.url);
      await sink?.close().catchError((_) {});
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {}
    } finally {
      _cancelled.remove(track.url);
      _progress.remove(track.url);
      notifyListeners();
    }
  }
}
