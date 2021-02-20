import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:location/location.dart';
import 'package:package_info/package_info.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/live_streaming_data.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/calendar_page.dart';
import 'package:shia_companion/pages/settings_page.dart';
import 'package:shia_companion/utils/data_search.dart';
import 'package:shia_companion/widgets/bottom_bar.dart';
import 'package:shia_companion/widgets/prayer_times_widget.dart';
import 'package:shia_companion/widgets/todays_recitation.dart';
import 'library_page.dart';
import 'list_items.dart';

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with WidgetsBindingObserver, RouteAware {
  String hadith = '';
  LocationData currentLocation;
  DateTime today = DateTime.now();

  Location location = Location();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DatabaseReference favsReference;

  List<LiveStreamingData> holyShrine, liveChannel;
  String initialFavs;
  DatabaseReference newFavsReference;

  List prayerTimes;

  int _page = 0;
  PageController _pageController;
  bool scrollToPrayerTimes = false;

  callback() {
    _page = 1;
    scrollToPrayerTimes = true;
    _pageController.jumpToPage(_page);
  }

  loginCallback() async {
    await setUpFavorites();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setupPreferences();
    _pageController = PageController(initialPage: 0);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
        key: key,
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
        bottomNavigationBar: BottomNavigationBar(
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white,
          onTap: navigationTapped, //
          currentIndex: _page, //
          items: bottomBarItems,
          backgroundColor: Colors.brown,
          type: BottomNavigationBarType.fixed,
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
                      child: SingleChildScrollView(
                        child: Text(
                          '$hadith',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: HomePrayerTimesCard(callback),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      child: ExpansionTile(
                        onExpansionChanged: (bool value) {
                          if (value &&
                              (favsData == null || favsData.length == 0)) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text("Please add some favorites first"),
                            ));
                          }
                        },
                        title: Text("Favorites", key: ValueKey('hadith-text')),
                        children: <Widget>[
                          favsData != null
                              ? ListView.separated(
                                  physics: NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  separatorBuilder:
                                      (BuildContext context, int index) =>
                                          Divider(),
                                  itemCount: favsData.length,
                                  itemBuilder: (BuildContext c, int i) {
                                    UniversalData itemData = favsData[i];
                                    return ListTile(
                                        onTap: () => handleUniversalDataClick(
                                            context, itemData),
                                        title: Text(itemData.title),
                                        trailing: InkWell(
                                            onTap: () {
                                              favsData.contains(itemData)
                                                  ? favsData.remove(itemData)
                                                  : favsData.add(itemData);
                                              setState(() {});
                                            },
                                            child: favsData.contains(itemData)
                                                ? Icon(
                                                    Icons.star,
                                                    color: Theme.of(context)
                                                        .primaryColor,
                                                  )
                                                : Icon(
                                                    Icons.star_border,
                                                    color: Theme.of(context)
                                                        .primaryColor,
                                                  )));
                                  })
                              : Container()
                        ],
                      ),
                    ),
                  ),
                  TodaysRecitation(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(), // new
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2),
                      itemCount: tableCode.length,
                      itemBuilder: (BuildContext c, int i) {
                        return Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Card(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => tableCode[i]));
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Image.asset(
                                    zikrImages[i],
                                    fit: BoxFit.fill,
                                    height: 120,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 2.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            zikr[i],
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            CalendarPage(scrollToPrayerTimes),
            LibraryPage(),
            SettingsPage(loginCallback)
          ],
          controller: _pageController,
          onPageChanged: ((int page) {
            setState(() {
              _page = page;
            });
          }),
        ));
  }

  void navigationTapped(int page) {
    scrollToPrayerTimes = false;
    _pageController.jumpToPage(page);
  }

  void initializeData() async {
    // Initialize Item Data
    String data =
        await DefaultAssetBundle.of(context).loadString("assets/items.json");
    items = json.decode(data);
    getHadith();

    await setUpFavorites();

    // Initialize LocationData
    await initializeLocation();

    if (!kIsWeb) {
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('ic_notification');
      IOSInitializationSettings initializationSettingsIOS =
          IOSInitializationSettings();
      InitializationSettings initializationSettings = InitializationSettings(
          initializationSettingsAndroid, initializationSettingsIOS);
      await flutterLocalNotificationsPlugin.initialize(initializationSettings,
          onSelectNotification: selectNotification);

      await flutterLocalNotificationsPlugin.cancelAll();
      final List<PendingNotificationRequest> pendingNotificationRequests =
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      pendingNotificationRequests.forEach((PendingNotificationRequest element) {
        debugPrint("${element.id} ${element.title} is scheduled");
        if (element.id == 786 &&
            element.payload.isNotEmpty &&
            DateTime.now()
                    .difference(DateTime.fromMillisecondsSinceEpoch(
                        int.parse(element.payload)))
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

  Future selectNotification(String payload) async {
    if (payload != null) {
      debugPrint('notification payload: ' + payload);
    }
    // TODO play with notification payload here
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
    sharedPreferences = await SharedPreferences.getInstance();
    arabicFontSize =
        sharedPreferences.getDouble('ara_font_size') ?? arabicFontSize;
    englishFontSize =
        sharedPreferences.getDouble('eng_font_size') ?? englishFontSize;
    screenOn = sharedPreferences.getBool('keep_awake') ?? true;

    showTranslation =
        sharedPreferences.getBool('showTranslation') ?? showTranslation;
    showTransliteration =
        sharedPreferences.getBool('showTransliteration') ?? showTransliteration;

    hijriDate = sharedPreferences.getInt('adjust_hijri_date') ?? hijriDate;

    city = sharedPreferences.getString("city");
    lat = sharedPreferences.getDouble("lat");
    long = sharedPreferences.getDouble("long");

    // By default turn on Azan for Fajr, Dhuhr and Maghrib
    if (sharedPreferences.getBool('fajr_notification') == null) {
      sharedPreferences.setBool('fajr_notification', true);
      sharedPreferences.setBool('dhuhr_notification', true);
      sharedPreferences.setBool('maghrib_notification', true);
      sharedPreferences.setBool('sunrise_notification', false);
      sharedPreferences.setBool('asr_notification', false);
      sharedPreferences.setBool('sunset_notification', false);
      sharedPreferences.setBool('isha_notification', false);
    }

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
        alignment: Alignment.bottomLeft,
        decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(zikrImages[i] + ".jpg"),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(2.0)),
        child: Container(
          width: screenWidth,
          decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: <Color>[Colors.black, Colors.white70]),
          ),
          child: Text(
            zikr[i],
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Shader l = LinearGradient(colors: <Color>[Colors.black, Colors.white])
      .createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0));

  showAlertDialog() async {
    // set up the button
    Widget okButton = FlatButton(
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
    int bnFromPref = sharedPreferences.getInt('buildNumber') ?? 0;
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    // Show What's New Dialog only when build number is greater or in release mode
    if (int.parse(packageInfo.buildNumber) > bnFromPref && kReleaseMode) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return alert;
        },
      );
      await sharedPreferences.setInt(
          'buildNumber', int.parse(packageInfo.buildNumber));
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
      await sharedPreferences.setString("new_favs", jsonEncode(favsData));
      if (newFavsReference != null)
        await newFavsReference.set(jsonEncode(favsData));
      debugPrint("Favorites updated");
    }
  }

  Future<void> setUpFavorites() async {
    favsData = [];
    String favsString = sharedPreferences.getString("new_favs");
    debugPrint("Prefs favs are $favsString");
    if (favsString != null && favsString != "null") {
      List values = json.decode(favsString);
      values.forEach((element) {
        favsData.add(
            UniversalData(element['uid'], element['title'], element['type']));
      });
    }

    user = _auth.currentUser;
    if (user != null) {
      newFavsReference = FirebaseDatabase.instance
          .reference()
          .child('new_favs')
          .child(user.uid);
      initialFavs = (await newFavsReference.once()).value;
      debugPrint("Firebase favs are $initialFavs");
      if (initialFavs != null) {
        favsData = [];
        List values = json.decode(initialFavs);
        for (var element in values) {
          favsData.add(
              UniversalData(element['uid'], element['title'], element['type']));
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context));
  }

  @override
  void didPopNext() {
    setState(() {});
  }
}
