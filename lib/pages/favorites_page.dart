import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

class FavoritesPage extends StatefulWidget {
  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<UniversalData>? _favs;
  DatabaseReference? _favRef;

  @override
  void initState() {
    super.initState();
    _loadFavs();
  }

  Future<void> _loadFavs() async {
    List<UniversalData> localFavs = [];
    String? favsString = SP.prefs.getString("new_favs");
    if (favsString != null && favsString != "null") {
      List values = json.decode(favsString);
      values.forEach((element) {
        localFavs.add(UniversalData(element['uid'], element['title'], element['type']));
      });
    }

    // If user is signed in, prefer remote favorites
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        _favRef = FirebaseDatabase.instance.ref().child('new_favs').child(user.uid);
        final snapshot = await _favRef!.once();
        String? remote = snapshot.snapshot.value as String?;
        if (remote != null) {
          localFavs = [];
          List values = json.decode(remote);
          values.forEach((element) {
            localFavs.add(UniversalData(element['uid'], element['title'], element['type']));
          });
        }
      } catch (e) {
        debugPrint('Failed to fetch remote favorites: $e');
      }
    }

    setState(() {
      _favs = localFavs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Favorites')),
      body: _favs == null || _favs!.isEmpty
          ? Center(child: Text('No favorites yet.'))
          : ListView.separated(
              itemCount: _favs!.length,
              separatorBuilder: (_, __) => Divider(),
              itemBuilder: (context, index) {
                UniversalData item = _favs![index];
                return ListTile(
                  title: isUserAdmin ? Text(item.uid + ' ' + item.title) : Text(item.title),
                  onTap: () => handleUniversalDataClick(context, item),
                  onLongPress: () {
                    if (isUserAdmin) handleUniversalDataClick(context, item, itemPage: true);
                  },
                );
              },
            ),
    );
  }
}
