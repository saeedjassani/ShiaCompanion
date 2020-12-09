import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:location/location.dart';
import 'package:package_info/package_info.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:http/http.dart';
import 'package:shia_companion/data/live_streaming_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/calendar_page.dart';
import 'package:shia_companion/pages/live_streaming_page.dart';
import 'package:shia_companion/pages/settings_page.dart';
import 'package:shia_companion/widgets/bottom_bar.dart';
import 'package:shia_companion/widgets/prayer_times_widget.dart';
import 'library_page.dart';
import 'list_items.dart';
import 'news_page.dart';

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String hadith = '';
  LocationData currentLocation;
  DateTime today = DateTime.now();

  Location location = Location();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DatabaseReference favsReference;

  List<LiveStreamingData> holyShrine, liveChannel;

  List prayerTimes;

  ThemeData themeData = ThemeData(
    canvasColor: Colors.brown,
  );
  int _page = 0;
  PageController _pageController;
  bool scrollToPrayerTimes = false;

  callback() {
    _page = 1;
    scrollToPrayerTimes = true;
    _pageController.animateToPage(_page,
        duration: const Duration(milliseconds: 300), curve: Curves.ease);
  }

  @override
  void initState() {
    super.initState();
    setupPreferences();
    _pageController = PageController(initialPage: 0);
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
        key: key,
        appBar: AppBar(
          title: Text(widget.title),
        ),
        bottomNavigationBar: Theme(
          data: themeData,
          child: BottomNavigationBar(
            showUnselectedLabels: false,
            selectedItemColor: Colors.white,
            onTap: navigationTapped, //
            currentIndex: _page, //
            items: bottomBarItems,
          ),
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
                        onExpansionChanged: (bool x) {
                          if (user == null && x)
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content:
                                  Text("Please sign in to access favorites"),
                            ));
                        },
                        title: Text("Favorites", key: ValueKey('hadith-text')),
                        children: <Widget>[
                          favsData != null
                              ? SizedBox(
                                  height: 300,
                                  child: ListView.separated(
                                      separatorBuilder:
                                          (BuildContext context, int index) =>
                                              Divider(),
                                      itemCount: favsData != null
                                          ? favsData.length
                                          : 0,
                                      itemBuilder: (BuildContext c, int i) {
                                        UniversalData itemData = favsData[i];
                                        return ListTile(
                                            onTap: () =>
                                                handleUniversalDataClick(
                                                    context, itemData),
                                            title: Text(itemData.title),
                                            trailing: InkWell(
                                                onTap: () {
                                                  favsData.contains(itemData)
                                                      ? favsData
                                                          .remove(itemData)
                                                      : favsData.add(itemData);
                                                  setState(() {});
                                                },
                                                child: favsData
                                                        .contains(itemData)
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
                                      }))
                              : Container()
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 120,
                    width: screenWidth,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 8.0),
                      child: Card(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: zikr.length,
                          itemBuilder: (BuildContext c, int i) =>
                              buildBody(c, i),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(), // new
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2),
                      itemCount: tableCode.length,
                      itemBuilder: (BuildContext c, int i) {
                        return Card(
                          color: Colors.brown[50],
                          child: InkWell(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => tableCode[i])),
                              child: Center(
                                child: Text(
                                  zikr[i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              )),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            CalendarPage(scrollToPrayerTimes),
            LibraryPage(),
            SettingsPage()
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
    _pageController.animateToPage(page,
        duration: const Duration(milliseconds: 300), curve: Curves.ease);
  }

  void initializeData() async {
    // Initialize LocationData
    await initializeLocation();

    if (!kIsWeb) {
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      var initializationSettingsAndroid =
          AndroidInitializationSettings('ic_launcher');
      var initializationSettingsIOS = IOSInitializationSettings();
      var initializationSettings = InitializationSettings(
          initializationSettingsAndroid, initializationSettingsIOS);
      await flutterLocalNotificationsPlugin.initialize(initializationSettings,
          onSelectNotification: selectNotification);

      final List<PendingNotificationRequest> pendingNotificationRequests =
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();

      bool needToSchedule = true;
      pendingNotificationRequests.forEach((PendingNotificationRequest element) {
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
      }
    }

    // Initialize Item Data
    if (kReleaseMode) {
      String data =
          await DefaultAssetBundle.of(context).loadString("assets/zikr.json");
      items = json.decode(data);
    } else {
      var request =
          await get("https://alghazienterprises.com/sc/scripts/getItems.php");
      String loadString = request.body;
      items = json.decode(loadString);
    }

    user = _auth.currentUser;
    // If user is logged in, initialize favorites
    if (user != null) {
      favsData = [];

      DatabaseReference newFavsReference = FirebaseDatabase.instance
          .reference()
          .child('new_favs')
          .child(user.uid);
      List values = json.decode((await newFavsReference.once()).value);

      for (var obj in values) {
        // Fix startsWithKey - Example: G17 should show when G17|L4 is present
        // The above issue cannot be fixed. Instead, always the primary UID should be saved (L4 in the case above)
        // TODO If type == 0 and items doen't contain UID remove it.
        if (items.containsKey(obj["uid"]) && obj['type'] == 0) {
          // Add Type 0 (Zikr) data only when it exists
          favsData.add(UniversalData(obj["uid"], obj["title"], obj['type']));
        } else {
          // Library Data is already imported
          favsData.add(UniversalData(obj["uid"], obj["title"], obj['type']));
        }
      }
    }

    getHadith();
  }

  Future selectNotification(String payload) async {
    if (payload != null) {
      debugPrint('notification payload: ' + payload);
    }
    // TODO play with notification payload here
  }

  // 0 - 2340 General
  // 2341 - 2375 Muharram
  getHadith() async {
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

    showTranslation =
        sharedPreferences.getBool('showTranslation') ?? showTranslation;
    showTransliteration =
        sharedPreferences.getBool('showTransliteration') ?? showTransliteration;

    hijriDate = sharedPreferences.getInt('adjust_hijri_date') ?? hijriDate;

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
  void dispose() {
    print("dispose was called");
    super.dispose();
  }
}
