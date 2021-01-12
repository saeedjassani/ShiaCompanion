import 'dart:async';
import 'dart:io';
import 'package:apple_sign_in/apple_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_auth_buttons/flutter_auth_buttons.dart' as authButton;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import 'about_page.dart';

class SettingsPage extends StatefulWidget {
  final Function() loginCallback;
  SettingsPage(this.loginCallback);

  @override
  _SettingsPageState createState() => new _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  _SettingsPageState();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          user != null
              ? ListTile(
                  title: Text("Name"),
                  trailing: Text("${user.displayName}"),
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
              min: 10.0,
              max: 24.0,
              divisions: 14,
              onChanged: (newRating) {
                englishFontSize = newRating.toInt().toDouble();
                saveDoublePref('eng_font_size', englishFontSize);
              },
              value: englishFontSize,
            ),
            trailing: Text(englishFontSize.toInt().toString()),
          ),
          Divider(),
          user != null
              ? ListTile(
                  leading: new Icon(Icons.power_settings_new),
                  title: new Text("Logout"),
                  onTap: () {
                    logOff();
                  },
                )
              : Column(
                  children: [
                    authButton.GoogleSignInButton(
                      onPressed: () {
                        _signInWithGoogle();
                        widget.loginCallback();
                      },
                    ),
                    Platform.isIOS
                        ? authButton.AppleSignInButton(
                            onPressed: () async {
                              _signInWithApple();
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
    int cur = sharedPreferences.getInt('adjust_hijri_date') ?? 0;
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
                onChanged: (int i) {
                  hijriDate = i;
                  saveHijriDate();
                  Navigator.pop(context);
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('adjust_hijri_date', hijriDate);
    await prefs.setString('prayerTimes', null);
    setState(() {});
  }

  saveBooleanPref(String key, bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {});
  }

  saveDoublePref(String key, double value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
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
    String url = 'mailto:developer110@hotmail.com?subject=' +
        Uri.encodeComponent("Shia Companion | Feedback");
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
        content: new Text("No email app found"),
      ));
    }
  }

  void _signInWithGoogle() async {
    try {
      User firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        final GoogleSignInAccount googleUser = await _googleSignIn.signIn();
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final UserCredential authResult =
            await _auth.signInWithCredential(credential);
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
      debugPrint(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
        content: new Text("Some error occured, please contact support"),
      ));
    }
  }

  void _signInWithApple() async {
    try {
      User firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        final AuthorizationResult appleResult =
            await AppleSignIn.performRequests(
                [AppleIdRequest(requestedScopes: [])]);

        switch (appleResult.status) {
          case AuthorizationStatus.authorized:
            final AuthCredential credential =
                OAuthProvider('apple.com').credential(
              accessToken: String.fromCharCodes(
                  appleResult.credential.authorizationCode),
              idToken:
                  String.fromCharCodes(appleResult.credential.identityToken),
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
                "Sign in failed: ${appleResult.error.localizedDescription}");
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
      debugPrint(error);
      return null;
    }
  }
}
