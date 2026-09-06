import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/services/analytics_service.dart';
import 'package:shia_companion/services/zikr_bookmark_store.dart';
import 'package:shia_companion/services/zikr_counter_session.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/external_launch.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/web_route_sync.dart';
import 'package:shia_companion/utils/zikr_wakelock.dart';
import 'package:shia_companion/models/zikr_audio_track.dart';
import '../../constants.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/zikr_action_bar.dart';
import '../../widgets/zikr_audio_player.dart';
import '../../widgets/zikr_reading_preferences.dart';
import '../../widgets/zikr_reading_progress_bar.dart';
import '../../widgets/zikr_settings.dart';
import '../../widgets/zikr_counter.dart';
import 'zikr_edit_form.dart';
import 'zikr_form_helpers.dart';
import 'zikr_content_parser.dart';
import 'zikr_content_viewer.dart';
import 'zikr_reading_stats.dart';
import 'zikr_share_image.dart';

enum _ZikrMenuAction { edit }

/// How far the text has to actually travel in one direction before the
/// reading chrome reacts.
///
/// This replaces reacting to [UserScrollNotification]'s direction, which
/// flips the instant a finger wobbles back by a pixel: on a normal read that
/// meant the progress strip and action bar popping in and back out several
/// times a gesture. A deliberate scroll crosses this in a frame or two; the
/// wobble inside one never does.
const double kZikrChromeScrollThreshold = 36.0;

/// Turns the reading area's stream of scroll deltas into hide/show decisions
/// for the reading chrome - the progress strip and the bottom action bar,
/// which move together. [update] returns true to show, false to hide, and
/// null - by far the common case - for "leave it exactly as it is".
///
/// Kept free of Flutter's scroll notification types (which need a live
/// [BuildContext] to build) so the whole hysteresis rule is unit testable.
class ZikrChromeScrollTracker {
  /// Signed pixels travelled since the last decision, positive downwards.
  /// Reset rather than carried whenever the reader reverses, so a scroll up
  /// starts earning its reveal from zero instead of from a debt built up
  /// scrolling down.
  double _accumulated = 0.0;

  /// Called at the start and end of every gesture: a new gesture always
  /// starts from zero, and momentum left over from the last one must not
  /// count towards the next one's threshold.
  void reset() {
    _accumulated = 0.0;
  }

  bool? update({
    required Axis axis,
    required double delta,
    required bool outOfRange,
    required bool chromeVisible,
    double threshold = kZikrChromeScrollThreshold,
  }) {
    // Horizontal scrolling is a swipe between tabs, not reading movement.
    // The reading list is nested inside the tabs' PageView, so its
    // notifications and the PageView's own arrive at the same listener.
    if (axis != Axis.vertical) return null;
    // An overscroll bounce reverses under its own momentum with no reader
    // input at all; letting that count would reveal the chrome every time a
    // read hit the end of a zikr.
    if (outOfRange) {
      _accumulated = 0.0;
      return null;
    }
    if (delta == 0) return null;
    if (_accumulated != 0 && _accumulated.isNegative != delta.isNegative) {
      _accumulated = 0.0;
    }
    _accumulated += delta;

    if (_accumulated >= threshold) {
      _accumulated = 0.0;
      return chromeVisible ? false : null;
    }
    if (_accumulated <= -threshold) {
      _accumulated = 0.0;
      return chromeVisible ? null : true;
    }
    return null;
  }
}

/// Whether a scroll notification from the reading content should drop a live
/// text selection.
///
/// Any scroll the reader drives should: the reading column is a lazily built
/// list, so scrolling disposes the very [Selectable] a selection edge sits in
/// and leaves the selection overlay reading geometry that is no longer in the
/// tree - the crash in `SelectableRegion` this guards against.
///
/// Idle is the carve-out, and it is not a nicety. `SelectableRegion`
/// auto-scrolls the list by `jumpTo` while a selection handle is dragged past
/// its edge, and `jumpTo` reports its scroll as idle. Acting on that would
/// cancel the selection the reader is in the middle of making.
///
/// Kept out of [_ZikrPageState] for the same reason as
/// [resolveChromeVisibilityForScroll]: a real [UserScrollNotification] needs a
/// live [BuildContext] to build.
bool shouldClearSelectionForScroll(ScrollDirection direction) =>
    direction != ScrollDirection.idle;

class ZikrPage extends StatefulWidget {
  final UidTitleData item;
  final bool startEditing;

  /// Where the open came from, so the dashboard can say whether search, the
  /// home grid or a shared link is what actually brings people to a zikr.
  final String source;

  ZikrPage(
    this.item, {
    this.startEditing = false,
    this.source = ZikrOpenSource.unknown,
  });

  @override
  _ZikrPageState createState() => _ZikrPageState();
}

class _ZikrPageState extends State<ZikrPage> with RouteAware {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference zikrCollection =
      FirebaseFirestore.instance.collection('zikr');

  bool isAdmin = false;
  bool isEditing = false;
  bool _isSharingZikr = false;
  bool _isCurrentRoute = false;
  bool _didFailToLoadZikrData = false;
  int _selectedZikrTabIndex = 0;
  String? userId;
  Map<String, dynamic>? zikrData;
  TextEditingController? titleController;
  TextEditingController? slugController;
  TextEditingController? codeController;
  TextEditingController? dataController;
  TextEditingController? meritsController;
  TextEditingController? orderController;
  TextEditingController? dayController;
  final List<TextEditingController> tabControllers = [];
  PageRoute? _pageRoute;
  Uri? _previousBrowserUri;
  List<String> _slugAliases = const [];
  ZikrBookmark? _savedBookmark;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Focus for the reading area's [SelectionArea]. Held here, rather than left
  /// to the node the widget would make for itself, so the page can drop a live
  /// selection through [_clearTextSelection] before the text it was made in
  /// goes away.
  final FocusNode _selectionFocusNode =
      FocusNode(debugLabel: 'ZikrPage selection');

  final Map<int, double> _currentTabScrollOffsets = {};
  final Map<int, double> _currentTabMaxScrollExtents = {};

  /// The content line at the top of each tab's view, measured from the laid
  /// out list. This is what a bookmark records alongside the raw offset, so
  /// the marker is drawn on the very line the offset was read off.
  final Map<int, int> _currentTabTopLineIndexes = {};
  final ValueNotifier<double> _readingProgress = ValueNotifier<double>(0);
  bool _hasRecordedCompletion = false;
  DateTime? _openedAt;
  ZikrReadingStats _readingStats = ZikrReadingStats.empty;
  String? _readingStatsSignature;
  late final String _counterSessionId;
  late final ValueNotifier<Offset> _counterOffset;
  late final ValueNotifier<bool> _showCounter;
  late final ValueNotifier<int> _counterCount;

