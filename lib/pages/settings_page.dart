import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_apple_sign_in/the_apple_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../models/azaan_option.dart';
import '../services/account_service.dart';
import '../utils/dark_mode.dart';
import '../utils/shared_preferences.dart';
import 'about_page.dart';

class SettingsPage extends StatefulWidget {
  final Future<void> Function() loginCallback;
  SettingsPage(this.loginCallback);

  @override
  _SettingsPageState createState() => new _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  _SettingsPageState();

  @override
  void initState() {
    super.initState();
    trackScreen('Settings Page');
  }

  @override
  Widget build(BuildContext context) {
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          user != null
              ? ListTile(
                  title: Text("Name"),
                  trailing: Text("${user?.displayName}"),
                )
              : Container(),
          ListTile(
            leading: Icon(Icons.info),
            title: Text("About Us"),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => AboutPage()));
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.adjust),
            title: Text("Adjust Hijri Date"),
            onTap: () {
              adjustHijriAlertDialog(context);
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.volume_up),
            title: Text("Notification Sound"),
            subtitle: Text(_getCurrentAzaanName()),
            onTap: () {
              _showAzaanSelectionDialog(context);
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.play_arrow),
            title: Text("Test Azaan Notification"),
            onTap: () {
              _testNotification();
            },
          ),
          Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.my_location),
            title: const Text("Always use live location"),
            subtitle: Text(shouldUseLiveLocation()
                ? "Prayer times will fetch your current location on app open."
                : "Reuse stored location until you refresh it manually."),
            value: shouldUseLiveLocation(),
            onChanged: (value) async {
              await SP.prefs.setBool('use_live_location', value);
              if (value) {
                final success = await initializeLocation(force: true);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? "Live location enabled."
                      : "Failed to fetch live location."),
                ));
              }
              setState(() {});
            },
          ),
          Divider(),
          if (!shouldUseLiveLocation()) ...[
            ListTile(
              leading: Icon(Icons.location_on),
              title: Text("Refresh Location"),
              onTap: () async {
                bool success = await initializeLocation(force: true);
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
            Divider(),
          ],
          ListTile(
            leading: Icon(Icons.feedback),
            title: Text("Feedback"),
            onTap: () {
              _launchURL();
            },
          ),
          Divider(),
          SwitchListTile(
            value: darkModeProvider.isDarkMode,
            onChanged: (value) {
              darkModeProvider.toggleDarkMode();
            },
            title: Text("Dark mode"),
          ),
          Divider(),
          user != null
              ? Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.power_settings_new),
                      title: Text("Logout"),
                      onTap: () {
                        logOff();
                      },
                    ),
                    Divider(),
                    ListTile(
                      leading: Icon(Icons.delete_forever_outlined),
                      onTap: () => _showDeleteConfirmationDialog(context),
                      title: Text('Delete My Account'),
                    ),
                  ],
                )
              : Column(
                  children: [
                    ListTile(
                      leading: Image.asset('assets/images/google_logo.png',
                          height: 24.0),
                      title: Text('Sign in with Google'),
                      onTap: () async {
                        await _signInWithGoogle();
                        await widget.loginCallback();
                      },
                    ),
                    Divider(),
                    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                        ? ListTile(
                            leading: Image.asset('assets/images/apple_logo.png',
                                height: 24.0),
                            title: Text('Sign in with Apple'),
                            onTap: () async {
                              await _signInWithApple();
                              await widget.loginCallback();
                            },
                          )
                        : Container(),
                  ],
                ),
        ],
      ),
    );
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
    setState(() {});
  }

  String _getCurrentAzaanName() {
    final azaanId = SP.prefs.getString('azaan_preference') ?? 'azaan';
    final azaan = AzaanOptions.getById(azaanId);
    if (azaan?.id == 'custom') {
      final customPath = SP.prefs.getString('azaan_custom_file_path');
      if (customPath != null && customPath.isNotEmpty) {
        final fileName = customPath.split('/').last;
        return 'Custom: $fileName';
      }
      return 'Custom Audio';
    }
    return azaan?.name ?? 'Azaan';
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
        setUpNotifications();

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
          SnackBar(content: Text('Error: Unable to pick file. Please try again.')),
        );
      }
    }
  }

  void _showAzaanSelectionDialog(BuildContext context) {
    List<Widget> options = [];
    final currentAzaanId =
        SP.prefs.getString('azaan_preference') ?? 'azaan';

    for (final azaan in AzaanOptions.all) {
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
              setUpNotifications();
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
        content: Text('Test notification scheduled in 1 minute'),
        duration: Duration(seconds: 2),
      ),
    );

    testNotification(flutterLocalNotificationsPlugin!);
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
      user = null;
      await widget.loginCallback();
      setState(() {});
    } catch (e) {
      debugPrint("Error : $e");
    }
  }

  _launchURL() async {
    Uri url = Uri.parse('mailto:developer110@hotmail.com?subject=' +
        Uri.encodeComponent("Shia Companion | Feedback"));
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
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

      user = null;
      await widget.loginCallback();
      setState(() {});
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
