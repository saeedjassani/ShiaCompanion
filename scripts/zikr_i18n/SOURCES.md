# Where the zikr translations come from

Every translated line should come from a **published** translation, never a
machine translation. These sources have been used, and these tried and turned
down. Not bundled into the app.

## Urdu

### duas.org decks (2026-10)

duas.org's PowerPoint decks put one Arabic phrase on each slide, with its
English, its Urdu (the Mafatih-style Urdu translation) and its Hindi. Each
zikr below was drafted with `deck_source.py`. Then every segment was checked
by hand against our Arabic, because the decks' Urdu often runs half a line
ahead of or behind its slide. Typos and words the deck left out were
fixed, and Urdu was divided by meaning wherever a deck line covers several
of our segments.

| uid | Zikr | Deck |
| --- | --- | --- |
| E31 | Dua Kumayl | https://www.duas.org/ppt/Dua_al_Kumayl_Eng_Urdu_Hindi.pptx |
| G4 | Ziyarat Ashura | https://www.duas.org/ppt/ziyarat-ashura-and-dua-alqama-eng-urdu.pptx |
| E24 | Dua Tawassul | https://duas.org/ppt/Dua_Tawassul_Eng_Urdu_Hindi.pptx |
| E34 | Dua Nudba | https://www.duas.org/ppt/Dua_al_Nudbah_Eng_Urdu_Hindi.pptx |
| E14 | Hadith al-Kisa | https://www.duas.org/ppt/Hadith_Kisa_Eng_Urdu_Hindi.ppt |
| E28 | Dua Mujeer | https://www.duas.org/ppt/ramppt/Dua_al_Mojeer_Eng_Urdu_Hindi.pptx |
| G2 | Ziyarat Aminullah | https://www.duas.org/ppt/Ziyarat_Aminallah_Eng_Urdu.ppt |
| AA10 | Dua Iftitah | https://www.duas.org/ppt/ramppt/Dua_al_Iftitah_Eng_Urdu_Hindi.pptx |
| E26 | Dua Simat | https://duas.org/ppt/simaat.ppt |

**Our own wording.** Instructions and headings (English-only lines) have no
deck text, so we translated them ourselves. The same goes for the few verses
where a deck has no Urdu, or repeats the next slide's Urdu:

- E31 Dua Kumayl: تَقْطَعُ الرَّجَآءَ, مِنْ سُوْٓءِ فِعْلِىْ وَاِسَآئَتِىْ,
  لِاَلِيْمِ الْعَذَابِ وَشِدَّتِهٖ
- E14 Hadith al-Kisa: the chain of narration from Jabir (the deck has none),
  and فَقَالَ لِاَبِىْ اِنَّ اللهَ قَدْ اَوْحىٰٓ اِلَيْكُمْ
- E34 Dua Nudba: وَلَا يُلْحَقُ فِىْ مَنْقَبَةٍ, فَلْيَنْدُبِ النَّادِبُوْنَ,
  وَالْيَصْرُخِ الصَّارِخُوْنَ, مُؤَلِّفُ شَمْلِ الصَّلَاحِ, and the second half of
  الْمُذَكِّرِ بِكَ وَبِنَبِيِّكَ
- E26 Dua Simat: وَانْتَقِمْ لِیْ مِنْ...

**Where a deck's Urdu was corrected:**
- Dua Mujeer: six names whose deck Urdu does not translate the Arabic (حفی,
  مقدم/مؤخر, ذارئ, مقسط, متعالی).
- Ziyarat Ashura:
  - the deck drops the "not" from وَلَا جَعَلَهُ اللهُ اٰخِرَ الْعَهْدِ;
  - it calls Ubaydullah "son of Ibn Marjana".
- Dua Nudba: eight phrases the deck mistranslates. These include شمل
  (rendered as a garment) and الْمُذَكِّرِ بِكَ.

### Urdu Mafatih al-Jinan (2026-10)

