import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../constants.dart';
import '../services/account_service.dart';
import '../services/analytics_service.dart';
import '../services/azaan_opt_in_service.dart';
import '../services/favorites_manager.dart';
import '../services/home_screen_widget_service.dart';
import '../services/location_service.dart';
import '../services/qaza_tracker_manager.dart';
import '../services/session_refresh_service.dart';
import '../utils/dark_mode.dart';
import '../utils/external_launch.dart';
import '../utils/shared_preferences.dart';
import '../utils/widget_prayer_time_selection.dart';
import '../widgets/responsive_content.dart';
import '../widgets/widget_prayer_times_dialog.dart';
import '../widgets/zikr_reading_preferences.dart';
import 'about_page.dart';
import 'delete_account_page.dart';
import 'scheduled_notifications_page.dart';

class SettingsPage extends StatefulWidget {
  SettingsPage();

  @override
  _SettingsPageState createState() => new _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  _SettingsPageState();

  Future<void> _refreshAfterAuthChange() async {
    await SessionRefreshService.refreshSessionState();
    await FavoritesManager.instance.loadFavorites();
    await QazaTrackerManager.instance.loadQaza();
    await HomeScreenWidgetService.instance.publishAll();
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    trackScreen('Settings Page');
    // The refresh row reflects location status, which can also change from the
    // home page or an automatic refresh, so follow the service rather than
    // relying on this page's own taps to know when to redraw.
    LocationService.instance.addListener(_onLocationChanged);
    if (_showPrecisePrayerAlarmSetting) {
      unawaited(_refreshExactAlarmPermissionStatus());
    }
  }

