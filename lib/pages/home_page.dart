import 'dart:io';

import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:http/http.dart';
import 'package:shia_companion/data/live_streaming_data.dart';
import 'package:shia_companion/pages/settings_page.dart';
import 'package:shia_companion/widgets/live_streaming.dart';
import 'package:shia_companion/widgets/prayer_times.dart';
import 'list_items.dart';

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

  List<LiveStreamingData> holyShrine, liveChannel;

  List prayerTimes;

  ThemeData themeData = ThemeData(
    canvasColor: Colors.brown,
  );
  int _page = 0;
  PageController _pageController;

  @override
  void initState() {
    super.initState();
    getHadith();
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
            onTap: navigationTapped, //
            currentIndex: _page, //
            items: [
              BottomNavigationBarItem(
                icon: Icon(
                  Icons.home,
                  color: Colors.white,
                ),
                title: Text(
                  "Home",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              BottomNavigationBarItem(
                  icon: Icon(
                    Icons.settings,
                    color: Colors.white,
                  ),
                  title: Text(
                    "Preferences",
                    style: TextStyle(color: Colors.white),
                  ))
            ],
          ),
        ),
        body: PageView(
          children: <Widget>[
            LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minWidth: constraints.maxWidth, minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
                            fit: FlexFit.loose,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                                child: Text(
                                  '$hadith',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )),
                        PrayerTimes(),
                        SizedBox(
                          height: 120,
                          width: screenWidth,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 8.0),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: zikr.length,
                              itemBuilder: (BuildContext c, int i) => buildBody(c, i),
                            ),
                          ),
                        ),
                        holyShrine != null ? LiveStreaming(holyShrine) : Container(),
                        liveChannel != null ? LiveStreaming(liveChannel) : Container(),
                      ],
                    ),
                  ),
                ),
              );
            }),
            SettingsPage()
          ],
          controller: _pageController,
          onPageChanged: ((int page) {
            setState(() {
              this._page = page;
            });
          }),
        ));
  }

  void navigationTapped(int page) {
    _pageController.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.ease);
  }

  void initializeData() async {
    // Initialize Item Data
    String url = "https://alghazienterprises.com/sc/scripts/getItems.php";
    var request = await get(url);
    String loadString = request.body;
    items = json.decode(loadString);

    // Initialize Holy Shrines Data
    if (Platform.isAndroid) {
      url = "https://alghazienterprises.com/sc/scripts/getHolyShrines.php";
      var response = await get(url);
      if (response.statusCode == 200) {
        List x = json.decode(response.body);
        holyShrine = List();
        x.forEach((f) => holyShrine.add(LiveStreamingData.fromJson(f)));
      }
      url = "https://alghazienterprises.com/sc/scripts/getIslamicChannels.php";
      response = await get(url);
      if (response.statusCode == 200) {
        List x = json.decode(response.body);
        liveChannel = List();
        x.forEach((f) => liveChannel.add(LiveStreamingData.fromJson(f)));
      }
    }

    // Initialize Islamic Channels Data
    setState(() {});
  }

  getHadith() async {
    Random rnd;
    int min = 1;
    int max = 2382;
    rnd = Random();
    int h = min + rnd.nextInt(max - min);
    hadith = await DefaultAssetBundle.of(context).loadString('assets/hadiths/$h');
    setState(() {});
  }

  setupPreferences() async {
    // Get SharedPreferences
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    arabicFontSize = sharedPreferences.getDouble('ara_font_size') ?? arabicFontSize;
    englishFontSize = sharedPreferences.getDouble('eng_font_size') ?? englishFontSize;

    showTranslation = sharedPreferences.getBool('showTranslation') ?? showTranslation;
    showTransliteration = sharedPreferences.getBool('showTransliteration') ?? showTransliteration;

    hijriDate = sharedPreferences.getInt('adjust_hijri_date') ?? hijriDate;
    initializeData();
  }

  buildBody(BuildContext c, int i) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ItemList(tableCode[i])));
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
            gradient: LinearGradient(colors: <Color>[Colors.black, Colors.white70]),
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
}