| uid | Zikr | Source |
| --- | --- | --- |
| E18 | Dua Ahad | https://mafatih.duas.co/dua-ehed (cross-checked against https://ur.wikishia.net/view/دعائے_عہد) |
| E1 | Dua Istighatha | https://mafatih.duas.co/istighasa-qayim |
| E4 | Dua Adeela | https://mafatih.duas.co/dua-adeela |
| G3 | Ziyarat Arbaeen | https://mafatih.duas.co/ziarat-arbaeen (verses and merits) |
| G6 | Ziyarat Warith | https://mafatih.duas.co/ziarat-warisa (tabs 1-3); tab 4, al-Abbas, is the short ziyarat inside https://mafatih.duas.co/ziarat-qadr |
| G1 | Ziyarat Aal-e-Yasin | https://mafatih.duas.co/ziarat-aaleyasin |
| Y4 | Munajat Shabaniyah | https://mafatih.duas.co/shaban-munajat |
| E8 | Dua Alqama | https://mafatih.duas.co/dua-alqama |

The Urdu Mafatih al-Jinan of Sheikh Abbas Qummi, translated by Allama Riaz
Husain Najafi, Allama Syed Niaz Husain Naqvi and Maulana Muhammad Ali Fazil
(mafatih.duas.co's about page names them). It was aligned to our segments
through the Arabic; source lines 9, 18, 27, 32, 42, 47 and 56 each span two
of our segments. Corrections: typos (پرودگار, مکروں گانہ, a word broken
across two lines); segment 20, where the source has "دعوت دینے والوں" for
الْمُحَامِيْنَ عَنْهُ, now reads "حمایت کرنے والوں"; and the و the source
dropped in segments 8, 14 and 15. The merits come from the same book's
introduction to the dua.

E1, E4 and G3 were asked for by readers (2026-10); G6 followed. A page's prose holds
the Mafatih's own introduction, which supplied G3's merits. Corrections to
the source:

- **E1 Dua Istighatha:**
  - 2: "بہت زیادہ" for الشامل العام, now "ہمہ گیر اور عام".
  - 8: "نبوت کی نشانی" for سلالة النبوة, now "نسل نبوت".
  - 49: "اس امر" for بأمره, now "اپنے امر".
  - Words the source dropped: القائمة (4), وانت الذي (32) and لي (45).
  - 0, 1, 44 and 54 are our earlier instruction lines.
- **E4 Dua Adeela:**
  - 2-3: قائماً بالقسط is about Allah, not the scholars. 3 uses our Urdu
    Quran's 3:18.
  - 41: "اضداد" for العلل, now "ہر عذر".
  - 48: "نام" for نيله, now "انعام".
  - 60: the source adds "جو میرا وصی ہے" and drops اشار.
  - 67: the source names علی بن الحسین for العابد.
  - 122: "یاد دلا دینا" for فرده, now "لوٹا دینا".
  - 123 (منکر و نکیر) is missing from the source, so it is our own.
  - ur.wikishia has the same اضداد and نام, so those two are in the
    printed translation.
- **G3 Ziyarat Arbaeen:**
  - 14: تَوَازَرَ عَلَيْهِ as "ظلم", now "گٹھ جوڑ".
  - 15: بَاعَ حَظَّهُ as "جانیں", now "حصہ".
  - 20: مُحْتَسِبًا, now "اجر کی امید کے ساتھ".
  - 37: the object of لَمْ تُنَجِّسْكَ, now "آپ کو".
  - 38: المدلهمات, now "تاریک".
  - 44: إيابكم read as "بزرگوں", now "واپسی".
  - Segment 0 is our earlier instruction.
- **G6 Ziyarat Warith** (not requested, but the same source had it):
  - 7: the source's Arabic lacks علی and ولی الله, and its Urdu adds
    "و جانشین". It now follows our Arabic.
  - 12-13: ثار الله / الوتر الموتور, worded as in our G4 Urdu.
  - 27: مدلهمات as "ناپاک", now "تاریک".
  - 28-29: دعائم as "نگہبان", now "ستونوں".
  - 37-38: إيابكم read as "باپ دادا", now "آپ کی واپسی" (as in G3).
  - 59: أوداء, now "دوستو".
  - 66: "تم" made "آپ", as in the rest of the ziyarat.
  - Tab labels 0, 47, 57 and 70 are our earlier ones.
- **All four:** dropped و's were restored, and ؑ/ؐ written (ع)/(ص), and (س) for Lady Fatimah, as
  in the other files.

- **G1 Ziyarat Aal-e-Yasin:**
  - 0: `سَلَامٌ عَلٰى آلِ يٰسٓ` translated directly as "سلام ہو آلِ یٰس (ع) پر" (source used "اولاد پیغمبرؐ").
  - 9-10: Slide 6 spans both segments (`اَلسَّلَامُ عَلَیْكَ یَا تَالِیَ كِتَابِ ﷲِ` / `وَتَرْجُمَانَہٗ`), divided cleanly.
  - 26: source had generic "ذکر الہیٰ کریں", rendered as "لا الہ الا اللہ کہتے ہیں اور تکبیر کہتے ہیں" for تُهَلِّلُ وَتُكَبِّرُ.
  - 85: Instruction heading "زیارت کے بعد پڑھی جانے والی دعا" following Mafatih.
  - 128 (اَللّٰهُمَّ انْصُرْهُ), 142 (وَاخْذُلْ خَاذِلِیْهِ), and 150 (وَّاَظْهِرْ بِهٖ دِیْنَ نَبِیِّكَ): the published source drops these three short phrases; the Urdu is restored against the Arabic (missing from the source, so it is our own).
  - 82-84: realigned to the source — 82 (وَنُصْرَتِىْ مُعَدَّةٌ لَكُمْ) takes the source's own line; an audit found 82-83 each carrying the next segment's translation.
- **Y4 Munajat Shabaniyah:**
  - 16: "عافیت" for لِعَاقِبَتِيْ corrected to "انجام/عاقبت".
  - 23: "رسوا کیا" for خَذَلْتَنِيْ corrected to "بے یار و مددگار چھوڑ دے".
  - 25: "عذاب" for سَخَطِكَ corrected to "ناراضگی".
  - 30: joins slides 24 & 25 (فَقُلْتَ مَا أَنْتَ أَهْلُهُ and وَتَغَمَّدْتَنِي بِعَفْوِكَ).
  - 45: Source dropped اِلٰهِيْ قَدْ اَحْسَنْتَ اِلَيَّ from its Arabic slide 40, restored in Urdu to match our Arabic segment.
  - 114: فَصَعِقَ لِجَلَالِكَ mistranslated as "نعرہ لگایا", now "جلال و ہیبت سے غش کھا گئے".
  - 118: اَسْقَطَتْنِيْ لَدَيْكَ mistranslated as "نظر انداز کر دی گئیں", now "تیری نگاہ میں گرا دیا ہے".
  - 129: وَلَا يَنْقُضُ عَهْدَكَ translated as "نافرمانی نہیں کی", now "عہد کو نہیں توڑتے".
  - 0 (opening instruction) and 139 (closing note) are our earlier instruction lines.
- **E8 Dua Alqama:**
  - Re-aligned group-by-group against the published dataset after an audit found displaced blocks.
  - 0: Standard Bismillah ("بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ.").
  - 163-164: Combined on slide 123 (ٲَسْتَوْدِعُكُمَا ﷲَ، وَلَا جَعَلَہُ ﷲُ اٰخِرَ الْعَھْدِ مِنِّیْ اِلَیْكُمَا), divided at segment break.
- **Across G1, Y4, E8:** dropped و's were restored, and ؑ/ؐ written (ع)/(ص), and (س) for Lady Fatimah.

**E21 Dua Ghariq** isn't in the Mafatih. Its Urdu is from a Hawzah News
article citing Kamal al-Din vol. 2 p. 351
(https://ur.hawzahnews.com/news/410402), divided at our segment breaks;
segment 0 is the Mafatih's Bismillah.

### The Quran translation, reused

- **A4 Ayat al-Kursi** (ur, fa, gu): segments 1-3 are 2:255-257, copied from
  each language's Al-Baqarah (A6 segments 257-259). Its opening narration
  is untranslated.
- **D1 General Taqibaat** (ur): the page has no Arabic, only an English
  introduction. The Quran quotes in it (2:186, 3:191, 27:62) are copied from
  the Urdu Quran; everything else is our own wording.

### Turned down

- **duas.org's Ziyarat Jamia Kabira and Dua Alqama decks**: their Urdu is
  machine-translated from the English. For example, عيبة علمه comes out as
  "اس کے علم کی شرمندگی" and المستغيثين as "مدد کے لئے فون کرنے والوں".
- **duas.pro** (the first batch, never merged): its Persian is a machine
  translation of the English.

## Persian

### Mafatih al-Jinan (Sheikh Abbas Qomi, Hossein Ansarian)

Canonical translations from published editions of *Mafatih al-Jinan* (Sheikh Abbas
Qomi, Hossein Ansarian, Allameh Majlesi) were used to translate the 9 famous duas
and ziyaraat that already had 1-to-1 Urdu segment mappings in `assets/zikr_i18n/ur/`.
Each segment was checked and aligned against the Arabic text and English references
to preserve exact verse correspondence:

| uid | Zikr | Translation Source | Segments |
| --- | --- | --- | --- |
| E24 | Dua Tawassul | Mafatih al-Jinan | 88 + merits |
| G2 | Ziyarat Aminullah | Mafatih al-Jinan | 62 + merits |
| E28 | Dua Mujeer | Mafatih al-Jinan | 96 + merits |
| G4 | Ziyarat Ashura | Mafatih al-Jinan | 128 + merits |
| E14 | Hadith al-Kisa | Mafatih al-Jinan | 132 |
| AA10 | Dua Iftitah | Mafatih al-Jinan | 189 + merits |
| E31 | Dua Kumayl | Mafatih al-Jinan | 271 |
| E26 | Dua Simat | Mafatih al-Jinan | 194 |
| E34 | Dua Nudba | Mafatih al-Jinan | 284 + merits |

Heading and instructional lines (e.g. in Dua Simat and Dua Nudba) were translated
into standard Persian corresponding to the original *Mafatih* directives.

### Ziyarat Jamia Saghira (erfan.ir)

| uid | Zikr | Source |
| --- | --- | --- |
| G12 | Ziyarat Jamia Saghira | https://erfan.ir/mafatih317/ (Hossein Ansarian's Kulliyat Mafatih al-Jinan) |

Ansarian's translation, as published; one long sentence of his is divided
across segments 10-20 by meaning. A4 reuses the Persian Quran (see Urdu).

erfan.ir's per-dua pages (`erfan.ir/mafatih<N>/...`, indexed from
`erfan.ir/farsi/mafatih`) load from a local machine with a browser
User-Agent; cloud sessions could not reach them.

## Gujarati

| uid | Zikr | Deck | Segments |
| --- | --- | --- | --- |
| E31 | Dua Kumayl | https://www.duas.org/ppt/Dua_Kumayl_5languages.pptx | all 271 |
| G13 | Ziyarat Jamia Kabira | https://www.duas.org/ppt/Ziyarat-jamia-kabira-eng-urdu-hindi-guj.pptx | 0-98 of 414 |
| G1 | Ziyarat Aal-e-Yasin | Jafri Library book 6687 (Hadi Library / Haji Naji) | all 159 |

Both decks set their Gujarati in the legacy LMG-Arun font.
`lmg_arun.py rows` decodes it into rows for `deck_source.py align`; the
rest of the workflow is the Urdu one.

The Gujarati was typed by hand, unlike these decks' Urdu, and reads as a
human translation. It is looser and more explanatory than the Urdu.

**Dua Kumayl.** Where a slide's Gujarati ran onto its neighbour's Arabic
(segments 54/55, 60/61 and 73-81), it was moved back. Two mistranslations
were corrected: 167 had "flames" for زَبَانِيَتُهَا, and 172 was
rephrased to match the Arabic.

Some segments are our own Gujarati. Most fill a line the deck skipped or
a split's second half: 61, 74, 79, 80, 87, 88, 106, 107, 133, 148, 149,
166, 167, 169, 170, 172.

**Ziyarat Jamia Kabira.** The deck's Gujarati stops after segment 98, so
the rest of the ziyarat shows in Arabic alone. Segments 29/30 had each
half on the other's slide, and are our own. In 73, the deck's "વિદ્વાન"
(learned) for الرَّاشِدُوْنَ is corrected.

Not to use: the Haji Naji Trust's "Mukhtasar Mafatih al-Jinan" PDF
(Tohafa-e-Saiyada). Its translations are Urdu written in Gujarati script,
not Gujarati.

### Jafri Library (jafrilibrary.com)

Jafri Library is the designated Gujarati source. Its catalog was searched for G1, Y4, and E8:
- **G1 Ziyarat Aal-e-Yasin:** completed all 159 segments (0-158) from Book 6687 (*Ziarat E Ale Yasin #*, published by Hadi Library / Haji Naji, 36 pages). The PDF was obtained without CAPTCHA and has a full text layer set in the legacy LMG-Arun font, decoded with `lmg_arun.py`. Aligned via the booklet's Gujarati transliteration blocks (each serving as an exact phonetic anchor for its Arabic segment) and cross-checked against the Arabic and the PR 338 Urdu. Segment 85 ("ઝિયારત પછી પઢવાની દુઆ") is preserved from the existing heading. Multi-segment sentences are partitioned cleanly across segment boundaries (1/2, 3/4, 5/6, 7/8, 9/10, 11/12, 18/19, 29/30, 34/35, 38/39, 40/41, 42/43, 44/45, 46/47, 48/49, 50/51, 52/53, 54-56, 59/60, 66/67, 69/70, 72/73, 74/75, 78/79, 86/87, 97/98, 99/100, 121/122, 128/129, 130/131, 135/136, 145/146, 147/148, 150/151, 152/153). Two split second halves are restored in our own Gujarati to complete the Arabic: 98 ("હઝરત મોહમ્મદ(સ.) અને તેમની આલ (અ.સ.) માટે") and 151 ("સલ્લલ્લાહો અલય્હે વ આલેહ"). Hand-corrected legacy-decode artifacts:
  - `Ò` (dropped by `lmg_arun.py`'s `DROP` set): represented `જી` in the font, hand-restored in `રાજી` (74), `ફરજિયાત` (125), and `વાજિબ` (126);
  - `Ô` (Latin character representing `જા` / `જો` glyph in the font): hand-corrected in `દરવાજા` (3), `છવાઇ જાય છે` (29), `પ્રકાશિત થઇ જાય છે.` (30), `સજા` (68), `રહેજો` (71), `માનવજાતની` (118), `ઈજાથી` (134), `વંશજોનું` (138), `જાહેર` (139), and `કમજોર` (143);
  - Vocalic r / ru-matra (decoded as apostrophe `'`): corrected in `મૃત્યુ` (57);
  - Ligature `Þ` (glyph for `ક્ક` conjunct): corrected in `'મક્કમ'` (90, 91);
  - Ligature `w` (glyph for half-dha): corrected in `ધ્વજ` (16);
  - Conjunct `ચ્ચ` (typed as `rR`, decoded with `ઇ` for `r`): corrected in `સચ્ચાઇના` (93) and `સચ્ચાઇની` (112);
  - Opening/closing quotation marks (decoded as `—` and dropped `˜`): restored in `'મુન્કર'` (77) and `'મક્કમ ઇરાદા'` (90);
  - Original book typo: duplicated `અને અને` corrected to single `અને` (137).
- **Y4 Munajat Shabaniyah:** Book 84725 (*Munajaat E Shabania #*, Hadi Library / Haji Naji) PDF was likewise obtained and has a text layer in a different legacy font ("Gujrati"), decode pending — Y4 Gujarati itself stays deferred.
- **E8 Dua Alqama:** has 0 records in the Jafri Library catalog (unchanged, deferred).
