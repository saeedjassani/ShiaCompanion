import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/external_launch.dart';
import 'package:shia_companion/widgets/responsive_content.dart';
import '../l10n/l10n.dart';

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
                context.l10n.aboutVersion(appVersion),
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
                context.l10n.aboutDedication,
                textAlign: TextAlign.center,
              ),
            ),
            Center(
              child: FilledButton.icon(
                onPressed: () async {
                  final launched = await launchSupportEmail();
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.aboutNoEmailApp)),
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
              title: Text(context.l10n.aboutCredits, textAlign: TextAlign.center),
              subtitle: Column(
                children: [
                  Text(
                    context.l10n.aboutCreditAudio,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        launchExternalUri(Uri.parse('https://www.duas.org')),
                    child: const Text('duas.org'),
                  ),
                  const SizedBox(height: 12),
                  // Scheherazade New ships under the SIL Open Font License,
                  // which asks that the font be acknowledged where it is used.
                  Text(
                    context.l10n.aboutCreditScheherazade,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => launchExternalUri(
                        Uri.parse('https://software.sil.org/scheherazade/')),
                    child: const Text('software.sil.org/scheherazade'),
                  ),
                  const SizedBox(height: 12),
                  // Tanzil's terms (CC BY 3.0) require the source to be named
                  // and linked wherever its text is shown.
                  Text(
                    context.l10n.aboutCreditTanzil,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        launchExternalUri(Uri.parse('https://tanzil.net')),
                    child: const Text('tanzil.net'),
                  ),
                  const SizedBox(height: 12),
                  // QuranWBW's licence asks for the font's own credits and
                  // for the licence itself to be stated. See
                  // assets/fonts/QuranWBW-IndoPak-NOTICE.txt.
                  Text(
                    context.l10n.aboutCreditQuranWbw,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.aboutCreditIndoPakFont,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        launchExternalUri(Uri.parse('https://quranwbw.com')),
                    child: const Text('quranwbw.com'),
                  ),
                  const SizedBox(height: 12),
                  // GeoNames data is CC BY 4.0: credit and link wherever it is
                  // used. The city picker names it too.
                  const Text(
                    'The city list is from GeoNames, used under Creative '
                    'Commons Attribution 4.0.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => launchExternalUri(
                        Uri.parse('https://www.geonames.org')),
                    child: const Text('geonames.org'),
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
