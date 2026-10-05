import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Shia Companion'**
  String get appTitle;

  /// Settings row for the language menus and buttons are shown in.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsAppLanguage;

  /// Settings row for the language a zikr's translation, instructions and title are shown in.
  ///
  /// In en, this message translates to:
  /// **'Translation language'**
  String get settingsTranslationLanguage;

  /// Default app-language option: follow the phone's language. {language} is the language that currently resolves to, in its own script.
  ///
  /// In en, this message translates to:
  /// **'Device language ({language})'**
  String languageFollowDevice(String language);

  /// Default translation-language option: follow the app language. {language} is the language that currently resolves to, in its own script.
  ///
  /// In en, this message translates to:
  /// **'Same as app ({language})'**
  String languageFollowApp(String language);

  /// No description provided for @settingsDownloadedRecitationsUsed.
  ///
  /// In en, this message translates to:
  /// **'{size} used on this device'**
  String settingsDownloadedRecitationsUsed(String size);

  /// No description provided for @settingsHijriAhead.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day ahead} other{{days} days ahead}}'**
  String settingsHijriAhead(int days);

  /// No description provided for @settingsHijriBehind.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day behind} other{{days} days behind}}'**
  String settingsHijriBehind(int days);

  /// {message} explains why the location refresh failed.
  ///
  /// In en, this message translates to:
  /// **'{message}. Tap to try again.'**
  String settingsLocationFailed(String message);

  /// No description provided for @settingsLocationSaved.
  ///
  /// In en, this message translates to:
  /// **'Current saved location: {city}.'**
  String settingsLocationSaved(String city);

  /// {age} is a relative time such as 'just now' or '5m ago'.
  ///
  /// In en, this message translates to:
  /// **'{city} · updated {age}. Refreshes on its own as you move.'**
  String settingsLocationUpdated(String city, String age);

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeHoursAgo(int hours);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String timeDaysAgo(int days);

  /// No description provided for @settingsAdjustHijriBy.
  ///
  /// In en, this message translates to:
  /// **'Adjust Hijri Date by {days} days'**
  String settingsAdjustHijriBy(int days);

  /// {names} is a comma-separated list of prayer names.
  ///
  /// In en, this message translates to:
  /// **'Shown on the home page and home screen widgets: {names}.'**
  String settingsPrayerTimesShownSubtitle(String names);

  /// No description provided for @settingsPrayerNotificationsAllOn.
  ///
  /// In en, this message translates to:
  /// **'On for all {count} times.'**
  String settingsPrayerNotificationsAllOn(int count);

  /// No description provided for @settingsPrayerNotificationsSomeOn.
  ///
  /// In en, this message translates to:
  /// **'{names} · {enabled} of {total} on'**
  String settingsPrayerNotificationsSomeOn(
      String names, int enabled, int total);

  /// No description provided for @settingsSectionPrayerLocation.
  ///
  /// In en, this message translates to:
  /// **'Prayer & Location'**
  String get settingsSectionPrayerLocation;

  /// No description provided for @settingsAdjustHijriDate.
  ///
  /// In en, this message translates to:
  /// **'Adjust Hijri Date'**
  String get settingsAdjustHijriDate;

  /// No description provided for @settingsPrayerTimesShown.
  ///
  /// In en, this message translates to:
  /// **'Prayer Times Shown'**
  String get settingsPrayerTimesShown;

  /// No description provided for @settingsRefreshLocation.
  ///
  /// In en, this message translates to:
  /// **'Refresh Location'**
  String get settingsRefreshLocation;

  /// No description provided for @settingsLocationRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Location has been refreshed.'**
  String get settingsLocationRefreshed;

  /// No description provided for @settingsSectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsSectionNotifications;

  /// No description provided for @settingsPrayerNotifications.
  ///
  /// In en, this message translates to:
  /// **'Prayer notifications'**
  String get settingsPrayerNotifications;

  /// No description provided for @settingsZikrReminders.
  ///
  /// In en, this message translates to:
  /// **'Zikr Reminders'**
  String get settingsZikrReminders;

  /// No description provided for @settingsZikrRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get reminded about a zikr on the days you choose.'**
  String get settingsZikrRemindersSubtitle;

  /// No description provided for @settingsPrecisePrayerAlarms.
  ///
  /// In en, this message translates to:
  /// **'Precise Prayer Alarms'**
  String get settingsPrecisePrayerAlarms;

  /// No description provided for @settingsScheduledNotifications.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Notifications'**
  String get settingsScheduledNotifications;

  /// No description provided for @settingsScheduledNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review pending prayer notifications.'**
  String get settingsScheduledNotificationsSubtitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsDarkModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the dark appearance across the app.'**
  String get settingsDarkModeSubtitle;

  /// No description provided for @settingsAppTextSize.
  ///
  /// In en, this message translates to:
  /// **'App text size'**
  String get settingsAppTextSize;

  /// No description provided for @settingsAppTextSizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Makes all text bigger or smaller, including zikr.'**
  String get settingsAppTextSizeSubtitle;

  /// No description provided for @settingsSectionZikrReading.
  ///
  /// In en, this message translates to:
  /// **'Zikr Reading & Sharing'**
  String get settingsSectionZikrReading;

  /// No description provided for @settingsSectionOfflineAudio.
  ///
  /// In en, this message translates to:
  /// **'Offline Audio'**
  String get settingsSectionOfflineAudio;

  /// No description provided for @settingsDownloadedRecitations.
  ///
  /// In en, this message translates to:
  /// **'Downloaded recitations'**
  String get settingsDownloadedRecitations;

  /// No description provided for @settingsDownloadedRecitationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Listen without a connection'**
  String get settingsDownloadedRecitationsEmpty;

  /// No description provided for @settingsSectionSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSectionSupport;

  /// No description provided for @settingsRateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate Shia Companion'**
  String get settingsRateApp;

  /// No description provided for @settingsRateAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enjoying the app? Leave us a rating.'**
  String get settingsRateAppSubtitle;

  /// No description provided for @settingsRequestContent.
  ///
  /// In en, this message translates to:
  /// **'Request a Zikr or Book'**
  String get settingsRequestContent;

  /// No description provided for @settingsRequestContentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find a dua, ziyarat or book? Ask us to add it.'**
  String get settingsRequestContentSubtitle;

  /// No description provided for @settingsFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get settingsFeedback;

  /// No description provided for @settingsFeedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send questions, issues, or suggestions.'**
  String get settingsFeedbackSubtitle;

  /// No description provided for @settingsGithub.
  ///
  /// In en, this message translates to:
  /// **'Contribute on GitHub'**
  String get settingsGithub;

  /// No description provided for @settingsGithubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shia Companion is open source. Report issues or help improve it.'**
  String get settingsGithubSubtitle;

  /// No description provided for @settingsGithubOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open GitHub'**
  String get settingsGithubOpenFailed;

  /// No description provided for @settingsAboutUs.
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get settingsAboutUs;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get settingsNotSignedIn;

  /// No description provided for @settingsSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync favorites across devices.'**
  String get settingsSignInPrompt;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out on this device.'**
  String get settingsLogoutSubtitle;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete My Account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove your account data.'**
  String get settingsDeleteAccountSubtitle;

  /// No description provided for @settingsSignInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get settingsSignInGoogle;

  /// No description provided for @settingsSignInGoogleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync favorites and account data.'**
  String get settingsSignInGoogleSubtitle;

  /// No description provided for @settingsSignInApple.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get settingsSignInApple;

  /// No description provided for @settingsSignInAppleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your Apple ID to sign in.'**
  String get settingsSignInAppleSubtitle;

  /// No description provided for @settingsSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get settingsSignedIn;

  /// No description provided for @settingsSyncing.
  ///
  /// In en, this message translates to:
  /// **'Favorites and account data are syncing.'**
  String get settingsSyncing;

  /// No description provided for @settingsHijriNoAdjustment.
  ///
  /// In en, this message translates to:
  /// **'No adjustment'**
  String get settingsHijriNoAdjustment;

  /// No description provided for @settingsLocationUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating your location…'**
  String get settingsLocationUpdating;

  /// No description provided for @settingsLocationUpdatePrompt.
  ///
  /// In en, this message translates to:
  /// **'Update the saved prayer-times location.'**
  String get settingsLocationUpdatePrompt;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @settingsPrayerNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Off. Turn on to be notified at prayer times.'**
  String get settingsPrayerNotificationsOff;

  /// No description provided for @settingsPreciseAlarmsOn.
  ///
  /// In en, this message translates to:
  /// **'Enabled for exact Azan timing.'**
  String get settingsPreciseAlarmsOn;

  /// No description provided for @settingsPreciseAlarmsOff.
  ///
  /// In en, this message translates to:
  /// **'Off. Android may deliver prayer notifications a bit late.'**
  String get settingsPreciseAlarmsOff;

  /// No description provided for @settingsNotificationsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Notification system not initialized'**
  String get settingsNotificationsUnavailable;

  /// No description provided for @settingsPreciseAlarmsAlreadyOn.
  ///
  /// In en, this message translates to:
  /// **'Precise prayer alarms are already enabled.'**
  String get settingsPreciseAlarmsAlreadyOn;

  /// No description provided for @settingsPreciseAlarmsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Precise Prayer Alarms?'**
  String get settingsPreciseAlarmsDialogTitle;

  /// No description provided for @settingsPreciseAlarmsDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Android requires Alarms & reminders access for Azan notifications to fire exactly at prayer time. Without it, reminders still work but may arrive a bit late.'**
  String get settingsPreciseAlarmsDialogBody;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get commonOpenSettings;

  /// No description provided for @settingsPreciseAlarmsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Precise prayer alarms enabled.'**
  String get settingsPreciseAlarmsEnabled;

  /// No description provided for @settingsPreciseAlarmsNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Precise prayer alarms were not enabled. Approximate timing will still be used.'**
  String get settingsPreciseAlarmsNotEnabled;

  /// No description provided for @settingsNoEmailApp.
  ///
  /// In en, this message translates to:
  /// **'No email app found'**
  String get settingsNoEmailApp;

  /// No description provided for @settingsLoginSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Login Successful'**
  String get settingsLoginSuccessful;

  /// No description provided for @settingsGoogleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In isn\'t available right now. Please try again.'**
  String get settingsGoogleUnavailable;

  /// No description provided for @commonNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect. Check your internet connection and try again.'**
  String get commonNetworkError;

  /// No description provided for @settingsGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In didn\'t work. Please try again in a moment.'**
  String get settingsGoogleFailed;

  /// No description provided for @settingsAppleFailed.
  ///
  /// In en, this message translates to:
  /// **'Apple Sign-In Failed'**
  String get settingsAppleFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
