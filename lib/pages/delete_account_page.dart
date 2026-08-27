import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/account_service.dart';
import '../services/analytics_service.dart';
import 'home_page.dart';

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
        const SnackBar(content: Text('Signed in successfully.')),
      );
    } on AccountActionException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Sign in failed: $error');
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
      _showSnackBar('Signed out.');
    } catch (error) {
      _showSnackBar('Sign out failed: $error');
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
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your Shia Companion account and synced favorites.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
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
      _showSnackBar('Account deleted successfully.');
    } on AccountActionException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Error deleting account: $error');
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
      MaterialPageRoute(builder: (_) => MyHomePage(title: appName)),
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
              title: const Text('Delete Account'),
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
                            'Manage your Shia Companion account',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currentUser == null
                                ? 'Sign in to review and permanently delete the account tied to your synced favorites.'
                                : 'You are signed in as ${currentUser.email ?? currentUser.displayName ?? currentUser.uid}.',
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
                              children: const [
                                Text(
                                  'What gets deleted',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 8),
                                Text(
                                    'Your Shia Companion account sign-in record.'),
                                SizedBox(height: 4),
                                Text(
                                    'Your synced favorites and qaza tracker stored for that account.'),
                                SizedBox(height: 4),
                                Text(
                                    'Your synced reading preferences — Hijri date adjustment and font choices.'),
                                SizedBox(height: 4),
                                Text(
                                  'Anonymous analytics or crash reports already collected may remain in aggregate form.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_isDeleted) ...[
                            const ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.check_circle_outline),
                              title: Text(
                                  'Your account deletion request has completed.'),
                              subtitle: Text(
                                'If you sign in again later, a brand new account will be created.',
                              ),
                            ),
                          ] else if (currentUser == null) ...[
                            Text(
                              kIsWeb
                                  ? 'Use the Google sign-in button below, then confirm deletion.'
                                  : 'Open Preferences in the app and use Delete My Account.',
                            ),
                            const SizedBox(height: 16),
                            if (kIsWeb)
                              FilledButton.icon(
                                onPressed: _isBusy ? null : _signInWithGoogle,
                                icon: const Icon(Icons.login),
                                label: Text(_isBusy
                                    ? 'Signing in...'
                                    : 'Sign in with Google'),
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
                                      ? 'Deleting...'
                                      : 'Delete my account'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _isBusy ? null : _signOut,
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Sign out'),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                          const Text(
                            'Need help? Email developer110@hotmail.com and include the email address tied to your account.',
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
