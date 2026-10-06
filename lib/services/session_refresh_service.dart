import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants.dart';

class SessionRefreshService {
  const SessionRefreshService._();

  static Future<void> refreshSessionState() async {
    user = FirebaseAuth.instance.currentUser;
    // Settled once, at the end, rather than reset to false up front: the tab
    // shell listens to it, and a false between here and the claim read would
    // swap an admin's Quran tab to the surah list and back, losing its place.
    if (user == null) isUserAdmin = false;

    // Load the bundled zikr index first: it's a local asset read with no
    // network dependency. Running it before the admin-claim check below
    // means a slow/stalled connection never delays the index that deep
    // links, search, and Today's Recitation all depend on.
    await loadItemsFromAssets();

    if (user != null) {
      var admin = false;
      try {
        final idTokenResult =
            await user!.getIdTokenResult().timeout(const Duration(seconds: 4));
        final claims = idTokenResult.claims;
        if (claims != null && claims['admin'] == true) {
          admin = true;
        }
      } catch (error) {
        debugPrint(
            'Unable to refresh admin claim, using bundled index: $error');
      }
      isUserAdmin = admin;
      unawaited(_refreshAdminClaim(user!));
    }
  }

  /// Re-reads the admin claim from a freshly minted ID token.
  ///
  /// A cached token carries whatever claims were true when it was minted, up
  /// to an hour ago, so a claim granted or revoked since would otherwise not
  /// show up until the token happens to expire. Forcing a refresh is a
  /// network round-trip, though, so it runs behind the cached read above
  /// rather than holding up startup or a deep-link launch, and a failure -
  /// offline, say - leaves the cached answer standing.
  static Future<void> _refreshAdminClaim(User forUser) async {
    try {
      final idTokenResult = await forUser
          .getIdTokenResult(true)
          .timeout(const Duration(seconds: 10));
      if (!identical(user, forUser)) return;
      isUserAdmin = idTokenResult.claims?['admin'] == true;
    } catch (error) {
      debugPrint('Unable to force-refresh admin claim: $error');
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
