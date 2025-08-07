import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shia_companion/firebase_options.dart';
import 'package:shia_companion/utils/dark_mode.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'constants.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  // Pass all uncaught errors from the framework to Crashlytics.
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    // You may also want to set collection enabled status here
    // await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    analytics.logAppOpen();
    return ChangeNotifierProvider(
      create: (context) => DarkModeProvider(context),
      child:
          Consumer<DarkModeProvider>(builder: (context, darkModeProvider, _) {
        return MaterialApp(
          title: appName,
          theme: ThemeData(
            primarySwatch: Colors.brown,
            bottomNavigationBarTheme:
                BottomNavigationBarThemeData(backgroundColor: Colors.brown),
          ),
          darkTheme: ThemeData.dark().copyWith(
              colorScheme: ThemeData.dark().colorScheme.copyWith(
                    primary: Colors.white,
                    secondary:
                        Colors.orange[100], // Set accent color for dark theme
                  ),
              textSelectionTheme:
                  TextSelectionThemeData(selectionColor: Colors.white)),
          themeMode:
              darkModeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: MyHomePage(
            title: appName,
            analytics: analytics,
            observer: observer,
          ),
          navigatorObservers: [routeObserver],
        );
      }),
    );
  }
}
