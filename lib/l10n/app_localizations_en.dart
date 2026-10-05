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
    return '$message. Tap to choose a city or try again.';
  }

  @override
  String settingsLocationSaved(String city) {
    return '$city · from your phone\'s location.';
  }

  @override
  String settingsLocationManual(String city) {
    return '$city · chosen by you. Tap to change.';
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
  String get settingsLocation => 'Location';

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
      'Choose a city, or use your phone\'s location.';

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

  @override
  String audioRecordingNumber(int number) {
    return 'Recording $number';
  }

  @override
  String playlistAddedTo(String name) {
    return 'Added to $name';
  }

  @override
  String playlistAlreadyIn(String name) {
    return 'Already in $name';
  }

  @override
  String zikrCount(int count) {
    return '$count zikr';
  }

  @override
  String get playlistsEmpty =>
      'Make a playlist of the zikr you listen to every day - Dua Ahad and Ziyarat Ashura each morning, say - and start them all with one tap.';

  @override
  String playlistDeleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get playlistDeleteKeepsDuasAndAudio =>
      'The duas themselves stay in the app, and so does their downloaded audio - remove it from Downloads to free space.';

  @override
  String get playlistEmpty =>
      'Tap Add to choose zikr. You can also add one from the player on any dua with audio.';

  @override
  String audioRecordingsChosen(int chosen, int total) {
    return '$chosen of $total recordings';
  }

  @override
  String audioDownloadingPercent(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String audioRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recordings',
      one: '1 recording',
    );
    return '$_temp0';
  }

  @override
  String playlistNowPlayingPosition(String playlist, int position, int count) {
    return '$playlist · $position of $count';
  }

  @override
  String get playlistNameHint => 'e.g. Morning';

  @override
  String get playlistOfflinePartial =>
      'You\'re offline - playing only the downloaded recordings';

  @override
  String get playlistNothingToPlay =>
      'Nothing in this playlist has a recording to play';

  @override
  String get playlistOfflineNothingDownloaded =>
      'You\'re offline and nothing in this playlist is downloaded yet';

  @override
  String get playlistStartFailed => 'Couldn\'t start the playlist. Try again.';

  @override
  String get playlistChooseRecordingsHint =>
      'Choose the recordings to play in this playlist';

  @override
  String get commonDone => 'Done';

  @override
  String get playlistAddTo => 'Add to playlist';

  @override
  String get playlistNew => 'New playlist';

  @override
  String get commonCreate => 'Create';

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get playlistDownloads => 'Downloads';

  @override
  String get commonPause => 'Pause';

  @override
  String get commonPlay => 'Play';

  @override
  String get playlistRename => 'Rename playlist';

  @override
  String get commonSave => 'Save';

  @override
  String get playlistDeleteKeepsDuas => 'The duas themselves stay in the app.';

  @override
  String get commonDelete => 'Delete';

  @override
  String get playlistDeleted => 'This playlist has been deleted.';

  @override
  String get commonRename => 'Rename';

  @override
  String get playlistRemoveDownloads => 'Remove downloads';

  @override
  String get playlistAllDownloads => 'All downloads';

  @override
  String get commonAdd => 'Add';

  @override
  String get playlistResume => 'Resume';

  @override
  String get playlistPlayAll => 'Play all';

  @override
  String get audioDownloaded => 'Downloaded';

  @override
  String get audioDownloadFailed => 'Download didn\'t finish';

  @override
  String get playlistOpenText => 'Open text';

  @override
  String get playlistChooseRecordings => 'Choose recordings';

  @override
  String get audioStopDownloading => 'Stop downloading';

  @override
  String get audioRemoveDownload => 'Remove download';

  @override
  String get audioDownload => 'Download';

  @override
  String get playlistRemoveZikr => 'Remove from playlist';

  @override
  String get playlistAddZikr => 'Add zikr';

  @override
  String get commonSearch => 'Search';

  @override
  String get audioPartlyDownloaded => 'Partly downloaded';

  @override
  String get playlistRepeatOn => 'Repeat is on';

  @override
  String get playlistRepeat => 'Repeat playlist';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get commonNext => 'Next';

  @override
  String get commonStop => 'Stop';

  @override
  String flightTimesShownAt(String origin, String destination) {
    return 'Times shown at $origin and $destination local clocks';
  }

  @override
  String flightDurationAndDistance(String duration, String distance) {
    return '$duration in the air · $distance great-circle';
  }

  @override
  String flightAirportTime(String airport) {
    return '$airport time';
  }

  @override
  String flightOverPosition(String position) {
    return ' · over $position';
  }

  @override
  String flightAfterTakeoff(String duration) {
    return '$duration after take-off';
  }

  @override
  String flightHorizonLater(int minutes) {
    return '$minutes min later than the horizon of the ground below';
  }

  @override
  String flightHorizonEarlier(int minutes) {
    return '$minutes min earlier than the horizon of the ground below';
  }

  @override
  String flightQiblaToRight(int degrees) {
    return '$degrees° to your right';
  }

  @override
  String flightQiblaToLeft(int degrees) {
    return '$degrees° to your left';
  }

  @override
  String flightQiblaLine(int bearing, String compass, String relative) {
    return 'Qibla $bearing° ($compass) — $relative relative to the direction of flight';
  }

  @override
  String flightAltitudeHorizonBody(String altitude, String dip) {
    return 'At $altitude the horizon sits about $dip° lower than on the ground, so the sun takes longer to set and dawn comes sooner. That moves Maghrib and Isha about twenty minutes later, and Fajr about twenty minutes earlier, than the times for the ground beneath you — each row shows its own shift. Which horizon governs the prayer is a question for your marja, not one this app can settle.';
  }

  @override
  String flightAltitudeFeet(String feet) {
    return '$feet ft';
  }

  @override
  String get flightTitleFallback => 'Flight';

  @override
  String get flightEdit => 'Edit flight';

  @override
  String get flightCheckTimes => 'Check the flight times';

  @override
  String get flightCheckTimesBody =>
      'The arrival is not after the departure once each airport\'s time zone is applied. Tap edit to fix the dates.';

  @override
  String get flightInTheAir => 'In the air';

  @override
  String get flightNoPrayerDuring => 'No prayer comes in during this flight';

  @override
  String get flightNoPrayerDuringBody =>
      'Every prayer time falls either before take-off or after landing.';

  @override
  String get flightNotDuring => 'Not during this flight';

  @override
  String get flightEndOfIshaWindow => 'End of the Isha window · ';

  @override
  String get flightStraightAhead => 'straight ahead';

  @override
  String get flightDirectlyBehind => 'directly behind you';

  @override
  String get flightIshaClosedBeforeTakeoff =>
      'The Isha window had already closed before take-off.';

  @override
  String get flightAlreadyInBeforeTakeoff =>
      'Already in before take-off — use the prayer times for your departure city.';

  @override
  String get flightIshaOpenUntilLanding =>
      'The Isha window does not close until after landing.';

  @override
  String get flightAfterLanding =>
      'Comes in after landing — use the prayer times for your destination.';

  @override
  String get flightSunAngleNeverReached =>
      'The sun never reaches the required angle anywhere along this route, so no time can be calculated.';

  @override
  String get flightHowWorkedOut => 'How these are worked out';

  @override
  String get flightHowWorkedOutBody =>
      'The aircraft is assumed to follow the great-circle route at a steady speed, and each prayer time is solved for the position the aircraft is at when that time arrives. A delay of an hour moves these times by roughly half an hour, and routing around weather can move them by ten to twenty minutes, so treat them as close rather than exact.';

  @override
  String get flightHorizonAtAltitude => 'Measured from the horizon at altitude';

  @override
  String get flightHorizonAtGround =>
      'Measured from the horizon at ground level';

  @override
  String get flightGroundHorizonBody =>
      'Times follow the horizon of the ground below the aircraft. From the cabin the sun sets later and dawn breaks earlier than shown, by around twenty minutes at cruise altitude.';

  @override
  String get flightHighLatitude => 'This route crosses high latitudes';

  @override
  String get flightHighLatitudeBody =>
      'Above roughly 48°, the sun may not dip far enough below the horizon for dawn and nightfall to happen normally. Times for Fajr, Maghrib and Isha there fall back to a proportional estimate of the night. Rulings for prayer at high latitude differ — please follow your marja.';

  @override
  String get flightSomeNotCalculated =>
      'Some prayer times could not be calculated';

  @override
  String get flightSomeNotCalculatedBody =>
      'The sun stays above the required angle for the whole route, so those prayers have no calculated time. Please follow your marja\'s ruling for these conditions.';

  @override
  String get flightTimeZonesFailed => 'Time zones could not be loaded';

  @override
  String get flightTimeZonesFailedBody =>
      'One of these airports has a time zone this build does not recognise. Tap edit to pick the airports again.';

  @override
  String get prayerFajr => 'Fajr';

  @override
  String get prayerSunrise => 'Sunrise';

  @override
  String get prayerZuhr => 'Zuhr';

  @override
  String get prayerAsr => 'Asr';

  @override
  String get prayerSunset => 'Sunset';

  @override
  String get prayerMaghrib => 'Maghrib';

  @override
  String get prayerIsha => 'Isha';

  @override
  String get prayerMidnight => 'Midnight';

  @override
  String locationErrorBody(String error) {
    return 'An error occurred while getting your location: $error\n\nPlease check that location services are enabled and try again.';
  }

  @override
  String notificationReopenAppBody(int days) {
    return 'It seems you\'ve not used the application in last $days days. Please open the app to continue receive Azan notifications';
  }

  @override
  String notificationPrayerTime(String prayer) {
    return 'It\'s time for $prayer';
  }

  @override
  String notificationTapToPlayCustom(String message) {
    return '$message · Tap to play your audio';
  }

  @override
  String notificationTapToPlayAzan(String message) {
    return '$message · Tap to hear the full azan';
  }

  @override
  String get locationEnableTitle => 'Enable Location for Prayer Times';

  @override
  String get locationEnableBody =>
      'Prayer times are unique to your location. We use your location while you are using the app so we can provide accurate prayer times for your area.';

  @override
  String get commonContinue => 'Continue';

  @override
  String get locationServicesDisabledTitle => 'Location Services Disabled';

  @override
  String get locationServicesDisabledBody =>
      'Location services are turned off. Please enable location services in your device settings to get accurate prayer times for your area.';

  @override
  String get locationPermissionDeniedForever =>
      'Location permission was permanently denied. Please open app settings and grant location permission to get accurate prayer times.';

  @override
  String get locationPermissionUnknown =>
      'Unable to determine location permission status. Please open app settings and ensure location permission is granted.';

  @override
  String get locationPermissionNeeded =>
      'Location permission is required to show accurate prayer times for your area.';

  @override
  String get locationPermissionTitle => 'Location Permission Required';

  @override
  String get locationTimeoutTitle => 'Location Timeout';

  @override
  String get locationTimeoutBody =>
      'Unable to get your location within the expected time. This may be due to poor GPS signal or network issues. Please try again.';

  @override
  String get locationErrorTitle => 'Location Error';

  @override
  String get notificationReopenAppTitle =>
      'Open the app to continue getting Azan notifications';

  @override
  String get notificationChannelTakbir => 'Prayer Times - Takbir';

  @override
  String get notificationChannelSystemDefault =>
      'Prayer Times - System Default';

  @override
  String get notificationChannelSilent => 'Prayer Times - Silent';

  @override
  String get notificationChannelCustom => 'Prayer Times - Custom Sound';

  @override
  String get notificationChannelFullAzan => 'Prayer Times - Full Azan';

  @override
  String get notificationChannelSilentDescription =>
      'Silent prayer time notifications';

  @override
  String get notificationChannelDescription => 'Prayer time notifications';

  @override
  String get notificationChannelGeneral => 'General';

  @override
  String qiblaNeedsCalibratingBody(int degrees) {
    return 'Readings are off by around $degrees°. Move the phone in a figure of eight a few times, away from anything metal or magnetic.';
  }

  @override
  String qiblaBearingFromNorth(String place, String bearing) {
    return '$place is $bearing of true north';
  }

  @override
  String qiblaFacing(String place) {
    return 'Facing $place';
  }

  @override
  String qiblaTurnRight(int degrees) {
    return 'Turn right $degrees°';
  }

  @override
  String qiblaTurnLeft(int degrees) {
    return 'Turn left $degrees°';
  }

  @override
  String qiblaDeclinationEast(String degrees) {
    return 'Magnetic north is $degrees° east of true north where you are, and the reading is corrected for it automatically.';
  }

  @override
  String qiblaDeclinationWest(String degrees) {
    return 'Magnetic north is $degrees° west of true north where you are, and the reading is corrected for it automatically.';
  }

  @override
  String get qiblaDistanceHere => 'Here';

  @override
  String get qiblaTitle => 'Qibla Finder';

  @override
  String get qiblaAboutCompass => 'About this compass';

  @override
  String get qiblaLocationNeeded => 'Location needed';

  @override
  String get qiblaLocationNeededBody =>
      'The direction depends on where you are. Share your location and the compass will point the moment a fix arrives.';

  @override
  String get qiblaUseMyLocation => 'Use my location';

  @override
  String get qiblaTurnOnCompass => 'Turn on the compass';

  @override
  String get qiblaTurnOnCompassBody =>
      'This browser needs your permission before it will report which way the phone is facing.';

  @override
  String get qiblaAllowCompass => 'Allow compass';

  @override
  String get qiblaCompassBlocked => 'Compass blocked';

  @override
  String get qiblaCompassBlockedBody =>
      'Motion and orientation access was declined, so the dial is held north-up. Allow it in your browser settings, or turn until north on the dial matches north around you.';

  @override
  String get qiblaNoCompass => 'No compass on this device';

  @override
  String get qiblaNoCompassBody =>
      'The dial is held north-up instead. Face north, and the needle shows the direction from there.';

  @override
  String get qiblaNeedsCalibrating => 'Compass needs calibrating';

  @override
  String get qiblaLocationUnknown => 'Location unknown';

  @override
  String get qiblaUpdateLocation => 'Update location';

  @override
  String get qiblaChangeCity => 'Change city';

  @override
  String get qiblaPointingTowards => 'Pointing towards';

  @override
  String get qiblaWaitingForLocation => 'Waiting for your location';

  @override
  String get qiblaPointTowards => 'Point towards';

  @override
  String get qiblaGreatCircleBody =>
      'The needle points along the great-circle path — the shortest way over the surface of the earth, which is the direction the qibla is defined by. On a flat map it can look surprising; from North America the Kaaba is roughly north-east, not south-east.';

  @override
  String get qiblaDeclinationUnknownBody =>
      'Your phone measures the angle to magnetic north, which differs from true north by an amount that depends on where you are. That correction is applied automatically once your location is known.';

  @override
  String get qiblaSteadyReadingBody =>
      'For a steady reading, hold the phone flat and keep it away from laptops, speakers, car dashboards and anything else with a magnet in it.';

  @override
  String get commonClose => 'Close';

  @override
  String get weekdayShortMon => 'Mon';

  @override
  String get weekdayShortTue => 'Tue';

  @override
  String get weekdayShortWed => 'Wed';

  @override
  String get weekdayShortThu => 'Thu';

  @override
  String get weekdayShortFri => 'Fri';

  @override
  String get weekdayShortSat => 'Sat';

  @override
  String get weekdayShortSun => 'Sun';

  @override
  String reminderMinutesRange(int max) {
    return 'Enter a number of minutes between 0 and $max.';
  }

  @override
  String get reminderTitleRequired => 'Please enter a title for this reminder.';

  @override
  String get reminderPickDay => 'Pick at least one day.';

  @override
  String get reminderSavedPendingLocation =>
      'Saved. It\'ll start firing once your prayer-time location is available.';

  @override
  String get reminderEditTitle => 'Edit Reminder';

  @override
  String get reminderNewTitle => 'New Reminder';

  @override
  String get reminderWhat => 'What';

  @override
  String get reminderWhatHint =>
      'Pick a zikr from the library, or just type a title below.';

  @override
  String get reminderChooseZikr => 'Choose from the zikr library';

  @override
  String get reminderChangeZikr => 'Change zikr';

  @override
  String get reminderTitleLabel => 'Title';

  @override
  String get reminderTitleHint => 'e.g. Dua Tawassul';

  @override
  String get reminderRepeatOn => 'Repeat on';

  @override
  String get reminderWhen => 'When';

  @override
  String get reminderFixedTime => 'Fixed time';

  @override
  String get reminderPrayerRelative => 'Prayer-relative';

  @override
  String get commonSaveChanges => 'Save Changes';

  @override
  String get reminderAdd => 'Add Reminder';

  @override
  String get reminderTime => 'Time';

  @override
  String get reminderPrayer => 'Prayer';

  @override
  String get reminderMinutes => 'Minutes';

  @override
  String get reminderBefore => 'Before';

  @override
  String get reminderAfter => 'After';

  @override
  String get reminderPrayerRelativeNote =>
      'Prayer times shift with the calendar, so this schedules the next few weeks\' occurrences and refreshes them each time you open the app.';

  @override
  String qazaCompletedCount(int count) {
    return '$count completed';
  }

  @override
  String get qazaPrayed => 'Prayed';

  @override
  String get qazaFasted => 'Fasted';

  @override
  String qazaEstimatePrayers(String days, String prayers) {
    return '$days of each daily prayer ($prayers prayers)';
  }

  @override
  String qazaEstimateFasts(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted fasts',
      one: '$formatted fast',
    );
    return '$_temp0';
  }

  @override
  String qazaLunarNote(int yearDays, int monthDays) {
    return 'Counted as lunar years of $yearDays days and months of $monthDays days.';
  }

  @override
  String get qazaTitle => 'Qaza Tracker';

  @override
  String get qazaCalculate => 'Calculate my qaza';

  @override
  String get qazaPrayers => 'Prayers';

  @override
  String get qazaFasts => 'Fasts';

  @override
  String get qazaRemaining => 'Qaza remaining';

  @override
  String get commonUndo => 'Undo';

  @override
  String get qazaMissed => 'Missed';

  @override
  String get qazaEditCount => 'Edit count';

  @override
  String get qazaMissedAWhile => 'Missed prayers for a while?';

  @override
  String get qazaMissedAWhileBody =>
      'Enter how long, and we will add one of each daily prayer for every day missed.';

  @override
  String get qazaPrayedFullDay => 'Prayed a full day';

  @override
  String get qazaLoggedFullDay => 'Logged one of each daily prayer';

  @override
  String get qazaAddedToList => 'Added to your qaza list';

  @override
  String get qazaRemainingLabel => 'Remaining';

  @override
  String get qazaCompletedLabel => 'Completed';

  @override
  String get commonClear => 'Clear';

  @override
  String get qazaCalculateBody =>
      'Roughly how long did you not pray? A best estimate is fine - you can adjust any prayer later.';

  @override
  String get qazaPrayersMissedFor => 'Prayers missed for';

  @override
  String get qazaYears => 'Years';

  @override
  String get qazaMonths => 'Months';

  @override
  String get qazaDays => 'Days';

  @override
  String get qazaFastsMissed => 'Fasts missed';

  @override
  String get qazaNumberOfFasts => 'Number of fasts';

  @override
  String get qazaThisAdds => 'This adds to your list:';

  @override
  String get qazaAddToList => 'Add to my list';

  @override
  String get qazaDhuhr => 'Dhuhr';

  @override
  String get qazaAyat => 'Namaz e Ayat';

  @override
  String get qazaOther => 'Other';

  @override
  String audioMobileDataSizedBody(String size) {
    return 'You\'re not on Wi-Fi. This will use about $size of mobile data.';
  }

  @override
  String get audioRemoveDownloadsTitle => 'Remove downloads?';

  @override
  String get audioRemoveDownloadTitle => 'Remove download?';

  @override
  String audioRemoveBody(String subject) {
    return '$subject will stream again, so you\'ll need a connection to listen.';
  }

  @override
  String get audioTheseRecitations => 'These recitations';

  @override
  String get audioThisRecitation => 'This recitation';

  @override
  String audioQuotedName(String name) {
    return '\"$name\"';
  }

  @override
  String audioRemoveFrees(String size) {
    return 'Frees $size.';
  }

  @override
  String get audioDownloadDone => 'Downloaded - plays without a connection';

  @override
  String audioDownloadDoneNamed(String name) {
    return '$name downloaded - plays without a connection';
  }

  @override
  String get audioTheseRecitationsLower => 'these recitations';

  @override
  String get audioThisRecitationLower => 'this recitation';

  @override
  String audioDownloadPartial(int saved, int total) {
    return 'Downloaded $saved of $total.';
  }

  @override
  String audioDownloadFailedNamed(String what) {
    return 'Couldn\'t download $what.';
  }

  @override
  String get audioDownloadOutOfSpace =>
      'Your device is out of space - free some up and try again.';

  @override
  String get audioDownloadUnavailable => 'A recitation is no longer available.';

  @override
  String get audioDownloadCheckConnection =>
      'Check your connection and try again.';

  @override
  String get commonRetry => 'Retry';

  @override
  String commonPercent(int percent) {
    return '$percent%';
  }

  @override
  String audioDownloadMore(int count) {
    return 'Download $count more';
  }

  @override
  String get audioDownloadAll => 'Download all';

  @override
  String get audioDownloadForOffline => 'Download for offline listening';

  @override
  String get audioOfflineCannotDownload =>
      'You\'re offline. Connect to the internet to download.';

  @override
  String get audioMobileDataTitle => 'Download using mobile data?';

  @override
  String get audioMobileDataBody =>
      'You\'re not on Wi-Fi. Recitations can be large, so this may use a lot of mobile data.';

  @override
  String get commonRemove => 'Remove';

  @override
  String get audioDownloading => 'Downloading';

  @override
  String get audioDownloadingEllipsis => 'Downloading…';

  @override
  String get audioDownloadedTooltip =>
      'Downloaded for offline listening. Tap to remove.';

  @override
  String get audioRetryDownload => 'Retry download';

  @override
  String get audioDownloadFailedTooltip =>
      'Download didn\'t finish. Tap to retry.';

  @override
  String get audioDownloadRestTooltip =>
      'Download the rest for offline listening';

  @override
  String get counterSemanticsLabel => 'Current rakaat and sajdah';

  @override
  String counterRakaatCompleted(int count) {
    return '$count rakaat completed';
  }

  @override
  String counterPosition(int rakaat, int sajdah) {
    return 'Rakaat $rakaat  ·  Sajdah $sajdah';
  }

  @override
  String counterSajdahProgress(int done, int total) {
    return '$done of $total sajdahs';
  }

  @override
  String get counterSensorStopped =>
      'The proximity sensor stopped responding. Check the phone position and turn automatic sensing on again.';

  @override
  String get counterStartOverTitle => 'Start over?';

  @override
  String get counterStartOverBody =>
      'Changing the number of rakaat will reset the current prayer count.';

  @override
  String get counterStartOver => 'Start over';

  @override
  String get counterTitle => 'Rakaat Counter';

  @override
  String get counterHowToPlace => 'How to place your phone';

  @override
  String get counterPlaceBelowTurbah => 'Place phone below the turbah';

  @override
  String get counterPlaceBelowTurbahBody =>
      'Lay it flat below the turbah, with the top edge pointing toward it. Keep your forehead’s path clear.';

  @override
  String get counterPrayerLength => 'Prayer length';

  @override
  String get counterSelectRakaat => 'Select the number of rakaat';

  @override
  String get counterComplete => 'Complete';

  @override
  String get counterSajdahDetected => 'Sajdah detected';

  @override
  String get counterSensorReady => 'Sensor ready';

  @override
  String get counterCheckingSensor => 'Checking sensor';

  @override
  String get counterSensingOff => 'Automatic sensing off';

  @override
  String get counterTapHint =>
      'Tap only if a sajdah was not detected automatically';

  @override
  String get counterReady => 'Ready for the first sajdah';

  @override
  String get counterAutomaticHint =>
      'Automatic counting · tap only if one is missed';

  @override
  String get counterManualHint => 'Tap card to add a sajdah manually';

  @override
  String get counterCheckingDevice => 'Checking this device…';

  @override
  String get counterNotAvailable =>
      'Automatic counting is not available on this device.';

  @override
  String get counterObjectDetected =>
      'Object detected. Move away to arm the next count.';

  @override
  String get counterSensorArmed => 'Ready — each detected sajdah counts once.';

  @override
  String get counterSensorOffSubtitle =>
      'Off — turn this on to count sajdahs automatically.';

  @override
  String get counterAutomaticSensing => 'Automatic sensing';

  @override
  String get counterIphoneNote =>
      'On iPhone, the display may turn off briefly while the sensor is covered. Sensor position and range vary by model.';

  @override
  String get counterAndroidNote =>
      'Sensor position and range vary by phone. Some Android phones use a less reliable virtual proximity sensor.';

  @override
  String get counterPhonePlacement => 'Phone placement';

  @override
  String get counterPlacementBody =>
      'Place the phone flat below the turbah, with its top edge and sensor pointing toward it. Keep the phone completely out of the path of your forehead.';

  @override
  String get counterPlacementTest =>
      'Before beginning, enable the sensor and test it with your hand. Move your hand away after each test so the next count can arm.';

  @override
  String quranJuzNumber(int number) {
    return 'Juz $number';
  }

  @override
  String quranCopiedVerse(String verse) {
    return 'Copied $verse';
  }

  @override
  String get quranRemoveFromSaved => 'Remove from saved';

  @override
  String get quranSaveVerse => 'Save verse';

  @override
  String quranRemovedVerse(String verse) {
    return 'Removed $verse';
  }

  @override
  String quranSavedVerse(String verse) {
    return 'Saved $verse';
  }

  @override
  String zikrPartNumber(int number) {
    return 'Part $number';
  }

  @override
  String zikrBookmarkMoveHint(String icon) {
    return 'Bookmarked. To move it later, drag the $icon on the \"Bookmarked\" label to another line.';
  }

  @override
  String get quranCopyVerse => 'Copy verse';

  @override
  String get quranCopyLink => 'Copy link';

  @override
  String get quranLinkCopied => 'Link copied';

  @override
  String get quranShareVerse => 'Share verse';

  @override
  String get zikrMerits => 'Merits';

  @override
  String get zikrReportThanks => 'Thanks - we\'ll take a look.';

  @override
  String get zikrReportFailed => 'Could not send the report. Please try again.';

  @override
  String get zikrSuggestCorrection => 'Suggest a Correction';

  @override
  String get zikrSelectedText => 'Selected text';

  @override
  String get zikrCorrectionHint => 'What should it say instead? (optional)';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get zikrSetReminder => 'Set Reminder';

  @override
  String get zikrUnableToOpen => 'Unable to open this dua.';

  @override
  String get zikrComingSoon => 'Coming soon...';

  @override
  String get zikrHideCounter => 'Hide counter';

  @override
  String deleteAccountSignInFailed(String error) {
    return 'Sign in failed: $error';
  }

  @override
  String deleteAccountSignOutFailed(String error) {
    return 'Sign out failed: $error';
  }

  @override
  String deleteAccountFailed(String error) {
    return 'Error deleting account: $error';
  }

  @override
  String deleteAccountSignedInAs(String account) {
    return 'You are signed in as $account.';
  }

  @override
  String get deleteAccountSignedIn => 'Signed in successfully.';

  @override
  String get deleteAccountSignedOut => 'Signed out.';

  @override
  String get deleteAccountConfirmTitle => 'Delete account?';

  @override
  String get deleteAccountConfirmBody =>
      'This permanently deletes your Shia Companion account and synced favorites.';

  @override
  String get deleteAccountDone => 'Account deleted successfully.';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountHeading => 'Manage your Shia Companion account';

  @override
  String get deleteAccountSignInPrompt =>
      'Sign in to review and permanently delete the account tied to your synced favorites.';

  @override
  String get deleteAccountWhatGetsDeleted => 'What gets deleted';

  @override
  String get deleteAccountItemSignIn =>
      'Your Shia Companion account sign-in record.';

  @override
  String get deleteAccountItemFavorites =>
      'Your synced favorites and qaza tracker stored for that account.';

  @override
  String get deleteAccountItemPreferences =>
      'Your synced reading preferences — Hijri date adjustment and font choices.';

  @override
  String get deleteAccountItemAnalytics =>
      'Anonymous analytics or crash reports already collected may remain in aggregate form.';

  @override
  String get deleteAccountCompleted =>
      'Your account deletion request has completed.';

  @override
  String get deleteAccountCompletedNote =>
      'If you sign in again later, a brand new account will be created.';

  @override
  String get deleteAccountWebSteps =>
      'Use the Google sign-in button below, then confirm deletion.';

  @override
  String get deleteAccountAppSteps =>
      'Open Settings in the app and use Delete My Account.';

  @override
  String get deleteAccountSigningIn => 'Signing in...';

  @override
  String get deleteAccountDeleting => 'Deleting...';

  @override
  String get deleteAccountButton => 'Delete my account';

  @override
  String get deleteAccountSignOut => 'Sign out';

  @override
  String get deleteAccountHelp =>
      'Need help? Email developer110@hotmail.com and include the email address tied to your account.';

  @override
  String statsBestStreak(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Best: $days days',
      one: 'Best: 1 day',
    );
    return '$_temp0';
  }

  @override
  String get statsTodayDone => 'Today: done';

  @override
  String get statsTodayNotYet => 'Today: not yet';

  @override
  String statsDaysToGoal(int remaining, Object goal) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$remaining more days to a $goal-day streak',
      one: '1 more day to a $goal-day streak',
    );
    return '$_temp0';
  }

  @override
  String statsUpdatedHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Updated $hours hours ago',
      one: 'Updated 1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String statsUpdatedOn(String date) {
    return 'Updated $date';
  }

  @override
  String statsAllTime(String count) {
    return '$count all time';
  }

  @override
  String statsCommunityNote(String updated) {
    return 'Anonymous totals from everyone using the app. $updated.';
  }

  @override
  String get statsTitle => 'My Stats';

  @override
  String get statsYourMostRecited => 'Your most recited';

  @override
  String get statsStreakStart =>
      'Finish reading a dua, ziyarat or surah and your streak begins.';

  @override
  String get statsWelcomeBack => 'Welcome back - every day is a fresh start.';

  @override
  String get statsDoneTodayFirst =>
      'Done for today. Come back tomorrow to start a streak.';

  @override
  String get statsDoneToday =>
      'Done for today - see you tomorrow, in sha Allah.';

  @override
  String get statsReadToday => 'Read something today to keep it going.';

  @override
  String get statsDayStreak => 'day streak';

  @override
  String get statsToday => 'Today';

  @override
  String get statsPrivateSynced =>
      'Your stats are private and sync across devices signed in to your account.';

  @override
  String get statsPrivateLocal =>
      'Your stats are private and kept on this device. Sign in from Preferences to keep them across devices.';

  @override
  String get statsUpdatedWithinHour => 'Updated within the hour';

  @override
  String get statsAcrossCommunity => 'Across the community';

  @override
  String get statsRecitedThisWeek =>
      'duas, ziyarats and surahs recited this week';

  @override
  String get statsMostRecitedThisWeek => 'Most recited this week';

  @override
  String quranSurahNumber(int number) {
    return 'Surah $number';
  }

  @override
  String get listenQuranTextFailed =>
      'Could not read the Quran text on this device.';

  @override
  String get listenRecogniserStopped =>
      'The recogniser stopped unexpectedly. Try again.';

  @override
  String get listenNothingRecognised =>
      'Nothing recognisable came through. Try again, a little closer to the reciter.';

  @override
  String get listenCouldNotPlace =>
      'Could not place that in the Quran. Try reciting a little more.';

  @override
  String get listenMicPermissionWeb =>
      'Listening needs microphone access. You can grant it in this site\'s permissions in your browser.';

  @override
  String get listenMicPermission =>
      'Listening needs microphone access. You can grant it in your device settings.';

  @override
  String get listenBrowserUnsupported =>
      'This browser cannot recognise speech. Chrome, Edge and Safari can.';

  @override
  String get listenDeviceUnsupported =>
      'This device has no speech recogniser available.';

  @override
  String get listenNoArabic =>
      'This device has no Arabic speech recognition installed. Adding Arabic in your device\'s language settings enables it.';

  @override
  String get listenStartFailed => 'Could not start listening. Try again.';

  @override
  String get listenTitle => 'Listen and follow';

  @override
  String get listenGettingReady => 'Getting ready…';

  @override
  String get listenListening => 'Listening…';

  @override
  String get listenHoldPhone => 'Hold the phone towards the recitation.';

  @override
  String get listenFindNow => 'Find the verse now';

  @override
  String get listenFinding => 'Finding the verse…';

  @override
  String get listenWhichVerse => 'Which verse was it?';

  @override
  String get listenAgain => 'Listen again';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String flightDepartureDateAt(String airport) {
    return 'Departure date at $airport';
  }

  @override
  String flightArrivalDateAt(String airport) {
    return 'Arrival date at $airport';
  }

  @override
  String flightDepartureTimeAt(String airport) {
    return 'Departure time (local at $airport)';
  }

  @override
  String flightArrivalTimeAt(String airport) {
    return 'Arrival time (local at $airport)';
  }

  @override
  String flightDurationTooLong(String duration) {
    return 'That works out to $duration in the air. Check the arrival date.';
  }

  @override
  String get flightFrom => 'From';

  @override
  String get flightTo => 'To';

  @override
  String get flightDeparts => 'Departs';

  @override
  String get flightArrives => 'Arrives';

  @override
  String get flightDepartureAirport => 'Departure airport';

  @override
  String get flightArrivalAirport => 'Arrival airport';

  @override
  String get flightChooseDepartureFirst =>
      'Choose the departure airport first.';

  @override
  String get flightChooseArrivalFirst => 'Choose the arrival airport first.';

  @override
  String get flightChooseBothAirports => 'Choose both airports.';

  @override
  String get flightSetTimes => 'Set the departure and arrival times.';

  @override
  String get flightAirportsMustDiffer =>
      'Departure and arrival airports must be different.';

  @override
  String get flightTimeZoneUnresolved =>
      'Could not resolve the time zone for one of those airports.';

  @override
  String get flightArrivalBeforeDeparture =>
      'Arrival is before departure once time zones are applied. Check the arrival date — overnight flights land the next day.';

  @override
  String get flightAdd => 'Add flight';

  @override
  String get flightDepartsHint => 'Local time at the departure airport';

  @override
  String get flightArrivesHint => 'Local time at the arrival airport';

  @override
  String get flightNumberLabel => 'Flight number (optional)';

  @override
  String get flightSaveChanges => 'Save changes';

  @override
  String get flightSave => 'Save flight';

  @override
  String get flightTicketNote =>
      'Enter the times exactly as they appear on your ticket — each one in the local time of its own airport.';

  @override
  String get flightChooseAirport => 'Choose an airport';

  @override
  String get flightChooseDateTime => 'Choose date and time';

  @override
  String get widgetIslamicCalendar => 'Islamic Calendar';

  @override
  String get widgetFavorites => 'Favorites';

  @override
  String get widgetNoFavorites => 'No favorites yet';

  @override
  String get widgetTodaysRecitations => 'Today\'s Recitations';

  @override
  String get widgetOpenAppToRefresh => 'Open app to refresh';

  @override
  String get widgetUpNext => 'Up Next';

  @override
  String get widgetPrayerTimes => 'Prayer Times';

  @override
  String get widgetLocationNeeded => 'Location needed';

  @override
  String get widgetSavedLocation => 'Saved location';

  @override
  String get widgetSetLocation => 'Set location';

  @override
  String get widgetOpenApp => 'Open app';

  @override
  String get widgetRefreshSchedule => 'Refresh schedule';

  @override
  String get commonToday => 'Today';

  @override
  String get commonTomorrow => 'Tomorrow';

  @override
  String quranSurahAyah(String surah, int ayah) {
    return '$surah $ayah';
  }

  @override
  String trackNameTaken(String name) {
    return 'There is already a track called \"$name\"';
  }

  @override
  String get trackNameRequired => 'Give the track a name';

  @override
  String get trackBeginning => 'The beginning';

  @override
  String get trackNew => 'New recitation track';

  @override
  String get trackName => 'Name';

  @override
  String get trackNameHint => 'e.g. Family, Tahajjud';

  @override
  String get trackReadBy => 'Read by';

  @override
  String get trackBySurah => 'Surah';

  @override
  String get trackByJuz => 'Juz (Para)';

  @override
  String get trackContinueFrom => 'Continue from';

  @override
  String get trackStartFrom => 'Start from';

  @override
  String get trackStartAt => 'Start at';

  @override
  String get trackEditNote =>
      'Your track moves on by itself as you read. Change this only to pick up somewhere else.';

  @override
  String get trackNewNote =>
      'You can change these anytime from the track card.';

  @override
  String get trackCreate => 'Create track';

  @override
  String notifDefaultSoundSubtitle(String sound) {
    return '$sound · used unless a time below overrides it';
  }

  @override
  String notifCustomSound(String file) {
    return 'Custom: $file';
  }

  @override
  String notifPrayerSound(String prayer) {
    return '$prayer sound';
  }

  @override
  String notifFollows(String sound) {
    return 'Follows $sound';
  }

  @override
  String get notifDefaultSound => 'Default sound';

  @override
  String get notifTimesHeading => 'TIMES';

  @override
  String get notifAudioUnreadable => 'That audio file could not be read.';

  @override
  String get notifPickFailed => 'Could not pick that file. Try again.';

  @override
  String get notifPlayingSample => 'Playing a sample in a moment…';

  @override
  String get notifUseDefault => 'Use default';

  @override
  String get notifOwnSoundNote =>
      'This time keeps its own sound. Everything else follows the default.';

  @override
  String get notifDefaultNote =>
      'Every time follows this unless you give it a sound of its own.';

  @override
  String get notifPreview => 'Preview';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutDedication =>
      'We thank Almighty Allah and His beloved Fourteen Infallibles (a.s.) for Their help which made us able to share this humble work with the Momeneen. We dedicate the app to them and the following Marhumeems:\n\nMarhooma Amina Mohammed Raza Jassani\nMarhoom Haji Mohammad Raza Jassani\nMarhoom Haji Yusufali Bhojani\n\n\nPlease recite Surah Fateha for Marhumeen and Marhumaat\n\nFor feedback, queries or suggestions contact :';

  @override
  String get aboutNoEmailApp => 'No e-mail app found';

  @override
  String get aboutCredits => 'Credits';

  @override
  String get aboutCreditAudio =>
      'Recitation audio is hosted on our own servers; the recordings are used with duas.org\'s kind permission.';

  @override
  String get aboutCreditScheherazade =>
      'Arabic is set in Scheherazade New by SIL Global, used under the SIL Open Font License.';

  @override
  String get aboutCreditTanzil =>
      'The Uthmani Quran text, shown with Scheherazade, is from the Tanzil Project, used under Creative Commons Attribution 3.0.';

  @override
  String get aboutCreditQuranWbw =>
      'The IndoPak Quran text and font, shown with Qalam, are from QuranWBW.com. The licence to use the Quran text and font unmodified was received from QuranWBW.com, the original contributor.';

  @override
  String get aboutCreditIndoPakFont =>
      'Font: AlQuran IndoPak by QuranWBW, made by Ayman Siddiqui, based on the Al Qalam Quran Majeed fonts, with ayah numbers from the KFGQPC Nastaleeq font. © Al Qalam © Ghandhara © KFGQPC © Ayman Siddiqui. Credits: Abdul Majeed Khan, Arif Karim, Shakir-ul-Qadree, Jawad. Quran text: typemybook.com, originally by InPage.';

  @override
  String downloadsRemoveAllBody(String size) {
    return 'Every recitation will stream again, so you\'ll need a connection to listen. Frees $size.';
  }

  @override
  String downloadsOlderSubtitle(int count, String size) {
    return '$count no longer used by any dua · $size';
  }

  @override
  String get downloadsRemoveAllTitle => 'Remove all downloads?';

  @override
  String get downloadsRemoveAll => 'Remove all';

  @override
  String get downloadsEmpty => 'No downloads yet';

  @override
  String get downloadsEmptyBody =>
      'Download a recitation to listen without a connection - tap the download button in a dua\'s audio player, or Download all on a playlist.';

  @override
  String get downloadsOlder => 'Older recordings';

  @override
  String get downloadsRemoveOlder => 'Remove older recordings';

  @override
  String get hijriMonth1 => 'Muharram';

  @override
  String get hijriMonth2 => 'Safar';

  @override
  String get hijriMonth3 => 'Rabi\' Al-Awwal';

  @override
  String get hijriMonth4 => 'Rabi\' Al-Thani';

  @override
  String get hijriMonth5 => 'Jumada Al-Awwal';

  @override
  String get hijriMonth6 => 'Jumada Al-Thani';

  @override
  String get hijriMonth7 => 'Rajab';

  @override
  String get hijriMonth8 => 'Sha\'aban';

  @override
  String get hijriMonth9 => 'Ramadan';

  @override
  String get hijriMonth10 => 'Shawwal';

  @override
  String get hijriMonth11 => 'Dhu Al-Qi\'dah';

  @override
  String get hijriMonth12 => 'Dhu Al-Hijjah';

  @override
  String get hijriMonthShort1 => 'Muh';

  @override
  String get hijriMonthShort2 => 'Saf';

  @override
  String get hijriMonthShort3 => 'Rab I';

  @override
  String get hijriMonthShort4 => 'Rab II';

  @override
  String get hijriMonthShort5 => 'Jum I';

  @override
  String get hijriMonthShort6 => 'Jum II';

  @override
  String get hijriMonthShort7 => 'Raj';

  @override
  String get hijriMonthShort8 => 'Sha';

  @override
  String get hijriMonthShort9 => 'Ram';

  @override
  String get hijriMonthShort10 => 'Shaw';

  @override
  String get hijriMonthShort11 => 'Dhul Q';

  @override
  String get hijriMonthShort12 => 'Dhul H';

  @override
  String prayerUpdatedAgo(String age) {
    return 'updated $age';
  }

  @override
  String get prayerNextDay => '(next day)';

  @override
  String get prayerLocating => 'Locating…';

  @override
  String get prayerForYourLocation => 'Prayer times for your location';

  @override
  String get prayerFindingLocation => 'Finding your location';

  @override
  String get prayerAppearSoon => 'Prayer times will appear in a moment';

  @override
  String get prayerTapToRetry => 'Tap to try again';

  @override
  String get prayerLocationUnavailable => 'Location not available';

  @override
  String get prayerTapToEnableLocation => 'Tap here to enable location';

  @override
  String calendarNotificationsSomeOn(int enabled, int total) {
    return '$enabled of $total on';
  }

  @override
  String get calendarNoEvent => 'No event listed for this date.';

  @override
  String get calendarNotificationsAllOff => 'Off for every prayer';

  @override
  String get readingFineTune =>
      'Fine-tune zikr text. Applied on top of App text size in Settings.';

  @override
  String get readingArabicFontSize => 'Arabic Font Size';

  @override
  String get readingEnglishFontSize => 'English Font Size';

  @override
  String get readingArabicFont => 'Arabic Font';

  @override
  String get readingKeepScreenOn => 'Keep screen on while reciting Zikr';

  @override
  String get readingFocusMode => 'Focus mode';

  @override
  String get readingFocusModeSubtitle =>
      'Hide the progress bar and action bar while reading. Scroll up or tap to bring them back.';

  @override
  String get readingShareAsImage => 'Share Zikr as Image';

  @override
  String get readingShareAsImageSubtitle =>
      'Create a formatted image when sharing.';

  @override
  String get readingShowTransliteration => 'Show Transliteration';

  @override
  String get readingShowTranslation => 'Show Translation';

  @override
  String get readingArabicParagraph => 'Show Arabic as Paragraph';

  @override
  String get readingArabicParagraphOn =>
      'Flow the Arabic verses together as one paragraph instead of separate lines.';

  @override
  String get readingArabicParagraphOff =>
      'Turn off Transliteration and Translation above to use this.';

  @override
  String pickerJuzRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String pickerSurahDetails(String ayahs, String juz) {
    return '$ayahs · Juz $juz';
  }

  @override
  String quranAyahCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ayahs',
      one: '1 ayah',
    );
    return '$_temp0';
  }

  @override
  String pickerJuzFrom(String start) {
    return 'From $start';
  }

  @override
  String pickerAyahSingle(int ayah) {
    return 'ayah $ayah';
  }

  @override
  String pickerAyahRange(int from, int to) {
    return 'ayahs $from–$to';
  }

  @override
  String get pickerThirtyJuz => 'There are 30 juz';

  @override
  String get pickerTryVerse => 'Try a verse like 33:33, or juz 22';

  @override
  String get pickerSearchHint => 'Go to a verse - 33:33, 18, juz 22';

  @override
  String get pickerChooseVerse => 'Choose a verse';

  @override
  String get pickerAllJuz => 'All juz';

  @override
  String get pickerAllSurahs => 'All surahs';

  @override
  String get pickerChoose => 'Choose';

  @override
  String quranFromPosition(String position) {
    return 'From $position';
  }

  @override
  String quranPercentRead(String percent) {
    return '$percent% of the Quran';
  }

  @override
  String quranEditTrack(String track) {
    return 'Edit $track track';
  }

  @override
  String get quranTitle => 'Quran';

  @override
  String get quranRecentSessions => 'Recent sessions';

  @override
  String get quranTabSurahs => 'Surahs';

  @override
  String get quranTabJuz => 'Juz';

  @override
  String get quranTabCollections => 'Collections';

  @override
  String get quranStartReading => 'Start reading';

  @override
  String get quranNewTrack => 'New track';

  @override
  String get quranGoToVerseError => 'Try something like 23:56';

  @override
  String get quranGoToVerseHint => 'Go to verse, e.g. 23:56';

  @override
  String get quranGo => 'Go';

  @override
  String get statsMetricVerses => 'Verses';

  @override
  String get statsMetricZikrs => 'Zikrs';

  @override
  String get statsMetricQaza => 'Qaza';

  @override
  String get statsMetricVersesLower => 'verses';

  @override
  String get statsMetricZikrsLower => 'zikrs';

  @override
  String get statsMetricQazaLower => 'qaza';

  @override
  String statsVerseCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted verses',
      one: '$formatted verse',
    );
    return '$_temp0';
  }

  @override
  String statsZikrCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted zikrs',
      one: '$formatted zikr',
    );
    return '$_temp0';
  }

  @override
  String statsQazaCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted qaza',
    );
    return '$_temp0';
  }

  @override
  String get statsPeriodWeek => 'Week';

  @override
  String get statsPeriodMonth => 'Month';

  @override
  String get statsPeriodAllTime => 'All time';

  @override
  String statsCaptionWeek(String metric) {
    return '$metric in the last 7 days';
  }

  @override
  String statsCaptionMonth(String metric) {
    return '$metric in the last 30 days';
  }

  @override
  String statsCaptionAllTime(String metric) {
    return '$metric in total';
  }

  @override
  String get statsHistory => 'History';

  @override
  String statsBestMonth(String month, String count) {
    return 'Best month: $month · $count';
  }

  @override
  String statsBestDay(String day, String count, String average) {
    return 'Best day: $day · $count · $average a day on average';
  }

  @override
  String get statsNew => 'New';

  @override
  String statsVersusBefore(String count) {
    return 'vs $count before';
  }

  @override
  String statsSessionCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted sessions',
      one: '$formatted session',
    );
    return '$_temp0';
  }

  @override
  String statsVersesRecited(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted verses recited',
      one: '$formatted verse recited',
    );
    return '$_temp0';
  }

  @override
  String statsLastOn(String date) {
    return 'last $date';
  }

  @override
  String statsVersesLeft(String count) {
    return '$count verses left to complete a khatm';
  }

  @override
  String statsJuzCoverage(int juz, int percent) {
    return 'Juz $juz: $percent%';
  }

  @override
  String statsJuzComplete(int count) {
    return '$count of 30 juz complete';
  }

  @override
  String get statsQuranProgress => 'Quran progress';

  @override
  String get statsQuranEmpty =>
      'Open a surah and start reading - the verses you recite are tracked here automatically, with your progress towards a full khatm.';

  @override
  String get statsRecitedTill => 'Recited till';

  @override
  String get statsNotStarted => 'Not started';

  @override
  String get statsJuzDone => 'Juz done';

  @override
  String get statsKhatmComplete => 'Khatm complete - may it be accepted';

  @override
  String reminderAtPrayer(String prayer) {
    return 'At $prayer';
  }

  @override
  String reminderMinutesAfter(int minutes, String prayer) {
    return '$minutes min after $prayer';
  }

  @override
  String reminderMinutesBefore(int minutes, String prayer) {
    return '$minutes min before $prayer';
  }

  @override
  String azanPlaying(String prayer) {
    return '$prayer Azan is playing';
  }

  @override
  String get libraryNeedsNetwork =>
      'Library browsing needs a network connection.';

  @override
  String get libraryChaptersFailed =>
      'Unable to load chapters. Please try again.';

  @override
  String get libraryReadingNeedsNetwork =>
      'Reading books needs a network connection.';

  @override
  String get libraryChapterFailed =>
      'Unable to load this chapter. Please try again.';

  @override
  String get menuCalendarPrayerTimes => 'Calendar & Prayer Times';

  @override
  String get menuFavorites => 'Favorites';

  @override
  String get menuTodaysRecitations => 'Today\'s Recitations';

  @override
  String get menuTaqeebat => 'Taqeebat e Namaz';

  @override
  String get menuNamaz => 'Namaz';

  @override
  String get menuDuas => 'Duas';

  @override
  String get menuZiyarats => 'Ziyarats';

  @override
  String get menuSurahs => 'Surahs';

  @override
  String get menuAamaal => 'Aamaal';

  @override
  String get menuLibrary => 'Library';

  @override
  String get menuMunajaat => 'Munajaat';

  @override
  String get menuBaaqeyaat => 'Baaqeyaat As Saalehaat';

  @override
  String get menuQiblaFinder => 'Qibla Finder';

  @override
  String get menuTasbeehCounter => 'Tasbeeh Counter';

  @override
  String get menuQazaTracker => 'Qaza Tracker';

  @override
  String get menuRakaatCounter => 'Rakaat Counter';

  @override
  String get menuPrayerTimesInFlight => 'Prayer Times in Flight';

  @override
  String get menuPreferences => 'Preferences';

  @override
  String get menuQuran => 'Quran';

  @override
  String get menuPlaylists => 'Playlists';

  @override
  String get menuMyStats => 'My Stats';

  @override
  String get menuCalendar => 'Calendar';

  @override
  String audioTrackNumber(int number) {
    return 'Track $number';
  }

  @override
  String get audioPauseRecitation => 'Pause recitation';

  @override
  String get audioPlayRecitation => 'Play recitation';

  @override
  String get audioList => 'Audio list';

  @override
  String get audioOfflineNotDownloaded =>
      'You\'re offline and this recitation isn\'t downloaded';

  @override
  String get audioLoadFailed => 'This recitation couldn\'t be loaded';

  @override
  String get audioClosePlayer => 'Close player';

  @override
  String get audioChooseRecording => 'Choose recording';

  @override
  String get audioRecitation => 'Recitation';

  @override
  String get audioRecitationAudio => 'Recitation audio';

  @override
  String librarySavedOffline(String book) {
    return '$book saved for offline.';
  }

  @override
  String librarySaveFailed(String error) {
    return 'Unable to save book: $error';
  }

  @override
  String libraryProgress(String chapter, int page, int pages) {
    return '$chapter - Page $page of $pages';
  }

  @override
  String get librarySavedChapterGone => 'Saved chapter is no longer available';

  @override
  String get libraryUnavailable => 'Library unavailable';

  @override
  String get libraryNoBooks => 'No books found';

  @override
  String get libraryEmpty => 'The library is empty right now.';

  @override
  String get libraryContinueReading => 'Continue Reading';

  @override
  String get libraryRequestBook => 'Request a Book';

  @override
  String get libraryRequestBookSubtitle =>
      'Can\'t find a book? Ask us to add it.';

  @override
  String flightRemoveBody(String flight) {
    return '$flight will be removed from your saved flights.';
  }

  @override
  String flightLands(String duration, String time, String airport) {
    return '$duration · lands $time $airport time';
  }

  @override
  String get flightRemoveTitle => 'Remove flight?';

  @override
  String get flightRemove => 'Remove flight';

  @override
  String get flightNoneSaved => 'No flights saved';

  @override
  String get flightNoneSavedBody =>
      'Add your flight and this page will work out when each prayer comes in along the route — shown in both your departure and arrival city\'s time.';

  @override
  String librarySavedForOffline(String title) {
    return '$title saved for offline';
  }

  @override
  String librarySaveFailedShort(String error) {
    return 'Save failed: $error';
  }

  @override
  String get libraryOfflineRemoved => 'Offline copy removed';

  @override
  String get libraryShareBook => 'Share book';

  @override
  String get libraryRemoveOffline => 'Remove offline copy';

  @override
  String get librarySaveOffline => 'Save book offline';

  @override
  String get libraryChaptersUnavailable => 'Chapters unavailable';

  @override
  String get libraryNoChapters => 'No chapters found';

  @override
  String get libraryNoChaptersBody => 'This book has no chapters right now.';

  @override
  String quranMoveEntry(String entry) {
    return 'Move \"$entry\"';
  }

  @override
  String get quranNoSessions =>
      'No sessions yet. Open a surah and start reading - the verses you recite are logged here automatically.';

  @override
  String get quranMoveToLabel => 'Move to another label';

  @override
  String get quranNewLabel => 'Or a new label';

  @override
  String get quranMove => 'Move';

  @override
  String get quranCollectionDuas => 'Duas';

  @override
  String get quranCollectionImamAli => 'Imam Ali (a.s.)';

  @override
  String get quranCollectionImamMahdi => 'Imam al-Mahdi (a.t.f.s.)';

  @override
  String get quranCollectionProphets => 'Prophets';

  @override
  String get quranCollectionSaved => 'Saved';

  @override
  String get quranFromTheQuran => 'From the Quran';

  @override
  String get quranNoSavedVerses => 'No saved verses yet';

  @override
  String get quranNoSavedVersesBody =>
      'Tap a verse while reading to keep it here.';

  @override
  String get libraryNextChapter => 'Next chapter';

  @override
  String get libraryPreviousChapter => 'Previous chapter';

  @override
  String get libraryNextPage => 'Next page';

  @override
  String get libraryPreviousPage => 'Previous page';

  @override
  String libraryNextChapterNamed(String chapter) {
    return 'Next chapter: $chapter';
  }

  @override
  String libraryPreviousChapterNamed(String chapter) {
    return 'Previous chapter: $chapter';
  }

  @override
  String libraryNextShort(String chapter) {
    return 'Next: $chapter';
  }

  @override
  String libraryPreviousShort(String chapter) {
    return 'Previous: $chapter';
  }

  @override
  String get libraryShareChapter => 'Share chapter';

  @override
  String get libraryChapterUnavailable => 'Chapter unavailable';

  @override
  String get libraryDecreaseFont => 'Decrease font size';

  @override
  String get libraryIncreaseFont => 'Increase font size';

  @override
  String get azaanTakbirName => 'Takbir Only';

  @override
  String get azaanTakbirDescription => 'Short takbir notification sound';

  @override
  String get azaanFullName => 'Full Azan';

  @override
  String get azaanFullDescription => 'Full azan, played automatically';

  @override
  String get azaanFullIosDescription =>
      'The notification plays the Takbir; tap it to hear the full azan';

  @override
  String get azaanSystemDefaultName => 'System Default';

  @override
  String get azaanSystemDefaultDescription =>
      'Use your device\'s default notification sound';

  @override
  String get azaanSilentName => 'Silent';

  @override
  String get azaanSilentDescription => 'Notification banner only (no sound)';

  @override
  String get azaanCustomName => 'Custom Audio';

  @override
  String get azaanCustomDescription => 'Choose an audio file from your device';

  @override
  String get ratingEnjoying => 'Enjoying Shia Companion?';

  @override
  String get ratingEnjoyingBody =>
      'We\'d love to hear how it\'s going for you - your feedback helps us keep improving the app.';

  @override
  String get ratingNotReally => 'Not really';

  @override
  String get ratingYes => 'Yes!';

  @override
  String get ratingSorry => 'Sorry to hear that';

  @override
  String get ratingSorryBody =>
      'Would you mind telling us what\'s not working? It helps us improve the app.';

  @override
  String get ratingNoThanks => 'No thanks';

  @override
  String get ratingSendFeedback => 'Send feedback';

  @override
  String get azaanOptInIntro =>
      'Shia Companion can send you a notification at Fajr, Zuhr and Maghrib and play the azan.';

  @override
  String get azaanOptInIosNote =>
      'On iPhone the notification plays a short takbir. Choose Full Azan in Settings to hear the whole azan when you tap it.';

  @override
  String get azaanOptInChangeLater =>
      'You can change which prayers notify you, pick a different sound, or turn this off again at any time in Settings.';

  @override
  String get azaanOptInTitle => 'Play the azan at prayer times?';

  @override
  String get azaanOptInNotNow => 'Not now';

  @override
  String get azaanOptInEnable => 'Enable azan';

  @override
  String reminderRemoveBody(String title) {
    return 'This removes the reminder for \"$title\". You can add it again any time.';
  }

  @override
  String get reminderRemoveTitle => 'Remove reminder?';

  @override
  String get reminderAddTooltip => 'Add reminder';

  @override
  String get reminderNone => 'No reminders yet';

  @override
  String get reminderNoneBody =>
      'Tap + to get reminded about a zikr or dua on the days you choose — like Tawassul every Tuesday, or Dua Kumail after Maghrib on Thursday.';

  @override
  String tasbeehBeepNumber(int number) {
    return 'Beep $number';
  }

  @override
  String get tasbeehHelp =>
      'Tap the counter circle to count. The beep will play at the milestones below.';

  @override
  String get tasbeehEnableBeep => 'Enable beep';

  @override
  String get tasbeehTapToCount => 'Tap to count';

  @override
  String get tasbeehMinusOne => 'Minus one';

  @override
  String get tasbeehReset => 'Reset';

  @override
  String get requestThanks => 'Thanks - we\'ve received your request.';

  @override
  String get requestFailed => 'Could not send the request. Please try again.';

  @override
  String get requestBookTitle => 'Book title';

  @override
  String get requestZikrName => 'Name of dua, ziyarat, etc.';

  @override
  String get requestBookDetails => 'Author, translator or link (optional)';

  @override
  String get requestZikrDetails => 'Source, occasion or link (optional)';

  @override
  String get commonSend => 'Send';

  @override
  String searchOneMatch(String source) {
    return '1 match in $source';
  }

  @override
  String searchMatches(int count, String source) {
    return '$count matches in $source';
  }

  @override
  String get searchSourceZikr => 'Zikr';

  @override
  String get searchSourceQuran => 'Quran';

  @override
  String get searchSourceLibrary => 'Library';

  @override
  String get searchTitleOrUid => 'Search title or UID';

  @override
  String get searchShow => 'Show';

  @override
  String get searchNoResults => 'No results';

  @override
  String get searchRequestIt => 'Request it';

  @override
  String widgetPrayerTimesHelp(int min, int max) {
    return 'Pick $min to $max times. Sunrise, Sunset and Midnight are the deadlines a prayer has to be offered before.';
  }

  @override
  String get accountSessionExpired =>
      'Your session expired. Please sign in again and retry deletion.';

  @override
  String get accountReauthenticate =>
      'For security, please sign in again and then retry deleting your account.';

  @override
  String get accountPopupClosed =>
      'Sign-in window closed before the action finished.';

  @override
  String get accountNetworkError =>
      'Network error. Please check your connection and try again.';

  @override
  String get commonSomethingWentWrong =>
      'Something went wrong. Please try again.';

  @override
  String zikrTabNumber(int number) {
    return 'Tab $number';
  }

  @override
  String get zikrBookmarked => 'Bookmarked';

  @override
  String get zikrMoveBookmarkHere => 'Move bookmark here';

  @override
  String get zikrDragBookmarkHint =>
      'Drag to move the bookmark to another line';

  @override
  String get durationUnderOneMinute => 'under 1 min';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hrs',
      one: '1 hr',
    );
    return '$_temp0';
  }

  @override
  String durationHoursMinutes(String hours, int minutes) {
    return '$hours $minutes min';
  }

  @override
  String zikrReadingTime(String duration) {
    return '$duration read';
  }

  @override
  String get zikrProgressCompleted => 'Completed';

  @override
  String airportNothingMatched(String query) {
    return 'Nothing matched \"$query\". Try the three letter code instead.';
  }

  @override
  String get airportSearchLabel => 'Airport code or city';

  @override
  String get airportSearchHint => 'e.g. SFO, Istanbul, Najaf';

  @override
  String get airportSearchTitle => 'Search for an airport';

  @override
  String get airportSearchDetail =>
      'Type an airport code, a city, or a country name.';

  @override
  String get airportNoneFound => 'No airports found';

  @override
  String get counterTapAnywhere => 'Tap anywhere to count';

  @override
  String get counterHoldToMove => 'Hold and drag to move';

  @override
  String get counterAddOne => 'Add one';

  @override
  String azanPaused(String prayer) {
    return '$prayer Azan is paused';
  }

  @override
  String get azanPrayerFallback => 'Prayer';

  @override
  String get reminderChannelDescription =>
      'Reminders for zikr and duas you scheduled';

  @override
  String get locationOff => 'Location services are off';

  @override
  String get locationPermissionShort => 'Location permission needed';

  @override
  String get locationNoFix => 'Couldn\'t get a location fix';

  @override
  String get locationUpdateFailed => 'Couldn\'t update location';

  @override
  String quranPreviousUnit(String unit) {
    return 'Previous $unit';
  }

  @override
  String quranNextUnit(String unit) {
    return 'Next $unit';
  }

  @override
  String get quranUnitSurah => 'surah';

  @override
  String hadithNoResults(String query) {
    return 'No results found for \"$query\"';
  }

  @override
  String get hadithTitle => 'Hadith';

  @override
  String get hadithSearchHint => 'Search hadith...';

  @override
  String get hadithNone => 'No hadith available';

  @override
  String favoritesReorder(String title) {
    return 'Reorder $title';
  }

  @override
  String get favoritesReorderFailed =>
      'Could not save the new order. Try again.';

  @override
  String get favoritesNone => 'No favorites yet.';

  @override
  String linkNotFoundRequested(String link) {
    return 'Requested link: $link';
  }

  @override
  String get linkNotFoundTitle => 'Link Not Found';

  @override
  String get linkNotFoundBody => 'We couldn\'t find this content.';

  @override
  String get linkNotFoundGoHome => 'Go Home';

  @override
  String get whatsNewTitle => 'What\'s new';

  @override
  String get whatsNewGotIt => 'Got it';

  @override
  String get pickerChooseZikr => 'Choose a Zikr or Dua';

  @override
  String get pickerSearchZikrHint => 'Search zikr, dua, ziyarat...';

  @override
  String get pickerNoMatches => 'No matches found.';

  @override
  String get todaysNone => 'No recitations configured.';

  @override
  String get scheduledFallbackTitle => 'Scheduled notification';

  @override
  String get scheduledNone => 'No scheduled notifications.';

  @override
  String newsLoadFailed(String error) {
    return 'Failed to load news: $error';
  }

  @override
  String get newsNoBrowser => 'No web browser found';

  @override
  String get actionSaved => 'Saved';

  @override
  String get actionBookmark => 'Bookmark';

  @override
  String get actionShare => 'Share';

  @override
  String get actionListen => 'Listen';

  @override
  String get actionSettings => 'Settings';

  @override
  String get actionCounter => 'Counter';

  @override
  String get prayerEnableLocationBody =>
      'Enable location to display accurate prayer times for your area.';

  @override
  String statsDayRead(String day) {
    return '$day: read';
  }

  @override
  String statsDayNotRead(String day) {
    return '$day: not read';
  }

  @override
  String get qiblaDistance => 'Distance';

  @override
  String get qiblaDirection => 'Direction';

  @override
  String get qiblaYouFace => 'You face';

  @override
  String pickerAyahLabel(int ayah) {
    return 'Ayah $ayah';
  }

  @override
  String hadithSharedVia(String link) {
    return 'Shared via Shia Companion - $link';
  }

  @override
  String get requestTypeZikr => 'Zikr';

  @override
  String get requestTypeBook => 'Book';
}
