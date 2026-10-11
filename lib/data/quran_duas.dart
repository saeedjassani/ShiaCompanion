import '../utils/quran_index.dart';
import 'quran_collections_i18n.dart';

/// One supplication the Quran itself contains - a prophet's, the believers'
/// or the angels' - as the Duas collection lists it.
class QuranDua {
  const QuranDua(this.verse, this.opening, this.note,
      {this.endAyah, required this.arabic});

  /// The ayah the dua starts on; the collection opens the reader here.
  final VerseKey verse;

  /// The last ayah when the dua runs over several, e.g. Prophet Musa's
  /// "Rabbish-rah li sadri" at 20:25-28. Null for a single-ayah dua.
  final int? endAyah;

  /// The dua's opening words, transliterated - what people know it by.
  final String opening;

  /// The same opening words in the Quran's own Arabic, copied from the
  /// surah's text rather than typed - what a reader outside English sees in
  /// place of [opening], since the app shows them no transliteration.
  ///
  /// Where the dua starts mid-sentence ("qul rabbi..."), the shadda the
  /// first letter takes from the word before it is dropped.
  final String arabic;

  /// Who made the dua, or what it asks for, in one short line, in English.
  /// [displayNote] is what to show.
  final String note;

  /// [note] in the app language.
  String get displayNote => quranCollectionsText()?.duas['$verse'] ?? note;
}

