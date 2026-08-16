import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands up enough of Firebase for a screen to be rendered.
///
/// Screens reach Firebase in two distinct ways, and both have to be answered or
/// the widget under test never gets as far as laying out:
///
///   * Construction. `FavoritesManager` and `QazaTrackerManager` hold
///     `FirebaseFirestore.instance`, `FirebaseAuth.instance` and
///     `FirebaseDatabase.instance` in field initialisers, and `ItemList` builds
///     a collection reference the same way. Every one of those throws
///     `[core/no-app]` until an app exists, which is what
///     [setupFirebaseCoreMocks] plus `Firebase.initializeApp` provides.
///   * Calls. Screens then read from those instances, usually unawaited from
///     `initState`. With no plugin behind the channel the call raises
///     `MissingPluginException`, which surfaces as an unhandled async error and
///     fails the test for a reason that has nothing to do with rendering.
///
/// The handlers below answer the second case with empty data, so a screen
/// renders its "nothing here yet" state — which is the state worth having a
/// render test for anyway, since it is what a new user sees.
Future<void> setUpFirebaseForRenderTests() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  await Firebase.initializeApp();
  _silenceFirebaseChannels();
}

/// Channels whose absence would otherwise raise MissingPluginException.
///
/// Each returns the emptiest well-formed answer the plugin will accept rather
/// than throwing, so callers take their "no data" path.
const Map<String, Object?> _emptyResponses = <String, Object?>{
  // cloud_firestore
  'Query#get': <String, Object?>{'documents': [], 'metadatas': []},
  'DocumentReference#get': <String, Object?>{'data': null, 'metadata': null},
  'DocumentReference#set': null,
  'DocumentReference#update': null,
  'Firestore#enableNetwork': null,
  'Firestore#disableNetwork': null,
  // firebase_auth
  'Auth#registerIdTokenListener': null,
  'Auth#registerAuthStateListener': null,
  'Auth#signInAnonymously': null,
  // firebase_database
  'DatabaseReference#get': <String, Object?>{'snapshot': null},
  'DatabaseReference#once': <String, Object?>{'snapshot': null},
};

void _silenceFirebaseChannels() {
  const channels = <String>[
    'plugins.flutter.io/firebase_core',
    'plugins.flutter.io/firebase_auth',
    'plugins.flutter.io/firebase_firestore',
    'plugins.flutter.io/firebase_database',
    'plugins.flutter.io/firebase_analytics',
  ];

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  for (final name in channels) {
    messenger.setMockMethodCallHandler(
      MethodChannel(name, const StandardMethodCodec()),
      (call) async => _emptyResponses[call.method],
    );
  }
}
