import 'dart:async';
import 'dart:math';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/live_streaming_data.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/navigation/home_menu.dart';
import 'package:shia_companion/pages/chapter_list_page.dart';
import 'package:shia_companion/pages/chapter_page.dart';
import 'package:shia_companion/pages/deep_link_not_found_page.dart';
import 'package:shia_companion/pages/quran/quran_page.dart';
import 'package:shia_companion/pages/zikr/zikr_page.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/quran_portion.dart';
import 'package:shia_companion/services/azaan_opt_in_service.dart';
import 'package:shia_companion/services/deep_link_resolver.dart';
import 'package:shia_companion/services/favorites_manager.dart';
import 'package:shia_companion/services/home_screen_widget_service.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/services/preferences_sync_service.dart';
import 'package:shia_companion/services/qaza_tracker_manager.dart';
import 'package:shia_companion/services/session_refresh_service.dart';
import 'package:shia_companion/utils/data_search.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/font_preferences.dart';
import 'package:shia_companion/utils/hadith_loader.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/web_route_sync.dart';

import 'package:shia_companion/widgets/prayer_times_widget.dart';
import 'package:shia_companion/widgets/responsive_content.dart';
import 'package:shia_companion/widgets/zikr_reading_preferences.dart';
import 'package:shia_companion/services/analytics_service.dart';

enum _PublishStatus { success, error, timeout }

class MyHomePage extends StatefulWidget {
  MyHomePage({
    required this.title,
  });

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with WidgetsBindingObserver, RouteAware {
  String hadith = '';
  DateTime today = DateTime.now();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<LiveStreamingData>? holyShrine, liveChannel;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  MethodChannel? _widgetLinkChannel;
  DeepLinkTarget? _pendingDeepLink;
  bool _itemsLoaded = false;
  bool _isPublishingIndex = false;
  String? _lastDeepLinkKey;
  DateTime? _lastDeepLinkAt;

  void _openHomeMenuItem(HomeMenuItem item) {
    final page = item.buildPage();
    pushPageRoute(context, page);
  }

  Future<void> _refreshHomeSessionState() async {
    await SessionRefreshService.refreshSessionState();
    _itemsLoaded = true;
    _resolvePendingDeepLink();
  }

  @override
  void initState() {
    super.initState();
    unawaited(trackScreen('Home Page', deferOnWeb: true));
    WidgetsBinding.instance.addObserver(this);
    _setupDeepLinks();
    _setupAndroidWidgetLinks();
    setupPreferences();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  Future<void> _setupDeepLinks() async {
    if (!webLaunchDeepLinkHandled) {
      _queueDeepLink(parseDeepLinkUri(Uri.base));
    }

    if (kIsWeb) return;

    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      _queueDeepLink(parseDeepLinkUri(initialLink));
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _queueDeepLink(parseDeepLinkUri(uri));
    });
  }

