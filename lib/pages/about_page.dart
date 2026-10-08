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

/// About: the app and its version, the dedication, the support address, and
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
        section(
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              children: [
                Image.asset('assets/logo.png', width: 96, height: 96),
                const SizedBox(height: 12),
                Text(
                  appName,
                  textAlign: TextAlign.center,
                  style: ShiaText.sectionTitle.copyWith(color: colors.text),
                ),
                const SizedBox(height: 14),
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
                  l10n.aboutDedication,
                  textAlign: TextAlign.center,
                  style: ShiaText.secondary.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 16),
                PageButton(
                  label: _supportEmail,
                  glyph: OutlineGlyph.mail,
                  filled: true,
                  onPressed: _email,
                ),
              ],
            ),
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
        ),
      ],
    );
  }
}
