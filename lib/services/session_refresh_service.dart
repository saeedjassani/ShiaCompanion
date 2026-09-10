import 'dart:convert';

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

    await loadItemsFromAssets();
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
}