  @override
  void dispose() {
    LocationService.instance.removeListener(_onLocationChanged);
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  bool get _showPrecisePrayerAlarmSetting =>
      shouldShowPrecisePrayerAlarmSetting(platform: defaultTargetPlatform);

  @override
  Widget build(BuildContext context) {
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    final currentUser = user ?? _auth.currentUser;

    return ResponsiveScrollableContent(
      maxWidth: compactContentWidth,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildAccountHeader(context, currentUser),
          const SizedBox(height: 16),
          _buildSettingsSection(
            context,
            title: 'Prayer & Location',
            children: [
              ListTile(
                leading: const Icon(Icons.adjust),
                title: const Text("Adjust Hijri Date"),
                subtitle: Text(_hijriAdjustmentLabel()),
                onTap: () {
                  adjustHijriAlertDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.widgets),
                title: const Text("Prayer Times Shown"),
                subtitle: Text(_widgetPrayerTimesSubtitle()),
                onTap: () async {
                  final changed = await showWidgetPrayerTimesDialog(context);
                  if (changed && mounted) setState(() {});
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text("Refresh Location"),
                subtitle: Text(_refreshLocationSubtitle()),
                trailing: LocationService.instance.isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                enabled: !LocationService.instance.isRefreshing,
                onTap: () async {
                  // Passing context lets initializeLocation explain *why* it
                  // failed and offer the relevant settings screen, instead of
                  // a snackbar that guesses. The row redraws from the service
                  // listener, so there is no setState to sequence here.
                  final success =
                      await LocationService.instance.refresh(context: context);
                  if (!mounted) return;
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Location has been refreshed."),
                    ));
                    return;
                  }
                  // Those diagnostic dialogs are all guarded on !kIsWeb, so on
                  // web a failure would otherwise look like a dead tap.
                  if (kIsWeb) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(LocationService.instance.failureMessage),
                    ));
                  }
                },
              ),
            ],
          ),
          if (!kIsWeb)
            _buildSettingsSection(
              context,
              title: 'Notifications',
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active),
                  title: const Text("Azan Notifications"),
                  subtitle: Text(_azaanNotificationsSubtitle()),
                  value: AzaanOptInService.isEnabled,
                  onChanged: _setAzaanNotifications,
                ),
                ListTile(
                  leading: const Icon(Icons.volume_up),
                  title: const Text("Notification Sound"),
                  subtitle: Text(_getCurrentAzaanName()),
                  onTap: () {
                    _showAzaanSelectionDialog(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.play_arrow),
                  title: const Text("Test Azaan Notification"),
                  subtitle:
                      const Text("Schedule a sample notification in a moment."),
                  onTap: () {
                    _testNotification();
                  },
                ),
                if (_showPrecisePrayerAlarmSetting)
                  ListTile(
                    leading: const Icon(Icons.alarm_on),
                    title: const Text("Precise Prayer Alarms"),
                    subtitle: Text(_precisePrayerAlarmSubtitle()),
                    onTap: _requestPrecisePrayerAlarms,
                  ),
                if (isUserAdmin)
                  ListTile(
                    leading: const Icon(Icons.notifications_active),
                    title: const Text("Scheduled Notifications"),
                    subtitle:
                        const Text("Review pending prayer notifications."),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScheduledNotificationsPage(),
                        ),
                      );
                    },
                  ),
              ],
            ),
          _buildSettingsSection(
            context,
            title: 'Appearance',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                value: darkModeProvider.isDarkMode,
                onChanged: (value) {
                  darkModeProvider.toggleDarkMode();
                },
                title: const Text("Dark mode"),
                subtitle: const Text("Use the dark appearance across the app."),
              ),
            ],
          ),
          _buildSettingsSection(
            context,
            title: 'Zikr Reading & Sharing',
            children: [
              ZikrReadingPreferencesControls(
                showLeadingIcons: true,
                onChanged: () {
                  if (!mounted) return;
                  setState(() {});
                },
              ),
            ],
          ),
          _buildSettingsSection(
            context,
            title: 'Support',
            children: [
              ListTile(
                leading: const Icon(Icons.feedback),
                title: const Text("Feedback"),
                subtitle: const Text("Send questions, issues, or suggestions."),
                onTap: () {
                  _launchURL();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text("About Us"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AboutPage()),
                  );
                },
              ),
            ],
          ),
          _buildSettingsSection(
            context,
            title: 'Account',
            children: _buildAccountActionTiles(currentUser),
          ),
          _buildVersionFooter(context),
        ],
      ),
    );
  }

  Widget _buildAccountHeader(BuildContext context, User? currentUser) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSignedIn = currentUser != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colorScheme.primary,
            child: isSignedIn
                ? Text(
                    _avatarLabel(currentUser),
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Icon(
                    Icons.account_circle,
                    color: colorScheme.onPrimary,
                    size: 30,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSignedIn ? _accountTitle(currentUser) : "Not signed in",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSignedIn
                      ? _accountSubtitle(currentUser)
                      : "Sign in to sync favorites across devices.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        colorScheme.onPrimaryContainer.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Material rather than a decorated Container: the rows inside are
          // ListTiles, which paint their background and ink splashes onto the
          // nearest Material ancestor. Behind a coloured Container those
          // effects are hidden, so taps landed with no ripple.
          Material(
            color: theme.cardColor,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.28),
              ),
            ),
            child: Column(
              children: _withDividers(children),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> children) {
    final dividedChildren = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        dividedChildren.add(const Divider(height: 1));
      }
      dividedChildren.add(children[index]);
    }
    return dividedChildren;
  }

  List<Widget> _buildAccountActionTiles(User? currentUser) {
    if (currentUser != null) {
      final errorColor = Theme.of(context).colorScheme.error;

      return [
        ListTile(
          leading: const Icon(Icons.power_settings_new),
          title: const Text("Logout"),
          subtitle: const Text("Sign out on this device."),
          onTap: () {
            logOff();
          },
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever_outlined,
            color: errorColor,
          ),
          onTap: () => _openDeleteAccountPage(context),
          title: Text(
            'Delete My Account',
            style: TextStyle(color: errorColor),
          ),
          subtitle: const Text("Permanently remove your account data."),
        ),
      ];
    }

    return [
      ListTile(
        leading: Image.asset('assets/images/google_logo.png', height: 24.0),
        title: const Text('Sign in with Google'),
        subtitle: const Text("Sync favorites and account data."),
        onTap: () async {
          await _signInWithGoogle();
          await _refreshAfterAuthChange();
        },
      ),
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
        ListTile(
          leading: Image.asset('assets/images/apple_logo.png', height: 24.0),
          title: const Text('Sign in with Apple'),
          subtitle: const Text("Use your Apple ID to sign in."),
          onTap: () async {
            await _signInWithApple();
            await _refreshAfterAuthChange();
          },
        ),
    ];
  }

  Widget _buildVersionFooter(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        "$appName $appVersion",
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
        ),
      ),
    );
  }

  String _accountTitle(User? currentUser) {
    final displayName = currentUser?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final email = currentUser?.email?.trim();
    if (email != null && email.isNotEmpty) return email;

    return "Signed in";
  }

  String _accountSubtitle(User? currentUser) {
    final email = currentUser?.email?.trim();
    if (email != null && email.isNotEmpty) return email;

    return "Favorites and account data are syncing.";
  }

  String _avatarLabel(User? currentUser) {
    final displayName = currentUser?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      final parts = displayName
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .take(2)
          .toList();
      final initials = parts.map((part) => part.substring(0, 1)).join();
      if (initials.isNotEmpty) return initials.toUpperCase();
    }

    final email = currentUser?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }

    return "SC";
  }

  String _hijriAdjustmentLabel() {
    final adjustment = SP.prefs.getInt('adjust_hijri_date') ?? hijriDate;
    if (adjustment == 0) return "No adjustment";

    final days = adjustment.abs();
    final suffix = days == 1 ? "day" : "days";
    return adjustment > 0 ? "$days $suffix ahead" : "$days $suffix behind";
  }

  String _refreshLocationSubtitle() {
    final location = LocationService.instance;
    if (location.isRefreshing) {
      return "Updating your location…";
    }
    // Survives the snackbar, and covers the paths that show no dialog at all.
    if (location.status == LocationRefreshStatus.failed) {
      return "${location.failureMessage}. Tap to try again.";
    }

    final savedCity = city?.trim();
    if (savedCity == null || savedCity.isEmpty) {
      return "Update the saved prayer-times location.";
    }

    final updatedAt = LocationService.instance.updatedAt;
    if (updatedAt == null) {
      return "Current saved location: $savedCity.";
    }
    return "$savedCity · updated ${_locationAgeLabel(updatedAt)}. "
        "Refreshes on its own as you move.";
  }

  String _locationAgeLabel(DateTime updatedAt) {
    final age = DateTime.now().difference(updatedAt);
    if (age.inMinutes < 1) return "just now";
    if (age.inMinutes < 60) return "${age.inMinutes}m ago";
    if (age.inHours < 24) return "${age.inHours}h ago";
    return "${age.inDays}d ago";
  }

  adjustHijriAlertDialog(BuildContext context) {
    List<Widget> options = [];
    List<int> ints = [-3, -2, -1, 0, 1, 2, 3];
    int cur = SP.prefs.getInt('adjust_hijri_date') ?? 0;
    if (cur > 3 || cur < -3) {
      cur = 0;
    }

    for (int i = 0, n = ints.length; i < n; i++) {
      String option = "Adjust Hijri Date by ${ints[i]} days";

      options.add(SimpleDialogOption(
        child: InkWell(
          onTap: () {
            hijriDate = ints[i];
            saveHijriDate();
            Navigator.pop(context);
          },
          child: Row(
            children: [
              Icon(
                cur == ints[i]
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(option)
            ],
          ),
        ),
      ));
    }

    SimpleDialog dialog = SimpleDialog(
      title: Text("Adjust Hijri Date"),
      children: options,
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return dialog;
      },
    );
  }

  String _widgetPrayerTimesSubtitle() {
    final names =
        selectedWidgetPrayerTimes().map((time) => time.name).join(', ');
    return "Shown on the home page and home screen widgets: $names.";
  }

  saveHijriDate() async {
    await SP.prefs.setInt('adjust_hijri_date', hijriDate);
    await SP.prefs.remove('prayerTimes');
    await HomeScreenWidgetService.instance.publishTodaysRecitations();
    setState(() {});
  }

  String _azaanNotificationsSubtitle() {
    if (!AzaanOptInService.isEnabled) {
      return "Off. Turn on to be notified at prayer times.";
    }
    final enabledCount =
        enabledPrayerNotificationCount(getPrayerNotificationPrayerNames());
    return enabledCount == 1
        ? "On for 1 prayer. Tap a prayer on the home page to change which."
        : "On for $enabledCount prayers. Tap a prayer on the home page to change which.";
  }

  /// The master switch, and the way back for anyone who said "Not now" on first
  /// run. Turning it on restores the default Fajr / Zuhr / Maghrib set — the
  /// per-prayer choice itself lives on the prayer times card.
  Future<void> _setAzaanNotifications(bool enabled) async {
    await AzaanOptInService.setEnabled(enabled);
    unawaited(AnalyticsService.feature(
      'azaan_notifications_toggled',
      label: 'Azan notifications',
      parameters: {'enabled': enabled ? 'on' : 'off'},
    ));
    if (!mounted) return;
    setState(() {});
  }

  String _getCurrentAzaanName() {
    final azaan = getSelectedAzaan();
    if (azaan.id == 'custom') {
      final customPath = SP.prefs.getString(azaanCustomFilePathKey);
      if (customPath != null && customPath.isNotEmpty) {
        final fileName = customPath.split('/').last;
        return 'Custom: $fileName';
      }
      return 'Custom Audio';
    }
    return azaan.name;
  }

  Future<void> _pickCustomAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.audio,
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        final filePath = file.path;
        final fileName = file.path.split('/').last;

        // Verify file exists and is readable
        if (!await file.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: Audio file not found')),
            );
          }
          return;
        }

        await saveCustomAudioFilePath(filePath);
        await saveAzaanPreference('custom');
        // IMPORTANT: Await the notification setup to catch any errors
        await setUpNotifications();

        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected: $fileName'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking audio file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: Unable to pick file. Please try again.')),
        );
      }
    }
  }

  void _showAzaanSelectionDialog(BuildContext context) {
    List<Widget> options = [];
    final currentAzaanId = getSelectedAzaan().id;

    for (final azaan in getAvailableAzaanOptions()) {
      options.add(SimpleDialogOption(
        child: InkWell(
          onTap: () async {
            if (azaan.id == 'custom') {
              // Show file picker for custom audio
              Navigator.pop(context);
              await _pickCustomAudioFile();
            } else {
              // Save standard option preference
              await saveAzaanPreference(azaan.id);
              await setUpNotifications();
              Navigator.pop(context);
              if (mounted) {
                setState(() {});
              }
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    currentAzaanId == azaan.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        azaan.name,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      SizedBox(
                        width: 250,
                        child: Text(
                          azaan.description,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ));
    }

    SimpleDialog dialog = SimpleDialog(
      title: Text("Notification Sound"),
      children: options,
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return dialog;
      },
    );
  }

  Future<void> _testNotification() async {
    if (flutterLocalNotificationsPlugin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification system not initialized')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Test notification scheduled in a few seconds'),
        duration: Duration(seconds: 2),
      ),
    );

    await testNotification(flutterLocalNotificationsPlugin!);
  }

  String _precisePrayerAlarmSubtitle() {
    return canScheduleExactPrayerNotifications
        ? 'Enabled for exact Azan timing.'
        : 'Off. Android may deliver prayer notifications a bit late.';
  }

  Future<void> _refreshExactAlarmPermissionStatus() async {
    await refreshExactPrayerAlarmPermissionStatus();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _requestPrecisePrayerAlarms() async {
    if (flutterLocalNotificationsPlugin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification system not initialized')),
      );
      return;
    }

    final alreadyEnabled = await refreshExactPrayerAlarmPermissionStatus();
    if (!mounted) return;
    if (alreadyEnabled) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Precise prayer alarms are already enabled.')),
      );
      return;
    }

    final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Enable Precise Prayer Alarms?'),
            content: const Text(
              'Android requires Alarms & reminders access for Azan notifications to fire exactly at prayer time. Without it, reminders still work but may arrive a bit late.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldOpenSettings) return;

    final granted = await requestExactPrayerAlarmPermissionIfNeeded();
    await refreshExactPrayerAlarmPermissionStatus();
    if (canScheduleExactPrayerNotifications) {
      await setUpNotifications();
    }

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted || canScheduleExactPrayerNotifications
              ? 'Precise prayer alarms enabled.'
              : 'Precise prayer alarms were not enabled. Approximate timing will still be used.',
        ),
      ),
    );
  }

  saveBooleanPref(String key, bool value) async {
    await SP.prefs.setBool(key, value);
    setState(() {});
  }

  saveDoublePref(String key, double value) async {
    await SP.prefs.setDouble(key, value);
    setState(() {});
  }

  Future<void> logOff() async {
    try {
      await AccountService.signOut();
      await _refreshAfterAuthChange();
    } catch (e) {
      debugPrint("Error : $e");
    }
  }

  Future<void> _launchURL() async {
    final launched =
        await launchSupportEmail(subject: "Shia Companion | Feedback");
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
        content: new Text("No email app found"),
      ));
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        final authResult = await AccountService.signInWithGoogle();

        ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
          content: new Text("Login Successful"),
        ));
        user = authResult.user;
        await _refreshAfterAuthChange();
      } else {
        logOff();
      }
    } catch (e) {
      final message = e.toString();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Something went wrong"),
          content: Text("Error: $message\nPlease contact support."),
        ),
      );
    }
  }

  Future<void> _signInWithApple() async {
    try {
      User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
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
        final authResult = await _auth.signInWithCredential(credential);
        ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
          content: new Text("Login Successful"),
        ));
        user = authResult.user;
        await _refreshAfterAuthChange();
      } else {
        logOff();
      }
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        debugPrint('User cancelled apple sign-in');
        return;
      }
      debugPrint("Apple sign-in failed: ${error.message}");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
        content: new Text("Apple Sign-In Failed"),
      ));
    } catch (error) {
      debugPrint(error.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
        content: new Text("Apple Sign-In Failed"),
      ));
    }
  }

  // Confirmation, deletion and error handling all live on DeleteAccountPage
  // now — it's also the page Google Play's public account-deletion link
  // opens, so Settings and that link go through one implementation instead
  // of a second, modal-based copy of the same flow.
  Future<void> _openDeleteAccountPage(BuildContext context) async {
    await pushPageRoute(context, const DeleteAccountPage());
    if (!mounted) return;
    await _refreshAfterAuthChange();
  }
}
