import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/external_launch.dart';
import 'package:shia_companion/widgets/responsive_content.dart';

class AboutPage extends StatefulWidget {
  @override
  _AboutPageState createState() => new _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const String _supportEmail = "developer110@hotmail.com";

  @override
  void initState() {
    super.initState();
    trackScreen('About Page');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getAppBar(),
      body: ResponsiveScrollableContent(
        maxWidth: compactContentWidth,
        padding: const EdgeInsets.all(20.0),
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
                "Version $appVersion",
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
                "We thank Almighty Allah and His beloved Fourteen Infallibles (a.s.) for Their help which made us able to share this humble work with the Momeneen. We dedicate the app to them and the following Marhumeems:\n\nMarhooma Amina Mohammed Raza Jassani\nMarhoom Haji Mohammad Raza Jassani\nMarhoom Haji Yusufali Bhojani\n\n\nPlease recite Surah Fateha for Marhumeen and Marhumaat\n\nFor feedback, queries or suggestions contact :",
                textAlign: TextAlign.center,
              ),
            ),
            Center(
              child: FilledButton.icon(
                onPressed: () async {
                  final launched = await launchSupportEmail();
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("No e-mail app found")),
                    );
                  }
                },
                icon: const Icon(Icons.mail_outline),
                label: const Text(_supportEmail),
              ),
            ),
            const Divider(height: 40),
            // duas.org permit use of their recitations on condition of
            // credit - this is that acknowledgement.
            ListTile(
              title: const Text('Credits', textAlign: TextAlign.center),
              subtitle: Column(
                children: [
                  const Text(
                    'Recitation audio is streamed from duas.org and used with '
                    'their kind permission.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        launchExternalUri(Uri.parse('https://www.duas.org')),
                    child: const Text('duas.org'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
