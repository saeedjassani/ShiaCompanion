import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
import '../../constants.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/zikr_reading_preferences.dart';
import '../../widgets/zikr_settings.dart';
import '../../widgets/zikr_counter.dart';
import 'zikr_edit_form.dart';
import 'zikr_form_helpers.dart';
import 'zikr_content_parser.dart';
import 'zikr_content_viewer.dart';
import 'zikr_reading_stats.dart';
import 'zikr_share_image.dart';

enum _ZikrMenuAction { share, readingSettings, edit }

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
  /// Below this width the app bar keeps only the bookmark icon so a long zikr
  /// title is not squeezed out by the action row.
  static const double _compactActionsWidth = 420;

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
  final Map<int, double> _currentTabScrollOffsets = {};
  final Map<int, double> _currentTabMaxScrollExtents = {};
  final ValueNotifier<double> _readingProgress = ValueNotifier<double>(0);
  bool _hasRecordedCompletion = false;
  DateTime? _openedAt;
  ZikrReadingStats _readingStats = ZikrReadingStats.empty;
  String? _readingStatsSignature;
  late final String _counterSessionId;
  late final ValueNotifier<Offset> _counterOffset;
  late final ValueNotifier<bool> _showCounter;
  late final ValueNotifier<int> _counterCount;

  /// Whether the "show counter" FAB is currently on screen. Starts visible
  /// so it's discoverable, then fades itself out after a few idle seconds so
  /// a feature most readings never touch stops sitting on top of the
  /// content — a tap anywhere on the page brings it back for another look.
  final ValueNotifier<bool> _counterFabVisible = ValueNotifier(true);
  Timer? _counterFabHideTimer;
  static const Duration _counterFabIdleDuration = Duration(seconds: 4);

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
    _scheduleCounterFabHide();
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
    _counterFabHideTimer?.cancel();
    _counterFabVisible.dispose();
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

  void _showCounterFromFab() {
    unawaited(AnalyticsService.feature(
      'zikr_counter_shown',
      label: 'Tasbeeh counter shown',
    ));
    _setCounterVisibility(true);
  }

  /// Restarts the idle timer and, if the FAB had already faded out, brings
  /// it back — called on any tap on the page, not just on the FAB itself.
  void _revealCounterFab() {
    if (_showCounter.value) return;
    _counterFabVisible.value = true;
    _scheduleCounterFabHide();
  }

  void _scheduleCounterFabHide() {
    _counterFabHideTimer?.cancel();
    _counterFabHideTimer = Timer(_counterFabIdleDuration, () {
      if (mounted) _counterFabVisible.value = false;
    });
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

  Offset _clampCounterOffset(
    Offset offset,
    BoxConstraints constraints,
  ) {
    const edgePadding = 12.0;
    final maxLeft = math.max(
      edgePadding,
      constraints.maxWidth - ZikrCounter.panelWidth - edgePadding,
    );
    final maxTop = math.max(
      edgePadding,
      constraints.maxHeight - ZikrCounter.panelHeight - edgePadding,
    );

    return Offset(
      offset.dx.clamp(edgePadding, maxLeft).toDouble(),
      offset.dy.clamp(edgePadding, maxTop).toDouble(),
    );
  }

  Offset _resolveCounterOffset(BoxConstraints constraints, Offset offset) {
    if (offset.dx >= 0 && offset.dy >= 0) {
      return _clampCounterOffset(offset, constraints);
    }

    return _clampCounterOffset(
      Offset(
        constraints.maxWidth - ZikrCounter.panelWidth - 16,
        constraints.maxHeight - ZikrCounter.panelHeight - 20,
      ),
      constraints,
    );
  }

  void _handleCounterDragUpdate(
    DragUpdateDetails details,
    BoxConstraints constraints,
  ) {
    final currentOffset = _resolveCounterOffset(
      constraints,
      _counterOffset.value,
    );
    _updateCounterOffset(
      _clampCounterOffset(currentOffset + details.delta, constraints),
    );
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
    _updateReadingProgress();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bookmark removed')),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bookmark saved on this device')),
    );
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
    _scheduleCurrentWebRouteSync(replace: true);
  }

  @override
  void didPushNext() {
    _isCurrentRoute = false;
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
      case _ZikrMenuAction.share:
        if (!_isSharingZikr) {
          unawaited(AnalyticsService.feature(
            'zikr_shared',
            label: 'Zikr shared',
            parameters: {'zikr_uid': widget.item.getFirstUId()},
          ));
          _shareCurrentZikr();
        }
        break;
      case _ZikrMenuAction.readingSettings:
        _scaffoldKey.currentState?.openEndDrawer();
        break;
      case _ZikrMenuAction.edit:
        _toggleEdit();
        break;
    }
  }

  List<Widget> _buildAppBarActions({
    required String pageTitle,
    required List<String> tabContents,
    required int selectedTabIndex,
    required bool hasAnyContent,
    required bool isCompact,
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

    final canShare = !_isSharingZikr;
    return [
      if (hasAnyContent)
        IconButton(
          icon: Icon(
            _savedBookmark == null ? Icons.bookmark_border : Icons.bookmark,
          ),
          tooltip: _savedBookmark == null ? 'Save Bookmark' : 'Remove Bookmark',
          onPressed: () => _toggleBookmark(
            pageTitle: pageTitle,
            tabContents: tabContents,
            selectedTabIndex: selectedTabIndex,
          ),
        ),
      if (!isCompact)
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: 'Share',
          onPressed: canShare ? _shareCurrentZikr : null,
        ),
      PopupMenuButton<_ZikrMenuAction>(
        tooltip: 'More options',
        onSelected: _handleMenuAction,
        itemBuilder: (context) => [
          if (isCompact)
            PopupMenuItem(
              value: _ZikrMenuAction.share,
              enabled: canShare,
              child: const ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.share),
                title: Text('Share'),
              ),
            ),
          const PopupMenuItem(
            value: _ZikrMenuAction.readingSettings,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.filter_list),
              title: Text('Reading settings'),
            ),
          ),
          if (isAdmin)
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

  PreferredSizeWidget? _buildReadingProgressBar(BuildContext context) {
    if (!_readingStats.hasContent) return null;
    if (SP.isInitialized && !(SP.prefs.getBool(showZikrProgressKey) ?? true)) {
      return null;
    }

    final foreground = Theme.of(context).appBarTheme.foregroundColor ??
        Theme.of(context).colorScheme.onSurface;
    final readingTime = zikrReadingTimeLabel(_readingStats.duration);

    return PreferredSize(
      preferredSize: const Size.fromHeight(29),
      child: ValueListenableBuilder<double>(
        valueListenable: _readingProgress,
        builder: (context, progress, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: foreground.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                foreground.withValues(alpha: 0.85),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 3, 16, 4),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontSize: 11,
                  color: foreground.withValues(alpha: 0.85),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(readingTime),
                    // Larger than the reading time beside it: this is the
                    // number people glance down to check progress by, so it
                    // carries the weight the row is there for.
                    Text(
                      zikrProgressLabel(progress),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    final isCompact = MediaQuery.of(context).size.width < _compactActionsWidth;

    return SelectionArea(
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: _buildAppBarTitle(pageTitle),
          actions: _buildAppBarActions(
            pageTitle: pageTitle,
            tabContents: tabContents,
            selectedTabIndex: selectedTabIndex,
            hasAnyContent: hasAnyContent,
            isCompact: isCompact,
          ),
          bottom: _buildReadingProgressBar(context),
        ),
        endDrawer: ZikrSettingsPage(refreshState),
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: _showCounter,
          builder: (context, showingCounter, _) {
            if (showingCounter) return const SizedBox.shrink();
            return ValueListenableBuilder<bool>(
              valueListenable: _counterFabVisible,
              builder: (context, visible, _) => IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: FloatingActionButton(
                    onPressed: _showCounterFromFab,
                    tooltip: 'Show Counter',
                    child: const Icon(tasbeehCounterIcon),
                  ),
                ),
              ),
            );
          },
        ),
        body: Listener(
          // Any touch on the page — not just the FAB — counts as "still
          // here", so the FAB is there to find again without having to wait
          // out the fade or go hunting for it.
          onPointerDown: (_) => _revealCounterFab(),
          behavior: HitTestBehavior.translucent,
          child: LayoutBuilder(
            builder: (context, bodyConstraints) => Stack(
              children: [
                zikrData == null
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
                            padding: const EdgeInsets.all(16.0),
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
                                    onScrollPositionChanged:
                                        _handleContentScrollPositionChanged,
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
                        final resolvedOffset =
                            _resolveCounterOffset(bodyConstraints, offset);
                        return Positioned(
                          left: resolvedOffset.dx,
                          top: resolvedOffset.dy,
                          child: SelectionContainer.disabled(
                            child: GestureDetector(
                              onPanUpdate: (details) =>
                                  _handleCounterDragUpdate(
                                details,
                                bodyConstraints,
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
                                        icon: const Icon(Icons.close, size: 16),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  void refreshState() {
    syncZikrWakelockPreference(owner: this, isActive: _isCurrentRoute);
    setState(() {});
  }
}
