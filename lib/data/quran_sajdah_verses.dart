import '../l10n/l10n.dart';
import '../utils/quran_index.dart';

/// Information about a Sajdah (prostration) verse in the Holy Quran according
/// to Fiqh-e-Jafria (Shia Ithna Ashari jurisprudence).
///
/// In Fiqh-e-Jafria, there are exactly 4 verses of Obligatory Prostration
/// (Aza'im / سُوَر العَزَائِم):
/// - Surah As-Sajdah (32:15)
/// - Surah Fussilat (41:38)
/// - Surah An-Najm (53:62)
/// - Surah Al-Alaq (96:19)
///
/// Reciting or hearing any of these 4 verses makes Sajdah immediately WAJIB.
/// Reciting any of these 4 Surahs in an obligatory (Wajib) daily prayer is
/// forbidden and invalidates the prayer.
///
/// The remaining 11 Sajdah verses in the Quran are MUSTAHABB (recommended).
class QuranSajdahVerse {
  const QuranSajdahVerse({
    required this.verse,
    required this.isWajib,
  });

  final VerseKey verse;

  /// True for the 4 Surahs of Aza'im where prostration is Wajib; false for
  /// the 11 verses where prostration is Mustahabb.
  final bool isWajib;

  /// Supplication recommended in sajdah al-tilawa (Sistani, al-Ta'liqa
  /// 'ala al-Urwa al-Wuthqa, sajdah chapter, ruling 18).
  static const String duaArabic =
      'لاَ إِلَهَ إِلَّا اللَّهُ حَقّاً حَقّاً، لاَ إِلَهَ إِلَّا اللَّهُ إِيْمَاناً وَتَصْدِيْقاً، لاَ إِلَهَ إِلَّا اللَّهُ عُبُوْدِيَّةً وَرِقّاً، سَجَدْتُ لَكَ يَا رَبِّ تَعَبُّداً وَرِقّاً، لاَ مُسْتَنْكِفاً وَلاَ مُسْتَكْبِراً، بَلْ أَنَا عَبْدٌ ذَلِيْلٌ ضَعِيْفٌ خَائِفٌ مُسْتَجِيْرٌ';

  String title([String? languageCode]) =>
      isWajib ? _texts(languageCode).titleWajib : _texts(languageCode).titleMustahabb;

  String badgeLabel([String? languageCode]) =>
      isWajib ? _texts(languageCode).badgeWajib : _texts(languageCode).badgeMustahabb;

  String wajibPill([String? languageCode]) => _texts(languageCode).wajibPill;

  String ruling([String? languageCode]) =>
      isWajib ? _texts(languageCode).rulingWajib : _texts(languageCode).rulingMustahabb;

  String duaHeading([String? languageCode]) => _texts(languageCode).duaHeading;

  String duaTranslation([String? languageCode]) => _texts(languageCode).duaTranslation;
}

class _SajdahTexts {
  const _SajdahTexts({
    required this.titleWajib,
    required this.titleMustahabb,
    required this.badgeWajib,
    required this.badgeMustahabb,
    required this.wajibPill,
    required this.rulingWajib,
    required this.rulingMustahabb,
    required this.duaHeading,
    required this.duaTranslation,
  });

  final String titleWajib;
  final String titleMustahabb;
  final String badgeWajib;
  final String badgeMustahabb;
  final String wajibPill;
  final String rulingWajib;
  final String rulingMustahabb;
  final String duaHeading;
  final String duaTranslation;
}

_SajdahTexts _texts(String? languageCode) {
  final lang =
      (languageCode ?? L10n.current.localeName).split(RegExp('[_-]')).first;
  return _translations[lang] ?? _translations['en']!;
}

