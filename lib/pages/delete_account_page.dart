import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/account_service.dart';
import '../services/analytics_service.dart';
import '../navigation/app_shell.dart';
import '../l10n/l10n.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _isBusy = false;
  bool _isDeleted = false;

  @override
  void initState() {
    super.initState();
    trackScreen('Delete Account Page');
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isBusy = true;
    });

    try {
      final authResult = await AccountService.signInWithGoogle();
      user = authResult.user;
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.deleteAccountSignedIn)),
      );
    } on AccountActionException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar(context.l10n.deleteAccountSignInFailed('$error'));
    } finally {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
      });
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
      _showSnackBar(context.l10n.deleteAccountSignedOut);
    } catch (error) {
      _showSnackBar(context.l10n.deleteAccountSignOutFailed('$error'));
    } finally {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
      });
    }
  }

  Future<void> _confirmDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.deleteAccountConfirmTitle),
        content: Text(
          context.l10n.deleteAccountConfirmBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _isBusy = true;
    });

    try {
      await AccountService.deleteCurrentAccountAndData();
      user = null;
      unawaited(AnalyticsService.feature(
        'account_deleted',
        label: 'Account deleted',
      ));
      if (!mounted) return;
      setState(() {
        _isDeleted = true;
      });
      _showSnackBar(context.l10n.deleteAccountDone);
    } on AccountActionException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar(context.l10n.deleteAccountFailed('$error'));
    } finally {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.deleteAccountTitle),
            ),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.deleteAccountHeading,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currentUser == null
                                ? context.l10n.deleteAccountSignInPrompt
                                : context.l10n.deleteAccountSignedInAs(currentUser.email ??
                                      currentUser.displayName ??
                                      currentUser.uid),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.deleteAccountWhatGetsDeleted,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 8),
                                Text(
                                    context.l10n.deleteAccountItemSignIn),
                                SizedBox(height: 4),
                                Text(
                                    context.l10n.deleteAccountItemFavorites),
                                SizedBox(height: 4),
                                Text(
                                    context.l10n.deleteAccountItemPreferences),
                                SizedBox(height: 4),
                                Text(
                                  context.l10n.deleteAccountItemAnalytics,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_isDeleted) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.check_circle_outline),
                              title: Text(
                                  context.l10n.deleteAccountCompleted),
                              subtitle: Text(
                                context.l10n.deleteAccountCompletedNote,
                              ),
                            ),
                          ] else if (currentUser == null) ...[
                            Text(
                              kIsWeb
                                  ? context.l10n.deleteAccountWebSteps
                                  : context.l10n.deleteAccountAppSteps,
                            ),
                            const SizedBox(height: 16),
                            if (kIsWeb)
                              FilledButton.icon(
                                onPressed: _isBusy ? null : _signInWithGoogle,
                                icon: const Icon(Icons.login),
                                label: Text(_isBusy
                                    ? context.l10n.deleteAccountSigningIn
                                    : context.l10n.settingsSignInGoogle),
                              ),
                          ] else ...[
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton.icon(
                                  onPressed: _isBusy ? null : _confirmDeletion,
                                  icon:
                                      const Icon(Icons.delete_forever_outlined),
                                  label: Text(_isBusy
                                      ? context.l10n.deleteAccountDeleting
                                      : context.l10n.deleteAccountButton),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _isBusy ? null : _signOut,
                                  icon: const Icon(Icons.logout),
                                  label: Text(context.l10n.deleteAccountSignOut),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                          Text(
                            context.l10n.deleteAccountHelp,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
