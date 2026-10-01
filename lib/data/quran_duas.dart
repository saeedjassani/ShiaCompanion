import '../utils/quran_index.dart';

/// One supplication the Quran itself contains - a prophet's, the believers'
/// or the angels' - as the Duas collection lists it.
class QuranDua {
  const QuranDua(this.verse, this.opening, this.note, {this.endAyah});

  /// The ayah the dua starts on; the collection opens the reader here.
  final VerseKey verse;

  /// The last ayah when the dua runs over several, e.g. Prophet Musa's
  /// "Rabbish-rah li sadri" at 20:25-28. Null for a single-ayah dua.
  final int? endAyah;

  /// The dua's opening words, transliterated - what people know it by.
  final String opening;

  /// Who made the dua, or what it asks for, in one short line.
  final String note;
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
      endAyah: 128),
  QuranDua(VerseKey(2, 201), 'Rabbana Atina fid-Dunya Hasanah',
      'For good in this world and the hereafter'),
  QuranDua(VerseKey(2, 250), 'Rabbana Afrigh ’Alayna Sabran',
      'Talut’s army facing Jalut: for patience and victory'),
  QuranDua(VerseKey(2, 286), 'Rabbana La Tu’akhidhna',
      'The closing dua of al-Baqarah'),
  QuranDua(VerseKey(3, 8), 'Rabbana La Tuzigh Qulubana',
      'That hearts not swerve after guidance',
      endAyah: 9),
  QuranDua(VerseKey(3, 16), 'Rabbana Innana Amanna',
      'For forgiveness and protection from the Fire'),
  QuranDua(VerseKey(3, 26), 'Qulillahumma Malikal-Mulk',
      'Allah, Master of all sovereignty',
      endAyah: 27),
  QuranDua(VerseKey(3, 38), 'Rabbi Hab Li Min Ladunka Dhurriyyatan Tayyibah',
      'Prophet Zakariyya (a.s.): for righteous offspring'),
  QuranDua(VerseKey(3, 53), 'Rabbana Amanna Bima Anzalta',
      'The disciples of Prophet ’Isa (a.s.)'),
  QuranDua(VerseKey(3, 147), 'Rabbanagh-fir Lana Dhunubana',
      'The steadfast companions of the prophets'),
  QuranDua(VerseKey(3, 191), 'Rabbana Ma Khalaqta Hadha Batila',
      'Those who reflect on the creation of the heavens and earth',
      endAyah: 194),
  QuranDua(VerseKey(5, 83), 'Rabbana Amanna Faktubna Ma’ash-Shahidin',
      'Those moved to tears on hearing the truth'),
  QuranDua(VerseKey(5, 114), 'Allahumma Rabbana Anzil ’Alayna Ma’idah',
      'Prophet ’Isa (a.s.): for the table spread from heaven'),
  QuranDua(VerseKey(7, 23), 'Rabbana Zalamna Anfusana',
      'Prophet Adam (a.s.) and Hawwa, in repentance'),
  QuranDua(VerseKey(7, 47), 'Rabbana La Taj’alna Ma’al-Qawmiz-Zalimin',
      'That we not be placed with the wrongdoers'),
  QuranDua(VerseKey(7, 89), 'Rabbanaf-tah Baynana',
      'Prophet Shu’ayb (a.s.): for judgement with truth'),
  QuranDua(VerseKey(7, 126), 'Rabbana Afrigh ’Alayna Sabran wa Tawaffana',
      'Pharaoh’s magicians, after believing'),
  QuranDua(VerseKey(7, 151), 'Rabbigh-fir Li wa Li-Akhi',
      'Prophet Musa (a.s.): for himself and Harun (a.s.)'),
  QuranDua(VerseKey(7, 155), 'Anta Waliyyuna Faghfir Lana',
      'Prophet Musa (a.s.): for forgiveness and mercy',
      endAyah: 156),
  QuranDua(VerseKey(10, 85), 'Rabbana La Taj’alna Fitnatan',
      'The people of Prophet Musa (a.s.): for deliverance',
      endAyah: 86),
  QuranDua(VerseKey(11, 47), 'Rabbi Inni A’udhu Bika',
      'Prophet Nuh (a.s.): refuge from asking what he has no knowledge of'),
  QuranDua(VerseKey(12, 101), 'Fatiras-Samawati wal-Ard',
      'Prophet Yusuf (a.s.): to die in submission and join the righteous'),
  QuranDua(VerseKey(14, 40), 'Rabbij-’alni Muqimas-Salah',
      'Prophet Ibrahim (a.s.): for prayer, and forgiveness for his parents',
      endAyah: 41),
  QuranDua(VerseKey(17, 24), 'Rabbir-hamhuma Kama Rabbayani Saghira',
      'For one’s parents'),
  QuranDua(VerseKey(17, 80), 'Rabbi Adkhilni Mudkhala Sidq',
      'For a truthful entrance and exit, and a helping authority'),
  QuranDua(VerseKey(18, 10), 'Rabbana Atina Min Ladunka Rahmah',
      'The Companions of the Cave'),
  QuranDua(VerseKey(20, 25), 'Rabbish-rah Li Sadri',
      'Prophet Musa (a.s.): for an open heart and an easy task',
      endAyah: 28),
  QuranDua(VerseKey(20, 114), 'Rabbi Zidni ’Ilma', 'For more knowledge'),
  QuranDua(VerseKey(21, 83), 'Anni Massaniyad-Durr',
      'Prophet Ayyub (a.s.), in his affliction'),
  QuranDua(VerseKey(21, 87), 'La Ilaha Illa Anta Subhanaka',
      'Prophet Yunus (a.s.), in the belly of the whale'),
  QuranDua(VerseKey(21, 89), 'Rabbi La Tadharni Farda',
      'Prophet Zakariyya (a.s.): not to be left childless'),
  QuranDua(VerseKey(23, 29), 'Rabbi Anzilni Munzalan Mubaraka',
      'Prophet Nuh (a.s.): for a blessed landing'),
  QuranDua(VerseKey(23, 97), 'Rabbi A’udhu Bika Min Hamazatish-Shayatin',
      'Refuge from the whispers of the devils',
      endAyah: 98),
  QuranDua(
      VerseKey(23, 118), 'Rabbigh-fir Warham', 'For forgiveness and mercy'),
  QuranDua(VerseKey(25, 65), 'Rabbanas-rif ’Anna ’Adhaba Jahannam',
      'The servants of the Most Merciful: refuge from Hell',
      endAyah: 66),
  QuranDua(VerseKey(25, 74), 'Rabbana Hab Lana Min Azwajina',
      'For spouses and children who are the coolness of the eyes'),
  QuranDua(VerseKey(26, 83), 'Rabbi Hab Li Hukma',
      'Prophet Ibrahim (a.s.): for wisdom and the Garden',
      endAyah: 85),
  QuranDua(VerseKey(26, 169), 'Rabbi Najjini wa Ahli',
      'Prophet Lut (a.s.): to be saved from what his people did'),
  QuranDua(VerseKey(27, 19), 'Rabbi Awzi’ni An Ashkura',
      'Prophet Sulayman (a.s.): for gratitude and righteous deeds'),
  QuranDua(VerseKey(28, 16), 'Rabbi Inni Zalamtu Nafsi',
      'Prophet Musa (a.s.), seeking forgiveness'),
  QuranDua(VerseKey(28, 21), 'Rabbi Najjini Minal-Qawmiz-Zalimin',
      'Prophet Musa (a.s.), fleeing Egypt'),
  QuranDua(VerseKey(28, 24), 'Rabbi Inni Lima Anzalta Ilayya Min Khayrin Faqir',
      'Prophet Musa (a.s.) at Madyan, in need of any good'),
  QuranDua(VerseKey(29, 30), 'Rabbin-surni ’Alal-Qawmil-Mufsidin',
      'Prophet Lut (a.s.): for help against the corrupt'),
  QuranDua(VerseKey(37, 100), 'Rabbi Hab Li Minas-Salihin',
      'Prophet Ibrahim (a.s.): for a righteous son'),
  QuranDua(VerseKey(38, 35), 'Rabbigh-fir Li wa Hab Li Mulka',
      'Prophet Sulayman (a.s.): for forgiveness and a kingdom'),
  QuranDua(VerseKey(40, 7), 'Rabbana Wasi’ta Kulla Shay’',
      'The angels bearing the Throne, for the believers',
      endAyah: 9),
  QuranDua(VerseKey(46, 15), 'Rabbi Awzi’ni An Ashkura Ni’matak',
      'At forty: for gratitude and righteous offspring'),
  QuranDua(VerseKey(54, 10), 'Anni Maghlubun Fantasir',
      'Prophet Nuh (a.s.): overpowered, asking for help'),
  QuranDua(VerseKey(59, 10), 'Rabbanagh-fir Lana wa Li-Ikhwanina',
      'For the believers who came before us'),
  QuranDua(VerseKey(60, 4), 'Rabbana ’Alayka Tawakkalna',
      'Prophet Ibrahim (a.s.) and those with him',
      endAyah: 5),
  QuranDua(VerseKey(66, 8), 'Rabbana Atmim Lana Nurana',
      'The believers on the Day of Judgement'),
  QuranDua(VerseKey(66, 11), 'Rabbibni Li ’Indaka Baytan Fil-Jannah',
      'Asiyah, the wife of Pharaoh'),
  QuranDua(VerseKey(71, 28), 'Rabbigh-fir Li wa Li-Walidayya',
      'Prophet Nuh (a.s.): for his parents and the believers'),
];
