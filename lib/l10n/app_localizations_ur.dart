// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appTitle => 'Shia Companion';

  @override
  String get settingsAppLanguage => 'ایپ کی زبان';

  @override
  String get settingsTranslationLanguage => 'ترجمے کی زبان';

  @override
  String languageFollowDevice(String language) {
    return 'آلے کی زبان ($language)';
  }

  @override
  String languageFollowApp(String language) {
    return 'ایپ جیسی ہی ($language)';
  }

  @override
  String settingsDownloadedRecitationsUsed(String size) {
    return 'اس آلے پر $size استعمال شدہ';
  }

  @override
  String settingsHijriAhead(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days دن آگے',
      one: 'ایک دن آگے',
    );
    return '$_temp0';
  }

  @override
  String settingsHijriBehind(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days دن پیچھے',
      one: 'ایک دن پیچھے',
    );
    return '$_temp0';
  }

  @override
  String settingsLocationFailed(String message) {
    return '$message۔ دوبارہ کوشش کرنے کے لیے ٹیپ کریں۔';
  }

  @override
  String settingsLocationSaved(String city) {
    return 'موجودہ محفوظ مقام: $city۔';
  }

  @override
  String settingsLocationUpdated(String city, String age) {
    return '$city · $age اپ ڈیٹ ہوا۔ آپ کے منتقل ہونے پر خود بخود تازہ ہوتا رہتا ہے۔';
  }

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes منٹ پہلے';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours گھنٹے پہلے';
  }

  @override
  String timeDaysAgo(int days) {
    return '$days دن پہلے';
  }

  @override
  String settingsAdjustHijriBy(int days) {
    return 'ہجری تاریخ کو $days دن سے ایڈجسٹ کریں';
  }

  @override
  String settingsPrayerTimesShownSubtitle(String names) {
    return 'ہوم پیج اور ہوم اسکرین ویجٹس پر دکھائے جاتے ہیں: $names۔';
  }

  @override
  String settingsPrayerNotificationsAllOn(int count) {
    return 'تمام $count اوقات کے لیے آن ہے۔';
  }

  @override
  String settingsPrayerNotificationsSomeOn(
      String names, int enabled, int total) {
    return '$names · $total میں سے $enabled آن';
  }

  @override
  String get settingsSectionPrayerLocation => 'نماز اور مقام';

  @override
  String get settingsAdjustHijriDate => 'ہجری تاریخ ایڈجسٹ کریں';

  @override
  String get settingsPrayerTimesShown => 'دکھائے جانے والے نماز کے اوقات';

  @override
  String get settingsRefreshLocation => 'مقام تازہ کریں';

  @override
  String get settingsLocationRefreshed => 'مقام تازہ کر دیا گیا ہے۔';

  @override
  String get settingsSectionNotifications => 'اطلاعات';

  @override
  String get settingsPrayerNotifications => 'نماز کی اطلاعات';

  @override
  String get settingsZikrReminders => 'ذکر کی یاد دہانیاں';

  @override
  String get settingsZikrRemindersSubtitle =>
      'اپنی پسند کے دنوں میں کسی ذکر کی یاد دہانی حاصل کریں۔';

  @override
  String get settingsPrecisePrayerAlarms => 'نماز کے درست الارم';

  @override
  String get settingsScheduledNotifications => 'طے شدہ اطلاعات';

  @override
  String get settingsScheduledNotificationsSubtitle =>
      'زیر التوا نماز کی اطلاعات کا جائزہ لیں۔';

  @override
  String get settingsSectionAppearance => 'ظاہری شکل';

  @override
  String get settingsDarkMode => 'ڈارک موڈ';

  @override
  String get settingsDarkModeSubtitle =>
      'پوری ایپ میں گہرا ظاہری انداز استعمال کریں۔';

  @override
  String get settingsAppTextSize => 'ایپ کے متن کا سائز';

  @override
  String get settingsAppTextSizeSubtitle =>
      'تمام متن کو بڑا یا چھوٹا کرتا ہے، ذکر سمیت۔';

  @override
  String get settingsSectionZikrReading => 'ذکر کی تلاوت اور شیئرنگ';

  @override
  String get settingsSectionOfflineAudio => 'آف لائن آڈیو';

  @override
  String get settingsDownloadedRecitations => 'ڈاؤن لوڈ شدہ تلاوتیں';

  @override
  String get settingsDownloadedRecitationsEmpty => 'کنکشن کے بغیر سنیں';

  @override
  String get settingsSectionSupport => 'معاونت';

  @override
  String get settingsRateApp => 'Shia Companion کی درجہ بندی کریں';

  @override
  String get settingsRateAppSubtitle => 'ایپ پسند آ رہی ہے؟ ہمیں ریٹنگ دیں۔';

  @override
  String get settingsRequestContent => 'ذکر یا کتاب کی درخواست کریں';

  @override
  String get settingsRequestContentSubtitle =>
      'کوئی دعا، زیارت یا کتاب نہیں مل رہی؟ ہم سے شامل کرنے کی درخواست کریں۔';

  @override
  String get settingsFeedback => 'تاثرات';

  @override
  String get settingsFeedbackSubtitle => 'سوالات، مسائل یا تجاویز بھیجیں۔';

  @override
  String get settingsGithub => 'GitHub پر تعاون کریں';

  @override
  String get settingsGithubSubtitle =>
      'Shia Companion اوپن سورس ہے۔ مسائل کی اطلاع دیں یا اسے بہتر بنانے میں مدد کریں۔';

  @override
  String get settingsGithubOpenFailed => 'GitHub نہیں کھل سکا';

  @override
  String get settingsAboutUs => 'ہمارے بارے میں';

  @override
  String get settingsSectionAccount => 'اکاؤنٹ';

  @override
  String get settingsNotSignedIn => 'سائن ان نہیں ہے';

  @override
  String get settingsSignInPrompt =>
      'تمام آلات پر پسندیدہ سنک کرنے کے لیے سائن ان کریں۔';

  @override
  String get settingsLogout => 'لاگ آؤٹ';

  @override
  String get settingsLogoutSubtitle => 'اس آلے پر سائن آؤٹ کریں۔';

  @override
  String get settingsDeleteAccount => 'میرا اکاؤنٹ حذف کریں';

  @override
  String get settingsDeleteAccountSubtitle =>
      'اپنے اکاؤنٹ کا ڈیٹا مستقل طور پر ختم کریں۔';

  @override
  String get settingsSignInGoogle => 'Google سے سائن ان کریں';

  @override
  String get settingsSignInGoogleSubtitle =>
      'پسندیدہ اور اکاؤنٹ ڈیٹا سنک کریں۔';

  @override
  String get settingsSignInApple => 'Apple سے سائن ان کریں';

  @override
  String get settingsSignInAppleSubtitle =>
      'سائن ان کے لیے اپنی Apple ID استعمال کریں۔';

  @override
  String get settingsSignedIn => 'سائن ان ہے';

  @override
  String get settingsSyncing => 'پسندیدہ اور اکاؤنٹ ڈیٹا سنک ہو رہا ہے۔';

  @override
  String get settingsHijriNoAdjustment => 'کوئی ایڈجسٹمنٹ نہیں';

  @override
  String get settingsLocationUpdating => 'آپ کا مقام اپ ڈیٹ ہو رہا ہے…';

  @override
  String get settingsLocationUpdatePrompt =>
      'محفوظ نماز اوقات کا مقام اپ ڈیٹ کریں۔';

  @override
  String get timeJustNow => 'ابھی ابھی';

  @override
  String get settingsPrayerNotificationsOff =>
      'آف ہے۔ نماز کے اوقات پر اطلاع پانے کے لیے آن کریں۔';

  @override
  String get settingsPreciseAlarmsOn => 'درست اذان اوقات کے لیے فعال ہے۔';

  @override
  String get settingsPreciseAlarmsOff =>
      'آف ہے۔ Android نماز کی اطلاعات کچھ دیر سے پہنچا سکتا ہے۔';

  @override
  String get settingsNotificationsUnavailable => 'اطلاعاتی نظام شروع نہیں ہوا';

  @override
  String get settingsPreciseAlarmsAlreadyOn =>
      'نماز کے درست الارم پہلے ہی فعال ہیں۔';

  @override
  String get settingsPreciseAlarmsDialogTitle =>
      'نماز کے درست الارم فعال کریں؟';

  @override
  String get settingsPreciseAlarmsDialogBody =>
      'Android کو اذان کی اطلاعات بالکل نماز کے وقت چلانے کے لیے الارم و یاد دہانیوں تک رسائی درکار ہے۔ اس کے بغیر یاد دہانیاں پھر بھی کام کرتی ہیں مگر کچھ دیر سے پہنچ سکتی ہیں۔';

  @override
  String get commonCancel => 'منسوخ کریں';

  @override
  String get commonOpenSettings => 'ترتیبات کھولیں';

  @override
  String get settingsPreciseAlarmsEnabled =>
      'نماز کے درست الارم فعال کر دیے گئے۔';

  @override
  String get settingsPreciseAlarmsNotEnabled =>
      'نماز کے درست الارم فعال نہیں ہوئے۔ تقریبی اوقات استعمال ہوتے رہیں گے۔';

  @override
  String get settingsNoEmailApp => 'کوئی ای میل ایپ نہیں ملی';

  @override
  String get settingsLoginSuccessful => 'لاگ ان کامیاب';

  @override
  String get settingsGoogleUnavailable =>
      'Google سائن ان اس وقت دستیاب نہیں۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get commonNetworkError =>
      'کنکٹ نہیں ہو سکا۔ اپنا انٹرنیٹ کنکشن چیک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get settingsGoogleFailed =>
      'Google سائن ان کامیاب نہیں ہوا۔ براہ کرم تھوڑی دیر بعد دوبارہ کوشش کریں۔';

  @override
  String get settingsAppleFailed => 'Apple سائن ان ناکام';

  @override
  String audioRecordingNumber(int number) {
    return 'ریکارڈنگ $number';
  }

  @override
  String playlistAddedTo(String name) {
    return '$name میں شامل کر دیا گیا';
  }

  @override
  String playlistAlreadyIn(String name) {
    return 'پہلے سے $name میں موجود ہے';
  }

  @override
  String zikrCount(int count) {
    return '$count ذکر';
  }

  @override
  String get playlistsEmpty =>
      'ان اذکار کی پلے لسٹ بنائیں جنہیں آپ روز سنتے ہیں — مثلاً ہر صبح دعائے عہد اور زیارت عاشورہ — اور ایک ٹیپ سے سب چلائیں۔';

  @override
  String playlistDeleteConfirm(String name) {
    return '\"$name\" حذف کریں؟';
  }

  @override
  String get playlistDeleteKeepsDuasAndAudio =>
      'دعائیں خود ایپ میں برقرار رہتی ہیں، اور ان کی ڈاؤن لوڈ شدہ آڈیو بھی — جگہ خالی کرنے کے لیے اسے ڈاؤن لوڈز سے ہٹائیں۔';

  @override
  String get playlistEmpty =>
      'ذکر منتخب کرنے کے لیے شامل کریں پر ٹیپ کریں۔ آپ آڈیو والی کسی بھی دعا کے پلیئر سے بھی ذکر شامل کر سکتے ہیں۔';

  @override
  String audioRecordingsChosen(int chosen, int total) {
    return '$total میں سے $chosen ریکارڈنگز';
  }

  @override
  String audioDownloadingPercent(int percent) {
    return 'ڈاؤن لوڈ ہو رہا ہے $percent%';
  }

  @override
  String audioRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ریکارڈنگز',
      one: 'ایک ریکارڈنگ',
    );
    return '$_temp0';
  }

  @override
  String playlistNowPlayingPosition(String playlist, int position, int count) {
    return '$playlist · $count میں سے $position';
  }

  @override
  String get playlistNameHint => 'مثلاً صبح';

  @override
  String get playlistOfflinePartial =>
      'آپ آف لائن ہیں — صرف ڈاؤن لوڈ شدہ ریکارڈنگز چلائی جا رہی ہیں';

  @override
  String get playlistNothingToPlay =>
      'اس پلے لسٹ میں چلانے کے لیے کوئی ریکارڈنگ نہیں';

  @override
  String get playlistOfflineNothingDownloaded =>
      'آپ آف لائن ہیں اور اس پلے لسٹ میں ابھی تک کچھ ڈاؤن لوڈ نہیں ہوا';

  @override
  String get playlistStartFailed =>
      'پلے لسٹ شروع نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get playlistChooseRecordingsHint =>
      'اس پلے لسٹ میں چلانے کے لیے ریکارڈنگز منتخب کریں';

  @override
  String get commonDone => 'ہو گیا';

  @override
  String get playlistAddTo => 'پلے لسٹ میں شامل کریں';

  @override
  String get playlistNew => 'نئی پلے لسٹ';

  @override
  String get commonCreate => 'بنائیں';

  @override
  String get playlistsTitle => 'پلے لسٹس';

  @override
  String get playlistDownloads => 'ڈاؤن لوڈز';

  @override
  String get commonPause => 'روکیں';

  @override
  String get commonPlay => 'چلائیں';

  @override
  String get playlistRename => 'پلے لسٹ کا نام بدلیں';

  @override
  String get commonSave => 'محفوظ کریں';

  @override
  String get playlistDeleteKeepsDuas => 'دعائیں خود ایپ میں برقرار رہتی ہیں۔';

  @override
  String get commonDelete => 'حذف کریں';

  @override
  String get playlistDeleted => 'یہ پلے لسٹ حذف کر دی گئی ہے۔';

  @override
  String get commonRename => 'نام بدلیں';

  @override
  String get playlistRemoveDownloads => 'ڈاؤن لوڈز ہٹائیں';

  @override
  String get playlistAllDownloads => 'تمام ڈاؤن لوڈز';

  @override
  String get commonAdd => 'شامل کریں';

  @override
  String get playlistResume => 'جاری رکھیں';

  @override
  String get playlistPlayAll => 'سب چلائیں';

  @override
  String get audioDownloaded => 'ڈاؤن لوڈ شدہ';

  @override
  String get audioDownloadFailed => 'ڈاؤن لوڈ مکمل نہیں ہوا';

  @override
  String get playlistOpenText => 'متن کھولیں';

  @override
  String get playlistChooseRecordings => 'ریکارڈنگز منتخب کریں';

  @override
  String get audioStopDownloading => 'ڈاؤن لوڈ روکیں';

  @override
  String get audioRemoveDownload => 'ڈاؤن لوڈ ہٹائیں';

  @override
  String get audioDownload => 'ڈاؤن لوڈ کریں';

  @override
  String get playlistRemoveZikr => 'پلے لسٹ سے ہٹائیں';

  @override
  String get playlistAddZikr => 'ذکر شامل کریں';

  @override
  String get commonSearch => 'تلاش';

  @override
  String get audioPartlyDownloaded => 'جزوی طور پر ڈاؤن لوڈ شدہ';

  @override
  String get playlistRepeatOn => 'تکرار آن ہے';

  @override
  String get playlistRepeat => 'پلے لسٹ دہرائیں';

  @override
  String get commonPrevious => 'پچھلا';

  @override
  String get commonNext => 'اگلا';

  @override
  String get commonStop => 'روکیں';

  @override
  String flightTimesShownAt(String origin, String destination) {
    return 'اوقات $origin اور $destination کی مقامی گھڑیوں کے مطابق دکھائے گئے ہیں';
  }

  @override
  String flightDurationAndDistance(String duration, String distance) {
    return 'ہوا میں $duration · دائرہ عظیمہ کے حساب سے $distance';
  }

  @override
  String flightAirportTime(String airport) {
    return '$airport کا وقت';
  }

  @override
  String flightOverPosition(String position) {
    return ' · $position کے اوپر';
  }

  @override
  String flightAfterTakeoff(String duration) {
    return 'ٹیک آف کے $duration بعد';
  }

  @override
  String flightHorizonLater(int minutes) {
    return 'نیچے کی زمین کے افق سے $minutes منٹ بعد';
  }

  @override
  String flightHorizonEarlier(int minutes) {
    return 'نیچے کی زمین کے افق سے $minutes منٹ پہلے';
  }

  @override
  String flightQiblaToRight(int degrees) {
    return 'آپ کے دائیں جانب $degrees°';
  }

  @override
  String flightQiblaToLeft(int degrees) {
    return 'آپ کے بائیں جانب $degrees°';
  }

  @override
  String flightQiblaLine(int bearing, String compass, String relative) {
    return 'قبلہ $bearing° ($compass) — پرواز کی سمت کے لحاظ سے $relative';
  }

  @override
  String flightAltitudeHorizonBody(String altitude, String dip) {
    return '$altitude پر افق زمین کی نسبت تقریباً $dip° نیچے ہوتا ہے، اس لیے سورج کو غروب ہونے میں زیادہ وقت لگتا ہے اور فجر جلد آتی ہے۔ اس سے مغرب اور عشاء نیچے کی زمین کے اوقات کی نسبت تقریباً بیس منٹ بعد، اور فجر تقریباً بیس منٹ پہلے ہو جاتی ہے — ہر سطر اپنی تبدیلی خود دکھاتی ہے۔ نماز پر کس افق کا حکم لاگو ہوتا ہے، یہ آپ کے مرجع کا مسئلہ ہے، اس ایپ کے طے کرنے کا نہیں۔';
  }

  @override
  String flightAltitudeFeet(String feet) {
    return '$feet فٹ';
  }

  @override
  String get flightTitleFallback => 'پرواز';

  @override
  String get flightEdit => 'پرواز میں ترمیم کریں';

  @override
  String get flightCheckTimes => 'پرواز کے اوقات چیک کریں';

  @override
  String get flightCheckTimesBody =>
      'ہر ہوائی اڈے کا ٹائم زون لاگو کرنے کے بعد آمد روانگی کے بعد نہیں آتی۔ تاریخیں درست کرنے کے لیے ترمیم پر ٹیپ کریں۔';

  @override
  String get flightInTheAir => 'ہوا میں';

  @override
  String get flightNoPrayerDuring => 'اس پرواز کے دوران کوئی نماز نہیں آتی';

  @override
  String get flightNoPrayerDuringBody =>
      'ہر نماز کا وقت یا ٹیک آف سے پہلے یا لینڈنگ کے بعد آتا ہے۔';

  @override
  String get flightNotDuring => 'اس پرواز کے دوران نہیں';

  @override
  String get flightEndOfIshaWindow => 'عشاء کے وقت کا اختتام · ';

  @override
  String get flightStraightAhead => 'بالکل سامنے';

  @override
  String get flightDirectlyBehind => 'بالکل پیچھے';

  @override
  String get flightIshaClosedBeforeTakeoff =>
      'عشاء کا وقت ٹیک آف سے پہلے ہی ختم ہو چکا تھا۔';

  @override
  String get flightAlreadyInBeforeTakeoff =>
      'ٹیک آف سے پہلے ہی شروع ہو چکا — اپنی روانگی کے شہر کے نماز اوقات استعمال کریں۔';

  @override
  String get flightIshaOpenUntilLanding =>
      'عشاء کا وقت لینڈنگ کے بعد تک ختم نہیں ہوتا۔';

  @override
  String get flightAfterLanding =>
      'لینڈنگ کے بعد آتی ہے — اپنی منزل کے شہر کے نماز اوقات استعمال کریں۔';

  @override
  String get flightSunAngleNeverReached =>
      'سورج اس پورے راستے میں کہیں بھی مطلوبہ زاویے تک نہیں پہنچتا، اس لیے کوئی وقت نہیں نکالا جا سکتا۔';

  @override
  String get flightHowWorkedOut => 'یہ کیسے نکالے جاتے ہیں';

  @override
  String get flightHowWorkedOutBody =>
      'فرض کیا جاتا ہے کہ طیارہ مستقل رفتار سے دائرہ عظیمہ کے راستے پر چلتا ہے، اور ہر نماز کا وقت طیارے کی اس پوزیشن کے حساب سے نکالا جاتا ہے جہاں وہ اس وقت ہو گا۔ ایک گھنٹے کی تاخیر ان اوقات کو تقریباً آدھا گھنٹہ آگے پیچھے کر دیتی ہے، اور موسم کی وجہ سے راستہ بدلنا انہیں دس سے بیس منٹ تک بدل سکتا ہے، اس لیے انہیں درست کے بجائے قریب ترین سمجھیں۔';

  @override
  String get flightHorizonAtAltitude => 'بلندی پر افق سے ناپا گیا';

  @override
  String get flightHorizonAtGround => 'زمینی سطح پر افق سے ناپا گیا';

  @override
  String get flightGroundHorizonBody =>
      'اوقات طیارے کے نیچے کی زمین کے افق کے مطابق ہیں۔ کیبن سے سورج دکھائے گئے وقت سے دیر سے غروب ہوتا ہے اور فجر جلد طلوع ہوتی ہے، کروز بلندی پر تقریباً بیس منٹ کے فرق سے۔';

  @override
  String get flightHighLatitude => 'یہ راستہ بلند عرض بلد سے گزرتا ہے';

  @override
  String get flightHighLatitudeBody =>
      'تقریباً 48° سے اوپر سورج افق سے اتنا نیچے نہیں جا پاتا کہ فجر اور رات معمول کے مطابق آئیں۔ وہاں فجر، مغرب اور عشاء کے اوقات رات کے تناسبی اندازے پر مبنی ہوتے ہیں۔ بلند عرض بلد پر نماز کے احکام مختلف ہیں — براہ کرم اپنے مرجع کی پیروی کریں۔';

  @override
  String get flightSomeNotCalculated => 'کچھ نمازوں کے اوقات نہیں نکالے جا سکے';

  @override
  String get flightSomeNotCalculatedBody =>
      'سورج پورے راستے مطلوبہ زاویے سے اوپر رہتا ہے، اس لیے ان نمازوں کا کوئی حساب شدہ وقت نہیں۔ ان حالات کے لیے براہ کرم اپنے مرجع کے حکم کی پیروی کریں۔';

  @override
  String get flightTimeZonesFailed => 'ٹائم زون لوڈ نہیں ہو سکے';

  @override
  String get flightTimeZonesFailedBody =>
      'ان میں سے ایک ہوائی اڈے کا ٹائم زون اس بلڈ میں پہچانا نہیں جاتا۔ ہوائی اڈے دوبارہ منتخب کرنے کے لیے ترمیم پر ٹیپ کریں۔';

  @override
  String get prayerFajr => 'فجر';

  @override
  String get prayerSunrise => 'طلوع آفتاب';

  @override
  String get prayerZuhr => 'ظہر';

  @override
  String get prayerAsr => 'عصر';

  @override
  String get prayerSunset => 'غروب آفتاب';

  @override
  String get prayerMaghrib => 'مغرب';

  @override
  String get prayerIsha => 'عشاء';

  @override
  String get prayerMidnight => 'آدھی رات';

  @override
  String locationErrorBody(String error) {
    return 'آپ کا مقام حاصل کرنے کے دوران خرابی پیش آئی: $error\n\nبراہ کرم چیک کریں کہ مقام کی خدمات فعال ہیں اور دوبارہ کوشش کریں۔';
  }

  @override
  String notificationReopenAppBody(int days) {
    return 'لگتا ہے آپ نے پچھلے $days دنوں میں ایپ استعمال نہیں کی۔ اذان کی اطلاعات ملتی رہنے کے لیے براہ کرم ایپ کھولیں';
  }

  @override
  String notificationPrayerTime(String prayer) {
    return '$prayer کا وقت ہو گیا ہے';
  }

  @override
  String notificationTapToPlayCustom(String message) {
    return '$message · اپنی آڈیو چلانے کے لیے ٹیپ کریں';
  }

  @override
  String notificationTapToPlayAzan(String message) {
    return '$message · مکمل اذان سننے کے لیے ٹیپ کریں';
  }

  @override
  String get locationEnableTitle => 'نماز کے اوقات کے لیے مقام فعال کریں';

  @override
  String get locationEnableBody =>
      'نماز کے اوقات آپ کے مقام کے لحاظ سے خاص ہوتے ہیں۔ جب آپ ایپ استعمال کر رہے ہوں تو ہم آپ کا مقام استعمال کرتے ہیں تاکہ آپ کے علاقے کے درست نماز اوقات فراہم کر سکیں۔';

  @override
  String get commonContinue => 'جاری رکھیں';

  @override
  String get locationServicesDisabledTitle => 'مقام کی خدمات بند ہیں';

  @override
  String get locationServicesDisabledBody =>
      'مقام کی خدمات بند ہیں۔ اپنے علاقے کے درست نماز اوقات حاصل کرنے کے لیے براہ کرم اپنے آلے کی ترتیبات میں مقام کی خدمات فعال کریں۔';

  @override
  String get locationPermissionDeniedForever =>
      'مقام کی اجازت مستقل طور پر مسترد کر دی گئی۔ براہ کرم ایپ کی ترتیبات کھولیں اور درست نماز اوقات کے لیے مقام کی اجازت دیں۔';

  @override
  String get locationPermissionUnknown =>
      'مقام کی اجازت کی حالت معلوم نہیں ہو سکی۔ براہ کرم ایپ کی ترتیبات کھولیں اور یقینی بنائیں کہ مقام کی اجازت دی گئی ہے۔';

  @override
  String get locationPermissionNeeded =>
      'آپ کے علاقے کے درست نماز اوقات دکھانے کے لیے مقام کی اجازت درکار ہے۔';

  @override
  String get locationPermissionTitle => 'مقام کی اجازت درکار ہے';

  @override
  String get locationTimeoutTitle => 'مقام کی مہلت ختم';

  @override
  String get locationTimeoutBody =>
      'متوقع وقت میں آپ کا مقام حاصل نہیں ہو سکا۔ یہ کمزور GPS سگنل یا نیٹ ورک مسائل کی وجہ سے ہو سکتا ہے۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get locationErrorTitle => 'مقام کی خرابی';

  @override
  String get notificationReopenAppTitle =>
      'اذان کی اطلاعات ملتی رہنے کے لیے ایپ کھولیں';

  @override
  String get notificationChannelTakbir => 'نماز کے اوقات - تکبیر';

  @override
  String get notificationChannelSystemDefault => 'نماز کے اوقات - سسٹم ڈیفالٹ';

  @override
  String get notificationChannelSilent => 'نماز کے اوقات - خاموش';

  @override
  String get notificationChannelCustom => 'نماز کے اوقات - حسب منشا آواز';

  @override
  String get notificationChannelFullAzan => 'نماز کے اوقات - مکمل اذان';

  @override
  String get notificationChannelSilentDescription => 'خاموش نماز وقت اطلاعات';

  @override
  String get notificationChannelDescription => 'نماز کے وقت کی اطلاعات';

  @override
  String get notificationChannelGeneral => 'عام';

  @override
  String qiblaNeedsCalibratingBody(int degrees) {
    return 'ریڈنگ تقریباً $degrees° ہٹی ہوئی ہے۔ فون کو 8 کی شکل میں چند بار گھمائیں، کسی دھات یا مقناطیسی چیز سے دور رکھ کر۔';
  }

  @override
  String qiblaBearingFromNorth(String place, String bearing) {
    return '$place حقیقی شمال سے $bearing پر ہے';
  }

  @override
  String qiblaFacing(String place) {
    return '$place کی طرف رخ ہے';
  }

  @override
  String qiblaTurnRight(int degrees) {
    return 'دائیں مڑیں $degrees°';
  }

  @override
  String qiblaTurnLeft(int degrees) {
    return 'بائیں مڑیں $degrees°';
  }

  @override
  String qiblaDeclinationEast(String degrees) {
    return 'آپ کے مقام پر مقناطیسی شمال حقیقی شمال سے $degrees° مشرق میں ہے، اور ریڈنگ اس کے مطابق خود بخود درست کر دی جاتی ہے۔';
  }

  @override
  String qiblaDeclinationWest(String degrees) {
    return 'آپ کے مقام پر مقناطیسی شمال حقیقی شمال سے $degrees° مغرب میں ہے، اور ریڈنگ اس کے مطابق خود بخود درست کر دی جاتی ہے۔';
  }

  @override
  String get qiblaDistanceHere => 'یہاں';

  @override
  String get qiblaTitle => 'قبلہ تلاش کنندہ';

  @override
  String get qiblaAboutCompass => 'اس قطب نما کے بارے میں';

  @override
  String get qiblaLocationNeeded => 'مقام درکار ہے';

  @override
  String get qiblaLocationNeededBody =>
      'سمت اس بات پر منحصر ہے کہ آپ کہاں ہیں۔ اپنا مقام شیئر کریں اور جیسے ہی فکس ملے گا قطب نما اشارہ کرے گا۔';

  @override
  String get qiblaUseMyLocation => 'میرا مقام استعمال کریں';

  @override
  String get qiblaTurnOnCompass => 'قطب نما آن کریں';

  @override
  String get qiblaTurnOnCompassBody =>
      'اس براؤزر کو آپ کی اجازت درکار ہے اس سے پہلے کہ یہ بتا سکے کہ فون کا رخ کس طرف ہے۔';

  @override
  String get qiblaAllowCompass => 'قطب نما کی اجازت دیں';

  @override
  String get qiblaCompassBlocked => 'قطب نما مسدود ہے';

  @override
  String get qiblaCompassBlockedBody =>
      'حرکت اور سمت تک رسائی مسترد کر دی گئی، اس لیے ڈائل شمال کی طرف اوپر رکھا گیا ہے۔ اپنے براؤزر کی ترتیبات میں اجازت دیں، یا اس وقت تک مڑیں جب تک ڈائل کا شمال آپ کے اردگرد کے شمال سے نہ مل جائے۔';

  @override
  String get qiblaNoCompass => 'اس آلے پر کوئی قطب نما نہیں';

  @override
  String get qiblaNoCompassBody =>
      'اس کے بجائے ڈائل شمال کی طرف اوپر رکھا گیا ہے۔ شمال کی طرف رخ کریں، اور سوئی وہاں سے سمت دکھاتی ہے۔';

  @override
  String get qiblaNeedsCalibrating => 'قطب نما کو کیلیبریشن درکار ہے';

  @override
  String get qiblaLocationUnknown => 'مقام نامعلوم';

  @override
  String get qiblaUpdateLocation => 'مقام اپ ڈیٹ کریں';

  @override
  String get qiblaPointingTowards => 'اشارہ اس طرف ہے';

  @override
  String get qiblaWaitingForLocation => 'آپ کے مقام کا انتظار ہے';

  @override
  String get qiblaPointTowards => 'رخ اس طرف کریں';

  @override
  String get qiblaGreatCircleBody =>
      'سوئی دائرہ عظیمہ کے راستے کی طرف اشارہ کرتی ہے — زمین کی سطح پر سب سے چھوٹا راستہ، اور یہی وہ سمت ہے جس سے قبلہ متعین ہوتا ہے۔ ہموار نقشے پر یہ حیران کن لگ سکتا ہے؛ شمالی امریکہ سے کعبہ تقریباً شمال مشرق میں ہے، جنوب مشرق میں نہیں۔';

  @override
  String get qiblaDeclinationUnknownBody =>
      'آپ کا فون مقناطیسی شمال کا زاویہ ناپتا ہے، جو حقیقی شمال سے اس مقدار میں مختلف ہوتا ہے جو آپ کے مقام پر منحصر ہے۔ آپ کا مقام معلوم ہوتے ہی یہ درستگی خود بخود لاگو ہو جاتی ہے۔';

  @override
  String get qiblaSteadyReadingBody =>
      'مستحکم ریڈنگ کے لیے فون کو ہموار پکڑیں اور اسے لیپ ٹاپ، اسپیکر، کار کے ڈیش بورڈ اور کسی بھی ایسی چیز سے دور رکھیں جس میں مقناطیس ہو۔';

  @override
  String get commonClose => 'بند کریں';

  @override
  String get weekdayShortMon => 'پیر';

  @override
  String get weekdayShortTue => 'منگل';

  @override
  String get weekdayShortWed => 'بدھ';

  @override
  String get weekdayShortThu => 'جمعرات';

  @override
  String get weekdayShortFri => 'جمعہ';

  @override
  String get weekdayShortSat => 'ہفتہ';

  @override
  String get weekdayShortSun => 'اتوار';

  @override
  String reminderMinutesRange(int max) {
    return '0 اور $max کے درمیان منٹوں کی تعداد درج کریں۔';
  }

  @override
  String get reminderTitleRequired =>
      'براہ کرم اس یاد دہانی کے لیے عنوان درج کریں۔';

  @override
  String get reminderPickDay => 'کم از کم ایک دن منتخب کریں۔';

  @override
  String get reminderSavedPendingLocation =>
      'محفوظ ہو گیا۔ جیسے ہی آپ کے نماز اوقات کا مقام دستیاب ہو گا یہ چلنا شروع ہو جائے گی۔';

  @override
  String get reminderEditTitle => 'یاد دہانی میں ترمیم کریں';

  @override
  String get reminderNewTitle => 'نئی یاد دہانی';

  @override
  String get reminderWhat => 'کیا';

  @override
  String get reminderWhatHint =>
      'لائبریری سے کوئی ذکر منتخب کریں، یا نیچے صرف عنوان لکھیں۔';

  @override
  String get reminderChooseZikr => 'ذکر لائبریری سے منتخب کریں';

  @override
  String get reminderChangeZikr => 'ذکر بدلیں';

  @override
  String get reminderTitleLabel => 'عنوان';

  @override
  String get reminderTitleHint => 'مثلاً دعائے توسل';

  @override
  String get reminderRepeatOn => 'ان دنوں دہرائیں';

  @override
  String get reminderWhen => 'کب';

  @override
  String get reminderFixedTime => 'مقررہ وقت';

  @override
  String get reminderPrayerRelative => 'نماز کے حساب سے';

  @override
  String get commonSaveChanges => 'تبدیلیاں محفوظ کریں';

  @override
  String get reminderAdd => 'یاد دہانی شامل کریں';

  @override
  String get reminderTime => 'وقت';

  @override
  String get reminderPrayer => 'نماز';

  @override
  String get reminderMinutes => 'منٹ';

  @override
  String get reminderBefore => 'پہلے';

  @override
  String get reminderAfter => 'بعد';

  @override
  String get reminderPrayerRelativeNote =>
      'نماز کے اوقات کیلنڈر کے ساتھ بدلتے ہیں، اس لیے یہ اگلے چند ہفتوں کے اوقات طے کرتی ہے اور جب بھی آپ ایپ کھولتے ہیں انہیں تازہ کرتی ہے۔';

  @override
  String qazaCompletedCount(int count) {
    return '$count مکمل';
  }

  @override
  String get qazaPrayed => 'ادا کر لی';

  @override
  String get qazaFasted => 'روزہ رکھ لیا';

  @override
  String qazaEstimatePrayers(String days, String prayers) {
    return 'ہر روزانہ نماز کے $days ($prayers نمازیں)';
  }

  @override
  String qazaEstimateFasts(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count روزے',
      one: '$count روزہ',
    );
    return '$_temp0';
  }

  @override
  String qazaLunarNote(int yearDays, int monthDays) {
    return 'قمری سالوں کے حساب سے شمار کیا گیا جن میں $yearDays دن اور مہینوں میں $monthDays دن ہوتے ہیں۔';
  }

  @override
  String get qazaTitle => 'قضا ٹریکر';

  @override
  String get qazaCalculate => 'میری قضا کا حساب کریں';

  @override
  String get qazaPrayers => 'نمازیں';

  @override
  String get qazaFasts => 'روزے';

  @override
  String get qazaRemaining => 'باقی قضا';

  @override
  String get commonUndo => 'کالعدم کریں';

  @override
  String get qazaMissed => 'رہ گئیں';

  @override
  String get qazaEditCount => 'تعداد میں ترمیم کریں';

  @override
  String get qazaMissedAWhile => 'کچھ عرصے سے نمازیں رہ گئی ہیں؟';

  @override
  String get qazaMissedAWhileBody =>
      'درج کریں کہ کتنا عرصہ، اور ہم ہر رہ گئے دن کے لیے ہر روزانہ نماز میں سے ایک شامل کر دیں گے۔';

  @override
  String get qazaPrayedFullDay => 'پورے دن کی نمازیں ادا کیں';

  @override
  String get qazaLoggedFullDay => 'ہر روزانہ نماز میں سے ایک درج کر دی گئی';

  @override
  String get qazaAddedToList => 'آپ کی قضا فہرست میں شامل کر دیا گیا';

  @override
  String get qazaRemainingLabel => 'باقی';

  @override
  String get qazaCompletedLabel => 'مکمل';

  @override
  String get commonClear => 'صاف کریں';

  @override
  String get qazaCalculateBody =>
      'تقریباً کتنے عرصے آپ نے نماز نہیں پڑھی؟ بہترین اندازہ کافی ہے — بعد میں کوئی بھی نماز ایڈجسٹ کر سکتے ہیں۔';

  @override
  String get qazaPrayersMissedFor => 'نمازیں رہ جانے کی مدت';

  @override
  String get qazaYears => 'سال';

  @override
  String get qazaMonths => 'مہینے';

  @override
  String get qazaDays => 'دن';

  @override
  String get qazaFastsMissed => 'رہ گئے روزے';

  @override
  String get qazaNumberOfFasts => 'روزوں کی تعداد';

  @override
  String get qazaThisAdds => 'یہ آپ کی فہرست میں شامل کرتا ہے:';

  @override
  String get qazaAddToList => 'میری فہرست میں شامل کریں';

  @override
  String get qazaDhuhr => 'ظہر';

  @override
  String get qazaAyat => 'نماز آیات';

  @override
  String get qazaOther => 'دیگر';

  @override
  String audioMobileDataSizedBody(String size) {
    return 'آپ Wi-Fi پر نہیں ہیں۔ اس سے تقریباً $size موبائل ڈیٹا استعمال ہو گا۔';
  }

  @override
  String get audioRemoveDownloadsTitle => 'ڈاؤن لوڈز ہٹائیں؟';

  @override
  String get audioRemoveDownloadTitle => 'ڈاؤن لوڈ ہٹائیں؟';

  @override
  String audioRemoveBody(String subject) {
    return '$subject دوبارہ اسٹریم ہو گا، اس لیے سننے کے لیے آپ کو کنکشن درکار ہو گا۔';
  }

  @override
  String get audioTheseRecitations => 'یہ تلاوتیں';

  @override
  String get audioThisRecitation => 'یہ تلاوت';

  @override
  String audioQuotedName(String name) {
    return '\"$name\"';
  }

  @override
  String audioRemoveFrees(String size) {
    return '$size خالی ہو گا۔';
  }

  @override
  String get audioDownloadDone => 'ڈاؤن لوڈ شدہ — کنکشن کے بغیر چلتا ہے';

  @override
  String audioDownloadDoneNamed(String name) {
    return '$name ڈاؤن لوڈ ہو گیا — کنکشن کے بغیر چلتا ہے';
  }

  @override
  String get audioTheseRecitationsLower => 'یہ تلاوتیں';

  @override
  String get audioThisRecitationLower => 'یہ تلاوت';

  @override
  String audioDownloadPartial(int saved, int total) {
    return '$total میں سے $saved ڈاؤن لوڈ ہوا۔';
  }

  @override
  String audioDownloadFailedNamed(String what) {
    return '$what ڈاؤن لوڈ نہیں ہو سکا۔';
  }

  @override
  String get audioDownloadOutOfSpace =>
      'آپ کے آلے میں جگہ ختم ہو گئی ہے — کچھ خالی کریں اور دوبارہ کوشش کریں۔';

  @override
  String get audioDownloadUnavailable => 'ایک تلاوت اب دستیاب نہیں۔';

  @override
  String get audioDownloadCheckConnection =>
      'اپنا کنکشن چیک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get commonRetry => 'دوبارہ کوشش کریں';

  @override
  String commonPercent(int percent) {
    return '$percent%';
  }

  @override
  String audioDownloadMore(int count) {
    return '$count مزید ڈاؤن لوڈ کریں';
  }

  @override
  String get audioDownloadAll => 'تمام ڈاؤن لوڈ کریں';

  @override
  String get audioDownloadForOffline => 'آف لائن سننے کے لیے ڈاؤن لوڈ کریں';

  @override
  String get audioOfflineCannotDownload =>
      'آپ آف لائن ہیں۔ ڈاؤن لوڈ کرنے کے لیے انٹرنیٹ سے کنکٹ ہوں۔';

  @override
  String get audioMobileDataTitle => 'موبائل ڈیٹا استعمال کرکے ڈاؤن لوڈ کریں؟';

  @override
  String get audioMobileDataBody =>
      'آپ Wi-Fi پر نہیں ہیں۔ تلاوتیں بڑی ہو سکتی ہیں، اس لیے اس سے بہت سا موبائل ڈیٹا استعمال ہو سکتا ہے۔';

  @override
  String get commonRemove => 'ہٹائیں';

  @override
  String get audioDownloading => 'ڈاؤن لوڈ ہو رہا ہے';

  @override
  String get audioDownloadingEllipsis => 'ڈاؤن لوڈ ہو رہا ہے…';

  @override
  String get audioDownloadedTooltip =>
      'آف لائن سننے کے لیے ڈاؤن لوڈ شدہ۔ ہٹانے کے لیے ٹیپ کریں۔';

  @override
  String get audioRetryDownload => 'ڈاؤن لوڈ دوبارہ آزمائیں';

  @override
  String get audioDownloadFailedTooltip =>
      'ڈاؤن لوڈ مکمل نہیں ہوا۔ دوبارہ کوشش کے لیے ٹیپ کریں۔';

  @override
  String get audioDownloadRestTooltip =>
      'باقی آف لائن سننے کے لیے ڈاؤن لوڈ کریں';

  @override
  String get counterSemanticsLabel => 'موجودہ رکعت اور سجدہ';

  @override
  String counterRakaatCompleted(int count) {
    return '$count رکعتیں مکمل';
  }

  @override
  String counterPosition(int rakaat, int sajdah) {
    return 'رکعت $rakaat · سجدہ $sajdah';
  }

  @override
  String counterSajdahProgress(int done, int total) {
    return '$total میں سے $done سجدے';
  }

  @override
  String get counterSensorStopped =>
      'قربت سینسر نے جواب دینا بند کر دیا۔ فون کی پوزیشن چیک کریں اور خودکار سینسنگ دوبارہ آن کریں۔';

  @override
  String get counterStartOverTitle => 'از سر نو شروع کریں؟';

  @override
  String get counterStartOverBody =>
      'رکعتوں کی تعداد بدلنے سے موجودہ نماز کی گنتی ری سیٹ ہو جائے گی۔';

  @override
  String get counterStartOver => 'از سر نو شروع کریں';

  @override
  String get counterTitle => 'رکعت کاؤنٹر';

  @override
  String get counterHowToPlace => 'اپنا فون کیسے رکھیں';

  @override
  String get counterPlaceBelowTurbah => 'فون تربت کے نیچے رکھیں';

  @override
  String get counterPlaceBelowTurbahBody =>
      'اسے تربت کے نیچے ہموار رکھیں، اوپر والا کنارہ اس کی طرف ہو۔ اپنے ماتھے کے راستے کو خالی رکھیں۔';

  @override
  String get counterPrayerLength => 'نماز کی طوالت';

  @override
  String get counterSelectRakaat => 'رکعتوں کی تعداد منتخب کریں';

  @override
  String get counterComplete => 'مکمل';

  @override
  String get counterSajdahDetected => 'سجدہ محسوس ہو گیا';

  @override
  String get counterSensorReady => 'سینسر تیار ہے';

  @override
  String get counterCheckingSensor => 'سینسر چیک ہو رہا ہے';

  @override
  String get counterSensingOff => 'خودکار سینسنگ آف ہے';

  @override
  String get counterTapHint =>
      'صرف اس صورت میں ٹیپ کریں جب سجدہ خود بخود محسوس نہ ہوا ہو';

  @override
  String get counterReady => 'پہلے سجدے کے لیے تیار';

  @override
  String get counterAutomaticHint =>
      'خودکار گنتی · صرف اس صورت میں ٹیپ کریں جب کوئی رہ جائے';

  @override
  String get counterManualHint =>
      'دستی طور پر سجدہ شامل کرنے کے لیے کارڈ پر ٹیپ کریں';

  @override
  String get counterCheckingDevice => 'یہ آلہ چیک ہو رہا ہے…';

  @override
  String get counterNotAvailable => 'اس آلے پر خودکار گنتی دستیاب نہیں ہے۔';

  @override
  String get counterObjectDetected =>
      'کوئی چیز محسوس ہوئی۔ اگلی گنتی تیار ہونے کے لیے دور ہٹیں۔';

  @override
  String get counterSensorArmed =>
      'تیار — ہر محسوس شدہ سجدہ ایک بار گنا جاتا ہے۔';

  @override
  String get counterSensorOffSubtitle =>
      'آف — سجدے خود بخود گننے کے لیے اسے آن کریں۔';

  @override
  String get counterAutomaticSensing => 'خودکار سینسنگ';

  @override
  String get counterIphoneNote =>
      'iPhone پر، سینسر ڈھکا ہونے کے دوران ڈسپلے کچھ دیر کے لیے بند ہو سکتا ہے۔ سینسر کی پوزیشن اور رینج ماڈل کے لحاظ سے مختلف ہوتی ہے۔';

  @override
  String get counterAndroidNote =>
      'سینسر کی پوزیشن اور رینج فون کے لحاظ سے مختلف ہوتی ہے۔ کچھ Android فون کم قابل اعتماد ورچوئل قربت سینسر استعمال کرتے ہیں۔';

  @override
  String get counterPhonePlacement => 'فون کی جگہ';

  @override
  String get counterPlacementBody =>
      'فون کو تربت کے نیچے ہموار رکھیں، اس کا اوپر والا کنارہ اور سینسر اس کی طرف ہو۔ فون کو اپنے ماتھے کے راستے سے بالکل دور رکھیں۔';

  @override
  String get counterPlacementTest =>
      'شروع کرنے سے پہلے سینسر فعال کریں اور اپنے ہاتھ سے اسے آزمائیں۔ ہر ٹیسٹ کے بعد اپنا ہاتھ دور ہٹائیں تاکہ اگلی گنتی تیار ہو سکے۔';

  @override
  String quranJuzNumber(int number) {
    return 'جزء $number';
  }

  @override
  String quranCopiedVerse(String verse) {
    return '$verse کاپی ہو گئی';
  }

  @override
  String get quranRemoveFromSaved => 'محفوظ شدہ سے ہٹائیں';

  @override
  String get quranSaveVerse => 'آیت محفوظ کریں';

  @override
  String quranRemovedVerse(String verse) {
    return '$verse ہٹا دی گئی';
  }

  @override
  String quranSavedVerse(String verse) {
    return '$verse محفوظ ہو گئی';
  }

  @override
  String zikrPartNumber(int number) {
    return 'حصہ $number';
  }

  @override
  String zikrBookmarkMoveHint(String icon) {
    return 'بک مارک ہو گیا۔ اسے بعد میں منتقل کرنے کے لیے، \"بک مارک شدہ\" لیبل پر موجود $icon کو گھسیٹ کر کسی اور سطر پر لے جائیں۔';
  }

  @override
  String get quranCopyVerse => 'آیت کاپی کریں';

  @override
  String get quranCopyLink => 'لنک کاپی کریں';

  @override
  String get quranLinkCopied => 'لنک کاپی ہو گیا';

  @override
  String get quranShareVerse => 'آیت شیئر کریں';

  @override
  String get zikrMerits => 'فضائل';

  @override
  String get zikrReportThanks => 'شکریہ — ہم جائزہ لیں گے۔';

  @override
  String get zikrReportFailed =>
      'رپورٹ بھیجی نہیں جا سکی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get zikrSuggestCorrection => 'درستگی تجویز کریں';

  @override
  String get zikrSelectedText => 'منتخب متن';

  @override
  String get zikrCorrectionHint => 'اس کے بجائے کیا ہونا چاہیے؟ (اختیاری)';

  @override
  String get commonSubmit => 'جمع کریں';

  @override
  String get zikrSetReminder => 'یاد دہانی مقرر کریں';

  @override
  String get zikrUnableToOpen => 'یہ دعا کھولی نہیں جا سکی۔';

  @override
  String get zikrComingSoon => 'جلد آ رہا ہے...';

  @override
  String get zikrHideCounter => 'کاؤنٹر چھپائیں';

  @override
  String deleteAccountSignInFailed(String error) {
    return 'سائن ان ناکام: $error';
  }

  @override
  String deleteAccountSignOutFailed(String error) {
    return 'سائن آؤٹ ناکام: $error';
  }

  @override
  String deleteAccountFailed(String error) {
    return 'اکاؤنٹ حذف کرنے میں خرابی: $error';
  }

  @override
  String deleteAccountSignedInAs(String account) {
    return 'آپ بطور $account سائن ان ہیں۔';
  }

  @override
  String get deleteAccountSignedIn => 'کامیابی سے سائن ان ہو گیا۔';

  @override
  String get deleteAccountSignedOut => 'سائن آؤٹ ہو گیا۔';

  @override
  String get deleteAccountConfirmTitle => 'اکاؤنٹ حذف کریں؟';

  @override
  String get deleteAccountConfirmBody =>
      'اس سے آپ کا Shia Companion اکاؤنٹ اور سنک شدہ پسندیدہ مستقل طور پر حذف ہو جاتے ہیں۔';

  @override
  String get deleteAccountDone => 'اکاؤنٹ کامیابی سے حذف ہو گیا۔';

  @override
  String get deleteAccountTitle => 'اکاؤنٹ حذف کریں';

  @override
  String get deleteAccountHeading =>
      'اپنے Shia Companion اکاؤنٹ کا انتظام کریں';

  @override
  String get deleteAccountSignInPrompt =>
      'اپنے سنک شدہ پسندیدہ سے منسلک اکاؤنٹ کا جائزہ لینے اور اسے مستقل طور پر حذف کرنے کے لیے سائن ان کریں۔';

  @override
  String get deleteAccountWhatGetsDeleted => 'کیا حذف ہوتا ہے';

  @override
  String get deleteAccountItemSignIn =>
      'آپ کے Shia Companion اکاؤنٹ کے سائن ان کا ریکارڈ۔';

  @override
  String get deleteAccountItemFavorites =>
      'اس اکاؤنٹ کے لیے محفوظ آپ کے سنک شدہ پسندیدہ اور قضا ٹریکر۔';

  @override
  String get deleteAccountItemPreferences =>
      'آپ کی سنک شدہ تلاوت ترجیحات — ہجری تاریخ کی ایڈجسٹمنٹ اور فونٹ کے انتخاب۔';

  @override
  String get deleteAccountItemAnalytics =>
      'پہلے سے جمع کیے گئے گمنام تجزیات یا کریش رپورٹس مجموعی صورت میں باقی رہ سکتے ہیں۔';

  @override
  String get deleteAccountCompleted =>
      'آپ کی اکاؤنٹ حذف کرنے کی درخواست مکمل ہو گئی ہے۔';

  @override
  String get deleteAccountCompletedNote =>
      'اگر آپ بعد میں دوبارہ سائن ان کرتے ہیں تو ایک بالکل نیا اکاؤنٹ بنے گا۔';

  @override
  String get deleteAccountWebSteps =>
      'نیچے Google سائن ان بٹن استعمال کریں، پھر حذف کی تصدیق کریں۔';

  @override
  String get deleteAccountAppSteps =>
      'ایپ میں ترجیحات کھولیں اور میرا اکاؤنٹ حذف کریں استعمال کریں۔';

  @override
  String get deleteAccountSigningIn => 'سائن ان ہو رہا ہے...';

  @override
  String get deleteAccountDeleting => 'حذف ہو رہا ہے...';

  @override
  String get deleteAccountButton => 'میرا اکاؤنٹ حذف کریں';

  @override
  String get deleteAccountSignOut => 'سائن آؤٹ';

  @override
  String get deleteAccountHelp =>
      'مدد چاہیے؟ developer110@hotmail.com پر ای میل کریں اور اپنے اکاؤنٹ سے منسلک ای میل ایڈریس شامل کریں۔';

  @override
  String statsBestStreak(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'بہترین: $days دن',
      one: 'بہترین: ایک دن',
    );
    return '$_temp0';
  }

  @override
  String get statsTodayDone => 'آج: ہو گیا';

  @override
  String get statsTodayNotYet => 'آج: ابھی نہیں';

  @override
  String statsDaysToGoal(int remaining, Object goal) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: 'ہدف کے سلسلے تک $remaining دن اور',
      one: 'ہدف کے سلسلے تک ایک دن اور',
    );
    return '$_temp0';
  }

  @override
  String statsUpdatedHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours گھنٹے پہلے اپ ڈیٹ ہوا',
      one: 'ایک گھنٹہ پہلے اپ ڈیٹ ہوا',
    );
    return '$_temp0';
  }

  @override
  String statsUpdatedOn(String date) {
    return '$date کو اپ ڈیٹ ہوا';
  }

  @override
  String statsAllTime(String count) {
    return 'کل $count';
  }

  @override
  String statsCommunityNote(String updated) {
    return 'ایپ استعمال کرنے والے تمام لوگوں کے گمنام مجموعے۔ $updated۔';
  }

  @override
  String get statsTitle => 'میرے اعداد و شمار';

  @override
  String get statsYourMostRecited => 'آپ کی سب سے زیادہ تلاوت شدہ';

  @override
  String get statsStreakStart =>
      'کوئی دعا، زیارت یا سورہ پڑھنا مکمل کریں اور آپ کا سلسلہ شروع ہو جائے گا۔';

  @override
  String get statsWelcomeBack => 'خوش آمدید — ہر دن ایک نئی شروعات ہے۔';

  @override
  String get statsDoneTodayFirst =>
      'آج کے لیے ہو گیا۔ سلسلہ شروع کرنے کے لیے کل واپس آئیں۔';

  @override
  String get statsDoneToday => 'آج کے لیے ہو گیا — کل ملتے ہیں، ان شاء اللہ۔';

  @override
  String get statsReadToday => 'اسے جاری رکھنے کے لیے آج کچھ پڑھیں۔';

  @override
  String get statsDayStreak => 'دنوں کا سلسلہ';

  @override
  String get statsToday => 'آج';

  @override
  String get statsPrivateSynced =>
      'آپ کے اعداد و شمار نجی ہیں اور آپ کے اکاؤنٹ میں سائن ان آلات پر سنک ہوتے ہیں۔';

  @override
  String get statsPrivateLocal =>
      'آپ کے اعداد و شمار نجی ہیں اور اس آلے پر رکھے جاتے ہیں۔ انہیں تمام آلات پر رکھنے کے لیے ترجیحات سے سائن ان کریں۔';

  @override
  String get statsUpdatedWithinHour => 'گھنٹے کے اندر اپ ڈیٹ ہوا';

  @override
  String get statsAcrossCommunity => 'پوری کمیونٹی میں';

  @override
  String get statsRecitedThisWeek =>
      'اس ہفتے تلاوت کی گئی دعائیں، زیارات اور سورتیں';

  @override
  String get statsMostRecitedThisWeek => 'اس ہفتے سب سے زیادہ تلاوت شدہ';

  @override
  String quranSurahNumber(int number) {
    return 'سورہ $number';
  }

  @override
  String get listenQuranTextFailed => 'اس آلے پر قرآن کا متن نہیں پڑھا جا سکا۔';

  @override
  String get listenRecogniserStopped =>
      'شناخت کار غیر متوقع طور پر رک گیا۔ دوبارہ کوشش کریں۔';

  @override
  String get listenNothingRecognised =>
      'کوئی قابل شناخت چیز نہیں آئی۔ دوبارہ کوشش کریں، قاری سے تھوڑا قریب ہو کر۔';

  @override
  String get listenCouldNotPlace =>
      'اسے قرآن میں تلاش نہیں کیا جا سکا۔ تھوڑا اور تلاوت کر کے دیکھیں۔';

  @override
  String get listenMicPermissionWeb =>
      'سننے کے لیے مائیکروفون تک رسائی درکار ہے۔ آپ اسے اپنے براؤزر میں اس سائٹ کی اجازتوں میں دے سکتے ہیں۔';

  @override
  String get listenMicPermission =>
      'سننے کے لیے مائیکروفون تک رسائی درکار ہے۔ آپ اسے اپنے آلے کی ترتیبات میں دے سکتے ہیں۔';

  @override
  String get listenBrowserUnsupported =>
      'یہ براؤزر آواز نہیں پہچان سکتا۔ Chrome، Edge اور Safari پہچان سکتے ہیں۔';

  @override
  String get listenDeviceUnsupported =>
      'اس آلے پر کوئی آواز شناخت کار دستیاب نہیں۔';

  @override
  String get listenNoArabic =>
      'اس آلے پر عربی آواز کی شناخت انسٹال نہیں ہے۔ اپنے آلے کی زبان کی ترتیبات میں عربی شامل کرنے سے یہ فعال ہو جائے گی۔';

  @override
  String get listenStartFailed => 'سننا شروع نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get listenTitle => 'سنیں اور ساتھ چلیں';

  @override
  String get listenGettingReady => 'تیاری ہو رہی ہے…';

  @override
  String get listenListening => 'سن رہا ہے…';

  @override
  String get listenHoldPhone => 'فون کو تلاوت کی طرف رکھیں۔';

  @override
  String get listenFindNow => 'آیت ابھی تلاش کریں';

  @override
  String get listenFinding => 'آیت تلاش ہو رہی ہے…';

  @override
  String get listenWhichVerse => 'وہ کون سی آیت تھی؟';

  @override
  String get listenAgain => 'دوبارہ سنیں';

  @override
  String get commonTryAgain => 'دوبارہ کوشش کریں';

  @override
  String flightDepartureDateAt(String airport) {
    return '$airport پر روانگی کی تاریخ';
  }

  @override
  String flightArrivalDateAt(String airport) {
    return '$airport پر آمد کی تاریخ';
  }

  @override
  String flightDepartureTimeAt(String airport) {
    return 'روانگی کا وقت ($airport پر مقامی)';
  }

  @override
  String flightArrivalTimeAt(String airport) {
    return 'آمد کا وقت ($airport پر مقامی)';
  }

  @override
  String flightDurationTooLong(String duration) {
    return 'اس حساب سے ہوا میں $duration بنتا ہے۔ آمد کی تاریخ چیک کریں۔';
  }

  @override
  String get flightFrom => 'سے';

  @override
  String get flightTo => 'تک';

  @override
  String get flightDeparts => 'روانگی';

  @override
  String get flightArrives => 'آمد';

  @override
  String get flightDepartureAirport => 'روانگی کا ہوائی اڈا';

  @override
  String get flightArrivalAirport => 'آمد کا ہوائی اڈا';

  @override
  String get flightChooseDepartureFirst =>
      'پہلے روانگی کا ہوائی اڈا منتخب کریں۔';

  @override
  String get flightChooseArrivalFirst => 'پہلے آمد کا ہوائی اڈا منتخب کریں۔';

  @override
  String get flightChooseBothAirports => 'دونوں ہوائی اڈے منتخب کریں۔';

  @override
  String get flightSetTimes => 'روانگی اور آمد کے اوقات مقرر کریں۔';

  @override
  String get flightAirportsMustDiffer =>
      'روانگی اور آمد کے ہوائی اڈے مختلف ہونے چاہئیں۔';

  @override
  String get flightTimeZoneUnresolved =>
      'ان میں سے ایک ہوائی اڈے کا ٹائم زون معلوم نہیں ہو سکا۔';

  @override
  String get flightArrivalBeforeDeparture =>
      'ٹائم زون لاگو کرنے کے بعد آمد روانگی سے پہلے آتی ہے۔ آمد کی تاریخ چیک کریں — رات کی پروازیں اگلے دن اترتی ہیں۔';

  @override
  String get flightAdd => 'پرواز شامل کریں';

  @override
  String get flightDepartsHint => 'روانگی کے ہوائی اڈے کا مقامی وقت';

  @override
  String get flightArrivesHint => 'آمد کے ہوائی اڈے کا مقامی وقت';

  @override
  String get flightNumberLabel => 'پرواز نمبر (اختیاری)';

  @override
  String get flightSaveChanges => 'تبدیلیاں محفوظ کریں';

  @override
  String get flightSave => 'پرواز محفوظ کریں';

  @override
  String get flightTicketNote =>
      'اوقات بالکل ویسے درج کریں جیسے آپ کے ٹکٹ پر ہیں — ہر ایک اس کے اپنے ہوائی اڈے کے مقامی وقت میں۔';

  @override
  String get flightChooseAirport => 'ہوائی اڈا منتخب کریں';

  @override
  String get flightChooseDateTime => 'تاریخ اور وقت منتخب کریں';

  @override
  String get widgetIslamicCalendar => 'اسلامی کیلنڈر';

  @override
  String get widgetFavorites => 'پسندیدہ';

  @override
  String get widgetNoFavorites => 'ابھی کوئی پسندیدہ نہیں';

  @override
  String get widgetTodaysRecitations => 'آج کی تلاوتیں';

  @override
  String get widgetOpenAppToRefresh => 'تازہ کرنے کے لیے ایپ کھولیں';

  @override
  String get widgetUpNext => 'اگلا';

  @override
  String get widgetPrayerTimes => 'نماز کے اوقات';

  @override
  String get widgetLocationNeeded => 'مقام درکار ہے';

  @override
  String get widgetSavedLocation => 'محفوظ مقام';

  @override
  String get widgetSetLocation => 'مقام مقرر کریں';

  @override
  String get widgetOpenApp => 'ایپ کھولیں';

  @override
  String get widgetRefreshSchedule => 'شیڈول تازہ کریں';

  @override
  String get commonToday => 'آج';

  @override
  String get commonTomorrow => 'کل';

  @override
  String quranSurahAyah(String surah, int ayah) {
    return '$surah $ayah';
  }

  @override
  String trackNameTaken(String name) {
    return 'پہلے سے ایک ٹریک ہے جس کا نام \"$name\" ہے';
  }

  @override
  String get trackNameRequired => 'ٹریک کو نام دیں';

  @override
  String get trackBeginning => 'شروعات';

  @override
  String get trackNew => 'نیا تلاوت ٹریک';

  @override
  String get trackName => 'نام';

  @override
  String get trackNameHint => 'مثلاً خاندان، تہجد';

  @override
  String get trackReadBy => 'تلاوت کنندہ';

  @override
  String get trackBySurah => 'سورہ';

  @override
  String get trackByJuz => 'جزء (پارہ)';

  @override
  String get trackContinueFrom => 'یہاں سے جاری رکھیں';

  @override
  String get trackStartFrom => 'یہاں سے شروع کریں';

  @override
  String get trackStartAt => 'یہاں سے آغاز';

  @override
  String get trackEditNote =>
      'آپ کے پڑھنے کے ساتھ آپ کا ٹریک خود بخود آگے بڑھتا ہے۔ اسے صرف اس وقت بدلیں جب کہیں اور سے جاری رکھنا ہو۔';

  @override
  String get trackNewNote => 'آپ انہیں کسی بھی وقت ٹریک کارڈ سے بدل سکتے ہیں۔';

  @override
  String get trackCreate => 'ٹریک بنائیں';

  @override
  String notifDefaultSoundSubtitle(String sound) {
    return '$sound · استعمال ہوتی ہے جب تک نیچے کوئی وقت اسے نہ بدل دے';
  }

  @override
  String notifCustomSound(String file) {
    return 'حسب منشا: $file';
  }

  @override
  String notifPrayerSound(String prayer) {
    return '$prayer کی آواز';
  }

  @override
  String notifFollows(String sound) {
    return '$sound کی پیروی کرتی ہے';
  }

  @override
  String get notifDefaultSound => 'ڈیفالٹ آواز';

  @override
  String get notifTimesHeading => 'اوقات';

  @override
  String get notifAudioUnreadable => 'وہ آڈیو فائل پڑھی نہیں جا سکی۔';

  @override
  String get notifPickFailed => 'وہ فائل منتخب نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get notifPlayingSample => 'تھوڑی دیر میں نمونہ چلے گا…';

  @override
  String get notifUseDefault => 'ڈیفالٹ استعمال کریں';

  @override
  String get notifOwnSoundNote =>
      'یہ وقت اپنی آواز برقرار رکھتا ہے۔ باقی سب ڈیفالٹ کی پیروی کرتے ہیں۔';

  @override
  String get notifDefaultNote =>
      'ہر وقت اس کی پیروی کرتا ہے جب تک آپ اسے اس کی اپنی آواز نہ دیں۔';

  @override
  String get notifPreview => 'پیش نظارہ';

  @override
  String aboutVersion(String version) {
    return 'ورژن $version';
  }

  @override
  String get aboutDedication =>
      'ہم اللہ تعالیٰ کی حمد کرتے ہیں اور ان کے محبوب چودہ معصومین (ع) کا شکر ادا کرتے ہیں جن کی مدد نے ہمیں یہ معمولی کاوش مومنین کے ساتھ شیئر کرنے کے قابل بنایا۔ ہم یہ ایپ ان کے اور درج ذیل مرحومین کے نام وقف کرتے ہیں:\n\nMarhooma Amina Mohammed Raza Jassani\nMarhoom Haji Mohammad Raza Jassani\nMarhoom Haji Yusufali Bhojani\n\n\nبراہ کرم مرحومین و مرحومات کے لیے سورۂ فاتحہ تلاوت فرمائیں\n\nتاثرات، سوالات یا تجاویز کے لیے رابطہ کریں:';

  @override
  String get aboutNoEmailApp => 'کوئی ای میل ایپ نہیں ملی';

  @override
  String get aboutCredits => 'کریڈٹ';

  @override
  String get aboutCreditAudio =>
      'تلاوت کی آڈیو ہمارے اپنے سرورز پر میزبانی شدہ ہے؛ ریکارڈنگز duas.org کی مہربان اجازت سے استعمال کی گئی ہیں۔';

  @override
  String get aboutCreditScheherazade =>
      'عربی متن Scheherazade New میں مرتب ہے جو SIL Global کا ہے، SIL اوپن فونٹ لائسنس کے تحت استعمال شدہ۔';

  @override
  String get aboutCreditTanzil =>
      'عثمانی قرآن متن، جو Scheherazade کے ساتھ دکھایا جاتا ہے، Tanzil Project سے ہے، Creative Commons Attribution 3.0 کے تحت استعمال شدہ۔';

  @override
  String get aboutCreditQuranWbw =>
      'انڈوپاک قرآن متن اور فونٹ، جو Qalam کے ساتھ دکھائے جاتے ہیں، QuranWBW.com سے ہیں۔ قرآن متن اور فونٹ کو بغیر تبدیلی استعمال کرنے کا لائسنس QuranWBW.com، اصل معاون، سے حاصل کیا گیا۔';

  @override
  String get aboutCreditIndoPakFont =>
      'فونٹ: AlQuran IndoPak از QuranWBW، Ayman Siddiqui کا بنایا ہوا، Al Qalam Quran Majeed فونٹس پر مبنی، آیت نمبر KFGQPC Nastaleeq فونٹ سے۔ © Al Qalam © Ghandhara © KFGQPC © Ayman Siddiqui۔ کریڈٹ: Abdul Majeed Khan، Arif Karim، Shakir-ul-Qadree، Jawad۔ قرآن متن: typemybook.com، اصلاً InPage سے۔';

  @override
  String downloadsRemoveAllBody(String size) {
    return 'ہر تلاوت دوبارہ اسٹریم ہو گی، اس لیے سننے کے لیے آپ کو کنکشن درکار ہو گا۔ $size خالی ہو گا۔';
  }

  @override
  String downloadsOlderSubtitle(int count, String size) {
    return '$count اب کسی دعا کے استعمال میں نہیں · $size';
  }

  @override
  String get downloadsRemoveAllTitle => 'تمام ڈاؤن لوڈز ہٹائیں؟';

  @override
  String get downloadsRemoveAll => 'تمام ہٹائیں';

  @override
  String get downloadsEmpty => 'ابھی کوئی ڈاؤن لوڈ نہیں';

  @override
  String get downloadsEmptyBody =>
      'کنکشن کے بغیر سننے کے لیے کوئی تلاوت ڈاؤن لوڈ کریں — کسی دعا کے آڈیو پلیئر میں ڈاؤن لوڈ بٹن پر ٹیپ کریں، یا پلے لسٹ پر تمام ڈاؤن لوڈ کریں۔';

  @override
  String get downloadsOlder => 'پرانی ریکارڈنگز';

  @override
  String get downloadsRemoveOlder => 'پرانی ریکارڈنگز ہٹائیں';

  @override
  String get hijriMonth1 => 'محرم';

  @override
  String get hijriMonth2 => 'صفر';

  @override
  String get hijriMonth3 => 'ربیع الاول';

  @override
  String get hijriMonth4 => 'ربیع الثانی';

  @override
  String get hijriMonth5 => 'جمادی الاول';

  @override
  String get hijriMonth6 => 'جمادی الثانی';

  @override
  String get hijriMonth7 => 'رجب';

  @override
  String get hijriMonth8 => 'شعبان';

  @override
  String get hijriMonth9 => 'رمضان';

  @override
  String get hijriMonth10 => 'شوال';

  @override
  String get hijriMonth11 => 'ذوالقعدہ';

  @override
  String get hijriMonth12 => 'ذوالحجہ';

  @override
  String get hijriMonthShort1 => 'محر';

  @override
  String get hijriMonthShort2 => 'صفر';

  @override
  String get hijriMonthShort3 => 'رب۱';

  @override
  String get hijriMonthShort4 => 'رب۲';

  @override
  String get hijriMonthShort5 => 'جم۱';

  @override
  String get hijriMonthShort6 => 'جم۲';

  @override
  String get hijriMonthShort7 => 'رجب';

  @override
  String get hijriMonthShort8 => 'شعب';

  @override
  String get hijriMonthShort9 => 'رمض';

  @override
  String get hijriMonthShort10 => 'شوا';

  @override
  String get hijriMonthShort11 => 'ذق';

  @override
  String get hijriMonthShort12 => 'ذح';

  @override
  String prayerUpdatedAgo(String age) {
    return '$age اپ ڈیٹ ہوا';
  }

  @override
  String get prayerNextDay => '(اگلے دن)';

  @override
  String get prayerLocating => 'مقام تلاش ہو رہا ہے…';

  @override
  String get prayerForYourLocation => 'آپ کے مقام کے نماز اوقات';

  @override
  String get prayerFindingLocation => 'آپ کا مقام تلاش ہو رہا ہے';

  @override
  String get prayerAppearSoon => 'نماز کے اوقات تھوڑی دیر میں ظاہر ہوں گے';

  @override
  String get prayerTapToRetry => 'دوبارہ کوشش کے لیے ٹیپ کریں';

  @override
  String get prayerLocationUnavailable => 'مقام دستیاب نہیں';

  @override
  String get prayerTapToEnableLocation => 'مقام فعال کرنے کے لیے یہاں ٹیپ کریں';

  @override
  String calendarNotificationsSomeOn(int enabled, int total) {
    return '$total میں سے $enabled آن';
  }

  @override
  String get calendarNoEvent => 'اس تاریخ کے لیے کوئی تقریب درج نہیں۔';

  @override
  String get calendarNotificationsAllOff => 'ہر نماز کے لیے آف';

  @override
  String get readingFineTune =>
      'ذکر کے متن کی باریک ایڈجسٹمنٹ۔ ترتیبات میں ایپ کے متن کے سائز کے اوپر لاگو ہوتی ہے۔';

  @override
  String get readingArabicFontSize => 'عربی فونٹ کا سائز';

  @override
  String get readingEnglishFontSize => 'انگریزی فونٹ کا سائز';

  @override
  String get readingArabicFont => 'عربی فونٹ';

  @override
  String get readingKeepScreenOn => 'ذکر کی تلاوت کے دوران اسکرین آن رکھیں';

  @override
  String get readingFocusMode => 'توجہ موڈ';

  @override
  String get readingFocusModeSubtitle =>
      'پڑھنے کے دوران پیش رفت بار اور ایکشن بار چھپائیں۔ انہیں واپس لانے کے لیے اوپر اسکرول کریں یا ٹیپ کریں۔';

  @override
  String get readingShareAsImage => 'ذکر کو تصویر کے طور پر شیئر کریں';

  @override
  String get readingShareAsImageSubtitle =>
      'شیئر کرتے وقت فارمیٹ شدہ تصویر بنائیں۔';

  @override
  String get readingShowTransliteration => 'نقل حرفی دکھائیں';

  @override
  String get readingShowTranslation => 'ترجمہ دکھائیں';

  @override
  String get readingArabicParagraph => 'عربی کو پیراگراف کے طور پر دکھائیں';

  @override
  String get readingArabicParagraphOn =>
      'عربی آیات کو الگ سطروں کے بجائے ایک پیراگراف کے طور پر بہائیں۔';

  @override
  String get readingArabicParagraphOff =>
      'اسے استعمال کرنے کے لیے اوپر نقل حرفی اور ترجمہ آف کریں۔';

  @override
  String pickerJuzRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String pickerSurahDetails(String ayahs, String juz) {
    return '$ayahs · جزء $juz';
  }

  @override
  String quranAyahCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آیات',
      one: 'ایک آیت',
    );
    return '$_temp0';
  }

  @override
  String pickerJuzFrom(String start) {
    return '$start سے';
  }

  @override
  String pickerAyahSingle(int ayah) {
    return 'آیت $ayah';
  }

  @override
  String pickerAyahRange(int from, int to) {
    return 'آیات $from–$to';
  }

  @override
  String get pickerThirtyJuz => 'کل 30 جزء ہیں';

  @override
  String get pickerTryVerse => '33:33 جیسی کوئی آیت آزمائیں، یا جزء 22';

  @override
  String get pickerSearchHint => 'کسی آیت پر جائیں — 33:33، 18، جزء 22';

  @override
  String get pickerChooseVerse => 'آیت منتخب کریں';

  @override
  String get pickerAllJuz => 'تمام جزء';

  @override
  String get pickerAllSurahs => 'تمام سورتیں';

  @override
  String get pickerChoose => 'منتخب کریں';

  @override
  String quranFromPosition(String position) {
    return '$position سے';
  }

  @override
  String quranPercentRead(String percent) {
    return 'قرآن کا $percent%';
  }

  @override
  String quranEditTrack(String track) {
    return '$track ٹریک میں ترمیم کریں';
  }

  @override
  String get quranTitle => 'قرآن';

  @override
  String get quranRecentSessions => 'حالیہ سیشنز';

  @override
  String get quranTabSurahs => 'سورتیں';

  @override
  String get quranTabJuz => 'جزء';

  @override
  String get quranTabCollections => 'مجموعے';

  @override
  String get quranStartReading => 'پڑھنا شروع کریں';

  @override
  String get quranNewTrack => 'نیا ٹریک';

  @override
  String get quranGoToVerseError => '23:56 جیسی کوئی چیز آزمائیں';

  @override
  String get quranGoToVerseHint => 'آیت پر جائیں، مثلاً 23:56';

  @override
  String get quranGo => 'جائیں';

  @override
  String get statsMetricVerses => 'آیات';

  @override
  String get statsMetricZikrs => 'اذکار';

  @override
  String get statsMetricQaza => 'قضا';

  @override
  String get statsMetricVersesLower => 'آیات';

  @override
  String get statsMetricZikrsLower => 'اذکار';

  @override
  String get statsMetricQazaLower => 'قضا';

  @override
  String statsVerseCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آیات',
      one: '$count آیت',
    );
    return '$_temp0';
  }

  @override
  String statsZikrCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اذکار',
      one: '$count ذکر',
    );
    return '$_temp0';
  }

  @override
  String statsQazaCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قضا',
    );
    return '$_temp0';
  }

  @override
  String get statsPeriodWeek => 'ہفتہ';

  @override
  String get statsPeriodMonth => 'مہینہ';

  @override
  String get statsPeriodAllTime => 'تمام وقت';

  @override
  String statsCaptionWeek(String metric) {
    return 'پچھلے 7 دنوں میں $metric';
  }

  @override
  String statsCaptionMonth(String metric) {
    return 'پچھلے 30 دنوں میں $metric';
  }

  @override
  String statsCaptionAllTime(String metric) {
    return 'مجموعی طور پر $metric';
  }

  @override
  String get statsHistory => 'تاریخچہ';

  @override
  String statsBestMonth(String month, String count) {
    return 'بہترین مہینہ: $month · $count';
  }

  @override
  String statsBestDay(String day, String count, String average) {
    return 'بہترین دن: $day · $count · اوسطاً روزانہ $average';
  }

  @override
  String get statsNew => 'نیا';

  @override
  String statsVersusBefore(String count) {
    return 'پہلے کے $count کے مقابلے میں';
  }

  @override
  String statsSessionCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سیشنز',
      one: '$count سیشن',
    );
    return '$_temp0';
  }

  @override
  String statsVersesRecited(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آیات تلاوت ہوئیں',
      one: '$count آیت تلاوت ہوئی',
    );
    return '$_temp0';
  }

  @override
  String statsLastOn(String date) {
    return 'آخری $date';
  }

  @override
  String statsVersesLeft(String count) {
    return 'ختم مکمل کرنے کے لیے $count آیات باقی ہیں';
  }

  @override
  String statsJuzCoverage(int juz, int percent) {
    return 'جزء $juz: $percent%';
  }

  @override
  String statsJuzComplete(int count) {
    return '30 میں سے $count جزء مکمل';
  }

  @override
  String get statsQuranProgress => 'قرآن کی پیش رفت';

  @override
  String get statsQuranEmpty =>
      'کوئی سورہ کھولیں اور پڑھنا شروع کریں — آپ کی تلاوت کی گئی آیات یہاں خود بخود درج ہوتی ہیں، مکمل ختم کی طرف آپ کی پیش رفت کے ساتھ۔';

  @override
  String get statsRecitedTill => 'یہاں تک تلاوت ہوئی';

  @override
  String get statsNotStarted => 'شروع نہیں ہوا';

  @override
  String get statsJuzDone => 'جزء مکمل';

  @override
  String get statsKhatmComplete => 'ختم مکمل — اللہ قبول فرمائے';

  @override
  String reminderAtPrayer(String prayer) {
    return '$prayer پر';
  }

  @override
  String reminderMinutesAfter(int minutes, String prayer) {
    return '$prayer کے $minutes منٹ بعد';
  }

  @override
  String reminderMinutesBefore(int minutes, String prayer) {
    return '$prayer سے $minutes منٹ پہلے';
  }

  @override
  String azanPlaying(String prayer) {
    return '$prayer کی اذان چل رہی ہے';
  }

  @override
  String get libraryNeedsNetwork =>
      'لائبریری براؤز کرنے کے لیے نیٹ ورک کنکشن درکار ہے۔';

  @override
  String get libraryChaptersFailed =>
      'ابواب لوڈ نہیں ہو سکے۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get libraryReadingNeedsNetwork =>
      'کتابیں پڑھنے کے لیے نیٹ ورک کنکشن درکار ہے۔';

  @override
  String get libraryChapterFailed =>
      'یہ باب لوڈ نہیں ہو سکا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get menuCalendarPrayerTimes => 'کیلنڈر اور نماز کے اوقات';

  @override
  String get menuFavorites => 'پسندیدہ';

  @override
  String get menuTodaysRecitations => 'آج کی تلاوتیں';

  @override
  String get menuTaqeebat => 'تعقیبات نماز';

  @override
  String get menuNamaz => 'نماز';

  @override
  String get menuDuas => 'دعائیں';

  @override
  String get menuZiyarats => 'زیارات';

  @override
  String get menuSurahs => 'سورتیں';

  @override
  String get menuAamaal => 'اعمال';

  @override
  String get menuLibrary => 'لائبریری';

  @override
  String get menuMunajaat => 'مناجات';

  @override
  String get menuBaaqeyaat => 'باقیات صالحات';

  @override
  String get menuQiblaFinder => 'قبلہ تلاش کنندہ';

  @override
  String get menuTasbeehCounter => 'تسبیح کاؤنٹر';

  @override
  String get menuQazaTracker => 'قضا ٹریکر';

  @override
  String get menuRakaatCounter => 'رکعت کاؤنٹر';

  @override
  String get menuPrayerTimesInFlight => 'پرواز میں نماز کے اوقات';

  @override
  String get menuPreferences => 'ترجیحات';

  @override
  String get menuQuran => 'قرآن';

  @override
  String get menuPlaylists => 'پلے لسٹس';

  @override
  String get menuMyStats => 'میرے اعداد و شمار';

  @override
  String get menuCalendar => 'کیلنڈر';

  @override
  String audioTrackNumber(int number) {
    return 'ٹریک $number';
  }

  @override
  String get audioPauseRecitation => 'تلاوت روکیں';

  @override
  String get audioPlayRecitation => 'تلاوت چلائیں';

  @override
  String get audioList => 'آڈیو فہرست';

  @override
  String get audioOfflineNotDownloaded =>
      'آپ آف لائن ہیں اور یہ تلاوت ڈاؤن لوڈ شدہ نہیں';

  @override
  String get audioLoadFailed => 'یہ تلاوت لوڈ نہیں ہو سکی';

  @override
  String get audioClosePlayer => 'پلیئر بند کریں';

  @override
  String get audioChooseRecording => 'ریکارڈنگ منتخب کریں';

  @override
  String get audioRecitation => 'تلاوت';

  @override
  String get audioRecitationAudio => 'تلاوت کی آڈیو';

  @override
  String librarySavedOffline(String book) {
    return '$book آف لائن کے لیے محفوظ ہو گئی۔';
  }

  @override
  String librarySaveFailed(String error) {
    return 'کتاب محفوظ نہیں ہو سکی: $error';
  }

  @override
  String libraryProgress(String chapter, int page, int pages) {
    return '$chapter — صفحہ $page از $pages';
  }

  @override
  String get librarySavedChapterGone => 'محفوظ باب اب دستیاب نہیں';

  @override
  String get libraryUnavailable => 'لائبریری دستیاب نہیں';

  @override
  String get libraryNoBooks => 'کوئی کتاب نہیں ملی';

  @override
  String get libraryEmpty => 'لائبریری اس وقت خالی ہے۔';

  @override
  String get libraryContinueReading => 'پڑھنا جاری رکھیں';

  @override
  String get libraryRequestBook => 'کتاب کی درخواست کریں';

  @override
  String get libraryRequestBookSubtitle =>
      'کوئی کتاب نہیں مل رہی؟ ہم سے شامل کرنے کی درخواست کریں۔';

  @override
  String flightRemoveBody(String flight) {
    return '$flight آپ کی محفوظ پروازوں سے ہٹا دیا جائے گا۔';
  }

  @override
  String flightLands(String duration, String time, String airport) {
    return '$duration · $time پر اترتی ہے $airport وقت';
  }

  @override
  String get flightRemoveTitle => 'پرواز ہٹائیں؟';

  @override
  String get flightRemove => 'پرواز ہٹائیں';

  @override
  String get flightNoneSaved => 'کوئی پرواز محفوظ نہیں';

  @override
  String get flightNoneSavedBody =>
      'اپنی پرواز شامل کریں اور یہ صفحہ نکالے گا کہ راستے میں ہر نماز کب آتی ہے — آپ کے روانگی اور آمد دونوں شہروں کے وقت میں دکھایا جائے گا۔';

  @override
  String librarySavedForOffline(String title) {
    return '$title آف لائن کے لیے محفوظ ہو گیا';
  }

  @override
  String librarySaveFailedShort(String error) {
    return 'محفوظ ناکام: $error';
  }

  @override
  String get libraryOfflineRemoved => 'آف لائن کاپی ہٹا دی گئی';

  @override
  String get libraryShareBook => 'کتاب شیئر کریں';

  @override
  String get libraryRemoveOffline => 'آف لائن کاپی ہٹائیں';

  @override
  String get librarySaveOffline => 'کتاب آف لائن محفوظ کریں';

  @override
  String get libraryChaptersUnavailable => 'ابواب دستیاب نہیں';

  @override
  String get libraryNoChapters => 'کوئی باب نہیں ملا';

  @override
  String get libraryNoChaptersBody => 'اس کتاب کے اس وقت کوئی ابواب نہیں ہیں۔';

  @override
  String quranMoveEntry(String entry) {
    return '\"$entry\" منتقل کریں';
  }

  @override
  String get quranNoSessions =>
      'ابھی کوئی سیشن نہیں۔ کوئی سورہ کھولیں اور پڑھنا شروع کریں — آپ کی تلاوت کی گئی آیات یہاں خود بخود درج ہوتی ہیں۔';

  @override
  String get quranMoveToLabel => 'دوسرے لیبل پر منتقل کریں';

  @override
  String get quranNewLabel => 'یا نیا لیبل';

  @override
  String get quranMove => 'منتقل کریں';

  @override
  String get quranCollectionDuas => 'دعائیں';

  @override
  String get quranCollectionImamAli => 'امام علی (ع)';

  @override
  String get quranCollectionImamMahdi => 'امام مہدی (عج)';

  @override
  String get quranCollectionProphets => 'انبیاء';

  @override
  String get quranCollectionSaved => 'محفوظ شدہ';

  @override
  String get quranFromTheQuran => 'قرآن سے';

  @override
  String get quranNoSavedVerses => 'ابھی کوئی محفوظ آیت نہیں';

  @override
  String get quranNoSavedVersesBody =>
      'پڑھنے کے دوران کسی آیت پر ٹیپ کریں تاکہ وہ یہاں رہے۔';

  @override
  String get libraryNextChapter => 'اگلا باب';

  @override
  String get libraryPreviousChapter => 'پچھلا باب';

  @override
  String get libraryNextPage => 'اگلا صفحہ';

  @override
  String get libraryPreviousPage => 'پچھلا صفحہ';

  @override
  String libraryNextChapterNamed(String chapter) {
    return 'اگلا باب: $chapter';
  }

  @override
  String libraryPreviousChapterNamed(String chapter) {
    return 'پچھلا باب: $chapter';
  }

  @override
  String libraryNextShort(String chapter) {
    return 'اگلا: $chapter';
  }

  @override
  String libraryPreviousShort(String chapter) {
    return 'پچھلا: $chapter';
  }

  @override
  String get libraryShareChapter => 'باب شیئر کریں';

  @override
  String get libraryChapterUnavailable => 'باب دستیاب نہیں';

  @override
  String get libraryDecreaseFont => 'فونٹ سائز کم کریں';

  @override
  String get libraryIncreaseFont => 'فونٹ سائز بڑھائیں';

  @override
  String get azaanTakbirName => 'صرف تکبیر';

  @override
  String get azaanTakbirDescription => 'چھوٹی تکبیر اطلاعی آواز';

  @override
  String get azaanFullName => 'مکمل اذان';

  @override
  String get azaanFullDescription => 'مکمل اذان، خود بخود چلتی ہے';

  @override
  String get azaanFullIosDescription =>
      'اطلاع تکبیر چلاتی ہے؛ مکمل اذان سننے کے لیے اس پر ٹیپ کریں';

  @override
  String get azaanSystemDefaultName => 'سسٹم ڈیفالٹ';

  @override
  String get azaanSystemDefaultDescription =>
      'اپنے آلے کی ڈیفالٹ اطلاعی آواز استعمال کریں';

  @override
  String get azaanSilentName => 'خاموش';

  @override
  String get azaanSilentDescription => 'صرف اطلاعی بینر (کوئی آواز نہیں)';

  @override
  String get azaanCustomName => 'حسب منشا آڈیو';

  @override
  String get azaanCustomDescription => 'اپنے آلے سے کوئی آڈیو فائل منتخب کریں';

  @override
  String get ratingEnjoying => 'Shia Companion پسند آ رہا ہے؟';

  @override
  String get ratingEnjoyingBody =>
      'ہم سننا چاہیں گے کہ آپ کے لیے یہ کیسا چل رہا ہے — آپ کے تاثرات ہمیں ایپ کو بہتر بناتے رہنے میں مدد دیتے ہیں۔';

  @override
  String get ratingNotReally => 'واقعی نہیں';

  @override
  String get ratingYes => 'جی ہاں!';

  @override
  String get ratingSorry => 'یہ سن کر افسوس ہوا';

  @override
  String get ratingSorryBody =>
      'کیا آپ ہمیں بتائیں گے کہ کیا کام نہیں کر رہا؟ یہ ہمیں ایپ بہتر بنانے میں مدد دیتا ہے۔';

  @override
  String get ratingNoThanks => 'نہیں، شکریہ';

  @override
  String get ratingSendFeedback => 'تاثرات بھیجیں';

  @override
  String get azaanOptInIntro =>
      'Shia Companion آپ کو فجر، ظہر اور مغرب پر اطلاع بھیج سکتا ہے اور اذان چلا سکتا ہے۔';

  @override
  String get azaanOptInIosNote =>
      'iPhone پر اطلاع ایک مختصر تکبیر چلاتی ہے۔ اس پر ٹیپ کرنے پر مکمل اذان سننے کے لیے ترتیبات میں مکمل اذان منتخب کریں۔';

  @override
  String get azaanOptInChangeLater =>
      'آپ کسی بھی وقت ترتیبات میں بدل سکتے ہیں کہ کون سی نمازیں آپ کو اطلاع دیں، کوئی اور آواز منتخب کر سکتے ہیں، یا اسے دوبارہ آف کر سکتے ہیں۔';

  @override
  String get azaanOptInTitle => 'نماز کے اوقات پر اذان چلائیں؟';

  @override
  String get azaanOptInNotNow => 'ابھی نہیں';

  @override
  String get azaanOptInEnable => 'اذان فعال کریں';

  @override
  String reminderRemoveBody(String title) {
    return 'یہ \"$title\" کی یاد دہانی ہٹا دیتا ہے۔ آپ اسے کسی بھی وقت دوبارہ شامل کر سکتے ہیں۔';
  }

  @override
  String get reminderRemoveTitle => 'یاد دہانی ہٹائیں؟';

  @override
  String get reminderAddTooltip => 'یاد دہانی شامل کریں';

  @override
  String get reminderNone => 'ابھی کوئی یاد دہانی نہیں';

  @override
  String get reminderNoneBody =>
      'اپنی پسند کے دنوں میں کسی ذکر یا دعا کی یاد دہانی کے لیے + پر ٹیپ کریں — جیسے ہر منگل توسل، یا جمعرات کو مغرب کے بعد دعائے کمیل۔';

  @override
  String tasbeehBeepNumber(int number) {
    return 'بیپ $number';
  }

  @override
  String get tasbeehHelp =>
      'گننے کے لیے کاؤنٹر کے دایرے پر ٹیپ کریں۔ نیچے دیے گئے مراحل پر بیپ بجے گی۔';

  @override
  String get tasbeehEnableBeep => 'بیپ فعال کریں';

  @override
  String get tasbeehTapToCount => 'گننے کے لیے ٹیپ کریں';

  @override
  String get tasbeehMinusOne => 'ایک کم کریں';

  @override
  String get tasbeehReset => 'ری سیٹ کریں';

  @override
  String get requestThanks => 'شکریہ — ہمیں آپ کی درخواست موصول ہو گئی ہے۔';

  @override
  String get requestFailed =>
      'درخواست بھیجی نہیں جا سکی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get requestBookTitle => 'کتاب کا عنوان';

  @override
  String get requestZikrName => 'دعا، زیارت وغیرہ کا نام';

  @override
  String get requestBookDetails => 'مصنف، مترجم یا لنک (اختیاری)';

  @override
  String get requestZikrDetails => 'ماخذ، موقع یا لنک (اختیاری)';

  @override
  String get commonSend => 'بھیجیں';

  @override
  String searchOneMatch(String source) {
    return '$source میں 1 مماثلت';
  }

  @override
  String searchMatches(int count, String source) {
    return '$source میں $count مماثلتیں';
  }

  @override
  String get searchSourceZikr => 'ذکر';

  @override
  String get searchSourceQuran => 'قرآن';

  @override
  String get searchSourceLibrary => 'لائبریری';

  @override
  String get searchTitleOrUid => 'عنوان یا UID تلاش کریں';

  @override
  String get searchShow => 'دکھائیں';

  @override
  String get searchNoResults => 'کوئی نتیجہ نہیں';

  @override
  String get searchRequestIt => 'اس کی درخواست کریں';

  @override
  String widgetPrayerTimesHelp(int min, int max) {
    return '$min سے $max اوقات منتخب کریں۔ طلوع آفتاب، غروب آفتاب اور آدھی رات وہ آخری حدیں ہیں جن سے پہلے نماز ادا کرنی ہوتی ہے۔';
  }

  @override
  String get accountSessionExpired =>
      'آپ کا سیشن ختم ہو گیا۔ براہ کرم دوبارہ سائن ان کریں اور حذف دوبارہ آزمائیں۔';

  @override
  String get accountReauthenticate =>
      'حفاظت کے لیے، براہ کرم دوبارہ سائن ان کریں اور پھر اپنا اکاؤنٹ حذف کرنا دوبارہ آزمائیں۔';

  @override
  String get accountPopupClosed =>
      'عمل مکمل ہونے سے پہلے سائن ان ونڈو بند ہو گئی۔';

  @override
  String get accountNetworkError =>
      'نیٹ ورک خرابی۔ براہ کرم اپنا کنکشن چیک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get commonSomethingWentWrong =>
      'کچھ غلط ہو گیا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String zikrTabNumber(int number) {
    return 'ٹیب $number';
  }

  @override
  String get zikrBookmarked => 'بک مارک شدہ';

  @override
  String get zikrMoveBookmarkHere => 'بک مارک یہاں منتقل کریں';

  @override
  String get zikrDragBookmarkHint =>
      'بک مارک کو دوسری سطر پر منتقل کرنے کے لیے گھسیٹیں';

  @override
  String get durationUnderOneMinute => '1 منٹ سے کم';

  @override
  String durationMinutes(int minutes) {
    return '$minutes منٹ';
  }

  @override
  String durationHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours گھنٹے',
      one: 'ایک گھنٹہ',
    );
    return '$_temp0';
  }

  @override
  String durationHoursMinutes(String hours, int minutes) {
    return '$hours گھنٹے $minutes منٹ';
  }

  @override
  String zikrReadingTime(String duration) {
    return '$duration مطالعہ';
  }

  @override
  String get zikrProgressCompleted => 'مکمل';

  @override
  String airportNothingMatched(String query) {
    return '\"$query\" سے کچھ مماثل نہیں۔ اس کے بجائے تین حرفی کوڈ آزمائیں۔';
  }

  @override
  String get airportSearchLabel => 'ہوائی اڈے کا کوڈ یا شہر';

  @override
  String get airportSearchHint => 'مثلاً SFO، استنبول، نجف';

  @override
  String get airportSearchTitle => 'ہوائی اڈا تلاش کریں';

  @override
  String get airportSearchDetail =>
      'ہوائی اڈے کا کوڈ، شہر، یا ملک کا نام لکھیں۔';

  @override
  String get airportNoneFound => 'کوئی ہوائی اڈا نہیں ملا';

  @override
  String get counterTapAnywhere => 'گننے کے لیے کہیں بھی ٹیپ کریں';

  @override
  String get counterHoldToMove => 'منتقل کرنے کے لیے دبا کر گھسیٹیں';

  @override
  String get counterAddOne => 'ایک شامل کریں';

  @override
  String azanPaused(String prayer) {
    return '$prayer کی اذان رکی ہوئی ہے';
  }

  @override
  String get azanPrayerFallback => 'نماز';

  @override
  String get reminderChannelDescription =>
      'آپ کی طے کردہ اذکار اور دعاؤں کی یاد دہانیاں';

  @override
  String get locationOff => 'مقام کی خدمات آف ہیں';

  @override
  String get locationPermissionShort => 'مقام کی اجازت درکار ہے';

  @override
  String get locationNoFix => 'مقام کا فکس حاصل نہیں ہو سکا';

  @override
  String get locationUpdateFailed => 'مقام اپ ڈیٹ نہیں ہو سکا';

  @override
  String quranPreviousUnit(String unit) {
    return 'پچھلا $unit';
  }

  @override
  String quranNextUnit(String unit) {
    return 'اگلا $unit';
  }

  @override
  String get quranUnitSurah => 'سورہ';

  @override
  String hadithNoResults(String query) {
    return '\"$query\" کے لیے کوئی نتیجہ نہیں ملا';
  }

  @override
  String get hadithTitle => 'حدیث';

  @override
  String get hadithSearchHint => 'حدیث تلاش کریں...';

  @override
  String get hadithNone => 'کوئی حدیث دستیاب نہیں';

  @override
  String favoritesReorder(String title) {
    return '$title دوبارہ ترتیب دیں';
  }

  @override
  String get favoritesReorderFailed =>
      'نئی ترتیب محفوظ نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get favoritesNone => 'ابھی کوئی پسندیدہ نہیں۔';

  @override
  String linkNotFoundRequested(String link) {
    return 'درخواست کردہ لنک: $link';
  }

  @override
  String get linkNotFoundTitle => 'لنک نہیں ملا';

  @override
  String get linkNotFoundBody => 'ہم یہ مواد تلاش نہیں کر سکے۔';

  @override
  String get linkNotFoundGoHome => 'ہوم جائیں';

  @override
  String get whatsNewTitle => 'نیا کیا ہے';

  @override
  String get whatsNewGotIt => 'سمجھ گیا';

  @override
  String get pickerChooseZikr => 'ذکر یا دعا منتخب کریں';

  @override
  String get pickerSearchZikrHint => 'ذکر، دعا، زیارت تلاش کریں...';

  @override
  String get pickerNoMatches => 'کوئی مماثلت نہیں ملی۔';

  @override
  String get todaysNone => 'کوئی تلاوت ترتیب شدہ نہیں۔';

  @override
  String get scheduledFallbackTitle => 'طے شدہ اطلاع';

  @override
  String get scheduledNone => 'کوئی طے شدہ اطلاع نہیں۔';

  @override
  String newsLoadFailed(String error) {
    return 'خبریں لوڈ ہونے میں ناکامی: $error';
  }

  @override
  String get newsNoBrowser => 'کوئی ویب براؤزر نہیں ملا';

  @override
  String get actionSaved => 'محفوظ شدہ';

  @override
  String get actionBookmark => 'بک مارک';

  @override
  String get actionShare => 'شیئر';

  @override
  String get actionListen => 'سنیں';

  @override
  String get actionSettings => 'ترتیبات';

  @override
  String get actionCounter => 'کاؤنٹر';

  @override
  String get prayerEnableLocationBody =>
      'اپنے علاقے کے درست نماز اوقات دکھانے کے لیے مقام فعال کریں۔';

  @override
  String statsDayRead(String day) {
    return '$day: پڑھا گیا';
  }

  @override
  String statsDayNotRead(String day) {
    return '$day: نہیں پڑھا گیا';
  }

  @override
  String get qiblaDistance => 'فاصلہ';

  @override
  String get qiblaDirection => 'سمت';

  @override
  String get qiblaYouFace => 'آپ کا رخ ہے';

  @override
  String pickerAyahLabel(int ayah) {
    return 'آیت $ayah';
  }

  @override
  String hadithSharedVia(String link) {
    return 'Shia Companion کے ذریعے شیئر شدہ - $link';
  }

  @override
  String get requestTypeZikr => 'ذکر';

  @override
  String get requestTypeBook => 'کتاب';
}
