import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/services/zikr_counter_session.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/external_launch.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/web_route_sync.dart';
import 'package:shia_companion/utils/zikr_wakelock.dart';
import '../../constants.dart';
import '../../widgets/zikr_settings.dart';
import '../../widgets/zikr_counter.dart';
import 'zikr_edit_form.dart';
import 'zikr_form_helpers.dart';
import 'zikr_content_parser.dart';
import 'zikr_content_viewer.dart';
import 'zikr_share_image.dart';

class ZikrPage extends StatefulWidget {
  final UidTitleData item;
  final bool startEditing;
  ZikrPage(this.item, {this.startEditing = false});

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
  late final String _counterSessionId;
  late final ValueNotifier<Offset> _counterOffset;
  late final ValueNotifier<bool> _showCounter;
  late final ValueNotifier<int> _counterCount;

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
    if (widget.startEditing) {
      isEditing = true;
    }
    _initializePageData();
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
      await pushPageRoute(context, ZikrPage(UidTitleData(internalUid, title)));
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

    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(pageTitle),
          actions: [
            if (isAdmin && zikrData != null && isEditing)
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete Zikr',
                onPressed: _deleteZikr,
              ),
            if (isAdmin && zikrData != null && isEditing)
              IconButton(
                icon: const Icon(Icons.done),
                tooltip: 'Save Changes',
                onPressed: _saveEdits,
              ),
            if (zikrData != null)
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share',
                onPressed: _isSharingZikr ? null : _shareCurrentZikr,
              ),
            isAdmin && zikrData != null
                ? IconButton(
                    icon: Icon(isEditing ? Icons.close : Icons.edit),
                    onPressed: _toggleEdit,
                  )
                : Container(),
            Builder(builder: (BuildContext innerContext) {
              return IconButton(
                icon: Icon(Icons.filter_list),
                onPressed: () => Scaffold.of(innerContext).openEndDrawer(),
              );
            }),
          ],
        ),
        endDrawer: ZikrSettingsPage(refreshState),
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: _showCounter,
          builder: (context, visible, _) => visible
              ? const SizedBox.shrink()
              : FloatingActionButton(
                  onPressed: () => _setCounterVisibility(true),
                  tooltip: 'Show Counter',
                  child: const Icon(tasbeehCounterIcon),
                ),
        ),
        body: LayoutBuilder(
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
                      : Padding(
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
                              : Column(
                                  children: [
                                    Expanded(
                                      child: ZikrContentViewerWidget(
                                        tabContents: tabContents,
                                        selectedTabIndex: selectedTabIndex,
                                        onTabChanged: (index) {
                                          setState(() {
                                            _selectedZikrTabIndex = index;
                                          });
                                        },
                                        hasMerits: hasMerits,
                                        onShowMerits: _showMeritsSheet,
                                        onLinkTap: _handleZikrLinkTap,
                                        code: zikrData?['code']?.toString(),
                                      ),
                                    ),
                                  ],
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
                            onPanUpdate: (details) => _handleCounterDragUpdate(
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
    );
  }

  void refreshState() {
    syncZikrWakelockPreference(owner: this, isActive: _isCurrentRoute);
    setState(() {});
  }
}
