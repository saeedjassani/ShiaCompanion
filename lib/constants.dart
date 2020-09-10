import 'package:flutter/material.dart';

double screenWidth = 0;
double screenHeight = 0;

final String appName = "Shia Companion";
int hijriDate = 0;
double arabicFontSize = 28.0;
double englishFontSize = 14.0;

bool showTranslation = true, showTransliteration = true;

List<String> tableCode = [
  "TR",
  "F",
  "E",
  "G",
  "A",
  /*"C", "A", */ "H", /* "I", "B" */
];

List<String> zikr = [
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
