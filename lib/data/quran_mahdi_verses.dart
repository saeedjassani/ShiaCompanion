import '../utils/quran_index.dart';

/// Verses the hadith of the Imams (a.s.) read as being about Imam al-Mahdi
/// (a.t.f.s.) - his occultation, his rising and the world after it.
///
/// Like [quranAliVerses], a curated starting set: the verses cited most
/// consistently in the works that gather these narrations (al-Saduq's Kamal
/// al-Din, al-Nu'mani's al-Ghaybah, al-Tusi's al-Ghaybah, and the tafsirs
/// that draw on them - al-Qummi, al-Ayyashi, al-Burhan) rather than every
/// verse ever linked to him by ta'wil. Each note names the phrase and how it
/// is read, short enough to sit under a list row.
final Map<VerseKey, String> quranMahdiVerses = {
  // Kamal al-Din, from Imam al-Sadiq: those who affirm the Qa'im's rising.
  VerseKey(2, 3):
      '“Those who believe in the unseen”: read by Imam al-Sadiq (a.s.) as those who believe in the Hidden Imam and his rising.',

  // al-Ghaybah (al-Nu'mani), from Imam al-Baqir.
  VerseKey(2, 148):
      '“Wherever you are, Allah will bring you all together”: the 313 companions of Imam al-Mahdi (a.t.f.s.), gathered to him in a single night.',

  // Kamal al-Din, from Imam al-Sadiq: the awaited sign is the Qa'im.
  VerseKey(6, 158):
      '“The day some of your Lord’s signs come”: read in the hadith of the Imams (a.s.) as the day Imam al-Mahdi (a.t.f.s.) rises.',

  VerseKey(9, 33):
      'That Islam be made to prevail over all religion: a promise the Imams (a.s.) said is fulfilled when Imam al-Mahdi (a.t.f.s.) rises.',

  VerseKey(11, 8):
      '“An appointed nation” (ummah ma‘dudah): the companions of Imam al-Mahdi (a.t.f.s.), numbering as many as the people of Badr.',

  // He is greeted "al-salamu 'alayka ya Baqiyyat Allah".
  VerseKey(11, 86):
      'Baqiyyatullah, “the remnant of Allah”: the title Imam al-Mahdi (a.t.f.s.) is greeted by when he rises.',

  // Imam Husayn's avenger.
  VerseKey(17, 33):
      '“We have given his heir authority”: Imam al-Mahdi (a.t.f.s.), who will avenge the blood of Imam Husayn (a.s.).',

  VerseKey(21, 105):
      '“My righteous servants shall inherit the earth”: Imam al-Mahdi (a.t.f.s.) and his companions.',

  VerseKey(22, 41):
      '“Those who, if We establish them in the land, keep up prayer”: the family of Muhammad (s.a.w.a.), established through Imam al-Mahdi (a.t.f.s.).',

  VerseKey(24, 55):
      'The promise of succession, an established religion and security after fear: fulfilled in Imam al-Mahdi (a.t.f.s.) and his companions.',

  // The heavenly call (al-sayhah), one of the certain signs.
  VerseKey(26, 4):
      'A sign from the sky to which necks bow: the heavenly call in the name of Imam al-Mahdi (a.t.f.s.), one of the signs of his rising.',

  // Imam Ali: "the world will incline to us as the camel to her young".
  VerseKey(28, 5):
      'To favour the oppressed and make them Imams and inheritors: Ahl al-Bayt (a.s.), whose rule returns with Imam al-Mahdi (a.t.f.s.).',

  VerseKey(57, 17):
      '“Allah revives the earth after its death”: through Imam al-Mahdi (a.t.f.s.), who fills it with justice after it was filled with oppression.',

  // Imam al-Rida / al-Kazim: your Imam hidden from you.
  VerseKey(67, 30):
      '“If your water sank away, who would bring you flowing water?”: read by the Imams (a.s.) as the Imam hidden from sight - none but Allah brings him back.',

  // Kamal al-Din, Imam al-Baqir to Umm Hani.
  VerseKey(81, 15):
      'The receding stars that hide: Imam al-Baqir (a.s.) read them as the Imam who goes into hiding, then shines out like a blazing star.',
};

/// The note on [verse] if it is one of [quranMahdiVerses], or null.
String? mahdiRelatedNoteFor(VerseKey verse) => quranMahdiVerses[verse];
