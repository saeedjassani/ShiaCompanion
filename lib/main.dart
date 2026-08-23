import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shia_companion/firebase_options.dart';
import 'package:shia_companion/pages/deep_link_launch_page.dart';
import 'package:shia_companion/pages/delete_account_page.dart';
import 'package:shia_companion/utils/dark_mode.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:shia_companion/utils/network_utils.dart';
import 'package:shia_companion/utils/webview_registry.dart'
    if (dart.library.js_interop) 'package:shia_companion/utils/webview_registry_web.dart';

import 'constants.dart';
import 'pages/home_page.dart';
import 'pages/widget_preview_page.dart';
import 'utils/deep_links.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  final FirebaseApp app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Firebase initialized: ${app.name}');

  // Set up Crashlytics for native platforms
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  }

  // Setup WebView for web platform
  registerWebViewWebImplementation();

  await NetworkUtils().initialize();

  runApp(const MyApp());
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

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    Widget buildHomePage() => MyHomePage(
          title: appName,
        );

    return ChangeNotifierProvider(
      create: (context) => DarkModeProvider(),
      child:
          Consumer<DarkModeProvider>(builder: (context, darkModeProvider, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: appName,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.brown,
              foregroundColor: Colors.white,
            ),
            bottomNavigationBarTheme:
                BottomNavigationBarThemeData(backgroundColor: Colors.brown),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.brown,
              brightness: Brightness.dark,
            ),
          ),
          themeMode:
              darkModeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
