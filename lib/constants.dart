import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'data/uid_title_data.dart';
import 'pages/item_page.dart';
import 'pages/list_items.dart';

double screenWidth = 0;
double screenHeight = 0;

User user;

final String appName = "Shia Companion";
int hijriDate = 0;
double arabicFontSize = 28.0;
double englishFontSize = 14.0;

bool showTranslation = true, showTransliteration = true;

List<String> tableCode = [
  "FAV",
  "TR",
  "F",
  "E",
  "G",
  "A",
  /*"C", "A", */ "H", /* "I", "B" */
];

List<String> zikr = [
  "Favorites",
  "Today's Recitations",
  "Namaz",
  "Duas",
  "Ziyarats",
  // "Amaal",
  "Surahs",
  "Munajaats",
  // "Baaqeyaat As Saalehaat",
  // "Ziyarat of Hijaz, Iran & Iraq"
];

List<String> zikrImages = [
  "assets/images/najaf_min",
  "assets/images/taaqebaat_namaz",
  "assets/images/namaz_home_min",
  "assets/images/dua_home",
  "assets/images/najaf_min",
  // "assets/images/amaal",
  "assets/images/surah_home",
  "assets/images/munajat_home",
  // "assets/images/taaqebaat_namaz",
  // "assets/images/mashhad_min"
];

Map items = {};

// HomePage key
GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

ListTile buildZikrRow(BuildContext context, UidTitleData itemData) {
  return ListTile(
    onTap: () {
      if (itemData.getUId().contains("~")) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    ItemList(itemData.getUId().split("~")[1])));
      } else {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => ItemPage(itemData)));
      }
    },
    title: Text(itemData.title),
  );
}
