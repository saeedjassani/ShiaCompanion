import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants.dart';

class SessionRefreshService {
  const SessionRefreshService._();

  static Future<void> refreshSessionState() async {
    user = FirebaseAuth.instance.currentUser;
    isUserAdmin = false;

    if (user != null) {
      try {
        final idTokenResult =
            await user!.getIdTokenResult().timeout(const Duration(seconds: 4));
        final claims = idTokenResult.claims;
        if (claims != null && claims['admin'] == true) {
          isUserAdmin = true;
        }
      } catch (error) {
        debugPrint(
            'Unable to refresh admin claim, using bundled index: $error');
      }
    }

    if (isUserAdmin) {
      await loadItemsFromFirebase();
    } else {
      await loadItemsFromAssets();
    }

    if (items.isEmpty) {
      await loadItemsFromAssets();
    }
  }

  static Future<void> loadItemsFromAssets() async {
    try {
      String data = await rootBundle.loadString("assets/zikr.json");
      final decoded = json.decode(data);
      items = {};
      itemOrder = {};
      itemMetadata = {};
      clearLocalSlugMaps();
      decoded.forEach((key, value) {
        if (value is Map) {
          final title = value['title']?.toString() ?? '';
          if (title.isEmpty) return;
          items[key] = title;
          final order = value['order'];
          if (order is num) itemOrder[key] = order.toDouble();
          final day = value['day'];
          if (day != null) {
            itemMetadata[key] = {'day': day};
          }
          setLocalSlugData(
            key.toString(),
            slug: value['slug']?.toString(),
            aliases:
                value['slugAliases'] is Iterable ? value['slugAliases'] : null,
          );
        } else {
          final title = value?.toString() ?? '';
          if (title.isEmpty) return;
          items[key] = title;
        }
      });
    } catch (e) {
      debugPrint("Error loading zikr index from assets: $e");
    }
  }

  static Future<void> loadItemsFromFirebase() async {
    try {
      final doc = await FirebaseFirestore.instance
          .doc('zikr_meta/index')
          .get(const GetOptions(source: Source.server));
      if (doc.exists && doc['items'] != null) {
        final rawItems = doc['items'];
        items = {};
        itemOrder = {};
        itemMetadata = {};
        clearLocalSlugMaps();
        final visibleUids = <String>{};

        rawItems.forEach((key, value) {
          final title = value is Map ? value['title'] : value;
          final hasData = value is Map ? value['hasData'] ?? false : true;
          final order = value is Map ? value['order'] : null;
          final slug = value is Map ? value['slug'] : null;
          final slugAliases = value is Map ? value['slugAliases'] : null;
          final day = value is Map ? value['day'] : null;

          if (isUserAdmin || hasData) {
            items[key] = title;
            visibleUids.add(key.toString());
            if (order is num) itemOrder[key] = order.toDouble();
            if (day != null) {
              itemMetadata[key] = {'day': day};
            }
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
      } else {
        items = {};
        itemOrder = {};
        clearLocalSlugMaps();
      }
    } catch (e) {
      debugPrint("Error loading zikr index: $e");
    }
  }
}
