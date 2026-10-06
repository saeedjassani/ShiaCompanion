// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'Shia Companion';

  @override
  String get settingsAppLanguage => 'زبان برنامه';

  @override
  String get settingsTranslationLanguage => 'زبان ترجمه';

  @override
  String languageFollowDevice(String language) {
    return 'زبان دستگاه ($language)';
  }

  @override
  String languageFollowApp(String language) {
    return 'همانند برنامه ($language)';
  }

  @override
  String settingsDownloadedRecitationsUsed(String size) {
    return '$size در این دستگاه استفاده شده است';
  }

  @override
  String settingsHijriAhead(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days روز جلوتر',
      one: 'یک روز جلوتر',
    );
    return '$_temp0';
  }

  @override
  String settingsHijriBehind(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days روز عقب‌تر',
      one: 'یک روز عقب‌تر',
    );
    return '$_temp0';
  }

  @override
  String settingsLocationFailed(String message) {
    return '$message. برای تلاش دوباره ضربه بزنید.';
  }

  @override
  String settingsLocationSaved(String city) {
    return 'مکان ذخیره‌شدهٔ فعلی: $city.';
  }

  @override
  String settingsLocationUpdated(String city, String age) {
    return '$city · $age پیش به‌روز شد. هنگام جابه‌جایی خودش تازه‌سازی می‌شود.';
  }

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes دقیقه پیش';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours ساعت پیش';
  }

  @override
  String timeDaysAgo(int days) {
    return '$days روز پیش';
  }

  @override
  String settingsAdjustHijriBy(int days) {
    return 'تنظیم تاریخ هجری به اندازهٔ $days روز';
  }

  @override
  String settingsPrayerTimesShownSubtitle(String names) {
    return 'در صفحهٔ اصلی و ویجت‌های صفحهٔ اصلی نشان داده می‌شود: $names.';
  }

  @override
  String settingsPrayerNotificationsAllOn(int count) {
    return 'برای هر $count وقت روشن است.';
  }

  @override
  String settingsPrayerNotificationsSomeOn(
      String names, int enabled, int total) {
    return '$names · $enabled از $total روشن';
  }

  @override
  String get settingsSectionPrayerLocation => 'نماز و مکان';

  @override
  String get settingsAdjustHijriDate => 'تنظیم تاریخ هجری';

  @override
  String get settingsPrayerTimesShown => 'اوقات نماز نمایش‌داده‌شده';

  @override
  String get settingsRefreshLocation => 'تازه‌سازی مکان';

  @override
  String get settingsLocationRefreshed => 'مکان تازه‌سازی شد.';

  @override
  String get settingsSectionNotifications => 'اعلان‌ها';

  @override
  String get settingsPrayerNotifications => 'اعلان‌های نماز';

  @override
  String get settingsZikrReminders => 'یادآورهای ذکر';

  @override
  String get settingsZikrRemindersSubtitle =>
      'در روزهایی که انتخاب می‌کنید، برای یک ذکر یادآوری بگیرید.';

  @override
  String get settingsPrecisePrayerAlarms => 'هشدارهای دقیق نماز';

  @override
  String get settingsScheduledNotifications => 'اعلان‌های زمان‌بندی‌شده';

  @override
  String get settingsScheduledNotificationsSubtitle =>
      'اعلان‌های نماز در انتظار را بررسی کنید.';

  @override
  String get settingsSectionAppearance => 'ظاهر';

  @override
  String get settingsDarkMode => 'حالت تاریک';

  @override
  String get settingsDarkModeSubtitle =>
      'از ظاهر تاریک در سراسر برنامه استفاده کنید.';

  @override
  String get settingsAppTextSize => 'اندازهٔ متن برنامه';

  @override
  String get settingsAppTextSizeSubtitle =>
      'همهٔ متن‌ها، از جمله ذکر، را بزرگ‌تر یا کوچک‌تر می‌کند.';

  @override
  String get settingsSectionZikrReading => 'خواندن و اشتراک‌گذاری ذکر';

  @override
  String get settingsSectionOfflineAudio => 'صدای آفلاین';

  @override
  String get settingsDownloadedRecitations => 'تلاوت‌های دانلودشده';

  @override
  String get settingsDownloadedRecitationsEmpty => 'بدون اتصال گوش دهید';

  @override
  String get settingsSectionSupport => 'پشتیبانی';

  @override
  String get settingsRateApp => 'به Shia Companion امتیاز دهید';

  @override
  String get settingsRateAppSubtitle =>
      'از برنامه لذت می‌برید؟ به ما امتیاز دهید.';

  @override
  String get settingsRequestContent => 'درخواست ذکر یا کتاب';

  @override
  String get settingsRequestContentSubtitle =>
      'دعا، زیارت یا کتابی را پیدا نمی‌کنید؟ از ما بخواهید اضافه‌اش کنیم.';

  @override
  String get settingsFeedback => 'بازخورد';

  @override
  String get settingsFeedbackSubtitle =>
      'پرسش‌ها، مشکلات یا پیشنهادها را بفرستید.';

  @override
  String get settingsGithub => 'در GitHub مشارکت کنید';

  @override
  String get settingsGithubSubtitle =>
      'Shia Companion متن‌باز است. مشکلات را گزارش دهید یا در بهبودش کمک کنید.';

  @override
  String get settingsGithubOpenFailed => 'باز کردن GitHub ممکن نشد';

  @override
  String get settingsAboutUs => 'دربارهٔ ما';

  @override
  String get settingsSectionAccount => 'حساب';

  @override
  String get settingsNotSignedIn => 'وارد نشده‌اید';

  @override
  String get settingsSignInPrompt =>
      'وارد شوید تا علاقه‌مندی‌ها در دستگاه‌ها همگام شود.';

  @override
  String get settingsLogout => 'خروج';

  @override
  String get settingsLogoutSubtitle => 'در این دستگاه از حساب خارج شوید.';

  @override
  String get settingsDeleteAccount => 'حذف حساب من';

  @override
  String get settingsDeleteAccountSubtitle =>
      'داده‌های حسابتان را برای همیشه حذف کنید.';

  @override
  String get settingsSignInGoogle => 'ورود با Google';

  @override
  String get settingsSignInGoogleSubtitle =>
      'علاقه‌مندی‌ها و داده‌های حساب را همگام کنید.';

  @override
  String get settingsSignInApple => 'ورود با Apple';

  @override
  String get settingsSignInAppleSubtitle => 'با Apple ID خود وارد شوید.';

  @override
  String get settingsSignedIn => 'وارد شده‌اید';

  @override
  String get settingsSyncing =>
      'علاقه‌مندی‌ها و داده‌های حساب در حال همگام‌سازی است.';

  @override
  String get settingsHijriNoAdjustment => 'بدون تنظیم';

  @override
  String get settingsLocationUpdating => 'در حال به‌روزرسانی مکان شما…';

  @override
  String get settingsLocationUpdatePrompt =>
      'مکان ذخیره‌شدهٔ اوقات نماز را به‌روز کنید.';

  @override
  String get timeJustNow => 'همین حالا';

  @override
  String get settingsPrayerNotificationsOff =>
      'خاموش. روشن کنید تا در اوقات نماز باخبر شوید.';

  @override
  String get settingsPreciseAlarmsOn => 'برای زمان‌بندی دقیق اذان فعال است.';

  @override
  String get settingsPreciseAlarmsOff =>
      'خاموش. اندروید ممکن است اعلان‌های نماز را کمی دیر برساند.';

  @override
  String get settingsNotificationsUnavailable =>
      'سامانهٔ اعلان راه‌اندازی نشده است';

  @override
  String get settingsPreciseAlarmsAlreadyOn =>
      'هشدارهای دقیق نماز از پیش فعال است.';

  @override
  String get settingsPreciseAlarmsDialogTitle => 'هشدارهای دقیق نماز فعال شود؟';

  @override
  String get settingsPreciseAlarmsDialogBody =>
      'اندروید برای اینکه اعلان‌های اذان دقیقاً سر وقت نماز اجرا شوند، به دسترسی «هشدارها و یادآورها» نیاز دارد. بدون آن، یادآورها همچنان کار می‌کنند اما ممکن است کمی دیر برسند.';

  @override
  String get commonCancel => 'لغو';

  @override
  String get commonOpenSettings => 'باز کردن تنظیمات';

  @override
  String get settingsPreciseAlarmsEnabled => 'هشدارهای دقیق نماز فعال شد.';

  @override
  String get settingsPreciseAlarmsNotEnabled =>
      'هشدارهای دقیق نماز فعال نشد. زمان‌بندی تقریبی همچنان استفاده می‌شود.';

  @override
  String get settingsNoEmailApp => 'برنامهٔ ایمیلی یافت نشد';

  @override
  String get settingsLoginSuccessful => 'ورود موفق بود';

  @override
  String get settingsGoogleUnavailable =>
      'ورود با Google در حال حاضر در دسترس نیست. لطفاً دوباره تلاش کنید.';

  @override
  String get commonNetworkError =>
      'اتصال ممکن نشد. اتصال اینترنت خود را بررسی و دوباره تلاش کنید.';

  @override
  String get settingsGoogleFailed =>
      'ورود با Google انجام نشد. لطفاً چند لحظهٔ دیگر دوباره تلاش کنید.';

  @override
  String get settingsAppleFailed => 'ورود با Apple ناموفق بود';

  @override
  String audioRecordingNumber(int number) {
    return 'ضبط $number';
  }

  @override
  String playlistAddedTo(String name) {
    return 'به $name افزوده شد';
  }

  @override
  String playlistAlreadyIn(String name) {
    return 'از پیش در $name هست';
  }

  @override
  String zikrCount(int count) {
    return '$count ذکر';
  }

  @override
  String get playlistsEmpty =>
      'از ذکرهایی که هر روز گوش می‌دهید فهرست پخش بسازید — مثلاً دعای عهد و زیارت عاشورا هر صبح — و همه را با یک ضربه شروع کنید.';

  @override
  String playlistDeleteConfirm(String name) {
    return '«$name» حذف شود؟';
  }

  @override
  String get playlistDeleteKeepsDuasAndAudio =>
      'خود دعاها در برنامه می‌مانند و صدای دانلودشده‌شان هم همین‌طور — برای آزاد کردن فضا آن‌ها را از دانلودها حذف کنید.';

  @override
  String get playlistEmpty =>
      'برای انتخاب ذکر، روی «افزودن» ضربه بزنید. از پخش‌کنندهٔ هر دعای دارای صدا هم می‌توانید بیفزایید.';

  @override
  String audioRecordingsChosen(int chosen, int total) {
    return '$chosen از $total ضبط';
  }

  @override
  String audioDownloadingPercent(int percent) {
    return 'در حال دانلود $percent%';
  }

  @override
  String audioRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ضبط',
      one: 'یک ضبط',
    );
    return '$_temp0';
  }

  @override
  String playlistNowPlayingPosition(String playlist, int position, int count) {
    return '$playlist · $position از $count';
  }

  @override
  String get playlistNameHint => 'مثلاً صبح';

  @override
  String get playlistOfflinePartial =>
      'آفلاین هستید — فقط ضبط‌های دانلودشده پخش می‌شود';

  @override
  String get playlistNothingToPlay =>
      'هیچ‌چیز در این فهرست پخش، ضبطی برای پخش ندارد';

  @override
  String get playlistOfflineNothingDownloaded =>
      'آفلاین هستید و هنوز هیچ‌چیز از این فهرست پخش دانلود نشده است';

  @override
  String get playlistStartFailed =>
      'شروع فهرست پخش ممکن نشد. دوباره تلاش کنید.';

  @override
  String get playlistChooseRecordingsHint =>
      'ضبط‌هایی را که در این فهرست پخش پخش می‌شوند انتخاب کنید';

  @override
  String get commonDone => 'انجام شد';

  @override
  String get playlistAddTo => 'افزودن به فهرست پخش';

  @override
  String get playlistNew => 'فهرست پخش جدید';

  @override
  String get commonCreate => 'ساختن';

  @override
  String get playlistsTitle => 'فهرست‌های پخش';

  @override
  String get playlistDownloads => 'دانلودها';

  @override
  String get commonPause => 'مکث';

  @override
  String get commonPlay => 'پخش';

  @override
  String get playlistRename => 'تغییر نام فهرست پخش';

  @override
  String get commonSave => 'ذخیره';

  @override
  String get playlistDeleteKeepsDuas => 'خود دعاها در برنامه می‌مانند.';

  @override
  String get commonDelete => 'حذف';

  @override
  String get playlistDeleted => 'این فهرست پخش حذف شد.';

  @override
  String get commonRename => 'تغییر نام';

  @override
  String get playlistRemoveDownloads => 'حذف دانلودها';

  @override
  String get playlistAllDownloads => 'همهٔ دانلودها';

  @override
  String get commonAdd => 'افزودن';

  @override
  String get playlistResume => 'ادامه';

  @override
  String get playlistPlayAll => 'پخش همه';

  @override
  String get audioDownloaded => 'دانلود شد';

  @override
  String get audioDownloadFailed => 'دانلود کامل نشد';

  @override
  String get playlistOpenText => 'باز کردن متن';

  @override
  String get playlistChooseRecordings => 'انتخاب ضبط‌ها';

  @override
  String get audioStopDownloading => 'توقف دانلود';

  @override
  String get audioRemoveDownload => 'حذف دانلود';

  @override
  String get audioDownload => 'دانلود';

  @override
  String get playlistRemoveZikr => 'حذف از فهرست پخش';

  @override
  String get playlistAddZikr => 'افزودن ذکر';

  @override
  String get commonSearch => 'جستجو';

  @override
  String get audioPartlyDownloaded => 'تا حدی دانلود شده';

  @override
  String get playlistRepeatOn => 'تکرار روشن است';

  @override
  String get playlistRepeat => 'تکرار فهرست پخش';

  @override
  String get commonPrevious => 'قبلی';

  @override
  String get commonNext => 'بعدی';

  @override
  String get commonStop => 'توقف';

  @override
  String flightTimesShownAt(String origin, String destination) {
    return 'ساعت‌ها بر اساس ساعت محلی $origin و $destination نشان داده می‌شود';
  }

  @override
  String flightDurationAndDistance(String duration, String distance) {
    return '$duration در هوا · $distance روی کوتاه‌ترین مسیر';
  }

  @override
  String flightAirportTime(String airport) {
    return 'ساعت $airport';
  }

  @override
  String flightOverPosition(String position) {
    return ' · بر فراز $position';
  }

  @override
  String flightAfterTakeoff(String duration) {
    return '$duration پس از برخاستن';
  }

  @override
  String flightHorizonLater(int minutes) {
    return '$minutes دقیقه دیرتر از افق سطح زمین';
  }

  @override
  String flightHorizonEarlier(int minutes) {
    return '$minutes دقیقه زودتر از افق سطح زمین';
  }

  @override
  String flightQiblaToRight(int degrees) {
    return '$degrees° به سمت راست شما';
  }

  @override
  String flightQiblaToLeft(int degrees) {
    return '$degrees° به سمت چپ شما';
  }

  @override
  String flightQiblaLine(int bearing, String compass, String relative) {
    return 'قبله $bearing° ($compass) — $relative نسبت به جهت پرواز';
  }

  @override
  String flightAltitudeHorizonBody(String altitude, String dip) {
    return 'در ارتفاع $altitude افق حدود $dip° پایین‌تر از روی زمین قرار می‌گیرد، پس خورشید دیرتر غروب می‌کند و سپیده زودتر می‌دمد. این یعنی مغرب و عشا حدود بیست دقیقه دیرتر و فجر حدود بیست دقیقه زودتر از اوقات زمین زیر شما می‌شود — هر ردیف تغییر خودش را نشان می‌دهد. اینکه کدام افق ملاک نماز است، پرسشی برای مرجع تقلید شماست و این برنامه نمی‌تواند آن را تعیین کند.';
  }

  @override
  String flightAltitudeFeet(String feet) {
    return '$feet فوت';
  }

  @override
  String get flightTitleFallback => 'پرواز';

  @override
  String get flightEdit => 'ویرایش پرواز';

  @override
  String get flightCheckTimes => 'ساعت‌های پرواز را بررسی کنید';

  @override
  String get flightCheckTimesBody =>
      'پس از اعمال منطقهٔ زمانی هر فرودگاه، رسیدن بعد از حرکت نیست. برای اصلاح تاریخ‌ها روی ویرایش ضربه بزنید.';

  @override
  String get flightInTheAir => 'در حال پرواز';

  @override
  String get flightNoPrayerDuring => 'در این پرواز هیچ نمازی فرا نمی‌رسد';

  @override
  String get flightNoPrayerDuringBody =>
      'همهٔ اوقات نماز یا پیش از برخاستن است یا پس از فرود.';

  @override
  String get flightNotDuring => 'در این پرواز نیست';

  @override
  String get flightEndOfIshaWindow => 'پایان بازهٔ عشا · ';

  @override
  String get flightStraightAhead => 'دقیقاً روبه‌رو';

  @override
  String get flightDirectlyBehind => 'دقیقاً پشت سر شما';

  @override
  String get flightIshaClosedBeforeTakeoff =>
      'بازهٔ عشا پیش از برخاستن بسته شده بود.';

  @override
  String get flightAlreadyInBeforeTakeoff =>
      'پیش از برخاستن فرا رسیده — از اوقات نماز شهر حرکت خود استفاده کنید.';

  @override
  String get flightIshaOpenUntilLanding =>
      'بازهٔ عشا تا پس از فرود بسته نمی‌شود.';

  @override
  String get flightAfterLanding =>
      'پس از فرود فرا می‌رسد — از اوقات نماز شهر مقصد استفاده کنید.';

  @override
  String get flightSunAngleNeverReached =>
      'خورشید در هیچ نقطه‌ای از این مسیر به زاویهٔ لازم نمی‌رسد، پس وقتی قابل محاسبه نیست.';

  @override
  String get flightHowWorkedOut => 'این اوقات چگونه محاسبه می‌شوند';

  @override
  String get flightHowWorkedOutBody =>
      'فرض می‌شود هواپیما مسیر دایرهٔ عظیمه را با سرعت ثابت می‌پیماید و هر وقت نماز برای موقعیتی حل می‌شود که هواپیما هنگام رسیدن آن وقت در آنجاست. یک ساعت تأخیر این اوقات را حدود نیم ساعت جابه‌جا می‌کند و تغییر مسیر به دلیل آب‌وهوا می‌تواند ده تا بیست دقیقه جابه‌جایشان کند، پس آن‌ها را نزدیک بدانید نه دقیق.';

  @override
  String get flightHorizonAtAltitude => 'اندازه‌گیری‌شده از افق در ارتفاع';

  @override
  String get flightHorizonAtGround => 'اندازه‌گیری‌شده از افق در سطح زمین';

  @override
  String get flightGroundHorizonBody =>
      'اوقات از افق زمین زیر هواپیما پیروی می‌کنند. از کابین، خورشید دیرتر غروب می‌کند و سپیده زودتر از آنچه نشان داده شده می‌دمد؛ در ارتفاع پروازی حدود بیست دقیقه.';

  @override
  String get flightHighLatitude => 'این مسیر از عرض‌های جغرافیایی بالا می‌گذرد';

  @override
  String get flightHighLatitudeBody =>
      'بالای حدود ۴۸°، خورشید ممکن است به اندازهٔ کافی زیر افق نرود تا سپیده‌دم و شب به‌طور عادی رخ دهند. اوقات فجر، مغرب و عشا در آنجا به برآوردی تناسبی از شب برمی‌گردد. احکام نماز در عرض‌های بالا متفاوت است — لطفاً از مرجع تقلید خود پیروی کنید.';

  @override
  String get flightSomeNotCalculated => 'برخی اوقات نماز قابل محاسبه نبود';

  @override
  String get flightSomeNotCalculatedBody =>
      'خورشید در سراسر مسیر بالای زاویهٔ لازم می‌ماند، پس آن نمازها وقت محاسبه‌شده‌ای ندارند. لطفاً برای این شرایط از حکم مرجع تقلید خود پیروی کنید.';

  @override
  String get flightTimeZonesFailed => 'منطقه‌های زمانی بارگیری نشدند';

  @override
  String get flightTimeZonesFailedBody =>
      'یکی از این فرودگاه‌ها منطقهٔ زمانی‌ای دارد که این نسخه نمی‌شناسد. برای انتخاب دوبارهٔ فرودگاه‌ها روی ویرایش ضربه بزنید.';

  @override
  String get prayerFajr => 'فجر';

  @override
  String get prayerSunrise => 'طلوع آفتاب';

  @override
  String get prayerZuhr => 'ظهر';

  @override
  String get prayerAsr => 'عصر';

  @override
  String get prayerSunset => 'غروب آفتاب';

  @override
  String get prayerMaghrib => 'مغرب';

  @override
  String get prayerIsha => 'عشا';

  @override
  String get prayerMidnight => 'نیمه‌شب';

  @override
  String locationErrorBody(String error) {
    return 'هنگام دریافت مکان شما خطایی رخ داد: $error\n\nلطفاً بررسی کنید که خدمات مکان فعال باشد و دوباره تلاش کنید.';
  }

  @override
  String notificationReopenAppBody(int days) {
    return 'به نظر می‌رسد در $days روز گذشته از برنامه استفاده نکرده‌اید. لطفاً برنامه را باز کنید تا اعلان‌های اذان را همچنان دریافت کنید';
  }

  @override
  String notificationPrayerTime(String prayer) {
    return 'وقت $prayer است';
  }

  @override
  String notificationTapToPlayCustom(String message) {
    return '$message · برای پخش صدای خود ضربه بزنید';
  }

  @override
  String notificationTapToPlayAzan(String message) {
    return '$message · برای شنیدن اذان کامل ضربه بزنید';
  }

  @override
  String get locationEnableTitle => 'فعال کردن مکان برای اوقات نماز';

  @override
  String get locationEnableBody =>
      'اوقات نماز به مکان شما بستگی دارد. وقتی از برنامه استفاده می‌کنید از مکانتان استفاده می‌کنیم تا اوقات نماز دقیق منطقهٔ شما را ارائه دهیم.';

  @override
  String get commonContinue => 'ادامه';

  @override
  String get locationServicesDisabledTitle => 'خدمات مکان خاموش است';

  @override
  String get locationServicesDisabledBody =>
      'خدمات مکان خاموش است. لطفاً خدمات مکان را در تنظیمات دستگاه فعال کنید تا اوقات نماز دقیق منطقهٔ شما را بگیرید.';

  @override
  String get locationPermissionDeniedForever =>
      'اجازهٔ مکان برای همیشه رد شد. لطفاً تنظیمات برنامه را باز کنید و اجازهٔ مکان بدهید تا اوقات نماز دقیق بگیرید.';

  @override
  String get locationPermissionUnknown =>
      'وضعیت اجازهٔ مکان مشخص نشد. لطفاً تنظیمات برنامه را باز کنید و مطمئن شوید اجازهٔ مکان داده شده است.';

  @override
  String get locationPermissionNeeded =>
      'برای نمایش اوقات نماز دقیق منطقهٔ شما، اجازهٔ مکان لازم است.';

  @override
  String get locationPermissionTitle => 'اجازهٔ مکان لازم است';

  @override
  String get locationTimeoutTitle => 'پایان مهلت مکان‌یابی';

  @override
  String get locationTimeoutBody =>
      'در زمان مورد انتظار مکان شما به دست نیامد. ممکن است به دلیل سیگنال ضعیف GPS یا مشکلات شبکه باشد. لطفاً دوباره تلاش کنید.';

  @override
  String get locationErrorTitle => 'خطای مکان';

  @override
  String get notificationReopenAppTitle =>
      'برنامه را باز کنید تا اعلان‌های اذان را همچنان بگیرید';

  @override
  String get notificationChannelTakbir => 'اوقات نماز - تکبیر';

  @override
  String get notificationChannelSystemDefault => 'اوقات نماز - پیش‌فرض سیستم';

  @override
  String get notificationChannelSilent => 'اوقات نماز - بی‌صدا';

  @override
  String get notificationChannelCustom => 'اوقات نماز - صدای سفارشی';

  @override
  String get notificationChannelFullAzan => 'اوقات نماز - اذان کامل';

  @override
  String get notificationChannelSilentDescription =>
      'اعلان‌های بی‌صدای اوقات نماز';

  @override
  String get notificationChannelDescription => 'اعلان‌های اوقات نماز';

  @override
  String get notificationChannelGeneral => 'عمومی';

  @override
  String qiblaNeedsCalibratingBody(int degrees) {
    return 'اندازه‌گیری‌ها حدود $degrees° خطا دارد. گوشی را چند بار به شکل هشت حرکت دهید، دور از هر چیز فلزی یا مغناطیسی.';
  }

  @override
  String qiblaBearingFromNorth(String place, String bearing) {
    return '$place در $bearing از شمال حقیقی است';
  }

  @override
  String qiblaFacing(String place) {
    return 'رو به $place';
  }

  @override
  String qiblaTurnRight(int degrees) {
    return '$degrees° به راست بچرخید';
  }

  @override
  String qiblaTurnLeft(int degrees) {
    return '$degrees° به چپ بچرخید';
  }

  @override
  String qiblaDeclinationEast(String degrees) {
    return 'شمال مغناطیسی در محل شما $degrees° شرق شمال حقیقی است و اندازه‌گیری به‌طور خودکار برای آن اصلاح می‌شود.';
  }

  @override
  String qiblaDeclinationWest(String degrees) {
    return 'شمال مغناطیسی در محل شما $degrees° غرب شمال حقیقی است و اندازه‌گیری به‌طور خودکار برای آن اصلاح می‌شود.';
  }

  @override
  String get qiblaDistanceHere => 'اینجا';

  @override
  String get qiblaTitle => 'قبله‌یاب';

  @override
  String get qiblaAboutCompass => 'دربارهٔ این قطب‌نما';

  @override
  String get qiblaLocationNeeded => 'مکان لازم است';

  @override
  String get qiblaLocationNeededBody =>
      'جهت به محل شما بستگی دارد. مکان خود را به اشتراک بگذارید و به محض رسیدن یک موقعیت، قطب‌نما اشاره می‌کند.';

  @override
  String get qiblaUseMyLocation => 'از مکان من استفاده کن';

  @override
  String get qiblaTurnOnCompass => 'قطب‌نما را روشن کنید';

  @override
  String get qiblaTurnOnCompassBody =>
      'این مرورگر پیش از اینکه جهت گوشی را گزارش دهد به اجازهٔ شما نیاز دارد.';

  @override
  String get qiblaAllowCompass => 'اجازه به قطب‌نما';

  @override
  String get qiblaCompassBlocked => 'قطب‌نما مسدود است';

  @override
  String get qiblaCompassBlockedBody =>
      'دسترسی به حرکت و جهت رد شد، پس صفحه روی شمال نگه داشته شده است. آن را در تنظیمات مرورگر مجاز کنید، یا بچرخید تا شمال روی صفحه با شمال اطراف شما یکی شود.';

  @override
  String get qiblaNoCompass => 'این دستگاه قطب‌نما ندارد';

  @override
  String get qiblaNoCompassBody =>
      'صفحه به جای آن روی شمال نگه داشته شده است. رو به شمال بایستید و عقربه جهت را از آنجا نشان می‌دهد.';

  @override
  String get qiblaNeedsCalibrating => 'قطب‌نما نیاز به کالیبره دارد';

  @override
  String get qiblaLocationUnknown => 'مکان نامشخص';

  @override
  String get qiblaUpdateLocation => 'به‌روزرسانی مکان';

  @override
  String get qiblaPointingTowards => 'اشاره به سمت';

  @override
  String get qiblaWaitingForLocation => 'در انتظار مکان شما';

  @override
  String get qiblaPointTowards => 'به سمتِ';

  @override
  String get qiblaGreatCircleBody =>
      'عقربه در امتداد مسیر دایرهٔ عظیمه اشاره می‌کند — کوتاه‌ترین راه روی سطح زمین، که قبله بر اساس آن تعریف می‌شود. روی نقشهٔ تخت ممکن است غافلگیرکننده به نظر برسد؛ از آمریکای شمالی کعبه تقریباً شمال شرقی است، نه جنوب شرقی.';

  @override
  String get qiblaDeclinationUnknownBody =>
      'گوشی شما زاویه تا شمال مغناطیسی را اندازه می‌گیرد، که با شمال حقیقی به اندازه‌ای تفاوت دارد که به محل شما بستگی دارد. آن اصلاح به محض مشخص شدن مکان شما به‌طور خودکار اعمال می‌شود.';

  @override
  String get qiblaSteadyReadingBody =>
      'برای اندازه‌گیری ثابت، گوشی را صاف نگه دارید و از لپ‌تاپ‌ها، بلندگوها، داشبورد خودرو و هر چیز دیگری که آهنربا دارد دور نگهش دارید.';

  @override
  String get commonClose => 'بستن';

  @override
  String get weekdayShortMon => 'دو';

  @override
  String get weekdayShortTue => 'سه';

  @override
  String get weekdayShortWed => 'چهار';

  @override
  String get weekdayShortThu => 'پنج';

  @override
  String get weekdayShortFri => 'جمعه';

  @override
  String get weekdayShortSat => 'شنبه';

  @override
  String get weekdayShortSun => 'یک';

  @override
  String reminderMinutesRange(int max) {
    return 'عددی از دقیقه بین ۰ و $max وارد کنید.';
  }

  @override
  String get reminderTitleRequired => 'لطفاً عنوانی برای این یادآور وارد کنید.';

  @override
  String get reminderPickDay => 'دست‌کم یک روز انتخاب کنید.';

  @override
  String get reminderSavedPendingLocation =>
      'ذخیره شد. به محض در دسترس بودن مکان اوقات نماز شما شروع به اجرا می‌کند.';

  @override
  String get reminderEditTitle => 'ویرایش یادآور';

  @override
  String get reminderNewTitle => 'یادآور جدید';

  @override
  String get reminderWhat => 'چه چیزی';

  @override
  String get reminderWhatHint =>
      'ذکری از کتابخانه انتخاب کنید، یا فقط عنوانی در زیر بنویسید.';

  @override
  String get reminderChooseZikr => 'انتخاب از کتابخانهٔ ذکر';

  @override
  String get reminderChangeZikr => 'تغییر ذکر';

  @override
  String get reminderTitleLabel => 'عنوان';

  @override
  String get reminderTitleHint => 'مثلاً دعای توسل';

  @override
  String get reminderRepeatOn => 'تکرار در';

  @override
  String get reminderWhen => 'کی';

  @override
  String get reminderFixedTime => 'ساعت ثابت';

  @override
  String get reminderPrayerRelative => 'نسبت به نماز';

  @override
  String get commonSaveChanges => 'ذخیرهٔ تغییرات';

  @override
  String get reminderAdd => 'افزودن یادآور';

  @override
  String get reminderTime => 'ساعت';

  @override
  String get reminderPrayer => 'نماز';

  @override
  String get reminderMinutes => 'دقیقه';

  @override
  String get reminderBefore => 'پیش از';

  @override
  String get reminderAfter => 'پس از';

  @override
  String get reminderPrayerRelativeNote =>
      'اوقات نماز با تقویم جابه‌جا می‌شود، پس این، رویدادهای چند هفتهٔ آینده را زمان‌بندی می‌کند و هر بار که برنامه را باز می‌کنید آن‌ها را تازه‌سازی می‌کند.';

  @override
  String qazaCompletedCount(int count) {
    return '$count انجام‌شده';
  }

  @override
  String get qazaPrayed => 'خوانده شد';

  @override
  String get qazaFasted => 'گرفته شد';

  @override
  String qazaEstimatePrayers(String days, String prayers) {
    return '$days از هر نماز روزانه ($prayers نماز)';
  }

  @override
  String qazaEstimateFasts(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count روزه',
      one: '$count روزه',
    );
    return '$_temp0';
  }

  @override
  String qazaLunarNote(int yearDays, int monthDays) {
    return 'به‌صورت سال‌های قمری $yearDays روزه و ماه‌های $monthDays روزه محاسبه شده است.';
  }

  @override
  String get qazaTitle => 'پیگیری قضا';

  @override
  String get qazaCalculate => 'قضای من را محاسبه کن';

  @override
  String get qazaPrayers => 'نمازها';

  @override
  String get qazaFasts => 'روزه‌ها';

  @override
  String get qazaRemaining => 'قضای باقی‌مانده';

  @override
  String get commonUndo => 'بازگردانی';

  @override
  String get qazaMissed => 'ازدست‌رفته';

  @override
  String get qazaEditCount => 'ویرایش تعداد';

  @override
  String get qazaMissedAWhile => 'مدتی نمازها از دست رفت؟';

  @override
  String get qazaMissedAWhileBody =>
      'مدت آن را وارد کنید، و ما برای هر روز ازدست‌رفته یکی از هر نماز روزانه اضافه می‌کنیم.';

  @override
  String get qazaPrayedFullDay => 'یک روز کامل نماز خوانده شد';

  @override
  String get qazaLoggedFullDay => 'یکی از هر نماز روزانه ثبت شد';

  @override
  String get qazaAddedToList => 'به فهرست قضای شما افزوده شد';

  @override
  String get qazaRemainingLabel => 'باقی‌مانده';

  @override
  String get qazaCompletedLabel => 'انجام‌شده';

  @override
  String get commonClear => 'پاک کردن';

  @override
  String get qazaCalculateBody =>
      'تقریباً چه مدت نماز نخواندید؟ یک برآورد کلی کافی است — بعداً می‌توانید هر نماز را تنظیم کنید.';

  @override
  String get qazaPrayersMissedFor => 'نمازهای قضاشده به مدت';

  @override
  String get qazaYears => 'سال';

  @override
  String get qazaMonths => 'ماه';

  @override
  String get qazaDays => 'روز';

  @override
  String get qazaFastsMissed => 'روزه‌های ازدست‌رفته';

  @override
  String get qazaNumberOfFasts => 'تعداد روزه‌ها';

  @override
  String get qazaThisAdds => 'این به فهرست شما اضافه می‌کند:';

  @override
  String get qazaAddToList => 'افزودن به فهرست من';

  @override
  String get qazaDhuhr => 'ظهر';

  @override
  String get qazaAyat => 'نماز آیات';

  @override
  String get qazaOther => 'دیگر';

  @override
  String audioMobileDataSizedBody(String size) {
    return 'به Wi-Fi متصل نیستید. این کار حدود $size از دادهٔ همراه استفاده می‌کند.';
  }

  @override
  String get audioRemoveDownloadsTitle => 'دانلودها حذف شوند؟';

  @override
  String get audioRemoveDownloadTitle => 'دانلود حذف شود؟';

  @override
  String audioRemoveBody(String subject) {
    return '$subject دوباره پخش جریانی می‌شود، پس برای گوش دادن به اتصال نیاز دارید.';
  }

  @override
  String get audioTheseRecitations => 'این تلاوت‌ها';

  @override
  String get audioThisRecitation => 'این تلاوت';

  @override
  String audioQuotedName(String name) {
    return '«$name»';
  }

  @override
  String audioRemoveFrees(String size) {
    return '$size آزاد می‌کند.';
  }

  @override
  String get audioDownloadDone => 'دانلود شد - بدون اتصال پخش می‌شود';

  @override
  String audioDownloadDoneNamed(String name) {
    return '$name دانلود شد - بدون اتصال پخش می‌شود';
  }

  @override
  String get audioTheseRecitationsLower => 'این تلاوت‌ها';

  @override
  String get audioThisRecitationLower => 'این تلاوت';

  @override
  String audioDownloadPartial(int saved, int total) {
    return '$saved از $total دانلود شد.';
  }

  @override
  String audioDownloadFailedNamed(String what) {
    return 'دانلود $what ممکن نشد.';
  }

  @override
  String get audioDownloadOutOfSpace =>
      'دستگاه شما فضای خالی ندارد — مقداری فضا آزاد کنید و دوباره تلاش کنید.';

  @override
  String get audioDownloadUnavailable => 'یک تلاوت دیگر در دسترس نیست.';

  @override
  String get audioDownloadCheckConnection =>
      'اتصال خود را بررسی و دوباره تلاش کنید.';

  @override
  String get commonRetry => 'تلاش دوباره';

  @override
  String commonPercent(int percent) {
    return '$percent%';
  }

  @override
  String audioDownloadMore(int count) {
    return 'دانلود $count مورد دیگر';
  }

  @override
  String get audioDownloadAll => 'دانلود همه';

  @override
  String get audioDownloadForOffline => 'دانلود برای گوش دادن آفلاین';

  @override
  String get audioOfflineCannotDownload =>
      'آفلاین هستید. برای دانلود به اینترنت متصل شوید.';

  @override
  String get audioMobileDataTitle => 'دانلود با دادهٔ همراه؟';

  @override
  String get audioMobileDataBody =>
      'به Wi-Fi متصل نیستید. تلاوت‌ها می‌توانند بزرگ باشند، پس ممکن است دادهٔ همراه زیادی مصرف شود.';

  @override
  String get commonRemove => 'حذف';

  @override
  String get audioDownloading => 'در حال دانلود';

  @override
  String get audioDownloadingEllipsis => 'در حال دانلود…';

  @override
  String get audioDownloadedTooltip =>
      'برای گوش دادن آفلاین دانلود شد. برای حذف ضربه بزنید.';

  @override
  String get audioRetryDownload => 'تلاش دوباره برای دانلود';

  @override
  String get audioDownloadFailedTooltip =>
      'دانلود کامل نشد. برای تلاش دوباره ضربه بزنید.';

  @override
  String get audioDownloadRestTooltip =>
      'بقیه را برای گوش دادن آفلاین دانلود کنید';

  @override
  String get counterSemanticsLabel => 'رکعت و سجدهٔ فعلی';

  @override
  String counterRakaatCompleted(int count) {
    return '$count رکعت کامل شد';
  }

  @override
  String counterPosition(int rakaat, int sajdah) {
    return 'رکعت $rakaat  ·  سجده $sajdah';
  }

  @override
  String counterSajdahProgress(int done, int total) {
    return '$done از $total سجده';
  }

  @override
  String get counterSensorStopped =>
      'حسگر مجاورت پاسخ نداد. موقعیت گوشی را بررسی کنید و حس‌کردن خودکار را دوباره روشن کنید.';

  @override
  String get counterStartOverTitle => 'از اول شروع شود؟';

  @override
  String get counterStartOverBody =>
      'تغییر تعداد رکعت، شمارش نماز فعلی را بازنشانی می‌کند.';

  @override
  String get counterStartOver => 'از اول شروع کن';

  @override
  String get counterTitle => 'شمارندهٔ رکعت';

  @override
  String get counterHowToPlace => 'گوشی را چگونه بگذارید';

  @override
  String get counterPlaceBelowTurbah => 'گوشی را زیر مهر بگذارید';

  @override
  String get counterPlaceBelowTurbahBody =>
      'آن را صاف زیر مهر بگذارید، طوری که لبهٔ بالایی‌اش رو به آن باشد. مسیر پیشانی‌تان را خالی نگه دارید.';

  @override
  String get counterPrayerLength => 'طول نماز';

  @override
  String get counterSelectRakaat => 'تعداد رکعت را انتخاب کنید';

  @override
  String get counterComplete => 'کامل';

  @override
  String get counterSajdahDetected => 'سجده تشخیص داده شد';

  @override
  String get counterSensorReady => 'حسگر آماده است';

  @override
  String get counterCheckingSensor => 'در حال بررسی حسگر';

  @override
  String get counterSensingOff => 'حس‌کردن خودکار خاموش است';

  @override
  String get counterTapHint =>
      'فقط اگر سجده‌ای به‌طور خودکار تشخیص داده نشد ضربه بزنید';

  @override
  String get counterReady => 'آماده برای نخستین سجده';

  @override
  String get counterAutomaticHint =>
      'شمارش خودکار · فقط اگر یکی از قلم افتاد ضربه بزنید';

  @override
  String get counterManualHint =>
      'برای افزودن سجده به‌صورت دستی روی کارت ضربه بزنید';

  @override
  String get counterCheckingDevice => 'در حال بررسی این دستگاه…';

  @override
  String get counterNotAvailable => 'شمارش خودکار در این دستگاه در دسترس نیست.';

  @override
  String get counterObjectDetected =>
      'شیئی تشخیص داده شد. دور شوید تا شمارش بعدی آماده شود.';

  @override
  String get counterSensorArmed =>
      'آماده است — هر سجدهٔ تشخیص‌داده‌شده یک بار شمرده می‌شود.';

  @override
  String get counterSensorOffSubtitle =>
      'خاموش — این را روشن کنید تا سجده‌ها به‌طور خودکار شمرده شوند.';

  @override
  String get counterAutomaticSensing => 'حس‌کردن خودکار';

  @override
  String get counterIphoneNote =>
      'در iPhone، وقتی حسگر پوشیده است نمایشگر ممکن است برای مدت کوتاهی خاموش شود. موقعیت و برد حسگر بسته به مدل متفاوت است.';

  @override
  String get counterAndroidNote =>
      'موقعیت و برد حسگر بسته به گوشی متفاوت است. برخی گوشی‌های اندرویدی از حسگر مجاورت مجازی کم‌اعتمادتری استفاده می‌کنند.';

  @override
  String get counterPhonePlacement => 'جای گوشی';

  @override
  String get counterPlacementBody =>
      'گوشی را صاف زیر مهر بگذارید، طوری که لبهٔ بالایی و حسگرش رو به آن باشد. گوشی را کاملاً از مسیر پیشانی‌تان دور نگه دارید.';

  @override
  String get counterPlacementTest =>
      'پیش از شروع، حسگر را فعال کنید و با دستتان آزمایشش کنید. پس از هر آزمایش دستتان را دور کنید تا شمارش بعدی آماده شود.';

  @override
  String quranJuzNumber(int number) {
    return 'جزء $number';
  }

  @override
  String quranCopiedVerse(String verse) {
    return '$verse کپی شد';
  }

  @override
  String get quranRemoveFromSaved => 'حذف از ذخیره‌شده‌ها';

  @override
  String get quranSaveVerse => 'ذخیرهٔ آیه';

  @override
  String quranRemovedVerse(String verse) {
    return '$verse حذف شد';
  }

  @override
  String quranSavedVerse(String verse) {
    return '$verse ذخیره شد';
  }

  @override
  String zikrPartNumber(int number) {
    return 'بخش $number';
  }

  @override
  String zikrBookmarkMoveHint(String icon) {
    return 'نشان شد. برای جابه‌جایی بعدی آن، $icon روی برچسب «نشان‌شده» را به سطر دیگری بکشید.';
  }

  @override
  String get quranCopyVerse => 'کپی آیه';

  @override
  String get quranCopyLink => 'کپی پیوند';

  @override
  String get quranLinkCopied => 'پیوند کپی شد';

  @override
  String get quranShareVerse => 'اشتراک‌گذاری آیه';

  @override
  String get zikrMerits => 'فضیلت‌ها';

  @override
  String get zikrReportThanks => 'ممنون — نگاهی می‌اندازیم.';

  @override
  String get zikrReportFailed =>
      'ارسال گزارش ممکن نشد. لطفاً دوباره تلاش کنید.';

  @override
  String get zikrSuggestCorrection => 'پیشنهاد اصلاح';

  @override
  String get zikrSelectedText => 'متن انتخاب‌شده';

  @override
  String get zikrCorrectionHint => 'به جایش چه باید نوشته شود؟ (اختیاری)';

  @override
  String get commonSubmit => 'ارسال';

  @override
  String get zikrSetReminder => 'تنظیم یادآور';

  @override
  String get zikrUnableToOpen => 'باز کردن این دعا ممکن نیست.';

  @override
  String get zikrComingSoon => 'به‌زودی...';

  @override
  String get zikrHideCounter => 'پنهان کردن شمارنده';

  @override
  String deleteAccountSignInFailed(String error) {
    return 'ورود ناموفق بود: $error';
  }

  @override
  String deleteAccountSignOutFailed(String error) {
    return 'خروج ناموفق بود: $error';
  }

  @override
  String deleteAccountFailed(String error) {
    return 'خطا در حذف حساب: $error';
  }

  @override
  String deleteAccountSignedInAs(String account) {
    return 'شما با $account وارد شده‌اید.';
  }

  @override
  String get deleteAccountSignedIn => 'ورود با موفقیت انجام شد.';

  @override
  String get deleteAccountSignedOut => 'خارج شدید.';

  @override
  String get deleteAccountConfirmTitle => 'حساب حذف شود؟';

  @override
  String get deleteAccountConfirmBody =>
      'این کار حساب Shia Companion و علاقه‌مندی‌های همگام‌شدهٔ شما را برای همیشه حذف می‌کند.';

  @override
  String get deleteAccountDone => 'حساب با موفقیت حذف شد.';

  @override
  String get deleteAccountTitle => 'حذف حساب';

  @override
  String get deleteAccountHeading => 'حساب Shia Companion خود را مدیریت کنید';

  @override
  String get deleteAccountSignInPrompt =>
      'وارد شوید تا حسابی را که به علاقه‌مندی‌های همگام‌شدهٔ شما گره خورده است بررسی و برای همیشه حذف کنید.';

  @override
  String get deleteAccountWhatGetsDeleted => 'چه چیزی حذف می‌شود';

  @override
  String get deleteAccountItemSignIn => 'سابقهٔ ورود حساب Shia Companion شما.';

  @override
  String get deleteAccountItemFavorites =>
      'علاقه‌مندی‌های همگام‌شده و پیگیری قضای ذخیره‌شده برای آن حساب.';

  @override
  String get deleteAccountItemPreferences =>
      'ترجیحات خواندن همگام‌شدهٔ شما — تنظیم تاریخ هجری و انتخاب‌های قلم.';

  @override
  String get deleteAccountItemAnalytics =>
      'آمار ناشناس یا گزارش‌های خرابی که از پیش جمع‌آوری شده ممکن است به‌صورت تجمیعی باقی بماند.';

  @override
  String get deleteAccountCompleted => 'درخواست حذف حساب شما کامل شد.';

  @override
  String get deleteAccountCompletedNote =>
      'اگر بعداً دوباره وارد شوید، حسابی کاملاً جدید ساخته می‌شود.';

  @override
  String get deleteAccountWebSteps =>
      'از دکمهٔ ورود با Google در زیر استفاده کنید، سپس حذف را تأیید کنید.';

  @override
  String get deleteAccountAppSteps =>
      'ترجیحات را در برنامه باز کنید و از «حذف حساب من» استفاده کنید.';

  @override
  String get deleteAccountSigningIn => 'در حال ورود...';

  @override
  String get deleteAccountDeleting => 'در حال حذف...';

  @override
  String get deleteAccountButton => 'حذف حساب من';

  @override
  String get deleteAccountSignOut => 'خروج';

  @override
  String get deleteAccountHelp =>
      'به کمک نیاز دارید؟ به developer110@hotmail.com ایمیل بزنید و نشانی ایمیل مرتبط با حسابتان را هم بیاورید.';

  @override
  String statsBestStreak(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'بهترین: $days روز',
      one: 'بهترین: یک روز',
    );
    return '$_temp0';
  }

  @override
  String get statsTodayDone => 'امروز: انجام شد';

  @override
  String get statsTodayNotYet => 'امروز: هنوز نه';

  @override
  String statsDaysToGoal(int remaining, Object goal) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$remaining روز دیگر تا زنجیرهٔ هدف',
      one: 'یک روز دیگر تا زنجیرهٔ هدف',
    );
    return '$_temp0';
  }

  @override
  String statsUpdatedHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours ساعت پیش به‌روز شد',
      one: 'یک ساعت پیش به‌روز شد',
    );
    return '$_temp0';
  }

  @override
  String statsUpdatedOn(String date) {
    return 'در $date به‌روز شد';
  }

  @override
  String statsAllTime(String count) {
    return '$count در کل';
  }

  @override
  String statsCommunityNote(String updated) {
    return 'مجموع‌های ناشناس از همهٔ کاربران برنامه. $updated.';
  }

  @override
  String get statsTitle => 'آمار من';

  @override
  String get statsYourMostRecited => 'پرتلاوت‌ترین‌های شما';

  @override
  String get statsStreakStart =>
      'خواندن یک دعا، زیارت یا سوره را تمام کنید و زنجیرهٔ شما آغاز می‌شود.';

  @override
  String get statsWelcomeBack => 'خوش برگشتید — هر روز شروعی تازه است.';

  @override
  String get statsDoneTodayFirst =>
      'برای امروز تمام شد. فردا برگردید تا زنجیره‌ای را شروع کنید.';

  @override
  String get statsDoneToday =>
      'برای امروز تمام شد — فردا می‌بینمتان، ان‌شاءالله.';

  @override
  String get statsReadToday => 'امروز چیزی بخوانید تا ادامه پیدا کند.';

  @override
  String get statsDayStreak => 'زنجیرهٔ روزانه';

  @override
  String get statsToday => 'امروز';

  @override
  String get statsPrivateSynced =>
      'آمار شما خصوصی است و در دستگاه‌هایی که به حساب شما وارد شده‌اند همگام می‌شود.';

  @override
  String get statsPrivateLocal =>
      'آمار شما خصوصی است و روی این دستگاه نگه داشته می‌شود. از ترجیحات وارد شوید تا در دستگاه‌ها همراهتان باشد.';

  @override
  String get statsUpdatedWithinHour => 'در همین ساعت به‌روز شد';

  @override
  String get statsAcrossCommunity => 'در سراسر جامعهٔ کاربران';

  @override
  String get statsRecitedThisWeek =>
      'دعاها، زیارت‌ها و سوره‌های تلاوت‌شده در این هفته';

  @override
  String get statsMostRecitedThisWeek => 'پرتلاوت‌ترین این هفته';

  @override
  String quranSurahNumber(int number) {
    return 'سوره $number';
  }

  @override
  String get listenQuranTextFailed =>
      'خواندن متن قرآن روی این دستگاه ممکن نشد.';

  @override
  String get listenRecogniserStopped =>
      'مبدل گفتار به‌طور غیرمنتظره متوقف شد. دوباره تلاش کنید.';

  @override
  String get listenNothingRecognised =>
      'چیز قابل تشخیصی نرسید. دوباره تلاش کنید، کمی نزدیک‌تر به قاری.';

  @override
  String get listenCouldNotPlace =>
      'جای آن در قرآن پیدا نشد. کمی بیشتر تلاوت کنید.';

  @override
  String get listenMicPermissionWeb =>
      'گوش دادن به دسترسی میکروفون نیاز دارد. می‌توانید آن را در مجوزهای این سایت در مرورگرتان بدهید.';

  @override
  String get listenMicPermission =>
      'گوش دادن به دسترسی میکروفون نیاز دارد. می‌توانید آن را در تنظیمات دستگاه بدهید.';

  @override
  String get listenBrowserUnsupported =>
      'این مرورگر نمی‌تواند گفتار را تشخیص دهد. Chrome و Edge و Safari می‌توانند.';

  @override
  String get listenDeviceUnsupported =>
      'این دستگاه مبدل گفتاری در دسترس ندارد.';

  @override
  String get listenNoArabic =>
      'این دستگاه تشخیص گفتار عربی نصب‌شده ندارد. افزودن عربی در تنظیمات زبان دستگاه آن را فعال می‌کند.';

  @override
  String get listenStartFailed => 'شروع گوش دادن ممکن نشد. دوباره تلاش کنید.';

  @override
  String get listenTitle => 'گوش دهید و دنبال کنید';

  @override
  String get listenGettingReady => 'در حال آماده‌سازی…';

  @override
  String get listenListening => 'در حال گوش دادن…';

  @override
  String get listenHoldPhone => 'گوشی را به سمت تلاوت بگیرید.';

  @override
  String get listenFindNow => 'حالا آیه را پیدا کن';

  @override
  String get listenFinding => 'در حال یافتن آیه…';

  @override
  String get listenWhichVerse => 'کدام آیه بود؟';

  @override
  String get listenAgain => 'دوباره گوش دهید';

  @override
  String get commonTryAgain => 'دوباره تلاش کنید';

  @override
  String flightDepartureDateAt(String airport) {
    return 'تاریخ حرکت در $airport';
  }

  @override
  String flightArrivalDateAt(String airport) {
    return 'تاریخ رسیدن در $airport';
  }

  @override
  String flightDepartureTimeAt(String airport) {
    return 'ساعت حرکت (محلی در $airport)';
  }

  @override
  String flightArrivalTimeAt(String airport) {
    return 'ساعت رسیدن (محلی در $airport)';
  }

  @override
  String flightDurationTooLong(String duration) {
    return 'یعنی $duration در هوا می‌شود. تاریخ رسیدن را بررسی کنید.';
  }

  @override
  String get flightFrom => 'از';

  @override
  String get flightTo => 'به';

  @override
  String get flightDeparts => 'حرکت';

  @override
  String get flightArrives => 'رسیدن';

  @override
  String get flightDepartureAirport => 'فرودگاه حرکت';

  @override
  String get flightArrivalAirport => 'فرودگاه مقصد';

  @override
  String get flightChooseDepartureFirst => 'ابتدا فرودگاه حرکت را انتخاب کنید.';

  @override
  String get flightChooseArrivalFirst => 'ابتدا فرودگاه مقصد را انتخاب کنید.';

  @override
  String get flightChooseBothAirports => 'هر دو فرودگاه را انتخاب کنید.';

  @override
  String get flightSetTimes => 'ساعت‌های حرکت و رسیدن را تنظیم کنید.';

  @override
  String get flightAirportsMustDiffer =>
      'فرودگاه حرکت و مقصد باید متفاوت باشند.';

  @override
  String get flightTimeZoneUnresolved =>
      'منطقهٔ زمانی یکی از آن فرودگاه‌ها مشخص نشد.';

  @override
  String get flightArrivalBeforeDeparture =>
      'پس از اعمال منطقه‌های زمانی، رسیدن پیش از حرکت است. تاریخ رسیدن را بررسی کنید — پروازهای شبانه روز بعد می‌رسند.';

  @override
  String get flightAdd => 'افزودن پرواز';

  @override
  String get flightDepartsHint => 'ساعت محلی در فرودگاه حرکت';

  @override
  String get flightArrivesHint => 'ساعت محلی در فرودگاه مقصد';

  @override
  String get flightNumberLabel => 'شمارهٔ پرواز (اختیاری)';

  @override
  String get flightSaveChanges => 'ذخیرهٔ تغییرات';

  @override
  String get flightSave => 'ذخیرهٔ پرواز';

  @override
  String get flightTicketNote =>
      'ساعت‌ها را دقیقاً همان‌طور که روی بلیتتان است وارد کنید — هر کدام به ساعت محلی فرودگاه خودش.';

  @override
  String get flightChooseAirport => 'فرودگاهی انتخاب کنید';

  @override
  String get flightChooseDateTime => 'تاریخ و ساعت را انتخاب کنید';

  @override
  String get widgetIslamicCalendar => 'تقویم اسلامی';

  @override
  String get widgetFavorites => 'علاقه‌مندی‌ها';

  @override
  String get widgetNoFavorites => 'هنوز علاقه‌مندی‌ای نیست';

  @override
  String get widgetTodaysRecitations => 'تلاوت‌های امروز';

  @override
  String get widgetOpenAppToRefresh => 'برای تازه‌سازی برنامه را باز کنید';

  @override
  String get widgetUpNext => 'بعدی';

  @override
  String get widgetPrayerTimes => 'اوقات نماز';

  @override
  String get widgetLocationNeeded => 'مکان لازم است';

  @override
  String get widgetSavedLocation => 'مکان ذخیره‌شده';

  @override
  String get widgetSetLocation => 'تنظیم مکان';

  @override
  String get widgetOpenApp => 'باز کردن برنامه';

  @override
  String get widgetRefreshSchedule => 'تازه‌سازی برنامهٔ زمانی';

  @override
  String get commonToday => 'امروز';

  @override
  String get commonTomorrow => 'فردا';

  @override
  String quranSurahAyah(String surah, int ayah) {
    return '$surah $ayah';
  }

  @override
  String trackNameTaken(String name) {
    return 'از پیش مسیری به نام «$name» هست';
  }

  @override
  String get trackNameRequired => 'به مسیر نامی بدهید';

  @override
  String get trackBeginning => 'آغاز';

  @override
  String get trackNew => 'مسیر تلاوت جدید';

  @override
  String get trackName => 'نام';

  @override
  String get trackNameHint => 'مثلاً خانواده، تهجد';

  @override
  String get trackReadBy => 'خوانده‌شده توسط';

  @override
  String get trackBySurah => 'سوره';

  @override
  String get trackByJuz => 'جزء (پاره)';

  @override
  String get trackContinueFrom => 'ادامه از';

  @override
  String get trackStartFrom => 'شروع از';

  @override
  String get trackStartAt => 'شروع در';

  @override
  String get trackEditNote =>
      'مسیر شما هنگام خواندن خودش پیش می‌رود. این را فقط برای ادامه از جایی دیگر تغییر دهید.';

  @override
  String get trackNewNote =>
      'این‌ها را هر وقت خواستید از کارت مسیر می‌توانید تغییر دهید.';

  @override
  String get trackCreate => 'ساختن مسیر';

  @override
  String notifDefaultSoundSubtitle(String sound) {
    return '$sound · استفاده می‌شود مگر وقتی در زیر آن را تغییر دهد';
  }

  @override
  String notifCustomSound(String file) {
    return 'سفارشی: $file';
  }

  @override
  String notifPrayerSound(String prayer) {
    return 'صدای $prayer';
  }

  @override
  String notifFollows(String sound) {
    return 'پیرو $sound';
  }

  @override
  String get notifDefaultSound => 'صدای پیش‌فرض';

  @override
  String get notifTimesHeading => 'اوقات';

  @override
  String get notifAudioUnreadable => 'آن فایل صوتی خوانده نشد.';

  @override
  String get notifPickFailed => 'انتخاب آن فایل ممکن نشد. دوباره تلاش کنید.';

  @override
  String get notifPlayingSample => 'تا لحظه‌ای دیگر نمونه‌ای پخش می‌شود…';

  @override
  String get notifUseDefault => 'استفاده از پیش‌فرض';

  @override
  String get notifOwnSoundNote =>
      'این وقت صدای خودش را نگه می‌دارد. بقیه از پیش‌فرض پیروی می‌کنند.';

  @override
  String get notifDefaultNote =>
      'هر وقت از این پیروی می‌کند مگر به آن صدای خودش را بدهید.';

  @override
  String get notifPreview => 'پیش‌نمایش';

  @override
  String aboutVersion(String version) {
    return 'نسخه $version';
  }

  @override
  String get aboutDedication =>
      'از خداوند متعال و چهارده معصوم محبوبش (ع) سپاسگزاریم که با یاریشان توانستیم این اثر ناچیز را با مؤمنین به اشتراک بگذاریم. این برنامه را به آنان و مرحومین زیر تقدیم می‌کنیم:\n\nMarhooma Amina Mohammed Raza Jassani\nMarhoom Haji Mohammad Raza Jassani\nMarhoom Haji Yusufali Bhojani\n\n\nلطفاً برای مرحومین و مرحومات سورهٔ فاتحه تلاوت کنید\n\nبرای بازخورد، پرسش یا پیشنهاد تماس بگیرید:';

  @override
  String get aboutNoEmailApp => 'برنامهٔ ایمیلی یافت نشد';

  @override
  String get aboutCredits => 'اعتبارات';

  @override
  String get aboutCreditAudio =>
      'صدای تلاوت‌ها روی سرورهای خودمان میزبانی می‌شود؛ ضبط‌ها با اجازهٔ لطف‌آمیز duas.org استفاده شده‌اند.';

  @override
  String get aboutCreditScheherazade =>
      'عربی با قلم Scheherazade New از SIL Global تنظیم شده و تحت مجوز قلم باز SIL استفاده می‌شود.';

  @override
  String get aboutCreditTanzil =>
      'متن عثمانی قرآن، که با Scheherazade نشان داده می‌شود، از پروژهٔ Tanzil است و تحت Creative Commons Attribution 3.0 استفاده می‌شود.';

  @override
  String get aboutCreditQuranWbw =>
      'متن و قلم هندی-پاکی قرآن، که با Qalam نشان داده می‌شود، از QuranWBW.com است. مجوز استفادهٔ بدون تغییر از متن و قلم قرآن از QuranWBW.com، مشارکت‌کنندهٔ اصلی، دریافت شده است.';

  @override
  String get aboutCreditIndoPakFont =>
      'قلم: AlQuran IndoPak از QuranWBW، ساختهٔ Ayman Siddiqui، بر پایهٔ قلم‌های Al Qalam Quran Majeed، با شمارهٔ آیات از قلم KFGQPC Nastaleeq. © Al Qalam © Ghandhara © KFGQPC © Ayman Siddiqui. اعتبارات: Abdul Majeed Khan، Arif Karim، Shakir-ul-Qadree، Jawad. متن قرآن: typemybook.com، در اصل از InPage.';

  @override
  String downloadsRemoveAllBody(String size) {
    return 'هر تلاوت دوباره پخش جریانی می‌شود، پس برای گوش دادن به اتصال نیاز دارید. $size آزاد می‌کند.';
  }

  @override
  String downloadsOlderSubtitle(int count, String size) {
    return '$count دیگر هیچ دعایی استفاده نمی‌کند · $size';
  }

  @override
  String get downloadsRemoveAllTitle => 'همهٔ دانلودها حذف شوند؟';

  @override
  String get downloadsRemoveAll => 'حذف همه';

  @override
  String get downloadsEmpty => 'هنوز دانلودی نیست';

  @override
  String get downloadsEmptyBody =>
      'تلاوتی را دانلود کنید تا بدون اتصال گوش دهید — روی دکمهٔ دانلود در پخش‌کنندهٔ صدای یک دعا ضربه بزنید، یا «دانلود همه» در یک فهرست پخش.';

  @override
  String get downloadsOlder => 'ضبط‌های قدیمی‌تر';

  @override
  String get downloadsRemoveOlder => 'حذف ضبط‌های قدیمی‌تر';

  @override
  String get hijriMonth1 => 'محرم';

  @override
  String get hijriMonth2 => 'صفر';

  @override
  String get hijriMonth3 => 'ربیع‌الاول';

  @override
  String get hijriMonth4 => 'ربیع‌الثانی';

  @override
  String get hijriMonth5 => 'جمادی‌الاول';

  @override
  String get hijriMonth6 => 'جمادی‌الثانی';

  @override
  String get hijriMonth7 => 'رجب';

  @override
  String get hijriMonth8 => 'شعبان';

  @override
  String get hijriMonth9 => 'رمضان';

  @override
  String get hijriMonth10 => 'شوال';

  @override
  String get hijriMonth11 => 'ذی‌القعده';

  @override
  String get hijriMonth12 => 'ذی‌الحجه';

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
  String get hijriMonthShort10 => 'شوال';

  @override
  String get hijriMonthShort11 => 'ذق';

  @override
  String get hijriMonthShort12 => 'ذح';

  @override
  String prayerUpdatedAgo(String age) {
    return '$age پیش به‌روز شد';
  }

  @override
  String get prayerNextDay => '(روز بعد)';

  @override
  String get prayerLocating => 'در حال مکان‌یابی…';

  @override
  String get prayerForYourLocation => 'اوقات نماز برای مکان شما';

  @override
  String get prayerFindingLocation => 'در حال یافتن مکان شما';

  @override
  String get prayerAppearSoon => 'اوقات نماز تا لحظه‌ای دیگر ظاهر می‌شود';

  @override
  String get prayerTapToRetry => 'برای تلاش دوباره ضربه بزنید';

  @override
  String get prayerLocationUnavailable => 'مکان در دسترس نیست';

  @override
  String get prayerTapToEnableLocation =>
      'برای فعال کردن مکان اینجا ضربه بزنید';

  @override
  String calendarNotificationsSomeOn(int enabled, int total) {
    return '$enabled از $total روشن';
  }

  @override
  String get calendarNoEvent => 'رویدادی برای این تاریخ فهرست نشده است.';

  @override
  String get calendarNotificationsAllOff => 'برای هر نماز خاموش';

  @override
  String get readingFineTune =>
      'متن ذکر را دقیق تنظیم کنید. روی اندازهٔ متن برنامه در تنظیمات اعمال می‌شود.';

  @override
  String get readingArabicFontSize => 'اندازهٔ قلم عربی';

  @override
  String get readingEnglishFontSize => 'اندازهٔ قلم انگلیسی';

  @override
  String get readingArabicFont => 'قلم عربی';

  @override
  String get readingKeepScreenOn => 'هنگام تلاوت ذکر صفحه را روشن نگه دار';

  @override
  String get readingFocusMode => 'حالت تمرکز';

  @override
  String get readingFocusModeSubtitle =>
      'هنگام خواندن نوار پیشرفت و نوار کنش را پنهان کنید. برای برگرداندنشان به بالا پیمایش کنید یا ضربه بزنید.';

  @override
  String get readingShareAsImage => 'اشتراک‌گذاری ذکر به‌صورت تصویر';

  @override
  String get readingShareAsImageSubtitle =>
      'هنگام اشتراک‌گذاری تصویری قالب‌بندی‌شده بسازید.';

  @override
  String get readingShowTransliteration => 'نمایش آوانویسی';

  @override
  String get readingShowTranslation => 'نمایش ترجمه';

  @override
  String get readingArabicParagraph => 'نمایش عربی به‌صورت پاراگراف';

  @override
  String get readingArabicParagraphOn =>
      'آیات عربی را به‌جای سطرهای جدا، در یک پاراگراف پیوسته جاری کنید.';

  @override
  String get readingArabicParagraphOff =>
      'برای استفاده از این، آوانویسی و ترجمه در بالا را خاموش کنید.';

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
      other: '$count آیه',
      one: 'یک آیه',
    );
    return '$_temp0';
  }

  @override
  String pickerJuzFrom(String start) {
    return 'از $start';
  }

  @override
  String pickerAyahSingle(int ayah) {
    return 'آیه $ayah';
  }

  @override
  String pickerAyahRange(int from, int to) {
    return 'آیات $from–$to';
  }

  @override
  String get pickerThirtyJuz => '۳۰ جزء وجود دارد';

  @override
  String get pickerTryVerse => 'آیه‌ای مثل 33:33 یا جزء 22 را امتحان کنید';

  @override
  String get pickerSearchHint => 'رفتن به یک آیه — 33:33، 18، جزء 22';

  @override
  String get pickerChooseVerse => 'آیه‌ای انتخاب کنید';

  @override
  String get pickerAllJuz => 'همهٔ اجزا';

  @override
  String get pickerAllSurahs => 'همهٔ سوره‌ها';

  @override
  String get pickerChoose => 'انتخاب';

  @override
  String quranFromPosition(String position) {
    return 'از $position';
  }

  @override
  String quranPercentRead(String percent) {
    return '$percent% از قرآن';
  }

  @override
  String quranEditTrack(String track) {
    return 'ویرایش مسیر $track';
  }

  @override
  String get quranTitle => 'قرآن';

  @override
  String get quranRecentSessions => 'نشست‌های اخیر';

  @override
  String get quranTabSurahs => 'سوره‌ها';

  @override
  String get quranTabJuz => 'جزء';

  @override
  String get quranTabCollections => 'مجموعه‌ها';

  @override
  String get quranStartReading => 'شروع خواندن';

  @override
  String get quranNewTrack => 'مسیر جدید';

  @override
  String get quranGoToVerseError => 'چیزی مثل 23:56 را امتحان کنید';

  @override
  String get quranGoToVerseHint => 'رفتن به آیه، مثلاً 23:56';

  @override
  String get quranGo => 'برو';

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
      other: '$count آیه',
      one: '$count آیه',
    );
    return '$_temp0';
  }

  @override
  String statsZikrCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ذکر',
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
  String get statsPeriodWeek => 'هفته';

  @override
  String get statsPeriodMonth => 'ماه';

  @override
  String get statsPeriodAllTime => 'همهٔ زمان‌ها';

  @override
  String statsCaptionWeek(String metric) {
    return '$metric در ۷ روز گذشته';
  }

  @override
  String statsCaptionMonth(String metric) {
    return '$metric در ۳۰ روز گذشته';
  }

  @override
  String statsCaptionAllTime(String metric) {
    return '$metric در کل';
  }

  @override
  String get statsHistory => 'پیشینه';

  @override
  String statsBestMonth(String month, String count) {
    return 'بهترین ماه: $month · $count';
  }

  @override
  String statsBestDay(String day, String count, String average) {
    return 'بهترین روز: $day · $count · میانگین $average در روز';
  }

  @override
  String get statsNew => 'جدید';

  @override
  String statsVersusBefore(String count) {
    return 'در برابر $count پیش از این';
  }

  @override
  String statsSessionCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نشست',
      one: '$count نشست',
    );
    return '$_temp0';
  }

  @override
  String statsVersesRecited(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آیه تلاوت شد',
      one: '$count آیه تلاوت شد',
    );
    return '$_temp0';
  }

  @override
  String statsLastOn(String date) {
    return 'آخرین بار $date';
  }

  @override
  String statsVersesLeft(String count) {
    return '$count آیه مانده تا یک ختم کامل شود';
  }

  @override
  String statsJuzCoverage(int juz, int percent) {
    return 'جزء $juz: $percent%';
  }

  @override
  String statsJuzComplete(int count) {
    return '$count از ۳۰ جزء کامل';
  }

  @override
  String get statsQuranProgress => 'پیشرفت قرآن';

  @override
  String get statsQuranEmpty =>
      'سوره‌ای را باز کنید و شروع به خواندن کنید — آیاتی که تلاوت می‌کنید اینجا به‌طور خودکار پیگیری می‌شود، همراه پیشرفت شما به سمت یک ختم کامل.';

  @override
  String get statsRecitedTill => 'تلاوت‌شده تا';

  @override
  String get statsNotStarted => 'شروع نشده';

  @override
  String get statsJuzDone => 'جزء تمام شد';

  @override
  String get statsKhatmComplete => 'ختم کامل شد — قبول باشد';

  @override
  String reminderAtPrayer(String prayer) {
    return 'هنگام $prayer';
  }

  @override
  String reminderMinutesAfter(int minutes, String prayer) {
    return '$minutes دقیقه پس از $prayer';
  }

  @override
  String reminderMinutesBefore(int minutes, String prayer) {
    return '$minutes دقیقه پیش از $prayer';
  }

  @override
  String azanPlaying(String prayer) {
    return 'اذان $prayer در حال پخش است';
  }

  @override
  String get libraryNeedsNetwork => 'مرور کتابخانه به اتصال شبکه نیاز دارد.';

  @override
  String get libraryChaptersFailed =>
      'بارگیری فصل‌ها ممکن نشد. لطفاً دوباره تلاش کنید.';

  @override
  String get libraryReadingNeedsNetwork =>
      'خواندن کتاب‌ها به اتصال شبکه نیاز دارد.';

  @override
  String get libraryChapterFailed =>
      'بارگیری این فصل ممکن نشد. لطفاً دوباره تلاش کنید.';

  @override
  String get menuCalendarPrayerTimes => 'تقویم و اوقات نماز';

  @override
  String get menuFavorites => 'علاقه‌مندی‌ها';

  @override
  String get menuTodaysRecitations => 'تلاوت‌های امروز';

  @override
  String get menuTaqeebat => 'تعقیبات نماز';

  @override
  String get menuNamaz => 'نماز';

  @override
  String get menuDuas => 'دعاها';

  @override
  String get menuZiyarats => 'زیارت‌ها';

  @override
  String get menuSurahs => 'سوره‌ها';

  @override
  String get menuAamaal => 'اعمال';

  @override
  String get menuLibrary => 'کتابخانه';

  @override
  String get menuMunajaat => 'مناجات';

  @override
  String get menuBaaqeyaat => 'باقیات صالحات';

  @override
  String get menuQiblaFinder => 'قبله‌یاب';

  @override
  String get menuTasbeehCounter => 'شمارندهٔ تسبیح';

  @override
  String get menuQazaTracker => 'پیگیری قضا';

  @override
  String get menuRakaatCounter => 'شمارندهٔ رکعت';

  @override
  String get menuPrayerTimesInFlight => 'اوقات نماز در پرواز';

  @override
  String get menuPreferences => 'ترجیحات';

  @override
  String get menuQuran => 'قرآن';

  @override
  String get menuPlaylists => 'فهرست‌های پخش';

  @override
  String get menuMyStats => 'آمار من';

  @override
  String get menuCalendar => 'تقویم';

  @override
  String audioTrackNumber(int number) {
    return 'قطعه $number';
  }

  @override
  String get audioPauseRecitation => 'مکث تلاوت';

  @override
  String get audioPlayRecitation => 'پخش تلاوت';

  @override
  String get audioList => 'فهرست صدا';

  @override
  String get audioOfflineNotDownloaded =>
      'آفلاین هستید و این تلاوت دانلود نشده است';

  @override
  String get audioLoadFailed => 'این تلاوت بارگیری نشد';

  @override
  String get audioClosePlayer => 'بستن پخش‌کننده';

  @override
  String get audioChooseRecording => 'انتخاب ضبط';

  @override
  String get audioRecitation => 'تلاوت';

  @override
  String get audioRecitationAudio => 'صدای تلاوت';

  @override
  String librarySavedOffline(String book) {
    return '$book برای استفادهٔ آفلاین ذخیره شد.';
  }

  @override
  String librarySaveFailed(String error) {
    return 'ذخیرهٔ کتاب ممکن نشد: $error';
  }

  @override
  String libraryProgress(String chapter, int page, int pages) {
    return '$chapter - صفحه $page از $pages';
  }

  @override
  String get librarySavedChapterGone => 'فصل ذخیره‌شده دیگر در دسترس نیست';

  @override
  String get libraryUnavailable => 'کتابخانه در دسترس نیست';

  @override
  String get libraryNoBooks => 'کتابی یافت نشد';

  @override
  String get libraryEmpty => 'کتابخانه در حال حاضر خالی است.';

  @override
  String get libraryContinueReading => 'ادامهٔ خواندن';

  @override
  String get libraryRequestBook => 'درخواست کتاب';

  @override
  String get libraryRequestBookSubtitle =>
      'کتابی را پیدا نمی‌کنید؟ از ما بخواهید اضافه‌اش کنیم.';

  @override
  String flightRemoveBody(String flight) {
    return '$flight از پروازهای ذخیره‌شدهٔ شما حذف می‌شود.';
  }

  @override
  String flightLands(String duration, String time, String airport) {
    return '$duration · در $time می‌رسد، ساعت $airport';
  }

  @override
  String get flightRemoveTitle => 'پرواز حذف شود؟';

  @override
  String get flightRemove => 'حذف پرواز';

  @override
  String get flightNoneSaved => 'پروازی ذخیره نشده است';

  @override
  String get flightNoneSavedBody =>
      'پروازتان را اضافه کنید و این صفحه حساب می‌کند هر نماز در مسیر کی فرا می‌رسد — به ساعت شهر حرکت و شهر رسیدن شما هر دو نشان داده می‌شود.';

  @override
  String librarySavedForOffline(String title) {
    return '$title برای استفادهٔ آفلاین ذخیره شد';
  }

  @override
  String librarySaveFailedShort(String error) {
    return 'ذخیره ناموفق بود: $error';
  }

  @override
  String get libraryOfflineRemoved => 'نسخهٔ آفلاین حذف شد';

  @override
  String get libraryShareBook => 'اشتراک‌گذاری کتاب';

  @override
  String get libraryRemoveOffline => 'حذف نسخهٔ آفلاین';

  @override
  String get librarySaveOffline => 'ذخیرهٔ کتاب برای آفلاین';

  @override
  String get libraryChaptersUnavailable => 'فصل‌ها در دسترس نیستند';

  @override
  String get libraryNoChapters => 'فصلی یافت نشد';

  @override
  String get libraryNoChaptersBody => 'این کتاب در حال حاضر فصلی ندارد.';

  @override
  String quranMoveEntry(String entry) {
    return 'جابه‌جایی «$entry»';
  }

  @override
  String get quranNoSessions =>
      'هنوز نشستی نیست. سوره‌ای را باز کنید و شروع به خواندن کنید — آیاتی که تلاوت می‌کنید اینجا به‌طور خودکار ثبت می‌شود.';

  @override
  String get quranMoveToLabel => 'انتقال به برچسبی دیگر';

  @override
  String get quranNewLabel => 'یا برچسبی جدید';

  @override
  String get quranMove => 'انتقال';

  @override
  String get quranCollectionDuas => 'دعاها';

  @override
  String get quranCollectionImamAli => 'امام علی (ع)';

  @override
  String get quranCollectionImamMahdi => 'امام مهدی (عج)';

  @override
  String get quranCollectionProphets => 'پیامبران';

  @override
  String get quranCollectionSaved => 'ذخیره‌شده';

  @override
  String get quranFromTheQuran => 'از قرآن';

  @override
  String get quranNoSavedVerses => 'هنوز آیهٔ ذخیره‌شده‌ای نیست';

  @override
  String get quranNoSavedVersesBody =>
      'هنگام خواندن روی یک آیه ضربه بزنید تا اینجا نگهش دارید.';

  @override
  String get libraryNextChapter => 'فصل بعد';

  @override
  String get libraryPreviousChapter => 'فصل قبل';

  @override
  String get libraryNextPage => 'صفحهٔ بعد';

  @override
  String get libraryPreviousPage => 'صفحهٔ قبل';

  @override
  String libraryNextChapterNamed(String chapter) {
    return 'فصل بعد: $chapter';
  }

  @override
  String libraryPreviousChapterNamed(String chapter) {
    return 'فصل قبل: $chapter';
  }

  @override
  String libraryNextShort(String chapter) {
    return 'بعدی: $chapter';
  }

  @override
  String libraryPreviousShort(String chapter) {
    return 'قبلی: $chapter';
  }

  @override
  String get libraryShareChapter => 'اشتراک‌گذاری فصل';

  @override
  String get libraryChapterUnavailable => 'فصل در دسترس نیست';

  @override
  String get libraryDecreaseFont => 'کوچک کردن قلم';

  @override
  String get libraryIncreaseFont => 'بزرگ کردن قلم';

  @override
  String get azaanTakbirName => 'فقط تکبیر';

  @override
  String get azaanTakbirDescription => 'صدای کوتاه تکبیر برای اعلان';

  @override
  String get azaanFullName => 'اذان کامل';

  @override
  String get azaanFullDescription => 'اذان کامل، به‌طور خودکار پخش می‌شود';

  @override
  String get azaanFullIosDescription =>
      'اعلان تکبیر را پخش می‌کند؛ روی آن ضربه بزنید تا اذان کامل را بشنوید';

  @override
  String get azaanSystemDefaultName => 'پیش‌فرض سیستم';

  @override
  String get azaanSystemDefaultDescription =>
      'از صدای پیش‌فرض اعلان دستگاه استفاده کنید';

  @override
  String get azaanSilentName => 'بی‌صدا';

  @override
  String get azaanSilentDescription => 'فقط بنر اعلان (بدون صدا)';

  @override
  String get azaanCustomName => 'صدای سفارشی';

  @override
  String get azaanCustomDescription => 'فایل صوتی‌ای از دستگاه خود انتخاب کنید';

  @override
  String get ratingEnjoying => 'از Shia Companion لذت می‌برید؟';

  @override
  String get ratingEnjoyingBody =>
      'دوست داریم بدانیم چطور پیش می‌رود — بازخورد شما به ما کمک می‌کند برنامه را همچنان بهتر کنیم.';

  @override
  String get ratingNotReally => 'نه واقعاً';

  @override
  String get ratingYes => 'بله!';

  @override
  String get ratingSorry => 'متأسفیم که این را می‌شنویم';

  @override
  String get ratingSorryBody =>
      'اشکالی دارد به ما بگویید چه چیزی کار نمی‌کند؟ به ما کمک می‌کند برنامه را بهتر کنیم.';

  @override
  String get ratingNoThanks => 'نه، ممنون';

  @override
  String get ratingSendFeedback => 'ارسال بازخورد';

  @override
  String get azaanOptInIntro =>
      'Shia Companion می‌تواند هنگام فجر، ظهر و مغرب برایتان اعلان بفرستد و اذان پخش کند.';

  @override
  String get azaanOptInIosNote =>
      'در iPhone اعلان یک تکبیر کوتاه پخش می‌کند. در تنظیمات «اذان کامل» را انتخاب کنید تا وقتی روی آن ضربه می‌زنید اذان کامل را بشنوید.';

  @override
  String get azaanOptInChangeLater =>
      'هر وقت خواستید می‌توانید در تنظیمات تغییر دهید کدام نمازها به شما خبر دهند، صدای دیگری انتخاب کنید، یا این را دوباره خاموش کنید.';

  @override
  String get azaanOptInTitle => 'هنگام نماز اذان پخش شود؟';

  @override
  String get azaanOptInNotNow => 'حالا نه';

  @override
  String get azaanOptInEnable => 'فعال کردن اذان';

  @override
  String reminderRemoveBody(String title) {
    return 'این کار یادآور «$title» را حذف می‌کند. هر وقت خواستید می‌توانید دوباره اضافه‌اش کنید.';
  }

  @override
  String get reminderRemoveTitle => 'یادآور حذف شود؟';

  @override
  String get reminderAddTooltip => 'افزودن یادآور';

  @override
  String get reminderNone => 'هنوز یادآوری نیست';

  @override
  String get reminderNoneBody =>
      'روی + ضربه بزنید تا در روزهایی که انتخاب می‌کنید برای یک ذکر یا دعا یادآوری بگیرید — مثل توسل هر سه‌شنبه، یا دعای کمیل پس از مغرب پنجشنبه.';

  @override
  String tasbeehBeepNumber(int number) {
    return 'بوق $number';
  }

  @override
  String get tasbeehHelp =>
      'برای شمردن روی دایرهٔ شمارنده ضربه بزنید. بوق در نقاط عطف زیر پخش می‌شود.';

  @override
  String get tasbeehEnableBeep => 'فعال کردن بوق';

  @override
  String get tasbeehTapToCount => 'برای شمردن ضربه بزنید';

  @override
  String get tasbeehMinusOne => 'یکی کم کن';

  @override
  String get tasbeehReset => 'بازنشانی';

  @override
  String get requestThanks => 'ممنون — درخواست شما را دریافت کردیم.';

  @override
  String get requestFailed => 'ارسال درخواست ممکن نشد. لطفاً دوباره تلاش کنید.';

  @override
  String get requestBookTitle => 'عنوان کتاب';

  @override
  String get requestZikrName => 'نام دعا، زیارت و غیره';

  @override
  String get requestBookDetails => 'نویسنده، مترجم یا پیوند (اختیاری)';

  @override
  String get requestZikrDetails => 'منبع، مناسبت یا پیوند (اختیاری)';

  @override
  String get commonSend => 'ارسال';

  @override
  String searchOneMatch(String source) {
    return 'یک مورد در $source';
  }

  @override
  String searchMatches(int count, String source) {
    return '$count مورد در $source';
  }

  @override
  String get searchSourceZikr => 'ذکر';

  @override
  String get searchSourceQuran => 'قرآن';

  @override
  String get searchSourceLibrary => 'کتابخانه';

  @override
  String get searchTitleOrUid => 'جستجوی عنوان یا UID';

  @override
  String get searchShow => 'نمایش';

  @override
  String get searchNoResults => 'نتیجه‌ای نیست';

  @override
  String get searchRequestIt => 'درخواستش کنید';

  @override
  String widgetPrayerTimesHelp(int min, int max) {
    return '$min تا $max وقت را انتخاب کنید. طلوع آفتاب، غروب آفتاب و نیمه‌شب مهلت‌هایی هستند که نماز باید پیش از آن‌ها خوانده شود.';
  }

  @override
  String get accountSessionExpired =>
      'نشست شما منقضی شد. لطفاً دوباره وارد شوید و حذف را دوباره امتحان کنید.';

  @override
  String get accountReauthenticate =>
      'برای امنیت، لطفاً دوباره وارد شوید و سپس حذف حساب را دوباره امتحان کنید.';

  @override
  String get accountPopupClosed => 'پنجرهٔ ورود پیش از پایان کار بسته شد.';

  @override
  String get accountNetworkError =>
      'خطای شبکه. لطفاً اتصال خود را بررسی و دوباره تلاش کنید.';

  @override
  String get commonSomethingWentWrong =>
      'مشکلی پیش آمد. لطفاً دوباره تلاش کنید.';

  @override
  String zikrTabNumber(int number) {
    return 'زبانه $number';
  }

  @override
  String get zikrBookmarked => 'نشان‌شده';

  @override
  String get zikrMoveBookmarkHere => 'انتقال نشانک به اینجا';

  @override
  String get zikrDragBookmarkHint =>
      'بکشید تا نشانک را به سطری دیگر منتقل کنید';

  @override
  String get durationUnderOneMinute => 'کمتر از ۱ دقیقه';

  @override
  String durationMinutes(int minutes) {
    return '$minutes دقیقه';
  }

  @override
  String durationHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours ساعت',
      one: 'یک ساعت',
    );
    return '$_temp0';
  }

  @override
  String durationHoursMinutes(String hours, int minutes) {
    return '$hours ساعت $minutes دقیقه';
  }

  @override
  String zikrReadingTime(String duration) {
    return '$duration خواندن';
  }

  @override
  String get zikrProgressCompleted => 'کامل شد';

  @override
  String airportNothingMatched(String query) {
    return 'هیچ‌چیز با «$query» مطابقت نداشت. به جایش کد سه‌حرفی را امتحان کنید.';
  }

  @override
  String get airportSearchLabel => 'کد فرودگاه یا شهر';

  @override
  String get airportSearchHint => 'مثلاً SFO، استانبول، نجف';

  @override
  String get airportSearchTitle => 'جستجوی فرودگاه';

  @override
  String get airportSearchDetail => 'کد فرودگاه، شهر یا نام کشوری را بنویسید.';

  @override
  String get airportNoneFound => 'فرودگاهی یافت نشد';

  @override
  String get counterTapAnywhere => 'برای شمردن هر جا ضربه بزنید';

  @override
  String get counterHoldToMove => 'نگه دارید و بکشید تا جابه‌جا شود';

  @override
  String get counterAddOne => 'یکی اضافه کن';

  @override
  String azanPaused(String prayer) {
    return 'اذان $prayer متوقف است';
  }

  @override
  String get azanPrayerFallback => 'نماز';

  @override
  String get reminderChannelDescription =>
      'یادآورهایی برای ذکرها و دعاهایی که زمان‌بندی کرده‌اید';

  @override
  String get locationOff => 'خدمات مکان خاموش است';

  @override
  String get locationPermissionShort => 'اجازهٔ مکان لازم است';

  @override
  String get locationNoFix => 'موقعیت مکان به دست نیامد';

  @override
  String get locationUpdateFailed => 'به‌روزرسانی مکان ممکن نشد';

  @override
  String quranPreviousUnit(String unit) {
    return '$unit قبلی';
  }

  @override
  String quranNextUnit(String unit) {
    return '$unit بعدی';
  }

  @override
  String get quranUnitSurah => 'سوره';

  @override
  String hadithNoResults(String query) {
    return 'نتیجه‌ای برای «$query» یافت نشد';
  }

  @override
  String get hadithTitle => 'حدیث';

  @override
  String get hadithSearchHint => 'جستجوی حدیث...';

  @override
  String get hadithNone => 'حدیثی در دسترس نیست';

  @override
  String favoritesReorder(String title) {
    return 'مرتب‌سازی دوبارهٔ $title';
  }

  @override
  String get favoritesReorderFailed =>
      'ذخیرهٔ ترتیب جدید ممکن نشد. دوباره تلاش کنید.';

  @override
  String get favoritesNone => 'هنوز علاقه‌مندی‌ای نیست.';

  @override
  String linkNotFoundRequested(String link) {
    return 'پیوند درخواستی: $link';
  }

  @override
  String get linkNotFoundTitle => 'پیوند یافت نشد';

  @override
  String get linkNotFoundBody => 'این محتوا را پیدا نکردیم.';

  @override
  String get linkNotFoundGoHome => 'رفتن به خانه';

  @override
  String get whatsNewTitle => 'تازه‌ها چیست';

  @override
  String get whatsNewGotIt => 'فهمیدم';

  @override
  String get pickerChooseZikr => 'ذکر یا دعایی انتخاب کنید';

  @override
  String get pickerSearchZikrHint => 'جستجوی ذکر، دعا، زیارت...';

  @override
  String get pickerNoMatches => 'موردی یافت نشد.';

  @override
  String get todaysNone => 'تلاوتی تنظیم نشده است.';

  @override
  String get scheduledFallbackTitle => 'اعلان زمان‌بندی‌شده';

  @override
  String get scheduledNone => 'اعلان زمان‌بندی‌شده‌ای نیست.';

  @override
  String newsLoadFailed(String error) {
    return 'بارگیری اخبار ناموفق بود: $error';
  }

  @override
  String get newsNoBrowser => 'مرورگر وبی یافت نشد';

  @override
  String get actionSaved => 'ذخیره شد';

  @override
  String get actionBookmark => 'نشانک';

  @override
  String get actionShare => 'اشتراک‌گذاری';

  @override
  String get actionListen => 'گوش دادن';

  @override
  String get actionSettings => 'تنظیمات';

  @override
  String get actionCounter => 'شمارنده';

  @override
  String get prayerEnableLocationBody =>
      'مکان را فعال کنید تا اوقات نماز دقیق منطقهٔ شما نمایش داده شود.';

  @override
  String statsDayRead(String day) {
    return '$day: خوانده شد';
  }

  @override
  String statsDayNotRead(String day) {
    return '$day: خوانده نشد';
  }

  @override
  String get qiblaDistance => 'فاصله';

  @override
  String get qiblaDirection => 'جهت';

  @override
  String get qiblaYouFace => 'شما رو به';

  @override
  String pickerAyahLabel(int ayah) {
    return 'آیه $ayah';
  }

  @override
  String hadithSharedVia(String link) {
    return 'از طریق Shia Companion به اشتراک گذاشته شد - $link';
  }

  @override
  String get requestTypeZikr => 'ذکر';

  @override
  String get requestTypeBook => 'کتاب';
}
