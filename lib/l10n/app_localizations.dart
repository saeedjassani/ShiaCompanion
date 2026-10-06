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
  /// **'{message}. Tap to choose a city or try again.'**
  String settingsLocationFailed(String message);

  /// No description provided for @settingsLocationSaved.
  ///
  /// In en, this message translates to:
  /// **'{city} · from your phone\'s location.'**
  String settingsLocationSaved(String city);

  /// No description provided for @settingsLocationManual.
  ///
  /// In en, this message translates to:
  /// **'{city} · chosen by you. Tap to change.'**
  String settingsLocationManual(String city);

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

  /// No description provided for @settingsLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get settingsLocation;

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
  /// **'Choose a city, or use your phone\'s location.'**
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

  /// No description provided for @cityChangeCity.
  ///
  /// In en, this message translates to:
  /// **'Change city'**
  String get cityChangeCity;

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
  /// **'Open Settings in the app and use Delete My Account.'**
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

  /// No description provided for @widgetIslamicCalendar.
  ///
  /// In en, this message translates to:
  /// **'Islamic Calendar'**
  String get widgetIslamicCalendar;

  /// No description provided for @widgetFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get widgetFavorites;

  /// No description provided for @widgetNoFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get widgetNoFavorites;

  /// No description provided for @widgetTodaysRecitations.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Recitations'**
  String get widgetTodaysRecitations;

  /// No description provided for @widgetOpenAppToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Open app to refresh'**
  String get widgetOpenAppToRefresh;

  /// No description provided for @widgetUpNext.
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get widgetUpNext;

  /// No description provided for @widgetPrayerTimes.
  ///
  /// In en, this message translates to:
  /// **'Prayer Times'**
  String get widgetPrayerTimes;

  /// No description provided for @widgetLocationNeeded.
  ///
  /// In en, this message translates to:
  /// **'Location needed'**
  String get widgetLocationNeeded;

  /// No description provided for @widgetSavedLocation.
  ///
  /// In en, this message translates to:
  /// **'Saved location'**
  String get widgetSavedLocation;

  /// No description provided for @widgetSetLocation.
  ///
  /// In en, this message translates to:
  /// **'Set location'**
  String get widgetSetLocation;

  /// No description provided for @widgetOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Open app'**
  String get widgetOpenApp;

  /// No description provided for @widgetRefreshSchedule.
  ///
  /// In en, this message translates to:
  /// **'Refresh schedule'**
  String get widgetRefreshSchedule;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get commonTomorrow;

  /// A surah name followed by a verse number, e.g. 'Al-Baqarah 142'.
  ///
  /// In en, this message translates to:
  /// **'{surah} {ayah}'**
  String quranSurahAyah(String surah, int ayah);

  /// No description provided for @trackNameTaken.
  ///
  /// In en, this message translates to:
  /// **'There is already a track called \"{name}\"'**
  String trackNameTaken(String name);

  /// No description provided for @trackNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the track a name'**
  String get trackNameRequired;

  /// No description provided for @trackBeginning.
  ///
  /// In en, this message translates to:
  /// **'The beginning'**
  String get trackBeginning;

  /// No description provided for @trackNew.
  ///
  /// In en, this message translates to:
  /// **'New recitation track'**
  String get trackNew;

  /// No description provided for @trackName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get trackName;

  /// No description provided for @trackNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Family, Tahajjud'**
  String get trackNameHint;

  /// No description provided for @trackReadBy.
  ///
  /// In en, this message translates to:
  /// **'Read by'**
  String get trackReadBy;

  /// No description provided for @trackBySurah.
  ///
  /// In en, this message translates to:
  /// **'Surah'**
  String get trackBySurah;

  /// No description provided for @trackByJuz.
  ///
  /// In en, this message translates to:
  /// **'Juz (Para)'**
  String get trackByJuz;

  /// No description provided for @trackContinueFrom.
  ///
  /// In en, this message translates to:
  /// **'Continue from'**
  String get trackContinueFrom;

  /// No description provided for @trackStartFrom.
  ///
  /// In en, this message translates to:
  /// **'Start from'**
  String get trackStartFrom;

  /// No description provided for @trackStartAt.
  ///
  /// In en, this message translates to:
  /// **'Start at'**
  String get trackStartAt;

  /// No description provided for @trackEditNote.
  ///
  /// In en, this message translates to:
  /// **'Your track moves on by itself as you read. Change this only to pick up somewhere else.'**
  String get trackEditNote;

  /// No description provided for @trackNewNote.
  ///
  /// In en, this message translates to:
  /// **'You can change these anytime from the track card.'**
  String get trackNewNote;

  /// No description provided for @trackCreate.
  ///
  /// In en, this message translates to:
  /// **'Create track'**
  String get trackCreate;

  /// {sound} is the name of a notification sound.
  ///
  /// In en, this message translates to:
  /// **'{sound} · used unless a time below overrides it'**
  String notifDefaultSoundSubtitle(String sound);

  /// {file} is an audio file name.
  ///
  /// In en, this message translates to:
  /// **'Custom: {file}'**
  String notifCustomSound(String file);

  /// Title of the sound picker for one prayer.
  ///
  /// In en, this message translates to:
  /// **'{prayer} sound'**
  String notifPrayerSound(String prayer);

  /// No description provided for @notifFollows.
  ///
  /// In en, this message translates to:
  /// **'Follows {sound}'**
  String notifFollows(String sound);

  /// No description provided for @notifDefaultSound.
  ///
  /// In en, this message translates to:
  /// **'Default sound'**
  String get notifDefaultSound;

  /// No description provided for @notifTimesHeading.
  ///
  /// In en, this message translates to:
  /// **'TIMES'**
  String get notifTimesHeading;

  /// No description provided for @notifAudioUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That audio file could not be read.'**
  String get notifAudioUnreadable;

  /// No description provided for @notifPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not pick that file. Try again.'**
  String get notifPickFailed;

  /// No description provided for @notifPlayingSample.
  ///
  /// In en, this message translates to:
  /// **'Playing a sample in a moment…'**
  String get notifPlayingSample;

  /// No description provided for @notifUseDefault.
  ///
  /// In en, this message translates to:
  /// **'Use default'**
  String get notifUseDefault;

  /// No description provided for @notifOwnSoundNote.
  ///
  /// In en, this message translates to:
  /// **'This time keeps its own sound. Everything else follows the default.'**
  String get notifOwnSoundNote;

  /// No description provided for @notifDefaultNote.
  ///
  /// In en, this message translates to:
  /// **'Every time follows this unless you give it a sound of its own.'**
  String get notifDefaultNote;

  /// No description provided for @notifPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get notifPreview;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutDedication.
  ///
  /// In en, this message translates to:
  /// **'We thank Almighty Allah and His beloved Fourteen Infallibles (a.s.) for Their help which made us able to share this humble work with the Momeneen. We dedicate the app to them and the following Marhumeems:\n\nMarhooma Amina Mohammed Raza Jassani\nMarhoom Haji Mohammad Raza Jassani\nMarhoom Haji Yusufali Bhojani\n\n\nPlease recite Surah Fateha for Marhumeen and Marhumaat\n\nFor feedback, queries or suggestions contact :'**
  String get aboutDedication;

  /// No description provided for @aboutNoEmailApp.
  ///
  /// In en, this message translates to:
  /// **'No e-mail app found'**
  String get aboutNoEmailApp;

  /// No description provided for @aboutCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get aboutCredits;

  /// No description provided for @aboutCreditAudio.
  ///
  /// In en, this message translates to:
  /// **'Recitation audio is hosted on our own servers; the recordings are used with duas.org\'s kind permission.'**
  String get aboutCreditAudio;

  /// No description provided for @aboutCreditScheherazade.
  ///
  /// In en, this message translates to:
  /// **'Arabic is set in Scheherazade New by SIL Global, used under the SIL Open Font License.'**
  String get aboutCreditScheherazade;

  /// No description provided for @aboutCreditTanzil.
  ///
  /// In en, this message translates to:
  /// **'The Uthmani Quran text, shown with Scheherazade, is from the Tanzil Project, used under Creative Commons Attribution 3.0.'**
  String get aboutCreditTanzil;

  /// No description provided for @aboutCreditQuranWbw.
  ///
  /// In en, this message translates to:
  /// **'The IndoPak Quran text and font, shown with Qalam, are from QuranWBW.com. The licence to use the Quran text and font unmodified was received from QuranWBW.com, the original contributor.'**
  String get aboutCreditQuranWbw;

  /// No description provided for @aboutCreditIndoPakFont.
  ///
  /// In en, this message translates to:
  /// **'Font: AlQuran IndoPak by QuranWBW, made by Ayman Siddiqui, based on the Al Qalam Quran Majeed fonts, with ayah numbers from the KFGQPC Nastaleeq font. © Al Qalam © Ghandhara © KFGQPC © Ayman Siddiqui. Credits: Abdul Majeed Khan, Arif Karim, Shakir-ul-Qadree, Jawad. Quran text: typemybook.com, originally by InPage.'**
  String get aboutCreditIndoPakFont;

  /// No description provided for @downloadsRemoveAllBody.
  ///
  /// In en, this message translates to:
  /// **'Every recitation will stream again, so you\'ll need a connection to listen. Frees {size}.'**
  String downloadsRemoveAllBody(String size);

  /// No description provided for @downloadsOlderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} no longer used by any dua · {size}'**
  String downloadsOlderSubtitle(int count, String size);

  /// No description provided for @downloadsRemoveAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove all downloads?'**
  String get downloadsRemoveAllTitle;

  /// No description provided for @downloadsRemoveAll.
  ///
  /// In en, this message translates to:
  /// **'Remove all'**
  String get downloadsRemoveAll;

  /// No description provided for @downloadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No downloads yet'**
  String get downloadsEmpty;

  /// No description provided for @downloadsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Download a recitation to listen without a connection - tap the download button in a dua\'s audio player, or Download all on a playlist.'**
  String get downloadsEmptyBody;

  /// No description provided for @downloadsOlder.
  ///
  /// In en, this message translates to:
  /// **'Older recordings'**
  String get downloadsOlder;

  /// No description provided for @downloadsRemoveOlder.
  ///
  /// In en, this message translates to:
  /// **'Remove older recordings'**
  String get downloadsRemoveOlder;

  /// No description provided for @hijriMonth1.
  ///
  /// In en, this message translates to:
  /// **'Muharram'**
  String get hijriMonth1;

  /// No description provided for @hijriMonth2.
  ///
  /// In en, this message translates to:
  /// **'Safar'**
  String get hijriMonth2;

  /// No description provided for @hijriMonth3.
  ///
  /// In en, this message translates to:
  /// **'Rabi\' Al-Awwal'**
  String get hijriMonth3;

  /// No description provided for @hijriMonth4.
  ///
  /// In en, this message translates to:
  /// **'Rabi\' Al-Thani'**
  String get hijriMonth4;

  /// No description provided for @hijriMonth5.
  ///
  /// In en, this message translates to:
  /// **'Jumada Al-Awwal'**
  String get hijriMonth5;

  /// No description provided for @hijriMonth6.
  ///
  /// In en, this message translates to:
  /// **'Jumada Al-Thani'**
  String get hijriMonth6;

  /// No description provided for @hijriMonth7.
  ///
  /// In en, this message translates to:
  /// **'Rajab'**
  String get hijriMonth7;

  /// No description provided for @hijriMonth8.
  ///
  /// In en, this message translates to:
  /// **'Sha\'aban'**
  String get hijriMonth8;

  /// No description provided for @hijriMonth9.
  ///
  /// In en, this message translates to:
  /// **'Ramadan'**
  String get hijriMonth9;

  /// No description provided for @hijriMonth10.
  ///
  /// In en, this message translates to:
  /// **'Shawwal'**
  String get hijriMonth10;

  /// No description provided for @hijriMonth11.
  ///
  /// In en, this message translates to:
  /// **'Dhu Al-Qi\'dah'**
  String get hijriMonth11;

  /// No description provided for @hijriMonth12.
  ///
  /// In en, this message translates to:
  /// **'Dhu Al-Hijjah'**
  String get hijriMonth12;

  /// No description provided for @hijriMonthShort1.
  ///
  /// In en, this message translates to:
  /// **'Muh'**
  String get hijriMonthShort1;

  /// No description provided for @hijriMonthShort2.
  ///
  /// In en, this message translates to:
  /// **'Saf'**
  String get hijriMonthShort2;

  /// No description provided for @hijriMonthShort3.
  ///
  /// In en, this message translates to:
  /// **'Rab I'**
  String get hijriMonthShort3;

  /// No description provided for @hijriMonthShort4.
  ///
  /// In en, this message translates to:
  /// **'Rab II'**
  String get hijriMonthShort4;

  /// No description provided for @hijriMonthShort5.
  ///
  /// In en, this message translates to:
  /// **'Jum I'**
  String get hijriMonthShort5;

  /// No description provided for @hijriMonthShort6.
  ///
  /// In en, this message translates to:
  /// **'Jum II'**
  String get hijriMonthShort6;

  /// No description provided for @hijriMonthShort7.
  ///
  /// In en, this message translates to:
  /// **'Raj'**
  String get hijriMonthShort7;

  /// No description provided for @hijriMonthShort8.
  ///
  /// In en, this message translates to:
  /// **'Sha'**
  String get hijriMonthShort8;

  /// No description provided for @hijriMonthShort9.
  ///
  /// In en, this message translates to:
  /// **'Ram'**
  String get hijriMonthShort9;

  /// No description provided for @hijriMonthShort10.
  ///
  /// In en, this message translates to:
  /// **'Shaw'**
  String get hijriMonthShort10;

  /// No description provided for @hijriMonthShort11.
  ///
  /// In en, this message translates to:
  /// **'Dhul Q'**
  String get hijriMonthShort11;

  /// No description provided for @hijriMonthShort12.
  ///
  /// In en, this message translates to:
  /// **'Dhul H'**
  String get hijriMonthShort12;

  /// {age} is a relative time such as '3h ago'.
  ///
  /// In en, this message translates to:
  /// **'updated {age}'**
  String prayerUpdatedAgo(String age);

  /// No description provided for @prayerNextDay.
  ///
  /// In en, this message translates to:
  /// **'next day'**
  String get prayerNextDay;

  /// No description provided for @prayerLocating.
  ///
  /// In en, this message translates to:
  /// **'Locating…'**
  String get prayerLocating;

  /// No description provided for @prayerFindingLocation.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get prayerFindingLocation;

  /// No description provided for @prayerLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location not available'**
  String get prayerLocationUnavailable;

  /// No description provided for @calendarNotificationsSomeOn.
  ///
  /// In en, this message translates to:
  /// **'{enabled} of {total} on'**
  String calendarNotificationsSomeOn(int enabled, int total);

  /// No description provided for @calendarNoEvent.
  ///
  /// In en, this message translates to:
  /// **'No event listed for this date.'**
  String get calendarNoEvent;

  /// No description provided for @calendarNotificationsAllOff.
  ///
  /// In en, this message translates to:
  /// **'Off for every prayer'**
  String get calendarNotificationsAllOff;

  /// No description provided for @readingFineTune.
  ///
  /// In en, this message translates to:
  /// **'Fine-tune zikr text. Applied on top of App text size in Settings.'**
  String get readingFineTune;

  /// No description provided for @readingArabicFontSize.
  ///
  /// In en, this message translates to:
  /// **'Arabic Font Size'**
  String get readingArabicFontSize;

  /// No description provided for @readingEnglishFontSize.
  ///
  /// In en, this message translates to:
  /// **'English Font Size'**
  String get readingEnglishFontSize;

  /// No description provided for @readingArabicFont.
  ///
  /// In en, this message translates to:
  /// **'Arabic Font'**
  String get readingArabicFont;

  /// No description provided for @readingKeepScreenOn.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on while reciting Zikr'**
  String get readingKeepScreenOn;

  /// No description provided for @readingFocusMode.
  ///
  /// In en, this message translates to:
  /// **'Focus mode'**
  String get readingFocusMode;

  /// No description provided for @readingFocusModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide the progress bar and action bar while reading. Scroll up or tap to bring them back.'**
  String get readingFocusModeSubtitle;

  /// No description provided for @readingShareAsImage.
  ///
  /// In en, this message translates to:
  /// **'Share Zikr as Image'**
  String get readingShareAsImage;

  /// No description provided for @readingShareAsImageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a formatted image when sharing.'**
  String get readingShareAsImageSubtitle;

  /// No description provided for @readingShowTransliteration.
  ///
  /// In en, this message translates to:
  /// **'Show Transliteration'**
  String get readingShowTransliteration;

  /// No description provided for @readingShowTranslation.
  ///
  /// In en, this message translates to:
  /// **'Show Translation'**
  String get readingShowTranslation;

  /// No description provided for @readingArabicParagraph.
  ///
  /// In en, this message translates to:
  /// **'Show Arabic as Paragraph'**
  String get readingArabicParagraph;

  /// No description provided for @readingArabicParagraphOn.
  ///
  /// In en, this message translates to:
  /// **'Flow the Arabic verses together as one paragraph instead of separate lines.'**
  String get readingArabicParagraphOn;

  /// No description provided for @readingArabicParagraphOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off Transliteration and Translation above to use this.'**
  String get readingArabicParagraphOff;

  /// The verses a juz runs between, e.g. 'Al-Baqarah 142 – Al-Baqarah 252'.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String pickerJuzRange(String start, String end);

  /// {ayahs} is e.g. '286 ayahs'; {juz} a juz number or range like '1–3'.
  ///
  /// In en, this message translates to:
  /// **'{ayahs} · Juz {juz}'**
  String pickerSurahDetails(String ayahs, String juz);

  /// No description provided for @quranAyahCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 ayah} other{{count} ayahs}}'**
  String quranAyahCount(int count);

  /// No description provided for @pickerJuzFrom.
  ///
  /// In en, this message translates to:
  /// **'From {start}'**
  String pickerJuzFrom(String start);

  /// No description provided for @pickerAyahSingle.
  ///
  /// In en, this message translates to:
  /// **'ayah {ayah}'**
  String pickerAyahSingle(int ayah);

  /// No description provided for @pickerAyahRange.
  ///
  /// In en, this message translates to:
  /// **'ayahs {from}–{to}'**
  String pickerAyahRange(int from, int to);

  /// No description provided for @pickerThirtyJuz.
  ///
  /// In en, this message translates to:
  /// **'There are 30 juz'**
  String get pickerThirtyJuz;

  /// No description provided for @pickerTryVerse.
  ///
  /// In en, this message translates to:
  /// **'Try a verse like 33:33, or juz 22'**
  String get pickerTryVerse;

  /// No description provided for @pickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Go to a verse - 33:33, 18, juz 22'**
  String get pickerSearchHint;

  /// No description provided for @pickerChooseVerse.
  ///
  /// In en, this message translates to:
  /// **'Choose a verse'**
  String get pickerChooseVerse;

  /// No description provided for @pickerAllJuz.
  ///
  /// In en, this message translates to:
  /// **'All juz'**
  String get pickerAllJuz;

  /// No description provided for @pickerAllSurahs.
  ///
  /// In en, this message translates to:
  /// **'All surahs'**
  String get pickerAllSurahs;

  /// No description provided for @pickerChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get pickerChoose;

  /// No description provided for @quranFromPosition.
  ///
  /// In en, this message translates to:
  /// **'From {position}'**
  String quranFromPosition(String position);

  /// {percent} is a formatted number.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of the Quran'**
  String quranPercentRead(String percent);

  /// No description provided for @quranEditTrack.
  ///
  /// In en, this message translates to:
  /// **'Edit {track} track'**
  String quranEditTrack(String track);

  /// No description provided for @quranTitle.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get quranTitle;

  /// No description provided for @quranRecentSessions.
  ///
  /// In en, this message translates to:
  /// **'Recent sessions'**
  String get quranRecentSessions;

  /// No description provided for @quranTabSurahs.
  ///
  /// In en, this message translates to:
  /// **'Surahs'**
  String get quranTabSurahs;

  /// No description provided for @quranTabJuz.
  ///
  /// In en, this message translates to:
  /// **'Juz'**
  String get quranTabJuz;

  /// No description provided for @quranTabCollections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get quranTabCollections;

  /// No description provided for @quranStartReading.
  ///
  /// In en, this message translates to:
  /// **'Start reading'**
  String get quranStartReading;

  /// No description provided for @quranNewTrack.
  ///
  /// In en, this message translates to:
  /// **'New track'**
  String get quranNewTrack;

  /// No description provided for @quranGoToVerseError.
  ///
  /// In en, this message translates to:
  /// **'Try something like 23:56'**
  String get quranGoToVerseError;

  /// No description provided for @quranGoToVerseHint.
  ///
  /// In en, this message translates to:
  /// **'Go to verse, e.g. 23:56'**
  String get quranGoToVerseHint;

  /// No description provided for @quranGo.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get quranGo;

  /// No description provided for @statsMetricVerses.
  ///
  /// In en, this message translates to:
  /// **'Verses'**
  String get statsMetricVerses;

  /// No description provided for @statsMetricZikrs.
  ///
  /// In en, this message translates to:
  /// **'Zikrs'**
  String get statsMetricZikrs;

  /// No description provided for @statsMetricQaza.
  ///
  /// In en, this message translates to:
  /// **'Qaza'**
  String get statsMetricQaza;

  /// No description provided for @statsMetricVersesLower.
  ///
  /// In en, this message translates to:
  /// **'verses'**
  String get statsMetricVersesLower;

  /// No description provided for @statsMetricZikrsLower.
  ///
  /// In en, this message translates to:
  /// **'zikrs'**
  String get statsMetricZikrsLower;

  /// No description provided for @statsMetricQazaLower.
  ///
  /// In en, this message translates to:
  /// **'qaza'**
  String get statsMetricQazaLower;

  /// No description provided for @statsVerseCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{formatted} verse} other{{formatted} verses}}'**
  String statsVerseCount(int count, Object formatted);

  /// No description provided for @statsZikrCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{formatted} zikr} other{{formatted} zikrs}}'**
  String statsZikrCount(int count, Object formatted);

  /// No description provided for @statsQazaCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{formatted} qaza}}'**
  String statsQazaCount(int count, Object formatted);

  /// No description provided for @statsPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get statsPeriodWeek;

  /// No description provided for @statsPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get statsPeriodMonth;

  /// No description provided for @statsPeriodAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get statsPeriodAllTime;

  /// No description provided for @statsCaptionWeek.
  ///
  /// In en, this message translates to:
  /// **'{metric} in the last 7 days'**
  String statsCaptionWeek(String metric);

  /// No description provided for @statsCaptionMonth.
  ///
  /// In en, this message translates to:
  /// **'{metric} in the last 30 days'**
  String statsCaptionMonth(String metric);

  /// No description provided for @statsCaptionAllTime.
  ///
  /// In en, this message translates to:
  /// **'{metric} in total'**
  String statsCaptionAllTime(String metric);

  /// No description provided for @statsHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get statsHistory;

  /// No description provided for @statsBestMonth.
  ///
  /// In en, this message translates to:
  /// **'Best month: {month} · {count}'**
  String statsBestMonth(String month, String count);

  /// {average} is a formatted number.
  ///
  /// In en, this message translates to:
  /// **'Best day: {day} · {count} · {average} a day on average'**
  String statsBestDay(String day, String count, String average);

  /// No description provided for @statsNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get statsNew;

  /// No description provided for @statsVersusBefore.
  ///
  /// In en, this message translates to:
  /// **'vs {count} before'**
  String statsVersusBefore(String count);

  /// No description provided for @statsSessionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{formatted} session} other{{formatted} sessions}}'**
  String statsSessionCount(int count, Object formatted);

  /// No description provided for @statsVersesRecited.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{formatted} verse recited} other{{formatted} verses recited}}'**
  String statsVersesRecited(int count, Object formatted);

  /// No description provided for @statsLastOn.
  ///
  /// In en, this message translates to:
  /// **'last {date}'**
  String statsLastOn(String date);

  /// No description provided for @statsVersesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} verses left to complete a khatm'**
  String statsVersesLeft(String count);

  /// No description provided for @statsJuzCoverage.
  ///
  /// In en, this message translates to:
  /// **'Juz {juz}: {percent}%'**
  String statsJuzCoverage(int juz, int percent);

  /// No description provided for @statsJuzComplete.
  ///
  /// In en, this message translates to:
  /// **'{count} of 30 juz complete'**
  String statsJuzComplete(int count);

  /// No description provided for @statsQuranProgress.
  ///
  /// In en, this message translates to:
  /// **'Quran progress'**
  String get statsQuranProgress;

  /// No description provided for @statsQuranEmpty.
  ///
  /// In en, this message translates to:
  /// **'Open a surah and start reading - the verses you recite are tracked here automatically, with your progress towards a full khatm.'**
  String get statsQuranEmpty;

  /// No description provided for @statsRecitedTill.
  ///
  /// In en, this message translates to:
  /// **'Recited till'**
  String get statsRecitedTill;

  /// No description provided for @statsNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get statsNotStarted;

  /// No description provided for @statsJuzDone.
  ///
  /// In en, this message translates to:
  /// **'Juz done'**
  String get statsJuzDone;

  /// No description provided for @statsKhatmComplete.
  ///
  /// In en, this message translates to:
  /// **'Khatm complete - may it be accepted'**
  String get statsKhatmComplete;

  /// No description provided for @reminderAtPrayer.
  ///
  /// In en, this message translates to:
  /// **'At {prayer}'**
  String reminderAtPrayer(String prayer);

  /// No description provided for @reminderMinutesAfter.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min after {prayer}'**
  String reminderMinutesAfter(int minutes, String prayer);

  /// No description provided for @reminderMinutesBefore.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min before {prayer}'**
  String reminderMinutesBefore(int minutes, String prayer);

  /// Media notification title while the Azan plays.
  ///
  /// In en, this message translates to:
  /// **'{prayer} Azan is playing'**
  String azanPlaying(String prayer);

  /// No description provided for @libraryNeedsNetwork.
  ///
  /// In en, this message translates to:
  /// **'Library browsing needs a network connection.'**
  String get libraryNeedsNetwork;

  /// No description provided for @libraryChaptersFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load chapters. Please try again.'**
  String get libraryChaptersFailed;

  /// No description provided for @libraryReadingNeedsNetwork.
  ///
  /// In en, this message translates to:
  /// **'Reading books needs a network connection.'**
  String get libraryReadingNeedsNetwork;

  /// No description provided for @libraryChapterFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load this chapter. Please try again.'**
  String get libraryChapterFailed;

  /// No description provided for @menuCalendarPrayerTimes.
  ///
  /// In en, this message translates to:
  /// **'Calendar & Prayer Times'**
  String get menuCalendarPrayerTimes;

  /// No description provided for @menuFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get menuFavorites;

  /// No description provided for @menuTodaysRecitations.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Recitations'**
  String get menuTodaysRecitations;

  /// No description provided for @menuTaqeebat.
  ///
  /// In en, this message translates to:
  /// **'Taqeebat e Namaz'**
  String get menuTaqeebat;

  /// No description provided for @menuNamaz.
  ///
  /// In en, this message translates to:
  /// **'Namaz'**
  String get menuNamaz;

  /// No description provided for @menuDuas.
  ///
  /// In en, this message translates to:
  /// **'Duas'**
  String get menuDuas;

  /// No description provided for @menuZiyarats.
  ///
  /// In en, this message translates to:
  /// **'Ziyarats'**
  String get menuZiyarats;

  /// No description provided for @menuSurahs.
  ///
  /// In en, this message translates to:
  /// **'Surahs'**
  String get menuSurahs;

  /// No description provided for @menuAamaal.
  ///
  /// In en, this message translates to:
  /// **'Aamaal'**
  String get menuAamaal;

  /// No description provided for @menuLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get menuLibrary;

  /// No description provided for @menuMunajaat.
  ///
  /// In en, this message translates to:
  /// **'Munajaat'**
  String get menuMunajaat;

  /// No description provided for @menuBaaqeyaat.
  ///
  /// In en, this message translates to:
  /// **'Baaqeyaat As Saalehaat'**
  String get menuBaaqeyaat;

  /// No description provided for @menuQiblaFinder.
  ///
  /// In en, this message translates to:
  /// **'Qibla Finder'**
  String get menuQiblaFinder;

  /// No description provided for @menuTasbeehCounter.
  ///
  /// In en, this message translates to:
  /// **'Tasbeeh Counter'**
  String get menuTasbeehCounter;

  /// No description provided for @menuQazaTracker.
  ///
  /// In en, this message translates to:
  /// **'Qaza Tracker'**
  String get menuQazaTracker;

  /// No description provided for @menuRakaatCounter.
  ///
  /// In en, this message translates to:
  /// **'Rakaat Counter'**
  String get menuRakaatCounter;

  /// No description provided for @menuPrayerTimesInFlight.
  ///
  /// In en, this message translates to:
  /// **'Prayer Times in Flight'**
  String get menuPrayerTimesInFlight;

  /// No description provided for @menuPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get menuPreferences;

  /// No description provided for @menuQuran.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get menuQuran;

  /// No description provided for @menuPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get menuPlaylists;

  /// No description provided for @menuMyStats.
  ///
  /// In en, this message translates to:
  /// **'My Stats'**
  String get menuMyStats;

  /// No description provided for @menuCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get menuCalendar;

  /// No description provided for @audioTrackNumber.
  ///
  /// In en, this message translates to:
  /// **'Track {number}'**
  String audioTrackNumber(int number);

  /// No description provided for @audioPauseRecitation.
  ///
  /// In en, this message translates to:
  /// **'Pause recitation'**
  String get audioPauseRecitation;

  /// No description provided for @audioPlayRecitation.
  ///
  /// In en, this message translates to:
  /// **'Play recitation'**
  String get audioPlayRecitation;

  /// No description provided for @audioList.
  ///
  /// In en, this message translates to:
  /// **'Audio list'**
  String get audioList;

  /// No description provided for @audioOfflineNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline and this recitation isn\'t downloaded'**
  String get audioOfflineNotDownloaded;

  /// No description provided for @audioLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'This recitation couldn\'t be loaded'**
  String get audioLoadFailed;

  /// No description provided for @audioClosePlayer.
  ///
  /// In en, this message translates to:
  /// **'Close player'**
  String get audioClosePlayer;

  /// No description provided for @audioChooseRecording.
  ///
  /// In en, this message translates to:
  /// **'Choose recording'**
  String get audioChooseRecording;

  /// No description provided for @audioRecitation.
  ///
  /// In en, this message translates to:
  /// **'Recitation'**
  String get audioRecitation;

  /// No description provided for @audioRecitationAudio.
  ///
  /// In en, this message translates to:
  /// **'Recitation audio'**
  String get audioRecitationAudio;

  /// No description provided for @librarySavedOffline.
  ///
  /// In en, this message translates to:
  /// **'{book} saved for offline.'**
  String librarySavedOffline(String book);

  /// No description provided for @librarySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save book: {error}'**
  String librarySaveFailed(String error);

  /// No description provided for @libraryProgress.
  ///
  /// In en, this message translates to:
  /// **'{chapter} - Page {page} of {pages}'**
  String libraryProgress(String chapter, int page, int pages);

  /// No description provided for @librarySavedChapterGone.
  ///
  /// In en, this message translates to:
  /// **'Saved chapter is no longer available'**
  String get librarySavedChapterGone;

  /// No description provided for @libraryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Library unavailable'**
  String get libraryUnavailable;

  /// No description provided for @libraryNoBooks.
  ///
  /// In en, this message translates to:
  /// **'No books found'**
  String get libraryNoBooks;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'The library is empty right now.'**
  String get libraryEmpty;

  /// No description provided for @libraryContinueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue Reading'**
  String get libraryContinueReading;

  /// No description provided for @libraryRequestBook.
  ///
  /// In en, this message translates to:
  /// **'Request a Book'**
  String get libraryRequestBook;

  /// No description provided for @libraryRequestBookSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find a book? Ask us to add it.'**
  String get libraryRequestBookSubtitle;

  /// No description provided for @flightRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'{flight} will be removed from your saved flights.'**
  String flightRemoveBody(String flight);

  /// {airport} is an airport code.
  ///
  /// In en, this message translates to:
  /// **'{duration} · lands {time} {airport} time'**
  String flightLands(String duration, String time, String airport);

  /// No description provided for @flightRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove flight?'**
  String get flightRemoveTitle;

  /// No description provided for @flightRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove flight'**
  String get flightRemove;

  /// No description provided for @flightNoneSaved.
  ///
  /// In en, this message translates to:
  /// **'No flights saved'**
  String get flightNoneSaved;

  /// No description provided for @flightNoneSavedBody.
  ///
  /// In en, this message translates to:
  /// **'Add your flight and this page will work out when each prayer comes in along the route — shown in both your departure and arrival city\'s time.'**
  String get flightNoneSavedBody;

  /// No description provided for @librarySavedForOffline.
  ///
  /// In en, this message translates to:
  /// **'{title} saved for offline'**
  String librarySavedForOffline(String title);

  /// No description provided for @librarySaveFailedShort.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String librarySaveFailedShort(String error);

  /// No description provided for @libraryOfflineRemoved.
  ///
  /// In en, this message translates to:
  /// **'Offline copy removed'**
  String get libraryOfflineRemoved;

  /// No description provided for @libraryShareBook.
  ///
  /// In en, this message translates to:
  /// **'Share book'**
  String get libraryShareBook;

  /// No description provided for @libraryRemoveOffline.
  ///
  /// In en, this message translates to:
  /// **'Remove offline copy'**
  String get libraryRemoveOffline;

  /// No description provided for @librarySaveOffline.
  ///
  /// In en, this message translates to:
  /// **'Save book offline'**
  String get librarySaveOffline;

  /// No description provided for @libraryChaptersUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Chapters unavailable'**
  String get libraryChaptersUnavailable;

  /// No description provided for @libraryNoChapters.
  ///
  /// In en, this message translates to:
  /// **'No chapters found'**
  String get libraryNoChapters;

  /// No description provided for @libraryNoChaptersBody.
  ///
  /// In en, this message translates to:
  /// **'This book has no chapters right now.'**
  String get libraryNoChaptersBody;

  /// No description provided for @quranMoveEntry.
  ///
  /// In en, this message translates to:
  /// **'Move \"{entry}\"'**
  String quranMoveEntry(String entry);

  /// No description provided for @quranNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet. Open a surah and start reading - the verses you recite are logged here automatically.'**
  String get quranNoSessions;

  /// No description provided for @quranMoveToLabel.
  ///
  /// In en, this message translates to:
  /// **'Move to another label'**
  String get quranMoveToLabel;

  /// No description provided for @quranNewLabel.
  ///
  /// In en, this message translates to:
  /// **'Or a new label'**
  String get quranNewLabel;

  /// No description provided for @quranMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get quranMove;

  /// No description provided for @quranCollectionDuas.
  ///
  /// In en, this message translates to:
  /// **'Duas'**
  String get quranCollectionDuas;

  /// No description provided for @quranCollectionImamAli.
  ///
  /// In en, this message translates to:
  /// **'Imam Ali (a.s.)'**
  String get quranCollectionImamAli;

  /// No description provided for @quranCollectionImamMahdi.
  ///
  /// In en, this message translates to:
  /// **'Imam al-Mahdi (a.t.f.s.)'**
  String get quranCollectionImamMahdi;

  /// No description provided for @quranCollectionProphets.
  ///
  /// In en, this message translates to:
  /// **'Prophets'**
  String get quranCollectionProphets;

  /// No description provided for @quranCollectionSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get quranCollectionSaved;

  /// No description provided for @quranFromTheQuran.
  ///
  /// In en, this message translates to:
  /// **'From the Quran'**
  String get quranFromTheQuran;

  /// No description provided for @quranNoSavedVerses.
  ///
  /// In en, this message translates to:
  /// **'No saved verses yet'**
  String get quranNoSavedVerses;

  /// No description provided for @quranNoSavedVersesBody.
  ///
  /// In en, this message translates to:
  /// **'Tap a verse while reading to keep it here.'**
  String get quranNoSavedVersesBody;

  /// No description provided for @libraryNextChapter.
  ///
  /// In en, this message translates to:
  /// **'Next chapter'**
  String get libraryNextChapter;

  /// No description provided for @libraryPreviousChapter.
  ///
  /// In en, this message translates to:
  /// **'Previous chapter'**
  String get libraryPreviousChapter;

  /// No description provided for @libraryNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get libraryNextPage;

  /// No description provided for @libraryPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get libraryPreviousPage;

  /// No description provided for @libraryNextChapterNamed.
  ///
  /// In en, this message translates to:
  /// **'Next chapter: {chapter}'**
  String libraryNextChapterNamed(String chapter);

  /// No description provided for @libraryPreviousChapterNamed.
  ///
  /// In en, this message translates to:
  /// **'Previous chapter: {chapter}'**
  String libraryPreviousChapterNamed(String chapter);

  /// No description provided for @libraryNextShort.
  ///
  /// In en, this message translates to:
  /// **'Next: {chapter}'**
  String libraryNextShort(String chapter);

  /// No description provided for @libraryPreviousShort.
  ///
  /// In en, this message translates to:
  /// **'Previous: {chapter}'**
  String libraryPreviousShort(String chapter);

  /// No description provided for @libraryShareChapter.
  ///
  /// In en, this message translates to:
  /// **'Share chapter'**
  String get libraryShareChapter;

  /// No description provided for @libraryChapterUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Chapter unavailable'**
  String get libraryChapterUnavailable;

  /// No description provided for @libraryDecreaseFont.
  ///
  /// In en, this message translates to:
  /// **'Decrease font size'**
  String get libraryDecreaseFont;

  /// No description provided for @libraryIncreaseFont.
  ///
  /// In en, this message translates to:
  /// **'Increase font size'**
  String get libraryIncreaseFont;

  /// No description provided for @azaanTakbirName.
  ///
  /// In en, this message translates to:
  /// **'Takbir Only'**
  String get azaanTakbirName;

  /// No description provided for @azaanTakbirDescription.
  ///
  /// In en, this message translates to:
  /// **'Short takbir notification sound'**
  String get azaanTakbirDescription;

  /// No description provided for @azaanFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Azan'**
  String get azaanFullName;

  /// No description provided for @azaanFullDescription.
  ///
  /// In en, this message translates to:
  /// **'Full azan, played automatically'**
  String get azaanFullDescription;

  /// No description provided for @azaanFullIosDescription.
  ///
  /// In en, this message translates to:
  /// **'The notification plays the Takbir; tap it to hear the full azan'**
  String get azaanFullIosDescription;

  /// No description provided for @azaanSystemDefaultName.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get azaanSystemDefaultName;

  /// No description provided for @azaanSystemDefaultDescription.
  ///
  /// In en, this message translates to:
  /// **'Use your device\'s default notification sound'**
  String get azaanSystemDefaultDescription;

  /// No description provided for @azaanSilentName.
  ///
  /// In en, this message translates to:
  /// **'Silent'**
  String get azaanSilentName;

  /// No description provided for @azaanSilentDescription.
  ///
  /// In en, this message translates to:
  /// **'Notification banner only (no sound)'**
  String get azaanSilentDescription;

  /// No description provided for @azaanCustomName.
  ///
  /// In en, this message translates to:
  /// **'Custom Audio'**
  String get azaanCustomName;

  /// No description provided for @azaanCustomDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose an audio file from your device'**
  String get azaanCustomDescription;

  /// No description provided for @ratingEnjoying.
  ///
  /// In en, this message translates to:
  /// **'Enjoying Shia Companion?'**
  String get ratingEnjoying;

  /// No description provided for @ratingEnjoyingBody.
  ///
  /// In en, this message translates to:
  /// **'We\'d love to hear how it\'s going for you - your feedback helps us keep improving the app.'**
  String get ratingEnjoyingBody;

  /// No description provided for @ratingNotReally.
  ///
  /// In en, this message translates to:
  /// **'Not really'**
  String get ratingNotReally;

  /// No description provided for @ratingYes.
  ///
  /// In en, this message translates to:
  /// **'Yes!'**
  String get ratingYes;

  /// No description provided for @ratingSorry.
  ///
  /// In en, this message translates to:
  /// **'Sorry to hear that'**
  String get ratingSorry;

  /// No description provided for @ratingSorryBody.
  ///
  /// In en, this message translates to:
  /// **'Would you mind telling us what\'s not working? It helps us improve the app.'**
  String get ratingSorryBody;

  /// No description provided for @ratingNoThanks.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get ratingNoThanks;

  /// No description provided for @ratingSendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get ratingSendFeedback;

  /// No description provided for @azaanOptInIntro.
  ///
  /// In en, this message translates to:
  /// **'Shia Companion can send you a notification at Fajr, Zuhr and Maghrib and play the azan.'**
  String get azaanOptInIntro;

  /// No description provided for @azaanOptInIosNote.
  ///
  /// In en, this message translates to:
  /// **'On iPhone the notification plays a short takbir. Choose Full Azan in Settings to hear the whole azan when you tap it.'**
  String get azaanOptInIosNote;

  /// No description provided for @azaanOptInChangeLater.
  ///
  /// In en, this message translates to:
  /// **'You can change which prayers notify you, pick a different sound, or turn this off again at any time in Settings.'**
  String get azaanOptInChangeLater;

  /// No description provided for @azaanOptInTitle.
  ///
  /// In en, this message translates to:
  /// **'Play the azan at prayer times?'**
  String get azaanOptInTitle;

  /// No description provided for @azaanOptInNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get azaanOptInNotNow;

  /// No description provided for @azaanOptInEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable azan'**
  String get azaanOptInEnable;

  /// No description provided for @reminderRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the reminder for \"{title}\". You can add it again any time.'**
  String reminderRemoveBody(String title);

  /// No description provided for @reminderRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove reminder?'**
  String get reminderRemoveTitle;

  /// No description provided for @reminderAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get reminderAddTooltip;

  /// No description provided for @reminderNone.
  ///
  /// In en, this message translates to:
  /// **'No reminders yet'**
  String get reminderNone;

  /// No description provided for @reminderNoneBody.
  ///
  /// In en, this message translates to:
  /// **'Tap + to get reminded about a zikr or dua on the days you choose — like Tawassul every Tuesday, or Dua Kumail after Maghrib on Thursday.'**
  String get reminderNoneBody;

  /// No description provided for @tasbeehBeepNumber.
  ///
  /// In en, this message translates to:
  /// **'Beep {number}'**
  String tasbeehBeepNumber(int number);

  /// No description provided for @tasbeehHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap the counter circle to count. The beep will play at the milestones below.'**
  String get tasbeehHelp;

  /// No description provided for @tasbeehEnableBeep.
  ///
  /// In en, this message translates to:
  /// **'Enable beep'**
  String get tasbeehEnableBeep;

  /// No description provided for @tasbeehTapToCount.
  ///
  /// In en, this message translates to:
  /// **'Tap to count'**
  String get tasbeehTapToCount;

  /// No description provided for @tasbeehMinusOne.
  ///
  /// In en, this message translates to:
  /// **'Minus one'**
  String get tasbeehMinusOne;

  /// No description provided for @tasbeehReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get tasbeehReset;

  /// No description provided for @requestThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks - we\'ve received your request.'**
  String get requestThanks;

  /// No description provided for @requestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the request. Please try again.'**
  String get requestFailed;

  /// No description provided for @requestBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Book title'**
  String get requestBookTitle;

  /// No description provided for @requestZikrName.
  ///
  /// In en, this message translates to:
  /// **'Name of dua, ziyarat, etc.'**
  String get requestZikrName;

  /// No description provided for @requestBookDetails.
  ///
  /// In en, this message translates to:
  /// **'Author, translator or link (optional)'**
  String get requestBookDetails;

  /// No description provided for @requestZikrDetails.
  ///
  /// In en, this message translates to:
  /// **'Source, occasion or link (optional)'**
  String get requestZikrDetails;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @searchOneMatch.
  ///
  /// In en, this message translates to:
  /// **'1 match in {source}'**
  String searchOneMatch(String source);

  /// No description provided for @searchMatches.
  ///
  /// In en, this message translates to:
  /// **'{count} matches in {source}'**
  String searchMatches(int count, String source);

  /// No description provided for @searchSourceZikr.
  ///
  /// In en, this message translates to:
  /// **'Zikr'**
  String get searchSourceZikr;

  /// No description provided for @searchSourceQuran.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get searchSourceQuran;

  /// No description provided for @searchSourceLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get searchSourceLibrary;

  /// No description provided for @searchTitleOrUid.
  ///
  /// In en, this message translates to:
  /// **'Search title or UID'**
  String get searchTitleOrUid;

  /// No description provided for @searchShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get searchShow;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchNoResults;

  /// No description provided for @searchRequestIt.
  ///
  /// In en, this message translates to:
  /// **'Request it'**
  String get searchRequestIt;

  /// No description provided for @widgetPrayerTimesHelp.
  ///
  /// In en, this message translates to:
  /// **'Pick {min} to {max} times. Sunrise, Sunset and Midnight are the deadlines a prayer has to be offered before.'**
  String widgetPrayerTimesHelp(int min, int max);

  /// No description provided for @accountSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again and retry deletion.'**
  String get accountSessionExpired;

  /// No description provided for @accountReauthenticate.
  ///
  /// In en, this message translates to:
  /// **'For security, please sign in again and then retry deleting your account.'**
  String get accountReauthenticate;

  /// No description provided for @accountPopupClosed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in window closed before the action finished.'**
  String get accountPopupClosed;

  /// No description provided for @accountNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection and try again.'**
  String get accountNetworkError;

  /// No description provided for @commonSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonSomethingWentWrong;

  /// No description provided for @zikrTabNumber.
  ///
  /// In en, this message translates to:
  /// **'Tab {number}'**
  String zikrTabNumber(int number);

  /// No description provided for @zikrBookmarked.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked'**
  String get zikrBookmarked;

  /// No description provided for @zikrMoveBookmarkHere.
  ///
  /// In en, this message translates to:
  /// **'Move bookmark here'**
  String get zikrMoveBookmarkHere;

  /// No description provided for @zikrDragBookmarkHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to move the bookmark to another line'**
  String get zikrDragBookmarkHint;

  /// No description provided for @durationUnderOneMinute.
  ///
  /// In en, this message translates to:
  /// **'under 1 min'**
  String get durationUnderOneMinute;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 hr} other{{hours} hrs}}'**
  String durationHours(int hours);

  /// {hours} is e.g. '1 hr' or '2 hrs'.
  ///
  /// In en, this message translates to:
  /// **'{hours} {minutes} min'**
  String durationHoursMinutes(String hours, int minutes);

  /// Estimated time to recite a zikr, e.g. '8 min read'.
  ///
  /// In en, this message translates to:
  /// **'{duration} read'**
  String zikrReadingTime(String duration);

  /// No description provided for @zikrProgressCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get zikrProgressCompleted;

  /// No description provided for @airportNothingMatched.
  ///
  /// In en, this message translates to:
  /// **'Nothing matched \"{query}\". Try the three letter code instead.'**
  String airportNothingMatched(String query);

  /// No description provided for @airportSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Airport code or city'**
  String get airportSearchLabel;

  /// No description provided for @airportSearchHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. SFO, Istanbul, Najaf'**
  String get airportSearchHint;

  /// No description provided for @airportSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search for an airport'**
  String get airportSearchTitle;

  /// No description provided for @airportSearchDetail.
  ///
  /// In en, this message translates to:
  /// **'Type an airport code, a city, or a country name.'**
  String get airportSearchDetail;

  /// No description provided for @airportNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No airports found'**
  String get airportNoneFound;

  /// No description provided for @counterTapAnywhere.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to count'**
  String get counterTapAnywhere;

  /// No description provided for @counterHoldToMove.
  ///
  /// In en, this message translates to:
  /// **'Hold and drag to move'**
  String get counterHoldToMove;

  /// No description provided for @counterAddOne.
  ///
  /// In en, this message translates to:
  /// **'Add one'**
  String get counterAddOne;

  /// No description provided for @azanPaused.
  ///
  /// In en, this message translates to:
  /// **'{prayer} Azan is paused'**
  String azanPaused(String prayer);

  /// No description provided for @azanPrayerFallback.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get azanPrayerFallback;

  /// No description provided for @reminderChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminders for zikr and duas you scheduled'**
  String get reminderChannelDescription;

  /// No description provided for @locationOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are off'**
  String get locationOff;

  /// No description provided for @locationPermissionShort.
  ///
  /// In en, this message translates to:
  /// **'Location permission needed'**
  String get locationPermissionShort;

  /// No description provided for @locationNoFix.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get a location fix'**
  String get locationNoFix;

  /// No description provided for @locationUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update location'**
  String get locationUpdateFailed;

  /// {unit} is e.g. 'surah'.
  ///
  /// In en, this message translates to:
  /// **'Previous {unit}'**
  String quranPreviousUnit(String unit);

  /// No description provided for @quranNextUnit.
  ///
  /// In en, this message translates to:
  /// **'Next {unit}'**
  String quranNextUnit(String unit);

  /// No description provided for @quranUnitSurah.
  ///
  /// In en, this message translates to:
  /// **'surah'**
  String get quranUnitSurah;

  /// No description provided for @hadithNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found for \"{query}\"'**
  String hadithNoResults(String query);

  /// No description provided for @hadithTitle.
  ///
  /// In en, this message translates to:
  /// **'Hadith'**
  String get hadithTitle;

  /// No description provided for @hadithSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search hadith...'**
  String get hadithSearchHint;

  /// No description provided for @hadithNone.
  ///
  /// In en, this message translates to:
  /// **'No hadith available'**
  String get hadithNone;

  /// No description provided for @favoritesReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder {title}'**
  String favoritesReorder(String title);

  /// No description provided for @favoritesReorderFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the new order. Try again.'**
  String get favoritesReorderFailed;

  /// No description provided for @favoritesNone.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet.'**
  String get favoritesNone;

  /// No description provided for @linkNotFoundRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested link: {link}'**
  String linkNotFoundRequested(String link);

  /// No description provided for @linkNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Link Not Found'**
  String get linkNotFoundTitle;

  /// No description provided for @linkNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find this content.'**
  String get linkNotFoundBody;

  /// No description provided for @linkNotFoundGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go Home'**
  String get linkNotFoundGoHome;

  /// No description provided for @whatsNewTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get whatsNewTitle;

  /// No description provided for @whatsNewGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get whatsNewGotIt;

  /// No description provided for @pickerChooseZikr.
  ///
  /// In en, this message translates to:
  /// **'Choose a Zikr or Dua'**
  String get pickerChooseZikr;

  /// No description provided for @pickerSearchZikrHint.
  ///
  /// In en, this message translates to:
  /// **'Search zikr, dua, ziyarat...'**
  String get pickerSearchZikrHint;

  /// No description provided for @pickerNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches found.'**
  String get pickerNoMatches;

  /// No description provided for @todaysNone.
  ///
  /// In en, this message translates to:
  /// **'No recitations configured.'**
  String get todaysNone;

  /// No description provided for @scheduledFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled notification'**
  String get scheduledFallbackTitle;

  /// No description provided for @scheduledNone.
  ///
  /// In en, this message translates to:
  /// **'No scheduled notifications.'**
  String get scheduledNone;

  /// No description provided for @newsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load news: {error}'**
  String newsLoadFailed(String error);

  /// No description provided for @newsNoBrowser.
  ///
  /// In en, this message translates to:
  /// **'No web browser found'**
  String get newsNoBrowser;

  /// No description provided for @actionSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get actionSaved;

  /// No description provided for @actionBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get actionBookmark;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @actionListen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get actionListen;

  /// No description provided for @actionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get actionSettings;

  /// No description provided for @actionCounter.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get actionCounter;

  /// No description provided for @prayerEnableLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Enable location to display accurate prayer times for your area.'**
  String get prayerEnableLocationBody;

  /// No description provided for @statsDayRead.
  ///
  /// In en, this message translates to:
  /// **'{day}: read'**
  String statsDayRead(String day);

  /// No description provided for @statsDayNotRead.
  ///
  /// In en, this message translates to:
  /// **'{day}: not read'**
  String statsDayNotRead(String day);

  /// No description provided for @qiblaDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get qiblaDistance;

  /// No description provided for @qiblaDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get qiblaDirection;

  /// No description provided for @qiblaYouFace.
  ///
  /// In en, this message translates to:
  /// **'You face'**
  String get qiblaYouFace;

  /// No description provided for @pickerAyahLabel.
  ///
  /// In en, this message translates to:
  /// **'Ayah {ayah}'**
  String pickerAyahLabel(int ayah);

  /// Appended to a shared hadith.
  ///
  /// In en, this message translates to:
  /// **'Shared via Shia Companion - {link}'**
  String hadithSharedVia(String link);

  /// No description provided for @requestTypeZikr.
  ///
  /// In en, this message translates to:
  /// **'Zikr'**
  String get requestTypeZikr;

  /// No description provided for @requestTypeBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get requestTypeBook;

  /// The Home tab in the bottom tab bar.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shellTabHome;

  /// The Quran tab in the bottom tab bar, and the title of the surah list it opens.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get shellTabQuran;

  /// The Favorites tab in the bottom tab bar.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get shellTabFavorites;

  /// Screen-reader label for a tab bar item, as a platform tab bar reads: 'Home, tab 1 of 3'.
  ///
  /// In en, this message translates to:
  /// **'{tab}, tab {position} of {count}'**
  String shellTabSemantics(String tab, int position, int count);

  /// Short name of Qibla Finder, for a Home shortcut tile.
  ///
  /// In en, this message translates to:
  /// **'Qibla'**
  String get menuQiblaShort;

  /// Short name of Tasbeeh Counter, for a Home shortcut tile.
  ///
  /// In en, this message translates to:
  /// **'Tasbeeh'**
  String get menuTasbeehShort;

  /// The tile, page and editor row that lists every feature of the app.
  ///
  /// In en, this message translates to:
  /// **'All features'**
  String get homeAllFeatures;

  /// Heading of Home's section of feature shortcuts, and of its editor sheet.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get homeShortcutsTitle;

  /// Action at the end of a Home section heading that opens its editor.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get homeSectionEdit;

  /// No description provided for @homeEditShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Edit shortcuts'**
  String get homeEditShortcuts;

  /// Screen-reader label for a feature that is already one of the Home shortcuts.
  ///
  /// In en, this message translates to:
  /// **'{feature}, on your Home'**
  String homeShortcutOnHomeSemantics(String feature);

  /// Heading over the shortcuts already on Home in the editor, e.g. 'On your Home · 5 of 7'. Shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'On your Home · {count} of {max}'**
  String homeShortcutsOnHomeCount(int count, int max);

  /// No description provided for @homeShortcutRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove {feature}'**
  String homeShortcutRemove(String feature);

  /// No description provided for @homeShortcutAdd.
  ///
  /// In en, this message translates to:
  /// **'Add {feature}'**
  String homeShortcutAdd(String feature);

  /// Under 'All features' in the shortcuts editor: that tile cannot be removed or moved.
  ///
  /// In en, this message translates to:
  /// **'Always last, so nothing gets lost'**
  String get homeAllFeaturesAlwaysLast;

  /// Heading over the features that can be added as shortcuts. Shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get homeShortcutsMore;

  /// The 'More' heading when Home already has the most shortcuts it can take. Shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'More · remove one above to add one here'**
  String get homeShortcutsMoreFull;

  /// Key under the All features grid, next to the check that marks a feature already on Home.
  ///
  /// In en, this message translates to:
  /// **'Already one of your Home shortcuts'**
  String get homeAlreadyShortcut;

  /// The greeting at the top of Home.
  ///
  /// In en, this message translates to:
  /// **'Assalamu alaykum'**
  String get homeGreeting;

  /// Tooltip and screen-reader label of the profile button on Home.
  ///
  /// In en, this message translates to:
  /// **'Settings and account'**
  String get homeSettingsAndAccount;

  /// How far off a Coming up event on Home is. Today and tomorrow have their own words.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{In 1 day} other{In {days} days}}'**
  String homeEventInDays(int days);

  /// A Coming up event on Home: what happened, and to whom, e.g. 'Wiladat of Imam Ali (a.s.)'. Both come from the calendar's event list.
  ///
  /// In en, this message translates to:
  /// **'{kind} of {name}'**
  String homeEventKindOf(String kind, String name);

  /// Heading of Home's section of upcoming Islamic calendar events.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get homeComingUpTitle;

  /// Screen-reader label of the Calendar link beside the Coming up heading.
  ///
  /// In en, this message translates to:
  /// **'Open the calendar'**
  String get homeOpenCalendar;

  /// No description provided for @homeHadithOfTheDay.
  ///
  /// In en, this message translates to:
  /// **'Hadith of the day'**
  String get homeHadithOfTheDay;

  /// Heading of Home's section that picks up the latest Quran track, bookmark or book.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get homeContinueTitle;

  /// What a zikr category is called on a Continue card on Home, before ' · bookmark'.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get homeCategoryQuran;

  /// What a zikr category is called on a Continue card on Home, before ' · bookmark'.
  ///
  /// In en, this message translates to:
  /// **'Aamaal'**
  String get homeCategoryAamaal;

  /// What a zikr category is called on a Continue card on Home, before ' · bookmark'.
  ///
  /// In en, this message translates to:
  /// **'Taqibaat'**
  String get homeCategoryTaqibaat;

  /// What a zikr category is called on a Continue card on Home, before ' · bookmark'.
  ///
  /// In en, this message translates to:
  /// **'Dua'**
  String get homeCategoryDua;

  /// What a zikr category is called on a Continue card on Home, before ' · bookmark'.
  ///
  /// In en, this message translates to:
  /// **'Namaz'**
  String get homeCategoryNamaz;

  /// What a zikr category is called on a Continue card on Home, before ' · bookmark'.
  ///
  /// In en, this message translates to:
  /// **'Ziyarat'**
  String get homeCategoryZiyarat;

  /// What a zikr category is called on a Continue card on Home, before ' · bookmark'.
  ///
  /// In en, this message translates to:
  /// **'Munajat'**
  String get homeCategoryMunajat;

  /// What a zikr category is called on a Continue card on Home, before ' · bookmark'.
  ///
  /// In en, this message translates to:
  /// **'Zikr'**
  String get homeCategoryZikr;

  /// Caption of a Continue card for a named Quran recitation track.
  ///
  /// In en, this message translates to:
  /// **'Quran · {track}'**
  String homeContinueQuranTrack(String track);

  /// No description provided for @homeContinueVerseOf.
  ///
  /// In en, this message translates to:
  /// **'Verse {ayah} of {count}'**
  String homeContinueVerseOf(int ayah, int count);

  /// Caption of a Continue card for a zikr bookmark, e.g. 'Dua · bookmark'.
  ///
  /// In en, this message translates to:
  /// **'{category} · bookmark'**
  String homeContinueBookmarkCaption(String category);

  /// No description provided for @homeContinueAtBookmark.
  ///
  /// In en, this message translates to:
  /// **'Pick up at your bookmark'**
  String get homeContinueAtBookmark;

  /// {tab} is the title of the tab of the zikr the bookmark is in.
  ///
  /// In en, this message translates to:
  /// **'Pick up in {tab}'**
  String homeContinueInTab(String tab);

  /// No description provided for @homeContinueWhereStopped.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you stopped'**
  String get homeContinueWhereStopped;

  /// Screen-reader label of the progress bar on a Quran Continue card.
  ///
  /// In en, this message translates to:
  /// **'Progress through the surah'**
  String get homeContinueSurahProgress;

  /// Part of a clock difference, e.g. '2 hr' in '2 hr 30 min ahead of your phone'.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr'**
  String cityClockHours(int hours);

  /// Part of a clock difference, e.g. '30 min' in '2 hr 30 min ahead of your phone'.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String cityClockMinutes(int minutes);

  /// How far a city's clock is ahead of the phone's; {amount} is e.g. '2 hr 30 min'.
  ///
  /// In en, this message translates to:
  /// **'{amount} ahead of your phone'**
  String cityClockAhead(String amount);

  /// How far a city's clock is behind the phone's; {amount} is e.g. '2 hr 30 min'.
  ///
  /// In en, this message translates to:
  /// **'{amount} behind your phone'**
  String cityClockBehind(String amount);

  /// Heading over the cities suggested before anything is typed. Shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'In your time zone'**
  String get cityInYourTimeZone;

  /// Heading over the city search results. Shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Cities'**
  String get cityResults;

  /// Title of the picker that looks up another city's prayer times without changing the reader's own.
  ///
  /// In en, this message translates to:
  /// **'Another city'**
  String get cityAnotherCity;

  /// No description provided for @cityChooseYourCity.
  ///
  /// In en, this message translates to:
  /// **'Choose your city'**
  String get cityChooseYourCity;

  /// {query} is what the reader typed.
  ///
  /// In en, this message translates to:
  /// **'No city called “{query}”. Try another spelling, or the nearest bigger city - its prayer times will be within a minute or two of yours.'**
  String cityNoMatch(String query);

  /// No description provided for @cityLookupNote.
  ///
  /// In en, this message translates to:
  /// **'See any city\'s prayer times on its own clock. Your own prayer times and notifications stay as they are.'**
  String get cityLookupNote;

  /// No description provided for @cityOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'Prayer times are worked out on your phone, so this works without internet. You can change city any time from the prayer card.'**
  String get cityOfflineNote;

  /// Attribution required by the city list's licence. Keep 'GeoNames', 'geonames.org' and 'CC BY 4.0' as they are.
  ///
  /// In en, this message translates to:
  /// **'City list: GeoNames (geonames.org), CC BY 4.0'**
  String get cityListCredit;

  /// No description provided for @cityInCityQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you in {city} now?'**
  String cityInCityQuestion(String city);

  /// {difference} is e.g. '2 hr ahead of your phone'.
  ///
  /// In en, this message translates to:
  /// **'{city} is {difference}. Checking its times won\'t change your own prayer times or notifications.'**
  String cityInCityBody(String city, String difference);

  /// Answer to 'Are you in {city} now?': only looking at that city's times.
  ///
  /// In en, this message translates to:
  /// **'Just checking times'**
  String get cityJustChecking;

  /// No description provided for @cityImInCity.
  ///
  /// In en, this message translates to:
  /// **'I\'m in {city} now'**
  String cityImInCity(String city);

  /// No description provided for @citySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a city'**
  String get citySearchHint;

  /// No description provided for @cityUseCurrentLocationInstead.
  ///
  /// In en, this message translates to:
  /// **'Use my current location instead'**
  String get cityUseCurrentLocationInstead;

  /// No description provided for @cityUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get cityUseCurrentLocation;

  /// Under 'Use my current location': the phone's location follows the reader.
  ///
  /// In en, this message translates to:
  /// **'Updates by itself when you travel'**
  String get cityUpdatesWhenTravelling;

  /// A city search result found by another name of the city, e.g. 'Iraq · also Kerbela'.
  ///
  /// In en, this message translates to:
  /// **'{place} · also {alias}'**
  String cityAlsoKnownAs(String place, String alias);

  /// No description provided for @cityPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get cityPreviousDay;

  /// No description provided for @cityNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get cityNextDay;

  /// Button that jumps back to the city's today.
  ///
  /// In en, this message translates to:
  /// **'Today in {city}'**
  String cityTodayIn(String city);

  /// Which clock the times are on, e.g. 'Karbala time, 2 hr ahead of your phone'.
  ///
  /// In en, this message translates to:
  /// **'{city} time, {difference}'**
  String cityTimeDifference(String city, String difference);

  /// No description provided for @cityJustLookingNote.
  ///
  /// In en, this message translates to:
  /// **'Just for looking: your own prayer times and notifications stay as they are.'**
  String get cityJustLookingNote;

  /// Under 'Another city' on the calendar.
  ///
  /// In en, this message translates to:
  /// **'See its prayer times for this date'**
  String get cityAnotherCitySubtitle;

  /// Attribution required by the city list's licence. Keep 'GeoNames' as it is.
  ///
  /// In en, this message translates to:
  /// **'The city list is from GeoNames, used under Creative Commons Attribution 4.0.'**
  String get aboutCityListCredit;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// Theme option: light or dark following the phone's setting.
  ///
  /// In en, this message translates to:
  /// **'Same as phone'**
  String get themeSameAsPhone;

  /// Theme option.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Theme option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSameAsPhoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Light or dark, as your phone is set'**
  String get themeSameAsPhoneSubtitle;

  /// Caption of Home's prayer card, and its screen-reader label.
  ///
  /// In en, this message translates to:
  /// **'Prayer times'**
  String get prayerTimesTitle;

  /// Stands in for the city's name in 'Still in {city}?' when the city has no name.
  ///
  /// In en, this message translates to:
  /// **'the city you chose'**
  String get prayerTheCityYouChose;

  /// Asked on the prayer card when a chosen city's clock no longer matches the phone's, e.g. after flying home.
  ///
  /// In en, this message translates to:
  /// **'Still in {city}?'**
  String prayerStillInCity(String city);

  /// No description provided for @prayerPhoneZoneDiffers.
  ///
  /// In en, this message translates to:
  /// **'Your phone is set to a different time zone.'**
  String get prayerPhoneZoneDiffers;

  /// No description provided for @prayerYesStillHere.
  ///
  /// In en, this message translates to:
  /// **'Yes, still here'**
  String get prayerYesStillHere;

  /// The place button on the prayer card while the location has no name yet.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get prayerYourLocation;

  /// Screen-reader label of the place button on the prayer card.
  ///
  /// In en, this message translates to:
  /// **'{place}. Change city'**
  String prayerCityButtonSemantics(String place);

  /// No description provided for @prayerChooseCity.
  ///
  /// In en, this message translates to:
  /// **'Choose city'**
  String get prayerChooseCity;

  /// Title of the prayer card before any location is known.
  ///
  /// In en, this message translates to:
  /// **'Which city are you in?'**
  String get prayerWhichCity;

  /// No description provided for @prayerWhichCityBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll show today\'s prayer times and the next azan.'**
  String get prayerWhichCityBody;

  /// No description provided for @prayerZoneSuggests.
  ///
  /// In en, this message translates to:
  /// **'Your phone\'s time zone suggests {city}.'**
  String prayerZoneSuggests(String city);

  /// No description provided for @prayerYesImIn.
  ///
  /// In en, this message translates to:
  /// **'Yes, I\'m in {city}'**
  String prayerYesImIn(String city);
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
