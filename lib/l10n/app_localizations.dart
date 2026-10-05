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

  /// No description provided for @audioRecordingNumber.
  ///
  /// In en, this message translates to:
  /// **'Recording {number}'**
  String audioRecordingNumber(int number);

  /// No description provided for @playlistAddedTo.
  ///
  /// In en, this message translates to:
  /// **'Added to {name}'**
  String playlistAddedTo(String name);

  /// No description provided for @playlistAlreadyIn.
  ///
  /// In en, this message translates to:
  /// **'Already in {name}'**
  String playlistAlreadyIn(String name);

  /// A number of zikr. 'Zikr' is its own plural in English.
  ///
  /// In en, this message translates to:
  /// **'{count} zikr'**
  String zikrCount(int count);

  /// No description provided for @playlistsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Make a playlist of the zikr you listen to every day - Dua Ahad and Ziyarat Ashura each morning, say - and start them all with one tap.'**
  String get playlistsEmpty;

  /// No description provided for @playlistDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String playlistDeleteConfirm(String name);

  /// No description provided for @playlistDeleteKeepsDuasAndAudio.
  ///
  /// In en, this message translates to:
  /// **'The duas themselves stay in the app, and so does their downloaded audio - remove it from Downloads to free space.'**
  String get playlistDeleteKeepsDuasAndAudio;

  /// No description provided for @playlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap Add to choose zikr. You can also add one from the player on any dua with audio.'**
  String get playlistEmpty;

  /// No description provided for @audioRecordingsChosen.
  ///
  /// In en, this message translates to:
  /// **'{chosen} of {total} recordings'**
  String audioRecordingsChosen(int chosen, int total);

  /// No description provided for @audioDownloadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String audioDownloadingPercent(int percent);

  /// No description provided for @audioRecordingsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recording} other{{count} recordings}}'**
  String audioRecordingsCount(int count);

  /// No description provided for @playlistNowPlayingPosition.
  ///
  /// In en, this message translates to:
  /// **'{playlist} · {position} of {count}'**
  String playlistNowPlayingPosition(String playlist, int position, int count);

  /// No description provided for @playlistNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Morning'**
  String get playlistNameHint;

  /// No description provided for @playlistOfflinePartial.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline - playing only the downloaded recordings'**
  String get playlistOfflinePartial;

  /// No description provided for @playlistNothingToPlay.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this playlist has a recording to play'**
  String get playlistNothingToPlay;

  /// No description provided for @playlistOfflineNothingDownloaded.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline and nothing in this playlist is downloaded yet'**
  String get playlistOfflineNothingDownloaded;

  /// No description provided for @playlistStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the playlist. Try again.'**
  String get playlistStartFailed;

  /// No description provided for @playlistChooseRecordingsHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the recordings to play in this playlist'**
  String get playlistChooseRecordingsHint;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @playlistAddTo.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get playlistAddTo;

  /// No description provided for @playlistNew.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get playlistNew;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @playlistsTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlistsTitle;

  /// No description provided for @playlistDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get playlistDownloads;

  /// No description provided for @commonPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get commonPause;

  /// No description provided for @commonPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get commonPlay;

  /// No description provided for @playlistRename.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get playlistRename;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @playlistDeleteKeepsDuas.
  ///
  /// In en, this message translates to:
  /// **'The duas themselves stay in the app.'**
  String get playlistDeleteKeepsDuas;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @playlistDeleted.
  ///
  /// In en, this message translates to:
  /// **'This playlist has been deleted.'**
  String get playlistDeleted;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @playlistRemoveDownloads.
  ///
  /// In en, this message translates to:
  /// **'Remove downloads'**
  String get playlistRemoveDownloads;

  /// No description provided for @playlistAllDownloads.
  ///
  /// In en, this message translates to:
  /// **'All downloads'**
  String get playlistAllDownloads;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @playlistResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get playlistResume;

  /// No description provided for @playlistPlayAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get playlistPlayAll;

  /// No description provided for @audioDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get audioDownloaded;

  /// No description provided for @audioDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download didn\'t finish'**
  String get audioDownloadFailed;

  /// No description provided for @playlistOpenText.
  ///
  /// In en, this message translates to:
  /// **'Open text'**
  String get playlistOpenText;

  /// No description provided for @playlistChooseRecordings.
  ///
  /// In en, this message translates to:
  /// **'Choose recordings'**
  String get playlistChooseRecordings;

  /// No description provided for @audioStopDownloading.
  ///
  /// In en, this message translates to:
  /// **'Stop downloading'**
  String get audioStopDownloading;

  /// No description provided for @audioRemoveDownload.
  ///
  /// In en, this message translates to:
  /// **'Remove download'**
  String get audioRemoveDownload;

  /// No description provided for @audioDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get audioDownload;

  /// No description provided for @playlistRemoveZikr.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get playlistRemoveZikr;

  /// No description provided for @playlistAddZikr.
  ///
  /// In en, this message translates to:
  /// **'Add zikr'**
  String get playlistAddZikr;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @audioPartlyDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Partly downloaded'**
  String get audioPartlyDownloaded;

  /// No description provided for @playlistRepeatOn.
  ///
  /// In en, this message translates to:
  /// **'Repeat is on'**
  String get playlistRepeatOn;

  /// No description provided for @playlistRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat playlist'**
  String get playlistRepeat;

  /// No description provided for @commonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get commonPrevious;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get commonStop;

  /// {origin} and {destination} are airport codes.
  ///
  /// In en, this message translates to:
  /// **'Times shown at {origin} and {destination} local clocks'**
  String flightTimesShownAt(String origin, String destination);

  /// No description provided for @flightDurationAndDistance.
  ///
  /// In en, this message translates to:
  /// **'{duration} in the air · {distance} great-circle'**
  String flightDurationAndDistance(String duration, String distance);

  /// Column heading: local time at an airport (airport code).
  ///
  /// In en, this message translates to:
  /// **'{airport} time'**
  String flightAirportTime(String airport);

  /// No description provided for @flightOverPosition.
  ///
  /// In en, this message translates to:
  /// **' · over {position}'**
  String flightOverPosition(String position);

  /// No description provided for @flightAfterTakeoff.
  ///
  /// In en, this message translates to:
  /// **'{duration} after take-off'**
  String flightAfterTakeoff(String duration);

  /// No description provided for @flightHorizonLater.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min later than the horizon of the ground below'**
  String flightHorizonLater(int minutes);

  /// No description provided for @flightHorizonEarlier.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min earlier than the horizon of the ground below'**
  String flightHorizonEarlier(int minutes);

  /// No description provided for @flightQiblaToRight.
  ///
  /// In en, this message translates to:
  /// **'{degrees}° to your right'**
  String flightQiblaToRight(int degrees);

  /// No description provided for @flightQiblaToLeft.
  ///
  /// In en, this message translates to:
  /// **'{degrees}° to your left'**
  String flightQiblaToLeft(int degrees);

  /// No description provided for @flightQiblaLine.
  ///
  /// In en, this message translates to:
  /// **'Qibla {bearing}° ({compass}) — {relative} relative to the direction of flight'**
  String flightQiblaLine(int bearing, String compass, String relative);

  /// No description provided for @flightAltitudeHorizonBody.
  ///
  /// In en, this message translates to:
  /// **'At {altitude} the horizon sits about {dip}° lower than on the ground, so the sun takes longer to set and dawn comes sooner. That moves Maghrib and Isha about twenty minutes later, and Fajr about twenty minutes earlier, than the times for the ground beneath you — each row shows its own shift. Which horizon governs the prayer is a question for your marja, not one this app can settle.'**
  String flightAltitudeHorizonBody(String altitude, String dip);

  /// An altitude, e.g. 38,000 ft.
  ///
  /// In en, this message translates to:
  /// **'{feet} ft'**
  String flightAltitudeFeet(String feet);

  /// No description provided for @flightTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get flightTitleFallback;

  /// No description provided for @flightEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit flight'**
  String get flightEdit;

  /// No description provided for @flightCheckTimes.
  ///
  /// In en, this message translates to:
  /// **'Check the flight times'**
  String get flightCheckTimes;

  /// No description provided for @flightCheckTimesBody.
  ///
  /// In en, this message translates to:
  /// **'The arrival is not after the departure once each airport\'s time zone is applied. Tap edit to fix the dates.'**
  String get flightCheckTimesBody;

  /// No description provided for @flightInTheAir.
  ///
  /// In en, this message translates to:
  /// **'In the air'**
  String get flightInTheAir;

  /// No description provided for @flightNoPrayerDuring.
  ///
  /// In en, this message translates to:
  /// **'No prayer comes in during this flight'**
  String get flightNoPrayerDuring;

  /// No description provided for @flightNoPrayerDuringBody.
  ///
  /// In en, this message translates to:
  /// **'Every prayer time falls either before take-off or after landing.'**
  String get flightNoPrayerDuringBody;

  /// No description provided for @flightNotDuring.
  ///
  /// In en, this message translates to:
  /// **'Not during this flight'**
  String get flightNotDuring;

  /// No description provided for @flightEndOfIshaWindow.
  ///
  /// In en, this message translates to:
  /// **'End of the Isha window · '**
  String get flightEndOfIshaWindow;

  /// No description provided for @flightStraightAhead.
  ///
  /// In en, this message translates to:
  /// **'straight ahead'**
  String get flightStraightAhead;

  /// No description provided for @flightDirectlyBehind.
  ///
  /// In en, this message translates to:
  /// **'directly behind you'**
  String get flightDirectlyBehind;

  /// No description provided for @flightIshaClosedBeforeTakeoff.
  ///
  /// In en, this message translates to:
  /// **'The Isha window had already closed before take-off.'**
  String get flightIshaClosedBeforeTakeoff;

  /// No description provided for @flightAlreadyInBeforeTakeoff.
  ///
  /// In en, this message translates to:
  /// **'Already in before take-off — use the prayer times for your departure city.'**
  String get flightAlreadyInBeforeTakeoff;

  /// No description provided for @flightIshaOpenUntilLanding.
  ///
  /// In en, this message translates to:
  /// **'The Isha window does not close until after landing.'**
  String get flightIshaOpenUntilLanding;

  /// No description provided for @flightAfterLanding.
  ///
  /// In en, this message translates to:
  /// **'Comes in after landing — use the prayer times for your destination.'**
  String get flightAfterLanding;

  /// No description provided for @flightSunAngleNeverReached.
  ///
  /// In en, this message translates to:
  /// **'The sun never reaches the required angle anywhere along this route, so no time can be calculated.'**
  String get flightSunAngleNeverReached;

  /// No description provided for @flightHowWorkedOut.
  ///
  /// In en, this message translates to:
  /// **'How these are worked out'**
  String get flightHowWorkedOut;

  /// No description provided for @flightHowWorkedOutBody.
  ///
  /// In en, this message translates to:
  /// **'The aircraft is assumed to follow the great-circle route at a steady speed, and each prayer time is solved for the position the aircraft is at when that time arrives. A delay of an hour moves these times by roughly half an hour, and routing around weather can move them by ten to twenty minutes, so treat them as close rather than exact.'**
  String get flightHowWorkedOutBody;

  /// No description provided for @flightHorizonAtAltitude.
  ///
  /// In en, this message translates to:
  /// **'Measured from the horizon at altitude'**
  String get flightHorizonAtAltitude;

  /// No description provided for @flightHorizonAtGround.
  ///
  /// In en, this message translates to:
  /// **'Measured from the horizon at ground level'**
  String get flightHorizonAtGround;

  /// No description provided for @flightGroundHorizonBody.
  ///
  /// In en, this message translates to:
  /// **'Times follow the horizon of the ground below the aircraft. From the cabin the sun sets later and dawn breaks earlier than shown, by around twenty minutes at cruise altitude.'**
  String get flightGroundHorizonBody;

  /// No description provided for @flightHighLatitude.
  ///
  /// In en, this message translates to:
  /// **'This route crosses high latitudes'**
  String get flightHighLatitude;

  /// No description provided for @flightHighLatitudeBody.
  ///
  /// In en, this message translates to:
  /// **'Above roughly 48°, the sun may not dip far enough below the horizon for dawn and nightfall to happen normally. Times for Fajr, Maghrib and Isha there fall back to a proportional estimate of the night. Rulings for prayer at high latitude differ — please follow your marja.'**
  String get flightHighLatitudeBody;

  /// No description provided for @flightSomeNotCalculated.
  ///
  /// In en, this message translates to:
  /// **'Some prayer times could not be calculated'**
  String get flightSomeNotCalculated;

  /// No description provided for @flightSomeNotCalculatedBody.
  ///
  /// In en, this message translates to:
  /// **'The sun stays above the required angle for the whole route, so those prayers have no calculated time. Please follow your marja\'s ruling for these conditions.'**
  String get flightSomeNotCalculatedBody;

  /// No description provided for @flightTimeZonesFailed.
  ///
  /// In en, this message translates to:
  /// **'Time zones could not be loaded'**
  String get flightTimeZonesFailed;

  /// No description provided for @flightTimeZonesFailedBody.
  ///
  /// In en, this message translates to:
  /// **'One of these airports has a time zone this build does not recognise. Tap edit to pick the airports again.'**
  String get flightTimeZonesFailedBody;

  /// No description provided for @prayerFajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayerFajr;

  /// No description provided for @prayerSunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get prayerSunrise;

  /// No description provided for @prayerZuhr.
  ///
  /// In en, this message translates to:
  /// **'Zuhr'**
  String get prayerZuhr;

  /// No description provided for @prayerAsr.
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayerAsr;

  /// No description provided for @prayerSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get prayerSunset;

  /// No description provided for @prayerMaghrib.
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get prayerMaghrib;

  /// No description provided for @prayerIsha.
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get prayerIsha;

  /// Islamic midnight, the end of the Isha window.
  ///
  /// In en, this message translates to:
  /// **'Midnight'**
  String get prayerMidnight;

  /// No description provided for @locationErrorBody.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while getting your location: {error}\n\nPlease check that location services are enabled and try again.'**
  String locationErrorBody(String error);

  /// No description provided for @notificationReopenAppBody.
  ///
  /// In en, this message translates to:
  /// **'It seems you\'ve not used the application in last {days} days. Please open the app to continue receive Azan notifications'**
  String notificationReopenAppBody(int days);

  /// Prayer notification text. {prayer} is the prayer's name, lower-cased in English.
  ///
  /// In en, this message translates to:
  /// **'It\'s time for {prayer}'**
  String notificationPrayerTime(String prayer);

  /// {message} is the prayer notification text.
  ///
  /// In en, this message translates to:
  /// **'{message} · Tap to play your audio'**
  String notificationTapToPlayCustom(String message);

  /// {message} is the prayer notification text.
  ///
  /// In en, this message translates to:
  /// **'{message} · Tap to hear the full azan'**
  String notificationTapToPlayAzan(String message);

  /// No description provided for @locationEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Location for Prayer Times'**
  String get locationEnableTitle;

  /// No description provided for @locationEnableBody.
  ///
  /// In en, this message translates to:
  /// **'Prayer times are unique to your location. We use your location while you are using the app so we can provide accurate prayer times for your area.'**
  String get locationEnableBody;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @locationServicesDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Location Services Disabled'**
  String get locationServicesDisabledTitle;

  /// No description provided for @locationServicesDisabledBody.
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off. Please enable location services in your device settings to get accurate prayer times for your area.'**
  String get locationServicesDisabledBody;

  /// No description provided for @locationPermissionDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission was permanently denied. Please open app settings and grant location permission to get accurate prayer times.'**
  String get locationPermissionDeniedForever;

  /// No description provided for @locationPermissionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unable to determine location permission status. Please open app settings and ensure location permission is granted.'**
  String get locationPermissionUnknown;

  /// No description provided for @locationPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to show accurate prayer times for your area.'**
  String get locationPermissionNeeded;

  /// No description provided for @locationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Location Permission Required'**
  String get locationPermissionTitle;

  /// No description provided for @locationTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Location Timeout'**
  String get locationTimeoutTitle;

  /// No description provided for @locationTimeoutBody.
  ///
  /// In en, this message translates to:
  /// **'Unable to get your location within the expected time. This may be due to poor GPS signal or network issues. Please try again.'**
  String get locationTimeoutBody;

  /// No description provided for @locationErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Location Error'**
  String get locationErrorTitle;

  /// No description provided for @notificationReopenAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Open the app to continue getting Azan notifications'**
  String get notificationReopenAppTitle;

  /// No description provided for @notificationChannelTakbir.
  ///
  /// In en, this message translates to:
  /// **'Prayer Times - Takbir'**
  String get notificationChannelTakbir;

  /// No description provided for @notificationChannelSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'Prayer Times - System Default'**
  String get notificationChannelSystemDefault;

  /// No description provided for @notificationChannelSilent.
  ///
  /// In en, this message translates to:
  /// **'Prayer Times - Silent'**
  String get notificationChannelSilent;

  /// No description provided for @notificationChannelCustom.
  ///
  /// In en, this message translates to:
  /// **'Prayer Times - Custom Sound'**
  String get notificationChannelCustom;

  /// No description provided for @notificationChannelFullAzan.
  ///
  /// In en, this message translates to:
  /// **'Prayer Times - Full Azan'**
  String get notificationChannelFullAzan;

  /// No description provided for @notificationChannelSilentDescription.
  ///
  /// In en, this message translates to:
  /// **'Silent prayer time notifications'**
  String get notificationChannelSilentDescription;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Prayer time notifications'**
  String get notificationChannelDescription;

  /// No description provided for @notificationChannelGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get notificationChannelGeneral;

  /// No description provided for @qiblaNeedsCalibratingBody.
  ///
  /// In en, this message translates to:
  /// **'Readings are off by around {degrees}°. Move the phone in a figure of eight a few times, away from anything metal or magnetic.'**
  String qiblaNeedsCalibratingBody(int degrees);

  /// {bearing} is a compass bearing such as '293° NW'.
  ///
  /// In en, this message translates to:
  /// **'{place} is {bearing} of true north'**
  String qiblaBearingFromNorth(String place, String bearing);

  /// No description provided for @qiblaFacing.
  ///
  /// In en, this message translates to:
  /// **'Facing {place}'**
  String qiblaFacing(String place);

  /// No description provided for @qiblaTurnRight.
  ///
  /// In en, this message translates to:
  /// **'Turn right {degrees}°'**
  String qiblaTurnRight(int degrees);

  /// No description provided for @qiblaTurnLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn left {degrees}°'**
  String qiblaTurnLeft(int degrees);

  /// No description provided for @qiblaDeclinationEast.
  ///
  /// In en, this message translates to:
  /// **'Magnetic north is {degrees}° east of true north where you are, and the reading is corrected for it automatically.'**
  String qiblaDeclinationEast(String degrees);

  /// No description provided for @qiblaDeclinationWest.
  ///
  /// In en, this message translates to:
  /// **'Magnetic north is {degrees}° west of true north where you are, and the reading is corrected for it automatically.'**
  String qiblaDeclinationWest(String degrees);

  /// Distance shown when you are already at the place.
  ///
  /// In en, this message translates to:
  /// **'Here'**
  String get qiblaDistanceHere;

  /// No description provided for @qiblaTitle.
  ///
  /// In en, this message translates to:
  /// **'Qibla Finder'**
  String get qiblaTitle;

  /// No description provided for @qiblaAboutCompass.
  ///
  /// In en, this message translates to:
  /// **'About this compass'**
  String get qiblaAboutCompass;

  /// No description provided for @qiblaLocationNeeded.
  ///
  /// In en, this message translates to:
  /// **'Location needed'**
  String get qiblaLocationNeeded;

  /// No description provided for @qiblaLocationNeededBody.
  ///
  /// In en, this message translates to:
  /// **'The direction depends on where you are. Share your location and the compass will point the moment a fix arrives.'**
  String get qiblaLocationNeededBody;

  /// No description provided for @qiblaUseMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get qiblaUseMyLocation;

  /// No description provided for @qiblaTurnOnCompass.
  ///
  /// In en, this message translates to:
  /// **'Turn on the compass'**
  String get qiblaTurnOnCompass;

  /// No description provided for @qiblaTurnOnCompassBody.
  ///
  /// In en, this message translates to:
  /// **'This browser needs your permission before it will report which way the phone is facing.'**
  String get qiblaTurnOnCompassBody;

  /// No description provided for @qiblaAllowCompass.
  ///
  /// In en, this message translates to:
  /// **'Allow compass'**
  String get qiblaAllowCompass;

  /// No description provided for @qiblaCompassBlocked.
  ///
  /// In en, this message translates to:
  /// **'Compass blocked'**
  String get qiblaCompassBlocked;

  /// No description provided for @qiblaCompassBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Motion and orientation access was declined, so the dial is held north-up. Allow it in your browser settings, or turn until north on the dial matches north around you.'**
  String get qiblaCompassBlockedBody;

  /// No description provided for @qiblaNoCompass.
  ///
  /// In en, this message translates to:
  /// **'No compass on this device'**
  String get qiblaNoCompass;

  /// No description provided for @qiblaNoCompassBody.
  ///
  /// In en, this message translates to:
  /// **'The dial is held north-up instead. Face north, and the needle shows the direction from there.'**
  String get qiblaNoCompassBody;

  /// No description provided for @qiblaNeedsCalibrating.
  ///
  /// In en, this message translates to:
  /// **'Compass needs calibrating'**
  String get qiblaNeedsCalibrating;

  /// No description provided for @qiblaLocationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Location unknown'**
  String get qiblaLocationUnknown;

  /// No description provided for @qiblaUpdateLocation.
  ///
  /// In en, this message translates to:
  /// **'Update location'**
  String get qiblaUpdateLocation;

  /// No description provided for @qiblaPointingTowards.
  ///
  /// In en, this message translates to:
  /// **'Pointing towards'**
  String get qiblaPointingTowards;

  /// No description provided for @qiblaWaitingForLocation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your location'**
  String get qiblaWaitingForLocation;

  /// No description provided for @qiblaPointTowards.
  ///
  /// In en, this message translates to:
  /// **'Point towards'**
  String get qiblaPointTowards;

  /// No description provided for @qiblaGreatCircleBody.
  ///
  /// In en, this message translates to:
  /// **'The needle points along the great-circle path — the shortest way over the surface of the earth, which is the direction the qibla is defined by. On a flat map it can look surprising; from North America the Kaaba is roughly north-east, not south-east.'**
  String get qiblaGreatCircleBody;

  /// No description provided for @qiblaDeclinationUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'Your phone measures the angle to magnetic north, which differs from true north by an amount that depends on where you are. That correction is applied automatically once your location is known.'**
  String get qiblaDeclinationUnknownBody;

  /// No description provided for @qiblaSteadyReadingBody.
  ///
  /// In en, this message translates to:
  /// **'For a steady reading, hold the phone flat and keep it away from laptops, speakers, car dashboards and anything else with a magnet in it.'**
  String get qiblaSteadyReadingBody;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @weekdayShortMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayShortMon;

  /// No description provided for @weekdayShortTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayShortTue;

  /// No description provided for @weekdayShortWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayShortWed;

  /// No description provided for @weekdayShortThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayShortThu;

  /// No description provided for @weekdayShortFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayShortFri;

  /// No description provided for @weekdayShortSat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdayShortSat;

  /// No description provided for @weekdayShortSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdayShortSun;

  /// No description provided for @reminderMinutesRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a number of minutes between 0 and {max}.'**
  String reminderMinutesRange(int max);

  /// No description provided for @reminderTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title for this reminder.'**
  String get reminderTitleRequired;

  /// No description provided for @reminderPickDay.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one day.'**
  String get reminderPickDay;

  /// No description provided for @reminderSavedPendingLocation.
  ///
  /// In en, this message translates to:
  /// **'Saved. It\'ll start firing once your prayer-time location is available.'**
  String get reminderSavedPendingLocation;

  /// No description provided for @reminderEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Reminder'**
  String get reminderEditTitle;

  /// No description provided for @reminderNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Reminder'**
  String get reminderNewTitle;

  /// No description provided for @reminderWhat.
  ///
  /// In en, this message translates to:
  /// **'What'**
  String get reminderWhat;

  /// No description provided for @reminderWhatHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a zikr from the library, or just type a title below.'**
  String get reminderWhatHint;

  /// No description provided for @reminderChooseZikr.
  ///
  /// In en, this message translates to:
  /// **'Choose from the zikr library'**
  String get reminderChooseZikr;

  /// No description provided for @reminderChangeZikr.
  ///
  /// In en, this message translates to:
  /// **'Change zikr'**
  String get reminderChangeZikr;

  /// No description provided for @reminderTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get reminderTitleLabel;

  /// No description provided for @reminderTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Dua Tawassul'**
  String get reminderTitleHint;

  /// No description provided for @reminderRepeatOn.
  ///
  /// In en, this message translates to:
  /// **'Repeat on'**
  String get reminderRepeatOn;

  /// No description provided for @reminderWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get reminderWhen;

  /// No description provided for @reminderFixedTime.
  ///
  /// In en, this message translates to:
  /// **'Fixed time'**
  String get reminderFixedTime;

  /// No description provided for @reminderPrayerRelative.
  ///
  /// In en, this message translates to:
  /// **'Prayer-relative'**
  String get reminderPrayerRelative;

  /// No description provided for @commonSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get commonSaveChanges;

  /// No description provided for @reminderAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Reminder'**
  String get reminderAdd;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get reminderTime;

  /// No description provided for @reminderPrayer.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get reminderPrayer;

  /// No description provided for @reminderMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get reminderMinutes;

  /// No description provided for @reminderBefore.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get reminderBefore;

  /// No description provided for @reminderAfter.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get reminderAfter;

  /// No description provided for @reminderPrayerRelativeNote.
  ///
  /// In en, this message translates to:
  /// **'Prayer times shift with the calendar, so this schedules the next few weeks\' occurrences and refreshes them each time you open the app.'**
  String get reminderPrayerRelativeNote;

  /// No description provided for @qazaCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} completed'**
  String qazaCompletedCount(int count);

  /// No description provided for @qazaPrayed.
  ///
  /// In en, this message translates to:
  /// **'Prayed'**
  String get qazaPrayed;

  /// No description provided for @qazaFasted.
  ///
  /// In en, this message translates to:
  /// **'Fasted'**
  String get qazaFasted;

  /// Both are formatted numbers.
  ///
  /// In en, this message translates to:
  /// **'{days} of each daily prayer ({prayers} prayers)'**
  String qazaEstimatePrayers(String days, String prayers);

  /// No description provided for @qazaEstimateFasts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{formatted} fast} other{{formatted} fasts}}'**
  String qazaEstimateFasts(int count, Object formatted);

  /// No description provided for @qazaLunarNote.
  ///
  /// In en, this message translates to:
  /// **'Counted as lunar years of {yearDays} days and months of {monthDays} days.'**
  String qazaLunarNote(int yearDays, int monthDays);

  /// No description provided for @qazaTitle.
  ///
  /// In en, this message translates to:
  /// **'Qaza Tracker'**
  String get qazaTitle;

  /// No description provided for @qazaCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate my qaza'**
  String get qazaCalculate;

  /// No description provided for @qazaPrayers.
  ///
  /// In en, this message translates to:
  /// **'Prayers'**
  String get qazaPrayers;

  /// No description provided for @qazaFasts.
  ///
  /// In en, this message translates to:
  /// **'Fasts'**
  String get qazaFasts;

  /// No description provided for @qazaRemaining.
  ///
  /// In en, this message translates to:
  /// **'Qaza remaining'**
  String get qazaRemaining;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @qazaMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get qazaMissed;

  /// No description provided for @qazaEditCount.
  ///
  /// In en, this message translates to:
  /// **'Edit count'**
  String get qazaEditCount;

  /// No description provided for @qazaMissedAWhile.
  ///
  /// In en, this message translates to:
  /// **'Missed prayers for a while?'**
  String get qazaMissedAWhile;

  /// No description provided for @qazaMissedAWhileBody.
  ///
  /// In en, this message translates to:
  /// **'Enter how long, and we will add one of each daily prayer for every day missed.'**
  String get qazaMissedAWhileBody;

  /// No description provided for @qazaPrayedFullDay.
  ///
  /// In en, this message translates to:
  /// **'Prayed a full day'**
  String get qazaPrayedFullDay;

  /// No description provided for @qazaLoggedFullDay.
  ///
  /// In en, this message translates to:
  /// **'Logged one of each daily prayer'**
  String get qazaLoggedFullDay;

  /// No description provided for @qazaAddedToList.
  ///
  /// In en, this message translates to:
  /// **'Added to your qaza list'**
  String get qazaAddedToList;

  /// No description provided for @qazaRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get qazaRemainingLabel;

  /// No description provided for @qazaCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get qazaCompletedLabel;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @qazaCalculateBody.
  ///
  /// In en, this message translates to:
  /// **'Roughly how long did you not pray? A best estimate is fine - you can adjust any prayer later.'**
  String get qazaCalculateBody;

  /// No description provided for @qazaPrayersMissedFor.
  ///
  /// In en, this message translates to:
  /// **'Prayers missed for'**
  String get qazaPrayersMissedFor;

  /// No description provided for @qazaYears.
  ///
  /// In en, this message translates to:
  /// **'Years'**
  String get qazaYears;

  /// No description provided for @qazaMonths.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get qazaMonths;

  /// No description provided for @qazaDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get qazaDays;

  /// No description provided for @qazaFastsMissed.
  ///
  /// In en, this message translates to:
  /// **'Fasts missed'**
  String get qazaFastsMissed;

  /// No description provided for @qazaNumberOfFasts.
  ///
  /// In en, this message translates to:
  /// **'Number of fasts'**
  String get qazaNumberOfFasts;

  /// No description provided for @qazaThisAdds.
  ///
  /// In en, this message translates to:
  /// **'This adds to your list:'**
  String get qazaThisAdds;

  /// No description provided for @qazaAddToList.
  ///
  /// In en, this message translates to:
  /// **'Add to my list'**
  String get qazaAddToList;

  /// No description provided for @qazaDhuhr.
  ///
  /// In en, this message translates to:
  /// **'Dhuhr'**
  String get qazaDhuhr;

  /// No description provided for @qazaAyat.
  ///
  /// In en, this message translates to:
  /// **'Namaz e Ayat'**
  String get qazaAyat;

  /// No description provided for @qazaOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get qazaOther;

  /// No description provided for @audioMobileDataSizedBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re not on Wi-Fi. This will use about {size} of mobile data.'**
  String audioMobileDataSizedBody(String size);

  /// No description provided for @audioRemoveDownloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove downloads?'**
  String get audioRemoveDownloadsTitle;

  /// No description provided for @audioRemoveDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove download?'**
  String get audioRemoveDownloadTitle;

  /// {subject} is 'This recitation', 'These recitations' or a quoted recitation name.
  ///
  /// In en, this message translates to:
  /// **'{subject} will stream again, so you\'ll need a connection to listen.'**
  String audioRemoveBody(String subject);

  /// No description provided for @audioTheseRecitations.
  ///
  /// In en, this message translates to:
  /// **'These recitations'**
  String get audioTheseRecitations;

  /// No description provided for @audioThisRecitation.
  ///
  /// In en, this message translates to:
  /// **'This recitation'**
  String get audioThisRecitation;

  /// No description provided for @audioQuotedName.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\"'**
  String audioQuotedName(String name);

  /// Appended to the remove-download message: the space it frees.
  ///
  /// In en, this message translates to:
  /// **'Frees {size}.'**
  String audioRemoveFrees(String size);

  /// No description provided for @audioDownloadDone.
  ///
  /// In en, this message translates to:
  /// **'Downloaded - plays without a connection'**
  String get audioDownloadDone;

  /// No description provided for @audioDownloadDoneNamed.
  ///
  /// In en, this message translates to:
  /// **'{name} downloaded - plays without a connection'**
  String audioDownloadDoneNamed(String name);

  /// No description provided for @audioTheseRecitationsLower.
  ///
  /// In en, this message translates to:
  /// **'these recitations'**
  String get audioTheseRecitationsLower;

  /// No description provided for @audioThisRecitationLower.
  ///
  /// In en, this message translates to:
  /// **'this recitation'**
  String get audioThisRecitationLower;

  /// No description provided for @audioDownloadPartial.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {saved} of {total}.'**
  String audioDownloadPartial(int saved, int total);

  /// {what} is a recitation name, or 'this recitation' / 'these recitations'.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download {what}.'**
  String audioDownloadFailedNamed(String what);

  /// No description provided for @audioDownloadOutOfSpace.
  ///
  /// In en, this message translates to:
  /// **'Your device is out of space - free some up and try again.'**
  String get audioDownloadOutOfSpace;

  /// No description provided for @audioDownloadUnavailable.
  ///
  /// In en, this message translates to:
  /// **'A recitation is no longer available.'**
  String get audioDownloadUnavailable;

  /// No description provided for @audioDownloadCheckConnection.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get audioDownloadCheckConnection;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String commonPercent(int percent);

  /// No description provided for @audioDownloadMore.
  ///
  /// In en, this message translates to:
  /// **'Download {count} more'**
  String audioDownloadMore(int count);

  /// No description provided for @audioDownloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download all'**
  String get audioDownloadAll;

  /// No description provided for @audioDownloadForOffline.
  ///
  /// In en, this message translates to:
  /// **'Download for offline listening'**
  String get audioDownloadForOffline;

  /// No description provided for @audioOfflineCannotDownload.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Connect to the internet to download.'**
  String get audioOfflineCannotDownload;

  /// No description provided for @audioMobileDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Download using mobile data?'**
  String get audioMobileDataTitle;

  /// No description provided for @audioMobileDataBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re not on Wi-Fi. Recitations can be large, so this may use a lot of mobile data.'**
  String get audioMobileDataBody;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @audioDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get audioDownloading;

  /// No description provided for @audioDownloadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get audioDownloadingEllipsis;

  /// No description provided for @audioDownloadedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Downloaded for offline listening. Tap to remove.'**
  String get audioDownloadedTooltip;

  /// No description provided for @audioRetryDownload.
  ///
  /// In en, this message translates to:
  /// **'Retry download'**
  String get audioRetryDownload;

  /// No description provided for @audioDownloadFailedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download didn\'t finish. Tap to retry.'**
  String get audioDownloadFailedTooltip;

  /// No description provided for @audioDownloadRestTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download the rest for offline listening'**
  String get audioDownloadRestTooltip;

  /// No description provided for @counterSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Current rakaat and sajdah'**
  String get counterSemanticsLabel;

  /// No description provided for @counterRakaatCompleted.
  ///
  /// In en, this message translates to:
  /// **'{count} rakaat completed'**
  String counterRakaatCompleted(int count);

  /// No description provided for @counterPosition.
  ///
  /// In en, this message translates to:
  /// **'Rakaat {rakaat}  ·  Sajdah {sajdah}'**
  String counterPosition(int rakaat, int sajdah);

  /// No description provided for @counterSajdahProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} sajdahs'**
  String counterSajdahProgress(int done, int total);

  /// No description provided for @counterSensorStopped.
  ///
  /// In en, this message translates to:
  /// **'The proximity sensor stopped responding. Check the phone position and turn automatic sensing on again.'**
  String get counterSensorStopped;

  /// No description provided for @counterStartOverTitle.
  ///
  /// In en, this message translates to:
  /// **'Start over?'**
  String get counterStartOverTitle;

  /// No description provided for @counterStartOverBody.
  ///
  /// In en, this message translates to:
  /// **'Changing the number of rakaat will reset the current prayer count.'**
  String get counterStartOverBody;

  /// No description provided for @counterStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get counterStartOver;

  /// No description provided for @counterTitle.
  ///
  /// In en, this message translates to:
  /// **'Rakaat Counter'**
  String get counterTitle;

  /// No description provided for @counterHowToPlace.
  ///
  /// In en, this message translates to:
  /// **'How to place your phone'**
  String get counterHowToPlace;

  /// No description provided for @counterPlaceBelowTurbah.
  ///
  /// In en, this message translates to:
  /// **'Place phone below the turbah'**
  String get counterPlaceBelowTurbah;

  /// No description provided for @counterPlaceBelowTurbahBody.
  ///
  /// In en, this message translates to:
  /// **'Lay it flat below the turbah, with the top edge pointing toward it. Keep your forehead’s path clear.'**
  String get counterPlaceBelowTurbahBody;

  /// No description provided for @counterPrayerLength.
  ///
  /// In en, this message translates to:
  /// **'Prayer length'**
  String get counterPrayerLength;

  /// No description provided for @counterSelectRakaat.
  ///
  /// In en, this message translates to:
  /// **'Select the number of rakaat'**
  String get counterSelectRakaat;

  /// No description provided for @counterComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get counterComplete;

  /// No description provided for @counterSajdahDetected.
  ///
  /// In en, this message translates to:
  /// **'Sajdah detected'**
  String get counterSajdahDetected;

  /// No description provided for @counterSensorReady.
  ///
  /// In en, this message translates to:
  /// **'Sensor ready'**
  String get counterSensorReady;

  /// No description provided for @counterCheckingSensor.
  ///
  /// In en, this message translates to:
  /// **'Checking sensor'**
  String get counterCheckingSensor;

  /// No description provided for @counterSensingOff.
  ///
  /// In en, this message translates to:
  /// **'Automatic sensing off'**
  String get counterSensingOff;

  /// No description provided for @counterTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap only if a sajdah was not detected automatically'**
  String get counterTapHint;

  /// No description provided for @counterReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for the first sajdah'**
  String get counterReady;

  /// No description provided for @counterAutomaticHint.
  ///
  /// In en, this message translates to:
  /// **'Automatic counting · tap only if one is missed'**
  String get counterAutomaticHint;

  /// No description provided for @counterManualHint.
  ///
  /// In en, this message translates to:
  /// **'Tap card to add a sajdah manually'**
  String get counterManualHint;

  /// No description provided for @counterCheckingDevice.
  ///
  /// In en, this message translates to:
  /// **'Checking this device…'**
  String get counterCheckingDevice;

  /// No description provided for @counterNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Automatic counting is not available on this device.'**
  String get counterNotAvailable;

  /// No description provided for @counterObjectDetected.
  ///
  /// In en, this message translates to:
  /// **'Object detected. Move away to arm the next count.'**
  String get counterObjectDetected;

  /// No description provided for @counterSensorArmed.
  ///
  /// In en, this message translates to:
  /// **'Ready — each detected sajdah counts once.'**
  String get counterSensorArmed;

  /// No description provided for @counterSensorOffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off — turn this on to count sajdahs automatically.'**
  String get counterSensorOffSubtitle;

  /// No description provided for @counterAutomaticSensing.
  ///
  /// In en, this message translates to:
  /// **'Automatic sensing'**
  String get counterAutomaticSensing;

  /// No description provided for @counterIphoneNote.
  ///
  /// In en, this message translates to:
  /// **'On iPhone, the display may turn off briefly while the sensor is covered. Sensor position and range vary by model.'**
  String get counterIphoneNote;

  /// No description provided for @counterAndroidNote.
  ///
  /// In en, this message translates to:
  /// **'Sensor position and range vary by phone. Some Android phones use a less reliable virtual proximity sensor.'**
  String get counterAndroidNote;

  /// No description provided for @counterPhonePlacement.
  ///
  /// In en, this message translates to:
  /// **'Phone placement'**
  String get counterPhonePlacement;

  /// No description provided for @counterPlacementBody.
  ///
  /// In en, this message translates to:
  /// **'Place the phone flat below the turbah, with its top edge and sensor pointing toward it. Keep the phone completely out of the path of your forehead.'**
  String get counterPlacementBody;

  /// No description provided for @counterPlacementTest.
  ///
  /// In en, this message translates to:
  /// **'Before beginning, enable the sensor and test it with your hand. Move your hand away after each test so the next count can arm.'**
  String get counterPlacementTest;

  /// No description provided for @quranJuzNumber.
  ///
  /// In en, this message translates to:
  /// **'Juz {number}'**
  String quranJuzNumber(int number);

  /// {verse} is a verse reference such as 2:255.
  ///
  /// In en, this message translates to:
  /// **'Copied {verse}'**
  String quranCopiedVerse(String verse);

  /// No description provided for @quranRemoveFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get quranRemoveFromSaved;

  /// No description provided for @quranSaveVerse.
  ///
  /// In en, this message translates to:
  /// **'Save verse'**
  String get quranSaveVerse;

  /// No description provided for @quranRemovedVerse.
  ///
  /// In en, this message translates to:
  /// **'Removed {verse}'**
  String quranRemovedVerse(String verse);

  /// No description provided for @quranSavedVerse.
  ///
  /// In en, this message translates to:
  /// **'Saved {verse}'**
  String quranSavedVerse(String verse);

  /// No description provided for @zikrPartNumber.
  ///
  /// In en, this message translates to:
  /// **'Part {number}'**
  String zikrPartNumber(int number);

  /// {icon} is replaced by a drag-handle icon; keep it where the icon belongs in the sentence.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked. To move it later, drag the {icon} on the \"Bookmarked\" label to another line.'**
  String zikrBookmarkMoveHint(String icon);

  /// No description provided for @quranCopyVerse.
  ///
  /// In en, this message translates to:
  /// **'Copy verse'**
  String get quranCopyVerse;

  /// No description provided for @quranCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get quranCopyLink;

  /// No description provided for @quranLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get quranLinkCopied;

  /// No description provided for @quranShareVerse.
  ///
  /// In en, this message translates to:
  /// **'Share verse'**
  String get quranShareVerse;

  /// No description provided for @zikrMerits.
  ///
  /// In en, this message translates to:
  /// **'Merits'**
  String get zikrMerits;

  /// No description provided for @zikrReportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks - we\'ll take a look.'**
  String get zikrReportThanks;

  /// No description provided for @zikrReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the report. Please try again.'**
  String get zikrReportFailed;

  /// No description provided for @zikrSuggestCorrection.
  ///
  /// In en, this message translates to:
  /// **'Suggest a Correction'**
  String get zikrSuggestCorrection;

  /// No description provided for @zikrSelectedText.
  ///
  /// In en, this message translates to:
  /// **'Selected text'**
  String get zikrSelectedText;

  /// No description provided for @zikrCorrectionHint.
  ///
  /// In en, this message translates to:
  /// **'What should it say instead? (optional)'**
  String get zikrCorrectionHint;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @zikrSetReminder.
  ///
  /// In en, this message translates to:
  /// **'Set Reminder'**
  String get zikrSetReminder;

  /// No description provided for @zikrUnableToOpen.
  ///
  /// In en, this message translates to:
  /// **'Unable to open this dua.'**
  String get zikrUnableToOpen;

  /// No description provided for @zikrComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon...'**
  String get zikrComingSoon;

  /// No description provided for @zikrHideCounter.
  ///
  /// In en, this message translates to:
  /// **'Hide counter'**
  String get zikrHideCounter;

  /// No description provided for @deleteAccountSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed: {error}'**
  String deleteAccountSignInFailed(String error);

  /// No description provided for @deleteAccountSignOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign out failed: {error}'**
  String deleteAccountSignOutFailed(String error);

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Error deleting account: {error}'**
  String deleteAccountFailed(String error);

  /// No description provided for @deleteAccountSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'You are signed in as {account}.'**
  String deleteAccountSignedInAs(String account);

  /// No description provided for @deleteAccountSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in successfully.'**
  String get deleteAccountSignedIn;

  /// No description provided for @deleteAccountSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out.'**
  String get deleteAccountSignedOut;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your Shia Companion account and synced favorites.'**
  String get deleteAccountConfirmBody;

  /// No description provided for @deleteAccountDone.
  ///
  /// In en, this message translates to:
  /// **'Account deleted successfully.'**
  String get deleteAccountDone;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountHeading.
  ///
  /// In en, this message translates to:
  /// **'Manage your Shia Companion account'**
  String get deleteAccountHeading;

  /// No description provided for @deleteAccountSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to review and permanently delete the account tied to your synced favorites.'**
  String get deleteAccountSignInPrompt;

  /// No description provided for @deleteAccountWhatGetsDeleted.
  ///
  /// In en, this message translates to:
  /// **'What gets deleted'**
  String get deleteAccountWhatGetsDeleted;

  /// No description provided for @deleteAccountItemSignIn.
  ///
  /// In en, this message translates to:
  /// **'Your Shia Companion account sign-in record.'**
  String get deleteAccountItemSignIn;

  /// No description provided for @deleteAccountItemFavorites.
  ///
  /// In en, this message translates to:
  /// **'Your synced favorites and qaza tracker stored for that account.'**
  String get deleteAccountItemFavorites;

  /// No description provided for @deleteAccountItemPreferences.
  ///
  /// In en, this message translates to:
  /// **'Your synced reading preferences — Hijri date adjustment and font choices.'**
  String get deleteAccountItemPreferences;

  /// No description provided for @deleteAccountItemAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Anonymous analytics or crash reports already collected may remain in aggregate form.'**
  String get deleteAccountItemAnalytics;

  /// No description provided for @deleteAccountCompleted.
  ///
  /// In en, this message translates to:
  /// **'Your account deletion request has completed.'**
  String get deleteAccountCompleted;

  /// No description provided for @deleteAccountCompletedNote.
  ///
  /// In en, this message translates to:
  /// **'If you sign in again later, a brand new account will be created.'**
  String get deleteAccountCompletedNote;

  /// No description provided for @deleteAccountWebSteps.
  ///
  /// In en, this message translates to:
  /// **'Use the Google sign-in button below, then confirm deletion.'**
  String get deleteAccountWebSteps;

  /// No description provided for @deleteAccountAppSteps.
  ///
  /// In en, this message translates to:
  /// **'Open Preferences in the app and use Delete My Account.'**
  String get deleteAccountAppSteps;

  /// No description provided for @deleteAccountSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get deleteAccountSigningIn;

  /// No description provided for @deleteAccountDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deleteAccountDeleting;

  /// No description provided for @deleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccountButton;

  /// No description provided for @deleteAccountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get deleteAccountSignOut;

  /// No description provided for @deleteAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Need help? Email developer110@hotmail.com and include the email address tied to your account.'**
  String get deleteAccountHelp;

  /// No description provided for @statsBestStreak.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Best: 1 day} other{Best: {days} days}}'**
  String statsBestStreak(int days);

  /// No description provided for @statsTodayDone.
  ///
  /// In en, this message translates to:
  /// **'Today: done'**
  String get statsTodayDone;

  /// No description provided for @statsTodayNotYet.
  ///
  /// In en, this message translates to:
  /// **'Today: not yet'**
  String get statsTodayNotYet;

  /// No description provided for @statsDaysToGoal.
  ///
  /// In en, this message translates to:
  /// **'{remaining, plural, =1{1 more day to a {goal}-day streak} other{{remaining} more days to a {goal}-day streak}}'**
  String statsDaysToGoal(int remaining, Object goal);

  /// No description provided for @statsUpdatedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{Updated 1 hour ago} other{Updated {hours} hours ago}}'**
  String statsUpdatedHoursAgo(int hours);

  /// No description provided for @statsUpdatedOn.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String statsUpdatedOn(String date);

  /// No description provided for @statsAllTime.
  ///
  /// In en, this message translates to:
  /// **'{count} all time'**
  String statsAllTime(String count);

  /// No description provided for @statsCommunityNote.
  ///
  /// In en, this message translates to:
  /// **'Anonymous totals from everyone using the app. {updated}.'**
  String statsCommunityNote(String updated);

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Stats'**
  String get statsTitle;

  /// No description provided for @statsYourMostRecited.
  ///
  /// In en, this message translates to:
  /// **'Your most recited'**
  String get statsYourMostRecited;

  /// No description provided for @statsStreakStart.
  ///
  /// In en, this message translates to:
  /// **'Finish reading a dua, ziyarat or surah and your streak begins.'**
  String get statsStreakStart;

  /// No description provided for @statsWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back - every day is a fresh start.'**
  String get statsWelcomeBack;

  /// No description provided for @statsDoneTodayFirst.
  ///
  /// In en, this message translates to:
  /// **'Done for today. Come back tomorrow to start a streak.'**
  String get statsDoneTodayFirst;

  /// No description provided for @statsDoneToday.
  ///
  /// In en, this message translates to:
  /// **'Done for today - see you tomorrow, in sha Allah.'**
  String get statsDoneToday;

  /// No description provided for @statsReadToday.
  ///
  /// In en, this message translates to:
  /// **'Read something today to keep it going.'**
  String get statsReadToday;

  /// No description provided for @statsDayStreak.
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get statsDayStreak;

  /// No description provided for @statsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statsToday;

  /// No description provided for @statsPrivateSynced.
  ///
  /// In en, this message translates to:
  /// **'Your stats are private and sync across devices signed in to your account.'**
  String get statsPrivateSynced;

  /// No description provided for @statsPrivateLocal.
  ///
  /// In en, this message translates to:
  /// **'Your stats are private and kept on this device. Sign in from Preferences to keep them across devices.'**
  String get statsPrivateLocal;

  /// No description provided for @statsUpdatedWithinHour.
  ///
  /// In en, this message translates to:
  /// **'Updated within the hour'**
  String get statsUpdatedWithinHour;

  /// No description provided for @statsAcrossCommunity.
  ///
  /// In en, this message translates to:
  /// **'Across the community'**
  String get statsAcrossCommunity;

  /// No description provided for @statsRecitedThisWeek.
  ///
  /// In en, this message translates to:
  /// **'duas, ziyarats and surahs recited this week'**
  String get statsRecitedThisWeek;

  /// No description provided for @statsMostRecitedThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Most recited this week'**
  String get statsMostRecitedThisWeek;

  /// No description provided for @quranSurahNumber.
  ///
  /// In en, this message translates to:
  /// **'Surah {number}'**
  String quranSurahNumber(int number);

  /// No description provided for @listenQuranTextFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the Quran text on this device.'**
  String get listenQuranTextFailed;

  /// No description provided for @listenRecogniserStopped.
  ///
  /// In en, this message translates to:
  /// **'The recogniser stopped unexpectedly. Try again.'**
  String get listenRecogniserStopped;

  /// No description provided for @listenNothingRecognised.
  ///
  /// In en, this message translates to:
  /// **'Nothing recognisable came through. Try again, a little closer to the reciter.'**
  String get listenNothingRecognised;

  /// No description provided for @listenCouldNotPlace.
  ///
  /// In en, this message translates to:
  /// **'Could not place that in the Quran. Try reciting a little more.'**
  String get listenCouldNotPlace;

  /// No description provided for @listenMicPermissionWeb.
  ///
  /// In en, this message translates to:
  /// **'Listening needs microphone access. You can grant it in this site\'s permissions in your browser.'**
  String get listenMicPermissionWeb;

  /// No description provided for @listenMicPermission.
  ///
  /// In en, this message translates to:
  /// **'Listening needs microphone access. You can grant it in your device settings.'**
  String get listenMicPermission;

  /// No description provided for @listenBrowserUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This browser cannot recognise speech. Chrome, Edge and Safari can.'**
  String get listenBrowserUnsupported;

  /// No description provided for @listenDeviceUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This device has no speech recogniser available.'**
  String get listenDeviceUnsupported;

  /// No description provided for @listenNoArabic.
  ///
  /// In en, this message translates to:
  /// **'This device has no Arabic speech recognition installed. Adding Arabic in your device\'s language settings enables it.'**
  String get listenNoArabic;

  /// No description provided for @listenStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start listening. Try again.'**
  String get listenStartFailed;

  /// No description provided for @listenTitle.
  ///
  /// In en, this message translates to:
  /// **'Listen and follow'**
  String get listenTitle;

  /// No description provided for @listenGettingReady.
  ///
  /// In en, this message translates to:
  /// **'Getting ready…'**
  String get listenGettingReady;

  /// No description provided for @listenListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get listenListening;

  /// No description provided for @listenHoldPhone.
  ///
  /// In en, this message translates to:
  /// **'Hold the phone towards the recitation.'**
  String get listenHoldPhone;

  /// No description provided for @listenFindNow.
  ///
  /// In en, this message translates to:
  /// **'Find the verse now'**
  String get listenFindNow;

  /// No description provided for @listenFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding the verse…'**
  String get listenFinding;

  /// No description provided for @listenWhichVerse.
  ///
  /// In en, this message translates to:
  /// **'Which verse was it?'**
  String get listenWhichVerse;

  /// No description provided for @listenAgain.
  ///
  /// In en, this message translates to:
  /// **'Listen again'**
  String get listenAgain;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @flightDepartureDateAt.
  ///
  /// In en, this message translates to:
  /// **'Departure date at {airport}'**
  String flightDepartureDateAt(String airport);

  /// No description provided for @flightArrivalDateAt.
  ///
  /// In en, this message translates to:
  /// **'Arrival date at {airport}'**
  String flightArrivalDateAt(String airport);

  /// No description provided for @flightDepartureTimeAt.
  ///
  /// In en, this message translates to:
  /// **'Departure time (local at {airport})'**
  String flightDepartureTimeAt(String airport);

  /// No description provided for @flightArrivalTimeAt.
  ///
  /// In en, this message translates to:
  /// **'Arrival time (local at {airport})'**
  String flightArrivalTimeAt(String airport);

  /// No description provided for @flightDurationTooLong.
  ///
  /// In en, this message translates to:
  /// **'That works out to {duration} in the air. Check the arrival date.'**
  String flightDurationTooLong(String duration);

  /// No description provided for @flightFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get flightFrom;

  /// No description provided for @flightTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get flightTo;

  /// No description provided for @flightDeparts.
  ///
  /// In en, this message translates to:
  /// **'Departs'**
  String get flightDeparts;

  /// No description provided for @flightArrives.
  ///
  /// In en, this message translates to:
  /// **'Arrives'**
  String get flightArrives;

  /// No description provided for @flightDepartureAirport.
  ///
  /// In en, this message translates to:
  /// **'Departure airport'**
  String get flightDepartureAirport;

  /// No description provided for @flightArrivalAirport.
  ///
  /// In en, this message translates to:
  /// **'Arrival airport'**
  String get flightArrivalAirport;

  /// No description provided for @flightChooseDepartureFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose the departure airport first.'**
  String get flightChooseDepartureFirst;

  /// No description provided for @flightChooseArrivalFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose the arrival airport first.'**
  String get flightChooseArrivalFirst;

  /// No description provided for @flightChooseBothAirports.
  ///
  /// In en, this message translates to:
  /// **'Choose both airports.'**
  String get flightChooseBothAirports;

  /// No description provided for @flightSetTimes.
  ///
  /// In en, this message translates to:
  /// **'Set the departure and arrival times.'**
  String get flightSetTimes;

  /// No description provided for @flightAirportsMustDiffer.
  ///
  /// In en, this message translates to:
  /// **'Departure and arrival airports must be different.'**
  String get flightAirportsMustDiffer;

  /// No description provided for @flightTimeZoneUnresolved.
  ///
  /// In en, this message translates to:
  /// **'Could not resolve the time zone for one of those airports.'**
  String get flightTimeZoneUnresolved;

  /// No description provided for @flightArrivalBeforeDeparture.
  ///
  /// In en, this message translates to:
  /// **'Arrival is before departure once time zones are applied. Check the arrival date — overnight flights land the next day.'**
  String get flightArrivalBeforeDeparture;

  /// No description provided for @flightAdd.
  ///
  /// In en, this message translates to:
  /// **'Add flight'**
  String get flightAdd;

  /// No description provided for @flightDepartsHint.
  ///
  /// In en, this message translates to:
  /// **'Local time at the departure airport'**
  String get flightDepartsHint;

  /// No description provided for @flightArrivesHint.
  ///
  /// In en, this message translates to:
  /// **'Local time at the arrival airport'**
  String get flightArrivesHint;

  /// No description provided for @flightNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Flight number (optional)'**
  String get flightNumberLabel;

  /// No description provided for @flightSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get flightSaveChanges;

  /// No description provided for @flightSave.
  ///
  /// In en, this message translates to:
  /// **'Save flight'**
  String get flightSave;

  /// No description provided for @flightTicketNote.
  ///
  /// In en, this message translates to:
  /// **'Enter the times exactly as they appear on your ticket — each one in the local time of its own airport.'**
  String get flightTicketNote;

  /// No description provided for @flightChooseAirport.
  ///
  /// In en, this message translates to:
  /// **'Choose an airport'**
  String get flightChooseAirport;

  /// No description provided for @flightChooseDateTime.
  ///
  /// In en, this message translates to:
  /// **'Choose date and time'**
  String get flightChooseDateTime;
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
