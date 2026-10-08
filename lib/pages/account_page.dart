import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../constants.dart';
import '../models/recitation_tracker_state.dart';
import '../services/account_service.dart';
import '../services/favorites_manager.dart';
import '../services/qaza_tracker_manager.dart';
import '../services/recitation_tracker_manager.dart';
import '../services/saved_verses_manager.dart';
import '../services/zikr_bookmarks_manager.dart';
import '../theme/shia_colors.dart';
import '../utils/network_utils.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import '../widgets/responsive_content.dart' show compactContentWidth;
import 'delete_account_page.dart';
import '../l10n/l10n.dart';
import '../widgets/app_toast.dart';

/// Who is signed in, as the Account page and the Settings card show them.
class AccountProfile {
  const AccountProfile({
    required this.name,
    required this.initials,
    this.email,
    this.provider,
  });

  factory AccountProfile.of(User user, AppLocalizations l10n) {
    final displayName = user.displayName?.trim() ?? '';
    final email = user.email?.trim() ?? '';
    final providers = user.providerData.map((p) => p.providerId).toSet();

    return AccountProfile(
      name: displayName.isNotEmpty
          ? displayName
          : email.isNotEmpty
              ? email
              : l10n.settingsSignedIn,
      initials: initialsOf(displayName),
      email: email.isEmpty ? null : email,
      provider: providers.contains('google.com')
          ? l10n.accountProviderGoogle
          : providers.contains('apple.com')
              ? l10n.accountProviderApple
              : null,
    );
  }

  final String name;

  /// Up to two letters for the avatar; empty without a display name.
  final String initials;
  final String? email;

  /// "Google" or "Apple": what the account signs in with.
  final String? provider;

  /// "Your Name" -> "YN".
  static String initialsOf(String displayName) => displayName
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part.substring(0, 1))
      .join()
      .toUpperCase();
}

