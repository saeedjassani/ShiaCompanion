import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants.dart' show items, zikrIndexReady;
import '../l10n/l10n.dart';
import '../utils/deep_links.dart';
import '../utils/quran_index.dart';
import '../utils/slug_registry.dart';
import 'playlist_audio_service.dart';
import 'zikr_audio_index.dart';
import 'zikr_playlist_store.dart';
import 'zikr_translations.dart';

/// The Dart end of Siri, the Shortcuts app and Spotlight on iOS - the App
/// Intents in `ios/Runner/SmartActions/`.
///
/// Two jobs. It keeps the native side's catalog current - the reader's
/// playlists and every zikr, with which ones have a recitation - since
/// Shortcuts and Siri ask what "Thursday Night" or "Dua Kumayl" means
/// without starting Dart. And it carries out what an intent asks for: play a
/// playlist or a dua, or open a zikr, through the same player and links the
/// app's own screens use.
class SmartActionsService {
  SmartActionsService._();

  static final SmartActionsService instance = SmartActionsService._();

  static const MethodChannel _channel =
      MethodChannel('shia_companion/smart_actions');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool _started = false;
  Timer? _catalogTimer;
  String? _lastCatalog;

  void Function(Uri link)? _linkHandler;
  Uri? _pendingLink;

  /// Takes intent calls from then on and tells the native side it can send
  /// them; one that arrived while the app was starting has been waiting.
  Future<void> start() async {
    if (!isSupported || _started) return;
    _started = true;
    _channel.setMethodCallHandler(_handle);
    ZikrPlaylistStore.instance.addListener(syncCatalog);
    zikrIndexReady.addListener(syncCatalog);
    // A new zikr language retitles the duas once its translations load.
    ZikrTranslations.instance.addListener(syncCatalog);
    await _invoke('ready');
    syncCatalog();
  }

  /// Where an "Open Dua" intent's link goes - Home's deep-link queue. Set
  /// once Home is up; a link that came first is handed over then.
  set linkHandler(void Function(Uri link)? handler) {
    _linkHandler = handler;
    final pending = _pendingLink;
    if (handler != null && pending != null) {
      _pendingLink = null;
      handler(pending);
    }
  }

  /// Sends the catalog again shortly, coalescing a burst of playlist edits
  /// into one write. Called when a playlist changes, the zikr index loads,
  /// or the app language changes the titles.
  void syncCatalog() {
    if (!_started) return;
    _catalogTimer?.cancel();
    _catalogTimer = Timer(const Duration(milliseconds: 500), _sendCatalog);
  }

  /// Tells Siri the reader just played [playlistId] from the app, so it can
  /// learn the habit and suggest it - "Thursday Night" on a Thursday evening.
  void donatePlaylist(String playlistId) {
    if (!_started) return;
    unawaited(_invoke('donatePlaylist', {'id': playlistId}));
  }

  Future<void> _sendCatalog() async {
    if (!zikrIndexReady.value) return;
    await ZikrAudioIndex.instance.load();
    final catalog = buildCatalog(
      playlists: [
        for (final playlist in ZikrPlaylistStore.instance.playlists)
          (
            id: playlist.id,
            name: playlist.name,
            displayName: playlist.displayName,
          ),
      ],
      titles: {
        for (final entry in items.entries)
          entry.key.toString(): entry.value?.toString() ?? '',
      },
      displayTitle: zikrDisplayTitle,
      slugFor: (uid) => itemSlugs[uid],
      slugAliasesFor: (uid) => itemSlugAliases[uid] ?? const [],
      hasAudio: (uid) => ZikrAudioIndex.instance.tracksFor(uid).isNotEmpty,
    );
    final encoded = jsonEncode(catalog);
    if (encoded == _lastCatalog) return;
    _lastCatalog = encoded;
    await _invoke('updateCatalog', {
      'playlists': jsonEncode(catalog['playlists']),
      'zikrs': jsonEncode(catalog['zikrs']),
    });
  }

