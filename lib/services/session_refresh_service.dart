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

    // Load the bundled zikr index first: it's a local asset read with no
    // network dependency. Running it before the admin-claim check below
    // means a slow/stalled connection never delays the index that deep
    // links, search, and Today's Recitation all depend on.
    await loadItemsFromAssets();

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
  }

  static Future<void> loadItemsFromAssets() async {
    zikrIndexReady.value = false;
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
    } finally {
      // Flip even on failure: a page waiting on this must stop spinning
      // (and fall back to whatever's currently in `items`, even if empty)
      // rather than hang indefinitely.
      zikrIndexReady.value = true;
    }
  }
}