  /// Whether the reading chrome - the progress strip and the bottom action
  /// bar, which move as one - is on screen. Scroll direction is the primary
  /// signal - down hides it, up brings it back, and that alone is enough for
  /// anything long enough to actually scroll. An idle timer is only the
  /// fallback, for a zikr short enough that it never generates a scroll event
  /// to react to; see [_scheduleChromeIdleHide]. Both bars are overlays
  /// rather than something the text is padded around, so either way this
  /// only ever changes what is painted, never the text's layout.
  ///
  /// Only meaningful with Focus mode on. With it off, [_setChromeVisible] is
  /// the one place that enforces the chrome staying pinned - every writer
  /// below goes through it rather than each having to check the setting.
  final ValueNotifier<bool> _chromeVisible = ValueNotifier(true);

  /// Whether the bar is showing the player instead of the action row. Set by
  /// Listen, cleared by the player's close button. The player is only built
  /// while this is true, so audio costs nothing on a reading that never uses
  /// it — and closing it stops playback.
  bool _showAudioPlayer = false;

  @override
  void initState() {
    super.initState();
    isAdmin = isUserAdmin;
    _counterSessionId = widget.item.getFirstUId();
    final counterState =
        ZikrCounterSessionStore.instance.read(_counterSessionId);
    _counterOffset = ValueNotifier(counterState.offset);
    _showCounter = ValueNotifier(counterState.isVisible);
    _counterCount = ValueNotifier(counterState.count);
    _loadSavedBookmark();
    if (widget.startEditing) {
      isEditing = true;
    }
    // The one place a zikr open is counted, so every entry point lands in the
    // same bucket exactly once.
    _openedAt = DateTime.now();
    unawaited(trackScreen('Zikr Page'));
    unawaited(AnalyticsService.zikrView(
      uid: widget.item.getUId(),
      title: widget.item.getTitle(),
      source: widget.source,
    ));
    _readingProgress.addListener(_maybeRecordCompletion);
    _initializePageData();
    _scheduleChromeIdleHide();
  }

  /// Fires at most once. Opening a zikr and reciting one are different things
  /// and the dashboard should not conflate them.
  ///
  /// Scroll position alone is not enough: [zikrTabScrollFraction] treats a zikr
  /// too short to scroll as fully read the moment it lays out, so a stray tap
  /// on a two-line dua would outrank a real recitation. Time on the page,
  /// scaled to how long the text actually takes to recite, is the second half
  /// of the signal.
  void _maybeRecordCompletion() {
    if (_hasRecordedCompletion) return;
    if (_readingProgress.value < 0.98) return;

    final openedAt = _openedAt;
    if (openedAt == null) return;
    final estimatedSeconds = _readingStats.duration.inSeconds;
    final requiredSeconds = math.max(10, estimatedSeconds ~/ 2);
    if (DateTime.now().difference(openedAt).inSeconds < requiredSeconds) return;

    _hasRecordedCompletion = true;
    unawaited(AnalyticsService.zikrCompleted(
      uid: widget.item.getUId(),
      title: widget.item.getTitle(),
    ));
  }