const Map<String, _SajdahTexts> _translations = {
  'en': _SajdahTexts(
    titleWajib: 'Obligatory Prostration (Wajib Sajdah)',
    titleMustahabb: 'Recommended Prostration (Mustahabb Sajdah)',
    badgeWajib: 'Wajib Sajdah',
    badgeMustahabb: 'Mustahabb Sajdah',
    wajibPill: 'WAJIB',
    rulingWajib:
        'Performing prostration (sajdah) is obligatory upon reciting or hearing this verse. (Reciting this surah in obligatory prayers is not permitted in Fiqh-e-Jafria).',
    rulingMustahabb:
        'According to Fiqh-e-Jafria, prostration upon this verse is recommended (mustahabb), not obligatory.',
    duaHeading: 'Recommended Supplication in Sajdah:',
    duaTranslation:
        'There is no god but Allah, truly and truly! There is no god but Allah, in faith and belief! There is no god but Allah, in servitude and bondage! I have prostrated to You, my Lord, in devotion and servitude, neither disdaining nor proud; rather I am a humble, weak, fearful servant seeking refuge.',
  ),
  'ur': _SajdahTexts(
    titleWajib: 'سجدۂ واجبہ (فقہ جعفریہ)',
    titleMustahabb: 'سجدۂ مستحب (فقہ جعفریہ)',
    badgeWajib: 'سجدۂ واجبہ',
    badgeMustahabb: 'سجدۂ مستحب',
    wajibPill: 'واجب',
    rulingWajib:
        'اس آیت کی تلاوت کرنے یا سننے پر فوراً سجدہ کرنا واجب ہے۔ (فقہ جعفریہ کے مطابق واجب نماز میں اس سورہ کی تلاوت جائز نہیں ہے)۔',
    rulingMustahabb:
        'فقہ جعفریہ کے مطابق اس آیت پر سجدہ کرنا مستحب ہے، واجب نہیں ہے۔',
    duaHeading: 'سجدۂ تلاوت کی مسنون دعا:',
    duaTranslation:
        'اللہ کے سوا کوئی معبود نہیں، حق ہے حق۔ اللہ کے سوا کوئی معبود نہیں، ایمان اور تصدیق کے ساتھ۔ اللہ کے سوا کوئی معبود نہیں، بندگی اور غلامی کے ساتھ۔ اے پروردگار! میں نے بندگی اور غلامی کے طور پر تجھے سجدہ کیا، نہ عار سمجھتے ہوئے اور نہ تکبر کرتے ہوئے، بلکہ میں ایک حقیر، کمزور، خوفزدہ اور پناہ کا طلبگار بندہ ہوں۔',
  ),
  'fa': _SajdahTexts(
    titleWajib: 'سجده واجب (فقه جعفری)',
    titleMustahabb: 'سجده مستحب (فقه جعفری)',
    badgeWajib: 'سجده واجب',
    badgeMustahabb: 'سجده مستحب',
    wajibPill: 'واجب',
    rulingWajib:
        'با خواندن یا شنیدن این آیه، سجده کردن فوراً واجب می‌شود. (قرائت این سوره در نمازهای واجب جایز نیست).',
    rulingMustahabb:
        'بر اساس فقه جعفری، سجده بر این آیه مستحب است، نه واجب.',
    duaHeading: 'دعای مستحب سجده تلاوت:',
    duaTranslation:
        'معبودی جز خدا نیست، به حق و راستی. معبودی جز خدا نیست، از روی ایمان و تصدیق. معبودی جز خدا نیست، از روی بندگی و عبودیت. پروردگارا! از روی بندگی و عبودیت برایت سجده کردم، نه از سر ننگ و نه از روی تکبر؛ بلکه من بنده‌ای خوار، ناتوان، ترسان و پناه‌جویم.',
  ),
  'ar': _SajdahTexts(
    titleWajib: 'سجدة واجبة (الفقه الجعفري)',
    titleMustahabb: 'سجدة مستحبة (الفقه الجعفري)',
    badgeWajib: 'سجدة واجبة',
    badgeMustahabb: 'سجدة مستحبة',
    wajibPill: 'واجب',
    rulingWajib:
        'السجود واجب فوراً عند قراءة هذه الآية أو استماعها. (لا تجوز قراءة هذه السورة في الصلاة الواجبة).',
    rulingMustahabb:
        'السجود عند هذه الآية مستحب في الفقه الجعفري وليس واجباً.',
    duaHeading: 'دعاء سجود التلاوة المستحب:',
    duaTranslation: '',
  ),
  'gu': _SajdahTexts(
    titleWajib: 'વાજિબ સજદો (ફિકહ-એ-જાફરિયા)',
    titleMustahabb: 'મુસ્તહબ સજદો (ફિકહ-એ-જાફરિયા)',
    badgeWajib: 'વાજિબ સજદો',
    badgeMustahabb: 'મુસ્તહબ સજદો',
    wajibPill: 'વાજિબ',
    rulingWajib:
        'આ આયતની તિલાવત કરવા કે સાંભળવા પર તરત જ સજદો કરવો વાજિબ છે. (વાજિબ નમાઝમાં આ સૂરહની તિલાવત કરવી જાયઝ નથી).',
    rulingMustahabb:
        'ફિકહ-એ-જાફરિયા મુજબ આ આયત પર સજદો કરવો મુસ્તહબ છે, વાજિબ નથી.',
    duaHeading: 'સજદા-એ-તિલાવતની દુઆ:',
    duaTranslation:
        'અલ્લાહ સિવાય કોઈ માબૂદ નથી, આ હક છે, આ હક છે. અલ્લાહ સિવાય કોઈ માબૂદ નથી, ઈમાન અને તસ્દીક સાથે. અલ્લાહ સિવાય કોઈ માબૂદ નથી, બંદગી અને ગુલામી સાથે. હે પરવરદિગાર! મેં બંદગી અને ગુલામી રૂપે તને સજદો કર્યો, ન તો શરમ સમજીને અને ન તો ઘમંડથી, બલ્કે હું એક હકીર, કમજોર, ડરતો અને પનાહ માંગનારો બંદો છું.',
  ),
};

