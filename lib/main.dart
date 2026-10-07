import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:shia_companion/firebase_options.dart';
import 'package:shia_companion/pages/deep_link_launch_page.dart';
import 'package:shia_companion/pages/delete_account_page.dart';
import 'package:shia_companion/pages/setup/first_run_setup_page.dart';
import 'package:shia_companion/services/audio_download_store.dart';
import 'package:shia_companion/services/azan_playback_service.dart';
import 'package:shia_companion/services/first_run_setup.dart';
import 'package:shia_companion/utils/app_text_scale.dart';
import 'package:shia_companion/utils/language_provider.dart';
import 'package:shia_companion/utils/theme_mode.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/services.dart' show BrowserContextMenu;
import 'package:shia_companion/utils/crash_reporting.dart';
import 'package:shia_companion/utils/network_utils.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/webview_registry.dart'
    if (dart.library.js_interop) 'package:shia_companion/utils/webview_registry_web.dart';

import 'constants.dart';
import 'l10n/l10n.dart';
import 'navigation/app_shell.dart';
import 'navigation/keyboard_shortcuts.dart';
import 'pages/widget_preview_page.dart';
import 'utils/deep_links.dart';
import 'widgets/audio_download_button.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
    // Flutter Web defers to the browser's own right-click menu by default
    // and suppresses its own SelectableRegion/SelectionArea toolbar entirely
    // - so ZikrPage's custom contextMenuBuilder (Suggest a Correction,
    // alongside Copy and Select All) never has a chance to render until this
    // runs.
    // Selecting text itself still worked without it; only the menu that
    // acts on a selection was missing.
    await BrowserContextMenu.disableContextMenu();
  }

  // Must run before any AudioPlayer is constructed - it swaps in the handler
  // that keeps zikr audio playing, with a notification, once the app is
  // backgrounded or the screen locks.
  //
  // The channel name is a fixed category label, shown by Android next to the
  // app name in the notification's small header line - it can never be the
  // playing zikr's title, since the channel exists before any zikr is ever
  // opened. That title comes from the MediaItem each track carries instead
  // (see ZikrAudioPlayer), which is what the notification's own title reads.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.developer110.shia_companion.audio',
    androidNotificationChannelName: 'Recitation playback',
    // Keep the service in the foreground while paused. Letting it drop out
    // on pause (the default) left Android free to kill it once the app was
    // backgrounded, taking the notification - and the playlist - with it, so
    // a paused recitation could never be resumed from the lock screen.
    // Ongoing must be off for this: audio_service only allows an ongoing
    // notification when the service stops being foreground on pause. The
    // notification's own stop button still dismisses it.
    androidStopForegroundOnPause: false,
  );

  // Registers android_alarm_manager_plus's dispatch so a prayer-time alarm
  // fired while the app isn't running can still reach AzanPlaybackService's
  // callback. No-op off Android.
  await AzanPlaybackService.initialize();

  final FirebaseApp app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Firebase initialized: ${app.name}');

  // Turn off Firestore's LRU cache garbage collection. Its periodic pass
  // (every few minutes for as long as the process lives, which with the
  // `audio` background mode can be hours) hard-asserts and aborts the whole
  // app when its LevelDB commit fails - TestFlight build 120 crashed exactly
  // there (LocalStore::CollectGarbage -> LevelDbTransaction::Commit) four
  // hours after launch. The cache only ever holds this user's handful of
  // small `users/{uid}/...` docs, so it never comes close to needing eviction.
  // Must be set before anything touches FirebaseFirestore.instance: the
  // native instance only reads these settings when it's first created, and
  // persistenceEnabled has to be non-null for cacheSizeBytes to be applied.
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Set up Crashlytics for native platforms
  if (!kIsWeb) {
    FlutterError.onError = (FlutterErrorDetails details) {
      // See isKnownSelectionGeometryNullCheckError: an open Flutter framework
      // bug, not something app code caused or can fully prevent, so it's
      // downgraded to non-fatal rather than taking the app down.
      if (isKnownSelectionGeometryNullCheckError(details)) {
        FirebaseCrashlytics.instance.recordFlutterError(details, fatal: false);
        return;
      }
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
  }

  // Setup WebView for web platform
  registerWebViewWebImplementation();

  await NetworkUtils().initialize();

  // A finished offline download says so wherever the reader has got to.
  AudioDownloadStore.instance.results.listen(showAudioDownloadResult);

  // Decided before the first frame, so a fresh install opens straight on
  // setup rather than on Home with setup sliding over it.
  await SP.init();
  final showFirstRunSetup = await FirstRunSetup.resolveOnLaunch();

  runApp(MyApp(showFirstRunSetup: showFirstRunSetup));
}

enum _AppLaunchDestination {
  home,
  deleteAccount,
  widgetPreview,
}

_AppLaunchDestination _resolveLaunchDestination(Uri uri) {
  final segments =
      uri.pathSegments.where((segment) => segment.trim().isNotEmpty).toList();
  if (segments.length == 1 && segments.first == 'delete-account') {
    return _AppLaunchDestination.deleteAccount;
  }
  if (kDebugMode &&
      segments.length == 1 &&
      segments.first == 'widget-preview') {
    return _AppLaunchDestination.widgetPreview;
  }
  return _AppLaunchDestination.home;
}

