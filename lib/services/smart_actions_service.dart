import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants.dart' show items, zikrIndexReady;
import '../l10n/l10n.dart';
import '../models/zikr_playlist.dart';
import '../navigation/home_menu.dart';
import '../utils/deep_links.dart';
import '../utils/quran_index.dart';
import '../utils/slug_registry.dart';
import '../utils/spoken_match.dart';
import '../widgets/app_toast.dart';
import 'playlist_audio_service.dart';
import 'zikr_audio_index.dart';
import 'zikr_playlist_store.dart';
import 'zikr_translations.dart';

/// Where a smart action takes the reader: Home carries it out, once it is up.
sealed class SmartActionTarget {
  const SmartActionTarget();
}

/// An app link: a zikr, a `/play/...` or `/playlist/...` link that also
/// starts it, the Calendar.
final class SmartActionLink extends SmartActionTarget {
  const SmartActionLink(this.link);

  final Uri link;
}

/// A feature of the home menu: Qibla, Tasbeeh, Calendar & Prayer Times.
final class SmartActionFeature extends SmartActionTarget {
  const SmartActionFeature(this.item);

  final HomeMenuItem item;
}

/// Search, starting from [query] (empty for a blank search).
final class SmartActionSearch extends SmartActionTarget {
  const SmartActionSearch(this.query);

  final String query;
}

/// The Dart end of the system's smart features.
///
/// - **iOS**: Siri, the Shortcuts app and Spotlight - the App Intents in
///   `ios/Runner/SmartActions/`.
/// - **Android**: launcher shortcuts (static ones, the playlists and duas
///   the reader uses, and ones pinned to the home screen) and Google
///   Assistant's App Actions - `android/app/src/main/res/xml/shortcuts.xml`
///   and `SmartActions.kt`.
///
/// Two jobs. It keeps the native side's catalog current - the reader's
/// playlists and every zikr, with which ones have a recitation - since
/// Shortcuts and Siri ask what "Thursday Night" or "Dua Kumayl" means
/// without starting Dart, and Android relabels its shortcuts from it. And it
/// carries out what an intent asks for: play a playlist or a dua, or open a
/// zikr, through the same player and links the app's own screens use. On
/// Android an action comes as the words someone said ("play Kumail"), which
/// this matches against the catalog itself.
class SmartActionsService {
  SmartActionsService._();

  static final SmartActionsService instance = SmartActionsService._();

  static const MethodChannel _channel =
      MethodChannel('shia_companion/smart_actions');

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool _started = false;
  Timer? _catalogTimer;
  String? _lastCatalog;
  bool? _canPinShortcuts;

