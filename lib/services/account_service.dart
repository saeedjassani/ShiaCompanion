import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../firebase_auth_config.dart';
import '../firebase_options.dart';
import 'activity_stats_store.dart';
import 'favorites_manager.dart';
import 'prayer_preferences_sync_service.dart';
import 'preferences_sync_service.dart';
import 'qaza_tracker_manager.dart';
import 'recitation_tracker_manager.dart';
import 'saved_verses_manager.dart';
import 'zikr_bookmarks_manager.dart';
import '../l10n/l10n.dart';

class AccountActionException implements Exception {
  final String message;

  const AccountActionException(this.message);

  @override
  String toString() => message;
}

class AccountService {
  AccountService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static Future<void>? _googleSignInInitialization;
  static const Duration _recentLoginWindow = Duration(minutes: 5);

  static Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      return FirebaseAuth.instance.signInWithPopup(googleProvider);
    }

    await _ensureGoogleSignInInitialized();

    final signIn = GoogleSignIn.instance;
    final googleUser = await _authenticateWithGoogle(signIn);

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  static Future<UserCredential> signInWithApple() async {
    final rawNonce = generateNonce();
    final nonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [],
      nonce: nonce,
    );
    final identityToken = appleCredential.identityToken;
    if (identityToken == null) {
      throw FirebaseAuthException(
        code: 'missing-apple-id-token',
        message: 'Apple did not return an identity token.',
      );
    }

    final credential = OAuthProvider('apple.com').credential(
      idToken: identityToken,
      rawNonce: rawNonce,
    );
    return _auth.signInWithCredential(credential);
  }

  static Future<GoogleSignInAccount> _authenticateWithGoogle(
    GoogleSignIn signIn,
  ) async {
    if (!signIn.supportsAuthenticate()) {
      final lightweightUser = await signIn.attemptLightweightAuthentication();
      if (lightweightUser != null) return lightweightUser;
    }

    try {
      return await signIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (defaultTargetPlatform != TargetPlatform.android ||
          error.code != GoogleSignInExceptionCode.interrupted) {
        rethrow;
      }

      final lightweightUser = await signIn.attemptLightweightAuthentication();
      if (lightweightUser != null) return lightweightUser;
      rethrow;
    }
  }

  static Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInitialization ??= GoogleSignIn.instance.initialize(
      clientId: switch (defaultTargetPlatform) {
        TargetPlatform.iOS => DefaultFirebaseOptions.ios.iosClientId,
        _ => null,
      },
      serverClientId: switch (defaultTargetPlatform) {
        TargetPlatform.android => FirebaseAuthConfig.googleServerClientId,
        _ => null,
      },
    );
  }

  static Future<void> signOut() {
    return _auth.signOut();
  }

  static Future<void> deleteCurrentAccountAndData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw const AccountActionException('User is not signed in.');
    }

    try {
      final deletionUser = await _ensureRecentLoginForDataDeletion(currentUser);
      await FavoritesManager.instance.deleteAllFavorites(deletionUser.uid);
      await QazaTrackerManager.instance.deleteAllQazaData(deletionUser.uid);
      await RecitationTrackerManager.instance
          .deleteAllRecitationData(deletionUser.uid);
      await SavedVersesManager.instance.deleteAllSavedVerses(deletionUser.uid);
      await ZikrBookmarksManager.instance.deleteAllBookmarks(deletionUser.uid);
      await PreferencesSyncService.instance
          .deleteSyncedPreferences(deletionUser.uid);
      await PrayerPreferencesSyncService.instance
          .deleteSyncedPreferences(deletionUser.uid);
      await ActivityStatsStore.instance.deleteSyncedStats(deletionUser.uid);
      await _deleteUserWithFallbackReauth(deletionUser);
    } on AccountActionException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AccountActionException(_messageForAuthError(error));
    } catch (error) {
      throw AccountActionException('Error deleting account: $error');
    }
  }

  static Future<User> _ensureRecentLoginForDataDeletion(User user) async {
    if (_hasRecentSignIn(user)) return user;

    if (kIsWeb && _supportsGooglePopupReauth(user)) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null || refreshedUser.uid != user.uid) {
        throw AccountActionException(L10n.current.accountSessionExpired);
      }
      return refreshedUser;
    }

    throw AccountActionException(L10n.current.accountReauthenticate);
  }

  static bool _hasRecentSignIn(User user) {
    final lastSignIn = user.metadata.lastSignInTime;
    if (lastSignIn == null) return false;

    return DateTime.now().difference(lastSignIn).abs() <= _recentLoginWindow;
  }

  static Future<void> _deleteUserWithFallbackReauth(User user) async {
    try {
      await user.delete();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login' &&
          kIsWeb &&
          _supportsGooglePopupReauth(user)) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
        final refreshedUser = _auth.currentUser;
        if (refreshedUser == null) {
          throw AccountActionException(L10n.current.accountSessionExpired);
        }
        await refreshedUser.delete();
        return;
      }
      throw AccountActionException(_messageForAuthError(error));
    }
  }

  static bool _supportsGooglePopupReauth(User user) {
    return user.providerData
        .any((provider) => provider.providerId == 'google.com');
  }

  static String _messageForAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'requires-recent-login':
        return L10n.current.accountReauthenticate;
      case 'popup-closed-by-user':
        return L10n.current.accountPopupClosed;
      case 'network-request-failed':
        return L10n.current.accountNetworkError;
      default:
        return error.message ?? L10n.current.commonSomethingWentWrong;
    }
  }
}
