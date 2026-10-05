import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_language.dart';
import '../l10n/l10n.dart';
import '../services/analytics_service.dart';
import '../utils/language_provider.dart';

/// The App language row. Absent until a language other than English has
/// shipped app text, so it never offers a choice that changes nothing.
class AppLanguageTile extends StatelessWidget {
  const AppLanguageTile({super.key, this.leading});

  final Widget? leading;

  static bool isOffered() => LanguageProvider.appTextLanguages.length > 1;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LanguageProvider>();
    final l10n = context.l10n;
    final choice = appLanguageFor(provider.appLanguageChoice);
    return ListTile(
      leading: leading,
      title: Text(l10n.settingsAppLanguage),
      subtitle: Text(
        choice == null
            ? l10n.languageFollowDevice(provider.appLanguage.nativeName)
            : choice.nativeName,
      ),
      onTap: () async {
        final picked = await _pickLanguage(
          context,
          title: l10n.settingsAppLanguage,
          defaultLabel:
              l10n.languageFollowDevice(provider.appLanguage.nativeName),
          languages: LanguageProvider.appTextLanguages,
          current: provider.appLanguageChoice,
        );
        if (picked == null) return;
        await provider.setAppLanguage(picked.code);
        unawaited(AnalyticsService.feature(
          'app_language_changed',
          label: 'App language changed',
          parameters: {'language': picked.code ?? 'device'},
        ));
      },
    );
  }
}

/// The Translation language row: what a zikr's translation, instructions,
/// merits and title are shown in. Absent until some zikr translations have
/// shipped.
class TranslationLanguageTile extends StatelessWidget {
  const TranslationLanguageTile({super.key, this.leading});

  final Widget? leading;

  /// Tolerates a tree with no [LanguageProvider] (widget tests that build
  /// the reading settings on their own), where there is nothing to offer.
  static bool isOffered(BuildContext context) =>
      (context.watch<LanguageProvider?>()?.translationLanguages.length ?? 0) >
      1;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LanguageProvider>();
    final l10n = context.l10n;
    final choice = appLanguageFor(provider.translationLanguageChoice);
    final followsApp =
        l10n.languageFollowApp(provider.translationLanguage.nativeName);
    return ListTile(
      leading: leading,
      title: Text(l10n.settingsTranslationLanguage),
      subtitle: Text(choice == null ? followsApp : choice.nativeName),
      onTap: () async {
        final picked = await _pickLanguage(
          context,
          title: l10n.settingsTranslationLanguage,
          defaultLabel: followsApp,
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
      },
    );
  }
}

/// What the reader picked: a language code, or null for the default option.
/// The dialog itself returns null for "dismissed".
class _LanguagePick {
  const _LanguagePick(this.code);

  final String? code;
}

Future<_LanguagePick?> _pickLanguage(
  BuildContext context, {
  required String title,
  required String defaultLabel,
  required List<AppLanguage> languages,
  required String? current,
}) {
  Widget option(String label, String? code, {TextDirection? direction}) {
    return ListTile(
      title: Text(label, textDirection: direction),
      trailing: current == code ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(_LanguagePick(code)),
    );
  }

  return showDialog<_LanguagePick>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        option(defaultLabel, null),
        for (final language in languages)
          option(
            language.nativeName,
            language.code,
            direction: language.textDirection,
          ),
      ],
    ),
  );
}