  void Function(SmartActionTarget target)? _navigator;
  SmartActionTarget? _pendingTarget;

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
    await takePendingActions();
  }

  /// Where an intent takes the reader - Home's deep-link queue and menu. Set
  /// once Home is up; a target that came first is handed over then.
  set navigator(void Function(SmartActionTarget target)? navigator) {
    _navigator = navigator;
    final pending = _pendingTarget;
    if (navigator != null && pending != null) {
      _pendingTarget = null;
      navigator(pending);
    }
  }

  void _navigate(SmartActionTarget target) {
    final navigator = _navigator;
    if (navigator == null) {
      _pendingTarget = target;
    } else {
      navigator(target);
    }
  }

  /// Carries out the shortcut taps and Assistant requests Android has
  /// been holding (`SmartActions.kt`). Android keeps them until asked rather
  /// than calling in: the activity they launch can come and go while the
  /// engine - and this isolate - lives on (audio_service keeps it), so
  /// nothing on that side knows whether Dart is listening. Run at start-up,
  /// on every resume, and when Android says one is waiting.
  Future<void> takePendingActions() async {
    if (!_started || !_isAndroid) return;
    List<Object?>? actions;
    try {
      actions = await _channel.invokeListMethod<Object?>('takeActions');
    } on MissingPluginException {
      return;
    } catch (error) {
      debugPrint('Smart actions takeActions failed: $error');
      return;
    }
    for (final action in actions ?? const <Object?>[]) {
      if (action is! Map) continue;
      final method = action['method']?.toString();
      if (method == null) continue;
      final arguments = action['arguments'];
      await _perform(
        method,
        arguments is Map
            ? Map<String, Object?>.from(arguments)
            : const <String, Object?>{},
      );
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

  /// Tells the system the reader just played [playlist] from the app, so it
  /// can learn the habit and suggest it - "Thursday Night" on a Thursday
  /// evening. Siri on iOS; on Android a launcher shortcut that plays it,
  /// which launcher search finds too.
  void donatePlaylist(ZikrPlaylist playlist) {
    if (!_started) return;
    if (_isAndroid) {
      unawaited(_invoke('donateShortcut', playlistShortcut(playlist)));
    } else {
      unawaited(_invoke('donatePlaylist', {'id': playlist.id}));
    }
  }

  /// Tells Android the reader just opened the zikr [uid]: the duas someone
  /// keeps coming back to become launcher shortcuts, and turn up in the
  /// launcher's search - what Spotlight does on iOS, for the duas they read.
  void donateZikr(String uid) {
    if (!_started || !_isAndroid) return;
    final shortcut = zikrShortcut(uid);
    if (shortcut == null) return;
    unawaited(_invoke('donateShortcut', shortcut));
  }

  /// Whether this device can put a shortcut on the home screen - Android
  /// only, and only with a launcher that takes them.
  Future<bool> canPinShortcuts() async {
    if (!_isAndroid) return false;
    if (_canPinShortcuts case final known?) return known;
    try {
      return _canPinShortcuts =
          await _channel.invokeMethod<bool>('canPinShortcuts') ?? false;
    } catch (_) {
      return _canPinShortcuts = false;
    }
  }

  /// Asks the launcher to put a shortcut on the home screen that plays
  /// [playlist]. False when it could not even ask; the launcher's own dialog
  /// then has the reader confirm.
  Future<bool> pinPlaylist(ZikrPlaylist playlist) async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
              'pinShortcut', playlistShortcut(playlist)) ??
          false;
    } catch (error) {
      debugPrint('Smart actions pinShortcut failed: $error');
      return false;
    }
  }

  /// The Android shortcut that plays [playlist]. Its id is the one
  /// `SmartActions.kt` relabels and retires from the catalog by.
  @visibleForTesting
  static Map<String, String> playlistShortcut(ZikrPlaylist playlist) => {
        'id': 'playlist:${playlist.id}',
        'kind': 'playlist',
        'label': playlist.displayName,
        'link': buildPlaylistDeepLinkUrl(playlist.id),
      };

  /// The Android shortcut that opens the zikr [uid], labelled as the
  /// catalog labels it, or null for one the catalog leaves out. An alias
  /// that only repeats its canonical's title is the canonical's shortcut.
  @visibleForTesting
  static Map<String, String>? zikrShortcut(
    String uid, {
    Map<Object?, Object?>? titles,
    String Function(String uid, String title) displayTitle = zikrDisplayTitle,
    String? Function(String uid)? slugFor,
  }) {
    final allTitles = titles ?? items;
    final title = allTitles[uid]?.toString() ?? '';
    if (uid.contains('~') || title.trim().isEmpty) return null;
    final contentUid = uid.split('|').last;
    final id = contentUid != uid && allTitles[contentUid]?.toString() == title
        ? contentUid
        : uid;
    final shown = displayTitle(id, title);
    final label = shown != title ? shown : spokenZikrName(contentUid, title);
    if (label.trim().isEmpty) return null;
    return {
      'id': 'zikr:$id',
      'kind': 'zikr',
      'label': label,
      'link': buildZikrDeepLinkUrl(
          uid: id, slug: (slugFor ?? (uid) => itemSlugs[uid])(id)),
    };
  }

  Future<void> _sendCatalog() async {
    if (!zikrIndexReady.value) return;
    final catalog = await _catalog();
    final encoded = jsonEncode(catalog);
    if (encoded == _lastCatalog) return;
    _lastCatalog = encoded;
    await _invoke('updateCatalog', {
      'playlists': jsonEncode(catalog['playlists']),
      'zikrs': jsonEncode(catalog['zikrs']),
    });
  }

  Future<Map<String, List<Map<String, Object>>>> _catalog() async {
    await ZikrAudioIndex.instance.load();
    return buildCatalog(
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
    if (call.method == 'actionsPending') {
      await takePendingActions();
      return null;
    }
    return _perform(call.method, arguments);
  }

  Future<Object?> _perform(
      String method, Map<String, Object?> arguments) async {
    switch (method) {
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
        _navigate(SmartActionLink(link));
        return _outcome(true, null);
      // Android: Assistant's words, or a static shortcut's feature id.
      case 'openNamed':
        await _whenIndexReady();
        _navigate(await _openTarget(arguments['name']?.toString() ?? ''));
        return _outcome(true, null);
      case 'playNamed':
        await _whenIndexReady();
        await _playNamed(
          arguments['name']?.toString() ?? '',
          playlistAsked: arguments['playlist'] == true,
        );
        return _outcome(true, null);
      case 'search':
        await _whenIndexReady();
        _navigate(SmartActionSearch(arguments['query']?.toString() ?? ''));
        return _outcome(true, null);
    }
    throw MissingPluginException('No handler for $method');
  }

  /// What "open [name]" means: a feature of the app ("qibla", "prayer
  /// times"), or a zikr ("Dua Kumayl"), whichever [name] names better - the
  /// feature when it is a tie, so "open Quran" is the Quran and not a dua
  /// about it. Search for [name] when it names neither.
  Future<SmartActionTarget> _openTarget(String name) async {
    if (name.trim().isEmpty) return const SmartActionSearch('');
    final catalog = await _catalog();
    final feature = matchFeature(name, _smartFeatures);
    final zikr = matchZikr(name, catalog['zikrs']!);
    if (feature != null &&
        (zikr == null || feature.score.isAtLeast(zikr.score))) {
      return SmartActionFeature(feature.entry);
    }
    if (zikr != null) {
      return SmartActionLink(Uri.parse(zikr.entry['link'] as String));
    }
    return SmartActionSearch(name);
  }

  /// "Play [name]": a playlist, or a dua's recitation. Opens what it plays,
  /// as a play link from anywhere else would. A playlist wins a tie with a
  /// dua, and always when [playlistAsked] ("play my Thursday Night
  /// playlist"). A dua with no recording opens with a note saying so;
  /// nothing at all searches for [name].
  Future<void> _playNamed(String name, {required bool playlistAsked}) async {
    final catalog = await _catalog();
    final playlist = matchPlaylist(name, catalog['playlists']!);
    final recited = matchZikr(name, catalog['zikrs']!, recitedOnly: true);
    if (playlist != null &&
        (playlistAsked ||
            recited == null ||
            playlist.score.isAtLeast(recited.score))) {
      _navigate(SmartActionLink(
          Uri.parse(buildPlaylistDeepLinkUrl(playlist.entry['id'] as String))));
      return;
    }
    if (playlistAsked) {
      showToast(L10n.current.smartActionsPlaylistMissing);
      _navigate(SmartActionFeature(playlistsMenuItem));
      return;
    }
    if (recited != null) {
      final id = recited.entry['id'] as String;
      _navigate(SmartActionLink(
          Uri.parse(buildPlayDeepLinkUrl(uid: id, slug: itemSlugs[id]))));
      return;
    }
    final unrecited = matchZikr(name, catalog['zikrs']!);
    if (unrecited != null) {
      showToast(L10n.current.smartActionsZikrMissing);
      _navigate(SmartActionLink(Uri.parse(unrecited.entry['link'] as String)));
      return;
    }
    _navigate(SmartActionSearch(name));
  }

  /// The features "open ..." can name: the home menu as this reader sees
  /// it, the Quran and Settings included.
  static List<HomeMenuItem> get _smartFeatures => visibleHomeMenuItems;

  /// The feature of [features] that [name] names best: by its id (what a
  /// static shortcut sends), its label in English and the app language, or
  /// the other words people use for it ([featureKeywords]).
  @visibleForTesting
  static ({HomeMenuItem entry, SpokenMatchScore score})? matchFeature(
    String name,
    List<HomeMenuItem> features,
  ) =>
      bestSpokenMatch(
        name,
        features,
        (item) => [
          item.analyticsId,
          item.label,
          item.shortLabel,
          item.displayLabel,
          item.displayShortLabel,
          ...?featureKeywords[item.analyticsId],
        ],
      );

  /// What else people call a feature, by its `analyticsId`, beside its
  /// label: "prayer times" is the Calendar, "tasbih" the Tasbeeh Counter.
  @visibleForTesting
  static const Map<String, List<String>> featureKeywords = {
    'calendar_prayer_times': [
      'prayer times',
      'prayer time',
      'namaz times',
      'namaz time',
      'salah times',
      'salat times',
      'islamic calendar',
      'hijri calendar',
      'hijri date',
      'islamic date',
    ],
    'qibla_finder': ['qibla', 'qiblah', 'kibla', 'qibla direction', 'compass'],
    'tasbeeh_counter': ['tasbih', 'tasbeeh', 'tasbih counter', 'counter'],
    'quran': ['quran', 'koran', 'holy quran'],
    'favorites': ['favourites', 'bookmarks', 'saved duas'],
    'today_s_recitations': ['recitations today', 'daily recitations'],
    'qaza_tracker': ['qaza', 'qada', 'kaza', 'missed prayers'],
    'rakaat_counter': ['rakat counter', 'raka at counter'],
    'prayer_times_in_flight': ['flight prayer times', 'flights'],
    'play_azan': ['azan', 'adhan', 'azaan', 'athan'],
    'preferences': ['settings', 'preferences'],
    'my_stats': ['stats', 'statistics'],
  };

  /// The zikr of the catalog's [zikrs] that [name] names best, by its
  /// spoken name, its title in the reader's language or an old spelling;
  /// only one with a recitation when [recitedOnly].
  @visibleForTesting
  static ({Map<String, Object> entry, SpokenMatchScore score})? matchZikr(
    String name,
    List<Map<String, Object>> zikrs, {
    bool recitedOnly = false,
  }) =>
      bestSpokenMatch(
        name,
        recitedOnly ? zikrs.where((zikr) => zikr['audio'] == true) : zikrs,
        (zikr) => [
          zikr['name'] as String,
          if (zikr['subtitle'] case final String subtitle) subtitle,
          ...(zikr['keywords'] as List).cast<String>(),
        ],
      );

  /// The playlist of the catalog's [playlists] that [name] names best, by
  /// its stored or shown name; "playlist" itself is not part of the name.
  @visibleForTesting
  static ({Map<String, Object> entry, SpokenMatchScore score})? matchPlaylist(
    String name,
    List<Map<String, Object>> playlists,
  ) =>
      bestSpokenMatch(
        name,
        playlists,
        (playlist) => [
          playlist['name'] as String,
          if (playlist['subtitle'] case final String subtitle) subtitle,
        ],
        ignoredWords: const {'playlist'},
      );

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
