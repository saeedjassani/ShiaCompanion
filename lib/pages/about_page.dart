import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';

class AboutPage extends StatefulWidget {
  @override
  _AboutPageState createState() => new _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(appName),
      ),
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
                  "Version 1.0",
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
                  "We thank Almighty Allah and His beloved Fourteen Infallibles (a.s.) for Their help which made us able to share this humble work with the Momeneen.\n\n\nFor feedback, queries or suggestions contact :",
                  textAlign: TextAlign.center,
                ),
              ),
              ListTile(
                title: Text(
                  "developer110@hotmail.com",
                  textAlign: TextAlign.center,
                ),
              ),
              ListTile(
                title: Text(
                  "\n\nPlease recite Surah Fateha for :\n\nMarhum Haji Mohammad Raza Jassani\nMarhum Haji Yusufali Bhojani\nMarhoom Haji Zahid Husain Mohammed Husain Ajani\nand other Marhumeen and Marhumaat",
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
