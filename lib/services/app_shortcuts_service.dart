import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:quick_actions/quick_actions.dart';

import '../constants.dart' show items;
import '../l10n/l10n.dart';
import '../pages/home/continue_section.dart';
import 'library_progress_store.dart';
import 'recitation_tracker_manager.dart';
import 'zikr_bookmarks_manager.dart';
import 'zikr_translations.dart';

/// What a launcher shortcut does. The [id] is the shortcut's type on the
/// platform side, so it has to stay stable: Android keeps a shortcut someone
/// dragged onto their home screen, and its id is all a later tap hands back.
enum AppShortcut {
  /// Picks up the newest of Home's Continue cards.
  continueReading('continue', 'ic_shortcut_continue'),
  favorites('favorites', 'ic_shortcut_favorites'),
  playlists('playlists', 'ic_shortcut_playlists'),
  tasbeeh('tasbeeh', 'ic_shortcut_tasbeeh'),
  qibla('qibla', 'ic_shortcut_qibla');

  const AppShortcut(this.id, this.icon);

  final String id;

  /// A drawable in `android/app/src/main/res/drawable` and an image set in
  /// `ios/Runner/Assets.xcassets`, both under this name.
  final String icon;

  static AppShortcut? fromId(String id) {
    for (final shortcut in values) {
      if (shortcut.id == id) return shortcut;
    }
    return null;
  }
}

/// The actions under the app icon when it is long-pressed: Android's app
/// shortcuts and iOS's Home Screen quick actions.
///
/// "Continue reading" leads, naming what it would open, when there is
/// anything to continue; Favorites, Playlists and Tasbeeh follow, and Qibla
/// takes the fourth place when there is nothing to continue. Four, because
/// that is what iOS shows and what most Android launchers fit.
///
/// The list is published again when the reading it describes changes and
/// whenever the app goes to the background, which also catches a change of
/// language and progress in a library book (whose store says nothing when
/// it changes). It is only sent when it differs from the last one sent:
/// Android rate-limits how often an app in the background may update them.
class AppShortcutsService with WidgetsBindingObserver {
  AppShortcutsService._();

  static final AppShortcutsService instance = AppShortcutsService._();

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final QuickActions _quickActions = const QuickActions();

  bool _started = false;
  Timer? _refreshTimer;
  String? _lastPublished;

  void Function(AppShortcut shortcut)? _handler;
  AppShortcut? _pending;

  /// Starts taking shortcut taps - including the one that launched the app,
  /// if any - and publishes the list. Called from Home once it is up: on
  /// Android the launching tap can only be read once the activity is
  /// attached.
  Future<void> start() async {
    if (!isSupported || _started) return;
    _started = true;
    try {
      await _quickActions.initialize(_onAction);
    } catch (error) {
      debugPrint('App shortcuts: initialize failed: $error');
    }
    WidgetsBinding.instance.addObserver(this);
    RecitationTrackerManager.instance.addListener(refresh);
    ZikrBookmarksManager.instance.addListener(refresh);
    // The titles, once the zikr language's translations load.
    ZikrTranslations.instance.addListener(refresh);
    refresh();
  }

  /// Where a tapped shortcut goes - Home, which waits for the zikr index
  /// before opening anything. A tap that came first is handed over then.
  set handler(void Function(AppShortcut shortcut)? handler) {
    _handler = handler;
    final pending = _pending;
    if (handler != null && pending != null) {
      _pending = null;
      handler(pending);
    }
  }

  void _onAction(String type) {
    final shortcut = AppShortcut.fromId(type);
    if (shortcut == null) return;
    final handler = _handler;
    if (handler == null) {
      _pending = shortcut;
    } else {
      handler(shortcut);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _refreshTimer?.cancel();
      unawaited(_publish());
    }
  }

  /// Publishes the list again shortly, coalescing a burst of changes (a
  /// sync landing, several bookmarks moving) into one update.
  void refresh() {
    if (!_started) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(seconds: 1), _publish);
  }

  Future<void> _publish() async {
    final entry = currentContinueEntry();
    final shortcuts = buildShortcuts(
      continueTitle: entry?.title,
      l10n: L10n.current,
      platform: defaultTargetPlatform,
    );
    final signature = [
      for (final item in shortcuts)
        '${item.type}|${item.localizedTitle}|${item.localizedSubtitle}',
    ].join('\n');
    if (signature == _lastPublished) return;
    try {
      await _quickActions.setShortcutItems(shortcuts);
      _lastPublished = signature;
    } catch (error) {
      debugPrint('App shortcuts: update failed: $error');
    }
  }

  /// The card Home's Continue section shows first, or null when there is
  /// nothing to continue.
  static ContinueEntry? currentContinueEntry() {
    return continueEntries(
      recitations: RecitationTrackerManager.instance.state,
      bookmarks: ZikrBookmarksManager.instance.state.bookmarks.values,
      library: LibraryProgressStore.instance.readAll(),
      titles: items,
    ).firstOrNull;
  }

  /// The shortcuts to publish, in order - the first sits nearest the icon.
  ///
  /// [continueTitle] is what Continue would open, or null for nothing to
  /// continue. iOS shows it as the action's subtitle under "Continue
  /// reading"; Android has one line per shortcut, so there it is folded into
  /// the label ("Continue Dua Kumayl").
  @visibleForTesting
  static List<ShortcutItem> buildShortcuts({
    required String? continueTitle,
    required AppLocalizations l10n,
    required TargetPlatform platform,
  }) {
    final title = continueTitle == null ? null : shortcutTitle(continueTitle);
    final ios = platform == TargetPlatform.iOS;
    final shortcuts = [
      if (title != null && title.isNotEmpty)
        ShortcutItem(
          type: AppShortcut.continueReading.id,
          localizedTitle: ios
              ? l10n.appShortcutContinueReading
              : l10n.appShortcutContinueItem(title),
          localizedSubtitle: ios ? title : null,
          icon: AppShortcut.continueReading.icon,
        ),
      _item(AppShortcut.favorites, l10n.menuFavorites),
      _item(AppShortcut.playlists, l10n.menuPlaylists),
      _item(AppShortcut.tasbeeh, l10n.menuTasbeehShort),
      _item(AppShortcut.qibla, l10n.menuQiblaShort),
    ];
    return shortcuts.take(maxShortcuts).toList(growable: false);
  }

  static const int maxShortcuts = 4;

  static ShortcutItem _item(AppShortcut shortcut, String title) => ShortcutItem(
      type: shortcut.id, localizedTitle: title, icon: shortcut.icon);

  /// [title] without the Arabic that English zikr titles carry after the
  /// English ("Dua Kumayl دعاء كميل" -> "Dua Kumayl"): a launcher's one short
  /// line has no room for both. A title in Urdu, Persian or Arabic script
  /// throughout is left whole, since stripping it would leave nothing.
  @visibleForTesting
  static String shortcutTitle(String title) {
    final trimmed = title.trim();
    if (!RegExp('[A-Za-z]').hasMatch(trimmed)) return trimmed;
    final latin = trimmed
        .replaceAll(_arabicScript, ' ')
        .replaceAll(RegExp(r'\(\s*\)|\[\s*\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[\s\-:,]+$'), '')
        .trim();
    return latin.isEmpty ? trimmed : latin;
  }

  static final RegExp _arabicScript = RegExp(
    '[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]+',
  );
}
