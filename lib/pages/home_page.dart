import 'dart:async';
import 'dart:ui' as ui;
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
import 'package:shia_companion/services/activity_stats_store.dart';
import 'package:shia_companion/services/azaan_opt_in_service.dart';
import 'package:shia_companion/services/deep_link_resolver.dart';
import 'package:shia_companion/services/favorites_manager.dart';
import 'package:shia_companion/services/home_screen_widget_service.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/services/location_service.dart';
import 'package:shia_companion/services/prayer_preferences_sync_service.dart';
import 'package:shia_companion/services/preferences_sync_service.dart';
import 'package:shia_companion/services/qaza_tracker_manager.dart';
import 'package:shia_companion/services/recitation_tracker_manager.dart';
import 'package:shia_companion/services/saved_verses_manager.dart';
import 'package:shia_companion/services/rating_prompt_service.dart';
import 'package:shia_companion/services/session_refresh_service.dart';
import 'package:shia_companion/services/whats_new_service.dart';
import 'package:shia_companion/services/zikr_bookmarks_manager.dart';
import 'package:shia_companion/services/zikr_reminder_service.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/font_preferences.dart';
import 'package:shia_companion/utils/hadith_loader.dart';
import 'package:shia_companion/utils/localized_hadith.dart';
import 'package:shia_companion/utils/islamic_day.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/web_route_sync.dart';

import 'package:shia_companion/pages/all_features_page.dart';
import 'package:shia_companion/pages/home/coming_up_section.dart';
import 'package:shia_companion/pages/home/continue_section.dart';
import 'package:shia_companion/pages/home/hadith_card.dart';
import 'package:shia_companion/pages/home/get_app_card.dart';
import 'package:shia_companion/pages/home/home_header.dart';
import 'package:shia_companion/pages/home/home_section.dart';
import 'package:shia_companion/pages/home/shortcuts_section.dart';
import 'package:shia_companion/theme/shia_colors.dart';
import 'package:shia_companion/widgets/glass_surface.dart';
import 'package:shia_companion/widgets/responsive_content.dart';
import 'package:shia_companion/widgets/prayer_times_widget.dart';
import 'package:shia_companion/widgets/whats_new_dialog.dart';
import 'package:shia_companion/widgets/zikr_reading_preferences.dart';
import 'package:shia_companion/services/analytics_service.dart';
import '../l10n/l10n.dart';

