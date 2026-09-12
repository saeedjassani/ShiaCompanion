import '../utils/quran_index.dart';

/// Verses widely cited in Shia tafsir as revealed about, or referring to,
/// Imam Ali (as) — alone or as part of Ahl al-Bayt.
///
/// This is a curated starting set of the verses cited most consistently
/// across Shia exegetical works (al-Mizan, al-Ghadir, and the hadith
/// collections behind them) rather than every verse any scholar has ever
/// linked to him by ta'wil — that list runs into the hundreds and is far
/// more contested. Each entry's note is the occasion or title the verse is
/// known by, kept short enough to sit in a tooltip - a pointer while
/// reading, not a tafsir sheet.
///
/// Keyed by [VerseKey] rather than surah/ayah ints so it composes directly
/// with the saved-verse and bookmark lookups the ayah viewer already does.
final Map<VerseKey, String> quranAliVerses = {
  // Laylat al-Mabit: Ali took the Prophet's place in his bed the night of
  // the Hijra, so the assassins watching the house would strike him instead.
  VerseKey(2, 207):
      'Regarding Imam Ali (as): he took the Prophet’s place in bed on the night of the Hijra.',

  // Mubahala: the Prophet brought only Ali, Fatima, Hasan and Husain (as) as
  // "our selves and our sons" to the mutual imprecation with Najran's
  // Christians.
  VerseKey(3, 61):
      'Ayat al-Mubahala: Imam Ali (as) was the one the Prophet brought as "our selves".',

  // The Well of Zamzam / Siqaya verse: contrasts giving water to pilgrims
  // and tending the Masjid with Ali's belief and striving in Allah's way.
  VerseKey(9, 19):
      'Revealed contrasting others’ claims with Imam Ali’s (as) belief and jihad.',

  // "You are only a warner, and for every people is a guide" — hadith from
  // Ibn Abbas identifies the guide as Ali (as).
  VerseKey(13, 7):
      'The "guide" named alongside the Prophet’s warning is identified as Imam Ali (as).',

  // Ayat al-Wilayah: "your guardian is only Allah, His Messenger, and those
  // who believe... while bowing" — Ali gave his ring in charity during ruku'.
  VerseKey(5, 55):
      'Ayat al-Wilayah: revealed when Imam Ali (as) gave his ring in charity during rukuʿ.',

  // Ikmal al-Din: "This day I have perfected your religion for you" —
  // revealed at Ghadir Khumm right after the announcement of Ali's wilayah.
  VerseKey(5, 3):
      'Revealed at Ghadir Khumm after the Prophet declared Imam Ali’s (as) wilayah.',

  // Ayat al-Tabligh: "O Messenger, deliver what has been revealed to you" —
  // the command to proclaim Ali's wilayah at Ghadir Khumm.
  VerseKey(5, 67):
      'Ayat al-Tabligh: commands the Prophet to proclaim Imam Ali’s (as) wilayah at Ghadir.',

  // Ayat al-Tathir: the purification of "the People of the House" — under
  // the cloak with the Prophet were Ali, Fatima, Hasan and Husain (as).
  VerseKey(33, 33):
      'Ayat al-Tathir: names Ahl al-Bayt, among them Imam Ali (as), as purified.',

  // Hal Ataa / al-Insan: Ali and Fatima (as) fed a poor man, an orphan and a
  // captive their own iftar on three successive nights while fasting.
  VerseKey(76, 8):
      'Hal Ataa: describes Imam Ali (as) and Sayyida Fatima (as) giving away their own food while fasting.',
  VerseKey(76, 9):
      'Hal Ataa: Imam Ali’s (as) household giving "only for the sake of Allah".',

  // "Best of creation" — hadith identifies this as Ali (as) and his Shia.
  VerseKey(98, 7):
      'Traditions identify Imam Ali (as) and his followers as "the best of creation" named here.',
};

/// The short note for [verse], or null when it is not one of the verses
/// curated above.
String? aliRelatedNoteFor(VerseKey verse) => quranAliVerses[verse];
