import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:the_apple_sign_in/the_apple_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../utils/dark_mode.dart';
import '../utils/font_preferences.dart';
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
          ListTile(
            title: Text(
              'Arabic Font',
            ),
            trailing: Text(arabicFont),
            onTap: _showFontSelectionDialog,
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
                        widget.loginCallback();
                      },
                    ),
                    Divider(),
                    !kIsWeb && Platform.isIOS
                        ? ListTile(
                            leading: Image.asset('assets/images/apple_logo.png',
                                height: 24.0),
                            title: Text('Sign in with Apple'),
                            onTap: () async {
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

  void _onFontChanged(String? font) async {
    if (font != null) {
      setState(() {
        arabicFont = font;
      });
      await FontPreferences.setSelectedFont(font);
    }
  }

  Future<void> _showFontSelectionDialog() async {
    String? newFont = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text('Qalam'),
                trailing: Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  style: TextStyle(fontFamily: 'Qalam'),
                ),
                onTap: () {
                  Navigator.of(context).pop('Qalam');
                },
              ),
              ListTile(
                title: Text('MeQuran'),
                trailing: Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  style: TextStyle(fontFamily: 'MeQuran'),
                ),
                onTap: () {
                  Navigator.of(context).pop('MeQuran');
                },
              ),
              ListTile(
                title: Text('Muhammadi'),
                trailing: Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  style: TextStyle(fontFamily: 'Muhammadi'),
                ),
                onTap: () {
                  Navigator.of(context).pop('Muhammadi');
                },
              ),
              ListTile(
                title: Text('Uthmani'),
                trailing: Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  style: TextStyle(fontFamily: 'Uthmani'),
                ),
                onTap: () {
                  Navigator.of(context).pop('Uthmani');
                },
              ),
            ],
          ),
        );
      },
    );

    if (newFont != null) {
      _onFontChanged(newFont);
    }
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
        UserCredential? authResult;
        if (kIsWeb) {
          final GoogleAuthProvider googleProvider = GoogleAuthProvider();
          authResult =
              await FirebaseAuth.instance.signInWithPopup(googleProvider);
        } else {
          final GoogleSignIn googleSignIn = GoogleSignIn();
          final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
          final GoogleSignInAuthentication? googleAuth =
              await googleUser?.authentication;
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth?.accessToken,
            idToken: googleAuth?.idToken,
          );
          authResult = await _auth.signInWithCredential(credential);
        }

        ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
          content: new Text("Login Successful"),
        ));
        setState(() {
          user = authResult?.user;
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
