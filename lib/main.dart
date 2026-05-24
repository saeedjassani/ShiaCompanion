import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shia_companion/firebase_options.dart';
import 'package:shia_companion/pages/delete_account_page.dart';
import 'package:shia_companion/utils/dark_mode.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
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
    final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    final FirebaseAnalyticsObserver observer =
        FirebaseAnalyticsObserver(analytics: analytics);

    return ChangeNotifierProvider(
      create: (context) => DarkModeProvider(),
      child:
          Consumer<DarkModeProvider>(builder: (context, darkModeProvider, _) {
        return MaterialApp(
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
            _AppLaunchDestination.home => MyHomePage(
                title: appName,
                analytics: analytics,
                observer: observer,
              ),
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
              return _ignoredPlatformRoute(settings);
            }
            return null;
          },
          onUnknownRoute: (settings) {
            return _ignoredPlatformRoute(settings);
          },
          navigatorObservers: [observer, routeObserver],
        );
      }),
    );
  }
}

Route<void> _ignoredPlatformRoute(RouteSettings settings) {
  return PageRouteBuilder<void>(
    settings: settings,
    opaque: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, _, __) => const _IgnoredPlatformRoutePage(),
  );
}

class _IgnoredPlatformRoutePage extends StatefulWidget {
  const _IgnoredPlatformRoutePage();

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
      Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