/// All 15 Sajdah verses across the Quran, with 4 marked as Wajib and 11
/// as Mustahabb according to Shia Fiqh.
final Map<VerseKey, QuranSajdahVerse> quranSajdahVerses = {
  // 11 Mustahabb Sajdah verses
  VerseKey(7, 206): const QuranSajdahVerse(verse: VerseKey(7, 206), isWajib: false),
  VerseKey(13, 15): const QuranSajdahVerse(verse: VerseKey(13, 15), isWajib: false),
  VerseKey(16, 50): const QuranSajdahVerse(verse: VerseKey(16, 50), isWajib: false),
  VerseKey(17, 109): const QuranSajdahVerse(verse: VerseKey(17, 109), isWajib: false),
  VerseKey(19, 58): const QuranSajdahVerse(verse: VerseKey(19, 58), isWajib: false),
  VerseKey(22, 18): const QuranSajdahVerse(verse: VerseKey(22, 18), isWajib: false),
  VerseKey(22, 77): const QuranSajdahVerse(verse: VerseKey(22, 77), isWajib: false),
  VerseKey(25, 60): const QuranSajdahVerse(verse: VerseKey(25, 60), isWajib: false),
  VerseKey(27, 26): const QuranSajdahVerse(verse: VerseKey(27, 26), isWajib: false),
  VerseKey(38, 24): const QuranSajdahVerse(verse: VerseKey(38, 24), isWajib: false),
  VerseKey(84, 21): const QuranSajdahVerse(verse: VerseKey(84, 21), isWajib: false),

  // 4 Wajib Sajdah verses (Surahs of Aza'im)
  VerseKey(32, 15): const QuranSajdahVerse(verse: VerseKey(32, 15), isWajib: true),
  VerseKey(41, 38): const QuranSajdahVerse(verse: VerseKey(41, 38), isWajib: true),
  VerseKey(53, 62): const QuranSajdahVerse(verse: VerseKey(53, 62), isWajib: true),
  VerseKey(96, 19): const QuranSajdahVerse(verse: VerseKey(96, 19), isWajib: true),
};

/// The 4 Surahs of Aza'im containing Wajib Sajdah verses.
final Set<int> azaimSurahNumbers = quranSajdahVerses.entries
    .where((e) => e.value.isWajib)
    .map((e) => e.key.surah)
    .toSet();

/// Whether surah [surah] is one of the 4 Surahs of Aza'im (with a Wajib Sajdah).
bool isAzaimSurah(int surah) => azaimSurahNumbers.contains(surah);

/// Returns the localized label for an Aza'im Surah (e.g. for surah list subtitle).
String azaimSurahBadgeLabel([String? languageCode]) =>
    _texts(languageCode).badgeWajib;

/// Returns the Sajdah information for [verse], or null if it is not a Sajdah verse.
QuranSajdahVerse? sajdahVerseFor(VerseKey verse) => quranSajdahVerses[verse];
