import '../utils/quran_index.dart';

/// Verses widely cited in Shia tafsir as revealed about, or referring to,
/// Imam Ali (a.s.) — alone or as part of Ahl al-Bayt.
///
/// This is a curated starting set of the verses cited most consistently
/// across Shia exegetical works (al-Mizan, al-Ghadir, al-Hakim al-Haskani's
/// Shawahid al-Tanzil, and the hadith collections behind them) rather than every verse any scholar has ever
/// linked to him by ta'wil — that list runs into the hundreds and is far
/// more contested. Each entry's note is the occasion or title the verse is
/// known by, kept short enough to sit in a tooltip - a pointer while
/// reading, not a tafsir sheet.
///
/// Keyed by [VerseKey] rather than surah/ayah ints so it composes directly
/// with the saved-verse and bookmark lookups the ayah viewer already does.
final Map<VerseKey, String> quranAliVerses = {
  // Laylat al-Mabit: Ali slept in the Prophet's bed the night of the Hijra
  // so the assassins surrounding the house would not know he had gone.
  VerseKey(2, 207):
      'Laylat al-Mabit: Imam Ali (a.s.) offered his own life by sleeping in the Prophet’s (s.a.w.a.) bed on the night of the Hijra.',

  // Ali had four dirhams and gave one by night, one by day, one secretly
  // and one openly (al-Wahidi's Asbab al-Nuzul, among others).
  VerseKey(2, 274):
      'Imam Ali (a.s.) had only four dirhams, and gave them in charity by night and by day, in secret and in the open.',

  // Mubahala: the Prophet brought only Ali, Fatimah, Hasan and Husayn.
  VerseKey(3, 61):
      'Ayat al-Mubahala: Imam Ali (a.s.) is the one the Prophet (s.a.w.a.) brought as “our selves”.',

  // Ulul-Amr: those vested with authority whose obedience is joined to the
  // Prophet's - in Shia tafsir, the twelve Imams, the first being Ali.
  VerseKey(4, 59):
      'Ayat Ulil-Amr: “those vested with authority”, whose obedience is joined to the Prophet’s (s.a.w.a.), are Imam Ali (a.s.) and the Imams after him.',

  // Ikmal al-Din: revealed at Ghadir Khumm after the announcement.
  VerseKey(5, 3):
      'Ayat Ikmal al-Din: revealed at Ghadir Khumm once Imam Ali (a.s.) had been declared master of the believers - the day the religion was perfected.',

  // Ayat al-Wilayah: Ali gave his ring to a beggar while in ruku'.
  VerseKey(5, 55):
      'Ayat al-Wilayah: revealed when Imam Ali (a.s.) gave his ring to a beggar while bowing in prayer.',

  // Ayat al-Tabligh: the command to proclaim Ali's wilayah at Ghadir.
  VerseKey(5, 67):
      'Ayat al-Tabligh: the command to the Prophet (s.a.w.a.) to proclaim Imam Ali’s (a.s.) wilayah at Ghadir Khumm.',

  // Surah Bara'ah: the Prophet recalled Abu Bakr and sent Ali to proclaim
  // its opening verses at the Hajj - "none may convey it but me or a man
  // from me".
  VerseKey(9, 3):
      'Imam Ali (a.s.) was sent to proclaim Surah Bara’ah at the Hajj: “none may deliver it but me or a man from me.”',

  // Siqayat al-Hajj: al-Abbas and Talha boasted of watering the pilgrims
  // and keeping the Ka'bah; Ali of his faith and jihad.
  VerseKey(9, 19):
      'Revealed when others boasted of watering the pilgrims and tending the Ka’bah, while Imam Ali (a.s.) spoke of his faith and jihad.',

  // "Be with the truthful" - the truthful being Ali and Ahl al-Bayt.
  VerseKey(9, 119):
      '“Be with the truthful”: the truthful are Imam Ali (a.s.) and the Ahl al-Bayt.',

  // "and a witness from him recites it" - the witness is Ali.
  VerseKey(11, 17):
      'Imam Ali (a.s.) is the “witness from him” who follows the Prophet (s.a.w.a.).',

  // "You are only a warner, and for every people is a guide" - the Prophet
  // placed his hand on Ali: "I am the warner, and you are the guide."
  VerseKey(13, 7):
      'The Prophet (s.a.w.a.) said: “I am the warner, and Ali is the guide.”',

  // "and whoever has knowledge of the Book".
  VerseKey(13, 43):
      'Imam Ali (a.s.) is the one “who has knowledge of the Book”.',

  // "the Most Merciful will place love for them" - in believers' hearts.
  VerseKey(19, 96):
      'Revealed about Imam Ali (a.s.): the All-Merciful placed love for him in the hearts of the believers.',

  // Hadith al-Dar / Yawm al-Indhar: at the feast for Banu Hashim only Ali
  // answered the call, and the Prophet named him brother and successor.
  VerseKey(26, 214):
      'Yawm al-Indhar: when the Prophet (s.a.w.a.) warned his clan, only Imam Ali (a.s.) answered, and was named his brother and successor.',

  // Ali and al-Walid ibn Uqbah.
  VerseKey(32, 18):
      'Revealed about Imam Ali (a.s.), the believer, set against al-Walid ibn Uqbah, the transgressor.',

  // "men true to their covenant ... and some still wait".
  VerseKey(33, 23):
      'Imam Ali (a.s.) is among the men true to their covenant with Allah - one of those who still waited.',

  // Ayat al-Tathir: the People of the Cloak.
  VerseKey(33, 33):
      'Ayat al-Tathir: revealed over the People of the Cloak - the Prophet (s.a.w.a.), Imam Ali, Lady Fatimah, Imam Hasan and Imam Husayn.',

  // "Stop them, they will be questioned" - about Ali's wilayah.
  VerseKey(37, 24):
      'On the Day of Judgement, people will be questioned about the wilayah of Imam Ali (a.s.).',

  // Ayat al-Mawaddah: love of the Prophet's near kin.
  VerseKey(42, 23):
      'Ayat al-Mawaddah: the kin whose love is the Prophet’s (s.a.w.a.) reward are Imam Ali, Lady Fatimah, Imam Hasan and Imam Husayn.',

  // Maraj al-Bahrayn: the two seas are Ali and Fatimah; the pearls and
  // coral that come from them (55:22) are Hasan and Husayn.
  VerseKey(55, 19):
      'The two seas that meet are Imam Ali (a.s.) and Lady Fatimah (s.a.); the pearl and coral are Imam Hasan and Imam Husayn.',

  // "The foremost, the foremost" - Ali, first to believe.
  VerseKey(56, 10):
      'Imam Ali (a.s.) is the foremost of the foremost - the first to believe in the Prophet (s.a.w.a.).',

  // Ayat al-Najwa: charity before a private audience - only Ali did it.
  VerseKey(58, 12):
      'Ayat al-Najwa: Imam Ali (a.s.) was the only one to give charity before speaking privately with the Prophet (s.a.w.a.).',

  // "Salih al-Mu'minin" - the righteous of the believers.
  VerseKey(66, 4):
      'The Prophet (s.a.w.a.) said Imam Ali (a.s.) is “the righteous among the believers”.',

  // "and retaining ears may retain it".
  VerseKey(69, 12):
      'The Prophet (s.a.w.a.) prayed that Imam Ali’s (a.s.) ear be the one that retains - and he never forgot what he heard.',

  // Sa'ala Sa'il: al-Nu'man ibn al-Harith rejected Ghadir and asked for a
  // punishment, and a stone fell on him.
  VerseKey(70, 1):
      'Revealed when a man who denied Imam Ali’s (a.s.) appointment at Ghadir asked for punishment - and it came.',

  // Hal Ata: Ali, Fatimah, Hasan and Husayn fasted three days on a vow and
  // gave their iftar to a poor man, an orphan and a captive.
  VerseKey(76, 7):
      'Surah al-Insan: Imam Ali (a.s.) and his family fasted three days to fulfil a vow for the recovery of Hasan and Husayn.',
  VerseKey(76, 8):
      'Surah al-Insan: each evening, Imam Ali (a.s.) and his family gave their iftar to the poor, the orphan and the captive.',
  VerseKey(76, 9):
      'Surah al-Insan: they fed others “only for the sake of Allah”, wanting no reward or thanks.',

  // "The Great News" - Ali: "I am the Great News."
  VerseKey(78, 2):
      'Imam Ali (a.s.) said: “I am the Great News (al-Naba al-Azim).”',

  // "Best of creation" - the Prophet to Ali: "you and your Shia".
  VerseKey(98, 7):
      'The Prophet (s.a.w.a.) said to Imam Ali (a.s.): “the best of creation” are you and your Shia.',
};

/// The short note for [verse], or null when it is not one of the verses
/// curated above.
String? aliRelatedNoteFor(VerseKey verse) => quranAliVerses[verse];