// Built once: MyApp rebuilds on every frame of a text size slider drag.
final ThemeData _lightTheme = buildAppTheme(Brightness.light);
final ThemeData _darkTheme = buildAppTheme(Brightness.dark);

class MyApp extends StatelessWidget {
  const MyApp({Key? key, this.showFirstRunSetup = false}) : super(key: key);

  /// Open on first-run setup, then on the tabs (see FirstRunGate).
  final bool showFirstRunSetup;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    Widget buildHomePage() => FirstRunGate(
          showSetup: showFirstRunSetup,
          child: const AppShell(),
        );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeModeProvider()),
        ChangeNotifierProvider(create: (context) => AppTextScaleProvider()),
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
      ],
      child: Consumer3<ThemeModeProvider, AppTextScaleProvider,
              LanguageProvider>(
          builder: (context, themeModeProvider, textScaleProvider,
              languageProvider, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: appScaffoldMessengerKey,
          title: appName,
          // Always explicit, rather than left to Flutter's own resolution, so
          // the language the UI is in is the one LanguageProvider reports
          // (and L10n.current serves outside the widget tree).
          locale: languageProvider.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // The in-app Text size setting, layered over the system's own
          // text scale for every route, dialog and sheet under the navigator.
          builder: (context, child) => BackOnEscape(
            child: textScaleProvider.apply(context, child ?? const SizedBox()),
          ),
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: themeModeProvider.themeMode,
          home: switch (_resolveLaunchDestination(Uri.base)) {
            _AppLaunchDestination.deleteAccount => const DeleteAccountPage(),
            _AppLaunchDestination.widgetPreview => const WidgetPreviewPage(),
            _AppLaunchDestination.home => buildHomePage(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/delete-account') {
              return MaterialPageRoute(
                builder: (_) => const DeleteAccountPage(),
                settings: settings,
              );
            }
            if (kDebugMode && settings.name == '/widget-preview') {
              return MaterialPageRoute(
                builder: (_) => const WidgetPreviewPage(),
                settings: settings,
              );
            }
            if (isReservedNonZikrRouteName(settings.name)) {
              return _ignoredPlatformRoute(
                settings,
                fallbackBuilder: (_) => buildHomePage(),
              );
            }
            // Web only: give a shared link a route of its own so the launch URL
            // survives start-up. Without this the name falls through to
            // onUnknownRoute, which mounts home and then removes itself,
            // rewriting the address bar to "/" on the way out. Native builds
            // report "/" here and receive their links through app_links, so
            // this never runs for them.
            if (kIsWeb) {
              final launchRoute = _launchDeepLinkRoute(settings);
              if (launchRoute != null) {
                return launchRoute;
              }
            }
            return null;
          },
          onUnknownRoute: (settings) {
            return _ignoredPlatformRoute(
              settings,
              fallbackBuilder: (_) => buildHomePage(),
            );
          },
          navigatorObservers: [
            // No FirebaseAnalyticsObserver: routes here are pushed without
            // names, so it logged blank screens on mobile and double-counted
            // every screen that also calls trackScreen. AnalyticsService.screen
            // is the single source of screen views, on every platform.
            routeObserver,
          ],
        );
      }),
    );
  }
}

/// Builds the route for a link the web app booted into, or null when the name
/// is not a deep link.
///
/// Navigator splits an initial route like /zikr/<slug> into "/", "/zikr" and
/// "/zikr/<slug>", generating what it can and discarding the rest, so home
/// stays underneath and back still reaches it. A library chapter link yields
/// the chapter over its chapter list the same way.
Route<void>? _launchDeepLinkRoute(RouteSettings settings) {
  final target = parseLaunchRouteName(settings.name);
  if (target == null) return null;

  webLaunchDeepLinkHandled = true;
  return MaterialPageRoute<void>(
    builder: (_) => DeepLinkLaunchPage(target: target),
    settings: settings,
  );
}

Route<void> _ignoredPlatformRoute(
  RouteSettings settings, {
  required WidgetBuilder fallbackBuilder,
}) {
  return PageRouteBuilder<void>(
    settings: settings,
    opaque: false,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, _, __) => _IgnoredPlatformRoutePage(
      fallbackBuilder: fallbackBuilder,
    ),
  );
}

class _IgnoredPlatformRoutePage extends StatefulWidget {
  const _IgnoredPlatformRoutePage({
    required this.fallbackBuilder,
  });

  final WidgetBuilder fallbackBuilder;

  @override
  State<_IgnoredPlatformRoutePage> createState() =>
      _IgnoredPlatformRoutePageState();
}

class _IgnoredPlatformRoutePageState extends State<_IgnoredPlatformRoutePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final route = ModalRoute.of(context);
      if (route != null && navigator.canPop()) {
        navigator.removeRoute(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) {
      return widget.fallbackBuilder(context);
    }

    return const IgnorePointer(child: SizedBox.expand());
  }
}
