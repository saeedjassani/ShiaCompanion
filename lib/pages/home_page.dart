import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
import 'package:shia_companion/pages/settings_page.dart';
import 'package:shia_companion/utils/data_search.dart';
import 'package:shia_companion/utils/font_preferences.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'package:shia_companion/widgets/prayer_times_widget.dart';

import 'library_page.dart';
import 'list_items.dart';
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


  bool scrollToPrayerTimes = false;

  callback() {
    // Navigate to calendar and scroll to prayer times when invoked from the home card
    scrollToPrayerTimes = true;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CalendarPage(scrollToPrayerTimes)));
  }

  loginCallback() async {
    await setUpFavorites();
  }

  @override
  void initState() {
    super.initState();
    trackScreen('Home Page');
    WidgetsBinding.instance.addObserver(this);
    setupPreferences();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: <Widget>[
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

        body: PageView(
          children: <Widget>[
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 32.0, horizontal: 16.0),
                      child: InkWell(
                        onTap: () {
                          SharePlus.instance.share(
                              ShareParams(
                                text: '$hadith\n\nShared via Shia Companion - https://www.onelink.to/ShiaCompanion',
                                sharePositionOrigin: Rect.fromLTWH(
                                    MediaQuery.of(context).size.width / 2,
                                    0,
                                    2,
                                    2),
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
                  lat != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: HomePrayerTimesCard(callback),
                        )
                      : Container(),
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
                                  if (i < tableCode.length) {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => tableCode[i]));
                                  } else if (zikr[i] == 'Preferences') {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => SettingsPage(loginCallback)));
                                  } else {
                                    // No route defined for this tile
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text("Coming soon")));
                                  }
                                },
                                child: LayoutBuilder(builder: (context, tileConstraints) {
                                  final double tileWidth = tileConstraints.maxWidth;
                                  final double avatarRadius = (tileWidth * 0.18).clamp(18.0, 40.0);
                                  final double iconSize = avatarRadius * 0.9;
                                  final double fontSize = tileWidth > 140 ? 14 : 12;
                                  final double verticalPadding = tileWidth > 140 ? 12 : 8;

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
            ),
            CalendarPage(scrollToPrayerTimes),
            LibraryPage(),
            SettingsPage(loginCallback)
          ],

        ));
  }



  Future<void> _loadItemsFromFirebase() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('zikr').get();

      if (snapshot.docs.isNotEmpty) {
        final Map<String, Map<String, dynamic>> allDocs = {
          for (var doc in snapshot.docs) doc.id: doc.data()
        };

        final Map<String, String> fetchedItems = {};
        allDocs.forEach((key, value) {
          final hasData = value['data'] != null;
          final isCategory = key.contains('~');
          final isAlias = key.contains('|');

          if (!(hasData || isCategory || isAlias)) {
            return; // Skip items that do not meet the base criteria.
          }

          // This is the alias-specific exclusion from the Python script.
          if (isAlias) {
            final originalKey = key.split('|')[1];
            final originalDoc = allDocs[originalKey];
            if (originalDoc != null && originalDoc['data'] == null) {
              return; // continue to next item in forEach
            }
          }

          if (value['title'] == null) {
            return; // Skip items without a title.
          }

          // Add the item to the index. Use a default empty string if 'title' is null.
          fetchedItems[key] = value['title'];
        });
        items = fetchedItems;
      }
    } catch (e) {
      debugPrint("Error fetching items from Firestore: $e");
      String data =
          await DefaultAssetBundle.of(context).loadString("assets/items.json");
      items = json.decode(data);
    }
  }

  void initializeData() async {
    // Initialize Item Data
    await _loadItemsFromFirebase();
    getHadith();

    await setUpFavorites();

    // Initialize LocationData
    await initializeLocation();

    if (!kIsWeb) {
      tz.initializeTimeZones();
      final _timeZone = await FlutterTimezone.getLocalTimezone();
      final currentTimeZone = _timeZone.identifier;
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
        initializationSettings,
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
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => ItemList(tableCode[i])));
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

    user = _auth.currentUser;
    if (user != null) {
      final idTokenResult = await user?.getIdTokenResult(true);
      final claims = idTokenResult?.claims;
      if (claims != null && claims['admin'] == true) {
        isUserAdmin = true;
      }

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
