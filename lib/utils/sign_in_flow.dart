import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../l10n/l10n.dart';
import '../services/account_service.dart';
import '../services/analytics_service.dart';
import '../widgets/app_toast.dart';

enum SignInProvider { google, apple }

/// Sign in with Apple is offered wherever Google is - iOS, Android and the
/// web - so an account made with Apple on an iPhone can be reached from any
/// device, not just iOS.
bool get appleSignInOffered =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android;

/// Signs in with [provider] from a button tap, for Settings and first-run
/// setup alike: counts it, says so in a snackbar, and turns every failure
/// into a snackbar too. A cancel says nothing. Returns the signed-in user,
/// or null when nobody was signed in.
///
/// Reloading the synced data afterwards is the caller's: Settings does it
/// straight away, setup leaves it to Home's start-up, which runs next.
Future<User?> signInFromButton(
  BuildContext context,
  SignInProvider provider,
) async {
  final current = FirebaseAuth.instance.currentUser;
  if (current != null) return current;

  try {
    final result = switch (provider) {
      SignInProvider.google => await AccountService.signInWithGoogle(),
      SignInProvider.apple => await AccountService.signInWithApple(),
    };
    unawaited(AnalyticsService.feature(
      'account_signed_in',
      label: 'Signed in',
      parameters: {'method': provider.name},
    ));
    if (context.mounted) {
      showToast(context.l10n.settingsLoginSuccessful);
    }
    return result.user;
  } on GoogleSignInException catch (error) {
    if (error.code == GoogleSignInExceptionCode.canceled) {
      debugPrint('User cancelled google sign-in');
      return null;
    }
    debugPrint('Google sign-in failed: $error');
    if (!context.mounted) return null;
    _showFailure(
        context,
        provider,
        error.code == GoogleSignInExceptionCode.uiUnavailable
            ? context.l10n.settingsGoogleUnavailable
            : null);
  } on SignInWithAppleAuthorizationException catch (error) {
    if (error.code == AuthorizationErrorCode.canceled) {
      debugPrint('User cancelled apple sign-in');
      return null;
    }
    debugPrint('Apple sign-in failed: ${error.message}');
    if (context.mounted) _showFailure(context, provider, null);
  } on FirebaseAuthException catch (error) {
    // Web popup or Android browser tab closed by the user - also a cancel,
    // not a failure.
    if (error.code == 'popup-closed-by-user' ||
        error.code == 'cancelled-popup-request' ||
        error.code == 'web-context-canceled') {
      return null;
    }
    debugPrint('Sign-in failed: ${error.code} ${error.message}');
    if (!context.mounted) return null;
    _showFailure(
        context,
        provider,
        switch (error.code) {
          'network-request-failed' => context.l10n.commonNetworkError,
          // The email is already on an account made with the other provider.
          'account-exists-with-different-credential' =>
            context.l10n.settingsAccountExistsOtherProvider,
          _ => null,
        });
  } catch (error) {
    debugPrint('Sign-in failed: $error');
    if (context.mounted) _showFailure(context, provider, null);
  }
  return null;
}

void _showFailure(
  BuildContext context,
  SignInProvider provider,
  String? message,
) {
  final l10n = context.l10n;
  showToast(message ??
      switch (provider) {
        SignInProvider.google => l10n.settingsGoogleFailed,
        SignInProvider.apple => l10n.settingsAppleFailed,
      });
}
