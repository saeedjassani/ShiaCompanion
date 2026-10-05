// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Shia Companion';

  @override
  String get settingsAppLanguage => 'App language';

  @override
  String get settingsTranslationLanguage => 'Translation language';

  @override
  String languageFollowDevice(String language) {
    return 'Device language ($language)';
  }

  @override
  String languageFollowApp(String language) {
    return 'Same as app ($language)';
  }

  @override
  String settingsDownloadedRecitationsUsed(String size) {
    return '$size used on this device';
  }

  @override
  String settingsHijriAhead(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ahead',
      one: '1 day ahead',
    );
    return '$_temp0';
  }

  @override
  String settingsHijriBehind(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days behind',
      one: '1 day behind',
    );
    return '$_temp0';
  }

  @override
  String settingsLocationFailed(String message) {
    return '$message. Tap to try again.';
  }

  @override
  String settingsLocationSaved(String city) {
    return 'Current saved location: $city.';
  }

  @override
  String settingsLocationUpdated(String city, String age) {
    return '$city · updated $age. Refreshes on its own as you move.';
  }

  @override
  String timeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String timeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String settingsAdjustHijriBy(int days) {
    return 'Adjust Hijri Date by $days days';
  }

  @override
  String settingsPrayerTimesShownSubtitle(String names) {
    return 'Shown on the home page and home screen widgets: $names.';
  }

  @override
  String settingsPrayerNotificationsAllOn(int count) {
    return 'On for all $count times.';
  }

  @override
  String settingsPrayerNotificationsSomeOn(
      String names, int enabled, int total) {
    return '$names · $enabled of $total on';
  }

  @override
  String get settingsSectionPrayerLocation => 'Prayer & Location';

  @override
  String get settingsAdjustHijriDate => 'Adjust Hijri Date';

  @override
  String get settingsPrayerTimesShown => 'Prayer Times Shown';

  @override
  String get settingsRefreshLocation => 'Refresh Location';

  @override
  String get settingsLocationRefreshed => 'Location has been refreshed.';

  @override
  String get settingsSectionNotifications => 'Notifications';

  @override
  String get settingsPrayerNotifications => 'Prayer notifications';

  @override
  String get settingsZikrReminders => 'Zikr Reminders';

  @override
  String get settingsZikrRemindersSubtitle =>
      'Get reminded about a zikr on the days you choose.';

  @override
  String get settingsPrecisePrayerAlarms => 'Precise Prayer Alarms';

  @override
  String get settingsScheduledNotifications => 'Scheduled Notifications';

  @override
  String get settingsScheduledNotificationsSubtitle =>
      'Review pending prayer notifications.';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsDarkMode => 'Dark mode';

  @override
  String get settingsDarkModeSubtitle =>
      'Use the dark appearance across the app.';

  @override
  String get settingsAppTextSize => 'App text size';

  @override
  String get settingsAppTextSizeSubtitle =>
      'Makes all text bigger or smaller, including zikr.';

  @override
  String get settingsSectionZikrReading => 'Zikr Reading & Sharing';

  @override
  String get settingsSectionOfflineAudio => 'Offline Audio';

  @override
  String get settingsDownloadedRecitations => 'Downloaded recitations';

  @override
  String get settingsDownloadedRecitationsEmpty =>
      'Listen without a connection';

  @override
  String get settingsSectionSupport => 'Support';

  @override
  String get settingsRateApp => 'Rate Shia Companion';

  @override
  String get settingsRateAppSubtitle => 'Enjoying the app? Leave us a rating.';

  @override
  String get settingsRequestContent => 'Request a Zikr or Book';

  @override
  String get settingsRequestContentSubtitle =>
      'Can\'t find a dua, ziyarat or book? Ask us to add it.';

  @override
  String get settingsFeedback => 'Feedback';

  @override
  String get settingsFeedbackSubtitle =>
      'Send questions, issues, or suggestions.';

  @override
  String get settingsGithub => 'Contribute on GitHub';

  @override
  String get settingsGithubSubtitle =>
      'Shia Companion is open source. Report issues or help improve it.';

  @override
  String get settingsGithubOpenFailed => 'Could not open GitHub';

  @override
  String get settingsAboutUs => 'About Us';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsNotSignedIn => 'Not signed in';

  @override
  String get settingsSignInPrompt =>
      'Sign in to sync favorites across devices.';

  @override
  String get settingsLogout => 'Logout';

  @override
  String get settingsLogoutSubtitle => 'Sign out on this device.';

  @override
  String get settingsDeleteAccount => 'Delete My Account';

  @override
  String get settingsDeleteAccountSubtitle =>
      'Permanently remove your account data.';

  @override
  String get settingsSignInGoogle => 'Sign in with Google';

  @override
  String get settingsSignInGoogleSubtitle => 'Sync favorites and account data.';

  @override
  String get settingsSignInApple => 'Sign in with Apple';

  @override
  String get settingsSignInAppleSubtitle => 'Use your Apple ID to sign in.';

  @override
  String get settingsSignedIn => 'Signed in';

  @override
  String get settingsSyncing => 'Favorites and account data are syncing.';

  @override
  String get settingsHijriNoAdjustment => 'No adjustment';

  @override
  String get settingsLocationUpdating => 'Updating your location…';

  @override
  String get settingsLocationUpdatePrompt =>
      'Update the saved prayer-times location.';

  @override
  String get timeJustNow => 'just now';

  @override
  String get settingsPrayerNotificationsOff =>
      'Off. Turn on to be notified at prayer times.';

  @override
  String get settingsPreciseAlarmsOn => 'Enabled for exact Azan timing.';

  @override
  String get settingsPreciseAlarmsOff =>
      'Off. Android may deliver prayer notifications a bit late.';

  @override
  String get settingsNotificationsUnavailable =>
      'Notification system not initialized';

  @override
  String get settingsPreciseAlarmsAlreadyOn =>
      'Precise prayer alarms are already enabled.';

  @override
  String get settingsPreciseAlarmsDialogTitle =>
      'Enable Precise Prayer Alarms?';

  @override
  String get settingsPreciseAlarmsDialogBody =>
      'Android requires Alarms & reminders access for Azan notifications to fire exactly at prayer time. Without it, reminders still work but may arrive a bit late.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOpenSettings => 'Open Settings';

  @override
  String get settingsPreciseAlarmsEnabled => 'Precise prayer alarms enabled.';

  @override
  String get settingsPreciseAlarmsNotEnabled =>
      'Precise prayer alarms were not enabled. Approximate timing will still be used.';

  @override
  String get settingsNoEmailApp => 'No email app found';

  @override
  String get settingsLoginSuccessful => 'Login Successful';

  @override
  String get settingsGoogleUnavailable =>
      'Google Sign-In isn\'t available right now. Please try again.';

  @override
  String get commonNetworkError =>
      'Couldn\'t connect. Check your internet connection and try again.';

  @override
  String get settingsGoogleFailed =>
      'Google Sign-In didn\'t work. Please try again in a moment.';

  @override
  String get settingsAppleFailed => 'Apple Sign-In Failed';
}
