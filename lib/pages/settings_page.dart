import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_apple_sign_in/the_apple_sign_in.dart';
import '../constants.dart';
import '../services/account_service.dart';
import '../services/favorites_manager.dart';
import '../services/home_screen_widget_service.dart';
import '../services/session_refresh_service.dart';
import '../utils/dark_mode.dart';
import '../utils/external_launch.dart';
import '../utils/shared_preferences.dart';
import 'about_page.dart';
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
    await HomeScreenWidgetService.instance.publishAll();
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    trackScreen('Settings Page');
  }

  @override
  Widget build(BuildContext context) {
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    final currentUser = user ?? _auth.currentUser;

    return SingleChildScrollView(
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
              SwitchListTile(
                secondary: const Icon(Icons.my_location),
                title: const Text("Always use live location"),
                subtitle: Text(_liveLocationSubtitle()),
                value: shouldUseLiveLocation(),
                onChanged: (value) async {
                  if (value) {
                    final success = await initializeLocation(force: true);
                    if (success) {
                      await SP.prefs.setBool('use_live_location', true);
                      await HomeScreenWidgetService.instance
                          .publishUpcomingPrayer();
                    } else {
                      await SP.prefs.setBool('use_live_location', false);
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(success
                          ? "Live location enabled."
                          : "Location permission was not granted."),
                    ));
                  } else {
                    await SP.prefs.setBool('use_live_location', false);
                  }
                  setState(() {});
                },
              ),
              if (!shouldUseLiveLocation())
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: const Text("Refresh Location"),
                  subtitle: Text(_refreshLocationSubtitle()),
                  onTap: () async {
                    bool success = await initializeLocation(force: true);
                    if (success) {
                      await HomeScreenWidgetService.instance
                          .publishUpcomingPrayer();
                    }
                    if (!mounted) return;
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Location has been refreshed."),
                      ));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Failed to refresh location."),
                      ));
                    }
                    setState(() {});
                  },
                ),
            ],
          ),
          if (!kIsWeb)
            _buildSettingsSection(
              context,
              title: 'Notifications',
              children: [
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
          if (!kIsWeb)
            _buildSettingsSection(
              context,
              title: 'Home Screen Widget',
              children: [
                ExpansionTile(
                  leading: const Icon(Icons.widgets),
                  title: const Text("Next prayer widget"),
                  subtitle: const Text("Choose which prayers can appear next."),
                  children: _buildUpcomingPrayerWidgetOptions(),
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
                subtitle: Text("Version $appVersion"),
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
    final photoUrl = currentUser?.photoURL;

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
            backgroundImage: photoUrl == null || photoUrl.isEmpty
                ? null
                : NetworkImage(photoUrl),
            child: photoUrl == null || photoUrl.isEmpty
                ? Text(
                    _avatarLabel(currentUser),
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
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
                    color: colorScheme.onPrimaryContainer.withOpacity(0.78),
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
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.28),
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
          onTap: () => _showDeleteConfirmationDialog(context),
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
          color: theme.colorScheme.onSurface.withOpacity(0.62),
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
    final label = _accountTitle(currentUser);
    return label.isEmpty ? "S" : label.substring(0, 1).toUpperCase();
  }

  String _hijriAdjustmentLabel() {
    final adjustment = SP.prefs.getInt('adjust_hijri_date') ?? hijriDate;
    if (adjustment == 0) return "No adjustment";

    final days = adjustment.abs();
    final suffix = days == 1 ? "day" : "days";
    return adjustment > 0 ? "$days $suffix ahead" : "$days $suffix behind";
  }

  String _liveLocationSubtitle() {
    if (shouldUseLiveLocation()) {
      return "Prayer times will fetch your current location on app open.";
    }
    return "Reuse stored location until you refresh it manually.";
  }

  String _refreshLocationSubtitle() {
    final savedCity = city?.trim();
    if (savedCity != null && savedCity.isNotEmpty) {
      return "Current saved location: $savedCity.";
    }
    return "Update the saved prayer-times location.";
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

  saveHijriDate() async {
    await SP.prefs.setInt('adjust_hijri_date', hijriDate);
    await SP.prefs.remove('prayerTimes');
    await HomeScreenWidgetService.instance.publishTodaysRecitations();
    setState(() {});
  }

  List<Widget> _buildUpcomingPrayerWidgetOptions() {
    final prayerNames = getPrayerTimeObject().getTimeNames();
    return prayerNames
        .map(
          (prayerName) => SwitchListTile(
            title: Text(prayerName),
            value: HomeScreenWidgetService.shouldIncludePrayer(prayerName),
            onChanged: (value) async {
              await SP.prefs.setBool(
                HomeScreenWidgetService.prayerFilterPreferenceKey(prayerName),
                value,
              );
              await HomeScreenWidgetService.instance.publishUpcomingPrayer();
              if (!mounted) return;
              setState(() {});
            },
          ),
        )
        .toList();
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
        setState(() {
          user = authResult.user;
        });
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
        final AuthorizationResult appleResult =
            await TheAppleSignIn.performRequests(
                [AppleIdRequest(requestedScopes: [])]);

        switch (appleResult.status) {
          case AuthorizationStatus.authorized:
            final AuthCredential credential =
                OAuthProvider('apple.com').credential(
              accessToken: String.fromCharCodes(
                  appleResult.credential!.authorizationCode!),
              idToken:
                  String.fromCharCodes(appleResult.credential!.identityToken!),
            );

            UserCredential authResult =
                await _auth.signInWithCredential(credential);
            ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
              content: new Text("Login Successful"),
            ));
            setState(() {
              user = authResult.user;
            });
            break;

          case AuthorizationStatus.error:
            debugPrint(
                "Sign in failed: ${appleResult.error!.localizedDescription}");
            ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
              content: new Text("Apple Sign-In Failed"),
            ));
            break;

          case AuthorizationStatus.cancelled:
            debugPrint('User cancelled apple sign-in');
            break;
        }
      } else {
        logOff();
      }
    } catch (error) {
      debugPrint(error.toString());
      return null;
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Account Deletion'),
          content: Text(
              'Are you sure you want to delete your account? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => _deleteAccountAndData(context),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // Function to delete the account and associated data
  void _deleteAccountAndData(BuildContext context) async {
    try {
      await AccountService.deleteCurrentAccountAndData();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted successfully.'),
        ),
      );

      await _refreshAfterAuthChange();
    } on AccountActionException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting account: ${error.toString()}'),
        ),
      );
    }
  }
}
