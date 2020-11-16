import 'package:flutter/material.dart';

List<BottomNavigationBarItem> bottomBarItems = [
  BottomNavigationBarItem(
    icon: Icon(
      Icons.home,
      color: Colors.white,
    ),
    label: "Home",
  ),
  BottomNavigationBarItem(
    icon: Icon(
      Icons.calendar_today,
      color: Colors.white,
      key: ValueKey('calendar-icon'),
    ),
    label: "Calendar",
  ),
  BottomNavigationBarItem(
    icon: Icon(
      Icons.library_books,
      color: Colors.white,
      key: ValueKey('library-icon'),
    ),
    label: "Library",
  ),
  BottomNavigationBarItem(
    icon: Icon(
      Icons.settings,
      color: Colors.white,
      key: ValueKey('prefs-icon'),
    ),
    label: "Preferences",
  )
];