/// The Home tab: everything that used to be the home screen, under a
/// greeting with the profile button (Settings) in place of the old app bar.
/// Search moved to the round button beside the tab bar (see AppShell).
///
/// Also where start-up work runs - deep links, notifications, the sync
/// managers - since Home is the tab every launch opens on.
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with WidgetsBindingObserver, RouteAware {
  String hadith = '';

  /// Today's hadith outside English; null in English.
  LocalizedHadith? localizedHadith;

  /// The app language [getHadith] last loaded for, so a change of language
  /// loads the hadith again.
  String? _hadithLanguage;
  DateTime today = DateTime.now();

  List<LiveStreamingData>? holyShrine, liveChannel;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  MethodChannel? _widgetLinkChannel;
  DeepLinkTarget? _pendingDeepLink;
  bool _itemsLoaded = false;
  String? _lastDeepLinkKey;
  DateTime? _lastDeepLinkAt;

  /// Set once start-up has acted on the notification tap that launched the
  /// app, if any; resumes check for a later one only from then on.
  bool _launchNotificationHandled = false;

  void _openHomeMenuItem(HomeMenuItem item) {
    item.open(context);
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
    _scrollController.addListener(_onScroll);
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

    await _takePendingWidgetUrl();
  }

  /// Opens the link a home screen widget tap left with MainActivity, if any.
  ///
  /// Run at start-up and on every resume: after Back closes the screen the
  /// app can keep running without one (MainActivity reuses audio_service's
  /// engine), and a widget tap then opens a new screen whose link only
  /// waits here - Home's start-up, the only other reader, ran long ago.
  /// MainActivity hands each link out once, so asking again is harmless.
  Future<void> _takePendingWidgetUrl() async {
    final channel = _widgetLinkChannel;
    if (channel == null) return;
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

    if (target.type == calendarDeepLinkType) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openHomeMenuItem(calendarMenuItem);
      });
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
    // A home-screen widget's own URL carries which widget it was tapped from;
    // an ordinary shared link carries none, and falls back to the generic
    // deepLink source it always has.
    final source = target.source ?? ZikrOpenSource.deepLink;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ZikrPage(
        resolvedItem,
        source: source,
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

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    final insets = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= homeWideBreakpoint;
    final desktop = width >= 1024;
    final gutter = wide ? 32.0 : 16.0;
    final gap = wide ? 24.0 : 18.0;

    final header = HomeHeader(
      onOpenSettings: () => _openHomeMenuItem(settingsMenuItem),
    );
    final prayerCard = HomePrayerTimesCard(
      onTap: () => _openHomeMenuItem(calendarMenuItem),
      footer: ComingUpRow(
        onOpenCalendar: () => _openHomeMenuItem(calendarMenuItem),
      ),
    );
    final shortcuts = ShortcutsSection(
      onOpen: _openHomeMenuItem,
      onOpenAllFeatures: _openAllFeatures,
    );
    final hadithCard = hadith.isEmpty && localizedHadith == null
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(top: gap),
            child: HadithOfTheDayCard(
              hadith: hadith,
              localized: localizedHadith,
            ),
          );
    final getApp = kIsWeb
        ? Padding(padding: EdgeInsets.only(top: gap), child: const GetAppCard())
        : const SizedBox.shrink();

    final Widget content;
    if (wide) {
      // Tablet and up: prayer card, Continue and (on the web) Get the app
      // on the left; Shortcuts and the hadith on the right.
      content = Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: desktop ? 115 : 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      prayerCard,
                      ContinueSection(topSpacing: gap, horizontalPadding: 0),
                      getApp,
                    ],
                  ),
                ),
                SizedBox(width: desktop ? 32 : 24),
                Expanded(
                  flex: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [shortcuts, hadithCard],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      final pad = EdgeInsets.symmetric(horizontal: gutter);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: pad, child: header),
          SizedBox(height: gap),
          Padding(padding: pad, child: prayerCard),
          // Draws its own gutter: its cards scroll to the screen's edge.
          ContinueSection(topSpacing: gap, horizontalPadding: gutter),
          SizedBox(height: gap),
          Padding(padding: pad, child: shortcuts),
          Padding(padding: pad, child: hadithCard),
          Padding(padding: pad, child: getApp),
        ],
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            // The bottom inset includes the floating tab bar, so the last
            // section can scroll clear of it.
            padding: EdgeInsets.only(
              top: insets.top + (wide ? 24 : 12),
              bottom: insets.bottom + 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: wideContentWidth),
                child: content,
              ),
            ),
          ),
          _CompactTitleBar(visible: _showCompactTitle, topInset: insets.top),
        ],
      ),
    );
  }

  final ScrollController _scrollController = ScrollController();

  /// Whether the header has scrolled away, so the small title bar shows.
  final ValueNotifier<bool> _showCompactTitle = ValueNotifier(false);

  void _onScroll() {
    _showCompactTitle.value = _scrollController.offset > 56;
  }

  void _openAllFeatures() {
    unawaited(AnalyticsService.feature(
      'home_menu_all_features',
      label: 'All features',
    ));
    pushPageRoute(context, const AllFeaturesPage());
  }

  void initializeData() async {
    // A tap on a prayer notification that cold-launched the app is someone
    // asking to hear the Azan *now*, so it's acted on before anything below
    // that can wait on the network or GPS. It used to be handled only after
    // the Firestore pulls and the location refresh (a GPS fix plus an
    // untimed reverse-geocode request - and the stored fix is always stale
    // by Fajr), so tapping did nothing for up to a minute or more. Worse,
    // those awaits freeze while iOS has the app suspended: a reader who gave
    // up and locked the phone had the Azan start by itself whenever the app
    // next came to the foreground, however much later that was.
    //
    // Reading launch details needs no initialize() call. Zikr reminder taps
    // still wait for the zikr index (loaded by _refreshHomeSessionState)
    // further down.
    NotificationResponse? launchResponse;
    if (!kIsWeb) {
      final launchDetails = await FlutterLocalNotificationsPlugin()
          .getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        launchResponse = launchDetails?.notificationResponse;
      }
      if (launchResponse != null &&
          !isZikrReminderNotificationResponse(launchResponse)) {
        // Unawaited: playback's future only completes when the Azan ends.
        unawaited(handlePrayerNotificationResponse(launchResponse));
        launchResponse = null;
      }
    }

    await _refreshHomeSessionState();
    getHadith();

    // Initialize synced user data from SharedPreferences or Firestore.
    await FavoritesManager.instance.loadFavorites();
    await QazaTrackerManager.instance.loadQaza();
    await RecitationTrackerManager.instance.loadRecitations();
    await SavedVersesManager.instance.loadSavedVerses();
    await ZikrBookmarksManager.instance.loadBookmarks();
    await PreferencesSyncService.instance.pullOrSeed();
    await PrayerPreferencesSyncService.instance.pullOrSeed();
    unawaited(ActivityStatsStore.instance.pullAndMerge());

    // On web, keep first load quiet and let the prayer card request location
    // only after the user taps it.
    if (!kIsWeb) {
      // Never with context: an automatic refresh must not interrupt with a
      // dialog or a permission prompt - those follow "Use my location" in
      // setup or on the prayer card. Without a location yet this fetches
      // only if the phone already allows it; the card offers the rest.
      await LocationService.instance.refreshIfAllowed();
    }

    if (!kIsWeb) {
      await initializeNotificationTimeZone();
      await ensureNotificationsPlugin();
      // A zikr reminder tap that launched the app from fully terminated
      // (prayer taps were already handled at the top of this method).
      if (launchResponse != null) {
        await handlePrayerNotificationResponse(launchResponse);
      }
      _launchNotificationHandled = true;
      // On iOS a launching tap can reach the plugin after the read at the
      // top of this method, yet before initialize() - then it is passed to
      // neither callback and waits only in the launch details. A tap
      // already handled is skipped.
      unawaited(handleNotificationThatOpenedApp());
      // Only for someone with something to be notified about: the prompt
      // follows "Turn on azan" or adding a reminder, never a bare launch
      // (setup's Azan step is where a new install is asked). Costs nothing
      // once permission is settled - neither OS re-prompts.
      await ZikrReminderService.instance.load();
      if (AzaanOptInService.isEnabled ||
          ZikrReminderService.instance.reminders.isNotEmpty) {
        await requestNotificationPermissions();
      }
      await refreshExactPrayerAlarmPermissionStatus();

      // A fresh install has nothing to catch up on (see WhatsNewService);
      // it has just been through setup instead.
      final whatsNew = await WhatsNewService.pending();
      await WhatsNewService.markSeen();
      if (whatsNew.isNotEmpty && mounted) {
        await showWhatsNewDialog(context, whatsNew);
      }

      // Only tracks install age here - the rating prompt itself is asked
      // from a real moment of engagement (see zikr_page.dart's
      // _maybeRecordCompletion), not on cold start.
      await RatingPromptService.recordLaunch();

      final List<PendingNotificationRequest>? pendingNotificationRequests =
          await flutterLocalNotificationsPlugin?.pendingNotificationRequests();
      pendingNotificationRequests
          ?.forEach((PendingNotificationRequest element) {
        debugPrint("${element.id} ${element.title} is scheduled");
      });
      needToSchedule = shouldRefreshPrayerNotificationSchedule(
              pendingNotificationRequests) ||
          await arePrayerAzanAlarmsMissing(pendingNotificationRequests);
      if (needToSchedule) {
        await setUpNotifications();
      } else {
        debugPrint("Azan notifications not scheduled");
      }
      // Cheap once there are no reminders, so this runs on every cold start
      // rather than trying to track whether anything changed.
      await ZikrReminderService.instance.rescheduleAll();
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

  Future<void> getHadith() async {
    // The Islamic day: from Maghrib on 8 Rabi' al-Awwal it is already the
    // 9th's eve, so the Muharram quotes end with the day the header shows.
    final today = islamicDayAt(DateTime.now()).day.hijri;
    final useMuharramQuotes =
        today.hMonth < 2 || (today.hMonth == 2 && today.hDay < 9);
    final bundle = DefaultAssetBundle.of(context);
    final language = L10n.current.localeName;
    _hadithLanguage = language;
    final localized = await loadLocalizedHadith(
      bundle,
      languageCode: language,
      useMuharramQuotes: useMuharramQuotes,
      day: hadithDayNumber(),
    );
    // Only English readers get the English collection: anyone else sees
    // their own language or, if it cannot be read, no hadith at all.
    final english = language != 'en'
        ? ''
        : await loadDailyHadith(
            bundle,
            useMuharramQuotes: useMuharramQuotes,
            day: hadithDayNumber(),
          );
    if (!mounted || language != _hadithLanguage) return;
    setState(() {
      localizedHadith = localized;
      hadith = english;
    });
  }

  setupPreferences() async {
    await SP.init();
    await migrateZikrFocusModePreference();
    arabicFontSize = SP.prefs.getDouble('ara_font_size') ?? arabicFontSize;
    englishFontSize = SP.prefs.getDouble('eng_font_size') ?? englishFontSize;

    showTranslation = SP.prefs.getBool('showTranslation') ?? showTranslation;
    showTransliteration =
        SP.prefs.getBool('showTransliteration') ?? showTransliteration;
    showArabicAsParagraph =
        SP.prefs.getBool('showArabicAsParagraph') ?? showArabicAsParagraph;

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
    // Same idea for the rating prompt: an install that predates it is
    // backfilled as already past its age/launch thresholds rather than
    // started fresh (see RatingPromptService.adoptExistingInstall).
    await RatingPromptService.adoptExistingInstall();

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    appVersion = packageInfo.version;

    initializeData();
  }

  @override
  void dispose() async {
    _scrollController.dispose();
    _showCompactTitle.dispose();
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
    if (_hadithLanguage != null &&
        _hadithLanguage != context.l10n.localeName) {
      getHadith();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // A tap that reached Dart by neither of the plugin's callbacks (see
      // handleNotificationThatOpenedApp). Not before start-up has handled
      // the tap that launched it. Unawaited: playback's future only
      // completes when the Azan ends.
      if (_launchNotificationHandled) {
        unawaited(handleNotificationThatOpenedApp());
      }
      unawaited(_takePendingWidgetUrl());
      _refreshLocationOnResume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(ActivityStatsStore.instance.pushIfDue());
    }
  }

  @override
  void didPopNext() {
    syncWebRoutePath('/', replace: true);
    setState(() {});
  }
}

/// The app's name over a frosted strip, once the header has scrolled out of
/// view. Decorative: the date already headed the page.
class _CompactTitleBar extends StatelessWidget {
  const _CompactTitleBar({required this.visible, required this.topInset});

  final ValueListenable<bool> visible;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final solid =
        !GlassSurface.blurEnabled || MediaQuery.highContrastOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget bar = Container(
      height: topInset + 44,
      padding: EdgeInsets.only(top: topInset),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: solid ? colors.ground : colors.ground.withValues(alpha: 0.88),
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Text(context.l10n.appTitle,
          style: ShiaText.cardTitle.copyWith(color: colors.text)),
    );
    if (!solid) {
      bar = ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: bar,
        ),
      );
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, show, child) => IgnorePointer(
          ignoring: !show,
          child: AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 150),
            child: child,
          ),
        ),
        child: ExcludeSemantics(child: bar),
      ),
    );
  }
}
