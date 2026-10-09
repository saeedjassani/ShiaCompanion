import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart' show setUpNotifications;
import '../l10n/app_language.dart';
import '../l10n/l10n.dart';
import '../services/analytics_service.dart';
import '../services/home_screen_widget_service.dart';
import '../services/zikr_reminder_service.dart';
import '../theme/shia_colors.dart';
import '../utils/language_provider.dart';
import 'choice_sheet.dart';
import 'outline_icon.dart';
import 'page_chrome.dart';

/// Whether Settings offers an App language row: only once a language other
/// than English has shipped app text, so it never offers a choice that
/// changes nothing.
bool appLanguageOffered() => LanguageProvider.appTextLanguages.length > 1;

/// Whether a Translation language row is offered: only once some zikr
/// translations have shipped. Tolerates a tree with no [LanguageProvider]
/// (widget tests that build the reading settings on their own), where there
/// is nothing to offer.
bool translationLanguageOffered(BuildContext context) =>
    (context.watch<LanguageProvider?>()?.translationLanguages.length ?? 0) > 1;

/// The app language as the App language row shows it: the chosen
/// language's own name, or "Same as phone (English)".
String appLanguageValue(BuildContext context) {
  final provider = context.watch<LanguageProvider>();
  final choice = appLanguageFor(provider.appLanguageChoice);
  return choice?.nativeName ??
      context.l10n.languageFollowDevice(provider.appLanguage.nativeName);
}

/// The translation language as its row shows it.
String translationLanguageValue(BuildContext context) {
  final provider = context.watch<LanguageProvider>();
  final choice = appLanguageFor(provider.translationLanguageChoice);
  return choice?.nativeName ??
      context.l10n.languageFollowApp(provider.translationLanguage.nativeName);
}

/// Asks which language the app's own text is in, and applies the answer.
Future<void> pickAppLanguage(BuildContext context) async {
  final provider = context.read<LanguageProvider>();
  final l10n = context.l10n;
  final picked = await _pickLanguage(
    context,
    title: l10n.settingsAppLanguage,
    defaultLabel: l10n.languageFollowDevice(provider.appLanguage.nativeName),
    languages: LanguageProvider.appTextLanguages,
    current: provider.appLanguageChoice,
  );
  if (picked == null) return;
  await provider.setAppLanguage(picked.code);
  // The home screen widgets, scheduled prayer notifications and zikr
  // reminders were written out in the old language: write them again.
  unawaited(HomeScreenWidgetService.instance.publishAll());
  unawaited(setUpNotifications());
  unawaited(ZikrReminderService.instance.rescheduleAll());
  unawaited(AnalyticsService.feature(
    'app_language_changed',
    label: 'App language changed',
    parameters: {'language': picked.code ?? 'device'},
  ));
}

/// Asks what a zikr's translation, instructions, merits and title are shown
/// in, and applies the answer.
Future<void> pickTranslationLanguage(BuildContext context) async {
  final provider = context.read<LanguageProvider>();
  final l10n = context.l10n;
  final picked = await _pickLanguage(
    context,
    title: l10n.settingsTranslationLanguage,
    defaultLabel:
        l10n.languageFollowApp(provider.translationLanguage.nativeName),
    languages: provider.translationLanguages,
    current: provider.translationLanguageChoice,
  );
  if (picked == null) return;
  await provider.setTranslationLanguage(picked.code);
  unawaited(AnalyticsService.feature(
    'translation_language_changed',
    label: 'Translation language changed',
    parameters: {'language': picked.code ?? 'app'},
  ));
}

/// The Translation language row of a card list (the reader's Text sheet).
class TranslationLanguageTile extends StatelessWidget {
  const TranslationLanguageTile({
    super.key,
    this.first = false,
    this.last = false,
  });

  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return CardListRow(
      first: first,
      last: last,
      title: Text(context.l10n.settingsTranslationLanguage),
      subtitle: Text(translationLanguageValue(context)),
      trailing: Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: OutlineIcon(OutlineGlyph.chevronRight,
            size: 18, color: colors.chevron),
      ),
      onTap: () => pickTranslationLanguage(context),
    );
  }
}

/// What the reader picked: a language code, or null for the default option.
/// The sheet itself returns null for "dismissed".
class _LanguagePick {
  const _LanguagePick(this.code);

  final String? code;

  @override
  bool operator ==(Object other) =>
      other is _LanguagePick && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

Future<_LanguagePick?> _pickLanguage(
  BuildContext context, {
  required String title,
  required String defaultLabel,
  required List<AppLanguage> languages,
  required String? current,
}) {
  return showChoiceSheet<_LanguagePick>(
    context,
    title: title,
    current: _LanguagePick(current),
    choices: [
      Choice(const _LanguagePick(null), defaultLabel),
      for (final language in languages)
        Choice(_LanguagePick(language.code), language.nativeName),
    ],
  );
}
