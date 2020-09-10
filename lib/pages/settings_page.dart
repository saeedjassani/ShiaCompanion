import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import 'about_page.dart';

class SettingsPage extends StatefulWidget {
  // final RefreshArticles refreshArticles;
  // final RefreshNotes refreshNotes;

  SettingsPage();

  @override
  _SettingsPageState createState() => new _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // final GoogleSignIn _googleSignIn = GoogleSignIn();
  // final FirebaseAuth _auth = FirebaseAuth.instance;
  // final RefreshArticles refreshArticles;
  // final RefreshNotes refreshNotes;

  _SettingsPageState();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          // ListTile(
          //   trailing:
          //       Text(user.isAnonymous ? AppTranslations.of(context).text("guest") : "${user.displayName}"),
          //   title: Text(AppTranslations.of(context).text("name")),
          // ),
          // Divider(),
          ListTile(
            leading: Icon(Icons.info),
            title: Text("About Us"),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => AboutPage()));
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
              divisions: 12,
              onChanged: (newRating) {
                englishFontSize = newRating.toInt().toDouble();
                saveDoublePref('eng_font_size', englishFontSize);
              },
              value: englishFontSize,
            ),
            trailing: Text(englishFontSize.toInt().toString()),
          ),
          Divider(),
          SwitchListTile(
            title: Text('Show Translation'),
            onChanged: (bool b) {
              showTranslation = b;
              saveBooleanPref('showTranslation', showTranslation);
            },
            value: showTranslation,
          ),
          Divider(),
          SwitchListTile(
            title: Text('Show Transliteration'),
            onChanged: (bool b) {
              showTransliteration = b;
              saveBooleanPref('showTransliteration', showTransliteration);
            },
            value: showTransliteration,
          )
          // Divider(),
          // !user.isAnonymous
          //     ? ListTile(
          //         leading: new Icon(Icons.power_settings_new),
          //         title: new Text(AppTranslations.of(context).text("logout")),
          //         onTap: () {
          //           logOff();
          //         },
          //       )
          //     : GoogleSignInButton(
          //         text: selectedLanguage == "English" ? "Sign in with Google" : "گوگل کے ساتھ سائن ان کریں",
          //         onPressed: () {
          //           _signInWithGoogle();
          //         },
          //         darkMode: true, // default: false
          //       ),
        ],
      ),
    );
  }

  adjustHijriAlertDialog(BuildContext context) {
    List<Widget> options = [];
    List<int> ints = [-3, -2, -1, 1, 2, 3];

    for (int i = 0, n = ints.length; i < n; i++) {
      String option = "Adjust Hijri Date by ${ints[i]} days";

      options.add(SimpleDialogOption(
        child: Text(option),
        onPressed: () {
          hijriDate += ints[i];
          saveHijriDate();
          Navigator.pop(context);
        },
      ));
    }

    SimpleDialog dialog = SimpleDialog(
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

  // void logOff() async {
  //   try {
  //     await _auth.signOut();
  //     Navigator.of(context).pushReplacementNamed(LoginPage.tag);
  //   } catch (e) {
  //     debugPrint("Error : $e");
  //   }
  // }

  _launchURL() async {
    String url =
        'mailto:developer110@hotmail.com?subject=' + Uri.encodeComponent("Shia Companion | Feedback");
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      key.currentState.showSnackBar(new SnackBar(
        content: new Text("No email app found"),
      ));
    }
  }

  // void _signInWithGoogle() async {
  //   try {
  //     FirebaseUser firebaseUser = await _auth.currentUser();
  //     if (firebaseUser != null && firebaseUser.isAnonymous) {
  //       final GoogleSignInAccount googleUser = await _googleSignIn.signIn();
  //       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
  //       final AuthCredential credential = GoogleAuthProvider.getCredential(
  //         accessToken: googleAuth.accessToken,
  //         idToken: googleAuth.idToken,
  //       );
  //       if (firebaseUser.isAnonymous) {
  //         await firebaseUser.linkWithCredential(credential);
  //       }

  //       assert(user.email != null);
  //       assert(user.displayName != null);
  //       assert(!user.isAnonymous);
  //       assert(await user.getIdToken() != null);

  //       final FirebaseUser currentUser = await _auth.currentUser();
  //       assert(user.uid == currentUser.uid);
  //       setState(() {
  //         if (user != null) {
  //           user = currentUser;
  //         }
  //       });
  //     } else if (firebaseUser != null && !firebaseUser.isAnonymous) {
  //       logOff();
  //     } else {
  //       Navigator.of(context).pushReplacementNamed(LoginPage.tag);
  //     }
  //   } catch (e) {
  //     debugPrint(e.toString());
  //     if (e.toString().contains('ERROR_CREDENTIAL_ALREADY_IN_USE,')) {
  //       // todo add note clear notice

  //       final GoogleSignInAccount googleUser = await _googleSignIn.signIn();
  //       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
  //       final AuthCredential credential = GoogleAuthProvider.getCredential(
  //         accessToken: googleAuth.accessToken,
  //         idToken: googleAuth.idToken,
  //       );
  //       final FirebaseUser currentUser = (await _auth.signInWithCredential(credential)).user;
  //       setState(() {
  //         if (user != null) {
  //           user = currentUser;
  //           refreshNotes();
  //         }
  //       });
  //     } else {
  //       key.currentState.showSnackBar(new SnackBar(
  //         content: new Text(AppTranslations.of(context).text("some_error")),
  //       ));
  //     }
  //   }
  // }
}
