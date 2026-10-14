import 'package:flutter/material.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/external_launch.dart';
import 'package:shia_companion/widgets/responsive_content.dart'
    show compactContentWidth;

import '../l10n/l10n.dart';
import '../theme/shia_colors.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import '../widgets/app_toast.dart';

/// About: the app and its version, its intention, the support address, and
/// the credits the content's licences ask for.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const String _supportEmail = "developer110@hotmail.com";

  @override
  void initState() {
    super.initState();
    trackScreen('About Page');
  }

  Future<void> _email() async {
    final launched = await launchSupportEmail();
    if (!launched && mounted) {
      showToast(context.l10n.aboutNoEmailApp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context, maxWidth: compactContentWidth);

    Widget section(Widget child, {double bottom = 14}) => SliverPadding(
          padding: gutter.copyWith(bottom: bottom),
          sliver: SliverToBoxAdapter(child: child),
        );

    final credits = <(String, String, String)>[
      // duas.org permit use of their recitations on condition of credit -
      // this is that acknowledgement.
      (l10n.aboutCreditAudio, 'duas.org', 'https://www.duas.org'),
      // Scheherazade New ships under the SIL Open Font License, which asks
      // that the font be acknowledged where it is used.
      (
        l10n.aboutCreditScheherazade,
        'software.sil.org/scheherazade',
        'https://software.sil.org/scheherazade/'
      ),
      // Tanzil's terms (CC BY 3.0) require the source to be named and linked
      // wherever its text is shown.
      (l10n.aboutCreditTanzil, 'tanzil.net', 'https://tanzil.net'),
      // QuranWBW's licence asks for the font's own credits and for the
      // licence itself to be stated. See
      // assets/fonts/QuranWBW-IndoPak-NOTICE.txt.
      (
        '${l10n.aboutCreditQuranWbw}\n\n${l10n.aboutCreditIndoPakFont}',
        'quranwbw.com',
        'https://quranwbw.com'
      ),
      // GeoNames data is CC BY 4.0: credit and link wherever it is used. The
      // city picker names it too.
      (l10n.aboutCityListCredit, 'geonames.org', 'https://www.geonames.org'),
    ];

    return LargeTitlePage(
      title: l10n.settingsAboutUs,
      subtitle: l10n.aboutVersion(appVersion),
      maxWidth: compactContentWidth,
      slivers: [
        // The app's identity sits on the page itself, not in a card.
        section(
          Column(
            children: [
              Image.asset('assets/logo.png', width: 88, height: 88),
              const SizedBox(height: 10),
              Text(
                appName,
                textAlign: TextAlign.center,
                style: ShiaText.sectionTitle.copyWith(color: colors.text),
              ),
            ],
          ),
          bottom: 24,
        ),
        section(
          Column(
            children: [
              Text(
                '﷽',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: arabicFont,
                  fontSize: 32,
                  height: 1.6,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.aboutIntention,
                textAlign: TextAlign.center,
                style: ShiaText.secondary.copyWith(color: colors.text),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.aboutFatihaRequest,
                textAlign: TextAlign.center,
                style: ShiaText.secondary.copyWith(color: colors.textMuted),
              ),
            ],
          ),
          bottom: 24,
        ),
        // Feedback, requests, GitHub and rating live under Settings' Support
        // group; this is just the address, for anyone who came here for it.
        section(
          CardList(
            children: [
              CardListRow(
                first: true,
                last: true,
                leading: OutlineIcon(OutlineGlyph.mail,
                    size: 20, color: colors.accent),
                title: Text(l10n.aboutContactUs),
                subtitle: Text(
                  _supportEmail,
                  style: ShiaText.secondary.copyWith(color: colors.textMuted),
                ),
                onTap: _email,
              ),
            ],
          ),
          bottom: 20,
        ),
        section(GroupLabel(l10n.aboutCredits), bottom: 8),
        section(
          CardList(
            children: [
              for (final (i, (credit, site, url)) in credits.indexed)
                CardListRow(
                  first: i == 0,
                  last: i == credits.length - 1,
                  titleStyle: ShiaText.secondary,
                  title: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(credit),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      site,
                      style: ShiaText.secondary.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ),
                  trailing: SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: OutlineIcon(OutlineGlyph.link,
                          size: 20, color: colors.accent),
                    ),
                  ),
                  onTap: () => launchExternalUri(Uri.parse(url)),
                ),
            ],
          ),
          bottom: 20,
        ),
        section(
          Text(
            l10n.aboutFooter,
            textAlign: TextAlign.center,
            style: ShiaText.caption.copyWith(color: colors.textMuted),
          ),
          bottom: 24,
        ),
      ],
    );
  }
}
