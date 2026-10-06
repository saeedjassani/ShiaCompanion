// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Shia Companion';

  @override
  String get settingsAppLanguage => 'لغة التطبيق';

  @override
  String get settingsTranslationLanguage => 'لغة الترجمة';

  @override
  String languageFollowDevice(String language) {
    return 'لغة الجهاز ($language)';
  }

  @override
  String languageFollowApp(String language) {
    return 'نفس لغة التطبيق ($language)';
  }

  @override
  String settingsDownloadedRecitationsUsed(String size) {
    return 'تم استخدام $size على هذا الجهاز';
  }

  @override
  String settingsHijriAhead(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'متقدم بـ$days يوم',
      many: 'متقدم بـ$days يومًا',
      few: 'متقدم بـ$days أيام',
      two: 'متقدم بيومين',
      one: 'متقدم بيوم واحد',
      zero: 'لا تقدّم في الأيام',
    );
    return '$_temp0';
  }

  @override
  String settingsHijriBehind(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'متأخر بـ$days يوم',
      many: 'متأخر بـ$days يومًا',
      few: 'متأخر بـ$days أيام',
      two: 'متأخر بيومين',
      one: 'متأخر بيوم واحد',
      zero: 'لا تأخّر في الأيام',
    );
    return '$_temp0';
  }

  @override
  String settingsLocationFailed(String message) {
    return '$message. اضغط للمحاولة مرة أخرى.';
  }

  @override
  String settingsLocationSaved(String city) {
    return 'الموقع المحفوظ الحالي: $city.';
  }

  @override
  String settingsLocationUpdated(String city, String age) {
    return '$city · تم التحديث $age. يُحدَّث تلقائيًا أثناء تنقّلك.';
  }

  @override
  String timeMinutesAgo(int minutes) {
    return 'قبل $minutes دقيقة';
  }

  @override
  String timeHoursAgo(int hours) {
    return 'قبل $hours ساعة';
  }

  @override
  String timeDaysAgo(int days) {
    return 'قبل $days يوم';
  }

  @override
  String settingsAdjustHijriBy(int days) {
    return 'ضبط التاريخ الهجري بمقدار $days يوم';
  }

  @override
  String settingsPrayerTimesShownSubtitle(String names) {
    return 'تظهر في الصفحة الرئيسية وأدوات الشاشة الرئيسية: $names.';
  }

  @override
  String settingsPrayerNotificationsAllOn(int count) {
    return 'مفعّلة لجميع الأوقات البالغ عددها $count.';
  }

  @override
  String settingsPrayerNotificationsSomeOn(
      String names, int enabled, int total) {
    return '$names · $enabled من $total مفعّلة';
  }

  @override
  String get settingsSectionPrayerLocation => 'الصلاة والموقع';

  @override
  String get settingsAdjustHijriDate => 'ضبط التاريخ الهجري';

  @override
  String get settingsPrayerTimesShown => 'أوقات الصلاة المعروضة';

  @override
  String get settingsRefreshLocation => 'تحديث الموقع';

  @override
  String get settingsLocationRefreshed => 'تم تحديث الموقع.';

  @override
  String get settingsSectionNotifications => 'الإشعارات';

  @override
  String get settingsPrayerNotifications => 'إشعارات الصلاة';

  @override
  String get settingsZikrReminders => 'تذكيرات الأذكار';

  @override
  String get settingsZikrRemindersSubtitle =>
      'احصل على تذكير بذكر في الأيام التي تختارها.';

  @override
  String get settingsPrecisePrayerAlarms => 'منبّهات الصلاة الدقيقة';

  @override
  String get settingsScheduledNotifications => 'الإشعارات المجدولة';

  @override
  String get settingsScheduledNotificationsSubtitle =>
      'مراجعة إشعارات الصلاة المعلّقة.';

  @override
  String get settingsSectionAppearance => 'المظهر';

  @override
  String get settingsDarkMode => 'الوضع الداكن';

  @override
  String get settingsDarkModeSubtitle =>
      'استخدام المظهر الداكن في جميع أنحاء التطبيق.';

  @override
  String get settingsAppTextSize => 'حجم نص التطبيق';

  @override
  String get settingsAppTextSizeSubtitle =>
      'تكبير أو تصغير جميع النصوص، بما فيها الأذكار.';

  @override
  String get settingsSectionZikrReading => 'قراءة الأذكار ومشاركتها';

  @override
  String get settingsSectionOfflineAudio => 'الصوت دون اتصال';

  @override
  String get settingsDownloadedRecitations => 'التلاوات المنزّلة';

  @override
  String get settingsDownloadedRecitationsEmpty => 'استمع دون اتصال بالإنترنت';

  @override
  String get settingsSectionSupport => 'الدعم';

  @override
  String get settingsRateApp => 'قيّم Shia Companion';

  @override
  String get settingsRateAppSubtitle => 'هل تستمتع بالتطبيق؟ اترك لنا تقييمًا.';

  @override
  String get settingsRequestContent => 'اطلب ذكرًا أو كتابًا';

  @override
  String get settingsRequestContentSubtitle =>
      'لا تجد دعاءً أو زيارة أو كتابًا؟ اطلب منا إضافته.';

  @override
  String get settingsFeedback => 'الملاحظات';

  @override
  String get settingsFeedbackSubtitle =>
      'أرسل الأسئلة أو المشكلات أو الاقتراحات.';

  @override
  String get settingsGithub => 'ساهم على GitHub';

  @override
  String get settingsGithubSubtitle =>
      'Shia Companion مفتوح المصدر. أبلغ عن المشكلات أو ساعد في تحسينه.';

  @override
  String get settingsGithubOpenFailed => 'تعذّر فتح GitHub';

  @override
  String get settingsAboutUs => 'من نحن';

  @override
  String get settingsSectionAccount => 'الحساب';

  @override
  String get settingsNotSignedIn => 'لم يتم تسجيل الدخول';

  @override
  String get settingsSignInPrompt => 'سجّل الدخول لمزامنة المفضلة عبر الأجهزة.';

  @override
  String get settingsLogout => 'تسجيل الخروج';

  @override
  String get settingsLogoutSubtitle => 'تسجيل الخروج من هذا الجهاز.';

  @override
  String get settingsDeleteAccount => 'حذف حسابي';

  @override
  String get settingsDeleteAccountSubtitle => 'إزالة بيانات حسابك نهائيًا.';

  @override
  String get settingsSignInGoogle => 'تسجيل الدخول باستخدام Google';

  @override
  String get settingsSignInGoogleSubtitle => 'مزامنة المفضلة وبيانات الحساب.';

  @override
  String get settingsSignInApple => 'تسجيل الدخول باستخدام Apple';

  @override
  String get settingsSignInAppleSubtitle => 'استخدم Apple ID لتسجيل الدخول.';

  @override
  String get settingsSignedIn => 'تم تسجيل الدخول';

  @override
  String get settingsSyncing => 'جارٍ مزامنة المفضلة وبيانات الحساب.';

  @override
  String get settingsHijriNoAdjustment => 'لا ضبط';

  @override
  String get settingsLocationUpdating => 'جارٍ تحديث موقعك…';

  @override
  String get settingsLocationUpdatePrompt => 'تحديث موقع أوقات الصلاة المحفوظ.';

  @override
  String get timeJustNow => 'الآن';

  @override
  String get settingsPrayerNotificationsOff =>
      'متوقفة. فعّلها ليتم إشعارك في أوقات الصلاة.';

  @override
  String get settingsPreciseAlarmsOn => 'مفعّلة لتوقيت الأذان الدقيق.';

  @override
  String get settingsPreciseAlarmsOff =>
      'متوقفة. قد يسلّم Android إشعارات الصلاة متأخرة قليلًا.';

  @override
  String get settingsNotificationsUnavailable => 'لم تتم تهيئة نظام الإشعارات';

  @override
  String get settingsPreciseAlarmsAlreadyOn =>
      'منبّهات الصلاة الدقيقة مفعّلة بالفعل.';

  @override
  String get settingsPreciseAlarmsDialogTitle =>
      'تفعيل منبّهات الصلاة الدقيقة؟';

  @override
  String get settingsPreciseAlarmsDialogBody =>
      'يتطلب Android إذن الوصول إلى المنبّهات والتذكيرات لكي تنطلق إشعارات الأذان في وقت الصلاة تمامًا. وبدون ذلك، تعمل التذكيرات لكنها قد تصل متأخرة قليلًا.';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonOpenSettings => 'فتح الإعدادات';

  @override
  String get settingsPreciseAlarmsEnabled => 'تم تفعيل منبّهات الصلاة الدقيقة.';

  @override
  String get settingsPreciseAlarmsNotEnabled =>
      'لم يتم تفعيل منبّهات الصلاة الدقيقة. وسيستمر استخدام التوقيت التقريبي.';

  @override
  String get settingsNoEmailApp => 'لم يتم العثور على تطبيق بريد إلكتروني';

  @override
  String get settingsLoginSuccessful => 'تم تسجيل الدخول بنجاح';

  @override
  String get settingsGoogleUnavailable =>
      'تسجيل الدخول باستخدام Google غير متاح حاليًا. حاول مرة أخرى.';

  @override
  String get commonNetworkError =>
      'تعذّر الاتصال. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';

  @override
  String get settingsGoogleFailed =>
      'لم ينجح تسجيل الدخول باستخدام Google. حاول مرة أخرى بعد قليل.';

  @override
  String get settingsAppleFailed => 'فشل تسجيل الدخول باستخدام Apple';

  @override
  String audioRecordingNumber(int number) {
    return 'التسجيل $number';
  }

  @override
  String playlistAddedTo(String name) {
    return 'أُضيف إلى $name';
  }

  @override
  String playlistAlreadyIn(String name) {
    return 'موجود بالفعل في $name';
  }

  @override
  String zikrCount(int count) {
    return '$count ذكر';
  }

  @override
  String get playlistsEmpty =>
      'أنشئ قائمة تشغيل بالأذكار التي تستمع إليها كل يوم — دعاء العهد وزيارة عاشوراء كل صباح مثلًا — وشغّلها كلها بضغطة واحدة.';

  @override
  String playlistDeleteConfirm(String name) {
    return 'حذف \"$name\"؟';
  }

  @override
  String get playlistDeleteKeepsDuasAndAudio =>
      'تبقى الأدعية نفسها في التطبيق، وكذلك صوتها المنزّل — أزله من التنزيلات لتحرير المساحة.';

  @override
  String get playlistEmpty =>
      'اضغط إضافة لاختيار الأذكار. يمكنك أيضًا إضافة ذكر من المشغّل في أي دعاء له صوت.';

  @override
  String audioRecordingsChosen(int chosen, int total) {
    return '$chosen من $total تسجيل';
  }

  @override
  String audioDownloadingPercent(int percent) {
    return 'جارٍ التنزيل $percent%';
  }

  @override
  String audioRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تسجيل',
      many: '$count تسجيلًا',
      few: '$count تسجيلات',
      two: 'تسجيلان',
      one: 'تسجيل واحد',
      zero: 'لا تسجيلات',
    );
    return '$_temp0';
  }

  @override
  String playlistNowPlayingPosition(String playlist, int position, int count) {
    return '$playlist · $position من $count';
  }

  @override
  String get playlistNameHint => 'مثال: الصباح';

  @override
  String get playlistOfflinePartial =>
      'أنت غير متصل — يتم تشغيل التسجيلات المنزّلة فقط';

  @override
  String get playlistNothingToPlay =>
      'لا يوجد في قائمة التشغيل هذه تسجيل يمكن تشغيله';

  @override
  String get playlistOfflineNothingDownloaded =>
      'أنت غير متصل ولا يوجد شيء منزّل في قائمة التشغيل هذه بعد';

  @override
  String get playlistStartFailed => 'تعذّر بدء قائمة التشغيل. حاول مرة أخرى.';

  @override
  String get playlistChooseRecordingsHint =>
      'اختر التسجيلات لتشغيلها في قائمة التشغيل هذه';

  @override
  String get commonDone => 'تم';

  @override
  String get playlistAddTo => 'إضافة إلى قائمة التشغيل';

  @override
  String get playlistNew => 'قائمة تشغيل جديدة';

  @override
  String get commonCreate => 'إنشاء';

  @override
  String get playlistsTitle => 'قوائم التشغيل';

  @override
  String get playlistDownloads => 'التنزيلات';

  @override
  String get commonPause => 'إيقاف مؤقت';

  @override
  String get commonPlay => 'تشغيل';

  @override
  String get playlistRename => 'إعادة تسمية قائمة التشغيل';

  @override
  String get commonSave => 'حفظ';

  @override
  String get playlistDeleteKeepsDuas => 'تبقى الأدعية نفسها في التطبيق.';

  @override
  String get commonDelete => 'حذف';

  @override
  String get playlistDeleted => 'تم حذف قائمة التشغيل هذه.';

  @override
  String get commonRename => 'إعادة التسمية';

  @override
  String get playlistRemoveDownloads => 'إزالة التنزيلات';

  @override
  String get playlistAllDownloads => 'جميع التنزيلات';

  @override
  String get commonAdd => 'إضافة';

  @override
  String get playlistResume => 'استئناف';

  @override
  String get playlistPlayAll => 'تشغيل الكل';

  @override
  String get audioDownloaded => 'تم التنزيل';

  @override
  String get audioDownloadFailed => 'لم يكتمل التنزيل';

  @override
  String get playlistOpenText => 'فتح النص';

  @override
  String get playlistChooseRecordings => 'اختيار التسجيلات';

  @override
  String get audioStopDownloading => 'إيقاف التنزيل';

  @override
  String get audioRemoveDownload => 'إزالة التنزيل';

  @override
  String get audioDownload => 'تنزيل';

  @override
  String get playlistRemoveZikr => 'إزالة من قائمة التشغيل';

  @override
  String get playlistAddZikr => 'إضافة ذكر';

  @override
  String get commonSearch => 'بحث';

  @override
  String get audioPartlyDownloaded => 'منزّل جزئيًا';

  @override
  String get playlistRepeatOn => 'التكرار مفعّل';

  @override
  String get playlistRepeat => 'تكرار قائمة التشغيل';

  @override
  String get commonPrevious => 'السابق';

  @override
  String get commonNext => 'التالي';

  @override
  String get commonStop => 'إيقاف';

  @override
  String flightTimesShownAt(String origin, String destination) {
    return 'الأوقات معروضة بحسب الساعة المحلية في $origin و$destination';
  }

  @override
  String flightDurationAndDistance(String duration, String distance) {
    return '$duration في الجو · $distance على الدائرة العظمى';
  }

  @override
  String flightAirportTime(String airport) {
    return 'بتوقيت $airport';
  }

  @override
  String flightOverPosition(String position) {
    return ' · فوق $position';
  }

  @override
  String flightAfterTakeoff(String duration) {
    return '$duration بعد الإقلاع';
  }

  @override
  String flightHorizonLater(int minutes) {
    return 'متأخر بـ$minutes دقيقة عن أفق الأرض في الأسفل';
  }

  @override
  String flightHorizonEarlier(int minutes) {
    return 'متقدم بـ$minutes دقيقة عن أفق الأرض في الأسفل';
  }

  @override
  String flightQiblaToRight(int degrees) {
    return '$degrees° إلى يمينك';
  }

  @override
  String flightQiblaToLeft(int degrees) {
    return '$degrees° إلى يسارك';
  }

  @override
  String flightQiblaLine(int bearing, String compass, String relative) {
    return 'القبلة $bearing° ($compass) — $relative بالنسبة لاتجاه الطيران';
  }

  @override
  String flightAltitudeHorizonBody(String altitude, String dip) {
    return 'على ارتفاع $altitude يقع الأفق أخفض بنحو $dip° منه على الأرض، لذا تستغرق الشمس وقتًا أطول للغروب ويأتي الفجر أبكر. وهذا يؤخّر المغرب والعشاء نحو عشرين دقيقة، ويقدّم الفجر نحو عشرين دقيقة، مقارنة بأوقات الأرض تحتك — يعرض كل صف مقدار إزاحته الخاصة. وأيّ الأفقين يحكم الصلاة فمسألة تعود إلى مرجعك، لا يمكن لهذا التطبيق أن يحسمها.';
  }

  @override
  String flightAltitudeFeet(String feet) {
    return '$feet قدم';
  }

  @override
  String get flightTitleFallback => 'رحلة';

  @override
  String get flightEdit => 'تعديل الرحلة';

  @override
  String get flightCheckTimes => 'تحقق من أوقات الرحلة';

  @override
  String get flightCheckTimesBody =>
      'الوصول ليس بعد المغادرة عند تطبيق المنطقة الزمنية لكل مطار. اضغط تعديل لتصحيح التواريخ.';

  @override
  String get flightInTheAir => 'في الجو';

  @override
  String get flightNoPrayerDuring => 'لا تحين أي صلاة أثناء هذه الرحلة';

  @override
  String get flightNoPrayerDuringBody =>
      'تقع جميع أوقات الصلاة إما قبل الإقلاع أو بعد الهبوط.';

  @override
  String get flightNotDuring => 'ليس أثناء هذه الرحلة';

  @override
  String get flightEndOfIshaWindow => 'نهاية وقت العشاء · ';

  @override
  String get flightStraightAhead => 'مباشرة أمامك';

  @override
  String get flightDirectlyBehind => 'مباشرة خلفك';

  @override
  String get flightIshaClosedBeforeTakeoff => 'انتهى وقت العشاء قبل الإقلاع.';

  @override
  String get flightAlreadyInBeforeTakeoff =>
      'حان قبل الإقلاع — استخدم أوقات الصلاة لمدينة المغادرة.';

  @override
  String get flightIshaOpenUntilLanding =>
      'لا ينتهي وقت العشاء إلا بعد الهبوط.';

  @override
  String get flightAfterLanding =>
      'يحين بعد الهبوط — استخدم أوقات الصلاة لوجهتك.';

  @override
  String get flightSunAngleNeverReached =>
      'لا تصل الشمس أبدًا إلى الزاوية المطلوبة في أي نقطة من هذا المسار، فلا يمكن حساب وقت.';

  @override
  String get flightHowWorkedOut => 'كيف يتم حسابها';

  @override
  String get flightHowWorkedOutBody =>
      'يُفترض أن الطائرة تتبع مسار الدائرة العظمى بسرعة ثابتة، ويُحسب كل وقت صلاة بحسب موقع الطائرة عند حلول ذلك الوقت. تأخّر ساعة يحرّك هذه الأوقات نحو نصف ساعة، والالتفاف حول الطقس قد يحرّكها من عشر إلى عشرين دقيقة، لذا اعتبرها قريبة لا دقيقة تمامًا.';

  @override
  String get flightHorizonAtAltitude => 'مقاسًا من الأفق على الارتفاع';

  @override
  String get flightHorizonAtGround => 'مقاسًا من الأفق على مستوى الأرض';

  @override
  String get flightGroundHorizonBody =>
      'تتبع الأوقات أفق الأرض تحت الطائرة. من المقصورة تغرب الشمس متأخرة وينبلج الفجر أبكر مما هو معروض، بنحو عشرين دقيقة على ارتفاع التحليق.';

  @override
  String get flightHighLatitude => 'يعبر هذا المسار خطوط عرض عالية';

  @override
  String get flightHighLatitudeBody =>
      'فوق 48° تقريبًا، قد لا تنخفض الشمس بما يكفي تحت الأفق ليحدث الفجر والغسق بشكل طبيعي. عندها تعود أوقات الفجر والمغرب والعشاء إلى تقدير نسبي لليل. وتختلف أحكام الصلاة عند خطوط العرض العالية — يرجى اتباع مرجعك.';

  @override
  String get flightSomeNotCalculated => 'تعذّر حساب بعض أوقات الصلاة';

  @override
  String get flightSomeNotCalculatedBody =>
      'تبقى الشمس فوق الزاوية المطلوبة طوال المسار، فلا وقت محسوب لتلك الصلوات. اتبع حكم مرجعك في هذه الظروف.';

  @override
  String get flightTimeZonesFailed => 'تعذّر تحميل المناطق الزمنية';

  @override
  String get flightTimeZonesFailedBody =>
      'أحد هذين المطارين له منطقة زمنية لا تتعرف عليها هذه النسخة. اضغط تعديل لاختيار المطارات مرة أخرى.';

  @override
  String get prayerFajr => 'الفجر';

  @override
  String get prayerSunrise => 'الشروق';

  @override
  String get prayerZuhr => 'الظهر';

  @override
  String get prayerAsr => 'العصر';

  @override
  String get prayerSunset => 'الغروب';

  @override
  String get prayerMaghrib => 'المغرب';

  @override
  String get prayerIsha => 'العشاء';

  @override
  String get prayerMidnight => 'منتصف الليل';

  @override
  String locationErrorBody(String error) {
    return 'حدث خطأ أثناء الحصول على موقعك: $error\n\nيرجى التحقق من تفعيل خدمات الموقع والمحاولة مرة أخرى.';
  }

  @override
  String notificationReopenAppBody(int days) {
    return 'يبدو أنك لم تستخدم التطبيق في آخر $days يوم. يرجى فتح التطبيق لمواصلة تلقّي إشعارات الأذان';
  }

  @override
  String notificationPrayerTime(String prayer) {
    return 'حان وقت $prayer';
  }

  @override
  String notificationTapToPlayCustom(String message) {
    return '$message · اضغط لتشغيل صوتك';
  }

  @override
  String notificationTapToPlayAzan(String message) {
    return '$message · اضغط لسماع الأذان كاملًا';
  }

  @override
  String get locationEnableTitle => 'تفعيل الموقع لأوقات الصلاة';

  @override
  String get locationEnableBody =>
      'أوقات الصلاة خاصة بموقعك. نستخدم موقعك أثناء استخدامك التطبيق لنقدم لك أوقات صلاة دقيقة لمنطقتك.';

  @override
  String get commonContinue => 'متابعة';

  @override
  String get locationServicesDisabledTitle => 'خدمات الموقع معطّلة';

  @override
  String get locationServicesDisabledBody =>
      'خدمات الموقع متوقفة. يرجى تفعيلها في إعدادات جهازك للحصول على أوقات صلاة دقيقة لمنطقتك.';

  @override
  String get locationPermissionDeniedForever =>
      'تم رفض إذن الموقع نهائيًا. يرجى فتح إعدادات التطبيق ومنح إذن الموقع للحصول على أوقات صلاة دقيقة.';

  @override
  String get locationPermissionUnknown =>
      'تعذّر تحديد حالة إذن الموقع. يرجى فتح إعدادات التطبيق والتأكد من منح إذن الموقع.';

  @override
  String get locationPermissionNeeded =>
      'يلزم إذن الموقع لعرض أوقات صلاة دقيقة لمنطقتك.';

  @override
  String get locationPermissionTitle => 'يلزم إذن الموقع';

  @override
  String get locationTimeoutTitle => 'انتهت مهلة الموقع';

  @override
  String get locationTimeoutBody =>
      'تعذّر الحصول على موقعك في الوقت المتوقع. قد يكون ذلك بسبب ضعف إشارة GPS أو مشكلات في الشبكة. حاول مرة أخرى.';

  @override
  String get locationErrorTitle => 'خطأ في الموقع';

  @override
  String get notificationReopenAppTitle =>
      'افتح التطبيق لمواصلة تلقي إشعارات الأذان';

  @override
  String get notificationChannelTakbir => 'أوقات الصلاة - تكبير';

  @override
  String get notificationChannelSystemDefault =>
      'أوقات الصلاة - الافتراضي للنظام';

  @override
  String get notificationChannelSilent => 'أوقات الصلاة - صامت';

  @override
  String get notificationChannelCustom => 'أوقات الصلاة - صوت مخصص';

  @override
  String get notificationChannelFullAzan => 'أوقات الصلاة - الأذان الكامل';

  @override
  String get notificationChannelSilentDescription =>
      'إشعارات صامتة لأوقات الصلاة';

  @override
  String get notificationChannelDescription => 'إشعارات أوقات الصلاة';

  @override
  String get notificationChannelGeneral => 'عام';

  @override
  String qiblaNeedsCalibratingBody(int degrees) {
    return 'القراءات منحرفة بنحو $degrees°. حرّك الهاتف على شكل الرقم ثمانية عدة مرات، بعيدًا عن أي معدن أو مغناطيس.';
  }

  @override
  String qiblaBearingFromNorth(String place, String bearing) {
    return '$place باتجاه $bearing من الشمال الحقيقي';
  }

  @override
  String qiblaFacing(String place) {
    return 'تواجه $place';
  }

  @override
  String qiblaTurnRight(int degrees) {
    return 'استدر يمينًا $degrees°';
  }

  @override
  String qiblaTurnLeft(int degrees) {
    return 'استدر يسارًا $degrees°';
  }

  @override
  String qiblaDeclinationEast(String degrees) {
    return 'الشمال المغناطيسي يقع $degrees° شرق الشمال الحقيقي في موقعك، ويتم تصحيح القراءة له تلقائيًا.';
  }

  @override
  String qiblaDeclinationWest(String degrees) {
    return 'الشمال المغناطيسي يقع $degrees° غرب الشمال الحقيقي في موقعك، ويتم تصحيح القراءة له تلقائيًا.';
  }

  @override
  String get qiblaDistanceHere => 'هنا';

  @override
  String get qiblaTitle => 'محدّد القبلة';

  @override
  String get qiblaAboutCompass => 'حول هذه البوصلة';

  @override
  String get qiblaLocationNeeded => 'يلزم الموقع';

  @override
  String get qiblaLocationNeededBody =>
      'يعتمد الاتجاه على مكانك. شارك موقعك وستشير البوصلة لحظة وصول إحداثياته.';

  @override
  String get qiblaUseMyLocation => 'استخدم موقعي';

  @override
  String get qiblaTurnOnCompass => 'شغّل البوصلة';

  @override
  String get qiblaTurnOnCompassBody =>
      'يحتاج هذا المتصفح إذنك قبل أن يبلّغ عن اتجاه الهاتف.';

  @override
  String get qiblaAllowCompass => 'السماح بالبوصلة';

  @override
  String get qiblaCompassBlocked => 'البوصلة محجوبة';

  @override
  String get qiblaCompassBlockedBody =>
      'تم رفض الوصول إلى الحركة والاتجاه، لذا يبقى القرص مثبّتًا نحو الشمال. اسمح به في إعدادات المتصفح، أو استدر حتى يتطابق شمال القرص مع الشمال من حولك.';

  @override
  String get qiblaNoCompass => 'لا بوصلة على هذا الجهاز';

  @override
  String get qiblaNoCompassBody =>
      'يبقى القرص مثبّتًا نحو الشمال بدلًا من ذلك. واجه الشمال، وتُظهر الإبرة الاتجاه من هناك.';

  @override
  String get qiblaNeedsCalibrating => 'البوصلة تحتاج إلى معايرة';

  @override
  String get qiblaLocationUnknown => 'الموقع غير معروف';

  @override
  String get qiblaUpdateLocation => 'تحديث الموقع';

  @override
  String get qiblaPointingTowards => 'يشير نحو';

  @override
  String get qiblaWaitingForLocation => 'في انتظار موقعك';

  @override
  String get qiblaPointTowards => 'وجّه نحو';

  @override
  String get qiblaGreatCircleBody =>
      'تشير الإبرة على طول مسار الدائرة العظمى — أقصر طريق على سطح الأرض، وهو الاتجاه الذي تُعرَّف به القبلة. على خريطة مسطّحة قد يبدو مفاجئًا؛ فمن أمريكا الشمالية تقع الكعبة نحو الشمال الشرقي تقريبًا، لا الجنوب الشرقي.';

  @override
  String get qiblaDeclinationUnknownBody =>
      'يقيس هاتفك الزاوية إلى الشمال المغناطيسي، الذي يختلف عن الشمال الحقيقي بمقدار يعتمد على مكانك. يُطبّق هذا التصحيح تلقائيًا بمجرد معرفة موقعك.';

  @override
  String get qiblaSteadyReadingBody =>
      'للحصول على قراءة ثابتة، احمل الهاتف مسطّحًا وأبعده عن الحواسيب المحمولة ومكبّرات الصوت ولوحات قيادة السيارات وأي شيء فيه مغناطيس.';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get weekdayShortMon => 'الاثنين';

  @override
  String get weekdayShortTue => 'الثلاثاء';

  @override
  String get weekdayShortWed => 'الأربعاء';

  @override
  String get weekdayShortThu => 'الخميس';

  @override
  String get weekdayShortFri => 'الجمعة';

  @override
  String get weekdayShortSat => 'السبت';

  @override
  String get weekdayShortSun => 'الأحد';

  @override
  String reminderMinutesRange(int max) {
    return 'أدخل عدد دقائق بين 0 و$max.';
  }

  @override
  String get reminderTitleRequired => 'يرجى إدخال عنوان لهذا التذكير.';

  @override
  String get reminderPickDay => 'اختر يومًا واحدًا على الأقل.';

  @override
  String get reminderSavedPendingLocation =>
      'تم الحفظ. سيبدأ العمل بمجرد توفر موقع أوقات الصلاة.';

  @override
  String get reminderEditTitle => 'تعديل التذكير';

  @override
  String get reminderNewTitle => 'تذكير جديد';

  @override
  String get reminderWhat => 'ماذا';

  @override
  String get reminderWhatHint =>
      'اختر ذكرًا من المكتبة، أو اكتب عنوانًا أدناه.';

  @override
  String get reminderChooseZikr => 'اختر من مكتبة الأذكار';

  @override
  String get reminderChangeZikr => 'تغيير الذكر';

  @override
  String get reminderTitleLabel => 'العنوان';

  @override
  String get reminderTitleHint => 'مثال: دعاء التوسل';

  @override
  String get reminderRepeatOn => 'التكرار في';

  @override
  String get reminderWhen => 'متى';

  @override
  String get reminderFixedTime => 'وقت ثابت';

  @override
  String get reminderPrayerRelative => 'نسبة إلى الصلاة';

  @override
  String get commonSaveChanges => 'حفظ التغييرات';

  @override
  String get reminderAdd => 'إضافة تذكير';

  @override
  String get reminderTime => 'الوقت';

  @override
  String get reminderPrayer => 'الصلاة';

  @override
  String get reminderMinutes => 'الدقائق';

  @override
  String get reminderBefore => 'قبل';

  @override
  String get reminderAfter => 'بعد';

  @override
  String get reminderPrayerRelativeNote =>
      'تتغيّر أوقات الصلاة مع التقويم، لذا يجدول هذا وقائع الأسابيع القليلة المقبلة ويحدّثها في كل مرة تفتح فيها التطبيق.';

  @override
  String qazaCompletedCount(int count) {
    return 'اكتمل $count';
  }

  @override
  String get qazaPrayed => 'قضيت';

  @override
  String get qazaFasted => 'صمت';

  @override
  String qazaEstimatePrayers(String days, String prayers) {
    return '$days من كل صلاة يومية ($prayers صلاة)';
  }

  @override
  String qazaEstimateFasts(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صيام',
      many: '$count يوم صيام',
      few: '$count أيام صيام',
      two: '$count صيامان',
      one: '$count صيام',
      zero: 'لا صيام',
    );
    return '$_temp0';
  }

  @override
  String qazaLunarNote(int yearDays, int monthDays) {
    return 'تُحسب كسنوات قمرية من $yearDays يومًا وأشهر من $monthDays يومًا.';
  }

  @override
  String get qazaTitle => 'متتبع القضاء';

  @override
  String get qazaCalculate => 'احسب قضائي';

  @override
  String get qazaPrayers => 'الصلوات';

  @override
  String get qazaFasts => 'الصيام';

  @override
  String get qazaRemaining => 'القضاء المتبقي';

  @override
  String get commonUndo => 'تراجع';

  @override
  String get qazaMissed => 'فاتت';

  @override
  String get qazaEditCount => 'تعديل العدد';

  @override
  String get qazaMissedAWhile => 'فاتتك صلوات منذ مدة؟';

  @override
  String get qazaMissedAWhileBody =>
      'أدخل المدة، وسنضيف واحدة من كل صلاة يومية عن كل يوم فات.';

  @override
  String get qazaPrayedFullDay => 'قضيت يومًا كاملًا';

  @override
  String get qazaLoggedFullDay => 'تم تسجيل واحدة من كل صلاة يومية';

  @override
  String get qazaAddedToList => 'أُضيف إلى قائمة القضاء';

  @override
  String get qazaRemainingLabel => 'المتبقي';

  @override
  String get qazaCompletedLabel => 'المكتمل';

  @override
  String get commonClear => 'مسح';

  @override
  String get qazaCalculateBody =>
      'كم من الوقت تقريبًا لم تصلِّ؟ يكفي تقدير تقريبي — يمكنك تعديل أي صلاة لاحقًا.';

  @override
  String get qazaPrayersMissedFor => 'صلوات فائتة لمدة';

  @override
  String get qazaYears => 'السنوات';

  @override
  String get qazaMonths => 'الأشهر';

  @override
  String get qazaDays => 'الأيام';

  @override
  String get qazaFastsMissed => 'الصيام الفائت';

  @override
  String get qazaNumberOfFasts => 'عدد أيام الصيام';

  @override
  String get qazaThisAdds => 'يضيف هذا إلى قائمتك:';

  @override
  String get qazaAddToList => 'إضافة إلى قائمتي';

  @override
  String get qazaDhuhr => 'الظهر';

  @override
  String get qazaAyat => 'صلاة الآيات';

  @override
  String get qazaOther => 'أخرى';

  @override
  String audioMobileDataSizedBody(String size) {
    return 'أنت لست على Wi-Fi. سيستخدم هذا نحو $size من بيانات الهاتف.';
  }

  @override
  String get audioRemoveDownloadsTitle => 'إزالة التنزيلات؟';

  @override
  String get audioRemoveDownloadTitle => 'إزالة التنزيل؟';

  @override
  String audioRemoveBody(String subject) {
    return 'سيتم بث $subject مجددًا، لذا ستحتاج إلى اتصال للاستماع.';
  }

  @override
  String get audioTheseRecitations => 'هذه التلاوات';

  @override
  String get audioThisRecitation => 'هذه التلاوة';

  @override
  String audioQuotedName(String name) {
    return '\"$name\"';
  }

  @override
  String audioRemoveFrees(String size) {
    return 'يحرّر $size.';
  }

  @override
  String get audioDownloadDone => 'تم التنزيل - يُشغَّل دون اتصال';

  @override
  String audioDownloadDoneNamed(String name) {
    return 'تم تنزيل $name - يُشغَّل دون اتصال';
  }

  @override
  String get audioTheseRecitationsLower => 'هذه التلاوات';

  @override
  String get audioThisRecitationLower => 'هذه التلاوة';

  @override
  String audioDownloadPartial(int saved, int total) {
    return 'تم تنزيل $saved من $total.';
  }

  @override
  String audioDownloadFailedNamed(String what) {
    return 'تعذّر تنزيل $what.';
  }

  @override
  String get audioDownloadOutOfSpace =>
      'نفدت مساحة جهازك - حرّر بعضها وحاول مرة أخرى.';

  @override
  String get audioDownloadUnavailable => 'لم تعد إحدى التلاوات متاحة.';

  @override
  String get audioDownloadCheckConnection => 'تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String commonPercent(int percent) {
    return '$percent%';
  }

  @override
  String audioDownloadMore(int count) {
    return 'تنزيل $count أخرى';
  }

  @override
  String get audioDownloadAll => 'تنزيل الكل';

  @override
  String get audioDownloadForOffline => 'التنزيل للاستماع دون اتصال';

  @override
  String get audioOfflineCannotDownload =>
      'أنت غير متصل. اتصل بالإنترنت للتنزيل.';

  @override
  String get audioMobileDataTitle => 'التنزيل باستخدام بيانات الهاتف؟';

  @override
  String get audioMobileDataBody =>
      'أنت لست على Wi-Fi. قد تكون التلاوات كبيرة، لذا قد يستخدم هذا الكثير من بيانات الهاتف.';

  @override
  String get commonRemove => 'إزالة';

  @override
  String get audioDownloading => 'جارٍ التنزيل';

  @override
  String get audioDownloadingEllipsis => 'جارٍ التنزيل…';

  @override
  String get audioDownloadedTooltip =>
      'منزّل للاستماع دون اتصال. اضغط للإزالة.';

  @override
  String get audioRetryDownload => 'إعادة محاولة التنزيل';

  @override
  String get audioDownloadFailedTooltip =>
      'لم يكتمل التنزيل. اضغط لإعادة المحاولة.';

  @override
  String get audioDownloadRestTooltip => 'تنزيل الباقي للاستماع دون اتصال';

  @override
  String get counterSemanticsLabel => 'الركعات والسجدات الحالية';

  @override
  String counterRakaatCompleted(int count) {
    return 'اكتملت $count ركعة';
  }

  @override
  String counterPosition(int rakaat, int sajdah) {
    return 'الركعة $rakaat · السجدة $sajdah';
  }

  @override
  String counterSajdahProgress(int done, int total) {
    return '$done من $total سجدة';
  }

  @override
  String get counterSensorStopped =>
      'توقف مستشعر التقارب عن الاستجابة. تحقق من موضع الهاتف وفعّل الاستشعار التلقائي مجددًا.';

  @override
  String get counterStartOverTitle => 'البدء من جديد؟';

  @override
  String get counterStartOverBody =>
      'سيؤدي تغيير عدد الركعات إلى إعادة ضبط عدّ الصلاة الحالي.';

  @override
  String get counterStartOver => 'البدء من جديد';

  @override
  String get counterTitle => 'عدّاد الركعات';

  @override
  String get counterHowToPlace => 'كيفية وضع هاتفك';

  @override
  String get counterPlaceBelowTurbah => 'ضع الهاتف أسفل التربة';

  @override
  String get counterPlaceBelowTurbahBody =>
      'ضعه مسطّحًا أسفل التربة، وحافته العلوية باتجاهها. أبقِ مسار جبهتك خاليًا.';

  @override
  String get counterPrayerLength => 'طول الصلاة';

  @override
  String get counterSelectRakaat => 'اختر عدد الركعات';

  @override
  String get counterComplete => 'مكتمل';

  @override
  String get counterSajdahDetected => 'تم اكتشاف سجدة';

  @override
  String get counterSensorReady => 'المستشعر جاهز';

  @override
  String get counterCheckingSensor => 'جارٍ فحص المستشعر';

  @override
  String get counterSensingOff => 'الاستشعار التلقائي متوقف';

  @override
  String get counterTapHint => 'اضغط فقط إذا لم تُكتشف سجدة تلقائيًا';

  @override
  String get counterReady => 'جاهز للسجدة الأولى';

  @override
  String get counterAutomaticHint => 'عدّ تلقائي · اضغط فقط إذا فاتت واحدة';

  @override
  String get counterManualHint => 'اضغط البطاقة لإضافة سجدة يدويًا';

  @override
  String get counterCheckingDevice => 'جارٍ فحص هذا الجهاز…';

  @override
  String get counterNotAvailable => 'العدّ التلقائي غير متاح على هذا الجهاز.';

  @override
  String get counterObjectDetected =>
      'تم اكتشاف جسم. ابتعد ليتهيأ العدّ التالي.';

  @override
  String get counterSensorArmed => 'جاهز — كل سجدة مكتشفة تُحسب مرة واحدة.';

  @override
  String get counterSensorOffSubtitle =>
      'متوقف — فعّل هذا لعدّ السجدات تلقائيًا.';

  @override
  String get counterAutomaticSensing => 'الاستشعار التلقائي';

  @override
  String get counterIphoneNote =>
      'على iPhone، قد تنطفئ الشاشة قليلًا أثناء تغطية المستشعر. يختلف موضع المستشعر ومداه حسب الطراز.';

  @override
  String get counterAndroidNote =>
      'يختلف موضع المستشعر ومداه حسب الهاتف. تستخدم بعض هواتف Android مستشعر تقارب افتراضيًا أقل موثوقية.';

  @override
  String get counterPhonePlacement => 'موضع الهاتف';

  @override
  String get counterPlacementBody =>
      'ضع الهاتف مسطّحًا أسفل التربة، وحافته العلوية ومستشعره باتجاهها. أبقِ الهاتف خارج مسار جبهتك تمامًا.';

  @override
  String get counterPlacementTest =>
      'قبل البدء، فعّل المستشعر واختبره بيدك. أبعد يدك بعد كل اختبار ليتهيأ العدّ التالي.';

  @override
  String quranJuzNumber(int number) {
    return 'الجزء $number';
  }

  @override
  String quranCopiedVerse(String verse) {
    return 'تم نسخ $verse';
  }

  @override
  String get quranRemoveFromSaved => 'إزالة من المحفوظة';

  @override
  String get quranSaveVerse => 'حفظ الآية';

  @override
  String quranRemovedVerse(String verse) {
    return 'أُزيل $verse';
  }

  @override
  String quranSavedVerse(String verse) {
    return 'تم حفظ $verse';
  }

  @override
  String zikrPartNumber(int number) {
    return 'الجزء $number';
  }

  @override
  String zikrBookmarkMoveHint(String icon) {
    return 'تم وضع الإشارة. لنقلها لاحقًا، اسحب $icon على ملصق «المحفوظة بإشارة» إلى سطر آخر.';
  }

  @override
  String get quranCopyVerse => 'نسخ الآية';

  @override
  String get quranCopyLink => 'نسخ الرابط';

  @override
  String get quranLinkCopied => 'تم نسخ الرابط';

  @override
  String get quranShareVerse => 'مشاركة الآية';

  @override
  String get zikrMerits => 'الفضائل';

  @override
  String get zikrReportThanks => 'شكرًا - سنلقي نظرة.';

  @override
  String get zikrReportFailed => 'تعذّر إرسال التقرير. حاول مرة أخرى.';

  @override
  String get zikrSuggestCorrection => 'اقتراح تصحيح';

  @override
  String get zikrSelectedText => 'النص المحدد';

  @override
  String get zikrCorrectionHint =>
      'ما الذي ينبغي أن يكون بدلًا من ذلك؟ (اختياري)';

  @override
  String get commonSubmit => 'إرسال';

  @override
  String get zikrSetReminder => 'تعيين تذكير';

  @override
  String get zikrUnableToOpen => 'تعذّر فتح هذا الدعاء.';

  @override
  String get zikrComingSoon => 'قريبًا...';

  @override
  String get zikrHideCounter => 'إخفاء العدّاد';

  @override
  String deleteAccountSignInFailed(String error) {
    return 'فشل تسجيل الدخول: $error';
  }

  @override
  String deleteAccountSignOutFailed(String error) {
    return 'فشل تسجيل الخروج: $error';
  }

  @override
  String deleteAccountFailed(String error) {
    return 'خطأ في حذف الحساب: $error';
  }

  @override
  String deleteAccountSignedInAs(String account) {
    return 'أنت مسجّل الدخول باسم $account.';
  }

  @override
  String get deleteAccountSignedIn => 'تم تسجيل الدخول بنجاح.';

  @override
  String get deleteAccountSignedOut => 'تم تسجيل الخروج.';

  @override
  String get deleteAccountConfirmTitle => 'حذف الحساب؟';

  @override
  String get deleteAccountConfirmBody =>
      'هذا يحذف حساب Shia Companion ومفضلتك المتزامنة نهائيًا.';

  @override
  String get deleteAccountDone => 'تم حذف الحساب بنجاح.';

  @override
  String get deleteAccountTitle => 'حذف الحساب';

  @override
  String get deleteAccountHeading => 'إدارة حساب Shia Companion';

  @override
  String get deleteAccountSignInPrompt =>
      'سجّل الدخول لمراجعة وحذف الحساب المرتبط بمفضلتك المتزامنة نهائيًا.';

  @override
  String get deleteAccountWhatGetsDeleted => 'ما الذي يُحذف';

  @override
  String get deleteAccountItemSignIn =>
      'سجلّ تسجيل دخول حساب Shia Companion الخاص بك.';

  @override
  String get deleteAccountItemFavorites =>
      'مفضلتك المتزامنة ومتتبع القضاء المخزّنان لذلك الحساب.';

  @override
  String get deleteAccountItemPreferences =>
      'تفضيلات القراءة المتزامنة — ضبط التاريخ الهجري وخيارات الخط.';

  @override
  String get deleteAccountItemAnalytics =>
      'قد تبقى التحليلات المجهولة أو تقارير الأعطال التي جُمعت بالفعل بشكل إجمالي.';

  @override
  String get deleteAccountCompleted => 'اكتمل طلب حذف حسابك.';

  @override
  String get deleteAccountCompletedNote =>
      'إذا سجّلت الدخول مجددًا لاحقًا، سيُنشأ حساب جديد تمامًا.';

  @override
  String get deleteAccountWebSteps =>
      'استخدم زر تسجيل الدخول بـ Google أدناه، ثم أكّد الحذف.';

  @override
  String get deleteAccountAppSteps =>
      'افتح التفضيلات في التطبيق واستخدم حذف حسابي.';

  @override
  String get deleteAccountSigningIn => 'جارٍ تسجيل الدخول...';

  @override
  String get deleteAccountDeleting => 'جارٍ الحذف...';

  @override
  String get deleteAccountButton => 'حذف حسابي';

  @override
  String get deleteAccountSignOut => 'تسجيل الخروج';

  @override
  String get deleteAccountHelp =>
      'تحتاج مساعدة؟ راسل developer110@hotmail.com واذكر عنوان البريد المرتبط بحسابك.';

  @override
  String statsBestStreak(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'الأفضل: $days يوم',
      many: 'الأفضل: $days يومًا',
      few: 'الأفضل: $days أيام',
      two: 'الأفضل: يومان',
      one: 'الأفضل: يوم واحد',
      zero: 'الأفضل: لا أيام',
    );
    return '$_temp0';
  }

  @override
  String get statsTodayDone => 'اليوم: تم';

  @override
  String get statsTodayNotYet => 'اليوم: ليس بعد';

  @override
  String statsDaysToGoal(int remaining, Object goal) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$remaining يوم آخر للوصول إلى سلسلة الهدف',
      many: '$remaining يومًا آخر للوصول إلى سلسلة الهدف',
      few: '$remaining أيام أخرى للوصول إلى سلسلة الهدف',
      two: 'يومان آخران للوصول إلى سلسلة الهدف',
      one: 'يوم آخر للوصول إلى سلسلة الهدف',
      zero: 'بلغت هدف السلسلة',
    );
    return '$_temp0';
  }

  @override
  String statsUpdatedHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'تم التحديث قبل $hours ساعة',
      many: 'تم التحديث قبل $hours ساعة',
      few: 'تم التحديث قبل $hours ساعات',
      two: 'تم التحديث قبل ساعتين',
      one: 'تم التحديث قبل ساعة',
      zero: 'تم التحديث الآن',
    );
    return '$_temp0';
  }

  @override
  String statsUpdatedOn(String date) {
    return 'تم التحديث $date';
  }

  @override
  String statsAllTime(String count) {
    return '$count إجمالًا';
  }

  @override
  String statsCommunityNote(String updated) {
    return 'مجاميع مجهولة من جميع مستخدمي التطبيق. $updated.';
  }

  @override
  String get statsTitle => 'إحصائياتي';

  @override
  String get statsYourMostRecited => 'الأكثر تلاوة لديك';

  @override
  String get statsStreakStart =>
      'أنهِ قراءة دعاء أو زيارة أو سورة وستبدأ سلسلتك.';

  @override
  String get statsWelcomeBack => 'أهلًا بعودتك - كل يوم بداية جديدة.';

  @override
  String get statsDoneTodayFirst => 'تم لليوم. عد غدًا لبدء سلسلة.';

  @override
  String get statsDoneToday => 'تم لليوم - نراك غدًا إن شاء الله.';

  @override
  String get statsReadToday => 'اقرأ شيئًا اليوم لمواصلتها.';

  @override
  String get statsDayStreak => 'سلسلة أيام';

  @override
  String get statsToday => 'اليوم';

  @override
  String get statsPrivateSynced =>
      'إحصائياتك خاصة وتتزامن عبر الأجهزة المسجّلة في حسابك.';

  @override
  String get statsPrivateLocal =>
      'إحصائياتك خاصة ومحفوظة على هذا الجهاز. سجّل الدخول من التفضيلات لحفظها عبر الأجهزة.';

  @override
  String get statsUpdatedWithinHour => 'تم التحديث خلال الساعة';

  @override
  String get statsAcrossCommunity => 'عبر المجتمع';

  @override
  String get statsRecitedThisWeek => 'أدعية وزيارات وسور تُليت هذا الأسبوع';

  @override
  String get statsMostRecitedThisWeek => 'الأكثر تلاوة هذا الأسبوع';

  @override
  String quranSurahNumber(int number) {
    return 'السورة $number';
  }

  @override
  String get listenQuranTextFailed => 'تعذّرت قراءة نص القرآن على هذا الجهاز.';

  @override
  String get listenRecogniserStopped =>
      'توقف المعرّف بشكل غير متوقع. حاول مرة أخرى.';

  @override
  String get listenNothingRecognised =>
      'لم يصل شيء يمكن التعرف عليه. حاول مرة أخرى، أقرب قليلًا إلى القارئ.';

  @override
  String get listenCouldNotPlace =>
      'تعذّر تحديد موضع ذلك في القرآن. حاول تلاوة المزيد.';

  @override
  String get listenMicPermissionWeb =>
      'يحتاج الاستماع إلى الوصول للميكروفون. يمكنك منحه في أذونات هذا الموقع في متصفحك.';

  @override
  String get listenMicPermission =>
      'يحتاج الاستماع إلى الوصول للميكروفون. يمكنك منحه في إعدادات جهازك.';

  @override
  String get listenBrowserUnsupported =>
      'لا يستطيع هذا المتصفح التعرف على الكلام. Chrome وEdge وSafari يستطيعون.';

  @override
  String get listenDeviceUnsupported =>
      'لا يوجد معرّف كلام متاح على هذا الجهاز.';

  @override
  String get listenNoArabic =>
      'لا يوجد تعرّف على الكلام العربي مثبّت على هذا الجهاز. إضافته في إعدادات لغة جهازك تفعّله.';

  @override
  String get listenStartFailed => 'تعذّر بدء الاستماع. حاول مرة أخرى.';

  @override
  String get listenTitle => 'استمع وتابع';

  @override
  String get listenGettingReady => 'جارٍ التهيّؤ…';

  @override
  String get listenListening => 'جارٍ الاستماع…';

  @override
  String get listenHoldPhone => 'قرّب الهاتف من التلاوة.';

  @override
  String get listenFindNow => 'ابحث عن الآية الآن';

  @override
  String get listenFinding => 'جارٍ البحث عن الآية…';

  @override
  String get listenWhichVerse => 'أي آية كانت؟';

  @override
  String get listenAgain => 'الاستماع مجددًا';

  @override
  String get commonTryAgain => 'حاول مرة أخرى';

  @override
  String flightDepartureDateAt(String airport) {
    return 'تاريخ المغادرة في $airport';
  }

  @override
  String flightArrivalDateAt(String airport) {
    return 'تاريخ الوصول في $airport';
  }

  @override
  String flightDepartureTimeAt(String airport) {
    return 'وقت المغادرة (المحلي في $airport)';
  }

  @override
  String flightArrivalTimeAt(String airport) {
    return 'وقت الوصول (المحلي في $airport)';
  }

  @override
  String flightDurationTooLong(String duration) {
    return 'هذا يعادل $duration في الجو. تحقق من تاريخ الوصول.';
  }

  @override
  String get flightFrom => 'من';

  @override
  String get flightTo => 'إلى';

  @override
  String get flightDeparts => 'المغادرة';

  @override
  String get flightArrives => 'الوصول';

  @override
  String get flightDepartureAirport => 'مطار المغادرة';

  @override
  String get flightArrivalAirport => 'مطار الوصول';

  @override
  String get flightChooseDepartureFirst => 'اختر مطار المغادرة أولًا.';

  @override
  String get flightChooseArrivalFirst => 'اختر مطار الوصول أولًا.';

  @override
  String get flightChooseBothAirports => 'اختر كلا المطارين.';

  @override
  String get flightSetTimes => 'عيّن أوقات المغادرة والوصول.';

  @override
  String get flightAirportsMustDiffer => 'يجب أن يختلف مطارا المغادرة والوصول.';

  @override
  String get flightTimeZoneUnresolved =>
      'تعذّر تحديد المنطقة الزمنية لأحد هذين المطارين.';

  @override
  String get flightArrivalBeforeDeparture =>
      'الوصول قبل المغادرة عند تطبيق المناطق الزمنية. تحقق من تاريخ الوصول — الرحلات الليلية تهبط في اليوم التالي.';

  @override
  String get flightAdd => 'إضافة رحلة';

  @override
  String get flightDepartsHint => 'الوقت المحلي في مطار المغادرة';

  @override
  String get flightArrivesHint => 'الوقت المحلي في مطار الوصول';

  @override
  String get flightNumberLabel => 'رقم الرحلة (اختياري)';

  @override
  String get flightSaveChanges => 'حفظ التغييرات';

  @override
  String get flightSave => 'حفظ الرحلة';

  @override
  String get flightTicketNote =>
      'أدخل الأوقات كما تظهر في تذكرتك بالضبط — كل منها بالتوقيت المحلي لمطاره.';

  @override
  String get flightChooseAirport => 'اختر مطارًا';

  @override
  String get flightChooseDateTime => 'اختر التاريخ والوقت';

  @override
  String get widgetIslamicCalendar => 'التقويم الإسلامي';

  @override
  String get widgetFavorites => 'المفضلة';

  @override
  String get widgetNoFavorites => 'لا مفضلة بعد';

  @override
  String get widgetTodaysRecitations => 'تلاوات اليوم';

  @override
  String get widgetOpenAppToRefresh => 'افتح التطبيق للتحديث';

  @override
  String get widgetUpNext => 'التالي';

  @override
  String get widgetPrayerTimes => 'أوقات الصلاة';

  @override
  String get widgetLocationNeeded => 'يلزم الموقع';

  @override
  String get widgetSavedLocation => 'الموقع المحفوظ';

  @override
  String get widgetSetLocation => 'تعيين الموقع';

  @override
  String get widgetOpenApp => 'فتح التطبيق';

  @override
  String get widgetRefreshSchedule => 'تحديث الجدول';

  @override
  String get commonToday => 'اليوم';

  @override
  String get commonTomorrow => 'غدًا';

  @override
  String quranSurahAyah(String surah, int ayah) {
    return '$surah $ayah';
  }

  @override
  String trackNameTaken(String name) {
    return 'يوجد بالفعل مسار باسم \"$name\"';
  }

  @override
  String get trackNameRequired => 'أعطِ المسار اسمًا';

  @override
  String get trackBeginning => 'البداية';

  @override
  String get trackNew => 'مسار تلاوة جديد';

  @override
  String get trackName => 'الاسم';

  @override
  String get trackNameHint => 'مثال: العائلة، التهجّد';

  @override
  String get trackReadBy => 'يقرأه';

  @override
  String get trackBySurah => 'سورة';

  @override
  String get trackByJuz => 'جزء';

  @override
  String get trackContinueFrom => 'المتابعة من';

  @override
  String get trackStartFrom => 'البدء من';

  @override
  String get trackStartAt => 'البدء عند';

  @override
  String get trackEditNote =>
      'يتقدم مسارك من تلقاء نفسه أثناء قراءتك. غيّر هذا فقط للمتابعة من مكان آخر.';

  @override
  String get trackNewNote => 'يمكنك تغيير هذه في أي وقت من بطاقة المسار.';

  @override
  String get trackCreate => 'إنشاء المسار';

  @override
  String notifDefaultSoundSubtitle(String sound) {
    return '$sound · يُستخدم ما لم يتجاوزه وقت أدناه';
  }

  @override
  String notifCustomSound(String file) {
    return 'مخصص: $file';
  }

  @override
  String notifPrayerSound(String prayer) {
    return 'صوت $prayer';
  }

  @override
  String notifFollows(String sound) {
    return 'يتبع $sound';
  }

  @override
  String get notifDefaultSound => 'الصوت الافتراضي';

  @override
  String get notifTimesHeading => 'الأوقات';

  @override
  String get notifAudioUnreadable => 'تعذّرت قراءة ذلك الملف الصوتي.';

  @override
  String get notifPickFailed => 'تعذّر اختيار ذلك الملف. حاول مرة أخرى.';

  @override
  String get notifPlayingSample => 'سيتم تشغيل عيّنة بعد قليل…';

  @override
  String get notifUseDefault => 'استخدام الافتراضي';

  @override
  String get notifOwnSoundNote =>
      'يحتفظ هذا الوقت بصوته الخاص. كل شيء آخر يتبع الافتراضي.';

  @override
  String get notifDefaultNote => 'يتبع كل وقت هذا ما لم تعطِه صوتًا خاصًا به.';

  @override
  String get notifPreview => 'معاينة';

  @override
  String aboutVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get aboutDedication =>
      'نشكر الله تعالى والمعصومين الأربعة عشر (ع) على عونهم الذي مكّننا من مشاركة هذا العمل المتواضع مع المؤمنين. نهدي هذا التطبيق إليهم وإلى المرحومين التالين:\n\nMarhooma Amina Mohammed Raza Jassani\nMarhoom Haji Mohammad Raza Jassani\nMarhoom Haji Yusufali Bhojani\n\n\nيرجى تلاوة سورة الفاتحة للمرحومين والمرحومات\n\nللملاحظات أو الاستفسارات أو الاقتراحات تواصل على:';

  @override
  String get aboutNoEmailApp => 'لم يتم العثور على تطبيق بريد إلكتروني';

  @override
  String get aboutCredits => 'شكر وتقدير';

  @override
  String get aboutCreditAudio =>
      'صوت التلاوة مستضاف على خوادمنا؛ تُستخدم التسجيلات بإذن كريم من duas.org.';

  @override
  String get aboutCreditScheherazade =>
      'العربية مضبوطة بخط Scheherazade New من SIL Global، المستخدم بموجب رخصة SIL للخطوط المفتوحة.';

  @override
  String get aboutCreditTanzil =>
      'نص القرآن العثماني، المعروض مع Scheherazade، من مشروع Tanzil، مستخدم بموجب رخصة المشاع الإبداعي (نسب المصنّف) 3.0.';

  @override
  String get aboutCreditQuranWbw =>
      'نص القرآن الهندي الباكستاني وخطه، المعروضان مع Qalam، من QuranWBW.com. وقد تم الحصول على رخصة استخدام نص القرآن والخط دون تعديل من QuranWBW.com، المساهم الأصلي.';

  @override
  String get aboutCreditIndoPakFont =>
      'الخط: AlQuran IndoPak من QuranWBW، صنعه Ayman Siddiqui، استنادًا إلى خطوط Al Qalam Quran Majeed، مع أرقام الآيات من خط KFGQPC Nastaleeq. © Al Qalam © Ghandhara © KFGQPC © Ayman Siddiqui. شكر: Abdul Majeed Khan، Arif Karim، Shakir-ul-Qadree، Jawad. نص القرآن: typemybook.com، أصله من InPage.';

  @override
  String downloadsRemoveAllBody(String size) {
    return 'سيتم بث كل تلاوة مجددًا، لذا ستحتاج إلى اتصال للاستماع. يحرّر $size.';
  }

  @override
  String downloadsOlderSubtitle(int count, String size) {
    return '$count لا يستخدمها أي دعاء بعد · $size';
  }

  @override
  String get downloadsRemoveAllTitle => 'إزالة جميع التنزيلات؟';

  @override
  String get downloadsRemoveAll => 'إزالة الكل';

  @override
  String get downloadsEmpty => 'لا تنزيلات بعد';

  @override
  String get downloadsEmptyBody =>
      'نزّل تلاوة للاستماع دون اتصال - اضغط زر التنزيل في مشغّل صوت الدعاء، أو نزّل الكل في قائمة تشغيل.';

  @override
  String get downloadsOlder => 'تسجيلات أقدم';

  @override
  String get downloadsRemoveOlder => 'إزالة التسجيلات الأقدم';

  @override
  String get hijriMonth1 => 'محرم';

  @override
  String get hijriMonth2 => 'صفر';

  @override
  String get hijriMonth3 => 'ربيع الأول';

  @override
  String get hijriMonth4 => 'ربيع الثاني';

  @override
  String get hijriMonth5 => 'جمادى الأولى';

  @override
  String get hijriMonth6 => 'جمادى الثانية';

  @override
  String get hijriMonth7 => 'رجب';

  @override
  String get hijriMonth8 => 'شعبان';

  @override
  String get hijriMonth9 => 'رمضان';

  @override
  String get hijriMonth10 => 'شوال';

  @override
  String get hijriMonth11 => 'ذو القعدة';

  @override
  String get hijriMonth12 => 'ذو الحجة';

  @override
  String get hijriMonthShort1 => 'محر';

  @override
  String get hijriMonthShort2 => 'صفر';

  @override
  String get hijriMonthShort3 => 'رب١';

  @override
  String get hijriMonthShort4 => 'رب٢';

  @override
  String get hijriMonthShort5 => 'جم١';

  @override
  String get hijriMonthShort6 => 'جم٢';

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
    return 'تم التحديث $age';
  }

  @override
  String get prayerNextDay => '(اليوم التالي)';

  @override
  String get prayerLocating => 'جارٍ تحديد الموقع…';

  @override
  String get prayerForYourLocation => 'أوقات الصلاة لموقعك';

  @override
  String get prayerFindingLocation => 'جارٍ العثور على موقعك';

  @override
  String get prayerAppearSoon => 'ستظهر أوقات الصلاة بعد قليل';

  @override
  String get prayerTapToRetry => 'اضغط لإعادة المحاولة';

  @override
  String get prayerLocationUnavailable => 'الموقع غير متاح';

  @override
  String get prayerTapToEnableLocation => 'اضغط هنا لتفعيل الموقع';

  @override
  String calendarNotificationsSomeOn(int enabled, int total) {
    return '$enabled من $total مفعّلة';
  }

  @override
  String get calendarNoEvent => 'لا حدث مدرجًا لهذا التاريخ.';

  @override
  String get calendarNotificationsAllOff => 'متوقفة لكل صلاة';

  @override
  String get readingFineTune =>
      'ضبط دقيق لنص الذكر. يُطبّق فوق حجم نص التطبيق في الإعدادات.';

  @override
  String get readingArabicFontSize => 'حجم الخط العربي';

  @override
  String get readingEnglishFontSize => 'حجم الخط الإنجليزي';

  @override
  String get readingArabicFont => 'الخط العربي';

  @override
  String get readingKeepScreenOn => 'إبقاء الشاشة مضيئة أثناء تلاوة الذكر';

  @override
  String get readingFocusMode => 'وضع التركيز';

  @override
  String get readingFocusModeSubtitle =>
      'إخفاء شريط التقدم وشريط الإجراءات أثناء القراءة. مرّر لأعلى أو اضغط لإعادتهما.';

  @override
  String get readingShareAsImage => 'مشاركة الذكر كصورة';

  @override
  String get readingShareAsImageSubtitle => 'إنشاء صورة منسّقة عند المشاركة.';

  @override
  String get readingShowTransliteration => 'إظهار النقحرة';

  @override
  String get readingShowTranslation => 'إظهار الترجمة';

  @override
  String get readingArabicParagraph => 'إظهار العربية كفقرة';

  @override
  String get readingArabicParagraphOn =>
      'تتدفق الآيات العربية معًا كفقرة واحدة بدلًا من أسطر منفصلة.';

  @override
  String get readingArabicParagraphOff =>
      'أوقف النقحرة والترجمة أعلاه لاستخدام هذا.';

  @override
  String pickerJuzRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String pickerSurahDetails(String ayahs, String juz) {
    return '$ayahs · الجزء $juz';
  }

  @override
  String quranAyahCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آية',
      many: '$count آية',
      few: '$count آيات',
      two: 'آيتان',
      one: 'آية واحدة',
      zero: 'لا آيات',
    );
    return '$_temp0';
  }

  @override
  String pickerJuzFrom(String start) {
    return 'من $start';
  }

  @override
  String pickerAyahSingle(int ayah) {
    return 'الآية $ayah';
  }

  @override
  String pickerAyahRange(int from, int to) {
    return 'الآيات $from–$to';
  }

  @override
  String get pickerThirtyJuz => 'يوجد 30 جزءًا';

  @override
  String get pickerTryVerse => 'جرّب آية مثل 33:33، أو الجزء 22';

  @override
  String get pickerSearchHint => 'اذهب إلى آية - 33:33، 18، الجزء 22';

  @override
  String get pickerChooseVerse => 'اختر آية';

  @override
  String get pickerAllJuz => 'كل الأجزاء';

  @override
  String get pickerAllSurahs => 'كل السور';

  @override
  String get pickerChoose => 'اختر';

  @override
  String quranFromPosition(String position) {
    return 'من $position';
  }

  @override
  String quranPercentRead(String percent) {
    return '$percent% من القرآن';
  }

  @override
  String quranEditTrack(String track) {
    return 'تعديل مسار $track';
  }

  @override
  String get quranTitle => 'القرآن';

  @override
  String get quranRecentSessions => 'الجلسات الأخيرة';

  @override
  String get quranTabSurahs => 'السور';

  @override
  String get quranTabJuz => 'الأجزاء';

  @override
  String get quranTabCollections => 'المجموعات';

  @override
  String get quranStartReading => 'ابدأ القراءة';

  @override
  String get quranNewTrack => 'مسار جديد';

  @override
  String get quranGoToVerseError => 'جرّب شيئًا مثل 23:56';

  @override
  String get quranGoToVerseHint => 'اذهب إلى آية، مثال 23:56';

  @override
  String get quranGo => 'اذهب';

  @override
  String get statsMetricVerses => 'الآيات';

  @override
  String get statsMetricZikrs => 'الأذكار';

  @override
  String get statsMetricQaza => 'القضاء';

  @override
  String get statsMetricVersesLower => 'آيات';

  @override
  String get statsMetricZikrsLower => 'أذكار';

  @override
  String get statsMetricQazaLower => 'قضاء';

  @override
  String statsVerseCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آية',
      many: '$count آية',
      few: '$count آيات',
      two: '$count آيتان',
      one: '$count آية',
      zero: 'لا آيات',
    );
    return '$_temp0';
  }

  @override
  String statsZikrCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ذكر',
      many: '$count ذكرًا',
      few: '$count أذكار',
      two: '$count ذكران',
      one: '$count ذكر',
      zero: 'لا أذكار',
    );
    return '$_temp0';
  }

  @override
  String statsQazaCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قضاء',
      many: '$count قضاء',
      few: '$count قضاء',
      two: '$count قضاءان',
      one: '$count قضاء',
      zero: 'لا قضاء',
    );
    return '$_temp0';
  }

  @override
  String get statsPeriodWeek => 'الأسبوع';

  @override
  String get statsPeriodMonth => 'الشهر';

  @override
  String get statsPeriodAllTime => 'كل الأوقات';

  @override
  String statsCaptionWeek(String metric) {
    return '$metric في الأيام السبعة الأخيرة';
  }

  @override
  String statsCaptionMonth(String metric) {
    return '$metric في الأيام الثلاثين الأخيرة';
  }

  @override
  String statsCaptionAllTime(String metric) {
    return '$metric إجمالًا';
  }

  @override
  String get statsHistory => 'السجلّ';

  @override
  String statsBestMonth(String month, String count) {
    return 'أفضل شهر: $month · $count';
  }

  @override
  String statsBestDay(String day, String count, String average) {
    return 'أفضل يوم: $day · $count · $average في اليوم كمعدل';
  }

  @override
  String get statsNew => 'جديد';

  @override
  String statsVersusBefore(String count) {
    return 'مقابل $count قبله';
  }

  @override
  String statsSessionCount(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جلسة',
      many: '$count جلسة',
      few: '$count جلسات',
      two: '$count جلستان',
      one: '$count جلسة',
      zero: 'لا جلسات',
    );
    return '$_temp0';
  }

  @override
  String statsVersesRecited(int count, Object formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آية تُليت',
      many: '$count آية تُليت',
      few: '$count آيات تُليت',
      two: '$count آيتان تُليتا',
      one: '$count آية تُليت',
      zero: 'لا آيات تُليت',
    );
    return '$_temp0';
  }

  @override
  String statsLastOn(String date) {
    return 'آخر مرة $date';
  }

  @override
  String statsVersesLeft(String count) {
    return 'تبقّى $count آية لإكمال ختمة';
  }

  @override
  String statsJuzCoverage(int juz, int percent) {
    return 'الجزء $juz: $percent%';
  }

  @override
  String statsJuzComplete(int count) {
    return 'اكتمل $count من 30 جزءًا';
  }

  @override
  String get statsQuranProgress => 'تقدم القرآن';

  @override
  String get statsQuranEmpty =>
      'افتح سورة وابدأ القراءة - تُتتبّع الآيات التي تتلوها هنا تلقائيًا، مع تقدّمك نحو ختمة كاملة.';

  @override
  String get statsRecitedTill => 'تُلي حتى';

  @override
  String get statsNotStarted => 'لم يبدأ';

  @override
  String get statsJuzDone => 'اكتمل الجزء';

  @override
  String get statsKhatmComplete => 'اكتملت الختمة - تقبّلها الله';

  @override
  String reminderAtPrayer(String prayer) {
    return 'عند $prayer';
  }

  @override
  String reminderMinutesAfter(int minutes, String prayer) {
    return 'بعد $minutes دقيقة من $prayer';
  }

  @override
  String reminderMinutesBefore(int minutes, String prayer) {
    return 'قبل $minutes دقيقة من $prayer';
  }

  @override
  String azanPlaying(String prayer) {
    return 'أذان $prayer يُشغَّل';
  }

  @override
  String get libraryNeedsNetwork => 'تصفّح المكتبة يحتاج إلى اتصال بالشبكة.';

  @override
  String get libraryChaptersFailed => 'تعذّر تحميل الفصول. حاول مرة أخرى.';

  @override
  String get libraryReadingNeedsNetwork =>
      'قراءة الكتب تحتاج إلى اتصال بالشبكة.';

  @override
  String get libraryChapterFailed => 'تعذّر تحميل هذا الفصل. حاول مرة أخرى.';

  @override
  String get menuCalendarPrayerTimes => 'التقويم وأوقات الصلاة';

  @override
  String get menuFavorites => 'المفضلة';

  @override
  String get menuTodaysRecitations => 'تلاوات اليوم';

  @override
  String get menuTaqeebat => 'تعقيبات الصلاة';

  @override
  String get menuNamaz => 'الصلاة';

  @override
  String get menuDuas => 'الأدعية';

  @override
  String get menuZiyarats => 'الزيارات';

  @override
  String get menuSurahs => 'السور';

  @override
  String get menuAamaal => 'الأعمال';

  @override
  String get menuLibrary => 'المكتبة';

  @override
  String get menuMunajaat => 'المناجاة';

  @override
  String get menuBaaqeyaat => 'الباقيات الصالحات';

  @override
  String get menuQiblaFinder => 'محدّد القبلة';

  @override
  String get menuTasbeehCounter => 'عدّاد التسبيح';

  @override
  String get menuQazaTracker => 'متتبع القضاء';

  @override
  String get menuRakaatCounter => 'عدّاد الركعات';

  @override
  String get menuPrayerTimesInFlight => 'أوقات الصلاة أثناء الطيران';

  @override
  String get menuPreferences => 'التفضيلات';

  @override
  String get menuQuran => 'القرآن';

  @override
  String get menuPlaylists => 'قوائم التشغيل';

  @override
  String get menuMyStats => 'إحصائياتي';

  @override
  String get menuCalendar => 'التقويم';

  @override
  String audioTrackNumber(int number) {
    return 'المقطع $number';
  }

  @override
  String get audioPauseRecitation => 'إيقاف التلاوة مؤقتًا';

  @override
  String get audioPlayRecitation => 'تشغيل التلاوة';

  @override
  String get audioList => 'قائمة الصوت';

  @override
  String get audioOfflineNotDownloaded =>
      'أنت غير متصل وهذه التلاوة غير منزّلة';

  @override
  String get audioLoadFailed => 'تعذّر تحميل هذه التلاوة';

  @override
  String get audioClosePlayer => 'إغلاق المشغّل';

  @override
  String get audioChooseRecording => 'اختيار التسجيل';

  @override
  String get audioRecitation => 'تلاوة';

  @override
  String get audioRecitationAudio => 'صوت التلاوة';

  @override
  String librarySavedOffline(String book) {
    return 'تم حفظ $book دون اتصال.';
  }

  @override
  String librarySaveFailed(String error) {
    return 'تعذّر حفظ الكتاب: $error';
  }

  @override
  String libraryProgress(String chapter, int page, int pages) {
    return '$chapter - الصفحة $page من $pages';
  }

  @override
  String get librarySavedChapterGone => 'الفصل المحفوظ لم يعد متاحًا';

  @override
  String get libraryUnavailable => 'المكتبة غير متاحة';

  @override
  String get libraryNoBooks => 'لم يتم العثور على كتب';

  @override
  String get libraryEmpty => 'المكتبة فارغة الآن.';

  @override
  String get libraryContinueReading => 'متابعة القراءة';

  @override
  String get libraryRequestBook => 'اطلب كتابًا';

  @override
  String get libraryRequestBookSubtitle => 'لا تجد كتابًا؟ اطلب منا إضافته.';

  @override
  String flightRemoveBody(String flight) {
    return 'ستتم إزالة $flight من رحلاتك المحفوظة.';
  }

  @override
  String flightLands(String duration, String time, String airport) {
    return '$duration · يهبط $time بتوقيت $airport';
  }

  @override
  String get flightRemoveTitle => 'إزالة الرحلة؟';

  @override
  String get flightRemove => 'إزالة الرحلة';

  @override
  String get flightNoneSaved => 'لا رحلات محفوظة';

  @override
  String get flightNoneSavedBody =>
      'أضف رحلتك وستحسب هذه الصفحة موعد حلول كل صلاة على طول المسار — معروضة بتوقيت مدينتي المغادرة والوصول.';

  @override
  String librarySavedForOffline(String title) {
    return 'تم حفظ $title دون اتصال';
  }

  @override
  String librarySaveFailedShort(String error) {
    return 'فشل الحفظ: $error';
  }

  @override
  String get libraryOfflineRemoved => 'أُزيلت النسخة دون الاتصال';

  @override
  String get libraryShareBook => 'مشاركة الكتاب';

  @override
  String get libraryRemoveOffline => 'إزالة النسخة دون الاتصال';

  @override
  String get librarySaveOffline => 'حفظ الكتاب دون اتصال';

  @override
  String get libraryChaptersUnavailable => 'الفصول غير متاحة';

  @override
  String get libraryNoChapters => 'لم يتم العثور على فصول';

  @override
  String get libraryNoChaptersBody => 'لا فصول لهذا الكتاب الآن.';

  @override
  String quranMoveEntry(String entry) {
    return 'نقل \"$entry\"';
  }

  @override
  String get quranNoSessions =>
      'لا جلسات بعد. افتح سورة وابدأ القراءة - تُسجَّل الآيات التي تتلوها هنا تلقائيًا.';

  @override
  String get quranMoveToLabel => 'نقل إلى تصنيف آخر';

  @override
  String get quranNewLabel => 'أو تصنيف جديد';

  @override
  String get quranMove => 'نقل';

  @override
  String get quranCollectionDuas => 'الأدعية';

  @override
  String get quranCollectionImamAli => 'الإمام علي (ع)';

  @override
  String get quranCollectionImamMahdi => 'الإمام المهدي (عج)';

  @override
  String get quranCollectionProphets => 'الأنبياء';

  @override
  String get quranCollectionSaved => 'المحفوظة';

  @override
  String get quranFromTheQuran => 'من القرآن';

  @override
  String get quranNoSavedVerses => 'لا آيات محفوظة بعد';

  @override
  String get quranNoSavedVersesBody => 'اضغط آية أثناء القراءة لحفظها هنا.';

  @override
  String get libraryNextChapter => 'الفصل التالي';

  @override
  String get libraryPreviousChapter => 'الفصل السابق';

  @override
  String get libraryNextPage => 'الصفحة التالية';

  @override
  String get libraryPreviousPage => 'الصفحة السابقة';

  @override
  String libraryNextChapterNamed(String chapter) {
    return 'الفصل التالي: $chapter';
  }

  @override
  String libraryPreviousChapterNamed(String chapter) {
    return 'الفصل السابق: $chapter';
  }

  @override
  String libraryNextShort(String chapter) {
    return 'التالي: $chapter';
  }

  @override
  String libraryPreviousShort(String chapter) {
    return 'السابق: $chapter';
  }

  @override
  String get libraryShareChapter => 'مشاركة الفصل';

  @override
  String get libraryChapterUnavailable => 'الفصل غير متاح';

  @override
  String get libraryDecreaseFont => 'تصغير الخط';

  @override
  String get libraryIncreaseFont => 'تكبير الخط';

  @override
  String get azaanTakbirName => 'التكبير فقط';

  @override
  String get azaanTakbirDescription => 'صوت إشعار تكبير قصير';

  @override
  String get azaanFullName => 'الأذان الكامل';

  @override
  String get azaanFullDescription => 'الأذان الكامل، يُشغَّل تلقائيًا';

  @override
  String get azaanFullIosDescription =>
      'يشغّل الإشعار التكبير؛ اضغطه لسماع الأذان كاملًا';

  @override
  String get azaanSystemDefaultName => 'افتراضي النظام';

  @override
  String get azaanSystemDefaultDescription =>
      'استخدام صوت إشعار جهازك الافتراضي';

  @override
  String get azaanSilentName => 'صامت';

  @override
  String get azaanSilentDescription => 'شعار إشعار فقط (بدون صوت)';

  @override
  String get azaanCustomName => 'صوت مخصص';

  @override
  String get azaanCustomDescription => 'اختر ملف صوت من جهازك';

  @override
  String get ratingEnjoying => 'هل تستمتع بـ Shia Companion؟';

  @override
  String get ratingEnjoyingBody =>
      'يسعدنا سماع تجربتك - ملاحظاتك تساعدنا على الاستمرار في تحسين التطبيق.';

  @override
  String get ratingNotReally => 'ليس تمامًا';

  @override
  String get ratingYes => 'نعم!';

  @override
  String get ratingSorry => 'نأسف لسماع ذلك';

  @override
  String get ratingSorryBody =>
      'هل تمانع إخبارنا بما لا يعمل؟ يساعدنا ذلك على تحسين التطبيق.';

  @override
  String get ratingNoThanks => 'لا شكرًا';

  @override
  String get ratingSendFeedback => 'إرسال الملاحظات';

  @override
  String get azaanOptInIntro =>
      'يمكن لـ Shia Companion إرسال إشعار عند الفجر والظهر والمغرب وتشغيل الأذان.';

  @override
  String get azaanOptInIosNote =>
      'على iPhone يشغّل الإشعار تكبيرًا قصيرًا. اختر الأذان الكامل في الإعدادات لسماع الأذان كاملًا عند الضغط عليه.';

  @override
  String get azaanOptInChangeLater =>
      'يمكنك تغيير الصلوات التي تُشعرك، واختيار صوت مختلف، أو إيقاف هذا في أي وقت من الإعدادات.';

  @override
  String get azaanOptInTitle => 'تشغيل الأذان عند أوقات الصلاة؟';

  @override
  String get azaanOptInNotNow => 'ليس الآن';

  @override
  String get azaanOptInEnable => 'تفعيل الأذان';

  @override
  String reminderRemoveBody(String title) {
    return 'هذا يزيل التذكير لـ \"$title\". يمكنك إضافته مجددًا في أي وقت.';
  }

  @override
  String get reminderRemoveTitle => 'إزالة التذكير؟';

  @override
  String get reminderAddTooltip => 'إضافة تذكير';

  @override
  String get reminderNone => 'لا تذكيرات بعد';

  @override
  String get reminderNoneBody =>
      'اضغط + للحصول على تذكير بذكر أو دعاء في الأيام التي تختارها — مثل التوسل كل ثلاثاء، أو دعاء كميل بعد المغرب يوم الخميس.';

  @override
  String tasbeehBeepNumber(int number) {
    return 'صافرة $number';
  }

  @override
  String get tasbeehHelp =>
      'اضغط دائرة العدّاد للعدّ. ستصدر الصافرة عند المراحل أدناه.';

  @override
  String get tasbeehEnableBeep => 'تفعيل الصافرة';

  @override
  String get tasbeehTapToCount => 'اضغط للعدّ';

  @override
  String get tasbeehMinusOne => 'ناقص واحد';

  @override
  String get tasbeehReset => 'إعادة الضبط';

  @override
  String get requestThanks => 'شكرًا - تلقّينا طلبك.';

  @override
  String get requestFailed => 'تعذّر إرسال الطلب. حاول مرة أخرى.';

  @override
  String get requestBookTitle => 'عنوان الكتاب';

  @override
  String get requestZikrName => 'اسم الدعاء أو الزيارة، إلخ.';

  @override
  String get requestBookDetails => 'المؤلف أو المترجم أو الرابط (اختياري)';

  @override
  String get requestZikrDetails => 'المصدر أو المناسبة أو الرابط (اختياري)';

  @override
  String get commonSend => 'إرسال';

  @override
  String searchOneMatch(String source) {
    return 'نتيجة واحدة في $source';
  }

  @override
  String searchMatches(int count, String source) {
    return '$count نتيجة في $source';
  }

  @override
  String get searchSourceZikr => 'الأذكار';

  @override
  String get searchSourceQuran => 'القرآن';

  @override
  String get searchSourceLibrary => 'مكتبة';

  @override
  String get searchTitleOrUid => 'بحث بالعنوان أو المعرّف';

  @override
  String get searchShow => 'إظهار';

  @override
  String get searchNoResults => 'لا نتائج';

  @override
  String get searchRequestIt => 'اطلبه';

  @override
  String widgetPrayerTimesHelp(int min, int max) {
    return 'اختر من $min إلى $max أوقات. الشروق والغروب ومنتصف الليل هي المواعيد النهائية التي يجب أداء الصلاة قبلها.';
  }

  @override
  String get accountSessionExpired =>
      'انتهت جلستك. يرجى تسجيل الدخول مجددًا وإعادة محاولة الحذف.';

  @override
  String get accountReauthenticate =>
      'لأسباب أمنية، يرجى تسجيل الدخول مجددًا ثم إعادة محاولة حذف حسابك.';

  @override
  String get accountPopupClosed =>
      'أُغلقت نافذة تسجيل الدخول قبل انتهاء الإجراء.';

  @override
  String get accountNetworkError =>
      'خطأ في الشبكة. يرجى التحقق من اتصالك والمحاولة مرة أخرى.';

  @override
  String get commonSomethingWentWrong => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String zikrTabNumber(int number) {
    return 'التبويب $number';
  }

  @override
  String get zikrBookmarked => 'محفوظ بإشارة';

  @override
  String get zikrMoveBookmarkHere => 'نقل الإشارة إلى هنا';

  @override
  String get zikrDragBookmarkHint => 'اسحب لنقل الإشارة إلى سطر آخر';

  @override
  String get durationUnderOneMinute => 'أقل من دقيقة';

  @override
  String durationMinutes(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String durationHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours ساعة',
      many: '$hours ساعة',
      few: '$hours ساعات',
      two: 'ساعتان',
      one: 'ساعة واحدة',
      zero: 'لا ساعات',
    );
    return '$_temp0';
  }

  @override
  String durationHoursMinutes(String hours, int minutes) {
    return '$hours ساعة و$minutes دقيقة';
  }

  @override
  String zikrReadingTime(String duration) {
    return 'قراءة $duration';
  }

  @override
  String get zikrProgressCompleted => 'اكتمل';

  @override
  String airportNothingMatched(String query) {
    return 'لا شيء يطابق \"$query\". جرّب رمز الحروف الثلاثة بدلًا من ذلك.';
  }

  @override
  String get airportSearchLabel => 'رمز المطار أو المدينة';

  @override
  String get airportSearchHint => 'مثال: SFO، إسطنبول، النجف';

  @override
  String get airportSearchTitle => 'البحث عن مطار';

  @override
  String get airportSearchDetail => 'اكتب رمز مطار أو مدينة أو اسم بلد.';

  @override
  String get airportNoneFound => 'لم يتم العثور على مطارات';

  @override
  String get counterTapAnywhere => 'اضغط أي مكان للعدّ';

  @override
  String get counterHoldToMove => 'اضغط واسحب للنقل';

  @override
  String get counterAddOne => 'إضافة واحد';

  @override
  String azanPaused(String prayer) {
    return 'أذان $prayer متوقف مؤقتًا';
  }

  @override
  String get azanPrayerFallback => 'الصلاة';

  @override
  String get reminderChannelDescription =>
      'تذكيرات للأذكار والأدعية التي جدولتها';

  @override
  String get locationOff => 'خدمات الموقع متوقفة';

  @override
  String get locationPermissionShort => 'يلزم إذن الموقع';

  @override
  String get locationNoFix => 'تعذّر الحصول على إحداثيات الموقع';

  @override
  String get locationUpdateFailed => 'تعذّر تحديث الموقع';

  @override
  String quranPreviousUnit(String unit) {
    return 'السابق $unit';
  }

  @override
  String quranNextUnit(String unit) {
    return 'التالي $unit';
  }

  @override
  String get quranUnitSurah => 'سورة';

  @override
  String hadithNoResults(String query) {
    return 'لم يتم العثور على نتائج لـ \"$query\"';
  }

  @override
  String get hadithTitle => 'الحديث';

  @override
  String get hadithSearchHint => 'بحث في الحديث...';

  @override
  String get hadithNone => 'لا حديث متاحًا';

  @override
  String favoritesReorder(String title) {
    return 'إعادة ترتيب $title';
  }

  @override
  String get favoritesReorderFailed =>
      'تعذّر حفظ الترتيب الجديد. حاول مرة أخرى.';

  @override
  String get favoritesNone => 'لا مفضلة بعد.';

  @override
  String linkNotFoundRequested(String link) {
    return 'الرابط المطلوب: $link';
  }

  @override
  String get linkNotFoundTitle => 'لم يتم العثور على الرابط';

  @override
  String get linkNotFoundBody => 'تعذّر علينا العثور على هذا المحتوى.';

  @override
  String get linkNotFoundGoHome => 'الذهاب إلى الرئيسية';

  @override
  String get whatsNewTitle => 'ما الجديد';

  @override
  String get whatsNewGotIt => 'فهمت';

  @override
  String get pickerChooseZikr => 'اختر ذكرًا أو دعاء';

  @override
  String get pickerSearchZikrHint => 'بحث في الأذكار والأدعية والزيارات...';

  @override
  String get pickerNoMatches => 'لم يتم العثور على تطابقات.';

  @override
  String get todaysNone => 'لا تلاوات مُعدّة.';

  @override
  String get scheduledFallbackTitle => 'إشعار مجدول';

  @override
  String get scheduledNone => 'لا إشعارات مجدولة.';

  @override
  String newsLoadFailed(String error) {
    return 'فشل تحميل الأخبار: $error';
  }

  @override
  String get newsNoBrowser => 'لم يتم العثور على متصفح ويب';

  @override
  String get actionSaved => 'المحفوظة';

  @override
  String get actionBookmark => 'إشارة مرجعية';

  @override
  String get actionShare => 'مشاركة';

  @override
  String get actionListen => 'استماع';

  @override
  String get actionSettings => 'الإعدادات';

  @override
  String get actionCounter => 'العدّاد';

  @override
  String get prayerEnableLocationBody =>
      'فعّل الموقع لعرض أوقات صلاة دقيقة لمنطقتك.';

  @override
  String statsDayRead(String day) {
    return '$day: قُرئ';
  }

  @override
  String statsDayNotRead(String day) {
    return '$day: لم يُقرأ';
  }

  @override
  String get qiblaDistance => 'المسافة';

  @override
  String get qiblaDirection => 'الاتجاه';

  @override
  String get qiblaYouFace => 'أنت تواجه';

  @override
  String pickerAyahLabel(int ayah) {
    return 'الآية $ayah';
  }

  @override
  String hadithSharedVia(String link) {
    return 'تمت المشاركة عبر Shia Companion - $link';
  }

  @override
  String get requestTypeZikr => 'ذكر';

  @override
  String get requestTypeBook => 'كتاب';
}
