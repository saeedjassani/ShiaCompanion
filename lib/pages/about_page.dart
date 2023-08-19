import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  @override
  _AboutPageState createState() => new _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  @override
  void initState() {
    super.initState();
    trackScreen('About Page');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getAppBar(),
      body: Container(
        padding: EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ListTile(
                title: Image.asset(
                  'assets/logo.png',
                  width: 150.0,
                  height: 150.0,
                ),
              ),
              ListTile(
                title: Text(
                  appName,
                  textAlign: TextAlign.center,
                ),
                subtitle: Text(
                  "Version " + appVersion,
                  textAlign: TextAlign.center,
                ),
              ),
              ListTile(
                title: Text(
                  "﷽",
                  textAlign: TextAlign.center,
                ),
              ),
              ListTile(
                title: Text(
                  "We thank Almighty Allah and His beloved Fourteen Infallibles (a.s.) for Their help which made us able to share this humble work with the Momeneen. We dedicate the app to them and the following Marhumeems:\n\nMarhum Haji Mohammad Raza Jassani\nMarhum Haji Yusufali Bhojani\nMarhoom Haji Zahid Husain Mohammed Husain Ajani\n\n\nPlease recite Surah Fateha for Marhumeen and Marhumaat\n\nFor feedback, queries or suggestions contact :",
                  textAlign: TextAlign.center,
                ),
              ),
              ListTile(
                onTap: () async {
                  Uri url = Uri.parse("mailto:developer110@hotmail.com");
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("No e-mail app found")));
                  }
                },
                title: Text(
                  "developer110@hotmail.com",
                  style: TextStyle(color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
