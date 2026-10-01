import '../utils/quran_index.dart';

/// One episode of a prophet's story as the Quran tells it.
class QuranStory {
  const QuranStory(this.prophet, this.title, this.verse, this.endAyah);

  /// The heading the episode is grouped under, e.g. `Musa (a.s.)`.
  final String prophet;

  /// The episode, in a few words.
  final String title;

  /// The ayah the episode starts on; the collection opens the reader here.
  final VerseKey verse;

  /// The ayah it ends on, in the same surah.
  final int endAyah;
}

/// The stories of the prophets, grouped by prophet in the order they lived
/// and, within a prophet, in the order of their lives.
///
/// Each entry is the fullest single passage for that episode rather than
/// every place the Quran returns to it - Musa and Pharaoh alone recur in
/// dozens of surahs. The collection opens the reader at the first ayah, so
/// the text itself comes from the Quran rather than a copy kept here.
const List<QuranStory> quranProphetStories = [
  QuranStory(
      'Adam (a.s.)', 'The creation of Adam and the fall', VerseKey(2, 30), 39),
  QuranStory('Adam (a.s.)', 'The two sons of Adam: Habil and Qabil',
      VerseKey(5, 27), 31),
  QuranStory('Idris (a.s.)', 'Raised to a high station', VerseKey(19, 56), 57),
  QuranStory('Nuh (a.s.)', 'The call to his people, the ark and the flood',
      VerseKey(11, 25), 49),
  QuranStory('Nuh (a.s.)', 'Surah Nuh: calling his people night and day',
      VerseKey(71, 1), 28),
  QuranStory('Hud (a.s.)', 'The people of ‘Ad', VerseKey(11, 50), 60),
  QuranStory('Salih (a.s.)', 'Thamud and the she-camel', VerseKey(11, 61), 68),
  QuranStory(
      'Ibrahim (a.s.)', 'The star, the moon and the sun', VerseKey(6, 74), 83),
  QuranStory('Ibrahim (a.s.)', 'Breaking the idols and the fire made cool',
      VerseKey(21, 51), 73),
  QuranStory('Ibrahim (a.s.)', 'The four birds brought back to life',
      VerseKey(2, 260), 260),
  QuranStory('Ibrahim (a.s.)', 'The angel guests and the news of Ishaq',
      VerseKey(11, 69), 76),
  QuranStory('Ibrahim (a.s.)', 'The dream and the sacrifice of Isma’il',
      VerseKey(37, 99), 113),
  QuranStory(
      'Lut (a.s.)', 'The destruction of his people', VerseKey(11, 77), 83),
  QuranStory(
      'Yusuf (a.s.)', 'The best of stories: Surah Yusuf', VerseKey(12, 4), 101),
  QuranStory('Shu’ayb (a.s.)', 'The people of Madyan', VerseKey(11, 84), 95),
  QuranStory('Ayyub (a.s.)', 'Patience in affliction', VerseKey(38, 41), 44),
  QuranStory('Musa (a.s.)', 'Birth, Pharaoh’s palace and flight to Madyan',
      VerseKey(28, 3), 28),
  QuranStory('Musa (a.s.)', 'The fire at Tur and the call to prophethood',
      VerseKey(20, 9), 36),
  QuranStory('Musa (a.s.)', 'Before Pharaoh: the magicians and the plagues',
      VerseKey(7, 103), 137),
  QuranStory('Musa (a.s.)', 'Parting the sea', VerseKey(26, 52), 68),
  QuranStory(
      'Musa (a.s.)', 'The golden calf and al-Samiri', VerseKey(20, 83), 98),
  QuranStory('Musa (a.s.)', 'The cow of Bani Isra’il', VerseKey(2, 67), 73),
  QuranStory('Musa (a.s.)', 'Musa and al-Khidr', VerseKey(18, 60), 82),
  QuranStory('Dawud (a.s.)', 'Talut, Jalut and the young Dawud',
      VerseKey(2, 246), 251),
  QuranStory('Dawud (a.s.)', 'The two litigants', VerseKey(38, 21), 26),
  QuranStory('Sulayman (a.s.)', 'The ant, the hoopoe and the Queen of Saba',
      VerseKey(27, 15), 44),
  QuranStory('Sulayman (a.s.)', 'The jinn at work and his death',
      VerseKey(34, 12), 14),
  QuranStory(
      'Ilyas (a.s.)', 'Against the worship of Ba’l', VerseKey(37, 123), 132),
  QuranStory('Yunus (a.s.)', 'The whale', VerseKey(37, 139), 148),
  QuranStory(
      'Zakariyya and Yahya (a.s.)', 'A son in old age', VerseKey(19, 2), 15),
  QuranStory(
      'Maryam (s.a.) and ‘Isa (a.s.)',
      'The birth of Maryam and her provision in the mihrab',
      VerseKey(3, 35),
      37),
  QuranStory('Maryam (s.a.) and ‘Isa (a.s.)',
      'The birth of ‘Isa, who spoke from the cradle', VerseKey(19, 16), 36),
  QuranStory('Maryam (s.a.) and ‘Isa (a.s.)',
      'The miracles of ‘Isa and the table from heaven', VerseKey(5, 110), 115),
  QuranStory('Muhammad (s.a.w.a.)', 'The Night Journey', VerseKey(17, 1), 1),
  QuranStory('Muhammad (s.a.w.a.)', 'The Ascension', VerseKey(53, 1), 18),
  QuranStory(
      'Muhammad (s.a.w.a.)', 'The cave of the Hijra', VerseKey(9, 40), 40),
];