/// Account (docs/DESIGN_SPEC.md, "Settings"; mockup `R3-Account`), opened
/// from the signed-in card in Settings: who is signed in and whether the
/// backup is up to date, what the backup holds, then **Log out** and
/// **Delete account…**. Pops once the user has logged out or deleted the
/// account, so Settings shows them signed out.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, this.profile, this.checkBackup});

  /// Read from the signed-in Firebase user when null.
  final AccountProfile? profile;

  /// Resolves true once everything written so far has reached the backup,
  /// false while it cannot (offline). Asks Firestore when null.
  final Future<bool> Function()? checkBackup;

  /// Whether everything written so far has reached the backup: false while
  /// offline, or when Firestore can't confirm it within ten seconds.
  static Future<bool> firestoreBackedUp() async {
    if (!await NetworkUtils().isDeviceOnline()) return false;
    try {
      await FirebaseFirestore.instance
          .waitForPendingWrites()
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  /// Null while checking.
  bool? _backedUp;
  bool _isBusy = false;

  final Listenable _synced = Listenable.merge([
    FavoritesManager.instance,
    ZikrBookmarksManager.instance,
    RecitationTrackerManager.instance,
    SavedVersesManager.instance,
    QazaTrackerManager.instance,
  ]);

  @override
  void initState() {
    super.initState();
    trackScreen('Account Page');
    unawaited(FavoritesManager.instance.loadFavorites());
    unawaited(ZikrBookmarksManager.instance.loadBookmarks());
    unawaited(RecitationTrackerManager.instance.loadRecitations());
    unawaited(SavedVersesManager.instance.loadSavedVerses());
    unawaited(QazaTrackerManager.instance.loadQaza());
    unawaited(_check());
  }

  Future<void> _check() async {
    final backedUp =
        await (widget.checkBackup ?? AccountPage.firestoreBackedUp)();
    if (mounted) setState(() => _backedUp = backedUp);
  }

  Future<void> _logOut() async {
    setState(() => _isBusy = true);
    try {
      await AccountService.signOut();
      user = null;
      if (!mounted) return;
      final message = context.l10n.deleteAccountSignedOut;
      // After the pop, so it shows on the page they go back to.
      Navigator.of(context).pop();
      _showToast(message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      _showToast(context.l10n.deleteAccountSignOutFailed('$error'));
    }
  }

  Future<void> _delete() async {
    if (!await confirmAccountDeletion(context) || !mounted) return;
    setState(() => _isBusy = true);
    final error = await deleteSignedInAccount();
    if (!mounted) return;
    if (error != null) {
      setState(() => _isBusy = false);
      _showToast(error);
      return;
    }
    final message = context.l10n.deleteAccountDone;
    // After the pop, so it shows on the page they go back to.
    Navigator.of(context).pop();
    _showToast(message);
  }

  void _showToast(String message) {
    showToast(message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context, maxWidth: compactContentWidth);
    final signedIn = FirebaseAuth.instance.currentUser;
    final profile = widget.profile ??
        (signedIn == null ? null : AccountProfile.of(signedIn, l10n));

    Widget section(Widget child, {double bottom = 14}) => SliverPadding(
          padding: gutter.copyWith(bottom: bottom),
          sliver: SliverToBoxAdapter(child: child),
        );

    return LargeTitlePage(
      title: l10n.accountTitle,
      maxWidth: compactContentWidth,
      slivers: [
        if (profile != null)
          section(_ProfileCard(profile: profile, backedUp: _backedUp)),
        section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GroupLabel(l10n.accountKeptSafe),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: _synced,
                builder: (context, _) => _BackupContents(),
              ),
            ],
          ),
        ),
        section(
          PageButton(
            label: l10n.accountLogOut,
            glyph: OutlineGlyph.logOut,
            onPressed: _isBusy ? null : _logOut,
          ),
        ),
        section(
          PageButton(
            label: l10n.accountDelete,
            glyph: OutlineGlyph.trash,
            danger: true,
            busy: _isBusy,
            onPressed: _isBusy ? null : _delete,
          ),
          bottom: 10,
        ),
        section(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l10n.accountDeleteNote,
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
  }
}

/// The avatar, name, email and provider, and whether the backup is up to
/// date.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.backedUp});

  final AccountProfile profile;
  final bool? backedUp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final email = profile.email;
    final provider = profile.provider;
    final detail = email != null && provider != null
        ? l10n.accountEmailAndProvider(email, provider)
        : email ?? provider;
    final backedUp = this.backedUp;
    final statusColor = backedUp == true ? colors.success : colors.textMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AccountAvatar(initials: profile.initials),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: ShiaText.sectionTitle.copyWith(
                        height: 25 / 20,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        detail,
                        style: ShiaText.secondary
                            .copyWith(color: colors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.well,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                OutlineIcon(
                  backedUp == true
                      ? OutlineGlyph.cloudCheck
                      : OutlineGlyph.cloud,
                  size: 20,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    switch (backedUp) {
                      null => l10n.accountBackupChecking,
                      true => l10n.accountBackedUp,
                      false => l10n.accountBackupOffline,
                    },
                    style: ShiaText.secondary.copyWith(
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The round avatar: initials on the accent, or a person without them.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.initials, this.size = 56});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
      child: initials.isEmpty
          ? OutlineIcon(OutlineGlyph.profile,
              size: size * 0.5, color: colors.onAccent)
          : Text(
              initials,
              style: TextStyle(
                fontSize: size * 20 / 56,
                fontWeight: FontWeight.w700,
                color: colors.onAccent,
              ),
            ),
    );
  }
}

/// What the backup holds, each with how much of it there is.
class _BackupContents extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final recitations = RecitationTrackerManager.instance.state;
    final tracks = recitations.labels.length +
        ((recitations.sessionsByLabel[unlabeledRecitationLabel] ?? 0) > 0
            ? 1
            : 0);
    final qaza = QazaTrackerManager.instance.state.totalRemaining;

    final rows = <(String, String?)>[
      (
        l10n.accountItemFavorites,
        '${FavoritesManager.instance.favorites.length}'
      ),
      (
        l10n.accountItemBookmarks,
        '${ZikrBookmarksManager.instance.state.bookmarks.length}'
      ),
      (l10n.accountItemQuranProgress, l10n.accountTracks(tracks)),
      (
        l10n.accountItemSavedVerses,
        '${SavedVersesManager.instance.state.verses.length}'
      ),
      (
        l10n.accountItemQaza,
        qaza == 0
            ? null
            : l10n.accountQazaLeft(NumberFormat.decimalPattern().format(qaza))
      ),
      (l10n.accountItemStats, null),
    ];

    return CardList(
      children: [
        for (var i = 0; i < rows.length; i++)
          CardListRow(
            first: i == 0,
            last: i == rows.length - 1,
            minHeight: 48,
            leading: OutlineIcon(OutlineGlyph.check,
                size: 18, color: colors.success, strokeWidth: 2.4),
            title: Text(rows[i].$1),
            trailing: rows[i].$2 == null
                ? null
                : Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
                    child: Text(
                      rows[i].$2!,
                      style:
                          ShiaText.secondary.copyWith(color: colors.textMuted),
                    ),
                  ),
          ),
      ],
    );
  }
}
