import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/zikr_audio_track.dart';
import 'analytics_service.dart';

/// Why a download did not finish, most actionable first.
enum AudioDownloadFailure {
  /// The device ran out of space.
  storage,

  /// No connection, or it dropped part-way.
  network,

  /// The bucket no longer has the file.
  unavailable,
}

/// How one [AudioDownloadStore.download] call ended, once every track in it
/// has either saved or failed. Cancelled tracks count as neither.
@immutable
class AudioDownloadResult {
  const AudioDownloadResult({
    required this.label,
    required this.tracks,
    required this.saved,
    required this.failed,
    this.failure,
  });

  /// What the reader downloaded - a playlist or zikr name - for the message.
  final String? label;

  /// Every track the call asked for, so a Retry can ask again.
  final List<ZikrAudioTrack> tracks;
  final int saved;
  final int failed;
  final AudioDownloadFailure? failure;

  bool get succeeded => failed == 0;
}

class _Batch {
  _Batch(this.label, this.tracks, this.pending);

  final String? label;
  final List<ZikrAudioTrack> tracks;
  final Set<String> pending;
  int saved = 0;
  int failed = 0;
  AudioDownloadFailure? failure;
}

/// Recitations the reader has saved to the device for offline listening.
///
/// Streaming stays the default - the whole corpus is about a gigabyte - so
/// nothing is downloaded until the reader asks, one zikr from its player or a
/// whole playlist at once. A saved track lives under the app support
/// directory as `zikr_audio/<file name>`, the same name it has in the R2
/// bucket, so what is on disk is simply what is in that folder: no separate
/// index to fall out of step with it.
///
/// That folder is kept out of device backups - Android's through
/// res/xml/backup_rules.xml and data_extraction_rules.xml, iOS's by flagging
/// it here - since everything in it can be downloaded again, and a few
/// hundred MB of audio would otherwise push Android over its 25 MB backup
/// quota and stop the reader's settings being backed up at all.
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

  static const MethodChannel _backupChannel =
      MethodChannel('shia_companion/file_backup');

  /// Whether this platform can save recitations at all.
  static bool get isSupported => !kIsWeb;

  Directory? _dir;
  Future<void>? _loading;

  /// Saved file name -> its size in bytes.
  final Map<String, int> _saved = {};

  /// url -> size in bytes, from a HEAD request or a download's
  /// Content-Length, so a button can say how big a download will be.
  final Map<String, int> _sizes = {};
  final Map<String, Future<int?>> _sizing = {};

  /// url -> bytes received so far, for every track downloading or queued.
  final Map<String, int> _received = {};
  final List<ZikrAudioTrack> _queue = [];
  final Set<String> _cancelled = {};

  /// urls whose last download attempt failed, until they are retried.
  final Map<String, AudioDownloadFailure> _failed = {};
  final List<_Batch> _batches = [];
  final StreamController<AudioDownloadResult> _results =
      StreamController<AudioDownloadResult>.broadcast();
  bool _isRunning = false;
  HttpClient? _client;

  /// One event per [download] call once it has finished, for the app-wide
  /// "downloaded" / "couldn't download" message - which has to outlive the
  /// page the download was started from.
  Stream<AudioDownloadResult> get results => _results.stream;

  /// Scans the download folder once; later calls return the same future.
  Future<void> load() {
    if (!isSupported) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final root = await getApplicationSupportDirectory();
      await _useDirectory(Directory('${root.path}/$folderName'));
      if (Platform.isIOS) unawaited(_excludeFromBackup(_dir!));
    } catch (error) {
      debugPrint('Unable to open the audio download folder: $error');
      _loading = null;
    }
  }

  Future<void> _excludeFromBackup(Directory dir) async {
    try {
      await _backupChannel
          .invokeMethod<void>('excludeFromBackup', {'path': dir.path});
    } catch (error) {
      debugPrint('Unable to exclude saved audio from backup: $error');
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
        try {
          await entity.delete();
        } catch (_) {}
        continue;
      }
      try {
        _saved[name] = await entity.length();
      } catch (_) {
        _saved[name] = 0;
      }
    }
    notifyListeners();
  }

  @visibleForTesting
  Future<void> useDirectoryForTest(Directory dir) {
    _received.clear();
    _queue.clear();
    _cancelled.clear();
    _failed.clear();
    _batches.clear();
    _sizes.clear();
    _sizing.clear();
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
      _saved.containsKey(fileNameFor(track));

  bool isDownloading(ZikrAudioTrack track) => _received.containsKey(track.url);

  bool allDownloaded(Iterable<ZikrAudioTrack> tracks) =>
      tracks.isNotEmpty && tracks.every(isDownloaded);

  bool anyDownloaded(Iterable<ZikrAudioTrack> tracks) =>
      tracks.any(isDownloaded);

  bool anyDownloading(Iterable<ZikrAudioTrack> tracks) =>
      tracks.any(isDownloading);

  /// Whether any of [tracks] failed to download last time it was tried - no
  /// signal, say, or a file gone from the bucket - and has not been saved
  /// since.
  bool anyFailed(Iterable<ZikrAudioTrack> tracks) => tracks
      .any((track) => _failed.containsKey(track.url) && !isDownloaded(track));

  /// The worst reason any of [tracks] last failed for.
  AudioDownloadFailure? failureOf(Iterable<ZikrAudioTrack> tracks) {
    AudioDownloadFailure? worst;
    for (final track in tracks) {
      final failure = _failed[track.url];
      if (failure != null && (worst == null || failure.index < worst.index)) {
        worst = failure;
      }
    }
    return worst;
  }

  /// [track]'s size in bytes, when known: from disk once saved, otherwise
  /// from [fetchSizes] or its download so far.
  int? sizeOf(ZikrAudioTrack track) =>
      _saved[fileNameFor(track)] ?? _sizes[track.url];

  /// Bytes still to download to have all of [tracks] saved, or null while
  /// any of their sizes is unknown.
  int? bytesToDownload(Iterable<ZikrAudioTrack> tracks) {
    var total = 0;
    for (final track in tracks) {
      if (isDownloaded(track)) continue;
      final size = _sizes[track.url];
      if (size == null) return null;
      total += size - (_received[track.url] ?? 0);
    }
    return total;
  }

  /// Bytes [tracks] take up on the device.
  int savedBytesOf(Iterable<ZikrAudioTrack> tracks) {
    var total = 0;
    for (final track in {...tracks.map(fileNameFor)}) {
      total += _saved[track] ?? 0;
    }
    return total;
  }

  /// Every saved recording's size in bytes together.
  int get totalSavedBytes => _saved.values.fold(0, (sum, size) => sum + size);

  /// The names of every file saved, including any no zikr names any more.
  Iterable<String> get savedFileNames => _saved.keys;

  /// Asks the bucket how big each of [tracks] is, so a Download button can
  /// say so before the reader commits to it. Quiet about failures - a size
  /// is a nicety - and cached, so reopening a page asks nothing.
  Future<void> fetchSizes(Iterable<ZikrAudioTrack> tracks) async {
    if (!isSupported) return;
    await load();
    final pending = <Future<int?>>[];
    for (final track in tracks) {
      if (isDownloaded(track) || _sizes.containsKey(track.url)) continue;
      pending.add(_sizing[track.url] ??= _head(track));
    }
    if (pending.isEmpty) return;
    await Future.wait(pending);
    notifyListeners();
  }

  Future<int?> _head(ZikrAudioTrack track) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.headUrl(Uri.parse(track.url));
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      await response.drain<void>();
      if (response.statusCode == HttpStatus.ok && response.contentLength > 0) {
        return _sizes[track.url] = response.contentLength;
      }
    } catch (_) {
      // No size is a button without a number, not an error.
    } finally {
      client.close();
      _sizing.remove(track.url);
    }
    return null;
  }

  /// Overall progress across [tracks], 0-1: by bytes when every size is
  /// known, so one long dua does not sit at "90%" for most of the download,
  /// otherwise by how many tracks are done.
  double overallProgress(List<ZikrAudioTrack> tracks) {
    if (tracks.isEmpty) return 0;
    var totalBytes = 0;
    var doneBytes = 0;
    var bytesKnown = true;
    var doneTracks = 0.0;
    for (final track in tracks) {
      final size = sizeOf(track);
      final received = _received[track.url] ?? 0;
      if (isDownloaded(track)) {
        doneTracks += 1;
        doneBytes += size ?? 0;
      } else {
        if (size != null && size > 0) doneTracks += received / size;
        doneBytes += received;
      }
      if (size == null) {
        bytesKnown = false;
      } else {
        totalBytes += size;
      }
    }
    final fraction = bytesKnown && totalBytes > 0
        ? doneBytes / totalBytes
        : doneTracks / tracks.length;
    return fraction.clamp(0, 1).toDouble();
  }

  /// Where a player should load [track] from: the saved file when there is
  /// one, the bucket otherwise.
  Uri sourceUri(ZikrAudioTrack track) {
    final file = isDownloaded(track) ? _fileFor(track) : null;
    return file == null ? Uri.parse(track.url) : Uri.file(file.path);
  }

  /// Queues every track in [tracks] not already saved or on its way, and
  /// reports on [results] once they have all finished, naming them [label].
  /// They download one at a time, so a playlist does not open a dozen
  /// connections at once and the first zikr is ready soonest.
  Future<void> download(
    Iterable<ZikrAudioTrack> tracks, {
    String? label,
  }) async {
    if (!isSupported) return;
    await load();
    if (_dir == null) return;
    final all = tracks.toList();
    final added = <String>{};
    for (final track in all) {
      if (isDownloaded(track) || isDownloading(track)) continue;
      if (!added.add(track.url)) continue;
      _cancelled.remove(track.url);
      _failed.remove(track.url);
      _received[track.url] = 0;
      _queue.add(track);
    }
    if (added.isEmpty) return;
    _batches.add(_Batch(label, all, added));
    notifyListeners();
    unawaited(AnalyticsService.feature(
      'zikr_audio_download',
      label: 'Zikr audio downloaded',
      parameters: {'track_count': added.length},
    ));
    unawaited(_drain());
  }

  /// Stops [tracks] downloading, dropping any still queued.
  void cancel(Iterable<ZikrAudioTrack> tracks) {
    var changed = false;
    for (final track in tracks) {
      if (_received.remove(track.url) == null) continue;
      _cancelled.add(track.url);
      _queue.removeWhere((queued) => queued.url == track.url);
      _settle(track.url, cancelled: true);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Deletes [tracks]' saved files; they stream again from then on.
  Future<void> remove(Iterable<ZikrAudioTrack> tracks) async {
    final list = tracks.toList();
    cancel(list);
    await _deleteNames(list.map(fileNameFor));
  }

  /// Deletes every saved recording, whichever zikr it belongs to.
  Future<void> removeAll() async {
    // Queued tracks have a _received entry too, so this covers them.
    cancel([
      for (final url in [..._received.keys]) ZikrAudioTrack(url: url),
    ]);
    await _deleteNames([..._saved.keys]);
  }

  Future<void> _deleteNames(Iterable<String> names) async {
    final dir = _dir;
    if (dir == null) return;
    for (final name in names.toSet()) {
      _saved.remove(name);
      final file = File('${dir.path}/$name');
      try {
        if (await file.exists()) await file.delete();
      } catch (error) {
        debugPrint('Unable to delete saved audio ${file.path}: $error');
      }
    }
    notifyListeners();
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
      _received.remove(track.url);
      _settle(track.url, saved: true);
      notifyListeners();
      return;
    }
    final part = File('${file.path}.part');
    IOSink? sink;
    AudioDownloadFailure? failure;
    try {
      final client = _client ??= HttpClient()
        ..connectionTimeout = const Duration(seconds: 20);
      final request = await client.getUrl(Uri.parse(track.url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        failure = response.statusCode == HttpStatus.notFound ||
                response.statusCode == HttpStatus.forbidden
            ? AudioDownloadFailure.unavailable
            : AudioDownloadFailure.network;
        throw HttpException('HTTP ${response.statusCode}',
            uri: Uri.parse(track.url));
      }
      final total = response.contentLength;
      if (total > 0) _sizes[track.url] = total;
      var received = 0;
      var lastReported = 0;
      sink = part.openWrite();
      // A connection that goes quiet mid-download (a lift, a tunnel) must
      // fail rather than leave the ring spinning forever.
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        if (_cancelled.contains(track.url)) break;
        sink.add(chunk);
        received += chunk.length;
        // A rebuild per 1% (or per 256 KB when the size is unknown) is
        // plenty for a progress ring.
        final step = total > 0 ? total ~/ 100 : 256 * 1024;
        if (received - lastReported >= step) {
          lastReported = received;
          _received[track.url] = received;
          notifyListeners();
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (_cancelled.remove(track.url)) {
        await part.delete();
        return;
      }
      if (total > 0 && received != total) {
        failure = AudioDownloadFailure.network;
        throw HttpException('Download cut short ($received of $total bytes)',
            uri: Uri.parse(track.url));
      }
      await part.rename(file.path);
      _saved[fileNameFor(track)] = received;
      _received.remove(track.url);
      _settle(track.url, saved: true);
    } catch (error) {
      debugPrint('Audio download failed for ${track.url}: $error');
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {}
      if (!_cancelled.contains(track.url)) {
        failure ??= _classify(error);
        _failed[track.url] = failure;
        _received.remove(track.url);
        _settle(track.url, failure: failure);
      }
    } finally {
      _cancelled.remove(track.url);
      _received.remove(track.url);
      notifyListeners();
    }
  }

  static AudioDownloadFailure _classify(Object error) {
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      // ENOSPC on Linux/Android (28) and Darwin (28 as well).
      if (code == 28) return AudioDownloadFailure.storage;
      final message =
          '${error.message} ${error.osError?.message}'.toLowerCase();
      if (message.contains('no space')) return AudioDownloadFailure.storage;
    }
    return AudioDownloadFailure.network;
  }

  /// Marks [url] finished in every batch waiting on it, and reports each
  /// batch that has nothing left.
  void _settle(
    String url, {
    bool saved = false,
    bool cancelled = false,
    AudioDownloadFailure? failure,
  }) {
    for (final batch in [..._batches]) {
      if (!batch.pending.remove(url)) continue;
      if (saved) batch.saved++;
      if (failure != null) {
        batch.failed++;
        if (batch.failure == null || failure.index < batch.failure!.index) {
          batch.failure = failure;
        }
      }
      if (batch.pending.isNotEmpty) continue;
      _batches.remove(batch);
      // A batch the reader cancelled outright reports nothing: they know.
      if (batch.saved == 0 && batch.failed == 0) continue;
      _results.add(AudioDownloadResult(
        label: batch.label,
        tracks: batch.tracks,
        saved: batch.saved,
        failed: batch.failed,
        failure: batch.failure,
      ));
    }
    if (cancelled) _failed.remove(url);
  }
}

/// "12.3 MB", "850 KB" - a size the way a phone's storage screen shows it.
String formatAudioBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    final mb = bytes / (1024 * 1024);
    return '${mb >= 100 ? mb.round() : mb.toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).ceil()} KB';
}