/// The duas of the Quran, in mushaf order.
///
/// Verse-level picks, unlike the zikr entries above them in the Duas
/// collection (Ayat al-Kursi, Dua Khatm al-Quran), which are whole zikrs of
/// their own. Each opens the reader at its first ayah, so the Arabic,
/// translation and surrounding verses come from the Quran itself rather than
/// a second copy kept here.
const List<QuranDua> quranDuas = [
  QuranDua(VerseKey(2, 127), 'Rabbana Taqabbal Minna',
      'Prophets Ibrahim and Isma’il (a.s.) raising the Ka’bah',
      endAyah: 128, arabic: 'رَبَّنَا تَقَبَّلْ مِنَّا'),
  QuranDua(VerseKey(2, 201), 'Rabbana Atina fid-Dunya Hasanah',
      'For good in this world and the hereafter',
      arabic: 'رَبَّنَآ اٰتِنَا فِى الدُّنْيَا حَسَنَةً'),
  QuranDua(VerseKey(2, 250), 'Rabbana Afrigh ’Alayna Sabran',
      'Talut’s army facing Jalut: for patience and victory',
      arabic: 'رَبَّنَآ اَفْرِغْ عَلَيْنَا صَبْرًا'),
  QuranDua(VerseKey(2, 286), 'Rabbana La Tu’akhidhna',
      'The closing dua of al-Baqarah',
      arabic: 'رَبَّنَا لَا تُؤَاخِذْنَاۤ'),
  QuranDua(VerseKey(3, 8), 'Rabbana La Tuzigh Qulubana',
      'That hearts not swerve after guidance',
      endAyah: 9, arabic: 'رَبَّنَا لَا تُزِغْ قُلُوْبَنَا'),
  QuranDua(VerseKey(3, 16), 'Rabbana Innana Amanna',
      'For forgiveness and protection from the Fire',
      arabic: 'رَبَّنَاۤ اِنَّنَاۤ اٰمَنَّا'),
  QuranDua(VerseKey(3, 26), 'Qulillahumma Malikal-Mulk',
      'Allah, Master of all sovereignty',
      endAyah: 27, arabic: 'قُلِ اللّٰهُمَّ مٰلِكَ الْمُلْكِ'),
  QuranDua(VerseKey(3, 38), 'Rabbi Hab Li Min Ladunka Dhurriyyatan Tayyibah',
      'Prophet Zakariyya (a.s.): for righteous offspring',
      arabic: 'رَبِّ هَبْ لِىْ مِنْ لَّدُنْكَ ذُرِّيَّةً طَيِّبَةً'),
  QuranDua(VerseKey(3, 53), 'Rabbana Amanna Bima Anzalta',
      'The disciples of Prophet ’Isa (a.s.)',
      arabic: 'رَبَّنَاۤ اٰمَنَّا بِمَاۤ اَنْزَلْتَ'),
  QuranDua(VerseKey(3, 147), 'Rabbanagh-fir Lana Dhunubana',
      'The steadfast companions of the prophets',
      arabic: 'رَبَّنَا اغْفِرْ لَنَا ذُنُوْبَنَا'),
  QuranDua(VerseKey(3, 191), 'Rabbana Ma Khalaqta Hadha Batila',
      'Those who reflect on the creation of the heavens and earth',
      endAyah: 194, arabic: 'رَبَّنَا مَا خَلَقْتَ هٰذَا بَاطِلًا'),
  QuranDua(VerseKey(5, 83), 'Rabbana Amanna Faktubna Ma’ash-Shahidin',
      'Those moved to tears on hearing the truth',
      arabic: 'رَبَّنَاۤ اٰمَنَّا فَاكْتُبْنَا مَعَ الشّٰهِدِيْنَ'),
  QuranDua(VerseKey(5, 114), 'Allahumma Rabbana Anzil ’Alayna Ma’idah',
      'Prophet ’Isa (a.s.): for the table spread from heaven',
      arabic: 'اللّٰهُمَّ رَبَّنَاۤ اَنْزِلْ عَلَيْنَا مَآئِدَةً'),
  QuranDua(VerseKey(7, 23), 'Rabbana Zalamna Anfusana',
      'Prophet Adam (a.s.) and Hawwa, in repentance',
      arabic: 'رَبَّنَا ظَلَمْنَاۤ اَنْفُسَنَا'),
  QuranDua(VerseKey(7, 47), 'Rabbana La Taj’alna Ma’al-Qawmiz-Zalimin',
      'That we not be placed with the wrongdoers',
      arabic: 'رَبَّنَا لَا تَجْعَلْنَا مَعَ الْقَوْمِ الظّٰلِمِيْنَ'),
  QuranDua(VerseKey(7, 89), 'Rabbanaf-tah Baynana',
      'Prophet Shu’ayb (a.s.): for judgement with truth',
      arabic: 'رَبَّنَا افْتَحْ بَيْنَنَا'),
  QuranDua(VerseKey(7, 126), 'Rabbana Afrigh ’Alayna Sabran wa Tawaffana',
      'Pharaoh’s magicians, after believing',
      arabic: 'رَبَّنَاۤ اَفْرِغْ عَلَيْنَا صَبْرًا وَّتَوَفَّنَا'),
  QuranDua(VerseKey(7, 151), 'Rabbigh-fir Li wa Li-Akhi',
      'Prophet Musa (a.s.): for himself and Harun (a.s.)',
      arabic: 'رَبِّ اغْفِرْ لِىْ وَلِاَخِىْ'),
  QuranDua(VerseKey(7, 155), 'Anta Waliyyuna Faghfir Lana',
      'Prophet Musa (a.s.): for forgiveness and mercy',
      endAyah: 156, arabic: 'اَنْتَ وَلِيُّنَا فَاغْفِرْ لَنَا'),
  QuranDua(VerseKey(10, 85), 'Rabbana La Taj’alna Fitnatan',
      'The people of Prophet Musa (a.s.): for deliverance',
      endAyah: 86, arabic: 'رَبَّنَا لَا تَجْعَلْنَا فِتْنَةً'),
  QuranDua(VerseKey(11, 47), 'Rabbi Inni A’udhu Bika',
      'Prophet Nuh (a.s.): refuge from asking what he has no knowledge of',
      arabic: 'رَبِّ اِنِّىْۤ اَعُوْذُ بِكَ'),
  QuranDua(VerseKey(12, 101), 'Fatiras-Samawati wal-Ard',
      'Prophet Yusuf (a.s.): to die in submission and join the righteous',
      arabic: 'فَاطِرَ السَّمٰوٰتِ وَالْاَرْضِ'),
  QuranDua(VerseKey(14, 40), 'Rabbij-’alni Muqimas-Salah',
      'Prophet Ibrahim (a.s.): for prayer, and forgiveness for his parents',
      endAyah: 41, arabic: 'رَبِّ اجْعَلْنِىْ مُقِيْمَ الصَّلٰوةِ'),
  QuranDua(VerseKey(17, 24), 'Rabbir-hamhuma Kama Rabbayani Saghira',
      'For one’s parents',
      arabic: 'رَبِّ ارْحَمْهُمَا كَمَا رَبَّيٰنِىْ صَغِيْرًا'),
  QuranDua(VerseKey(17, 80), 'Rabbi Adkhilni Mudkhala Sidq',
      'For a truthful entrance and exit, and a helping authority',
      arabic: 'رَبِّ اَدْخِلْنِىْ مُدْخَلَ صِدْقٍ'),
  QuranDua(VerseKey(18, 10), 'Rabbana Atina Min Ladunka Rahmah',
      'The Companions of the Cave',
      arabic: 'رَبَّنَاۤ اٰتِنَا مِنْ لَّدُنْكَ رَحْمَةً'),
  QuranDua(VerseKey(20, 25), 'Rabbish-rah Li Sadri',
      'Prophet Musa (a.s.): for an open heart and an easy task',
      endAyah: 28, arabic: 'رَبِّ اشْرَحْ لِىْ صَدْرِىْ'),
  QuranDua(VerseKey(20, 114), 'Rabbi Zidni ’Ilma', 'For more knowledge',
      arabic: 'رَبِّ زِدْنِىْ عِلْمًا'),
  QuranDua(VerseKey(21, 83), 'Anni Massaniyad-Durr',
      'Prophet Ayyub (a.s.), in his affliction',
      arabic: 'اَنِّىْ مَسَّنِىَ الضُّرُّ'),
  QuranDua(VerseKey(21, 87), 'La Ilaha Illa Anta Subhanaka',
      'Prophet Yunus (a.s.), in the belly of the whale',
      arabic: 'اَنْ لَّاۤ اِلٰهَ اِلَّاۤ اَنْتَ سُبْحٰنَكَ'),
  QuranDua(VerseKey(21, 89), 'Rabbi La Tadharni Farda',
      'Prophet Zakariyya (a.s.): not to be left childless',
      arabic: 'رَبِّ لَا تَذَرْنِىْ فَرْدًا'),
  QuranDua(VerseKey(23, 29), 'Rabbi Anzilni Munzalan Mubaraka',
      'Prophet Nuh (a.s.): for a blessed landing',
      arabic: 'رَبِّ اَنْزِلْنِىْ مُنْزَلًا مُّبٰرَكًا'),
  QuranDua(VerseKey(23, 97), 'Rabbi A’udhu Bika Min Hamazatish-Shayatin',
      'Refuge from the whispers of the devils',
      endAyah: 98, arabic: 'رَبِّ اَعُوْذُ بِكَ مِنْ هَمَزٰتِ الشَّيٰطِيْنِ'),
  QuranDua(VerseKey(23, 118), 'Rabbigh-fir Warham', 'For forgiveness and mercy',
      arabic: 'رَبِّ اغْفِرْ وَارْحَمْ'),
  QuranDua(VerseKey(25, 65), 'Rabbanas-rif ’Anna ’Adhaba Jahannam',
      'The servants of the Most Merciful: refuge from Hell',
      endAyah: 66, arabic: 'رَبَّنَا اصْرِفْ عَنَّا عَذَابَ جَهَنَّمَ'),
  QuranDua(VerseKey(25, 74), 'Rabbana Hab Lana Min Azwajina',
      'For spouses and children who are the coolness of the eyes',
      arabic: 'رَبَّنَا هَبْ لَنَا مِنْ اَزْوَاجِنَا'),
  QuranDua(VerseKey(26, 83), 'Rabbi Hab Li Hukma',
      'Prophet Ibrahim (a.s.): for wisdom and the Garden',
      endAyah: 85, arabic: 'رَبِّ هَبْ لِىْ حُكْمًا'),
  QuranDua(VerseKey(26, 169), 'Rabbi Najjini wa Ahli',
      'Prophet Lut (a.s.): to be saved from what his people did',
      arabic: 'رَبِّ نَجِّنِىْ وَاَهْلِىْ'),
  QuranDua(VerseKey(27, 19), 'Rabbi Awzi’ni An Ashkura',
      'Prophet Sulayman (a.s.): for gratitude and righteous deeds',
      arabic: 'رَبِّ اَوْزِعْنِىْۤ اَنْ اَشْكُرَ'),
  QuranDua(VerseKey(28, 16), 'Rabbi Inni Zalamtu Nafsi',
      'Prophet Musa (a.s.), seeking forgiveness',
      arabic: 'رَبِّ اِنِّىْ ظَلَمْتُ نَفْسِىْ'),
  QuranDua(VerseKey(28, 21), 'Rabbi Najjini Minal-Qawmiz-Zalimin',
      'Prophet Musa (a.s.), fleeing Egypt',
      arabic: 'رَبِّ نَجِّنِىْ مِنَ الْقَوْمِ الظّٰلِمِيْنَ'),
  QuranDua(VerseKey(28, 24), 'Rabbi Inni Lima Anzalta Ilayya Min Khayrin Faqir',
      'Prophet Musa (a.s.) at Madyan, in need of any good',
      arabic: 'رَبِّ اِنِّىْ لِمَاۤ اَنْزَلْتَ اِلَىَّ مِنْ خَيْرٍ فَقِيْرٌ'),
  QuranDua(VerseKey(29, 30), 'Rabbin-surni ’Alal-Qawmil-Mufsidin',
      'Prophet Lut (a.s.): for help against the corrupt',
      arabic: 'رَبِّ انْصُرْنِىْ عَلَى الْقَوْمِ الْمُفْسِدِيْنَ'),
  QuranDua(VerseKey(37, 100), 'Rabbi Hab Li Minas-Salihin',
      'Prophet Ibrahim (a.s.): for a righteous son',
      arabic: 'رَبِّ هَبْ لِىْ مِنَ الصّٰلِحِيْنَ'),
  QuranDua(VerseKey(38, 35), 'Rabbigh-fir Li wa Hab Li Mulka',
      'Prophet Sulayman (a.s.): for forgiveness and a kingdom',
      arabic: 'رَبِّ اغْفِرْ لِىْ وَهَبْ لِىْ مُلْكًا'),
  QuranDua(VerseKey(40, 7), 'Rabbana Wasi’ta Kulla Shay’',
      'The angels bearing the Throne, for the believers',
      endAyah: 9, arabic: 'رَبَّنَا وَسِعْتَ كُلَّ شَىْءٍ'),
  QuranDua(VerseKey(46, 15), 'Rabbi Awzi’ni An Ashkura Ni’matak',
      'At forty: for gratitude and righteous offspring',
      arabic: 'رَبِّ اَوْزِعْنِىْۤ اَنْ اَشْكُرَ نِعْمَتَكَ'),
  QuranDua(VerseKey(54, 10), 'Anni Maghlubun Fantasir',
      'Prophet Nuh (a.s.): overpowered, asking for help',
      arabic: 'اَنِّىْ مَغْلُوْبٌ فَانْتَصِرْ'),
  QuranDua(VerseKey(59, 10), 'Rabbanagh-fir Lana wa Li-Ikhwanina',
      'For the believers who came before us',
      arabic: 'رَبَّنَا اغْفِرْ لَنَا وَلِاِخْوَانِنَا'),
  QuranDua(VerseKey(60, 4), 'Rabbana ’Alayka Tawakkalna',
      'Prophet Ibrahim (a.s.) and those with him',
      endAyah: 5, arabic: 'رَبَّنَا عَلَيْكَ تَوَكَّلْنَا'),
  QuranDua(VerseKey(66, 8), 'Rabbana Atmim Lana Nurana',
      'The believers on the Day of Judgement',
      arabic: 'رَبَّنَاۤ اَ تْمِمْ لَنَا نُوْرَنَا'),
  QuranDua(VerseKey(66, 11), 'Rabbibni Li ’Indaka Baytan Fil-Jannah',
      'Asiyah, the wife of Pharaoh',
      arabic: 'رَبِّ ابْنِ لِىْ عِنْدَكَ بَيْتًا فِى الْجَنَّةِ'),
  QuranDua(VerseKey(71, 28), 'Rabbigh-fir Li wa Li-Walidayya',
      'Prophet Nuh (a.s.): for his parents and the believers',
      arabic: 'رَبِّ اغْفِرْلِىْ وَلِوَالِدَىَّ'),
];
