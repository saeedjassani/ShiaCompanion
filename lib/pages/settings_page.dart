import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:the_apple_sign_in/the_apple_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../utils/dark_mode.dart';
import '../utils/shared_preferences.dart';
import 'about_page.dart';

class SettingsPage extends StatefulWidget {
  final Function() loginCallback;
  SettingsPage(this.loginCallback);

  @override
  _SettingsPageState createState() => new _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  _SettingsPageState();

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
            leading: Icon(Icons.feedback),
            title: Text("Feedback"),
            onTap: () {
              _launchURL();
            },
          ),
          Divider(),
          ListTile(
            title: Text('Arabic Font Size'),
            subtitle: Slider(
              activeColor: Theme.of(context).colorScheme.secondary,
              min: 20.0,
              max: 44.0,
              divisions: 12,
              onChanged: (newRating) {
                arabicFontSize = newRating.toInt().toDouble();
                saveDoublePref('ara_font_size', arabicFontSize);
              },
              value: arabicFontSize,
            ),
            trailing: Text(arabicFontSize.toInt().toString()),
          ),
          Divider(),
          ListTile(
            title: Text('English Font Size'),
            subtitle: Slider(
              activeColor: Theme.of(context).colorScheme.secondary,
              min: 10.0,
              max: 24.0,
              divisions: 14,
              onChanged: (val) {
                englishFontSize = val.toInt().toDouble();
                saveDoublePref('eng_font_size', englishFontSize);
              },
              value: englishFontSize,
            ),
            trailing: Text(englishFontSize.toInt().toString()),
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
          SwitchListTile(
            value: SP.prefs.getBool('keep_awake') ?? true,
            onChanged: (v) async {
              await SP.prefs.setBool("keep_awake", v);
              setState(() {});
            },
            title: Text("Keep screen on while reciting Zikr"),
          ),
          Divider(),
          user != null
              ? Column(
                  children: [
                    ListTile(
                      leading: new Icon(Icons.power_settings_new),
                      title: new Text("Logout"),
                      onTap: () {
                        logOff();
                      },
                    ),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => _showDeleteConfirmationDialog(context),
                        child: Text('Delete My Account'),
                      ),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors
                              .white, // Set your desired background color here
                        ),
                        icon: Image.asset('assets/images/google_logo.png',
                            height: 24.0),
                        onPressed: () async {
                          await _signInWithGoogle();
                          widget.loginCallback();
                        },
                      ),
                    ),
                    !kIsWeb && Platform.isIOS
                        ? SignInWithAppleButton(
                            text: '',
                            onPressed: () async {
                              await _signInWithApple();
                              widget.loginCallback();
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
              Radio(
                value: ints[i],
                groupValue: cur,
                onChanged: (int? i) {
                  if (i != null) {
                    hijriDate = i;
                    saveHijriDate();
                    Navigator.pop(context);
                  }
                },
              ),
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
      await _auth.signOut();
      user = null;
      widget.loginCallback();
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
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);

        ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
          content: new Text("Login Successful"),
        ));
        setState(() {
          user = userCredential.user;
        });
      } else {
        logOff();
      }
    } catch (e) {
      debugPrint(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
        content: new Text("Some error occured, please contact support"),
      ));
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
            // debugPrint(
            //     "Sign in failed: ${appleResult.error!.localizedDescription}");
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
      // debugPrint(error);
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
      // Get the currently signed-in user
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Remove favorites from the database
        DatabaseReference favoritesRef =
            FirebaseDatabase.instance.ref().child('new_favs').child(user.uid);
        await favoritesRef.remove();

        // Delete the user account
        await user.delete();

        Navigator.of(context).pop();

        // Show a success message or snackbar if needed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account deleted successfully.'),
          ),
        );

        user = null;
        widget.loginCallback();
        setState(() {});
      } else {
        // User is not signed in, show an appropriate message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User is not signed in.'),
          ),
        );
      }
    } catch (error) {
      // Handle errors during deletion process
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting account: ${error.toString()}'),
        ),
      );
    }
  }
}
