import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'app_localizations_en.dart';

export 'app_localizations.dart';

/// The app's translated strings, for code that has no [BuildContext] to look
/// them up from - notifications, home screen widgets, share text.
///
/// Kept in step with the app language by [LanguageProvider]. Widgets should
/// use `context.l10n` instead, which also rebuilds them when the language
/// changes.
class L10n {
  L10n._();

  static AppLocalizations _current = AppLocalizationsEn();

  static AppLocalizations get current => _current;

  static set current(AppLocalizations value) => _current = value;
}

extension AppLocalizationsContext on BuildContext {
  /// The strings for the language this part of the tree is shown in.
  ///
  /// Falls back to [L10n.current] where no [AppLocalizations] is in scope -
  /// widget tests that pump a page without the app's delegates - so those
  /// keep seeing English rather than crashing.
  AppLocalizations get l10n => AppLocalizations.of(this) ?? L10n.current;
}