  /// What the native side shows and matches against, as JSON-ready maps.
  ///
  /// A zikr's `name` is its English title with the Arabic script taken out
  /// ("Dua Kumayl", "Surah Ya-Sin"): Siri listens in English or Arabic only,
  /// never Urdu, Persian or Gujarati, so a title in those would never match
  /// what someone says. `subtitle` carries the title in the reader's own zikr
  /// language when that is not English. Menu entries (`~`) are left out, and
  /// so is an alias whose title is its canonical's - it would only be the
  /// same dua twice.
  @visibleForTesting
  static Map<String, List<Map<String, Object>>> buildCatalog({
    required List<({String id, String name, String displayName})> playlists,
    required Map<String, String> titles,
    required String Function(String uid, String title) displayTitle,
    required String? Function(String uid) slugFor,
    required List<String> Function(String uid) slugAliasesFor,
    required bool Function(String contentUid) hasAudio,
  }) {
    final zikrs = <Map<String, Object>>[];
    for (final MapEntry(key: uid, value: title) in titles.entries) {
      if (uid.contains('~') || title.trim().isEmpty) continue;
      final contentUid = uid.split('|').last;
      if (contentUid != uid && titles[contentUid] == title) continue;

      final name = spokenZikrName(contentUid, title);
      if (name.isEmpty) continue;
      final shown = displayTitle(uid, title);
      final slug = slugFor(uid);
      zikrs.add({
        'id': uid,
        'uid': contentUid,
        'name': name,
        if (shown != title) 'subtitle': shown,
        'link': buildZikrDeepLinkUrl(uid: uid, slug: slug),
        'audio': hasAudio(contentUid),
        'keywords': {
          for (final s in [if (slug != null) slug, ...slugAliasesFor(uid)])
            s.replaceAll('-', ' '),
        }.toList(),
      });
    }
    return {
      'playlists': [
        for (final playlist in playlists)
          {
            'id': playlist.id,
            'name': playlist.name,
            if (playlist.displayName != playlist.name)
              'subtitle': playlist.displayName,
          },
      ],
      'zikrs': zikrs,
    };
  }

  /// [title] as Siri can hear it: the Arabic script dropped, and a surah's
  /// "36: Ya-Sin" said as "Surah Ya-Sin".
  @visibleForTesting
  static String spokenZikrName(String contentUid, String title) {
    var name = title
        .replaceAll(_arabicScript, ' ')
        .replaceAll(RegExp(r'\(\s*\)|\[\s*\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (surahForUid(contentUid) != null) {
      name = name.replaceFirst(RegExp(r'^\d+\s*:\s*'), 'Surah ');
    }
    return name.replaceAll(RegExp(r'[\s\-:,]+$'), '');
  }

  static final RegExp _arabicScript = RegExp(
    '[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]+',
  );

  Future<Object?> _handle(MethodCall call) async {
    final arguments = call.arguments is Map
        ? Map<String, Object?>.from(call.arguments as Map)
        : const <String, Object?>{};
    switch (call.method) {
      case 'playPlaylist':
        await _whenIndexReady();
        final playlist =
            ZikrPlaylistStore.instance.byId(arguments['id']?.toString() ?? '');
        if (playlist == null) {
          return _outcome(false, L10n.current.smartActionsPlaylistMissing);
        }
        return _startOutcome(
            await PlaylistAudioService.instance.play(playlist));
      case 'playZikr':
        await _whenIndexReady();
        final uid = arguments['uid']?.toString() ?? '';
        await ZikrAudioIndex.instance.load();
        if (uid.isEmpty || ZikrAudioIndex.instance.tracksFor(uid).isEmpty) {
          return _outcome(false, L10n.current.smartActionsZikrMissing);
        }
        return _startOutcome(await PlaylistAudioService.instance.playZikr(uid));
      case 'openLink':
        final link = Uri.tryParse(arguments['url']?.toString() ?? '');
        if (link == null) return _outcome(false, null);
        final handler = _linkHandler;
        if (handler == null) {
          _pendingLink = link;
        } else {
          handler(link);
        }
        return _outcome(true, null);
    }
    throw MissingPluginException('No handler for ${call.method}');
  }

  /// Waits for the zikr index the titles and playlists come from: an intent
  /// can arrive while the app is still starting. Gives up after a while
  /// rather than leave Siri hanging; the play then reports what it can.
  Future<void> _whenIndexReady() async {
    if (zikrIndexReady.value) return;
    final ready = Completer<void>();
    void listener() {
      if (zikrIndexReady.value && !ready.isCompleted) ready.complete();
    }

    zikrIndexReady.addListener(listener);
    try {
      await ready.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    } finally {
      zikrIndexReady.removeListener(listener);
    }
  }

  static Map<String, Object?> _startOutcome(PlaylistStartResult result) =>
      _outcome(result.isStarted, result.message);

  static Map<String, Object?> _outcome(bool ok, String? message) =>
      {'ok': ok, if (message != null) 'message': message};

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // An iOS build without the SmartActions sources.
    } catch (error) {
      debugPrint('Smart actions $method failed: $error');
    }
  }
}
