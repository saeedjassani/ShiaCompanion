import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

TextStyle whiteColor = new TextStyle(color: Colors.white);
TextStyle whiteColor70 = new TextStyle(color: Colors.white70);
TextStyle arabicStyle = new TextStyle(fontFamily: "Qalam", fontSize: 18.0);
TextStyle smallText = new TextStyle(fontSize: 12.0);
int day = 1;
const String base = "https://mahditours.com/noor_diary/scripts/";
User? user;
int hijriDate = 0;

typedef RefreshArticles = void Function();
typedef RefreshNotes = void Function();

String replaceFarsiNumber(String input) {
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const farsi = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  for (int i = 0; i < english.length; i++) {
    input = input.replaceAll(english[i], farsi[i]);
  }

  return input;
}