  Future<void> _setupAndroidWidgetLinks() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final channel = MethodChannel('shia_companion/home_widgets');
    _widgetLinkChannel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method != 'openWidgetUrl') return;
      final url = call.arguments?.toString();
      if (url == null || url.isEmpty) return;
      _queueDeepLink(parseDeepLinkUri(Uri.parse(url)));
    });

    try {
      final url = await channel.invokeMethod<String>('takeWidgetUrl');
      if (url != null && url.isNotEmpty) {
        _queueDeepLink(parseDeepLinkUri(Uri.parse(url)));
      }
    } on MissingPluginException {
      // Native widget bridge is only available on Android/iOS app builds.
    }
  }

  void _queueDeepLink(DeepLinkTarget? target) {
    if (target == null) return;
    if (_pendingDeepLink?.key == target.key) {
      return;
    }

    final now = DateTime.now();
    if (_lastDeepLinkKey == target.key &&
        _lastDeepLinkAt != null &&
        now.difference(_lastDeepLinkAt!) < const Duration(seconds: 5)) {
      return;
    }

    _lastDeepLinkKey = target.key;
    _lastDeepLinkAt = now;
    _pendingDeepLink = target;
    _resolvePendingDeepLink();
  }

  Future<void> _resolvePendingDeepLink() async {
    if (!_itemsLoaded || _pendingDeepLink == null || !mounted) return;

    final target = _pendingDeepLink!;
    _pendingDeepLink = null;

    // Checked before the empty-segment guard: a bare /quran names the Quran
    // screen, and is the one link that carries nothing after its prefix.
    if (target.type == quranDeepLinkType) {
      await _resolveQuranDeepLink(target);
      return;
    }

    if (target.segments.isEmpty) {
      _openDeepLinkNotFound(target.key);
      return;
    }

    if (target.type == libraryDeepLinkType) {
      await _resolveLibraryDeepLink(target);
      return;
    }

    if (target.type != zikrDeepLinkType) {
      _openDeepLinkNotFound(target.key);
      return;
    }

    final resolvedItem = await _resolveDeepLinkItem(target);
    if (!mounted) return;
    if (resolvedItem == null) {
      _openDeepLinkNotFound(target.segments.join('/'));
      return;
    }

    final verse = zikrLinkVerse(target, resolvedItem);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ZikrPage(
        resolvedItem,
        source: ZikrOpenSource.deepLink,
        initialVerse: verse,
      );
      pushRootPageRoute(route) ?? pushPageRoute(context, route);
    });
  }

  Future<void> _resolveQuranDeepLink(DeepLinkTarget target) async {
    final destination = DeepLinkResolver.resolveQuranDestination(target);
    if (destination == null) {
      _openDeepLinkNotFound(target.segments.join('/'));
      return;
    }

    if (destination.isHome) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        const route = QuranPage();
        pushRootPageRoute(route) ?? pushPageRoute(context, route);
      });
      return;
    }

    final juz = destination.juz;
    if (juz != null) {
      // A juz is assembled rather than loaded - it spans surahs.
      final portion = await loadJuzPortion(juz, DefaultAssetBundle.of(context));
      if (!mounted) return;
      if (portion == null || portion.isEmpty) {
        _openDeepLinkNotFound(target.segments.join('/'));
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ZikrPage(
          UidTitleData(quranJuzUid(juz), portion.title),
          source: ZikrOpenSource.deepLink,
          portion: portion,
        );
        pushRootPageRoute(route) ?? pushPageRoute(context, route);
      });
      return;
    }

    final verse = destination.verse!;
    final info = surahInfoFor(verse.surah);
    if (info == null) {
      _openDeepLinkNotFound(target.segments.join('/'));
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ZikrPage(
        UidTitleData(info.uid, items[info.uid]?.toString() ?? info.fullTitle),
        source: ZikrOpenSource.deepLink,
        initialVerse: verse,
      );
      pushRootPageRoute(route) ?? pushPageRoute(context, route);
    });
  }

  Future<void> _resolveLibraryDeepLink(DeepLinkTarget target) async {
    // A retired duplicate's slug still resolves, to the copy that survived, so
    // old links and saved positions do not dead-end.
    final bookSlug =
        await LibraryService.resolveBookSlug(target.segments.first);
    final chapterSlug = target.segments.length > 1 ? target.segments[1] : null;

    final books = await LibraryService.loadBooks();
    if (!mounted) return;

    UidTitleData? book;
    for (final candidate in books) {
      if (candidate.uid == bookSlug) {
        book = candidate;
        break;
      }
    }
    if (book == null) {
      _openDeepLinkNotFound(target.segments.join('/'));
      return;
    }
    final resolvedBook = book;

    if (chapterSlug == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ChapterListPage(resolvedBook.uid, resolvedBook.title);
        pushRootPageRoute(route) ?? pushPageRoute(context, route);
      });
      return;
    }

    List<UidTitleData> chapters;
    try {
      chapters = await LibraryService.loadChapters(bookSlug);
    } on LibraryLoadException {
      chapters = const [];
    }
    if (!mounted) return;

    final chapterIndex =
        chapters.indexWhere((chapter) => chapter.uid == chapterSlug);
    if (chapterIndex == -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ChapterListPage(resolvedBook.uid, resolvedBook.title);
        pushRootPageRoute(route) ?? pushPageRoute(context, route);
      });
      return;
    }

    final chapter = chapters[chapterIndex];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Put the book's chapter list under the chapter, so backing out of a
      // shared chapter link lands in the book rather than dropping to home.
      final listRoute = ChapterListPage(resolvedBook.uid, resolvedBook.title);
      pushRootPageRoute(listRoute) ?? pushPageRoute(context, listRoute);
      final route = ChapterPage(
        '$bookSlug/${chapter.uid}',
        chapter.title,
        bookTitle: resolvedBook.title,
        chapters: chapters,
        chapterIndex: chapterIndex,
        bookSlug: bookSlug,
      );
      pushRootPageRoute(route) ?? pushPageRoute(context, route);
    });
  }

  Future<UidTitleData?> _resolveDeepLinkItem(DeepLinkTarget target) {
    return DeepLinkResolver.resolveZikrItem(target);
  }

  void _openDeepLinkNotFound(String target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DeepLinkNotFoundPage(target: target),
      ));
    });
  }

  void _showAddItemDialog() {
    final _formKey = GlobalKey<FormState>();
    String _uid = '';
    String _title = '';
    String? _linkTargetUid;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New Item'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'UID (Document ID)',
                      hintText: 'e.g. G100',
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                    onSaved: (value) => _uid = value!,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Title'),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                    onSaved: (value) => _title = value!,
                  ),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Link Target UID (Optional)',
                      hintText: 'e.g. A1',
                    ),
                    onSaved: (value) => _linkTargetUid = value,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();

                  String finalUid = _uid;
                  if (_linkTargetUid != null && _linkTargetUid!.isNotEmpty) {
                    finalUid = '$_uid|$_linkTargetUid';
                  }

                  try {
                    final docRef = FirebaseFirestore.instance
                        .collection('zikr')
                        .doc(finalUid);
                    final docSnap = await docRef.get();
                    if (docSnap.exists) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text('Error: Item $finalUid already exists')));
                      return;
                    }
                    await docRef.set({
                      'title': _title,
                    }, SetOptions(merge: true));
                    Navigator.pop(context);
                    // Manually update local list since we aren't fetching from server anymore.
                    items[finalUid] = _title;
                    setState(() {});
                    if (_linkTargetUid == null || _linkTargetUid!.isEmpty) {
                      pushPageRoute(
                          context,
                          ZikrPage(UidTitleData(finalUid, _title),
                              startEditing: true,
                              source: ZikrOpenSource.admin));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Item linked successfully')));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _publishZikrIndex() async {
    if (_isPublishingIndex) return;

    setState(() {
      _isPublishingIndex = true;
    });

    try {
      final requestId =
          '${DateTime.now().millisecondsSinceEpoch}-${_auth.currentUser?.uid ?? 'admin'}';
      await FirebaseFirestore.instance.doc('zikr_meta/publish_requests').set({
        'requestId': requestId,
        'status': 'requested',
        'requestedAt': FieldValue.serverTimestamp(),
        'requestedBy': _auth.currentUser?.uid,
      }, SetOptions(merge: true));

      final publishStatus = await _waitForPublishCompletion(requestId);
      if (publishStatus == _PublishStatus.success && isUserAdmin) {
        await SessionRefreshService.loadItemsFromFirebase();
      }

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (publishStatus) {
          _PublishStatus.success => 'Publish finished. Admin index refreshed.',
          _PublishStatus.error => 'Publish failed. Check Cloud Function logs.',
          _PublishStatus.timeout =>
            'Publish requested. Rebuild is taking longer than expected.',
        }),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Publish failed: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isPublishingIndex = false;
      });
    }
  }

  Future<_PublishStatus> _waitForPublishCompletion(String requestId) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 1));
      final status = await _getPublishStatus(requestId);
      if (status != null) {
        return status;
      }
    }

    return _PublishStatus.timeout;
  }

  Future<_PublishStatus?> _getPublishStatus(String requestId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .doc('zikr_meta/publish_requests')
          .get();
      final data = doc.data();
      if (data == null) {
        return null;
      }

      final processedRequestId = data['processedRequestId']?.toString() ?? '';
      if (processedRequestId != requestId) {
        return null;
      }

      final status = data['status']?.toString() ?? '';
      if (status == 'success') {
        return _PublishStatus.success;
      }
      if (status == 'error') {
        return _PublishStatus.error;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    final menuItems = visibleHomeMenuItems;

    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: <Widget>[
            if (isUserAdmin) ...[
              IconButton(
                icon: _isPublishingIndex
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish),
                tooltip: 'Publish changes',
                onPressed: _isPublishingIndex ? null : _publishZikrIndex,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add item',
                onPressed: _showAddItemDialog,
              ),
            ],
            IconButton(
              icon: Icon(Icons.search),
              onPressed: _openSearch,
            )
          ],
        ),
        body: ResponsiveScrollableContent(
          maxWidth: wideContentWidth,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 22.0, horizontal: 16.0),
                  child: InkWell(
                    onTap: () {
                      SharePlus.instance.share(ShareParams(
                        text:
                            '$hadith\n\nShared via Shia Companion - https://www.onelink.to/ShiaCompanion',
                        sharePositionOrigin: Rect.fromLTWH(
                            MediaQuery.of(context).size.width / 2, 0, 2, 2),
                      ));
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Text(
                        '$hadith',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      child: HomePrayerTimesCard(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: LayoutBuilder(builder: (context, constraints) {
                  // Use maxCrossAxisExtent so grid adapts to available width
                  // Make the tiles smaller on narrow screens so more columns can fit
                  double maxExtent;
                  double spacing = 8.0;
                  if (constraints.maxWidth < 360) {
                    maxExtent = 140;
                    spacing = 6.0;
                  } else if (constraints.maxWidth < 600) {
                    maxExtent = 160;
                    spacing = 8.0;
                  } else if (constraints.maxWidth < 900) {
                    maxExtent = 190;
                    spacing = 10.0;
                  } else {
                    maxExtent = 210;
                    spacing = 12.0;
                  }
                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: maxExtent,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio:
                          constraints.maxWidth >= 900 ? 1.05 : 0.95,
                    ),
                    itemCount: menuItems.length,
                    itemBuilder: (BuildContext c, int i) {
                      final menuItem = menuItems[i];
                      return Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Card(
                          child: InkWell(
                            onTap: () => _openHomeMenuItem(menuItem),
                            child: LayoutBuilder(
                                builder: (context, tileConstraints) {
                              final double tileWidth = tileConstraints.maxWidth;
                              final double avatarRadius =
                                  (tileWidth * 0.18).clamp(18.0, 40.0);
                              final double iconSize = avatarRadius * 0.9;
                              final double fontSize = tileWidth > 140 ? 14 : 12;
                              final double verticalPadding =
                                  tileWidth > 140 ? 12 : 8;

                              return Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: verticalPadding, horizontal: 8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: avatarRadius,
                                      backgroundColor:
                                          Theme.of(context).primaryColor,
                                      child: Icon(
                                        menuItem.icon,
                                        size: iconSize,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: tileWidth > 140 ? 10 : 6),
                                    Text(
                                      menuItem.label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: fontSize),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ));
  }

  void initializeData() async {
    await _refreshHomeSessionState();
    getHadith();

    // Initialize synced user data from SharedPreferences or Firestore.
    await FavoritesManager.instance.loadFavorites();
    await QazaTrackerManager.instance.loadQaza();
    await PreferencesSyncService.instance.pullOrSeed();

    // On web, keep first load quiet and let the prayer card request location
    // only after the user taps it.
    if (!kIsWeb) {
      // Pass context only when there is nothing stored yet: that first fetch
      // needs the explainer and the permission prompt. Once a location exists,
      // an automatic refresh must never interrupt the user with a dialog — the
      // card shows the outcome instead.
      await LocationService.instance.refreshIfStale(
        context: LocationService.instance.hasLocation ? null : context,
      );
    }

    if (!kIsWeb) {
      await initializeNotificationTimeZone();

      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('ic_notification');

      DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();
      InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS);
      await flutterLocalNotificationsPlugin?.initialize(
        settings: initializationSettings,
      );
      // Two prompts back to back is one too many, so the OS permission dialog
      // is skipped on the launch we ask our own question; the opt-in requests
      // it itself, and only if the user actually wants azan.
      final askingAboutAzaan = AzaanOptInService.shouldAsk(
        hasLocation: LocationService.instance.hasLocation,
      );
      if (!askingAboutAzaan) {
        await requestNotificationPermissions();
      }
      await refreshExactPrayerAlarmPermissionStatus();
      if (askingAboutAzaan && mounted) {
        await _askAboutAzaan();
      }

      final List<PendingNotificationRequest>? pendingNotificationRequests =
          await flutterLocalNotificationsPlugin?.pendingNotificationRequests();
      pendingNotificationRequests
          ?.forEach((PendingNotificationRequest element) {
        debugPrint("${element.id} ${element.title} is scheduled");
      });
      needToSchedule =
          shouldRefreshPrayerNotificationSchedule(pendingNotificationRequests);
      if (needToSchedule) {
        await setUpNotifications();
      } else {
        debugPrint("Azan notifications not scheduled");
      }
    }
    await HomeScreenWidgetService.instance.publishAll();
    setState(() {});
  }

  Future<void> _refreshLocationOnResume() async {
    if (kIsWeb || !SP.isInitialized) return;

    // Cheap by design: this returns immediately unless the stored fix has aged
    // past the freshness window, so flicking away and back costs nothing.
    await LocationService.instance.refreshIfStale();
  }

  Future<void> _openSearch() async {
    final books = await LibraryService.loadBooks();
    if (!mounted) return;

    final zikrEntries = items.entries
        .map((entry) => UidTitleData(entry.key, entry.value))
        .toList();

    unawaited(AnalyticsService.searchOpened());
    showSearch(
      context: context,
      delegate: DataSearch(
        [
          ...zikrEntries,
          ...books,
        ],
        libraryUids: books.map((book) => book.uid).toSet(),
      ),
    );
  }

  Future<void> getHadith() async {
    final today =
        HijriCalendar.fromDate(DateTime.now().add(Duration(days: hijriDate)));
    final useMuharramQuotes =
        today.hMonth < 2 || (today.hMonth == 2 && today.hDay < 9);
    hadith = await loadRandomHadith(
      DefaultAssetBundle.of(context),
      useMuharramQuotes: useMuharramQuotes,
      random: Random(dailyHadithSeed()),
    );
    if (!mounted) return;
    setState(() {});
  }

  setupPreferences() async {
    await SP.init();
    await migrateZikrFocusModePreference();
    arabicFontSize = SP.prefs.getDouble('ara_font_size') ?? arabicFontSize;
    englishFontSize = SP.prefs.getDouble('eng_font_size') ?? englishFontSize;

    showTranslation = SP.prefs.getBool('showTranslation') ?? showTranslation;
    showTransliteration =
        SP.prefs.getBool('showTransliteration') ?? showTransliteration;

    hijriDate = SP.prefs.getInt('adjust_hijri_date') ?? hijriDate;

    city = SP.prefs.getString("city");
    lat = SP.prefs.getDouble("lat");
    long = SP.prefs.getDouble("long");
    LocationService.instance.restore();
    arabicFont = await FontPreferences.getSelectedFont() ?? "Qalam";

    // Azan stays off until the user says otherwise. A fresh install writes no
    // per-prayer preference at all, which is also how a later launch still
    // recognises it as never having been asked; an install that predates the
    // opt-in keeps whatever it already had.
    await AzaanOptInService.adoptChoiceFromExistingInstall();

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    appVersion = packageInfo.version;

    // WidgetsBinding.instance.addPostFrameCallback((_) => showAlertDialog());
    initializeData();
  }

  /// Puts the first-run azan question to the user and records the answer.
  ///
  /// The schedule is not rebuilt here: the caller does that a few lines later
  /// for every launch, and the answer has already changed the fingerprint it
  /// checks.
  Future<void> _askAboutAzaan() async {
    final enabled = await AzaanOptInService.ask(context);
    unawaited(AnalyticsService.feature(
      'azaan_opt_in',
      label: 'Azan opt-in',
      parameters: {'choice': enabled ? 'enabled' : 'declined'},
    ));
  }

  buildBody(BuildContext c, int i) {
    final menuItem = visibleHomeMenuItems[i];
    return InkWell(
      onTap: () => _openHomeMenuItem(menuItem),
      child: Container(
        margin: EdgeInsets.all(6.0),
        padding: EdgeInsets.only(
          left: 2.0,
        ),
        constraints: BoxConstraints.expand(height: 150.0, width: 150.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(6.0),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(menuItem.icon,
                size: 48, color: Theme.of(context).primaryColor),
            SizedBox(height: 8),
            Text(
              menuItem.label,
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Shader l = LinearGradient(colors: <Color>[Colors.black, Colors.white])
      .createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0));

  showAlertDialog() async {
    // set up the button
    Widget okButton = TextButton(
      child: Text("OK"),
      onPressed: () {
        Navigator.pop(context);
      },
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("What's New"),
      content: Text(
          "1. Azan notification added. By default Fajr, Dhuhr and Magrib are turned on.\n2. Live Holy Shrines and Islamic Channels\n3. Islamic calendar with events."),
      actions: [
        okButton,
      ],
    );

    // show the dialog
    int bnFromPref = SP.prefs.getInt('buildNumber') ?? 0;
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    // Show What's New Dialog only when build number is greater or in release mode
    if (int.parse(packageInfo.buildNumber) > bnFromPref && kReleaseMode) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return alert;
        },
      );
      await SP.prefs.setInt('buildNumber', int.parse(packageInfo.buildNumber));
    }
  }

  @override
  void dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _linkSubscription?.cancel();
    _widgetLinkChannel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocationOnResume();
    }
  }

  @override
  void didPopNext() {
    syncWebRoutePath('/', replace: true);
    setState(() {});
  }
}