  @override
  void dispose() {
    if (_pageRoute != null) {
      routeObserver.unsubscribe(this);
    }
    titleController?.dispose();
    slugController?.dispose();
    codeController?.dispose();
    dataController?.dispose();
    meritsController?.dispose();
    orderController?.dispose();
    dayController?.dispose();
    for (final controller in tabControllers) {
      controller.dispose();
    }
    _counterOffset.dispose();
    _showCounter.dispose();
    _counterCount.dispose();
    _chromeIdleTimer?.cancel();
    _chromeVisible.dispose();
    _selectionFocusNode.dispose();
    _maybeRecordCompletion();
    _readingProgress.removeListener(_maybeRecordCompletion);
    _readingProgress.dispose();
    syncZikrWakelockPreference(owner: this, isActive: false);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _pageRoute) {
      if (_pageRoute != null) {
        routeObserver.unsubscribe(this);
      }
      _pageRoute = route;
      routeObserver.subscribe(this, route);
    }
  }

  String get _bookmarkUid => widget.item.getFirstUId();

  void _loadSavedBookmark() {
    final bookmark = ZikrBookmarkStore.instance.read(_bookmarkUid);
    if (bookmark == null) return;

    _savedBookmark = bookmark;
    _selectedZikrTabIndex = bookmark.tabIndex;
    _currentTabScrollOffsets[bookmark.tabIndex] = bookmark.scrollOffset;
  }

  void _persistCounterSession({
    int? count,
    bool? isVisible,
    Offset? offset,
  }) {
    final nextState =
        ZikrCounterSessionStore.instance.read(_counterSessionId).copyWith(
              count: count ?? _counterCount.value,
              isVisible: isVisible ?? _showCounter.value,
              offset: offset ?? _counterOffset.value,
            );
    ZikrCounterSessionStore.instance.write(_counterSessionId, nextState);
  }

  void _setCounterVisibility(bool isVisible) {
    _showCounter.value = isVisible;
    _persistCounterSession(isVisible: isVisible);
  }

  void _toggleCounterFromActionBar() {
    if (_showCounter.value) {
      _setCounterVisibility(false);
      return;
    }
    unawaited(AnalyticsService.feature(
      'zikr_counter_shown',
      label: 'Tasbeeh counter shown',
    ));
    _setCounterVisibility(true);
  }

  void _openAudioPlayer() {
    unawaited(AnalyticsService.feature(
      'zikr_audio_opened',
      label: 'Zikr audio opened',
      parameters: {'zikr_uid': widget.item.getUId()},
    ));
    setState(() => _showAudioPlayer = true);
    // Reading down the page hides the chrome; opening the player has to
    // bring it back or the reader taps Listen and sees nothing happen. Always
    // allowed regardless of Focus mode - true is never a hide request, so it
    // needs no guard.
    _chromeVisible.value = true;
    _chromeIdleTimer?.cancel();
  }

  void _closeAudioPlayer() {
    setState(() => _showAudioPlayer = false);
    _scheduleChromeIdleHide();
  }

  /// Whether Focus mode is on - the reading chrome is only ever eligible to
  /// hide when it is. Read live rather than cached: it is an in-memory prefs
  /// read, and a cached copy would need re-syncing from the drawer, the
  /// global settings page, and [didPopNext].
  bool get _focusModeEnabled => zikrFocusModeEnabled();

  /// The one place the chrome is hidden. With Focus mode off the chrome is
  /// pinned, so a hide request from the scroll handler or the idle timer is
  /// dropped here rather than having to be caught at every call site.
  void _setChromeVisible(bool visible) {
    if (!visible && !_focusModeEnabled) return;
    _chromeVisible.value = visible;
  }

  /// Accumulates scroll deltas so the chrome only moves on a scroll the
  /// reader meant; see [ZikrChromeScrollTracker].
  final ZikrChromeScrollTracker _chromeScrollTracker =
      ZikrChromeScrollTracker();

  /// Slides the chrome away as the reader moves down the text and back when
  /// they scroll up. Held open while the player is showing: hiding transport
  /// controls part-way through a half-hour recitation would strand them.
  ///
  /// Driven by [ScrollUpdateNotification]'s deltas rather than
  /// [UserScrollNotification]'s direction, which reverses on the smallest
  /// wobble and so made the bars flicker mid-read.
  ///
  /// The reading content is a [ListView] nested inside the tab [PageView], so
  /// its scroll notifications arrive here having already bubbled past the
  /// PageView - which, being itself a [Scrollable], bumps [depth] to 1 on the
  /// way through. Gating on `depth == 0` (as the counter FAB's old idle timer
  /// effectively assumed nothing nested) discarded every one of them, so the
  /// chrome never moved on a real read. The tracker gates on axis instead,
  /// which reads correctly regardless of nesting and as a side effect also
  /// ignores the PageView's own horizontal swipes between tabs.
  bool _handleScrollNotification(ScrollNotification notification) {
    // Ahead of the chrome logic and its guards: a selection has to be dropped
    // on every scroll the reader drives, not only the ones that also move the
    // bars.
    if (notification is UserScrollNotification &&
        shouldClearSelectionForScroll(notification.direction)) {
      _clearTextSelection();
    }

    if (notification is ScrollStartNotification ||
        notification is ScrollEndNotification) {
      _chromeScrollTracker.reset();
      return false;
    }
    if (notification is! ScrollUpdateNotification) return false;
    if (_showAudioPlayer || !_focusModeEnabled) return false;

    final delta = notification.scrollDelta;
    if (delta == null) return false;

    final visible = _chromeScrollTracker.update(
      axis: notification.metrics.axis,
      delta: delta,
      outOfRange: notification.metrics.outOfRange,
      chromeVisible: _chromeVisible.value,
    );
    if (visible != null) {
      _setChromeVisible(visible);
      // A deliberate scroll signal always wins; the idle fallback is only
      // for the short zikr that never generates one at all.
      _chromeIdleTimer?.cancel();
      if (visible) _scheduleChromeIdleHide();
    }
    return false;
  }

  /// Drops any live text selection.
  ///
  /// A [SelectionArea] holds its handles and its toolbar against the
  /// [Selectable]s the selection was made in, and asks them for their geometry
  /// again on every rebuild of the overlay. The reading column is a lazily
  /// built [ListView] inside the tab [PageView], so those Selectables are
  /// disposed the moment their line leaves the list's cache or their tab is
  /// swiped away - and a selection that outlives them leaves the overlay
  /// reading an edge that is no longer in the tree, which is where the
  /// framework's null checks fire (flutter/flutter#124078, #123378). Dropping
  /// the selection wherever the text under it is about to change keeps the two
  /// in step.
  ///
  /// Unfocusing rather than reaching into the region's state: losing focus is
  /// already how [SelectableRegion] clears itself, and the focus manager
  /// applies the change in a microtask, so this is safe to call from a scroll
  /// notification that arrives mid-layout.
  void _clearTextSelection() {
    if (!_selectionFocusNode.hasFocus) return;
    _selectionFocusNode.unfocus();
  }

  /// Brings the chrome back and restarts the idle clock - called on any tap
  /// on the page, not just on either bar itself, so a reader is never left
  /// having to guess where to tap to get it back.
  void _revealChrome() {
    _setChromeVisible(true);
    _scheduleChromeIdleHide();
  }

  /// Where the current touch went down, and whether it has since travelled
  /// far enough to be a scroll rather than a tap. Tracked by hand instead of
  /// with a [GestureDetector]: the reading text is inside a [SelectionArea],
  /// whose own recognisers would compete for the tap in the arena and swallow
  /// it, and this listener must never take a gesture away from them.
  Offset? _chromePointerDownPosition;
  bool _chromePointerMoved = false;

  void _handleChromePointerDown(PointerDownEvent event) {
    _chromePointerDownPosition = event.position;
    _chromePointerMoved = false;
  }

  void _handleChromePointerMove(PointerMoveEvent event) {
    final downPosition = _chromePointerDownPosition;
    if (downPosition == null || _chromePointerMoved) return;
    if ((event.position - downPosition).distance > kTouchSlop) {
      _chromePointerMoved = true;
    }
  }

  void _handleChromePointerCancel(PointerCancelEvent event) {
    _chromePointerDownPosition = null;
    _chromePointerMoved = false;
  }

  /// True when the touch that just ended was a tap in place rather than the
  /// beginning of a scroll. Clears the tracking either way.
  bool _consumeChromeTap() {
    final wasTap = _chromePointerDownPosition != null && !_chromePointerMoved;
    _chromePointerDownPosition = null;
    _chromePointerMoved = false;
    return wasTap;
  }

  /// Fallback for a zikr short enough that it never scrolls, so the chrome
  /// would otherwise sit over the text for the entire visit. Longer than the
  /// old counter FAB's 4s: the FAB was a rarely-needed extra, but the action
  /// bar holds Bookmark and Share, which a reader is more likely to want
  /// mid-thought, and a shorter fallback would fight normal pauses in
  /// reading.
  static const Duration _chromeIdleDuration = Duration(seconds: 8);
  Timer? _chromeIdleTimer;

  void _scheduleChromeIdleHide() {
    if (!_focusModeEnabled) return;
    _chromeIdleTimer?.cancel();
    _chromeIdleTimer = Timer(_chromeIdleDuration, () {
      // Re-checked here, not just at scheduling time: the setting can change
      // while this timer is already in flight.
      if (mounted && !_showAudioPlayer && _focusModeEnabled) {
        _setChromeVisible(false);
      }
    });
  }

  /// Called when the reading settings change. Turning Focus mode off has to
  /// pin the chrome back open immediately - the reader just asked for it,
  /// and with no scroll or tap to follow, the pin would otherwise not take
  /// effect until something happened to write the notifier.
  void _applyFocusModePreference() {
    if (_focusModeEnabled) {
      _scheduleChromeIdleHide();
    } else {
      _chromeIdleTimer?.cancel();
      _chromeVisible.value = true; // direct write: _setChromeVisible only
      // ever filters out a hide, and true always needs to go through.
    }
  }

  void _updateCounterOffset(Offset offset) {
    _counterOffset.value = offset;
    _persistCounterSession(offset: offset);
  }

  void _setCounterCount(int count) {
    _counterCount.value = count;
    _persistCounterSession(count: count);
  }

  Widget _buildCounterCard() {
    return ValueListenableBuilder<int>(
      valueListenable: _counterCount,
      builder: (context, count, _) => ZikrCounter(
        count: count,
        onIncrement: () => _setCounterCount(count + 1),
        onDecrement: count > 0 ? () => _setCounterCount(count - 1) : () {},
        onReset: () => _setCounterCount(0),
      ),
    );
  }

  String _currentWebRoutePath() {
    final controllerSlug = normalizeSlug(slugController?.text.trim() ?? '');
    final dataSlug = normalizeSlug(zikrData?['slug']?.toString() ?? '');
    final cachedSlug = itemSlugs[widget.item.uid];

    return buildZikrDeepLinkPath(
      uid: widget.item.uid,
      slug: controllerSlug.isNotEmpty
          ? controllerSlug
          : dataSlug.isNotEmpty
              ? dataSlug
              : cachedSlug,
    );
  }

  String? _currentShareSlug() {
    final controllerSlug = normalizeSlug(slugController?.text.trim() ?? '');
    final dataSlug = normalizeSlug(zikrData?['slug']?.toString() ?? '');
    final cachedSlug = itemSlugs[widget.item.uid];

    if (controllerSlug.isNotEmpty) return controllerSlug;
    if (dataSlug.isNotEmpty) return dataSlug;
    return cachedSlug;
  }

  void _scheduleCurrentWebRouteSync({bool replace = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isCurrentRoute) return;
      syncWebRoutePath(_currentWebRoutePath(), replace: replace);
    });
  }

  /// [bottomInset] keeps the panel clear of the bottom action bar - the bar
  /// is a Stack overlay rather than something [constraints] already excludes,
  /// so without this the panel's default corner position and its drag range
  /// both reach straight under it.
  Offset _clampCounterOffset(
    Offset offset,
    BoxConstraints constraints, {
    double bottomInset = 0,
  }) {
    const edgePadding = 12.0;
    final maxLeft = math.max(
      edgePadding,
      constraints.maxWidth - ZikrCounter.panelWidth - edgePadding,
    );
    final maxTop = math.max(
      edgePadding,
      constraints.maxHeight -
          bottomInset -
          ZikrCounter.panelHeight -
          edgePadding,
    );

    return Offset(
      offset.dx.clamp(edgePadding, maxLeft).toDouble(),
      offset.dy.clamp(edgePadding, maxTop).toDouble(),
    );
  }

  Offset _resolveCounterOffset(
    BoxConstraints constraints,
    Offset offset, {
    double bottomInset = 0,
  }) {
    if (offset.dx >= 0 && offset.dy >= 0) {
      return _clampCounterOffset(offset, constraints, bottomInset: bottomInset);
    }

    return _clampCounterOffset(
      Offset(
        constraints.maxWidth - ZikrCounter.panelWidth - 16,
        constraints.maxHeight - bottomInset - ZikrCounter.panelHeight - 20,
      ),
      constraints,
      bottomInset: bottomInset,
    );
  }

  void _handleCounterDragUpdate(
    DragUpdateDetails details,
    BoxConstraints constraints, {
    double bottomInset = 0,
  }) {
    final currentOffset = _resolveCounterOffset(
      constraints,
      _counterOffset.value,
      bottomInset: bottomInset,
    );
    _updateCounterOffset(
      _clampCounterOffset(
        currentOffset + details.delta,
        constraints,
        bottomInset: bottomInset,
      ),
    );
  }

  /// Vertical space the bottom action bar reserves, when it exists at all -
  /// its own height plus the device's bottom safe area, plus a small gap so
  /// the counter panel does not sit flush against it.
  double _counterBottomInset(BuildContext context, bool showActionBar) {
    if (!showActionBar) return 0;
    return ZikrActionBar.barHeight + MediaQuery.of(context).padding.bottom + 8;
  }

  Future<void> _checkAdmin() async {
    final user = _auth.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          userId = user.uid;
        });
      }
      try {
        final idTokenResult =
            await user.getIdTokenResult().timeout(const Duration(seconds: 4));
        final claims = idTokenResult.claims;
        if (!mounted) return;
        setState(() {
          isAdmin = claims != null && claims['admin'] == true;
        });
      } catch (error) {
        debugPrint('Unable to refresh zikr admin claim: $error');
      }
    }
  }

  Future<void> _initializePageData() async {
    if (isAdmin) {
      await _checkAdmin();
      final loaded = await _fetchZikrData();
      if (!loaded) _markZikrDataUnavailable();
      return;
    }

    final loaded = await _loadZikrDataFromAssets();
    if (!loaded) _markZikrDataUnavailable();
    _refreshAdminDataIfNeeded();
  }

  void _applyZikrData(Map<String, dynamic> data) {
    final currentSlug = normalizeSlug(data['slug']?.toString() ?? '');
    final currentAliases = normalizeSlugAliases(
      data['slugAliases'] is Iterable ? data['slugAliases'] : null,
      exclude: currentSlug,
    );
    setState(() {
      _didFailToLoadZikrData = false;
      zikrData = data;
      titleController = TextEditingController(text: zikrData?['title']);
      slugController = TextEditingController(text: currentSlug);
      codeController = TextEditingController(text: zikrData?['code']);
      dataController = TextEditingController(text: zikrData?['data']);
      meritsController = TextEditingController(text: zikrData?['merits']);
      dayController = TextEditingController(
        text: formatZikrDayValue(zikrData?['day']),
      );
      _slugAliases = currentAliases;
      final rawTabs = zikrData?['tabs'];
      if (rawTabs is List) {
        for (final controller in tabControllers) {
          controller.dispose();
        }
        tabControllers.clear();
        for (final tab in rawTabs) {
          tabControllers
              .add(TextEditingController(text: tab?.toString() ?? ''));
        }
      }
      final double? currentOrder = itemOrder[widget.item.uid];
      orderController = TextEditingController(
        text: formatZikrOrderValue(currentOrder),
      );
    });
    _scheduleCurrentWebRouteSync(replace: true);
  }

  Future<bool> _loadZikrDataFromAssets() async {
    try {
      final raw = await DefaultAssetBundle.of(context)
          .loadString('assets/zikr/${widget.item.getFirstUId()}');
      final decoded = json.decode(raw);
      if (decoded is! Map) {
        return false;
      }

      _applyZikrData(Map<String, dynamic>.from(decoded));
      return true;
    } catch (e) {
      debugPrint('Error loading zikr from assets: $e');
      return false;
    }
  }

  Future<bool> _loadZikrDataFromFirestore() async {
    try {
      final doc = await zikrCollection.doc(widget.item.getFirstUId()).get();
      if (!doc.exists) {
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      _applyZikrData(data);
      return true;
    } catch (e) {
      debugPrint('Error loading zikr from Firestore: $e');
      return false;
    }
  }

  Future<bool> _fetchZikrData() async {
    if (!isAdmin) {
      return _loadZikrDataFromAssets();
    }

    final loadedFromFirestore = await _loadZikrDataFromFirestore();
    if (loadedFromFirestore) return true;
    return _loadZikrDataFromAssets();
  }

  Future<void> _refreshAdminDataIfNeeded() async {
    await _checkAdmin();
    if (!mounted || !isAdmin) return;

    final loadedFromFirestore = await _loadZikrDataFromFirestore();
    if (!loadedFromFirestore && zikrData == null) {
      _markZikrDataUnavailable();
    }
  }

  void _markZikrDataUnavailable() {
    if (!mounted || zikrData != null) return;
    setState(() {
      _didFailToLoadZikrData = true;
    });
  }

  void _resetControllersFromCurrentData() {
    final currentSlug = normalizeSlug(zikrData?['slug']?.toString() ?? '');
    titleController?.text = zikrData?['title']?.toString() ?? '';
    slugController?.text = currentSlug;
    codeController?.text = zikrData?['code']?.toString() ?? '';
    dataController?.text = zikrData?['data']?.toString() ?? '';
    meritsController?.text = zikrData?['merits']?.toString() ?? '';
    dayController?.text = formatZikrDayValue(zikrData?['day']);
    final currentOrder = itemOrder[widget.item.uid];
    orderController?.text = formatZikrOrderValue(currentOrder);
    final rawSlugAliases = zikrData?['slugAliases'];
    _slugAliases = normalizeSlugAliases(
      rawSlugAliases is Iterable ? rawSlugAliases : null,
      exclude: currentSlug,
    );

    for (final controller in tabControllers) {
      controller.dispose();
    }
    tabControllers.clear();
    final rawTabs = zikrData?['tabs'];
    if (rawTabs is List) {
      for (final tab in rawTabs) {
        tabControllers.add(TextEditingController(text: tab?.toString() ?? ''));
      }
    }
  }

  void _toggleEdit() {
    setState(() {
      if (isEditing) {
        _resetControllersFromCurrentData();
      }
      isEditing = !isEditing;
    });
  }

  Future<void> _saveEdits() async {
    if (zikrData != null) {
      final trimmedTitle = titleController?.text.trim() ?? '';
      final rawOrder = orderController?.text.trim() ?? '';
      final rawDay = dayController?.text.trim() ?? '';
      final savedTabs = tabControllers
          .map((controller) => controller.text)
          .where((content) => content.trim().isNotEmpty)
          .toList();
      final existingSlug = normalizeSlug(zikrData?['slug']?.toString() ?? '');
      final enteredSlug = slugController?.text.trim() ?? '';
      final normalizedEnteredSlug = normalizeSlug(enteredSlug);
      if (enteredSlug.isNotEmpty && normalizedEnteredSlug.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Slug must contain letters or numbers'),
        ));
        return;
      }
      if (!isValidZikrOrderInput(rawOrder)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Order must be a number (examples: -2, 5, 5.5) or left blank'),
        ));
        return;
      }
      final parsedOrder = rawOrder.isEmpty ? null : double.parse(rawOrder);
      final nextSlug = enteredSlug.isNotEmpty
          ? normalizedEnteredSlug
          : existingSlug.isNotEmpty
              ? existingSlug
              : makeUniqueSlug(
                  buildSlugSeed(
                    uid: widget.item.uid,
                    title: trimmedTitle,
                  ),
                  currentUid: widget.item.uid,
                );
      if (!isSlugAvailable(nextSlug, currentUid: widget.item.uid)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Slug is already in use. Please choose another one.'),
        ));
        return;
      }
      final nextSlugAliases = normalizeSlugAliases(
        [
          ..._slugAliases,
          if (existingSlug.isNotEmpty && existingSlug != nextSlug) existingSlug,
        ],
        exclude: nextSlug,
      );

      final dayValue = parseZikrDayInput(rawDay);

      await zikrCollection.doc(widget.item.uid).update({
        'title': titleController?.text,
        'slug': nextSlug,
        'slugAliases':
            nextSlugAliases.isEmpty ? FieldValue.delete() : nextSlugAliases,
        'code': codeController?.text,
        'data': dataController?.text,
        'merits': (meritsController?.text.trim().isEmpty ?? true)
            ? FieldValue.delete()
            : meritsController?.text,
        'day': dayValue == null ? FieldValue.delete() : dayValue,
        'tabs': savedTabs.isEmpty ? FieldValue.delete() : savedTabs,
        'order': parsedOrder ?? FieldValue.delete(),
      });
      if (parsedOrder == null) {
        itemOrder.remove(widget.item.uid);
      } else {
        itemOrder[widget.item.uid] = parsedOrder;
      }
      if (dayValue == null) {
        itemMetadata.remove(widget.item.uid);
      } else {
        itemMetadata[widget.item.uid] = {'day': dayValue};
      }
      items[widget.item.uid] = titleController?.text ?? widget.item.title;
      widget.item.title = titleController?.text ?? widget.item.title;
      setLocalSlugData(
        widget.item.uid,
        slug: nextSlug,
        aliases: nextSlugAliases,
      );
      setState(() {
        isEditing = false;
        zikrData?['title'] = titleController?.text;
        zikrData?['slug'] = nextSlug;
        zikrData?['slugAliases'] = nextSlugAliases;
        zikrData?['code'] = codeController?.text;
        zikrData?['data'] = dataController?.text;
        zikrData?['merits'] = meritsController?.text;
        zikrData?['day'] = dayValue;
        zikrData?['tabs'] = savedTabs;
        slugController?.text = nextSlug;
        _slugAliases = nextSlugAliases;
      });
      _scheduleCurrentWebRouteSync(replace: true);
    }
  }

  void _addTabField() {
    setState(() {
      tabControllers.add(TextEditingController());
    });
  }

  void _showMeritsSheet() {
    final merits = meritsController?.text.trim() ?? '';
    if (merits.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Merits',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    SelectableText(
                      merits,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _buildVisibleTabContents() {
    final primary = dataController?.text ?? zikrData?['data']?.toString() ?? '';
    final extraTabs = <String>[];
    final rawTabs = zikrData?['tabs'];

    if (tabControllers.isNotEmpty) {
      extraTabs.addAll(tabControllers.map((controller) => controller.text));
    } else if (rawTabs is List) {
      extraTabs.addAll(rawTabs.map((tab) => tab?.toString() ?? ''));
    }

    return buildVisibleZikrTabContents(
      primary: primary,
      extraTabs: extraTabs,
    );
  }

  Future<void> _deleteZikr() async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete Zikr?'),
            content: Text(
              'This will permanently delete "${titleController?.text ?? widget.item.title}".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    await zikrCollection.doc(widget.item.uid).delete();
    items.remove(widget.item.uid);
    itemOrder.remove(widget.item.uid);
    itemMetadata.remove(widget.item.uid);
    removeLocalSlugData(widget.item.uid);

    if (!mounted) return;
    Navigator.pop(context);
  }

  int _clampedSelectedTabIndex(List<String> tabContents) {
    if (tabContents.isEmpty) return 0;
    return _selectedZikrTabIndex.clamp(0, tabContents.length - 1);
  }

  String _tabHeaderForContent(String content, int index) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    if (lines.isNotEmpty) {
      return ZikrContentParser.parseLineSegments(lines.first)
          .map((segment) => segment.text)
          .join()
          .trim();
    }
    return 'Part ${index + 1}';
  }

  Future<void> _shareZikrText({
    required String title,
    required String deepLink,
    required Rect sharePositionOrigin,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        text: '$title\n$deepLink',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<void> _shareCurrentZikr() async {
    if (_isSharingZikr) return;

    final title = titleController?.text.trim().isNotEmpty == true
        ? titleController!.text.trim()
        : widget.item.title;
    final deepLink = buildZikrDeepLinkUrl(
      uid: widget.item.uid,
      slug: _currentShareSlug(),
    );
    final sharePositionOrigin = Rect.fromLTWH(
      MediaQuery.of(context).size.width / 2,
      0,
      2,
      2,
    );

    setState(() {
      _isSharingZikr = true;
    });

    try {
      final shareImage = SP.prefs.getBool('share_zikr_image') ?? true;
      if (!shareImage) {
        await _shareZikrText(
          title: title,
          deepLink: deepLink,
          sharePositionOrigin: sharePositionOrigin,
        );
        return;
      }

      final tabContents = _buildVisibleTabContents();
      final selectedIndex = _clampedSelectedTabIndex(tabContents);
      final selectedContent =
          tabContents.isEmpty ? '' : tabContents[selectedIndex];
      if (selectedContent.trim().isEmpty) {
        await _shareZikrText(
          title: title,
          deepLink: deepLink,
          sharePositionOrigin: sharePositionOrigin,
        );
        return;
      }

      final showTabHeaders = tabContents.length > 1;
      final imageBytes = await buildZikrShareImage(
        ZikrShareImageRequest(
          title: title,
          tabTitle: showTabHeaders
              ? _tabHeaderForContent(selectedContent, selectedIndex)
              : '',
          content: selectedContent,
          hideHeaderLine: showTabHeaders,
          colorScheme: Theme.of(context).colorScheme,
          code: zikrData?['code']?.toString(),
        ),
      );
      if (imageBytes == null) {
        await _shareZikrText(
          title: title,
          deepLink: deepLink,
          sharePositionOrigin: sharePositionOrigin,
        );
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          title: title,
          subject: title,
          text: '$title\n$deepLink',
          files: [
            XFile.fromData(
              imageBytes,
              mimeType: 'image/png',
              name: 'shia-companion-zikr.png',
            ),
          ],
          fileNameOverrides: const ['shia-companion-zikr.png'],
          downloadFallbackEnabled: false,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (error) {
      debugPrint('Error sharing zikr image: $error');
      await _shareZikrText(
        title: title,
        deepLink: deepLink,
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharingZikr = false;
        });
      }
    }
  }

  void _handleContentScrollPositionChanged(
    ZikrContentScrollPosition position,
  ) {
    _currentTabScrollOffsets[position.tabIndex] = position.scrollOffset;
    _currentTabMaxScrollExtents[position.tabIndex] = position.maxScrollExtent;
    final lineIndex = position.lineIndex;
    if (lineIndex != null) {
      _currentTabTopLineIndexes[position.tabIndex] = lineIndex;
    }
    _updateReadingProgress();
  }

  /// Gives a bookmark saved before line indexes existed the line it turns out
  /// to sit on, measured once its offset has been restored, and rewrites it
  /// so the marker no longer depends on the offset surviving a relayout.
  void _handleBookmarkLineResolved(int lineIndex) {
    final bookmark = _savedBookmark;
    if (bookmark == null || bookmark.lineIndex != null) return;

    final upgraded = bookmark.copyWith(lineIndex: lineIndex);
    setState(() {
      _savedBookmark = upgraded;
    });
    unawaited(ZikrBookmarkStore.instance.save(upgraded));
  }

  /// Recomputes the reading estimate only when the rendered text changed, since
  /// this runs on every rebuild of the page.
  void _refreshReadingStats(
    List<String> tabContents, {
    required bool hideHeaderLine,
  }) {
    final signature = '$hideHeaderLine|${tabContents.join('\n')}';
    if (signature == _readingStatsSignature) return;

    _readingStatsSignature = signature;
    _readingStats = analyzeZikrReadingStats(
      tabContents,
      hideHeaderLine: hideHeaderLine,
    );
    // This runs from build, so the notifier is written once the frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateReadingProgress();
    });
  }

  void _updateReadingProgress() {
    _readingProgress.value = _computeReadingProgress();
  }

  double _computeReadingProgress() {
    final weights = _readingStats.tabWeights;
    if (weights.isEmpty) return 0;

    final tabIndex = _selectedZikrTabIndex.clamp(0, weights.length - 1);
    final maxScrollExtent = _currentTabMaxScrollExtents[tabIndex];
    // An unmeasured tab has not been laid out yet, so nothing is read.
    final tabFraction = maxScrollExtent == null
        ? 0.0
        : zikrTabScrollFraction(
            scrollOffset: _currentTabScrollOffsets[tabIndex] ?? 0,
            maxScrollExtent: maxScrollExtent,
          );

    return zikrReadingProgress(
      tabWeights: weights,
      tabIndex: tabIndex,
      tabFraction: tabFraction,
    );
  }

  Future<void> _toggleBookmark({
    required String pageTitle,
    required List<String> tabContents,
    required int selectedTabIndex,
  }) async {
    final existingBookmark = _savedBookmark;
    if (existingBookmark != null) {
      await ZikrBookmarkStore.instance.remove(_bookmarkUid);
      if (!mounted) return;
      setState(() {
        _savedBookmark = null;
      });
      unawaited(AnalyticsService.feature(
        'zikr_bookmark_removed',
        label: 'Bookmark removed',
      ));
      return;
    }

    final selectedContent =
        tabContents.isEmpty ? '' : tabContents[selectedTabIndex];
    final bookmark = ZikrBookmark(
      uid: _bookmarkUid,
      title: pageTitle,
      tabIndex: selectedTabIndex,
      tabTitle: tabContents.length > 1
          ? _tabHeaderForContent(selectedContent, selectedTabIndex)
          : null,
      scrollOffset: _currentTabScrollOffsets[selectedTabIndex] ?? 0,
      lineIndex: _currentTabTopLineIndexes[selectedTabIndex],
      updatedAt: DateTime.now().toUtc(),
    );

    await ZikrBookmarkStore.instance.save(bookmark);
    if (!mounted) return;
    setState(() {
      _savedBookmark = bookmark;
    });
    unawaited(AnalyticsService.feature(
      'zikr_bookmark_saved',
      label: 'Bookmark saved',
      parameters: {'zikr_uid': _bookmarkUid},
    ));
  }

  String? _lookupInternalItemUid(String segment) {
    if (segment.isEmpty) return null;

    if (items.containsKey(segment)) {
      return segment;
    }

    final mappedUid = slugToItemUid[segment];
    if (mappedUid != null) {
      return mappedUid;
    }

    return null;
  }

  String? _findInternalUid(String href) {
    final segment = extractZikrLinkSegment(href);
    return segment == null ? null : _lookupInternalItemUid(segment);
  }

  Future<void> _handleZikrLinkTap(String href) async {
    if (href.trim().isEmpty) return;

    final internalUid = _findInternalUid(href);
    if (internalUid != null) {
      final title = items[internalUid]?.toString() ?? internalUid;
      await pushPageRoute(
        context,
        ZikrPage(
          UidTitleData(internalUid, title),
          source: ZikrOpenSource.zikrLink,
        ),
      );
      return;
    }

    var uri = Uri.tryParse(href);
    if (uri == null) return;
    if (!uri.hasScheme) {
      uri = Uri.parse('https://$href');
    }

    await launchExternalUri(uri);
  }

  @override
  void didPush() {
    _isCurrentRoute = true;
    syncZikrWakelockPreference(owner: this, isActive: _isCurrentRoute);
    _previousBrowserUri ??= Uri.base;
    _scheduleCurrentWebRouteSync();
  }

  @override
  void didPopNext() {
    _isCurrentRoute = true;
    syncZikrWakelockPreference(owner: this, isActive: _isCurrentRoute);
    // Covers Focus mode being flipped from the global settings page while
    // this route sat underneath it - refreshState only runs from this
    // page's own drawer.
    _applyFocusModePreference();
    _scheduleCurrentWebRouteSync(replace: true);
  }

  @override
  void didPushNext() {
    _isCurrentRoute = false;
    // The selection toolbar lives in the enclosing Overlay, so it would
    // otherwise float over the route that just covered this one.
    _clearTextSelection();
    syncZikrWakelockPreference(owner: this, isActive: _isCurrentRoute);
  }

  @override
  void didPop() {
    _isCurrentRoute = false;
    syncZikrWakelockPreference(owner: this, isActive: _isCurrentRoute);
    final previousBrowserUri = _previousBrowserUri;
    if (previousBrowserUri != null) {
      syncWebRouteUri(previousBrowserUri, replace: true);
    }
  }

  Widget _buildAppBarTitle(String title) {
    // Long titles wrap onto a second, smaller line instead of being clipped.
    final useTwoLines = title.trim().length > 24;
    return Text(
      title,
      maxLines: useTwoLines ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: useTwoLines ? const TextStyle(fontSize: 16, height: 1.2) : null,
    );
  }

  void _handleMenuAction(_ZikrMenuAction action) {
    switch (action) {
      case _ZikrMenuAction.edit:
        _toggleEdit();
        break;
    }
  }

  void _shareFromActionBar() {
    if (_isSharingZikr) return;
    unawaited(AnalyticsService.feature(
      'zikr_shared',
      label: 'Zikr shared',
      parameters: {'zikr_uid': widget.item.getFirstUId()},
    ));
    _shareCurrentZikr();
  }

  List<Widget> _buildAppBarActions({
    required String pageTitle,
    required List<String> tabContents,
    required int selectedTabIndex,
    required bool hasAnyContent,
  }) {
    final settingsButton = IconButton(
      icon: const Icon(Icons.filter_list),
      tooltip: 'Reading settings',
      onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
    );

    if (zikrData == null) return [settingsButton];

    if (isEditing) {
      if (!isAdmin) return [settingsButton];
      return [
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'Delete Zikr',
          onPressed: _deleteZikr,
        ),
        IconButton(
          icon: const Icon(Icons.done),
          tooltip: 'Save Changes',
          onPressed: _saveEdits,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Stop editing',
          onPressed: _toggleEdit,
        ),
      ];
    }

    // Bookmark, share and reading settings now live in the bottom action
    // bar, where they are labelled and within thumb reach. All that stays
    // here is admin-only.
    return [
      if (isAdmin)
        PopupMenuButton<_ZikrMenuAction>(
          tooltip: 'More options',
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _ZikrMenuAction.edit,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit),
                title: Text('Edit Zikr'),
              ),
            ),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final merits = meritsController?.text.trim() ?? '';
    final hasMerits = merits.isNotEmpty;
    final tabContents = _buildVisibleTabContents();
    final pageTitle = isEditing
        ? (titleController?.text.trim().isNotEmpty == true
            ? titleController!.text.trim()
            : widget.item.title)
        : (zikrData?['title']?.toString().trim().isNotEmpty == true
            ? zikrData!['title'].toString().trim()
            : widget.item.title);
    final hasAnyContent =
        tabContents.any((content) => content.trim().isNotEmpty);
    final selectedTabIndex = _clampedSelectedTabIndex(tabContents);
    _refreshReadingStats(
      isEditing ? const [] : tabContents,
      hideHeaderLine: tabContents.length > 1,
    );
    final audioTracks = ZikrAudioTrack.listFrom(zikrData?['audio']);
    // Editing replaces the reading view with a form, and the bar's actions all
    // act on the rendered zikr, so it has nothing to do there.
    final showActionBar = !isEditing && zikrData != null;
    // Independent of showActionBar - a zikr with no estimable reading time
    // (still loading, or edit mode, where _refreshReadingStats is fed no
    // content at all) can lack one while the other still applies.
    final showProgressBar = !isEditing && _readingStats.hasContent;
    final readingTimeLabel = zikrReadingTimeLabel(_readingStats.duration);

    return SelectionArea(
      focusNode: _selectionFocusNode,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: _buildAppBarTitle(pageTitle),
          // Reading settings opens this same endDrawer from the bottom bar
          // now. Without this, AppBar auto-fills an empty actions list (the
          // common case, for any non-admin reader) with its own end-drawer
          // button - "Open navigation menu" - duplicating that entry point.
          automaticallyImplyActions: false,
          actions: _buildAppBarActions(
            pageTitle: pageTitle,
            tabContents: tabContents,
            selectedTabIndex: selectedTabIndex,
            hasAnyContent: hasAnyContent,
          ),
        ),
        endDrawer: ZikrSettingsPage(refreshState),
        body: Listener(
          // Covers the whole reading area, not just either bar: after the
          // idle timeout has hidden the chrome, the reader should not have to
          // hunt for exactly where to tap to get it back.
          //
          // On the finished tap, not on pointer-down: a scroll starts with a
          // pointer-down too, so revealing there flashed both bars onto the
          // screen at the start of every single scroll gesture, for the
          // scroll itself to slide them straight back out.
          onPointerDown: _handleChromePointerDown,
          onPointerMove: _handleChromePointerMove,
          onPointerCancel: _handleChromePointerCancel,
          onPointerUp: (_) {
            if (!_consumeChromeTap()) return;
            if (showActionBar || showProgressBar) _revealChrome();
          },
          behavior: HitTestBehavior.translucent,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: LayoutBuilder(
              builder: (context, bodyConstraints) => Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: zikrData == null
                            ? Center(
                                child: _didFailToLoadZikrData
                                    ? const Text('Unable to open this dua.')
                                    : const CircularProgressIndicator(),
                              )
                            : !hasAnyContent && !isEditing
                                ? const Center(child: Text('Coming soon...'))
                                : ResponsiveContent(
                                    maxWidth: isEditing
                                        ? wideContentWidth
                                        : readingContentWidth,
                                    // Both bars float over the reading area
                                    // rather than sitting in the column, so
                                    // this - not either bar's own size - is
                                    // what keeps the text out from under
                                    // them.
                                    //
                                    // Reserved for as long as a bar exists at
                                    // all, rather than following
                                    // [_chromeVisible]: letting it follow the
                                    // chrome meant every hide and reveal
                                    // re-laid out the whole reading list, and
                                    // the top inset shifted the text under
                                    // the reader's eyes mid-scroll. A
                                    // standing gap behind a hidden bar is the
                                    // cheaper of the two costs by far.
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      16 +
                                          (showProgressBar
                                              ? ZikrReadingProgressBar.barHeight
                                              : 0.0),
                                      16,
                                      16 +
                                          (showActionBar
                                              ? ZikrActionBar.barHeight
                                              : 0.0),
                                    ),
                                    child: isEditing
                                        ? ZikrEditFormWidget(
                                            titleController: titleController!,
                                            slugController: slugController!,
                                            codeController: codeController!,
                                            orderController: orderController!,
                                            dayController: dayController!,
                                            meritsController: meritsController!,
                                            dataController: dataController!,
                                            tabControllers: tabControllers,
                                            onAddTab: _addTabField,
                                          )
                                        : ZikrContentViewerWidget(
                                            tabContents: tabContents,
                                            selectedTabIndex: selectedTabIndex,
                                            onTabChanged: (index) {
                                              // A swiped tab change is already
                                              // covered by the scroll handler;
                                              // this is the tab header being
                                              // tapped, which animates the
                                              // pager without ever reporting a
                                              // user scroll.
                                              _clearTextSelection();
                                              setState(() {
                                                _selectedZikrTabIndex = index;
                                              });
                                              _updateReadingProgress();
                                            },
                                            hasMerits: hasMerits,
                                            onShowMerits: _showMeritsSheet,
                                            onLinkTap: _handleZikrLinkTap,
                                            code: zikrData?['code']?.toString(),
                                            initialBookmarkTabIndex:
                                                _savedBookmark?.tabIndex,
                                            initialBookmarkScrollOffset:
                                                _savedBookmark?.scrollOffset,
                                            initialBookmarkLineIndex:
                                                _savedBookmark?.lineIndex,
                                            onScrollPositionChanged:
                                                _handleContentScrollPositionChanged,
                                            onBookmarkLineResolved:
                                                _handleBookmarkLineResolved,
                                          ),
                                  ),
                      ),
                    ],
                  ),
                  if (showProgressBar)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      // Stack only clips a child that overflows its *layout*;
                      // AnimatedSlide is a paint-time translation, so without
                      // this the strip would paint up into the app bar's
                      // band instead of disappearing behind its edge.
                      child: ClipRect(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _chromeVisible,
                          builder: (context, visible, child) => AnimatedSlide(
                            offset: visible ? Offset.zero : const Offset(0, -1),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: child,
                          ),
                          // Purely informational and sits over selectable
                          // text - taps and drags must keep reaching the
                          // reading column underneath.
                          child: IgnorePointer(
                            child: ValueListenableBuilder<double>(
                              valueListenable: _readingProgress,
                              builder: (context, progress, _) =>
                                  ZikrReadingProgressBar(
                                progress: progress,
                                readingTimeLabel: readingTimeLabel,
                                progressLabel: zikrProgressLabel(progress),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Counter overlay
                  ValueListenableBuilder<bool>(
                    valueListenable: _showCounter,
                    builder: (context, visible, _) {
                      if (!visible) return const SizedBox.shrink();
                      return ValueListenableBuilder<Offset>(
                        valueListenable: _counterOffset,
                        builder: (context, offset, __) {
                          final bottomInset = _counterBottomInset(
                            context,
                            showActionBar,
                          );
                          final resolvedOffset = _resolveCounterOffset(
                            bodyConstraints,
                            offset,
                            bottomInset: bottomInset,
                          );
                          return Positioned(
                            left: resolvedOffset.dx,
                            top: resolvedOffset.dy,
                            child: SelectionContainer.disabled(
                              child: GestureDetector(
                                onPanUpdate: (details) =>
                                    _handleCounterDragUpdate(
                                  details,
                                  bodyConstraints,
                                  bottomInset: bottomInset,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _buildCounterCard(),
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Material(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        shape: const CircleBorder(),
                                        child: IconButton(
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          icon:
                                              const Icon(Icons.close, size: 16),
                                          tooltip: 'Hide counter',
                                          onPressed: () =>
                                              _setCounterVisibility(false),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  if (showActionBar)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _chromeVisible,
                        builder: (context, visible, child) => AnimatedSlide(
                          // Slides out of frame rather than collapsing: the bar
                          // sits over the reading area, so its size never
                          // affects the text's layout either way.
                          offset: visible ? Offset.zero : const Offset(0, 1),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: child,
                        ),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _showCounter,
                          builder: (context, counterVisible, _) =>
                              ZikrActionBar(
                            hasAudio: audioTracks.isNotEmpty,
                            canBookmark: hasAnyContent,
                            isBookmarked: _savedBookmark != null,
                            canShare: !_isSharingZikr,
                            isCounterVisible: counterVisible,
                            onBookmark: () => _toggleBookmark(
                              pageTitle: pageTitle,
                              tabContents: tabContents,
                              selectedTabIndex: selectedTabIndex,
                            ),
                            onShare: _shareFromActionBar,
                            onListen: _openAudioPlayer,
                            onSettings: () =>
                                _scaffoldKey.currentState?.openEndDrawer(),
                            onCounter: _toggleCounterFromActionBar,
                            player: _showAudioPlayer && audioTracks.isNotEmpty
                                ? ZikrAudioPlayer(
                                    tracks: audioTracks,
                                    zikrUid: widget.item.getUId(),
                                    zikrTitle: pageTitle,
                                    onClose: _closeAudioPlayer,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void refreshState() {
    // Reading settings - font, size, transliteration - relay every line of the
    // column out from under whatever was selected in it.
    _clearTextSelection();
    syncZikrWakelockPreference(owner: this, isActive: _isCurrentRoute);
    _applyFocusModePreference();
    setState(() {});
  }
}
