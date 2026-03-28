import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:location/location.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/live_streaming_data.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/calendar_page.dart';
import 'package:shia_companion/pages/deep_link_not_found_page.dart';
import 'package:shia_companion/pages/zikr_page.dart';
import 'package:shia_companion/utils/data_search.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/font_preferences.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'package:shia_companion/widgets/prayer_times_widget.dart';

import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class MyHomePage extends StatefulWidget {
  MyHomePage({
    required this.title,
    required this.analytics,
    required this.observer,
  });

  final String title;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with WidgetsBindingObserver, RouteAware {
  String hadith = '';
  LocationData? currentLocation;
  DateTime today = DateTime.now();

  Location location = Location();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DatabaseReference? favsReference;

  List<LiveStreamingData>? holyShrine, liveChannel;
  String? initialFavs;
  DatabaseReference? newFavsReference;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  DeepLinkTarget? _pendingDeepLink;
  bool _itemsLoaded = false;
  String? _lastDeepLinkKey;
  DateTime? _lastDeepLinkAt;
  final CollectionReference<Map<String, dynamic>> _zikrCollection =
      FirebaseFirestore.instance.collection('zikr');

  bool scrollToPrayerTimes = false;

  callback() {
    // Navigate to calendar and scroll to prayer times when invoked from the home card
    scrollToPrayerTimes = true;
    pushPageRoute(context, CalendarPage(scrollToPrayerTimes));
  }

  loginCallback() async {
    await setUpFavorites();
  }

  @override
  void initState() {
    super.initState();
    trackScreen('Home Page');
    WidgetsBinding.instance.addObserver(this);
    _setupDeepLinks();
    setupPreferences();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  Future<void> _setupDeepLinks() async {
    _queueDeepLink(parseDeepLinkUri(Uri.base));

    if (kIsWeb) return;

    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      _queueDeepLink(parseDeepLinkUri(initialLink));
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _queueDeepLink(parseDeepLinkUri(uri));
    });
  }

  void _queueDeepLink(DeepLinkTarget? target) {
    if (target == null) return;

    final now = DateTime.now();
    if (_lastDeepLinkKey == target.key &&
        _lastDeepLinkAt != null &&
        now.difference(_lastDeepLinkAt!) < const Duration(seconds: 2)) {
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

    if (target.type != 0 || target.segments.isEmpty) {
      _openDeepLinkNotFound(target.key);
      return;
    }

    final resolvedItem = await _resolveDeepLinkItem(target);
    if (!mounted) return;
    if (resolvedItem == null) {
      _openDeepLinkNotFound(target.segments.join('/'));
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      pushPageRoute(context, ZikrPage(resolvedItem));
    });
  }

  Future<UidTitleData?> _resolveDeepLinkItem(DeepLinkTarget target) async {
    if (target.segments.isEmpty) return null;

    final primarySegment = target.segments.first;
    if (items.containsKey(primarySegment)) {
      final title = items[primarySegment];
      if (title is String && title.isNotEmpty) {
        return UidTitleData(primarySegment, title);
      }
    }

    final cachedUid = slugToItemUid[primarySegment];
    if (cachedUid != null) {
      final title = items[cachedUid];
      if (title is String && title.isNotEmpty) {
        return UidTitleData(cachedUid, title);
      }
    }

    return _fetchDeepLinkItemFromFirestore(primarySegment);
  }

  Future<UidTitleData?> _fetchDeepLinkItemFromFirestore(String segment) async {
    final directUidSnapshot = await _zikrCollection.doc(segment).get();
    final directUidItem = _buildDeepLinkItemFromSnapshot(directUidSnapshot);
    if (directUidItem != null) {
      return directUidItem;
    }

    final slugSnapshot =
        await _zikrCollection.where('slug', isEqualTo: segment).limit(1).get();
    if (slugSnapshot.docs.isNotEmpty) {
      final slugItem = _buildDeepLinkItemFromSnapshot(slugSnapshot.docs.first);
      if (slugItem != null) {
        return slugItem;
      }
    }

    final aliasSnapshot = await _zikrCollection
        .where('slugAliases', arrayContains: segment)
        .limit(1)
        .get();
    if (aliasSnapshot.docs.isEmpty) return null;

    return _buildDeepLinkItemFromSnapshot(aliasSnapshot.docs.first);
  }

  UidTitleData? _buildDeepLinkItemFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) return null;

    final data = snapshot.data();
    if (data == null) return null;

    final title = data['title']?.toString().trim() ?? '';
    if (title.isEmpty) return null;

    final hasPrimaryData = data['data']?.toString().trim().isNotEmpty == true;
    final rawTabs = data['tabs'];
    final hasTabData = rawTabs is List &&
        rawTabs.any((tab) => tab?.toString().trim().isNotEmpty == true);
    if (!isUserAdmin && !hasPrimaryData && !hasTabData) {
      return null;
    }

    final uid = snapshot.id;
    items[uid] = title;
    final order = data['order'];
    if (order is num) {
      itemOrder[uid] = order.toDouble();
    }
    setLocalSlugData(
      uid,
      slug: data['slug']?.toString(),
      aliases: data['slugAliases'] is Iterable ? data['slugAliases'] : null,
    );
    return UidTitleData(uid, title);
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
                              startEditing: true));
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

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: <Widget>[
            if (isUserAdmin) ...[
              IconButton(
                icon: Icon(Icons.add),
                onPressed: _showAddItemDialog,
              ),
            ],
            IconButton(
                icon: Icon(Icons.search),
                onPressed: () {
                  showSearch(
                      context: context,
                      delegate: DataSearch(items.entries
                          .map((entry) => UidTitleData(entry.key, entry.value))
                          .toList()));
                })
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 32.0, horizontal: 16.0),
                  child: InkWell(
                    onTap: () {
                      SharePlus.instance.share(ShareParams(
                        text:
                            '$hadith\n\nShared via Shia Companion - https://www.onelink.to/ShiaCompanion',
                        sharePositionOrigin: Rect.fromLTWH(
                            MediaQuery.of(context).size.width / 2, 0, 2, 2),
                      ));
                    },
                    child: SingleChildScrollView(
                      child: Text(
                        '$hadith',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                  child: HomePrayerTimesCard(callback),
                ),
              ),
              SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(8.0),
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
                  } else {
                    maxExtent = 240;
                    spacing = 8.0;
                  }
                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: maxExtent,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio: constraints.maxWidth < 400 ? 0.95 : 0.9,
                    ),
                    itemCount: zikr.length,
                    itemBuilder: (BuildContext c, int i) {
                      return Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Card(
                          child: InkWell(
                            onTap: () {
                              // Preferences is handled specially because it requires a callback
                              Widget page = getPage(zikr[i],
                                  loginCallback: loginCallback,
                                  scrollToPrayerTimes: false);
                              if (page is Container) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Coming soon")));
                              } else {
                                pushPageRoute(context, page);
                              }
                            },
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
                                        zikrIcons[i],
                                        size: iconSize,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: tileWidth > 140 ? 10 : 6),
                                    Text(
                                      zikr[i],
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

  Future<void> _loadItemsFromAssets() async {
    try {
      String data =
          await DefaultAssetBundle.of(context).loadString("assets/items.json");
      final decoded = json.decode(data);
      items = {};
      itemOrder = {};
      clearLocalSlugMaps();
      decoded.forEach((key, value) {
        if (value is Map) {
          items[key] = value['title'] ?? '';
          final order = value['order'];
          if (order is num) itemOrder[key] = order.toDouble();
        } else {
          items[key] = value;
        }
      });
    } catch (e) {
      debugPrint("Error loading items from assets: $e");
    }
  }

  Future<void> _loadItemsFromFirebase() async {
    try {
      final doc = await FirebaseFirestore.instance.doc('zikr_meta/index').get();
      if (doc.exists && doc['items'] != null) {
        final rawItems = doc['items'];
        items = {};
        itemOrder = {};
        clearLocalSlugMaps();
        final visibleUids = <String>{};

        // Filter items based on admin status
        rawItems.forEach((key, value) {
          final title = value is Map ? value['title'] : value;
          final hasData = value is Map ? value['hasData'] ?? false : true;
          final order = value is Map ? value['order'] : null;
          final slug = value is Map ? value['slug'] : null;
          final slugAliases = value is Map ? value['slugAliases'] : null;

          // Show all items to admins, only items with data to users
          if (isUserAdmin || hasData) {
            items[key] = title;
            visibleUids.add(key.toString());
            if (order is num) itemOrder[key] = order.toDouble();
            setLocalSlugData(
              key.toString(),
              slug: slug?.toString(),
              aliases: slugAliases is Iterable ? slugAliases : null,
            );
          }
        });
        final rawSlugLookup = doc.data()?['slugLookup'];
        if (rawSlugLookup is Map) {
          applySlugLookupMap(rawSlugLookup, visibleUids);
        }
      }
    } catch (e) {
      debugPrint("Error loading zikr index: $e");
    }
  }

  void initializeData() async {
    user = _auth.currentUser;
    if (user != null) {
      final idTokenResult = await user?.getIdTokenResult(true);
      final claims = idTokenResult?.claims;
      if (claims != null && claims['admin'] == true) {
        isUserAdmin = true;
      }
    }
    // Load index from Firebase (free tier friendly - single read per app launch)
    await _loadItemsFromFirebase();
    // Fall back to assets if Firebase fails
    if (items.isEmpty) {
      await _loadItemsFromAssets();
    }
    getHadith();

    await setUpFavorites();

    // Initialize LocationData
    await initializeLocation(context: context);

    if (!kIsWeb) {
      tz.initializeTimeZones();
      final currentTimeZone = tz.local.name;
      tz.setLocalLocation(tz.getLocation(currentTimeZone));

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

      await flutterLocalNotificationsPlugin?.cancelAll();
      final List<PendingNotificationRequest>? pendingNotificationRequests =
          await flutterLocalNotificationsPlugin?.pendingNotificationRequests();
      pendingNotificationRequests
          ?.forEach((PendingNotificationRequest element) {
        debugPrint("${element.id} ${element.title} is scheduled");
        if (element.id == 786 &&
            element.payload != null &&
            DateTime.now()
                    .difference(DateTime.fromMillisecondsSinceEpoch(
                        int.parse(element.payload!)))
                    .inDays <
                -2) {
          needToSchedule = false;
        }
      });
      if (needToSchedule) {
        setUpNotifications();
      } else {
        debugPrint("Azan notifications not scheduled");
      }
    }
    _itemsLoaded = true;
    _resolvePendingDeepLink();
    setState(() {});
  }

  // 0 - 2340 General
  // 2341 - 2375 Muharram
  Future<void> getHadith() async {
    HijriCalendar _today =
        HijriCalendar.fromDate(DateTime.now().add(Duration(days: hijriDate)));
    Random rnd = Random();
    int min = 0, max = 2341;
    if (_today.hMonth < 2 || (_today.hMonth == 2 && _today.hDay < 9)) {
      min = 2341;
      max = 2376;
    }
    int randomIndex = min + rnd.nextInt(max - min);
    String hadithString =
        await DefaultAssetBundle.of(context).loadString('assets/hadith.csv');
    List csvTable = CsvToListConverter().convert(hadithString);
    hadith = csvTable[randomIndex][0];
    setState(() {});
  }

  setupPreferences() async {
    await SP.init();
    arabicFontSize = SP.prefs.getDouble('ara_font_size') ?? arabicFontSize;
    englishFontSize = SP.prefs.getDouble('eng_font_size') ?? englishFontSize;

    showTranslation = SP.prefs.getBool('showTranslation') ?? showTranslation;
    showTransliteration =
        SP.prefs.getBool('showTransliteration') ?? showTransliteration;

    hijriDate = SP.prefs.getInt('adjust_hijri_date') ?? hijriDate;

    city = SP.prefs.getString("city");
    lat = SP.prefs.getDouble("lat");
    long = SP.prefs.getDouble("long");
    arabicFont = await FontPreferences.getSelectedFont() ?? "Qalam";

    // By default turn on Azan for Fajr, Dhuhr and Maghrib
    if (SP.prefs.getBool('fajr_notification') == null) {
      await SP.prefs.setBool('fajr_notification', true);
      await SP.prefs.setBool('dhuhr_notification', true);
      await SP.prefs.setBool('maghrib_notification', true);
      await SP.prefs.setBool('sunrise_notification', false);
      await SP.prefs.setBool('asr_notification', false);
      await SP.prefs.setBool('sunset_notification', false);
      await SP.prefs.setBool('isha_notification', false);
    }

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    appVersion = packageInfo.version;

    // WidgetsBinding.instance.addPostFrameCallback((_) => showAlertDialog());
    initializeData();
  }

  buildBody(BuildContext c, int i) {
    return InkWell(
      onTap: () {
        Widget page = getPage(zikr[i],
            loginCallback: loginCallback, scrollToPrayerTimes: false);
        if (page is Container) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Coming soon")));
        } else {
          pushPageRoute(context, page);
        }
      },
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
            Icon(zikrIcons[i], size: 48, color: Theme.of(context).primaryColor),
            SizedBox(height: 8),
            Text(
              zikr[i],
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
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused && favsData != null) {
      await SP.prefs.setString("new_favs", jsonEncode(favsData));
      if (newFavsReference != null)
        await newFavsReference?.set(jsonEncode(favsData));
      debugPrint("Favorites updated");
    }
  }

  Future<void> setUpFavorites() async {
    favsData = [];
    String? favsString = SP.prefs.getString("new_favs");
    debugPrint("Prefs favs are $favsString");
    if (favsString != null && favsString != "null") {
      List values = json.decode(favsString);
      values.forEach((element) {
        favsData!.add(
            UniversalData(element['uid'], element['title'], element['type']));
      });
    }

    if (user != null) {
      widget.analytics.setUserId(id: user!.uid);
      newFavsReference =
          FirebaseDatabase.instance.ref().child('new_favs').child(user!.uid);
      initialFavs = (await newFavsReference!.once()).snapshot.value as String?;
      debugPrint("Firebase favs are $initialFavs");
      if (initialFavs != null) {
        favsData = [];
        List values = json.decode(initialFavs!);
        for (var element in values) {
          favsData!.add(
              UniversalData(element['uid'], element['title'], element['type']));
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPopNext() {
    setState(() {});
  }
}
