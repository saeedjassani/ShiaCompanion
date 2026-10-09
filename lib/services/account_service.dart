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

  /// Signs in with Apple: the native sheet on iOS, Firebase's own web flow
  /// (a popup on the web, a browser tab on Android) everywhere else, so an
  /// account made on an iPhone can be reached from any device.
  static Future<UserCredential> signInWithApple() async {
    if (kIsWeb) return _auth.signInWithPopup(AppleAuthProvider());
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return _auth.signInWithProvider(AppleAuthProvider());
    }

    final (credential, _) = await _nativeAppleCredential();
    return _auth.signInWithCredential(credential);
  }

  /// Asks Apple's native sheet (iOS) for a Firebase credential, plus the
  /// one-off authorization code Apple wants back to revoke its tokens.
  static Future<(OAuthCredential, String)> _nativeAppleCredential() async {
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
    return (credential, appleCredential.authorizationCode);
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
      final (deletionUser, appleAuthorizationCode) =
          await _ensureRecentLoginForDataDeletion(currentUser);
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
      if (appleAuthorizationCode != null) {
        await _revokeAppleTokens(appleAuthorizationCode);
      }
      await _deleteUserWithFallbackReauth(deletionUser);
    } on AccountActionException {
      rethrow;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw AccountActionException(L10n.current.accountPopupClosed);
      }
      throw AccountActionException(L10n.current.settingsAppleFailed);
    } on FirebaseAuthException catch (error) {
      throw AccountActionException(_messageForAuthError(error));
    } catch (error) {
      throw AccountActionException('Error deleting account: $error');
    }
  }

  /// Makes sure [user] signed in recently enough to be deleted, asking them
  /// to sign in again where that can be done in place. Also returns, for an
  /// Apple account on iOS, the authorization code to revoke its Apple tokens
  /// with - Apple requires that on deletion, and only iOS can do it.
  static Future<(User, String?)> _ensureRecentLoginForDataDeletion(
    User user,
  ) async {
    if (_hasProvider(user, 'apple.com')) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // Always ask: the authorization code is single-use and short-lived,
        // so a fresh one is needed even right after signing in.
        final (credential, code) = await _nativeAppleCredential();
        final result = await user.reauthenticateWithCredential(credential);
        return (result.user ?? user, code);
      }
      if (_hasRecentSignIn(user)) return (user, null);
      if (kIsWeb) {
        await user.reauthenticateWithPopup(AppleAuthProvider());
      } else {
        await user.reauthenticateWithProvider(AppleAuthProvider());
      }
      return (_refreshedUser(user), null);
    }

    if (_hasRecentSignIn(user)) return (user, null);

    if (kIsWeb && _hasProvider(user, 'google.com')) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
      return (_refreshedUser(user), null);
    }

    throw AccountActionException(L10n.current.accountReauthenticate);
  }

  static User _refreshedUser(User user) {
    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null || refreshedUser.uid != user.uid) {
      throw AccountActionException(L10n.current.accountSessionExpired);
    }
    return refreshedUser;
  }

  /// Revokes the app's Apple tokens. A failure is logged, not thrown: the
  /// account and its data still go, which matters more to the user.
  static Future<void> _revokeAppleTokens(String authorizationCode) async {
    try {
      await _auth.revokeTokenWithAuthorizationCode(authorizationCode);
    } catch (error) {
      debugPrint('Apple token revocation failed: $error');
    }
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
          _hasProvider(user, 'google.com')) {
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

  static bool _hasProvider(User user, String providerId) {
    return user.providerData
        .any((provider) => provider.providerId == providerId);
  }

  static String _messageForAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'requires-recent-login':
        return L10n.current.accountReauthenticate;
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'web-context-canceled':
        return L10n.current.accountPopupClosed;
      case 'user-mismatch':
        return L10n.current.accountUserMismatch;
      case 'network-request-failed':
        return L10n.current.accountNetworkError;
      default:
        return error.message ?? L10n.current.commonSomethingWentWrong;
    }
  }
}
