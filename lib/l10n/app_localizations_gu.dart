// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Gujarati (`gu`).
class AppLocalizationsGu extends AppLocalizations {
  AppLocalizationsGu([String locale = 'gu']) : super(locale);

  @override
  String get appTitle => 'Shia Companion';

  @override
  String get settingsAppLanguage => 'એપની ભાષા';

  @override
  String get settingsTranslationLanguage => 'અનુવાદની ભાષા';

  @override
  String languageFollowDevice(String language) {
    return 'ડિવાઇસની ભાષા ($language)';
  }

  @override
  String languageFollowApp(String language) {
    return 'એપ જેવી જ ($language)';
  }

  @override
  String settingsDownloadedRecitationsUsed(String size) {
    return 'આ ડિવાઇસ પર $size વપરાયું';
  }

  @override
  String settingsHijriAhead(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days દિવસ આગળ',
      one: 'એક દિવસ આગળ',
    );
    return '$_temp0';
  }

  @override
  String settingsHijriBehind(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days દિવસ પાછળ',
      one: 'એક દિવસ પાછળ',
    );
    return '$_temp0';
  }

  @override
  String settingsLocationFailed(String message) {
    return '$message. ફરી પ્રયાસ કરવા ટૅપ કરો.';
  }

  @override
  String settingsLocationSaved(String city) {
    return 'હાલમાં સાચવેલું સ્થાન: $city.';
  }

  @override
  String settingsLocationUpdated(String city, String age) {
    return '$city · $age અપડેટ થયું. તમે ફરતા રહો તેમ તે આપોઆપ તાજું થતું રહે છે.';
  }

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes મિનિટ પહેલાં';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours કલાક પહેલાં';
  }

  @override
  String timeDaysAgo(int days) {
    return '$days દિવસ પહેલાં';
  }

  @override
  String settingsAdjustHijriBy(int days) {
    return 'હિજરી તારીખ $days દિવસ ગોઠવો';
  }

  @override
  String settingsPrayerTimesShownSubtitle(String names) {
    return 'હોમ પેજ અને હોમ સ્ક્રીન વિજેટ્સ પર બતાવાય છે: $names.';
  }

  @override
  String settingsPrayerNotificationsAllOn(int count) {
    return 'તમામ $count સમય માટે ચાલુ.';
  }

  @override
  String settingsPrayerNotificationsSomeOn(
      String names, int enabled, int total) {
    return '$names · $totalમાંથી $enabled ચાલુ';
  }

  @override
  String get settingsSectionPrayerLocation => 'નમાઝ અને સ્થાન';

  @override
  String get settingsAdjustHijriDate => 'હિજરી તારીખ ગોઠવો';

  @override
  String get settingsPrayerTimesShown => 'બતાવાતા નમાઝના સમય';

  @override
  String get settingsRefreshLocation => 'સ્થાન તાજું કરો';

  @override
  String get settingsLocationRefreshed => 'સ્થાન તાજું થઈ ગયું છે.';

  @override
  String get settingsSectionNotifications => 'સૂચનાઓ';

  @override
  String get settingsPrayerNotifications => 'નમાઝની સૂચનાઓ';

  @override
  String get settingsZikrReminders => 'ઝિક્ર રિમાઇન્ડર્સ';

  @override
  String get settingsZikrRemindersSubtitle =>
      'તમે પસંદ કરેલા દિવસોએ ઝિક્ર વિશે યાદ અપાવવામાં આવશે.';

  @override
  String get settingsPrecisePrayerAlarms => 'ચોક્કસ નમાઝ એલાર્મ';

  @override
  String get settingsScheduledNotifications => 'નિર્ધારિત સૂચનાઓ';

  @override
  String get settingsScheduledNotificationsSubtitle => 'બાકી નમાઝ સૂચનાઓ જુઓ.';

  @override
  String get settingsSectionAppearance => 'દેખાવ';

  @override
  String get settingsDarkMode => 'ડાર્ક મોડ';

  @override
  String get settingsDarkModeSubtitle => 'આખી એપમાં ઘેરો દેખાવ વાપરો.';

  @override
  String get settingsAppTextSize => 'એપના લખાણનું કદ';

  @override
  String get settingsAppTextSizeSubtitle =>
      'ઝિક્ર સહિત તમામ લખાણ મોટું કે નાનું કરે છે.';

  @override
  String get settingsSectionZikrReading => 'ઝિક્ર વાંચન અને શેરિંગ';

  @override
  String get settingsSectionOfflineAudio => 'ઓફલાઇન ઓડિયો';

  @override
  String get settingsDownloadedRecitations => 'ડાઉનલોડ કરેલા પઠન';

  @override
  String get settingsDownloadedRecitationsEmpty => 'કનેક્શન વગર સાંભળો';

  @override
  String get settingsSectionSupport => 'સહાય';

  @override
  String get settingsRateApp => 'Shia Companionને રેટ કરો';

  @override
  String get settingsRateAppSubtitle => 'એપ ગમે છે? અમને રેટિંગ આપો.';

  @override
  String get settingsRequestContent => 'ઝિક્ર કે પુસ્તકની વિનંતી કરો';

  @override
  String get settingsRequestContentSubtitle =>
      'કોઈ દુઆ, ઝિયારત કે પુસ્તક નથી મળતું? અમને ઉમેરવા કહો.';

  @override
  String get settingsFeedback => 'પ્રતિસાદ';

  @override
  String get settingsFeedbackSubtitle => 'પ્રશ્નો, સમસ્યાઓ કે સૂચનો મોકલો.';

  @override
  String get settingsGithub => 'GitHub પર યોગદાન આપો';

  @override
  String get settingsGithubSubtitle =>
      'Shia Companion ઓપન સોર્સ છે. સમસ્યાઓ જણાવો અથવા તેને સુધારવામાં મદદ કરો.';

  @override
  String get settingsGithubOpenFailed => 'GitHub ખોલી શકાયું નહીં';

  @override
  String get settingsAboutUs => 'અમારા વિશે';

  @override
  String get settingsSectionAccount => 'એકાઉન્ટ';

  @override
  String get settingsNotSignedIn => 'સાઇન ઇન નથી';

  @override
  String get settingsSignInPrompt =>
      'ડિવાઇસો વચ્ચે મનપસંદ સિંક કરવા સાઇન ઇન કરો.';

  @override
  String get settingsLogout => 'લોગઆઉટ';

  @override
  String get settingsLogoutSubtitle => 'આ ડિવાઇસ પર સાઇન આઉટ કરો.';

  @override
  String get settingsDeleteAccount => 'મારું એકાઉન્ટ કાઢી નાખો';

  @override
  String get settingsDeleteAccountSubtitle =>
      'તમારા એકાઉન્ટનો ડેટા કાયમ માટે દૂર કરો.';

  @override
  String get settingsSignInGoogle => 'Google વડે સાઇન ઇન કરો';

  @override
  String get settingsSignInGoogleSubtitle =>
      'મનપસંદ અને એકાઉન્ટ ડેટા સિંક કરો.';

  @override
  String get settingsSignInApple => 'Apple વડે સાઇન ઇન કરો';

  @override
  String get settingsSignInAppleSubtitle =>
      'સાઇન ઇન કરવા તમારું Apple ID વાપરો.';

  @override
  String get settingsSignedIn => 'સાઇન ઇન થઈ ગયું';

  @override
  String get settingsSyncing => 'મનપસંદ અને એકાઉન્ટ ડેટા સિંક થઈ રહ્યો છે.';

  @override
  String get settingsHijriNoAdjustment => 'કોઈ ગોઠવણ નહીં';

  @override
  String get settingsLocationUpdating => 'તમારું સ્થાન અપડેટ થઈ રહ્યું છે…';

  @override
  String get settingsLocationUpdatePrompt =>
      'સાચવેલું નમાઝ-સમયનું સ્થાન અપડેટ કરો.';

  @override
  String get timeJustNow => 'હમણાં જ';

  @override
  String get settingsPrayerNotificationsOff =>
      'બંધ. નમાઝના સમયે સૂચના મેળવવા ચાલુ કરો.';

  @override
  String get settingsPreciseAlarmsOn => 'ચોક્કસ અઝાન સમય માટે સક્ષમ.';

  @override
  String get settingsPreciseAlarmsOff =>
      'બંધ. Android નમાઝની સૂચનાઓ થોડી મોડી પહોંચાડી શકે છે.';

  @override
  String get settingsNotificationsUnavailable => 'સૂચના સિસ્ટમ શરૂ થઈ નથી';

  @override
  String get settingsPreciseAlarmsAlreadyOn =>
      'ચોક્કસ નમાઝ એલાર્મ પહેલેથી જ સક્ષમ છે.';

  @override
  String get settingsPreciseAlarmsDialogTitle =>
      'ચોક્કસ નમાઝ એલાર્મ સક્ષમ કરીએ?';

  @override
  String get settingsPreciseAlarmsDialogBody =>
      'અઝાનની સૂચનાઓ બરાબર નમાઝના સમયે આવે તે માટે Androidને એલાર્મ અને રિમાઇન્ડરની પરવાનગી જોઈએ છે. તેના વગર રિમાઇન્ડર કામ તો કરશે, પણ થોડા મોડા આવી શકે છે.';

  @override
  String get commonCancel => 'રદ કરો';

  @override
  String get commonOpenSettings => 'સેટિંગ્સ ખોલો';

  @override
  String get settingsPreciseAlarmsEnabled => 'ચોક્કસ નમાઝ એલાર્મ સક્ષમ થયા.';

  @override
  String get settingsPreciseAlarmsNotEnabled =>
      'ચોક્કસ નમાઝ એલાર્મ સક્ષમ થયા નહીં. અંદાજિત સમય જ વપરાશે.';

  @override
  String get settingsNoEmailApp => 'કોઈ ઈમેઇલ એપ મળી નહીં';

  @override
  String get settingsLoginSuccessful => 'લોગિન સફળ';

  @override
  String get settingsGoogleUnavailable =>
      'Google સાઇન-ઇન હાલમાં ઉપલબ્ધ નથી. કૃપા કરી ફરી પ્રયાસ કરો.';

  @override
  String get commonNetworkError =>
      'કનેક્ટ થઈ શક્યું નહીં. તમારું ઇન્ટરનેટ કનેક્શન તપાસી ફરી પ્રયાસ કરો.';

  @override
  String get settingsGoogleFailed =>
      'Google સાઇન-ઇન કામ ન થયું. થોડી વારમાં ફરી પ્રયાસ કરો.';

  @override
  String get settingsAppleFailed => 'Apple સાઇન-ઇન નિષ્ફળ';

  @override
  String audioRecordingNumber(int number) {
    return 'રેકોર્ડિંગ $number';
  }

  @override
  String playlistAddedTo(String name) {
    return '$nameમાં ઉમેર્યું';
  }

  @override
  String playlistAlreadyIn(String name) {
    return 'પહેલેથી જ $nameમાં છે';
  }

  @override
  String zikrCount(int count) {
    return '$count ઝિક્ર';
  }

  @override
  String get playlistsEmpty =>
      'તમે રોજ સાંભળો છો તે ઝિક્રની પ્લેલિસ્ટ બનાવો — જેમ કે રોજ સવારે દુઆ અહદ અને ઝિયારત આશુરા — અને એક ટૅપથી બધું શરૂ કરો.';

  @override
  String playlistDeleteConfirm(String name) {
    return '\"$name\" કાઢી નાખીએ?';
  }

  @override
  String get playlistDeleteKeepsDuasAndAudio =>
      'દુઆઓ પોતે એપમાં રહેશે, અને તેમનો ડાઉનલોડ કરેલો ઓડિયો પણ — જગ્યા ખાલી કરવા તેને ડાઉનલોડ્સમાંથી દૂર કરો.';

  @override
  String get playlistEmpty =>
      'ઝિક્ર પસંદ કરવા ઉમેરો પર ટૅપ કરો. ઓડિયો ધરાવતી કોઈ પણ દુઆના પ્લેયરમાંથી પણ તમે તેને ઉમેરી શકો છો.';

  @override
  String audioRecordingsChosen(int chosen, int total) {
    return '$totalમાંથી $chosen રેકોર્ડિંગ';
  }

  @override
  String audioDownloadingPercent(int percent) {
    return '$percent% ડાઉનલોડ થઈ રહ્યું છે';
  }

  @override
  String audioRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count રેકોર્ડિંગ',
      one: 'એક રેકોર્ડિંગ',
    );
    return '$_temp0';
  }

  @override
  String playlistNowPlayingPosition(String playlist, int position, int count) {
    return '$playlist · $countમાંથી $position';
  }

  @override
  String get playlistNameHint => 'દા.ત. સવાર';

  @override
  String get playlistOfflinePartial =>
      'તમે ઓફલાઇન છો — ફક્ત ડાઉનલોડ કરેલા રેકોર્ડિંગ જ ચાલશે';

  @override
  String get playlistNothingToPlay =>
      'આ પ્લેલિસ્ટમાં ચલાવવા જેવું કોઈ રેકોર્ડિંગ નથી';

  @override
  String get playlistOfflineNothingDownloaded =>
      'તમે ઓફલાઇન છો અને આ પ્લેલિસ્ટમાં હજી કંઈ ડાઉનલોડ થયું નથી';

  @override
  String get playlistStartFailed =>
      'પ્લેલિસ્ટ શરૂ થઈ શકી નહીં. ફરી પ્રયાસ કરો.';

  @override
  String get playlistChooseRecordingsHint =>
      'આ પ્લેલિસ્ટમાં ચલાવવાના રેકોર્ડિંગ પસંદ કરો';

  @override
  String get commonDone => 'થઈ ગયું';

  @override
  String get playlistAddTo => 'પ્લેલિસ્ટમાં ઉમેરો';

  @override
  String get playlistNew => 'નવી પ્લેલિસ્ટ';

  @override
  String get commonCreate => 'બનાવો';

  @override
  String get playlistsTitle => 'પ્લેલિસ્ટ્સ';

  @override
  String get playlistDownloads => 'ડાઉનલોડ્સ';

  @override
  String get commonPause => 'થોભાવો';

  @override
  String get commonPlay => 'ચલાવો';

  @override
  String get playlistRename => 'પ્લેલિસ્ટનું નામ બદલો';

  @override
  String get commonSave => 'સાચવો';

  @override
  String get playlistDeleteKeepsDuas => 'દુઆઓ પોતે એપમાં રહેશે.';

  @override
  String get commonDelete => 'કાઢી નાખો';

  @override
  String get playlistDeleted => 'આ પ્લેલિસ્ટ કાઢી નાખવામાં આવી છે.';

  @override
  String get commonRename => 'નામ બદલો';

  @override
  String get playlistRemoveDownloads => 'ડાઉનલોડ્સ દૂર કરો';

  @override
  String get playlistAllDownloads => 'તમામ ડાઉનલોડ્સ';

  @override
  String get commonAdd => 'ઉમેરો';

  @override
  String get playlistResume => 'આગળ ચલાવો';

  @override
  String get playlistPlayAll => 'બધું ચલાવો';

  @override
  String get audioDownloaded => 'ડાઉનલોડ થયું';

  @override
  String get audioDownloadFailed => 'ડાઉનલોડ પૂરું ન થયું';

  @override
  String get playlistOpenText => 'લખાણ ખોલો';

  @override
  String get playlistChooseRecordings => 'રેકોર્ડિંગ પસંદ કરો';

  @override
  String get audioStopDownloading => 'ડાઉનલોડ અટકાવો';

  @override
  String get audioRemoveDownload => 'ડાઉનલોડ દૂર કરો';

  @override
  String get audioDownload => 'ડાઉનલોડ';

  @override
  String get playlistRemoveZikr => 'પ્લેલિસ્ટમાંથી દૂર કરો';

  @override
  String get playlistAddZikr => 'ઝિક્ર ઉમેરો';

  @override
  String get commonSearch => 'શોધો';

  @override
  String get audioPartlyDownloaded => 'અંશતઃ ડાઉનલોડ થયું';

  @override
  String get playlistRepeatOn => 'રિપીટ ચાલુ છે';

  @override
  String get playlistRepeat => 'પ્લેલિસ્ટ રિપીટ કરો';

  @override
  String get commonPrevious => 'પહેલું';

  @override
  String get commonNext => 'આગળનું';

  @override
  String get commonStop => 'અટકાવો';

  @override
  String flightTimesShownAt(String origin, String destination) {
    return '$origin અને $destinationના સ્થાનિક સમય મુજબ બતાવેલા સમય';
  }

  @override
  String flightDurationAndDistance(String duration, String distance) {
    return 'હવામાં $duration · $distance ગ્રેટ-સર્કલ અંતર';
  }

  @override
  String flightAirportTime(String airport) {
    return '$airportનો સમય';
  }

  @override
  String flightOverPosition(String position) {
    return ' · $position ઉપર';
  }

  @override
  String flightAfterTakeoff(String duration) {
    return 'ઉડાન ભર્યાના $duration પછી';
  }

  @override
  String flightHorizonLater(int minutes) {
    return 'નીચેની જમીનના ક્ષિતિજ કરતાં $minutes મિનિટ મોડું';
  }

  @override
  String flightHorizonEarlier(int minutes) {
    return 'નીચેની જમીનના ક્ષિતિજ કરતાં $minutes મિનિટ વહેલું';
  }

  @override
  String flightQiblaToRight(int degrees) {
    return 'તમારી જમણી બાજુ $degrees°';
  }

  @override
  String flightQiblaToLeft(int degrees) {
    return 'તમારી ડાબી બાજુ $degrees°';
  }

  @override
  String flightQiblaLine(int bearing, String compass, String relative) {
    return 'કિબલા $bearing° ($compass) — ઉડાનની દિશાની સાપેક્ષે $relative';
  }

  @override
  String flightAltitudeHorizonBody(String altitude, String dip) {
    return '$altitude પર ક્ષિતિજ જમીન કરતાં લગભગ $dip° નીચો હોય છે, તેથી સૂર્ય આથમતાં વધુ સમય લાગે છે અને પરોઢ વહેલું આવે છે. તેનાથી મગરિબ અને ઇશા નીચેની જમીનના સમય કરતાં લગભગ વીસ મિનિટ મોડા, અને ફજર લગભગ વીસ મિનિટ વહેલું થાય છે — દરેક હરોળ પોતાનો ફેરફાર બતાવે છે. કયો ક્ષિતિજ નમાઝ માટે માન્ય છે એ પ્રશ્ન તમારા મર્જા માટે છે, આ એપ તેનો નિર્ણય કરી શકે નહીં.';
  }

  @override
  String flightAltitudeFeet(String feet) {
    return '$feet ફૂટ';
  }

  @override
  String get flightTitleFallback => 'ફ્લાઇટ';

  @override
  String get flightEdit => 'ફ્લાઇટ સંપાદિત કરો';

  @override
  String get flightCheckTimes => 'ફ્લાઇટના સમય તપાસો';

  @override
  String get flightCheckTimesBody =>
      'દરેક એરપોર્ટનો સમય ઝોન લાગુ કર્યા પછી આગમન પ્રસ્થાન પછીનું નથી. તારીખો સુધારવા સંપાદન પર ટૅપ કરો.';

  @override
  String get flightInTheAir => 'હવામાં';

  @override
  String get flightNoPrayerDuring => 'આ ફ્લાઇટ દરમિયાન કોઈ નમાઝ આવતી નથી';

  @override
  String get flightNoPrayerDuringBody =>
      'દરેક નમાઝનો સમય કાં તો ઉડાન પહેલાં અથવા ઉતરાણ પછી આવે છે.';

  @override
  String get flightNotDuring => 'આ ફ્લાઇટ દરમિયાન નહીં';

  @override
  String get flightEndOfIshaWindow => 'ઇશાના સમયગાળાનો અંત · ';

  @override
  String get flightStraightAhead => 'બરાબર સામે';

  @override
  String get flightDirectlyBehind => 'બરાબર તમારી પાછળ';

  @override
  String get flightIshaClosedBeforeTakeoff =>
      'ઇશાનો સમયગાળો ઉડાન પહેલાં જ પૂરો થઈ ગયો હતો.';

  @override
  String get flightAlreadyInBeforeTakeoff =>
      'ઉડાન પહેલાં જ શરૂ થઈ ગયો હતો — તમારા પ્રસ્થાન શહેરના નમાઝના સમય વાપરો.';

  @override
  String get flightIshaOpenUntilLanding =>
      'ઇશાનો સમયગાળો ઉતરાણ પછી સુધી પૂરો થતો નથી.';

  @override
  String get flightAfterLanding =>
      'ઉતરાણ પછી આવે છે — તમારા ગંતવ્યના નમાઝના સમય વાપરો.';

  @override
  String get flightSunAngleNeverReached =>
      'આ આખા માર્ગ પર સૂર્ય જરૂરી ખૂણા સુધી ક્યારેય પહોંચતો નથી, તેથી કોઈ સમય ગણી શકાતો નથી.';

  @override
  String get flightHowWorkedOut => 'આ કેવી રીતે ગણવામાં આવે છે';

  @override
  String get flightHowWorkedOutBody =>
      'વિમાન ગ્રેટ-સર્કલ માર્ગે સ્થિર ઝડપે જાય છે એમ ધારવામાં આવે છે, અને દરેક નમાઝનો સમય એ સ્થાન માટે ઉકેલવામાં આવે છે જ્યાં વિમાન તે સમયે હોય. એક કલાકનો વિલંબ આ સમયોને લગભગ અડધો કલાક ખસેડે છે, અને હવામાનને કારણે માર્ગ બદલાવાથી તે દસથી વીસ મિનિટ ખસી શકે છે, તેથી તેમને ચોક્કસ નહીં, અંદાજિત ગણો.';

  @override
  String get flightHorizonAtAltitude => 'ઊંચાઈ પરના ક્ષિતિજથી માપેલું';

  @override
  String get flightHorizonAtGround => 'જમીન સ્તરના ક્ષિતિજથી માપેલું';

  @override
  String get flightGroundHorizonBody =>
      'સમય વિમાનની નીચેની જમીનના ક્ષિતિજને અનુસરે છે. કેબિનમાંથી સૂર્ય મોડો આથમે છે અને પરોઢ બતાવ્યા કરતાં વહેલું આવે છે — ક્રૂઝ ઊંચાઈએ લગભગ વીસ મિનિટ જેટલું.';

  @override
  String get flightHighLatitude => 'આ માર્ગ ઊંચા અક્ષાંશોમાંથી પસાર થાય છે';

  @override
  String get flightHighLatitudeBody =>
      'લગભગ 48°થી ઉપર, સૂર્ય ક્ષિતિજની નીચે એટલો ન જાય કે પરોઢ અને રાત્રિ સામાન્ય રીતે થાય. ત્યાં ફજર, મગરિબ અને ઇશાના સમય રાત્રિના પ્રમાણસર અંદાજ પર આધાર રાખે છે. ઊંચા અક્ષાંશ પર નમાઝના ચુકાદા અલગ-અલગ છે — કૃપા કરી તમારા મર્જાનું અનુસરણ કરો.';

  @override
  String get flightSomeNotCalculated => 'કેટલાક નમાઝના સમય ગણી શકાયા નહીં';

  @override
  String get flightSomeNotCalculatedBody =>
      'સૂર્ય આખા માર્ગ દરમિયાન જરૂરી ખૂણાથી ઉપર જ રહે છે, તેથી તે નમાઝોનો કોઈ ગણેલો સમય નથી. આવી પરિસ્થિતિ માટે કૃપા કરી તમારા મર્જાના ચુકાદાને અનુસરો.';

  @override
  String get flightTimeZonesFailed => 'સમય ઝોન લોડ થઈ શક્યા નહીં';

  @override
  String get flightTimeZonesFailedBody =>
      'આમાંથી એક એરપોર્ટનો સમય ઝોન આ બિલ્ડ ઓળખતું નથી. એરપોર્ટ ફરી પસંદ કરવા સંપાદન પર ટૅપ કરો.';

  @override
  String get prayerFajr => 'ફજર';

  @override
  String get prayerSunrise => 'સૂર્યોદય';

  @override
  String get prayerZuhr => 'ઝોહર';

  @override
  String get prayerAsr => 'અસર';

  @override
  String get prayerSunset => 'સૂર્યાસ્ત';

  @override
  String get prayerMaghrib => 'મગરીબ';

  @override
  String get prayerIsha => 'ઇશા';

  @override
  String get prayerMidnight => 'મધ્યરાત્રિ';

  @override
  String locationErrorBody(String error) {
    return 'તમારું સ્થાન મેળવવામાં ભૂલ થઈ: $error\n\nકૃપા કરી તપાસો કે સ્થાન સેવાઓ ચાલુ છે અને ફરી પ્રયાસ કરો.';
  }

  @override
  String notificationReopenAppBody(int days) {
    return 'લાગે છે કે તમે છેલ્લા $days દિવસોમાં એપ્લિકેશન વાપરી નથી. અઝાનની સૂચનાઓ મળતી રહે તે માટે કૃપા કરી એપ ખોલો';
  }

  @override
  String notificationPrayerTime(String prayer) {
    return '$prayerનો સમય થઈ ગયો છે';
  }

  @override
  String notificationTapToPlayCustom(String message) {
    return '$message · તમારો ઓડિયો ચલાવવા ટૅપ કરો';
  }

  @override
  String notificationTapToPlayAzan(String message) {
    return '$message · પૂરી અઝાન સાંભળવા ટૅપ કરો';
  }

  @override
  String get locationEnableTitle => 'નમાઝના સમય માટે સ્થાન સક્ષમ કરો';

  @override
  String get locationEnableBody =>
      'નમાઝના સમય તમારા સ્થાન મુજબ અનન્ય હોય છે. તમે એપ વાપરતા હો ત્યારે અમે તમારું સ્થાન વાપરીએ છીએ જેથી તમારા વિસ્તાર માટે ચોક્કસ નમાઝના સમય આપી શકીએ.';

  @override
  String get commonContinue => 'આગળ વધો';

  @override
  String get locationServicesDisabledTitle => 'સ્થાન સેવાઓ બંધ છે';

  @override
  String get locationServicesDisabledBody =>
      'સ્થાન સેવાઓ બંધ છે. તમારા વિસ્તાર માટે ચોક્કસ નમાઝના સમય મેળવવા કૃપા કરી તમારા ડિવાઇસની સેટિંગ્સમાં સ્થાન સેવાઓ ચાલુ કરો.';

  @override
  String get locationPermissionDeniedForever =>
      'સ્થાનની પરવાનગી કાયમ માટે નકારવામાં આવી છે. ચોક્કસ નમાઝના સમય મેળવવા કૃપા કરી એપ સેટિંગ્સ ખોલી સ્થાનની પરવાનગી આપો.';

  @override
  String get locationPermissionUnknown =>
      'સ્થાન પરવાનગીની સ્થિતિ જાણી શકાઈ નહીં. કૃપા કરી એપ સેટિંગ્સ ખોલો અને ખાતરી કરો કે સ્થાનની પરવાનગી આપેલી છે.';

  @override
  String get locationPermissionNeeded =>
      'તમારા વિસ્તાર માટે ચોક્કસ નમાઝના સમય બતાવવા સ્થાનની પરવાનગી જરૂરી છે.';

  @override
  String get locationPermissionTitle => 'સ્થાનની પરવાનગી જરૂરી છે';

  @override
  String get locationTimeoutTitle => 'સ્થાનનો સમય પૂરો';

  @override
  String get locationTimeoutBody =>
      'અપેક્ષિત સમયમાં તમારું સ્થાન મળી શક્યું નહીં. આ નબળા GPS સિગ્નલ કે નેટવર્ક સમસ્યાઓને કારણે હોઈ શકે છે. કૃપા કરી ફરી પ્રયાસ કરો.';

  @override
  String get locationErrorTitle => 'સ્થાન ભૂલ';

  @override
  String get notificationReopenAppTitle =>
      'અઝાનની સૂચનાઓ મળતી રહે તે માટે એપ ખોલો';

  @override
  String get notificationChannelTakbir => 'નમાઝના સમય - તકબીર';

  @override
  String get notificationChannelSystemDefault => 'નમાઝના સમય - સિસ્ટમ ડિફોલ્ટ';

  @override
  String get notificationChannelSilent => 'નમાઝના સમય - શાંત';

  @override
  String get notificationChannelCustom => 'નમાઝના સમય - કસ્ટમ અવાજ';

  @override
  String get notificationChannelFullAzan => 'નમાઝના સમય - પૂરી અઝાન';

  @override
  String get notificationChannelSilentDescription => 'શાંત નમાઝ-સમય સૂચનાઓ';

  @override
  String get notificationChannelDescription => 'નમાઝ-સમયની સૂચનાઓ';

  @override
  String get notificationChannelGeneral => 'સામાન્ય';

  @override
  String qiblaNeedsCalibratingBody(int degrees) {
    return 'રીડિંગ લગભગ $degrees° જેટલું ખોટું છે. ધાતુ કે ચુંબકીય કોઈ પણ વસ્તુથી દૂર રહી ફોનને આઠના આકારમાં થોડી વાર ફેરવો.';
  }

  @override
  String qiblaBearingFromNorth(String place, String bearing) {
    return '$place સાચી ઉત્તરથી $bearing પર છે';
  }

  @override
  String qiblaFacing(String place) {
    return '$place તરફ મુખ';
  }

  @override
  String qiblaTurnRight(int degrees) {
    return 'જમણે $degrees° વળો';
  }

  @override
  String qiblaTurnLeft(int degrees) {
    return 'ડાબે $degrees° વળો';
  }

  @override
  String qiblaDeclinationEast(String degrees) {
    return 'તમે જ્યાં છો ત્યાં ચુંબકીય ઉત્તર સાચી ઉત્તરથી $degrees° પૂર્વમાં છે, અને રીડિંગ તેના માટે આપોઆપ સુધારવામાં આવે છે.';
  }

  @override
  String qiblaDeclinationWest(String degrees) {
    return 'તમે જ્યાં છો ત્યાં ચુંબકીય ઉત્તર સાચી ઉત્તરથી $degrees° પશ્ચિમમાં છે, અને રીડિંગ તેના માટે આપોઆપ સુધારવામાં આવે છે.';
  }

  @override
  String get qiblaDistanceHere => 'અહીં';

  @override
  String get qiblaTitle => 'કિબલા શોધક';

  @override
  String get qiblaAboutCompass => 'આ હોકાયંત્ર વિશે';

  @override
  String get qiblaLocationNeeded => 'સ્થાન જરૂરી છે';

  @override
  String get qiblaLocationNeededBody =>
      'દિશા તમે ક્યાં છો તેના પર આધાર રાખે છે. તમારું સ્થાન શેર કરો અને ફિક્સ મળતાં જ હોકાયંત્ર દિશા બતાવશે.';

  @override
  String get qiblaUseMyLocation => 'મારું સ્થાન વાપરો';

  @override
  String get qiblaTurnOnCompass => 'હોકાયંત્ર ચાલુ કરો';

  @override
  String get qiblaTurnOnCompassBody =>
      'ફોન કઈ દિશામાં છે તે જણાવતા પહેલાં આ બ્રાઉઝરને તમારી પરવાનગી જોઈએ છે.';

  @override
  String get qiblaAllowCompass => 'હોકાયંત્રને મંજૂરી આપો';

  @override
  String get qiblaCompassBlocked => 'હોકાયંત્ર અવરોધિત';

  @override
  String get qiblaCompassBlockedBody =>
      'ગતિ અને દિશાની પરવાનગી નકારવામાં આવી, તેથી ડાયલ ઉત્તર-ઉપર જ રાખવામાં આવ્યો છે. તેને તમારી બ્રાઉઝર સેટિંગ્સમાં મંજૂરી આપો, અથવા ડાયલ પરની ઉત્તર દિશા તમારી આસપાસની ઉત્તર સાથે મળે ત્યાં સુધી ફરો.';

  @override
  String get qiblaNoCompass => 'આ ડિવાઇસ પર હોકાયંત્ર નથી';

  @override
  String get qiblaNoCompassBody =>
      'તેના બદલે ડાયલ ઉત્તર-ઉપર રાખવામાં આવ્યો છે. ઉત્તર તરફ મુખ રાખો, અને સોય ત્યાંથી દિશા બતાવે છે.';

  @override
  String get qiblaNeedsCalibrating => 'હોકાયંત્રને માપાંકન જોઈએ છે';

  @override
  String get qiblaLocationUnknown => 'સ્થાન અજાણ્યું';

  @override
  String get qiblaUpdateLocation => 'સ્થાન અપડેટ કરો';

  @override
  String get qiblaPointingTowards => 'આ તરફ દિશા છે';

  @override
  String get qiblaWaitingForLocation => 'તમારા સ્થાનની રાહ જોવાઈ રહી છે';

  @override
  String get qiblaPointTowards => 'આ તરફ રાખો';

  @override
  String get qiblaGreatCircleBody =>
      'સોય ગ્રેટ-સર્કલ માર્ગે દિશા બતાવે છે — પૃથ્વીની સપાટી પરનો સૌથી ટૂંકો રસ્તો, જે દિશાથી કિબલા નક્કી થાય છે. સપાટ નકશા પર તે આશ્ચર્યજનક લાગી શકે છે; ઉત્તર અમેરિકાથી કાબા લગભગ ઉત્તર-પૂર્વમાં છે, દક્ષિણ-પૂર્વમાં નહીં.';

  @override
  String get qiblaDeclinationUnknownBody =>
      'તમારો ફોન ચુંબકીય ઉત્તરનો ખૂણો માપે છે, જે સાચી ઉત્તરથી અલગ પડે છે અને તે તમે ક્યાં છો તેના પર આધાર રાખે છે. તમારું સ્થાન જણાતાં જ તે સુધારો આપોઆપ લાગુ થાય છે.';

  @override
  String get qiblaSteadyReadingBody =>
      'સ્થિર રીડિંગ માટે ફોનને સપાટ રાખો અને લેપટોપ, સ્પીકર, કારના ડેશબોર્ડ અને ચુંબક ધરાવતી બીજી દરેક વસ્તુથી દૂર રાખો.';

  @override
  String get commonClose => 'બંધ કરો';

  @override
  String get weekdayShortMon => 'સોમ';

  @override
  String get weekdayShortTue => 'મંગળ';

  @override
  String get weekdayShortWed => 'બુધ';

  @override
  String get weekdayShortThu => 'ગુરુ';

  @override
  String get weekdayShortFri => 'શુક્ર';

  @override
  String get weekdayShortSat => 'શનિ';

  @override
  String get weekdayShortSun => 'રવિ';

  @override
  String reminderMinutesRange(int max) {
    return '0 અને $max વચ્ચેની મિનિટની સંખ્યા નાખો.';
  }

  @override
  String get reminderTitleRequired => 'કૃપા કરી આ રિમાઇન્ડર માટે શીર્ષક નાખો.';

  @override
  String get reminderPickDay => 'ઓછામાં ઓછો એક દિવસ પસંદ કરો.';

  @override
  String get reminderSavedPendingLocation =>
      'સાચવાઈ ગયું. તમારું નમાઝ-સમયનું સ્થાન ઉપલબ્ધ થતાં જ તે શરૂ થશે.';

  @override
  String get reminderEditTitle => 'રિમાઇન્ડર સંપાદિત કરો';

  @override
  String get reminderNewTitle => 'નવું રિમાઇન્ડર';

  @override
  String get reminderWhat => 'શું';

  @override
  String get reminderWhatHint =>
      'લાઇબ્રેરીમાંથી ઝિક્ર પસંદ કરો, અથવા નીચે ફક્ત શીર્ષક લખો.';

  @override
  String get reminderChooseZikr => 'ઝિક્ર લાઇબ્રેરીમાંથી પસંદ કરો';

  @override
  String get reminderChangeZikr => 'ઝિક્ર બદલો';

  @override
  String get reminderTitleLabel => 'શીર્ષક';

  @override
  String get reminderTitleHint => 'દા.ત. દુઆ તવસ્સુલ';

  @override
  String get reminderRepeatOn => 'આ દિવસોએ ફરી';

  @override
  String get reminderWhen => 'ક્યારે';

  @override
  String get reminderFixedTime => 'નિશ્ચિત સમય';

  @override
  String get reminderPrayerRelative => 'નમાઝ-સાપેક્ષ';

  @override
  String get commonSaveChanges => 'ફેરફારો સાચવો';

  @override
  String get reminderAdd => 'રિમાઇન્ડર ઉમેરો';

  @override
  String get reminderTime => 'સમય';

  @override
  String get reminderPrayer => 'નમાઝ';

  @override
  String get reminderMinutes => 'મિનિટ';

  @override
  String get reminderBefore => 'પહેલાં';

  @override
  String get reminderAfter => 'પછી';

  @override
  String get reminderPrayerRelativeNote =>
      'નમાઝના સમય કેલેન્ડર સાથે બદલાય છે, તેથી આ આગામી થોડાં અઠવાડિયાની ઘટનાઓ નિર્ધારિત કરે છે અને તમે જ્યારે પણ એપ ખોલો ત્યારે તેમને તાજી કરે છે.';

  @override
  String qazaCompletedCount(int count) {
    return '$count પૂર્ણ';
  }

  @override
  String get qazaPrayed => 'નમાઝ પઢી';

  @override
  String get qazaFasted => 'રોજો રાખ્યો';

  @override
  String qazaEstimatePrayers(String days, String prayers) {
    return 'દરેક રોજિંદી નમાઝના $days ($prayers નમાઝો)';
  }

  @override
  String qazaEstimateFasts(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count રોજા',
      one: '$count રોજો',
    );
    return '$_temp0';
  }

  @override
  String qazaLunarNote(int yearDays, int monthDays) {
    return 'ચંદ્ર વર્ષ $yearDays દિવસના અને મહિના $monthDays દિવસના ગણેલા છે.';
  }

  @override
  String get qazaTitle => 'કઝા ટ્રેકર';

  @override
  String get qazaCalculate => 'મારી કઝા ગણો';

  @override
  String get qazaPrayers => 'નમાઝો';

  @override
  String get qazaFasts => 'રોજા';

  @override
  String get qazaRemaining => 'કઝા બાકી';

  @override
  String get commonUndo => 'પાછું કરો';

  @override
  String get qazaMissed => 'છૂટી ગયેલી';

  @override
  String get qazaEditCount => 'સંખ્યા સંપાદિત કરો';

  @override
  String get qazaMissedAWhile => 'થોડો સમય નમાઝો છૂટી ગઈ?';

  @override
  String get qazaMissedAWhileBody =>
      'કેટલો સમય તે નાખો, અને અમે છૂટેલા દરેક દિવસ માટે દરેક રોજિંદી નમાઝમાંથી એક ઉમેરીશું.';

  @override
  String get qazaPrayedFullDay => 'આખા દિવસની નમાઝ પઢી';

  @override
  String get qazaLoggedFullDay => 'દરેક રોજિંદી નમાઝમાંથી એક નોંધી';

  @override
  String get qazaAddedToList => 'તમારી કઝા યાદીમાં ઉમેર્યું';

  @override
  String get qazaRemainingLabel => 'બાકી';

  @override
  String get qazaCompletedLabel => 'પૂર્ણ';

  @override
  String get commonClear => 'સાફ કરો';

  @override
  String get qazaCalculateBody =>
      'લગભગ કેટલો સમય તમે નમાઝ ન પઢી? શ્રેષ્ઠ અંદાજ ચાલશે — કોઈ પણ નમાઝ પછીથી ગોઠવી શકો છો.';

  @override
  String get qazaPrayersMissedFor => 'આટલા સમયથી છૂટેલી નમાઝો';

  @override
  String get qazaYears => 'વર્ષ';

  @override
  String get qazaMonths => 'મહિના';

  @override
  String get qazaDays => 'દિવસ';

  @override
  String get qazaFastsMissed => 'છૂટેલા રોજા';

  @override
  String get qazaNumberOfFasts => 'રોજાની સંખ્યા';

  @override
  String get qazaThisAdds => 'આ તમારી યાદીમાં આ ઉમેરે છે:';

  @override
  String get qazaAddToList => 'મારી યાદીમાં ઉમેરો';

  @override
  String get qazaDhuhr => 'ધુહર';

  @override
  String get qazaAyat => 'નમાઝ-એ-આયાત';

  @override
  String get qazaOther => 'અન્ય';

  @override
  String audioMobileDataSizedBody(String size) {
    return 'તમે Wi-Fi પર નથી. આ લગભગ $size મોબાઇલ ડેટા વાપરશે.';
  }

  @override
  String get audioRemoveDownloadsTitle => 'ડાઉનલોડ્સ દૂર કરીએ?';

  @override
  String get audioRemoveDownloadTitle => 'ડાઉનલોડ દૂર કરીએ?';

  @override
  String audioRemoveBody(String subject) {
    return '$subject ફરી સ્ટ્રીમ થશે, તેથી સાંભળવા માટે કનેક્શન જોઈશે.';
  }

  @override
  String get audioTheseRecitations => 'આ પઠનો';

  @override
  String get audioThisRecitation => 'આ પઠન';

  @override
  String audioQuotedName(String name) {
    return '\"$name\"';
  }

  @override
  String audioRemoveFrees(String size) {
    return '$size ખાલી થશે.';
  }

  @override
  String get audioDownloadDone => 'ડાઉનલોડ થયું — કનેક્શન વગર ચાલે છે';

  @override
  String audioDownloadDoneNamed(String name) {
    return '$name ડાઉનલોડ થયું — કનેક્શન વગર ચાલે છે';
  }

  @override
  String get audioTheseRecitationsLower => 'આ પઠનો';

  @override
  String get audioThisRecitationLower => 'આ પઠન';

  @override
  String audioDownloadPartial(int saved, int total) {
    return '$totalમાંથી $saved ડાઉનલોડ થયા.';
  }

  @override
  String audioDownloadFailedNamed(String what) {
    return '$what ડાઉનલોડ થઈ શક્યું નહીં.';
  }

  @override
  String get audioDownloadOutOfSpace =>
      'તમારા ડિવાઇસમાં જગ્યા ખાલી નથી — થોડી ખાલી કરી ફરી પ્રયાસ કરો.';

  @override
  String get audioDownloadUnavailable => 'એક પઠન હવે ઉપલબ્ધ નથી.';

  @override
  String get audioDownloadCheckConnection =>
      'તમારું કનેક્શન તપાસી ફરી પ્રયાસ કરો.';

  @override
  String get commonRetry => 'ફરી પ્રયાસ કરો';

  @override
  String commonPercent(int percent) {
    return '$percent%';
  }

  @override
  String audioDownloadMore(int count) {
    return 'બીજા $count ડાઉનલોડ કરો';
  }

  @override
  String get audioDownloadAll => 'બધું ડાઉનલોડ કરો';

  @override
  String get audioDownloadForOffline => 'ઓફલાઇન સાંભળવા ડાઉનલોડ કરો';

  @override
  String get audioOfflineCannotDownload =>
      'તમે ઓફલાઇન છો. ડાઉનલોડ કરવા ઇન્ટરનેટ સાથે કનેક્ટ થાઓ.';

  @override
  String get audioMobileDataTitle => 'મોબાઇલ ડેટા વાપરી ડાઉનલોડ કરીએ?';

  @override
  String get audioMobileDataBody =>
      'તમે Wi-Fi પર નથી. પઠનો મોટા હોઈ શકે છે, તેથી આ ઘણો મોબાઇલ ડેટા વાપરી શકે છે.';

  @override
  String get commonRemove => 'દૂર કરો';

  @override
  String get audioDownloading => 'ડાઉનલોડ થઈ રહ્યું છે';

  @override
  String get audioDownloadingEllipsis => 'ડાઉનલોડ થઈ રહ્યું છે…';

  @override
  String get audioDownloadedTooltip =>
      'ઓફલાઇન સાંભળવા ડાઉનલોડ કરેલું. દૂર કરવા ટૅપ કરો.';

  @override
  String get audioRetryDownload => 'ડાઉનલોડ ફરી કરો';

  @override
  String get audioDownloadFailedTooltip =>
      'ડાઉનલોડ પૂરું ન થયું. ફરી પ્રયાસ કરવા ટૅપ કરો.';

  @override
  String get audioDownloadRestTooltip => 'બાકીનું ઓફલાઇન સાંભળવા ડાઉનલોડ કરો';

  @override
  String get counterSemanticsLabel => 'હાલની રકાત અને સજદા';

  @override
  String counterRakaatCompleted(int count) {
    return '$count રકાત પૂર્ણ';
  }

  @override
  String counterPosition(int rakaat, int sajdah) {
    return 'રકાત $rakaat · સજદા $sajdah';
  }

  @override
  String counterSajdahProgress(int done, int total) {
    return '$totalમાંથી $done સજદા';
  }

  @override
  String get counterSensorStopped =>
      'પ્રોક્સિમિટી સેન્સરે પ્રતિસાદ આપવાનું બંધ કર્યું. ફોનની સ્થિતિ તપાસો અને સ્વચાલિત સેન્સિંગ ફરી ચાલુ કરો.';

  @override
  String get counterStartOverTitle => 'ફરીથી શરૂ કરીએ?';

  @override
  String get counterStartOverBody =>
      'રકાતની સંખ્યા બદલવાથી હાલની નમાઝની ગણતરી ફરી શરૂ થશે.';

  @override
  String get counterStartOver => 'ફરીથી શરૂ કરો';

  @override
  String get counterTitle => 'રકાત કાઉન્ટર';

  @override
  String get counterHowToPlace => 'તમારો ફોન કેવી રીતે મૂકવો';

  @override
  String get counterPlaceBelowTurbah => 'ફોન તુરબહની નીચે મૂકો';

  @override
  String get counterPlaceBelowTurbahBody =>
      'તેને તુરબહની નીચે સપાટ મૂકો, ઉપલી ધાર તેની તરફ હોય એ રીતે. તમારા કપાળનો માર્ગ ખાલી રાખો.';

  @override
  String get counterPrayerLength => 'નમાઝની લંબાઈ';

  @override
  String get counterSelectRakaat => 'રકાતની સંખ્યા પસંદ કરો';

  @override
  String get counterComplete => 'પૂર્ણ';

  @override
  String get counterSajdahDetected => 'સજદો નોંધાયો';

  @override
  String get counterSensorReady => 'સેન્સર તૈયાર';

  @override
  String get counterCheckingSensor => 'સેન્સર તપાસાઈ રહ્યું છે';

  @override
  String get counterSensingOff => 'સ્વચાલિત સેન્સિંગ બંધ';

  @override
  String get counterTapHint => 'સજદો આપોઆપ ન નોંધાયો હોય તો જ ટૅપ કરો';

  @override
  String get counterReady => 'પહેલા સજદા માટે તૈયાર';

  @override
  String get counterAutomaticHint =>
      'સ્વચાલિત ગણતરી · એક છૂટી જાય તો જ ટૅપ કરો';

  @override
  String get counterManualHint => 'સજદો જાતે ઉમેરવા કાર્ડ પર ટૅપ કરો';

  @override
  String get counterCheckingDevice => 'આ ડિવાઇસ તપાસાઈ રહ્યું છે…';

  @override
  String get counterNotAvailable => 'આ ડિવાઇસ પર સ્વચાલિત ગણતરી ઉપલબ્ધ નથી.';

  @override
  String get counterObjectDetected =>
      'વસ્તુ નોંધાઈ. આગલી ગણતરી માટે તૈયાર થવા દૂર ખસો.';

  @override
  String get counterSensorArmed =>
      'તૈયાર — નોંધાયેલો દરેક સજદો એક વાર ગણાય છે.';

  @override
  String get counterSensorOffSubtitle => 'બંધ — સજદા આપોઆપ ગણવા આ ચાલુ કરો.';

  @override
  String get counterAutomaticSensing => 'સ્વચાલિત સેન્સિંગ';

  @override
  String get counterIphoneNote =>
      'iPhone પર, સેન્સર ઢંકાયેલું હોય ત્યારે ડિસ્પ્લે થોડી વાર બંધ થઈ શકે છે. સેન્સરનું સ્થાન અને રેન્જ મોડેલ મુજબ બદલાય છે.';

  @override
  String get counterAndroidNote =>
      'સેન્સરનું સ્થાન અને રેન્જ ફોન મુજબ બદલાય છે. કેટલાક Android ફોન ઓછું ભરોસાપાત્ર વર્ચ્યુઅલ પ્રોક્સિમિટી સેન્સર વાપરે છે.';

  @override
  String get counterPhonePlacement => 'ફોનની ગોઠવણ';

  @override
  String get counterPlacementBody =>
      'ફોનને તુરબહની નીચે સપાટ મૂકો, તેની ઉપલી ધાર અને સેન્સર તેની તરફ હોય એ રીતે. ફોનને તમારા કપાળના માર્ગથી સંપૂર્ણ બહાર રાખો.';

  @override
  String get counterPlacementTest =>
      'શરૂ કરતા પહેલાં સેન્સર સક્ષમ કરો અને તમારા હાથથી તેનું પરીક્ષણ કરો. દરેક પરીક્ષણ પછી હાથ દૂર ખસેડો જેથી આગલી ગણતરી તૈયાર થઈ શકે.';

  @override
  String quranJuzNumber(int number) {
    return 'જુઝ $number';
  }

  @override
  String quranCopiedVerse(String verse) {
    return '$verse કોપી થઈ';
  }

  @override
  String get quranRemoveFromSaved => 'સાચવેલામાંથી દૂર કરો';

  @override
  String get quranSaveVerse => 'આયત સાચવો';

  @override
  String quranRemovedVerse(String verse) {
    return '$verse દૂર કરી';
  }

  @override
  String quranSavedVerse(String verse) {
    return '$verse સાચવી';
  }

  @override
  String zikrPartNumber(int number) {
    return 'ભાગ $number';
  }

  @override
  String zikrBookmarkMoveHint(String icon) {
    return 'બુકમાર્ક થયું. તેને પછીથી ખસેડવા, \"બુકમાર્ક કર્યું\" લેબલ પરના $iconને બીજી લીટી પર ખેંચો.';
  }

  @override
  String get quranCopyVerse => 'આયત કોપી કરો';

  @override
  String get quranCopyLink => 'લિંક કોપી કરો';

  @override
  String get quranLinkCopied => 'લિંક કોપી થઈ';

  @override
  String get quranShareVerse => 'આયત શેર કરો';

  @override
  String get zikrMerits => 'ફઝીલત';

  @override
  String get zikrReportThanks => 'આભાર — અમે જોઈ લઈશું.';

  @override
  String get zikrReportFailed =>
      'રિપોર્ટ મોકલી શકાયો નહીં. કૃપા કરી ફરી પ્રયાસ કરો.';

  @override
  String get zikrSuggestCorrection => 'સુધારો સૂચવો';

  @override
  String get zikrSelectedText => 'પસંદ કરેલું લખાણ';

  @override
  String get zikrCorrectionHint => 'તેના બદલે શું હોવું જોઈએ? (વૈકલ્પિક)';

  @override
  String get commonSubmit => 'સબમિટ કરો';

  @override
  String get zikrSetReminder => 'રિમાઇન્ડર સેટ કરો';

  @override
  String get zikrUnableToOpen => 'આ દુઆ ખોલી શકાતી નથી.';

  @override
  String get zikrComingSoon => 'ટૂંક સમયમાં આવી રહ્યું છે...';

  @override
  String get zikrHideCounter => 'કાઉન્ટર છુપાવો';

  @override
  String deleteAccountSignInFailed(String error) {
    return 'સાઇન ઇન નિષ્ફળ: $error';
  }

  @override
  String deleteAccountSignOutFailed(String error) {
    return 'સાઇન આઉટ નિષ્ફળ: $error';
  }

  @override
  String deleteAccountFailed(String error) {
    return 'એકાઉન્ટ કાઢી નાખવામાં ભૂલ: $error';
  }

  @override
  String deleteAccountSignedInAs(String account) {
    return 'તમે $account તરીકે સાઇન ઇન છો.';
  }

  @override
  String get deleteAccountSignedIn => 'સફળતાપૂર્વક સાઇન ઇન થયું.';

  @override
  String get deleteAccountSignedOut => 'સાઇન આઉટ થઈ ગયું.';

  @override
  String get deleteAccountConfirmTitle => 'એકાઉન્ટ કાઢી નાખીએ?';

  @override
  String get deleteAccountConfirmBody =>
      'આ તમારું Shia Companion એકાઉન્ટ અને સિંક કરેલા મનપસંદ કાયમ માટે કાઢી નાખે છે.';

  @override
  String get deleteAccountDone => 'એકાઉન્ટ સફળતાપૂર્વક કાઢી નખાયું.';

  @override
  String get deleteAccountTitle => 'એકાઉન્ટ કાઢી નાખો';

  @override
  String get deleteAccountHeading =>
      'તમારું Shia Companion એકાઉન્ટ સંચાલિત કરો';

  @override
  String get deleteAccountSignInPrompt =>
      'તમારા સિંક કરેલા મનપસંદ સાથે જોડાયેલું એકાઉન્ટ જોવા અને કાયમ માટે કાઢી નાખવા સાઇન ઇન કરો.';

  @override
  String get deleteAccountWhatGetsDeleted => 'શું કાઢી નખાય છે';

  @override
  String get deleteAccountItemSignIn =>
      'તમારો Shia Companion એકાઉન્ટ સાઇન-ઇન રેકોર્ડ.';

  @override
  String get deleteAccountItemFavorites =>
      'તે એકાઉન્ટ માટે સંગ્રહેલા તમારા સિંક કરેલા મનપસંદ અને કઝા ટ્રેકર.';

  @override
  String get deleteAccountItemPreferences =>
      'તમારી સિંક કરેલી વાંચન પસંદગીઓ — હિજરી તારીખની ગોઠવણ અને ફોન્ટની પસંદગીઓ.';

  @override
  String get deleteAccountItemAnalytics =>
      'પહેલેથી એકત્ર કરેલા અનામી એનાલિટિક્સ કે ક્રેશ રિપોર્ટ્સ એકંદર સ્વરૂપમાં રહી શકે છે.';

  @override
  String get deleteAccountCompleted =>
      'તમારી એકાઉન્ટ કાઢી નાખવાની વિનંતી પૂર્ણ થઈ છે.';

  @override
  String get deleteAccountCompletedNote =>
      'તમે પછીથી ફરી સાઇન ઇન કરશો તો તદ્દન નવું એકાઉન્ટ બનશે.';

  @override
  String get deleteAccountWebSteps =>
      'નીચેનું Google સાઇન-ઇન બટન વાપરો, પછી કાઢી નાખવાની પુષ્ટિ કરો.';

  @override
  String get deleteAccountAppSteps =>
      'એપમાં પસંદગીઓ ખોલો અને મારું એકાઉન્ટ કાઢી નાખો વાપરો.';

  @override
  String get deleteAccountSigningIn => 'સાઇન ઇન થઈ રહ્યું છે...';

  @override
  String get deleteAccountDeleting => 'કાઢી નખાઈ રહ્યું છે...';

  @override
  String get deleteAccountButton => 'મારું એકાઉન્ટ કાઢી નાખો';

  @override
  String get deleteAccountSignOut => 'સાઇન આઉટ';

  @override
  String get deleteAccountHelp =>
      'મદદ જોઈએ છે? developer110@hotmail.com પર ઈમેઇલ કરો અને તમારા એકાઉન્ટ સાથે જોડાયેલું ઈમેઇલ સરનામું સામેલ કરો.';

  @override
  String statsBestStreak(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'શ્રેષ્ઠ: $days દિવસ',
      one: 'શ્રેષ્ઠ: એક દિવસ',
    );
    return '$_temp0';
  }

  @override
  String get statsTodayDone => 'આજે: થઈ ગયું';

  @override
  String get statsTodayNotYet => 'આજે: હજી નહીં';

  @override
  String statsDaysToGoal(int remaining, Object goal) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: 'લક્ષ્ય શ્રેણી સુધી $remaining દિવસ બાકી',
      one: 'લક્ષ્ય શ્રેણી સુધી એક દિવસ બાકી',
    );
    return '$_temp0';
  }

  @override
  String statsUpdatedHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours કલાક પહેલાં અપડેટ થયું',
      one: 'એક કલાક પહેલાં અપડેટ થયું',
    );
    return '$_temp0';
  }

  @override
  String statsUpdatedOn(String date) {
    return '$dateએ અપડેટ થયું';
  }

  @override
  String statsAllTime(String count) {
    return 'કુલ $count';
  }

  @override
  String statsCommunityNote(String updated) {
    return 'એપ વાપરતા દરેકના અનામી કુલ આંકડા. $updated.';
  }

  @override
  String get statsTitle => 'મારા આંકડા';

  @override
  String get statsYourMostRecited => 'તમારું સૌથી વધુ પઢેલું';

  @override
  String get statsStreakStart =>
      'એક દુઆ, ઝિયારત કે સૂરહ વાંચવાનું પૂરું કરો અને તમારી શ્રેણી શરૂ થાય છે.';

  @override
  String get statsWelcomeBack => 'ફરી સ્વાગત છે — દરેક દિવસ નવી શરૂઆત છે.';

  @override
  String get statsDoneTodayFirst =>
      'આજ માટે થઈ ગયું. શ્રેણી શરૂ કરવા આવતીકાલે પાછા આવો.';

  @override
  String get statsDoneToday => 'આજ માટે થઈ ગયું — આવતીકાલે મળીએ, ઇન્શા અલ્લાહ.';

  @override
  String get statsReadToday => 'તે ચાલુ રાખવા આજે કંઈક વાંચો.';

  @override
  String get statsDayStreak => 'દિવસની શ્રેણી';

  @override
  String get statsToday => 'આજે';

  @override
  String get statsPrivateSynced =>
      'તમારા આંકડા ખાનગી છે અને તમારા એકાઉન્ટમાં સાઇન ઇન થયેલા ડિવાઇસો વચ્ચે સિંક થાય છે.';

  @override
  String get statsPrivateLocal =>
      'તમારા આંકડા ખાનગી છે અને આ ડિવાઇસ પર જ રહે છે. તેમને ડિવાઇસો વચ્ચે રાખવા પસંદગીઓમાંથી સાઇન ઇન કરો.';

  @override
  String get statsUpdatedWithinHour => 'એક કલાકની અંદર અપડેટ થયું';

  @override
  String get statsAcrossCommunity => 'આખા સમુદાયમાં';

  @override
  String get statsRecitedThisWeek => 'આ અઠવાડિયે પઢેલી દુઆઓ, ઝિયારતો અને સૂરહો';

  @override
  String get statsMostRecitedThisWeek => 'આ અઠવાડિયે સૌથી વધુ પઢાયેલું';

  @override
  String quranSurahNumber(int number) {
    return 'સૂરહ $number';
  }

  @override
  String get listenQuranTextFailed =>
      'આ ડિવાઇસ પર કુરઆનનું લખાણ વાંચી શકાયું નહીં.';

  @override
  String get listenRecogniserStopped =>
      'ઓળખકર્તા અણધારી રીતે બંધ થઈ ગયો. ફરી પ્રયાસ કરો.';

  @override
  String get listenNothingRecognised =>
      'ઓળખી શકાય એવું કંઈ આવ્યું નહીં. પઠનકર્તાની થોડા નજીક રહી ફરી પ્રયાસ કરો.';

  @override
  String get listenCouldNotPlace =>
      'તે કુરઆનમાં મૂકી શકાયું નહીં. થોડું વધુ પઠન કરી જુઓ.';

  @override
  String get listenMicPermissionWeb =>
      'સાંભળવા માટે માઇક્રોફોનની પરવાનગી જોઈએ છે. તમે તે આ સાઇટની પરવાનગીઓમાં તમારા બ્રાઉઝરમાંથી આપી શકો છો.';

  @override
  String get listenMicPermission =>
      'સાંભળવા માટે માઇક્રોફોનની પરવાનગી જોઈએ છે. તમે તે તમારા ડિવાઇસની સેટિંગ્સમાં આપી શકો છો.';

  @override
  String get listenBrowserUnsupported =>
      'આ બ્રાઉઝર વાણી ઓળખી શકતું નથી. Chrome, Edge અને Safari શકે છે.';

  @override
  String get listenDeviceUnsupported =>
      'આ ડિવાઇસ પર કોઈ વાણી ઓળખકર્તા ઉપલબ્ધ નથી.';

  @override
  String get listenNoArabic =>
      'આ ડિવાઇસ પર અરબી વાણી ઓળખ સ્થાપિત નથી. તમારા ડિવાઇસની ભાષા સેટિંગ્સમાં અરબી ઉમેરવાથી તે સક્ષમ થશે.';

  @override
  String get listenStartFailed =>
      'સાંભળવાનું શરૂ થઈ શક્યું નહીં. ફરી પ્રયાસ કરો.';

  @override
  String get listenTitle => 'સાંભળો અને અનુસરો';

  @override
  String get listenGettingReady => 'તૈયાર થઈ રહ્યું છે…';

  @override
  String get listenListening => 'સાંભળી રહ્યું છે…';

  @override
  String get listenHoldPhone => 'ફોનને પઠન તરફ રાખો.';

  @override
  String get listenFindNow => 'આયત હમણાં શોધો';

  @override
  String get listenFinding => 'આયત શોધાઈ રહી છે…';

  @override
  String get listenWhichVerse => 'તે કઈ આયત હતી?';

  @override
  String get listenAgain => 'ફરી સાંભળો';

  @override
  String get commonTryAgain => 'ફરી પ્રયાસ કરો';

  @override
  String flightDepartureDateAt(String airport) {
    return '$airport પર પ્રસ્થાન તારીખ';
  }

  @override
  String flightArrivalDateAt(String airport) {
    return '$airport પર આગમન તારીખ';
  }

  @override
  String flightDepartureTimeAt(String airport) {
    return 'પ્રસ્થાન સમય ($airport પર સ્થાનિક)';
  }

  @override
  String flightArrivalTimeAt(String airport) {
    return 'આગમન સમય ($airport પર સ્થાનિક)';
  }

  @override
  String flightDurationTooLong(String duration) {
    return 'તે મુજબ હવામાં $duration થાય છે. આગમન તારીખ તપાસો.';
  }

  @override
  String get flightFrom => 'અહીંથી';

  @override
  String get flightTo => 'અહીં સુધી';

  @override
  String get flightDeparts => 'પ્રસ્થાન';

  @override
  String get flightArrives => 'આગમન';

  @override
  String get flightDepartureAirport => 'પ્રસ્થાન એરપોર્ટ';

  @override
  String get flightArrivalAirport => 'આગમન એરપોર્ટ';

  @override
  String get flightChooseDepartureFirst => 'પહેલાં પ્રસ્થાન એરપોર્ટ પસંદ કરો.';

  @override
  String get flightChooseArrivalFirst => 'પહેલાં આગમન એરપોર્ટ પસંદ કરો.';

  @override
  String get flightChooseBothAirports => 'બંને એરપોર્ટ પસંદ કરો.';

  @override
  String get flightSetTimes => 'પ્રસ્થાન અને આગમનના સમય સેટ કરો.';

  @override
  String get flightAirportsMustDiffer =>
      'પ્રસ્થાન અને આગમન એરપોર્ટ અલગ હોવા જોઈએ.';

  @override
  String get flightTimeZoneUnresolved =>
      'તે એરપોર્ટમાંથી એકનો સમય ઝોન ઉકેલી શકાયો નહીં.';

  @override
  String get flightArrivalBeforeDeparture =>
      'સમય ઝોન લાગુ કર્યા પછી આગમન પ્રસ્થાન પહેલાં આવે છે. આગમન તારીખ તપાસો — રાતોરાત ફ્લાઇટ્સ બીજા દિવસે ઉતરે છે.';

  @override
  String get flightAdd => 'ફ્લાઇટ ઉમેરો';

  @override
  String get flightDepartsHint => 'પ્રસ્થાન એરપોર્ટ પર સ્થાનિક સમય';

  @override
  String get flightArrivesHint => 'આગમન એરપોર્ટ પર સ્થાનિક સમય';

  @override
  String get flightNumberLabel => 'ફ્લાઇટ નંબર (વૈકલ્પિક)';

  @override
  String get flightSaveChanges => 'ફેરફારો સાચવો';

  @override
  String get flightSave => 'ફ્લાઇટ સાચવો';

  @override
  String get flightTicketNote =>
      'સમય બરાબર તમારી ટિકિટ પર દેખાય છે એમ જ નાખો — દરેક તેના પોતાના એરપોર્ટના સ્થાનિક સમયમાં.';

  @override
  String get flightChooseAirport => 'એરપોર્ટ પસંદ કરો';

  @override
  String get flightChooseDateTime => 'તારીખ અને સમય પસંદ કરો';

  @override
  String get widgetIslamicCalendar => 'ઇસ્લામી કેલેન્ડર';

  @override
  String get widgetFavorites => 'મનપસંદ';

  @override
  String get widgetNoFavorites => 'હજી કોઈ મનપસંદ નથી';

  @override
  String get widgetTodaysRecitations => 'આજના પઠન';

  @override
  String get widgetOpenAppToRefresh => 'તાજું કરવા એપ ખોલો';

  @override
  String get widgetUpNext => 'હવે પછી';

  @override
  String get widgetPrayerTimes => 'નમાઝના સમય';

  @override
  String get widgetLocationNeeded => 'સ્થાન જરૂરી છે';

  @override
  String get widgetSavedLocation => 'સાચવેલું સ્થાન';

  @override
  String get widgetSetLocation => 'સ્થાન સેટ કરો';

  @override
  String get widgetOpenApp => 'એપ ખોલો';

  @override
  String get widgetRefreshSchedule => 'સમયપત્રક તાજું કરો';

  @override
  String get commonToday => 'આજે';

  @override
  String get commonTomorrow => 'આવતીકાલે';

  @override
  String quranSurahAyah(String surah, int ayah) {
    return '$surah $ayah';
  }

  @override
  String trackNameTaken(String name) {
    return '\"$name\" નામનો ટ્રેક પહેલેથી છે';
  }

  @override
  String get trackNameRequired => 'ટ્રેકને નામ આપો';

  @override
  String get trackBeginning => 'શરૂઆત';

  @override
  String get trackNew => 'નવો પઠન ટ્રેક';

  @override
  String get trackName => 'નામ';

  @override
  String get trackNameHint => 'દા.ત. કુટુંબ, તહજ્જુદ';

  @override
  String get trackReadBy => 'પઢનાર';

  @override
  String get trackBySurah => 'સૂરહ';

  @override
  String get trackByJuz => 'જુઝ (પારા)';

  @override
  String get trackContinueFrom => 'અહીંથી આગળ';

  @override
  String get trackStartFrom => 'અહીંથી શરૂ';

  @override
  String get trackStartAt => 'અહીંથી શરૂ કરો';

  @override
  String get trackEditNote =>
      'તમે વાંચતા જાઓ તેમ તમારો ટ્રેક આપોઆપ આગળ વધે છે. બીજે ક્યાંકથી આગળ વધવું હોય તો જ આ બદલો.';

  @override
  String get trackNewNote => 'આ તમે ટ્રેક કાર્ડમાંથી ગમે ત્યારે બદલી શકો છો.';

  @override
  String get trackCreate => 'ટ્રેક બનાવો';

  @override
  String notifDefaultSoundSubtitle(String sound) {
    return '$sound · નીચેનો કોઈ સમય તેને બદલે નહીં ત્યાં સુધી વપરાય છે';
  }

  @override
  String notifCustomSound(String file) {
    return 'કસ્ટમ: $file';
  }

  @override
  String notifPrayerSound(String prayer) {
    return '$prayerનો અવાજ';
  }

  @override
  String notifFollows(String sound) {
    return '$soundને અનુસરે છે';
  }

  @override
  String get notifDefaultSound => 'ડિફોલ્ટ અવાજ';

  @override
  String get notifTimesHeading => 'સમય';

  @override
  String get notifAudioUnreadable => 'તે ઓડિયો ફાઇલ વાંચી શકાઈ નહીં.';

  @override
  String get notifPickFailed => 'તે ફાઇલ પસંદ થઈ શકી નહીં. ફરી પ્રયાસ કરો.';

  @override
  String get notifPlayingSample => 'થોડી વારમાં નમૂનો ચાલશે…';

  @override
  String get notifUseDefault => 'ડિફોલ્ટ વાપરો';

  @override
  String get notifOwnSoundNote =>
      'આ સમય પોતાનો અવાજ રાખે છે. બાકીનું બધું ડિફોલ્ટને અનુસરે છે.';

  @override
  String get notifDefaultNote =>
      'દરેક સમય આને અનુસરે છે, સિવાય કે તમે તેને પોતાનો અવાજ આપો.';

  @override
  String get notifPreview => 'પૂર્વાવલોકન';

  @override
  String aboutVersion(String version) {
    return 'આવૃત્તિ $version';
  }

  @override
  String get aboutDedication =>
      'અમે સર્વશક્તિમાન અલ્લાહ અને તેમના પ્રિય ચૌદ માસૂમીન (અ.સ.)નો આભાર માનીએ છીએ, જેમની મદદથી અમે આ નમ્ર કાર્ય મોમિનીન સાથે વહેંચી શક્યા. અમે આ એપ તેમને અને નીચેના મરહૂમીનને અર્પણ કરીએ છીએ:\n\nMarhooma Amina Mohammed Raza Jassani\nMarhoom Haji Mohammad Raza Jassani\nMarhoom Haji Yusufali Bhojani\n\n\nકૃપા કરી મરહૂમીન અને મરહૂમાત માટે સૂરહ ફાતેહા પઢો\n\nપ્રતિસાદ, પ્રશ્નો કે સૂચનો માટે સંપર્ક કરો :';

  @override
  String get aboutNoEmailApp => 'કોઈ ઈ-મેઇલ એપ મળી નહીં';

  @override
  String get aboutCredits => 'શ્રેય';

  @override
  String get aboutCreditAudio =>
      'પઠન ઓડિયો અમારા પોતાના સર્વર પર રાખવામાં આવ્યો છે; રેકોર્ડિંગ duas.orgની માયાળુ પરવાનગીથી વપરાયા છે.';

  @override
  String get aboutCreditScheherazade =>
      'અરબી Scheherazade Newમાં ગોઠવવામાં આવ્યું છે, જે SIL Globalનું છે અને SIL Open Font License હેઠળ વપરાય છે.';

  @override
  String get aboutCreditTanzil =>
      'Scheherazade સાથે બતાવાતું ઉસ્માની કુરઆન લખાણ Tanzil Projectનું છે, Creative Commons Attribution 3.0 હેઠળ વપરાય છે.';

  @override
  String get aboutCreditQuranWbw =>
      'Qalam સાથે બતાવાતું ઇન્ડોપાક કુરઆન લખાણ અને ફોન્ટ QuranWBW.comના છે. કુરઆન લખાણ અને ફોન્ટ અબદલાયેલા વગર વાપરવાની પરવાનગી મૂળ યોગદાનકર્તા QuranWBW.com તરફથી મળી હતી.';

  @override
  String get aboutCreditIndoPakFont =>
      'ફોન્ટ: AlQuran IndoPak by QuranWBW, Ayman Siddiquiએ બનાવેલ, Al Qalam Quran Majeed ફોન્ટ્સ પર આધારિત, આયત નંબર KFGQPC Nastaleeq ફોન્ટમાંથી. © Al Qalam © Ghandhara © KFGQPC © Ayman Siddiqui. શ્રેય: Abdul Majeed Khan, Arif Karim, Shakir-ul-Qadree, Jawad. કુરઆન લખાણ: typemybook.com, મૂળ InPage દ્વારા.';

  @override
  String downloadsRemoveAllBody(String size) {
    return 'દરેક પઠન ફરી સ્ટ્રીમ થશે, તેથી સાંભળવા માટે કનેક્શન જોઈશે. $size ખાલી થશે.';
  }

  @override
  String downloadsOlderSubtitle(int count, String size) {
    return '$count હવે કોઈ દુઆ દ્વારા વપરાતા નથી · $size';
  }

  @override
  String get downloadsRemoveAllTitle => 'તમામ ડાઉનલોડ્સ દૂર કરીએ?';

  @override
  String get downloadsRemoveAll => 'બધા દૂર કરો';

  @override
  String get downloadsEmpty => 'હજી કોઈ ડાઉનલોડ નથી';

  @override
  String get downloadsEmptyBody =>
      'કનેક્શન વગર સાંભળવા પઠન ડાઉનલોડ કરો — દુઆના ઓડિયો પ્લેયરમાં ડાઉનલોડ બટન ટૅપ કરો, અથવા પ્લેલિસ્ટ પર બધું ડાઉનલોડ કરો.';

  @override
  String get downloadsOlder => 'જૂના રેકોર્ડિંગ';

  @override
  String get downloadsRemoveOlder => 'જૂના રેકોર્ડિંગ દૂર કરો';

  @override
  String get hijriMonth1 => 'મુહર્રમ';

  @override
  String get hijriMonth2 => 'સફર';

  @override
  String get hijriMonth3 => 'રબી અલ-અવ્વલ';

  @override
  String get hijriMonth4 => 'રબી અલ-થાની';

  @override
  String get hijriMonth5 => 'જુમાદા અલ-અવ્વલ';

  @override
  String get hijriMonth6 => 'જુમાદા અલ-થાની';

  @override
  String get hijriMonth7 => 'રજબ';

  @override
  String get hijriMonth8 => 'શાબાન';

  @override
  String get hijriMonth9 => 'રમઝાન';

  @override
  String get hijriMonth10 => 'શવ્વાલ';

  @override
  String get hijriMonth11 => 'ધુ અલ-કઅદા';

  @override
  String get hijriMonth12 => 'ધુ અલ-હિજ્જા';

  @override
  String get hijriMonthShort1 => 'મુહ';

  @override
  String get hijriMonthShort2 => 'સફ';

  @override
  String get hijriMonthShort3 => 'રબી 1';

  @override
  String get hijriMonthShort4 => 'રબી 2';

  @override
  String get hijriMonthShort5 => 'જુમા 1';

  @override
  String get hijriMonthShort6 => 'જુમા 2';

  @override
  String get hijriMonthShort7 => 'રજ';

  @override
  String get hijriMonthShort8 => 'શાબ';

  @override
  String get hijriMonthShort9 => 'રમ';

  @override
  String get hijriMonthShort10 => 'શવ';

  @override
  String get hijriMonthShort11 => 'ધુલ ક';

  @override
  String get hijriMonthShort12 => 'ધુલ હ';

  @override
  String prayerUpdatedAgo(String age) {
    return '$age અપડેટ થયું';
  }

  @override
  String get prayerNextDay => '(બીજો દિવસ)';

  @override
  String get prayerLocating => 'સ્થાન શોધાઈ રહ્યું છે…';

  @override
  String get prayerForYourLocation => 'તમારા સ્થાન માટે નમાઝના સમય';

  @override
  String get prayerFindingLocation => 'તમારું સ્થાન શોધાઈ રહ્યું છે';

  @override
  String get prayerAppearSoon => 'નમાઝના સમય થોડી વારમાં દેખાશે';

  @override
  String get prayerTapToRetry => 'ફરી પ્રયાસ કરવા ટૅપ કરો';

  @override
  String get prayerLocationUnavailable => 'સ્થાન ઉપલબ્ધ નથી';

  @override
  String get prayerTapToEnableLocation => 'સ્થાન સક્ષમ કરવા અહીં ટૅપ કરો';

  @override
  String calendarNotificationsSomeOn(int enabled, int total) {
    return '$totalમાંથી $enabled ચાલુ';
  }

  @override
  String get calendarNoEvent => 'આ તારીખ માટે કોઈ પ્રસંગ નોંધાયેલો નથી.';

  @override
  String get calendarNotificationsAllOff => 'દરેક નમાઝ માટે બંધ';

  @override
  String get readingFineTune =>
      'ઝિક્ર લખાણને ઝીણવટથી ગોઠવો. સેટિંગ્સમાં એપ લખાણ કદ ઉપરાંત લાગુ થાય છે.';

  @override
  String get readingArabicFontSize => 'અરબી ફોન્ટનું કદ';

  @override
  String get readingEnglishFontSize => 'અંગ્રેજી ફોન્ટનું કદ';

  @override
  String get readingArabicFont => 'અરબી ફોન્ટ';

  @override
  String get readingKeepScreenOn => 'ઝિક્ર પઢતી વખતે સ્ક્રીન ચાલુ રાખો';

  @override
  String get readingFocusMode => 'ફોકસ મોડ';

  @override
  String get readingFocusModeSubtitle =>
      'વાંચતી વખતે પ્રગતિ પટ્ટી અને ક્રિયા પટ્ટી છુપાવો. તેમને પાછા લાવવા ઉપર સ્ક્રોલ કરો અથવા ટૅપ કરો.';

  @override
  String get readingShareAsImage => 'ઝિક્ર છબી તરીકે શેર કરો';

  @override
  String get readingShareAsImageSubtitle =>
      'શેર કરતી વખતે સુંદર ગોઠવેલી છબી બનાવો.';

  @override
  String get readingShowTransliteration => 'લિપ્યંતર બતાવો';

  @override
  String get readingShowTranslation => 'અનુવાદ બતાવો';

  @override
  String get readingArabicParagraph => 'અરબી ફકરા તરીકે બતાવો';

  @override
  String get readingArabicParagraphOn =>
      'અરબી આયતોને અલગ લીટીઓને બદલે એક ફકરા તરીકે વહેતી રાખો.';

  @override
  String get readingArabicParagraphOff =>
      'આ વાપરવા ઉપર લિપ્યંતર અને અનુવાદ બંધ કરો.';

  @override
  String pickerJuzRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String pickerSurahDetails(String ayahs, String juz) {
    return '$ayahs · જુઝ $juz';
  }

  @override
  String quranAyahCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count આયતો',
      one: 'એક આયત',
    );
    return '$_temp0';
  }

  @override
  String pickerJuzFrom(String start) {
    return '$startથી';
  }

  @override
  String pickerAyahSingle(int ayah) {
    return 'આયત $ayah';
  }

  @override
  String pickerAyahRange(int from, int to) {
    return 'આયતો $from–$to';
  }

  @override
  String get pickerThirtyJuz => 'કુલ 30 જુઝ છે';

  @override
  String get pickerTryVerse => '33:33 જેવી આયત, અથવા જુઝ 22 અજમાવો';

  @override
  String get pickerSearchHint => 'આયત પર જાઓ — 33:33, 18, જુઝ 22';

  @override
  String get pickerChooseVerse => 'આયત પસંદ કરો';

  @override
  String get pickerAllJuz => 'તમામ જુઝ';

  @override
  String get pickerAllSurahs => 'તમામ સૂરહો';

  @override
  String get pickerChoose => 'પસંદ કરો';

  @override
  String quranFromPosition(String position) {
    return '$positionથી';
  }

  @override
  String quranPercentRead(String percent) {
    return 'કુરઆનના $percent%';
  }

  @override
  String quranEditTrack(String track) {
    return '$track ટ્રેક સંપાદિત કરો';
  }

  @override
  String get quranTitle => 'કુરઆન';

  @override
  String get quranRecentSessions => 'તાજેતરના સેશન';

  @override
  String get quranTabSurahs => 'સૂરહો';

  @override
  String get quranTabJuz => 'જુઝ';

  @override
  String get quranTabCollections => 'સંગ્રહો';

  @override
  String get quranStartReading => 'વાંચવાનું શરૂ કરો';

  @override
  String get quranNewTrack => 'નવો ટ્રેક';

  @override
  String get quranGoToVerseError => '23:56 જેવું કંઈક અજમાવો';

  @override
  String get quranGoToVerseHint => 'આયત પર જાઓ, દા.ત. 23:56';

  @override
  String get quranGo => 'જાઓ';

  @override
  String get statsMetricVerses => 'આયતો';

  @override
  String get statsMetricZikrs => 'ઝિક્ર';

  @override
  String get statsMetricQaza => 'કઝા';

  @override
  String get statsMetricVersesLower => 'આયતો';

  @override
  String get statsMetricZikrsLower => 'ઝિક્ર';

  @override
  String get statsMetricQazaLower => 'કઝા';

  @override
  String statsVerseCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count આયતો',
      one: '$count આયત',
    );
    return '$_temp0';
  }

  @override
  String statsZikrCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ઝિક્ર',
      one: '$count ઝિક્ર',
    );
    return '$_temp0';
  }

  @override
  String statsQazaCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count કઝા',
    );
    return '$_temp0';
  }

  @override
  String get statsPeriodWeek => 'અઠવાડિયું';

  @override
  String get statsPeriodMonth => 'મહિનો';

  @override
  String get statsPeriodAllTime => 'કુલ સમય';

  @override
  String statsCaptionWeek(String metric) {
    return 'છેલ્લા 7 દિવસમાં $metric';
  }

  @override
  String statsCaptionMonth(String metric) {
    return 'છેલ્લા 30 દિવસમાં $metric';
  }

  @override
  String statsCaptionAllTime(String metric) {
    return 'કુલ $metric';
  }

  @override
  String get statsHistory => 'ઇતિહાસ';

  @override
  String statsBestMonth(String month, String count) {
    return 'શ્રેષ્ઠ મહિનો: $month · $count';
  }

  @override
  String statsBestDay(String day, String count, String average) {
    return 'શ્રેષ્ઠ દિવસ: $day · $count · રોજ સરેરાશ $average';
  }

  @override
  String get statsNew => 'નવું';

  @override
  String statsVersusBefore(String count) {
    return 'પહેલાંના $countની સામે';
  }

  @override
  String statsSessionCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count સેશન',
      one: '$count સેશન',
    );
    return '$_temp0';
  }

  @override
  String statsVersesRecited(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count આયતો વંચાઈ',
      one: '$count આયત વંચાઈ',
    );
    return '$_temp0';
  }

  @override
  String statsLastOn(String date) {
    return 'છેલ્લે $date';
  }

  @override
  String statsVersesLeft(String count) {
    return 'ખત્મ પૂર્ણ કરવા $count આયતો બાકી';
  }

  @override
  String statsJuzCoverage(int juz, int percent) {
    return 'જુઝ $juz: $percent%';
  }

  @override
  String statsJuzComplete(int count) {
    return '30માંથી $count જુઝ પૂર્ણ';
  }

  @override
  String get statsQuranProgress => 'કુરઆનની પ્રગતિ';

  @override
  String get statsQuranEmpty =>
      'સૂરહ ખોલો અને વાંચવાનું શરૂ કરો — તમે પઢો છો તે આયતો અહીં આપોઆપ નોંધાય છે, સંપૂર્ણ ખત્મ તરફની તમારી પ્રગતિ સાથે.';

  @override
  String get statsRecitedTill => 'આટલે સુધી પઢ્યું';

  @override
  String get statsNotStarted => 'શરૂ થયું નથી';

  @override
  String get statsJuzDone => 'જુઝ પૂરો';

  @override
  String get statsKhatmComplete => 'ખત્મ પૂર્ણ — તે સ્વીકાર્ય થાય';

  @override
  String reminderAtPrayer(String prayer) {
    return '$prayer વખતે';
  }

  @override
  String reminderMinutesAfter(int minutes, String prayer) {
    return '$prayer પછી $minutes મિનિટ';
  }

  @override
  String reminderMinutesBefore(int minutes, String prayer) {
    return '$prayer પહેલાં $minutes મિનિટ';
  }

  @override
  String azanPlaying(String prayer) {
    return '$prayer અઝાન ચાલી રહી છે';
  }

  @override
  String get libraryNeedsNetwork =>
      'લાઇબ્રેરી જોવા માટે નેટવર્ક કનેક્શન જોઈએ છે.';

  @override
  String get libraryChaptersFailed =>
      'પ્રકરણો લોડ થઈ શક્યા નહીં. કૃપા કરી ફરી પ્રયાસ કરો.';

  @override
  String get libraryReadingNeedsNetwork =>
      'પુસ્તકો વાંચવા માટે નેટવર્ક કનેક્શન જોઈએ છે.';

  @override
  String get libraryChapterFailed =>
      'આ પ્રકરણ લોડ થઈ શક્યું નહીં. કૃપા કરી ફરી પ્રયાસ કરો.';

  @override
  String get menuCalendarPrayerTimes => 'કેલેન્ડર અને નમાઝના સમય';

  @override
  String get menuFavorites => 'મનપસંદ';

  @override
  String get menuTodaysRecitations => 'આજના પઠન';

  @override
  String get menuTaqeebat => 'તઅકીબાત-એ-નમાઝ';

  @override
  String get menuNamaz => 'નમાઝ';

  @override
  String get menuDuas => 'દુઆઓ';

  @override
  String get menuZiyarats => 'ઝિયારતો';

  @override
  String get menuSurahs => 'સૂરહો';

  @override
  String get menuAamaal => 'આમાલ';

  @override
  String get menuLibrary => 'લાઇબ્રેરી';

  @override
  String get menuMunajaat => 'મુનાજાત';

  @override
  String get menuBaaqeyaat => 'બાકિયાત અસ-સાલેહાત';

  @override
  String get menuQiblaFinder => 'કિબલા શોધક';

  @override
  String get menuTasbeehCounter => 'તસ્બીહ કાઉન્ટર';

  @override
  String get menuQazaTracker => 'કઝા ટ્રેકર';

  @override
  String get menuRakaatCounter => 'રકાત કાઉન્ટર';

  @override
  String get menuPrayerTimesInFlight => 'ફ્લાઇટમાં નમાઝના સમય';

  @override
  String get menuPreferences => 'પસંદગીઓ';

  @override
  String get menuQuran => 'કુરઆન';

  @override
  String get menuPlaylists => 'પ્લેલિસ્ટ્સ';

  @override
  String get menuMyStats => 'મારા આંકડા';

  @override
  String get menuCalendar => 'કેલેન્ડર';

  @override
  String audioTrackNumber(int number) {
    return 'ટ્રેક $number';
  }

  @override
  String get audioPauseRecitation => 'પઠન થોભાવો';

  @override
  String get audioPlayRecitation => 'પઠન ચલાવો';

  @override
  String get audioList => 'ઓડિયો યાદી';

  @override
  String get audioOfflineNotDownloaded =>
      'તમે ઓફલાઇન છો અને આ પઠન ડાઉનલોડ થયેલું નથી';

  @override
  String get audioLoadFailed => 'આ પઠન લોડ થઈ શક્યું નહીં';

  @override
  String get audioClosePlayer => 'પ્લેયર બંધ કરો';

  @override
  String get audioChooseRecording => 'રેકોર્ડિંગ પસંદ કરો';

  @override
  String get audioRecitation => 'પઠન';

  @override
  String get audioRecitationAudio => 'પઠન ઓડિયો';

  @override
  String librarySavedOffline(String book) {
    return '$book ઓફલાઇન માટે સાચવાયું.';
  }

  @override
  String librarySaveFailed(String error) {
    return 'પુસ્તક સાચવી શકાયું નહીં: $error';
  }

  @override
  String libraryProgress(String chapter, int page, int pages) {
    return '$chapter — પાનું $page / $pages';
  }

  @override
  String get librarySavedChapterGone => 'સાચવેલું પ્રકરણ હવે ઉપલબ્ધ નથી';

  @override
  String get libraryUnavailable => 'લાઇબ્રેરી ઉપલબ્ધ નથી';

  @override
  String get libraryNoBooks => 'કોઈ પુસ્તકો મળ્યા નહીં';

  @override
  String get libraryEmpty => 'લાઇબ્રેરી હાલમાં ખાલી છે.';

  @override
  String get libraryContinueReading => 'વાંચવાનું આગળ વધારો';

  @override
  String get libraryRequestBook => 'પુસ્તકની વિનંતી કરો';

  @override
  String get libraryRequestBookSubtitle => 'પુસ્તક નથી મળતું? અમને ઉમેરવા કહો.';

  @override
  String flightRemoveBody(String flight) {
    return '$flight તમારી સાચવેલી ફ્લાઇટ્સમાંથી દૂર થશે.';
  }

  @override
  String flightLands(String duration, String time, String airport) {
    return '$duration · $timeએ ઉતરે છે, $airportનો સમય';
  }

  @override
  String get flightRemoveTitle => 'ફ્લાઇટ દૂર કરીએ?';

  @override
  String get flightRemove => 'ફ્લાઇટ દૂર કરો';

  @override
  String get flightNoneSaved => 'કોઈ ફ્લાઇટ સાચવેલી નથી';

  @override
  String get flightNoneSavedBody =>
      'તમારી ફ્લાઇટ ઉમેરો અને આ પાનું માર્ગ દરમિયાન દરેક નમાઝ ક્યારે આવે છે તે ગણી આપશે — તમારા પ્રસ્થાન અને આગમન બંને શહેરના સમયમાં બતાવેલું.';

  @override
  String librarySavedForOffline(String title) {
    return '$title ઓફલાઇન માટે સાચવાયું';
  }

  @override
  String librarySaveFailedShort(String error) {
    return 'સાચવવું નિષ્ફળ: $error';
  }

  @override
  String get libraryOfflineRemoved => 'ઓફલાઇન નકલ દૂર કરી';

  @override
  String get libraryShareBook => 'પુસ્તક શેર કરો';

  @override
  String get libraryRemoveOffline => 'ઓફલાઇન નકલ દૂર કરો';

  @override
  String get librarySaveOffline => 'પુસ્તક ઓફલાઇન સાચવો';

  @override
  String get libraryChaptersUnavailable => 'પ્રકરણો ઉપલબ્ધ નથી';

  @override
  String get libraryNoChapters => 'કોઈ પ્રકરણો મળ્યા નહીં';

  @override
  String get libraryNoChaptersBody => 'આ પુસ્તકમાં હાલમાં કોઈ પ્રકરણો નથી.';

  @override
  String quranMoveEntry(String entry) {
    return '\"$entry\" ખસેડો';
  }

  @override
  String get quranNoSessions =>
      'હજી કોઈ સેશન નથી. સૂરહ ખોલો અને વાંચવાનું શરૂ કરો — તમે પઢો છો તે આયતો અહીં આપોઆપ નોંધાય છે.';

  @override
  String get quranMoveToLabel => 'બીજા લેબલ પર ખસેડો';

  @override
  String get quranNewLabel => 'અથવા નવું લેબલ';

  @override
  String get quranMove => 'ખસેડો';

  @override
  String get quranCollectionDuas => 'દુઆઓ';

  @override
  String get quranCollectionImamAli => 'ઇમામ અલી (અ.સ.)';

  @override
  String get quranCollectionImamMahdi => 'ઇમામ અલ-મહદી (અ.ત.ફ.સ.)';

  @override
  String get quranCollectionProphets => 'નબીઓ';

  @override
  String get quranCollectionSaved => 'સાચવેલું';

  @override
  String get quranFromTheQuran => 'કુરઆનમાંથી';

  @override
  String get quranNoSavedVerses => 'હજી કોઈ આયતો સાચવેલી નથી';

  @override
  String get quranNoSavedVersesBody =>
      'વાંચતી વખતે આયત પર ટૅપ કરો અને તે અહીં રહેશે.';

  @override
  String get libraryNextChapter => 'આગળનું પ્રકરણ';

  @override
  String get libraryPreviousChapter => 'પાછળનું પ્રકરણ';

  @override
  String get libraryNextPage => 'આગળનું પાનું';

  @override
  String get libraryPreviousPage => 'પાછળનું પાનું';

  @override
  String libraryNextChapterNamed(String chapter) {
    return 'આગળનું પ્રકરણ: $chapter';
  }

  @override
  String libraryPreviousChapterNamed(String chapter) {
    return 'પાછળનું પ્રકરણ: $chapter';
  }

  @override
  String libraryNextShort(String chapter) {
    return 'આગળ: $chapter';
  }

  @override
  String libraryPreviousShort(String chapter) {
    return 'પાછળ: $chapter';
  }

  @override
  String get libraryShareChapter => 'પ્રકરણ શેર કરો';

  @override
  String get libraryChapterUnavailable => 'પ્રકરણ ઉપલબ્ધ નથી';

  @override
  String get libraryDecreaseFont => 'ફોન્ટનું કદ ઘટાડો';

  @override
  String get libraryIncreaseFont => 'ફોન્ટનું કદ વધારો';

  @override
  String get azaanTakbirName => 'ફક્ત તકબીર';

  @override
  String get azaanTakbirDescription => 'ટૂંકો તકબીર સૂચના અવાજ';

  @override
  String get azaanFullName => 'પૂરી અઝાન';

  @override
  String get azaanFullDescription => 'પૂરી અઝાન, આપોઆપ ચાલે છે';

  @override
  String get azaanFullIosDescription =>
      'સૂચના તકબીર વગાડે છે; તેને ટૅપ કરી પૂરી અઝાન સાંભળો';

  @override
  String get azaanSystemDefaultName => 'સિસ્ટમ ડિફોલ્ટ';

  @override
  String get azaanSystemDefaultDescription =>
      'તમારા ડિવાઇસનો ડિફોલ્ટ સૂચના અવાજ વાપરો';

  @override
  String get azaanSilentName => 'શાંત';

  @override
  String get azaanSilentDescription => 'ફક્ત સૂચના બેનર (અવાજ નહીં)';

  @override
  String get azaanCustomName => 'કસ્ટમ ઓડિયો';

  @override
  String get azaanCustomDescription => 'તમારા ડિવાઇસમાંથી ઓડિયો ફાઇલ પસંદ કરો';

  @override
  String get ratingEnjoying => 'Shia Companion ગમે છે?';

  @override
  String get ratingEnjoyingBody =>
      'તમને તે કેવું લાગે છે તે સાંભળવું અમને ગમશે — તમારો પ્રતિસાદ એપને સુધારતા રહેવામાં અમને મદદ કરે છે.';

  @override
  String get ratingNotReally => 'ખાસ નહીં';

  @override
  String get ratingYes => 'હા!';

  @override
  String get ratingSorry => 'તે સાંભળી દુઃખ થયું';

  @override
  String get ratingSorryBody =>
      'શું કામ નથી કરતું તે કહેશો? તે એપ સુધારવામાં અમને મદદ કરે છે.';

  @override
  String get ratingNoThanks => 'ના, આભાર';

  @override
  String get ratingSendFeedback => 'પ્રતિસાદ મોકલો';

  @override
  String get azaanOptInIntro =>
      'Shia Companion તમને ફજર, ઝોહર અને મગરીબ વખતે સૂચના મોકલી શકે છે અને અઝાન વગાડી શકે છે.';

  @override
  String get azaanOptInIosNote =>
      'iPhone પર સૂચના ટૂંકી તકબીર વગાડે છે. તેને ટૅપ કરતી વખતે આખી અઝાન સાંભળવા સેટિંગ્સમાં પૂરી અઝાન પસંદ કરો.';

  @override
  String get azaanOptInChangeLater =>
      'કઈ નમાઝો તમને સૂચના આપે તે, અલગ અવાજ પસંદ કરવો, કે આ ફરી બંધ કરવું — એ બધું તમે સેટિંગ્સમાં ગમે ત્યારે બદલી શકો છો.';

  @override
  String get azaanOptInTitle => 'નમાઝના સમયે અઝાન વગાડીએ?';

  @override
  String get azaanOptInNotNow => 'હમણાં નહીં';

  @override
  String get azaanOptInEnable => 'અઝાન સક્ષમ કરો';

  @override
  String reminderRemoveBody(String title) {
    return 'આ \"$title\" માટેનું રિમાઇન્ડર દૂર કરે છે. તમે તે ગમે ત્યારે ફરી ઉમેરી શકો છો.';
  }

  @override
  String get reminderRemoveTitle => 'રિમાઇન્ડર દૂર કરીએ?';

  @override
  String get reminderAddTooltip => 'રિમાઇન્ડર ઉમેરો';

  @override
  String get reminderNone => 'હજી કોઈ રિમાઇન્ડર નથી';

  @override
  String get reminderNoneBody =>
      '+ ટૅપ કરી તમે પસંદ કરેલા દિવસોએ ઝિક્ર કે દુઆ વિશે યાદ અપાવો — જેમ કે દર મંગળવારે તવસ્સુલ, અથવા ગુરુવારે મગરીબ પછી દુઆ કુમૈલ.';

  @override
  String tasbeehBeepNumber(int number) {
    return 'બીપ $number';
  }

  @override
  String get tasbeehHelp =>
      'ગણવા માટે કાઉન્ટર વર્તુળ પર ટૅપ કરો. નીચેના સીમાચિહ્નો પર બીપ વાગશે.';

  @override
  String get tasbeehEnableBeep => 'બીપ સક્ષમ કરો';

  @override
  String get tasbeehTapToCount => 'ગણવા ટૅપ કરો';

  @override
  String get tasbeehMinusOne => 'એક ઓછું';

  @override
  String get tasbeehReset => 'રીસેટ';

  @override
  String get requestThanks => 'આભાર — અમને તમારી વિનંતી મળી છે.';

  @override
  String get requestFailed =>
      'વિનંતી મોકલી શકાઈ નહીં. કૃપા કરી ફરી પ્રયાસ કરો.';

  @override
  String get requestBookTitle => 'પુસ્તકનું શીર્ષક';

  @override
  String get requestZikrName => 'દુઆ, ઝિયારત વગેરેનું નામ';

  @override
  String get requestBookDetails => 'લેખક, અનુવાદક કે લિંક (વૈકલ્પિક)';

  @override
  String get requestZikrDetails => 'સ્ત્રોત, પ્રસંગ કે લિંક (વૈકલ્પિક)';

  @override
  String get commonSend => 'મોકલો';

  @override
  String searchOneMatch(String source) {
    return '$sourceમાં 1 મેળ';
  }

  @override
  String searchMatches(int count, String source) {
    return '$sourceમાં $count મેળ';
  }

  @override
  String get searchSourceZikr => 'ઝિક્ર';

  @override
  String get searchSourceQuran => 'કુરઆન';

  @override
  String get searchSourceLibrary => 'લાઇબ્રેરી';

  @override
  String get searchTitleOrUid => 'શીર્ષક કે UID શોધો';

  @override
  String get searchShow => 'બતાવો';

  @override
  String get searchNoResults => 'કોઈ પરિણામ નથી';

  @override
  String get searchRequestIt => 'તેની વિનંતી કરો';

  @override
  String widgetPrayerTimesHelp(int min, int max) {
    return '$minથી $max સમય પસંદ કરો. સૂર્યોદય, સૂર્યાસ્ત અને મધ્યરાત્રિ એ સમયમર્યાદા છે જે પહેલાં નમાઝ અદા કરવી જોઈએ.';
  }

  @override
  String get accountSessionExpired =>
      'તમારું સેશન સમાપ્ત થઈ ગયું. કૃપા કરી ફરી સાઇન ઇન કરો અને કાઢી નાખવાનો ફરી પ્રયાસ કરો.';

  @override
  String get accountReauthenticate =>
      'સુરક્ષા માટે, કૃપા કરી ફરી સાઇન ઇન કરો અને પછી તમારું એકાઉન્ટ કાઢી નાખવાનો ફરી પ્રયાસ કરો.';

  @override
  String get accountPopupClosed =>
      'ક્રિયા પૂરી થાય તે પહેલાં સાઇન-ઇન વિન્ડો બંધ થઈ ગઈ.';

  @override
  String get accountNetworkError =>
      'નેટવર્ક ભૂલ. કૃપા કરી તમારું કનેક્શન તપાસી ફરી પ્રયાસ કરો.';

  @override
  String get commonSomethingWentWrong =>
      'કંઈક ખોટું થયું. કૃપા કરી ફરી પ્રયાસ કરો.';

  @override
  String zikrTabNumber(int number) {
    return 'ટૅબ $number';
  }

  @override
  String get zikrBookmarked => 'બુકમાર્ક કર્યું';

  @override
  String get zikrMoveBookmarkHere => 'બુકમાર્ક અહીં ખસેડો';

  @override
  String get zikrDragBookmarkHint => 'બુકમાર્કને બીજી લીટી પર ખસેડવા ખેંચો';

  @override
  String get durationUnderOneMinute => '1 મિનિટથી ઓછું';

  @override
  String durationMinutes(int minutes) {
    return '$minutes મિનિટ';
  }

  @override
  String durationHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours કલાક',
      one: 'એક કલાક',
    );
    return '$_temp0';
  }

  @override
  String durationHoursMinutes(String hours, int minutes) {
    return '$hours કલાક $minutes મિનિટ';
  }

  @override
  String zikrReadingTime(String duration) {
    return 'વાંચન: $duration';
  }

  @override
  String get zikrProgressCompleted => 'પૂર્ણ';

  @override
  String airportNothingMatched(String query) {
    return '\"$query\" સાથે કંઈ મળ્યું નહીં. તેના બદલે ત્રણ અક્ષરનો કોડ અજમાવો.';
  }

  @override
  String get airportSearchLabel => 'એરપોર્ટ કોડ કે શહેર';

  @override
  String get airportSearchHint => 'દા.ત. SFO, ઇસ્તંબુલ, નજફ';

  @override
  String get airportSearchTitle => 'એરપોર્ટ શોધો';

  @override
  String get airportSearchDetail => 'એરપોર્ટ કોડ, શહેર, કે દેશનું નામ લખો.';

  @override
  String get airportNoneFound => 'કોઈ એરપોર્ટ મળ્યા નહીં';

  @override
  String get counterTapAnywhere => 'ગણવા ગમે ત્યાં ટૅપ કરો';

  @override
  String get counterHoldToMove => 'ખસેડવા દબાવી રાખી ખેંચો';

  @override
  String get counterAddOne => 'એક ઉમેરો';

  @override
  String azanPaused(String prayer) {
    return '$prayer અઝાન થોભાવી છે';
  }

  @override
  String get azanPrayerFallback => 'નમાઝ';

  @override
  String get reminderChannelDescription =>
      'તમે નિર્ધારિત કરેલા ઝિક્ર અને દુઆઓ માટેના રિમાઇન્ડર';

  @override
  String get locationOff => 'સ્થાન સેવાઓ બંધ છે';

  @override
  String get locationPermissionShort => 'સ્થાનની પરવાનગી જોઈએ છે';

  @override
  String get locationNoFix => 'સ્થાન ફિક્સ મળી શક્યું નહીં';

  @override
  String get locationUpdateFailed => 'સ્થાન અપડેટ થઈ શક્યું નહીં';

  @override
  String quranPreviousUnit(String unit) {
    return 'પાછલું $unit';
  }

  @override
  String quranNextUnit(String unit) {
    return 'આગળનું $unit';
  }

  @override
  String get quranUnitSurah => 'સૂરહ';

  @override
  String hadithNoResults(String query) {
    return '\"$query\" માટે કોઈ પરિણામ મળ્યું નહીં';
  }

  @override
  String get hadithTitle => 'હદીસ';

  @override
  String get hadithSearchHint => 'હદીસ શોધો...';

  @override
  String get hadithNone => 'કોઈ હદીસ ઉપલબ્ધ નથી';

  @override
  String favoritesReorder(String title) {
    return '$title ફરી ગોઠવો';
  }

  @override
  String get favoritesReorderFailed =>
      'નવો ક્રમ સાચવી શકાયો નહીં. ફરી પ્રયાસ કરો.';

  @override
  String get favoritesNone => 'હજી કોઈ મનપસંદ નથી.';

  @override
  String linkNotFoundRequested(String link) {
    return 'વિનંતી કરેલી લિંક: $link';
  }

  @override
  String get linkNotFoundTitle => 'લિંક મળી નહીં';

  @override
  String get linkNotFoundBody => 'અમને આ સામગ્રી મળી શકી નહીં.';

  @override
  String get linkNotFoundGoHome => 'હોમ જાઓ';

  @override
  String get whatsNewTitle => 'નવું શું છે';

  @override
  String get whatsNewGotIt => 'સમજાઈ ગયું';

  @override
  String get pickerChooseZikr => 'ઝિક્ર કે દુઆ પસંદ કરો';

  @override
  String get pickerSearchZikrHint => 'ઝિક્ર, દુઆ, ઝિયારત શોધો...';

  @override
  String get pickerNoMatches => 'કોઈ મેળ મળ્યો નહીં.';

  @override
  String get todaysNone => 'કોઈ પઠન ગોઠવેલા નથી.';

  @override
  String get scheduledFallbackTitle => 'નિર્ધારિત સૂચના';

  @override
  String get scheduledNone => 'કોઈ નિર્ધારિત સૂચના નથી.';

  @override
  String newsLoadFailed(String error) {
    return 'સમાચાર લોડ થઈ શક્યા નહીં: $error';
  }

  @override
  String get newsNoBrowser => 'કોઈ વેબ બ્રાઉઝર મળ્યું નહીં';

  @override
  String get actionSaved => 'સાચવેલું';

  @override
  String get actionBookmark => 'બુકમાર્ક';

  @override
  String get actionShare => 'શેર';

  @override
  String get actionListen => 'સાંભળો';

  @override
  String get actionSettings => 'સેટિંગ્સ';

  @override
  String get actionCounter => 'કાઉન્ટર';

  @override
  String get prayerEnableLocationBody =>
      'તમારા વિસ્તાર માટે ચોક્કસ નમાઝના સમય બતાવવા સ્થાન સક્ષમ કરો.';

  @override
  String statsDayRead(String day) {
    return '$day: વાંચ્યું';
  }

  @override
  String statsDayNotRead(String day) {
    return '$day: વાંચ્યું નથી';
  }

  @override
  String get qiblaDistance => 'અંતર';

  @override
  String get qiblaDirection => 'દિશા';

  @override
  String get qiblaYouFace => 'તમારું મુખ';

  @override
  String pickerAyahLabel(int ayah) {
    return 'આયત $ayah';
  }

  @override
  String hadithSharedVia(String link) {
    return 'Shia Companion દ્વારા શેર કર્યું - $link';
  }

  @override
  String get requestTypeZikr => 'ઝિક્ર';

  @override
  String get requestTypeBook => 'પુસ્તક';
}
