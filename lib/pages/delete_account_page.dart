import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/account_service.dart';
import '../services/analytics_service.dart';
import '../utils/sign_in_flow.dart' show SignInProvider;
import '../navigation/app_shell.dart';
import '../theme/shia_colors.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import '../widgets/responsive_content.dart' show compactContentWidth;
import '../l10n/l10n.dart';
import '../widgets/app_toast.dart';

/// Asks before an account is deleted; true to go ahead. Shared by the
/// Account page and [DeleteAccountPage], so both ask the same way.
Future<bool> confirmAccountDeletion(BuildContext context) async {
  final l10n = context.l10n;
  final confirmed = await showRevampDialog<bool>(
    context,
    title: l10n.deleteAccountConfirmTitle,
    body: l10n.deleteAccountConfirmBody,
    answers: [
      DialogAnswer(true, l10n.commonDelete, danger: true),
      DialogAnswer(false, l10n.commonCancel),
    ],
  );
  return confirmed == true;
}

/// Deletes the signed-in account and everything synced to it. Null once it
/// is gone; otherwise what went wrong, to show the user.
Future<String?> deleteSignedInAccount() async {
  try {
    await AccountService.deleteCurrentAccountAndData();
    user = null;
    unawaited(AnalyticsService.feature(
      'account_deleted',
      label: 'Account deleted',
    ));
    return null;
  } on AccountActionException catch (error) {
    return error.message;
  } catch (error) {
    return L10n.current.deleteAccountFailed('$error');
  }
}

/// The public account-deletion page - Google Play requires one at
/// `/delete-account` - which signs in on the web if need be. In the app,
/// deleting starts from the Account page.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _isBusy = false;
  bool _isDeleted = false;
  SignInProvider? _signingIn;

  @override
  void initState() {
    super.initState();
    trackScreen('Delete Account Page');
  }

  Future<void> _signIn(SignInProvider provider) async {
    setState(() {
      _isBusy = true;
      _signingIn = provider;
    });

    try {
      final authResult = switch (provider) {
        SignInProvider.google => await AccountService.signInWithGoogle(),
        SignInProvider.apple => await AccountService.signInWithApple(),
      };
      user = authResult.user;
      if (!mounted) return;
      setState(() {});
      showToast(context.l10n.deleteAccountSignedIn);
    } on AccountActionException catch (error) {
      _showToast(error.message);
    } catch (error) {
      _showToast(context.l10n.deleteAccountSignInFailed('$error'));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _signingIn = null;
        });
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isBusy = true;
    });

    try {
      await AccountService.signOut();
      user = null;
      if (!mounted) return;
      setState(() {});
      _showToast(context.l10n.deleteAccountSignedOut);
    } catch (error) {
      _showToast(context.l10n.deleteAccountSignOutFailed('$error'));
    } finally {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
      });
    }
  }

  Future<void> _confirmDeletion() async {
    if (await confirmAccountDeletion(context)) await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _isBusy = true;
    });

    final error = await deleteSignedInAccount();
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _isDeleted = error == null;
    });
    _showToast(error ?? context.l10n.deleteAccountDone);
  }

  void _showToast(String message) {
    if (!mounted) return;
    showToast(message);
  }

  // This page doubles as the public `/delete-account` web route Google Play
  // requires, so it is sometimes the Navigator's only route (opened directly
  // from a link, not pushed from Settings). With nothing to pop, the default
  // back gesture/button would leave the user stranded here — send them home
  // instead.
  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goHome(context);
      },
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final currentUser = snapshot.data;

          final l10n = context.l10n;
          final colors = ShiaColors.of(context);
          final gutter = pageGutter(context, maxWidth: compactContentWidth);

          Widget section(Widget child, {double bottom = 14}) => SliverPadding(
                padding: gutter.copyWith(bottom: bottom),
                sliver: SliverToBoxAdapter(child: child),
              );
          Widget note(String text) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  text,
                  style: ShiaText.secondary.copyWith(color: colors.textMuted),
                ),
              );

          final deleted = [
            l10n.deleteAccountItemSignIn,
            l10n.deleteAccountItemFavorites,
            l10n.deleteAccountItemPreferences,
            l10n.deleteAccountItemAnalytics,
          ];

          return LargeTitlePage(
            title: l10n.deleteAccountTitle,
            subtitle: l10n.deleteAccountHeading,
            maxWidth: compactContentWidth,
            slivers: [
              section(note(currentUser == null
                  ? l10n.deleteAccountSignInPrompt
                  : l10n.deleteAccountSignedInAs(currentUser.email ??
                      currentUser.displayName ??
                      currentUser.uid))),
              section(GroupLabel(l10n.deleteAccountWhatGetsDeleted), bottom: 8),
              section(
                CardList(children: [
                  for (final (i, item) in deleted.indexed)
                    CardListRow(
                      first: i == 0,
                      last: i == deleted.length - 1,
                      titleStyle: ShiaText.secondary,
                      title: Text(item),
                    ),
                ]),
                bottom: 20,
              ),
              if (_isDeleted)
                section(
                  EmptyStateCard(
                    glyph: OutlineGlyph.check,
                    title: l10n.deleteAccountCompleted,
                    body: l10n.deleteAccountCompletedNote,
                  ),
                )
              else if (currentUser == null) ...[
                section(note(kIsWeb
                    ? l10n.deleteAccountWebSteps
                    : l10n.deleteAccountAppStepsAccount)),
                if (kIsWeb) ...[
                  section(
                    PageButton(
                      label: _signingIn == SignInProvider.google
                          ? l10n.deleteAccountSigningIn
                          : l10n.settingsSignInGoogle,
                      busy: _signingIn == SignInProvider.google,
                      icon: Image.asset('assets/images/google_logo.png',
                          width: 20, height: 20, excludeFromSemantics: true),
                      onPressed:
                          _isBusy ? null : () => _signIn(SignInProvider.google),
                    ),
                    bottom: 10,
                  ),
                  section(
                    PageButton(
                      label: _signingIn == SignInProvider.apple
                          ? l10n.deleteAccountSigningIn
                          : l10n.settingsSignInApple,
                      busy: _signingIn == SignInProvider.apple,
                      icon: Image.asset('assets/images/apple_logo.png',
                          width: 20,
                          height: 20,
                          color: colors.text,
                          excludeFromSemantics: true),
                      onPressed:
                          _isBusy ? null : () => _signIn(SignInProvider.apple),
                    ),
                  ),
                ],
              ] else ...[
                section(
                  PageButton(
                    label: _isBusy
                        ? l10n.deleteAccountDeleting
                        : l10n.deleteAccountButton,
                    glyph: OutlineGlyph.trash,
                    danger: true,
                    busy: _isBusy,
                    onPressed: _confirmDeletion,
                  ),
                  bottom: 10,
                ),
                section(
                  PageButton(
                    label: l10n.deleteAccountSignOut,
                    glyph: OutlineGlyph.logOut,
                    onPressed: _isBusy ? null : _signOut,
                  ),
                ),
              ],
              section(
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.deleteAccountHelp,
                    textAlign: TextAlign.center,
                    style: ShiaText.caption.copyWith(
                      height: 18 / 13,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
