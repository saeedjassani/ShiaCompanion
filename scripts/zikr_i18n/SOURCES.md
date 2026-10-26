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
| E6 | Dua al-Mahdi (a.t.f.s.) | https://mafatih.duas.co/dua-faraj-hujjat2 |
| E4 | Dua Adeela | https://mafatih.duas.co/dua-adeela |
| G3 | Ziyarat Arbaeen | https://mafatih.duas.co/ziarat-arbaeen (verses and merits) |
| G6 | Ziyarat Warith | https://mafatih.duas.co/ziarat-warisa (tabs 1-3); tab 4, al-Abbas, is the short ziyarat inside https://mafatih.duas.co/ziarat-qadr |
| G1 | Ziyarat Aal-e-Yasin | https://mafatih.duas.co/ziarat-aaleyasin |
| Y4 | Munajat Shabaniyah | https://mafatih.duas.co/shaban-munajat |
| E8 | Dua Alqama | https://mafatih.duas.co/dua-alqama |
| E10 | Dua Asharat | https://mafatih.duas.co/dua-asharat |
| H17 | Munajat Amir al-Mu'minin (Masjid Kufa) | https://mafatih.duas.co/munajat-kufa |

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

- **H17 Munajat Amir al-Mu'minin (Masjid Kufa):**
  - Aligned to our segments through the Arabic; 69/69 segments.
  - The book prints the verses of Surah Abasa (80:34-37) and Surah
    Ma'arij (70:11-13) in six short lines where our text has four
    segments, so its lines 15 and 18 are each split across two of our
    segments (13/14 and 15/16) at the Arabic clause boundary; every word
    is the book's own.
  - Our Arabic spells اَسْئَلُكَ with ئ where the book prints اَسْاَلُكَ
    with أ — the same text, a hamza seat only.
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

- **E10 Dua Asharat:** the mafatih.duas.co page prints 151 numbered
  Arabic/Urdu line pairs — the dua's repeated phrase-blocks are written
  out in full at every repetition — aligned to our 61 verse segments.
  Segments 0, 52, 59, 60 and 63 are our earlier instruction lines. Its
  Persian is Ansarian's, from erfan.ir/mafatih42 (see Persian below).

**E21 Dua Ghariq** isn't in the Mafatih. Its Urdu is from a Hawzah News
article citing Kamal al-Din vol. 2 p. 351
(https://ur.hawzahnews.com/news/410402), divided at our segment breaks;
segment 0 is the Mafatih's Bismillah.

### Seasonal small gaps — W1, W3 (2026-10-25)

| uid | Zikr | Source | Segments |
| --- | --- | --- | --- |
| W1 | 3rd Jumada II aamal | *Mafatih al-Jinan wa Baqiyat al-Salihat* (Urdu), alhassanain.org book 193, p. 42 (chapter 10: aamal of Rabi II, Jumada I and Jumada II); mirrored at sayyid-shouhadaa-center.com | segment 3 (4 of 4) |
| W3 | Aamal in Jumada al-Akhirah | same, p. 42 | segments 6, 8, 10, 12 (14 of 14) |

The printed Urdu Mafatih interleaves the Arabic and the Urdu mid-sentence,
so each segment is assembled from the book's Urdu pieces in order (a
documented join; punctuation normalised). The book prints its honorifics
as ligature glyphs; they are written (ص)/(ع) here, as elsewhere in this
file. W1 segment 3's Arabic spans the ziyarat of Lady Fatimah (sa) and the
closing salawat; the book's Urdu for both parts is joined in order. W3
segment 12's Urdu is split by the Arabic line break in the book and is
joined in order.

- **G64 Ziyarat of Imam Zayn al-Abidin (as):** this salam set is not
  printed in the Urdu Mafatih — its Jumada I chapter (book 193, p. 39)
  only directs the reader to recite the Imams' ziyarat at Baqi, and the
  Baqi ziyarat the Mafatih prints is the joint ziyarat of the four Imams,
  a different text. The set is published in Arabic and English only
  (duas.org, *Sha'ban Amaal* booklet). No published Urdu translation
  found; all 11 segments left blank.
- **G81 Ziyarat of Lady Umm al-Baneen (sa):** this short ziyarat (source:
  ziaraat.org; duas.org "First Ziyarat") is not in *Mafatih al-Jinan*.
  Urdu publications quote its Arabic without a translation, and the
  widely translated ziyaratnameh (beginning أَشهَدُ أَن لا إلهَ إلا الله)
  is a different, longer text. No published Urdu translation of this text
  found; all 8 segments left blank and no file created.
### Urdu Mafatih al-Jinan — Firebase Batch (2026-10-26)

Published Urdu *Mafatih al-Jinan* (Sheikh Abbas Qummi, translated by Allama Riaz Husain Najafi / Allama Syed Zeeshan Haider Jawadi) on mafatih.duas.co was used to fill user-requested Urdu translations:

| uid | Zikr | Source | Segments |
| --- | --- | --- | --- |
| G56 | Ziyarat of the Martyrs of Karbala | https://mafatih.duas.co/ziarat-warisa | 12 of 12 (4 filled + 8 existing) |
| D2 | Dua after Namaz-e-Fajr | https://mafatih.duas.co/dua-imam-reza-fajr | 21 of 21 (20 filled + 1 existing) |
| F5 | Namaz-e-Ghufaila | https://mafatih.duas.co/namaz-ghufaila | 8 of 8 (4 filled + 4 existing) |
| I74 | Hirz of Lady Fatimah (sa) | https://mafatih.duas.co/hirz-bibi-fatima | 3 of 5 (2 filled + 1 existing; 2 left blank) |
| G5 | Ziyarat al-Haqq al-Jadid | https://mafatih.duas.co/ziarat-hujjat-3 | 32 of 32 (32 filled) |
| A3 | Dua Khatm al-Quran | Not in Mafatih al-Jinan; no published Urdu translation found | 0 filled — no file shipped (5 missing left blank) |
| D12 | Dua after Namaz for Seeking Sustenance | al-Kaf'ami al-Balad al-Amin / Ibn al-Sa'i (not in Mafatih al-Jinan); no published Urdu translation found | 0 filled — no file shipped (7 missing left blank) |

- **G56 (Ziyarat of the Martyrs of Karbala):** Sourced from the Ziyarat of the Martyrs section in `https://mafatih.duas.co/ziarat-warisa`. Segments 0 (`اے! اولیا اللہ آپ پر سلام ہو اور اے اللہ کے پیارو`), 1 (`آپ پر سلام ہو اے خدا کے برگزیدہ اور منتخب لوگو`), 5 (`آپ پر سلام ہو اے فاطمہ(س) کی حمایت کرنے والو جو تمام عورتوں کی سردار ہیں`), and 6 (`آپ پر سلام ہو اے ابو محمد حسن(ع) بن علی کے مددگارو کہ جو خدا کے ولی اور نصیحت کرنے والے ہیں`) were filled verbatim from the published text (with ؑ/ؐ standardized to (ع)/(ص) and (س) for Lady Fatimah). Existing segments 2–4 and 7–11 are preserved verbatim. 12/12 segments filled.
- **D2 (Dua after Namaz-e-Fajr):** Sourced from `https://mafatih.duas.co/dua-imam-reza-fajr` (Dua of Imam al-Rida (a.s.) narrated in *Uddat al-Da'i*). Segments 2–5 and 7–20 are verbatim from the published numbered items 1–4 and 6–20 (segment 6 = items 5+6 verbatim, including the source's `﴿خدا﴾` insertion; an earlier draft carried the E28 deck's wording for this Quran verse and was replaced with this page's own wording at audit). Source item 8 spans segment 8 (`پس ﴿مجاہد﴾ خدا کے فضل وکرم سے اس طرح آئے`) and the opening clause of segment 9 (`کہ انہیں تکلیف نہ پہنچی تھی`), divided cleanly at the Arabic phrase boundary and joined with item 9 (`جو اللہ چاہے وہ ہو گا، نہیں کوئی طاقت وقوت مگر وہ جو اللہ سے ملتی ہے`). Segment 1 (standalone basmala) keeps the corpus-standard published Urdu basmala (`عظیم اور دائمی رحمتوں والے خدا کے نام سے`, as in the A-series files) — this page merges the basmala into item 1 (= our segment 2) under a different rendering; same documented convention as E27's Persian basmala. Segment 0 is pre-existing. 21/21 segments filled.
- **F5 (Namaz-e-Ghufaila):** Sourced from `https://mafatih.duas.co/namaz-ghufaila`. Segment 2 (Surah al-Anbiya 21:87-88) takes published items 1–5; segment 4 (Surah al-An'am 6:59) takes items 6–10; segment 6 (first qunoot) takes items 11–14, with two digitization typos in the published page corrected as proven corrections against the Arabic (item 13's trailing `فرما ا` → `فرما`; item 14's `ور` → `اور`); segment 7 (second qunoot) takes items 15–18. ؐ/ؑ standardized to (ص)/(ع) in segments 6–7. Existing instruction segments 0, 1, 3, 5 are preserved verbatim. 8/8 segments filled.
- **I74 (Hirz of Lady Fatimah (sa)):** Sourced from `https://mafatih.duas.co/hirz-bibi-fatima`. Segment 2 takes the verbatim published prefix of item 2 (`اے زندہ اے پائندہ تیری رحمت کے ذریعے فریاد کر رہا ہوں`). Segment 1 (standalone basmala) keeps the corpus-standard published Urdu basmala (see D2 note above) — this page's item 1 prints a different rendering (`خدا کے نام سے جو بڑا رحم والا مہربان ہے`). Segments 3 and 4 are left blank: in the published Urdu, the adverbial clause `طَرْفَةَ عَیْنٍ أَبَدًا` ("پلک جھپکنے کے لئے بھی کبھی") is embedded in the middle of item 3 (`اور مجھے پلک جھپکنے کے لئے بھی کبھی میرے نفس کے حوالے نہ کرنا`), while the template splits `فَاَغِثْنِىْ وَلَا تَكِلْنِىْ اِلٰى نَفْسِىْ` (seg 3) and `طَرْفَةَ عَيْنٍ اَبَدًا وَاَصْلِحْ لِىْ شَاْنِىْ كُلَّهٗ.` (seg 4), preventing ordered contiguous verbatim partitioning without swapping phrases. Segment 0 is pre-existing. 3/5 segments translated (2 left blank: 3, 4).
- **G5 (Ziyarat al-Haqq al-Jadid):** Sourced from `https://mafatih.duas.co/ziarat-hujjat-3` (Third Ziyarat of Imam al-Mahdi (a.s.) in the Sardaab of Samarra). All 32 segments (0–31) mapped directly to source items 1–33. Multi-item and multi-segment blocks were partitioned cleanly at Arabic phrase boundaries: segments 0 (items 1 & 2), 8 (items 10 & 11), 13 & 14 (partitioning items 16 & 17), 20 & 21 (items 23 & 24), 23, 24 & 25 (items 26 & 27), segments 28 & 29 partition items 30–31 (segment 29 = item 30's tail + item 31 verbatim), and segment 30 takes item 32. Segment 16 drops the source item 19's bracketed editorial insertion `[سلام ہو اس پر جو]` (the Arabic has no salutation there). Honorifics normalized to (ع). 32/32 segments filled.
- **A3 (Dua Khatm al-Quran):** Not part of Sheikh Abbas Qummi's *Mafatih al-Jinan*. No published Urdu translation found in mafatih.duas.co or backstops (duas.org, ur.wikishia.net). The composite supplication lines do not match isolated Quran verses from our Urdu Quran translation. All 5 missing segments (1–5) are left blank per binding instructions; no A3 file is shipped in this batch (segment 0 remains served via its existing alias file). 1/6 segments translated (5 left blank: 1–5).
- **D12 (Dua after Namaz for Seeking Sustenance):** Supplication from al-Kaf'ami's *al-Balad al-Amin* / Ibn al-Sa'i. Not part of *Mafatih al-Jinan*, and no published Urdu translation exists on mafatih.duas.co or backstops. All 7 missing segments (1–3, 5–8) are left blank per binding instructions; no D12 file is shipped in this batch (segments 0, 4, 9 remain served via their existing alias file). 3/10 segments translated (7 left blank: 1–3, 5–8).

### The Quran translation, reused

- **A4 Ayat al-Kursi** (ur, fa, gu): segments 1-3 are 2:255-257, copied from
  each language's Al-Baqarah (A6 segments 257-259). Its opening narration
  is untranslated.
- **D1 General Taqibaat** (ur): the page has no Arabic, only an English
  introduction. The Quran quotes in it (2:186, 3:191, 27:62) are copied from
  the Urdu Quran; everything else is our own wording.

### mafatih.net Urdu Mafatih — G52 (2026-10-25)

| uid | Zikr | Source | Segments |
| --- | --- | --- | --- |
| G52 | Ziyarat of Lady Fatimah al-Zahra (sa) | https://mafatih.net/?p=2985 (Urdu *Mafatih al-Jinan*) | all 64 (61 filled + existing 0, 12, 63) |

- **G52:** Published on mafatih.net under زیارتِ حضرت فاطمہ زہراءؑ (Urdu Mafatih
  al-Jinan). The 25 published translation blocks were partitioned into
  consecutive verbatim slices across the 61 Arabic segments; every slice is an
  exact substring of its block and the slices jointly reproduce each block
  word-for-word (100% per-anchor audit: anchors verified in order against each
  block's Arabic; monotonic, no drift). Two published word-order interleaves
  are documented rather than silently reordered: in block 5–8 the Urdu renders
  the salawat (segment 7's Arabic) at the end of the sentence, so the
  consecutive partition places the wasi clause slice on 7 and the salawat slice
  on 8; blocks 19–21 and 22–24 are single-phrase renderings split mid-phrase
  (20/21, 23/24). Segment 56's Arabic (مُتَبَرِّئٌ) is spelled by mafatih.net
  with U+06CC ی where the app anchor normalizes the hamza letter away.
  Existing segments 0, 12, 63 and the merits text are preserved as-is.

### duas.org / ur.wikishia.net Urdu — G11 (2026-10-26)

| uid | Zikr | Source | Segments |
| --- | --- | --- | --- |
| G11 | Ziyarat Nahiya (Ziyarat al-Nahiya al-Muqaddasa) | https://www.duas.org/ppt/Ziyarat-Nahiya_Ara_Eng_Urdu_Transliteration.pptx (cross-checked against https://ur.wikishia.net/view/زیارت_ناحیہ_مقدسہ) | 380/493 (362 filled + 18 preserved) |

- **G11:** Ziyarat al-Nahiya al-Muqaddasa (the ziyarat of Imam Husayn (as)
  attributed to Imam al-Mahdi (atfs)). The primary source `mafatih.duas.co`
  lacks Ziyarat Nahiya (verified across its 697-page sitemap and search index;
  Sheikh Abbas Qummi's standard *Mafatih al-Jinan* does not contain this
  ziyarat). The text was sourced from the published bilingual/trilingual Urdu
  presentation on `duas.org` (`Ziyarat-Nahiya_Ara_Eng_Urdu_Transliteration.pptx`,
  211 slides covering segments 1 to 368) and cross-checked against the published
  Urdu text on `ur.wikishia.net/view/زیارت_ناحیہ_مقدسہ`.
  - **Segments 1–368 (Ziyarat proper):** All 368 segments were filled verbatim
    from the 211 published deck slides. Multi-anchor slides were partitioned
    into contiguous verbatim substrings matching each anchor boundary;
    concatenating the split slices reproduces the published Urdu slide verbatim
    (modulo whitespace).
  - **Preserved anchors (18 segments):** Preserved byte-for-byte from existing
    master/template translations:
    - Opening heading: 0 ("زیارت")
    - Text anchors: 269 ("تو رحمت فرما محمد (ص) و آلِ محمد (ص) پر"), 270 ("مجھے ان کے گروہ میں محشور فرما"), 289 ("ہم چاہتے ہیں کہ رحمت فرما محمد (ص) و آلِ محمد (ص) پر"), 295 ("اور میرے لئے آئندہ نسلوں میں سچی زبان اور ذکر خیر قرار دے"), 302 ("اپنی رحمت سے اے سب سے زیادہ رحم کرنے والے۔"), 368 ("اپنی رحمت سے اے سب سے زیادہ رحم کرنے والے۔")
    - Post-ziyarat ritual headings and instructions: 369 ("نماز زیارت اور دعائے قنوت"), 370, 487, 489, 490, 492
    - Post-ziyarat prayer anchors: 388, 425, 426, 432, 481
  - **Segments 207/208 (auditor correction, 2026-10-26):** slide 126 of the
    deck prints its two Urdu phrases in the opposite order to its Arabic
    (swords phrase first, horses phrase second). The two segments were
    assigned by meaning so each matches its own Arabic anchor; each is a
    verbatim substring of that slide's published Urdu.
  - **Unfilled segments (113 segments):** Segments 371–387, 389–424, 427–431,
    433–480, 482–486, 488, 491 (all within the post-ziyarat two-rak'ah prayer
    and Qunoot supplication) were left blank (`""`) per prompt guidelines
    because no published Urdu translation exists in *Mafatih al-Jinan*,
    `mafatih.duas.co`, `duas.org`, or `ur.wikishia.net`. No machine translation
    or original composition was used.

### Turned down

- **duas.org's Ziyarat Jamia Kabira and Dua Alqama decks**: their Urdu is
  machine-translated from the English. For example, عيبة علمه comes out as
  "اس کے علم کی شرمندگی" and المستغيثين as "مدد کے لئے فون کرنے والوں".
- **duas.pro** (the first batch, never merged): its Persian is a machine
  translation of the English.

## Persian

### erfan.ir — AH2, AL5 (2026-10-25)

Ostad Hossein Ansarian's published *Mafatih al-Jinan* translation on erfan.ir
(cross-checked against valasr.app) was used to fill Persian translations for these two
Kazimayn and Samarra ziyaraat. Per-anchor audit 2026-10-25: every filled segment is a
verbatim substring of the erfan.ir published Persian block containing that segment's
Arabic anchor (AH2 190/190, AL5 149/149; block order monotonic within each tab). Where published blocks spanned adjacent template segments,
they were divided cleanly by meaning at the Arabic phrase boundaries into verbatim
substrings without altering or composing any words.

| uid | Zikr | Source | Segments |
| --- | --- | --- | --- |
| AH2 | Ziyarat of Imam Musa al-Kazim (a.s.) — Kazimayn | https://erfan.ir/mafatih282 (cross-checked at https://valasr.app/library/mafatih/زیارت-مخصوص-امام-موسی-کاظمع) | 195 of 201 |
| AL5 | Ziyarat of Imam Ali al-Naqi al-Hadi (a.s.) — Samarra | https://erfan.ir/mafatih303 and https://erfan.ir/mafatih674 (cross-checked at https://valasr.app/library/mafatih/زیارت-مخصوص-امام-هادی and https://valasr.app/library/mafatih/صلوات-بر-علی-بن-محمدعلیهالسلام) | 157 of 158 |

- **AH2 (Ziyarat of Imam Musa al-Kazim):** 190 verse segments (95 segments each across
  Tab 1 and Tab 2) were filled from Ostad Hossein Ansarian's published Mafatih al-Jinan
  translation on erfan.ir (`mafatih282`). Segments 0, 1, 100, 101, and 200
  (headings and instruction lines) were preserved verbatim from the shipped file.
  Tab 2 (segments 101–200) contains the exact same Arabic verses as Tab 1 (segments 0–100),
  so segments 102–199 match segments 2–99 verbatim.
  Segments left blank:
  - Segments 21–22 and 121–122 (`اَلسَّلاَمُ عَلَيْكَ يَا مَوْلاَيَ مُوسَىٰ بْنَ جَعْفَرٍ` /
    `وَرَحْمَةُ ٱللَّهِ وَبَرَكَاتُهُ`) are left blank: in Ansarian's published Persian
    the salutation and benediction are merged and inverted
    («سلام و رحمت و برکات خدا بر تو ای مولای من موسی بن جعفر»), with the benediction preceding
    the vocative name, preventing contiguous ordered partitioning without reordering or
    swapping phrases.
  - Segments 99 and 199 (`وَرَحْمَةُ ٱللَّهِ وَبَرَكَاتُهُ`) are left blank: in published
    Ansarian combines the terminal benediction into the opening salutation
    («پس درود و رحمت و برکات خدا بر تو و پدران و اجداد و فرزندان و شیعیان و دوستدارانت باد.»),
    leaving four Arabic segments with only three published Persian clauses and no distinct
    clause of its own for segment 99/199.
  - Recension-variant alignment: segment 87 restores the published Ansarian reading «گواهی می‌دهم...»
    as printed on erfan.ir (the valasr.app digitization drops the initial letter «گ»).
  - 195/201 segments translated (6 segments left blank: 21, 22, 99, 121, 122, 199).
- **AL5 (Ziyarat of Imam Ali al-Naqi al-Hadi):** 149 verse segments were filled from
  published Mafatih al-Jinan on erfan.ir: segments 4–136 from `mafatih303`, and
  segments 138–157 from `mafatih674`. Segments 0, 1, 2, 3, 20, 22, 90,
  and 137 (tab labels, headings, and instruction lines) were preserved verbatim from the
  shipped file.
  Segments left blank:
  - Segment 21 (`اَللّٰهُ اكْبَرُ`) is left blank: in the published source,
    the Takbir recitation is embedded within untranslated instructional prose
    («...و صد مرتبه «اللّٰهُ أَکْبَرُ» بگو و بخوان:») without a dedicated Persian translation.
  - Multi-segment published blocks were divided cleanly at anchor boundaries into contiguous
    ordered substrings.
  - 157/158 segments translated (1 segment left blank: 21).


### Mafatih al-Jinan (Sheikh Abbas Qomi, Hossein Ansarian)

Canonical translations from published editions of *Mafatih al-Jinan* (Sheikh Abbas
Qomi, Hossein Ansarian, Allameh Majlesi) were used to translate the 9 famous duas
and ziyaraat that already had 1-to-1 Urdu segment mappings in `assets/zikr_i18n/ur/`.
Each segment was checked and aligned against the Arabic text and English references
to preserve exact verse correspondence:

| uid | Zikr | Translation Source | Segments |
| --- | --- | --- | --- |
| E24 | Dua Tawassul | Mafatih al-Jinan | 88 + merits |
| E10 | Dua Asharat | Mafatih al-Jinan (erfan.ir/mafatih42) | 66 |
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

### valasr.app — Persian Mafatih (2026-10)

valasr.app's Mafatih library pairs each Arabic passage with exactly one Persian
line of the published *Mafatih al-Jinan* translation — the same Ansarian text as
hawzah.net's serialized Mafatih (collection 79461). Where one published line
covers two of our segments it was divided by meaning at the Arabic phrase
boundary.

| uid | Zikr | Source | Segments |
| --- | --- | --- | --- |
| G1 | Ziyarat Aal-e-Yasin | https://valasr.app/library/mafatih/زیارت-ال-یاسینیس-امام-زمان | 159 |
| Y4 | Munajat Shabaniyah | hawzah.net Mafatih (collection 79461, item 11183) | 140 |
| E8 | Dua Alqama | valasr.app/library/mafatih (دعای علقمه); cross-checked at https://hawzah.net/fa/pray/View/79461/7195/دعاى_علقمه_بعد_از_نماز_زیارت_عاشوراء | 185 of 186 |
| E27 | Dua Mashlool | https://valasr.app/library/mafatih/دعای-مشلول; cross-checked at https://erfan.ir/mafatih44/دعای-مشلول-کلیات-مفاتیح-الجنان-با-ترجمه-استاد-حسین-انصاریان | 257 + merits |

- **E27:** valasr.app's published Persian pairs with Arabic blocks (85 blocks for 257 segments); clauses were mapped verbatim to segments 0–256 at the Arabic phrase boundaries. Published Persian merits text from block 0 of valasr.app (cross-checked with erfan.ir) was populated into `merits`. Per-anchor audit corrections and documented exceptions: segments 4, 28, 96, 115, 119, 120, 135, 199 and 220 take the exact wording of their own valasr block (an earlier draft carried cross-zikr template wording for the same Arabic phrases); segments 102–103 are a documented verbatim split of the single published phrase «ای برآورنده خواسته‌ها و نیازها،» (valasr block 30; identical merged phrasing in erfan.ir and hawzah.net 79461/6420) at the الطلبات/الحاجات anchor boundary; segment 94's Arabic (يَا ذَا الْعِزَّةِ وَالسُّلْطَانِ) is absent from valasr's Arabic blocks but its Persian «ای دارای توانمندی و سلطنت،» is verbatim in the erfan.ir/hawzah.net rendering of the same published translation; segments 1 and 3 (standalone basmala) keep the corpus-standard published basmala «به نام خداوند بخشنده بخشایشگر» — valasr merges the basmala into block 1 under a different rendering; segment 255 keeps «ستایش» where the valasr/hawzah digitization prints the non-word «ستایس» — the segment is byte-identical to E28's already-shipped closing segment for this same Arabic line, and the same published translation prints «ستایش ویژه» for this phrase elsewhere in Mafatih (cf. E31/G4 in this repo).
- **G1:** valasr's page repeats one salutation in its Persian (the
  «سلام بر تو وقتی که می‌خوانی و بیان می‌کنی» line appears again at the head of
  the نماز/قنوت passage); we follow the Arabic — segment 24 carries only the
  نماز/قنوت line. valasr prints no separate Persian for segment 151
  (صَلَّى اللّٰهُ عَلَيْهِ وَآلِهِ) and its Arabic omits the
  وَاجْعَلْنِي اللّٰهُمَّ مِنْ أَنْصَارِهِ passage; segments 151–153 follow the
  same published translation as printed in other editions of this dua.
- **E8:** segment 87 (وَمُغِيثٌ لَامُغِيثَ سِوَاكَ) is left untranslated: the
  published Persian gives the کافی/مفرّج/مغیث/جار sequence three clauses for
  its four Arabic phrases, with no clause of its own for مغیث. Left blank
  rather than composed.

### Ziyarat Jamia Saghira (erfan.ir)

| uid | Zikr | Source |
| --- | --- | --- |
| G12 | Ziyarat Jamia Saghira | https://erfan.ir/mafatih317/ (Hossein Ansarian's Kulliyat Mafatih al-Jinan) |

Ansarian's translation, as published; one long sentence of his is divided
across segments 10-20 by meaning. A4 reuses the Persian Quran (see Urdu).

erfan.ir's per-dua pages (`erfan.ir/mafatih<N>/...`, indexed from
`erfan.ir/farsi/mafatih`) load from a local machine with a browser
User-Agent; cloud sessions could not reach them.

### Ziyarat Jamia Kabira (valasr.app)

| uid | Zikr | Source |
| --- | --- | --- |
| G13 | Ziyarat Jamia Kabira | https://valasr.app/library/mafatih/زیارت-جامعه-کبیره (published Persian Mafatih al-Jinan translation) |

The published page pairs each Arabic passage with exactly one Persian line,
matching the app's segments; 414 segments.

### valasr.app — E144, G6, E18 (2026-10)

Ostad Hossein Ansarian's published *Mafatih al-Jinan* translation on valasr.app
was used to fill Persian translations for these three zikrs. Where published
sentences spanned adjacent template segments, they were divided cleanly by meaning
at the Arabic phrase boundaries without altering or composing any words.

| uid | Zikr | Source | Segments |
| --- | --- | --- | --- |
| E144 | Salawat of Abul Hasan al-Zarrab al-Isfahani | https://valasr.app/library/mafatih/صلوات-ابوالحسن-ضراب-اصفهانی | 168 of 170 + merits |
| G6 | Ziyarat Warith | https://valasr.app/library/mafatih/زیارت-هفتم-زیارت-وارث (tabs 1-3); tab 4 (Hazrat Abbas) from https://valasr.app/library/mafatih/زیارت-امام-حسینع-در-شبهای-قدر | 80 of 80 |
| E18 | Dua Ahad | https://valasr.app/library/mafatih/دعای-عهد | 38 of 42 + merits |

- **E144 (Salawat Abul Hasan al-Zarrab al-Isfahani):** 166 verse segments
  were filled from Ostad Hossein Ansarian's published Mafatih translation on valasr.app.
  Segments 0 and 169 (introductory and concluding instructions) were preserved verbatim
  from the shipped file. The published introductory narration provided the full merits
  text. Segments 122 (`وَبَلِّغْهُ اَفْضَلَ مَا اَمَّلَهٗ`) and 166 (`وَبَلِّغْهُمْ اَقْصٰى آمَالِهِمْ`)
  are left blank (deleted): in Ansarian's Persian, the adverbial/prepositional complements
  (`در دنیا و آخرت` in 123; `دینی و دنیوی و آخرتی‌شان` in 167) precede the governing verb
  (`برسان`), preventing contiguous, ordered partitioning without dropping or reordering words.
  Segments 132–133 (`وَلَا بَاطِلَ عِنْدَهٗ` / `وَلَا بِدْعَةَ لَدَيْهِ`) partition the published
  line `و باطل و بدعتی همراه آن نماند` into contiguous slices `و باطل` and `و بدعتی همراه آن نماند`.
  Recension-variant mappings: seg 14 (`وَاَفْلِحْ حُجَّتَهٗ` maps to published line with `وَأَفْلِجْ`);
  seg 16 (`وَاَضِءْ نُوْرَهٗ` maps to published line with `وَأَضِئْ`). Segment 96 follows the
  published line ending at `پیوسته` (omitting composed `و خوشایند`); seg 158 uses verbatim published
  `و دستاویز` (omitting composed `محکم`); seg 161 uses verbatim start `و بر ولیت`; seg 168 uses
  verbatim published `زیرا تو بر هر کاری توانایی.`. 168/170 segments translated (2 blank segments).
- **G6 (Ziyarat Warith):** 76 verse segments were filled from published Mafatih al-Jinan
  on valasr.app. Tabs 1–3 (Imام Husain, Ali Akbar, Shuhada) are from the Ziyarat Warith
  chapter; tab 4 (Hazrat Abbas) is the short ziyarat from the Qadr nights chapter (matching
  the same structure used in Urdu G6). Tab labels 0, 47, 57, and 70 were preserved verbatim
  from the shipped file. G6 has no merits note in the English source, so merits remains absent.
  Recension-variant mappings and verbatim alignment:
  - Tab 1: Seg 7 (`اَلسَّلَامُ عَلَيْكَ يَا وَارِثَ عَلِىٍّ اَمِيْرِ الْمُؤْمِنِيْنَ وَلِىِّ اللهِ`)
    maps to published line `سلام بر تو ای وارث امیرمؤمنان ولی خدا،` (published Arabic recension
    reads `السَّلامُ عَلَيْكَ يَا وارِثَ أَمِيرِ الْمُؤْمِنِينَ عَلَيْهِ السَّلاٰمُ`). Segments 7-8
    and 9-10 cleanly partition blocks 31 and 32 into verbatim contiguous slices. Seg 11 takes the
    verbatim first slice of block 33. Segments 14-15 map to block 34 (`الصَّلوٰةَ` vs `الصَّلاةَ`),
    partitioned cleanly.
  - Segments 33-34 use verbatim published `ریشه تقوا و نشانه‌های هدایت` and `و دستاویز محکم و حجّت بر اهل دنیا هستند،`
    (restoring published `ریشه` and `دستاویز`). Segments 35-36 partition block 42 into `و گواه می‌گیرم خدا و فرشتگان`
    and `و پیامبران و رسولانش را`. Segments 38-40 take verbatim published slices `و بر یقین به بازگشت شمایم،`,
    `براساس قوانین دینم`, and `و پایان‌های عملم`. Seg 41 takes verbatim `و دلم تسلیم دل شما`.
    Segments 43-44 take `درود خدا بر شما و بر ارواح` and `و اجساد و پیکرهایتان`. Segments 45-46 take
    `و بر حاضر و غایب` and `و آشکار و باطنتان.`.
  - Tab 2 (Ali Akbar): Segments 48-49 and 50-51 partition blocks 62 and 63. Seg 52 takes verbatim
    published `سلام بر تو ای شهید،` (omitting composed `و فرزند شهید`).
  - Tab 3 (Shuhada): Segments 58-59 and 63-64 follow verbatim published lines (mapping slight
    orthographic differences in `أَوِدَّاءَهُ` and `نِساءِ`).
  - Tab 4 (Abbas): Seg 71 takes verbatim opening `سلام بر تو ای فرزند امیرمؤمنان،`; Seg 76 takes
    verbatim remainder `تا آن‌که مرگ به سویت آمد`; Seg 79 takes verbatim published `و به هلاکت‌گاه دوزخ واردتان کند.`
    (matching published `واردتان` character-for-character). 80/80 segments translated (0 blank segments).
- **E18 (Dua Ahad):** 37 verse segments were filled from the published Mafatih al-Jinan on valasr.app.
  Segment 40 (instruction to strike thigh 3 times) was preserved verbatim from the shipped file.
  The published introductory narration provided the merits text.
  - Seg 0 (Bismillah): The valasr Dua Ahad page has no basmala block; uses the exact published Ansarian
    basmala line from valasr (cf. E144 seg 1): «به نام خدا که رحمتش بسیار و مهربانی‌اش همیشگی است».
  - Seg 4: takes verbatim published slice `و پروردگار فرشتگان مقرّب و پیامبران و رسولان.` from block 2
    (mapping recension-variant space in `وَ الْمُرْسَلِينَ`).
  - Segments 5-6 and 7-8 cleanly partition blocks 3 and 4: seg 6 takes the remainder of block 3
    (`و فرمانروایی دیرینه‌ات، ای زنده و پا برجای دائم،`); seg 7 takes the opening of block 4
    (`از تو می‌خواهم به حق نامت که به آن آسمان‌ها و زمین‌ها روشن شد`).
  - Segments 16 and 17 take verbatim published blocks 10 and 11: seg 16 takes full block 10
    (`خدایا در صبح این روز و تا زندگی کنم از روزهایم، برای آن حضرت بر عهده‌ام، عهد و پیمان و بیعت تجدید می‌کنم`);
    seg 17 takes full block 11 (`که از آن‌، رو نگردانم و هیچ‌گاه دست برندارم.`).
  - Seg 25 takes the verbatim second slice of block 16 (`و با نگاهی از من به او، دیده‌ام را سرمه بنه`).
  - Segments 28, 29, 30, 31 left blank (deleted): The template's Arabic verse cuts cross-cut
    published Mafatih blocks 18–22; in Persian, the Quran quotation (30:41) and surrounding invocations
    invert verb-object order (`ظَهَرَ الْفَسَادُ` rendered at the end of the Persian clause; `فَأَظْهِرِ`
    at the end of block 20), preventing any contiguous ordered partitioning without splicing across
    blocks or dropping words from the middle. Left blank rather than composed or spliced across blocks.
  - Segments 35 and 36 cleanly partition block 25 into contiguous, ordered, non-overlapping slices:
    seg 35 takes `خدایا پیامبرت محمّد (درود خدا بر او و خاندانش) را به دیدار او`; seg 36 takes
    `و کسانی که بر پایه دعوتش از او پیروی کردند شاد کن و پس از او به درماندگی ما رحم فرما،`.
  38/42 segments translated (4 blank segments).

### Batch E37, H17, E141, Q3, E16 (2026-10)

| uid | Zikr | Source | Segments |
| --- | --- | --- | --- |
| Q3 | Ziyarat on Thursday (Imam Hasan al-Askari) | https://valasr.app/library/mafatih/زیارت-روز-پنجشنبه-امام-حسن-عسکری-ع | all 13 (12 filled + existing 0) |
| H17 | Munajat of Amir al-Mu'minin (Masjid Kufa) | https://valasr.app/library/mafatih/مناجات-حضرت-امیرالمومنین-2 | all 69 (68 filled + existing 0) |
| E16 | Dua during Occultation (short version) | https://erfan.ir/mafatih569/دعای-اللهم-عرفنی-نفسک-برای-زمان-غیبت-کلیات-مفاتیح-الجنان-با-ترجمه-استاد-حسین-انصاریان (Ansarian translation, Kulliyat Mafatih al-Jinan; cross-checked with opening of Friday occultation prayer at https://valasr.app/library/mafatih/دعایی-بسیار-با-عظمت-که-در-عصر-غیبت-باید-خواند) | all 10 (9 filled + existing 0) |
| E37 | Dua Sanamay Quraish | Not in Mafatih al-Jinan (source: al-Kaf'ami Misbah, Bihar al-Anwar 85:240); not found in published Mafatih al-Jinan translations (valasr.app, hawzah.net, mafatih.anhar.ir, ghbook.ir book 19344, erfan.ir) | 1 of 64 (63 missing left blank) |
| E141 | Istighfar before Sleep (Istighfar-e-Maujiz-e-Aasaa) | Not in Mafatih al-Jinan (source: al-Kaf'ami al-Balad al-Amin, Bihar al-Anwar); not found in published Mafatih al-Jinan translations (valasr.app, hawzah.net, mafatih.anhar.ir, ghbook.ir book 19344, erfan.ir) | 4 of 38 (34 missing left blank) |

- **Q3:** Published on valasr.app under زیارت روز پنجشنبه امام حسن عسکری (ع) (Ansarian translation). The 6 published translation blocks were cleanly partitioned at Arabic phrase boundaries across the 12 Arabic segments (1/2, 3/4/5, 6, 7, 8/9/10, 11/12). Segment 0 ("امام حسن عسکری (ع)") is preserved as-is.
- **H17:** Published on valasr.app under مناجات حضرت امیرالمومنین (مناجات مسجد کوفه) in 33 translation blocks (Ansarian translation). Segments 1–18 cleanly partition the 8 Quranic verses at the Arabic phrase boundaries (1/2, 3/4, 5/6, 7/8, 9/10, 11/12, 13/14, 15–18). Segments 19–64 correspond to the 23 pairs, each cleanly split into the statement (مولایم ای مولای من...) and question (آیا رحم می‌کند...). Segments 65–68 partition the closing duas (65/66 and 67/68). Segment 0 ("مناجات امام علی (ع)") is preserved as-is.
- **E16:** Published on erfan.ir under item mafatih569 («دعای اللهم عرفنی نفسک برای زمان غیبت» از کلیات مفاتیح الجنان با ترجمه استاد حسین انصاریان). The 3 published translation blocks were cleanly partitioned across segments 1–3, 4–6, and 7–9. Segment 0 (the introductory narration note) is preserved as-is.
- **E37:** Dua Sanamay Quraish is not part of Sheikh Abbas Qomi's *Mafatih al-Jinan*, and no published translation exists on valasr.app or backstops (hawzah.net collection 79461, mafatih.anhar.ir, ghbook.ir book 19344, erfan.ir). Per binding instruction, all 63 missing segments (1–60, 62–64) are left blank. Existing segment 61 ("سپس چهار مرتبه بگو:") is preserved as-is.
- **E141:** Istighfar before Sleep (Istighfar-e-Maujiz-e-Aasaa) is from al-Kaf'ami's *al-Balad al-Amin* and *Bihar al-Anwar*, and is not part of *Mafatih al-Jinan*. No published translation exists on valasr.app or backstops. Per binding instruction, all 34 missing segments (2–32, 35–37) are left blank. Existing segments 0, 1, 33, 34 are preserved as-is.

### Seasonal small gaps — W1, W3, G64, G81 (2026-10-25)

| uid | Zikr | Source | Segments |
| --- | --- | --- | --- |
| W1 | 3rd Jumada II aamal | erfan.ir, *Kulliyat Mafatih al-Jinan* (Ansarian), chapter اعمال ماه جمادی الآخر (mafatih180); cross-checked against hawzah.net collection 79461, اعمال روز سوم جمادى الآخر (6996) | segment 3 (4 of 4) |
| W3 | Aamal in Jumada al-Akhirah | same chapter (erfan.ir mafatih180; hawzah.net 79461) | segments 6, 8, 10, 12 (14 of 14) |

W1 segment 3's Arabic is a single segment spanning two consecutive
published blocks — the ziyarat salams and the closing salawat — and the
two Ansarian blocks are joined in order. W3's four segments are the
chapter's dhikr lines, each printed with its own translation directly
under its Arabic.

- **G64 Ziyarat of Imam Zayn al-Abidin (as):** this salam set is not in
  *Mafatih al-Jinan* — the Persian Mafatih's ziyarat listings (hawzah.net
  collection 79461; erfan.ir) carry the joint Tuesday/Baqi ziyarat of the
  Imams, a different text. The set is published in Arabic and English
  only (duas.org, *Sha'ban Amaal* booklet; ABNA English). No published
  Persian translation found; all 11 segments left blank.
- **G81 Ziyarat of Lady Umm al-Baneen (sa):** this short ziyarat (source:
  ziaraat.org; duas.org "First Ziyarat") is not in *Mafatih al-Jinan*;
  Persian and Urdu publications carry the longer ziyaratnameh (a
  different text) or quote this one's Arabic without a translation. No
  published Persian translation found; all 8 segments left blank and no
  file created.
### valasr.app — G52 (2026-10-25)

| uid | Zikr | Source | Segments |
| --- | --- | --- | --- |
| G52 | Ziyarat of Lady Fatimah al-Zahra (sa) | https://valasr.app/library/mafatih/زیارت-حضرت-فاطمهع (Ansarian translation; cross-checked against hawzah.net/fa/pray/View/79461/7040) | all 64 (61 filled + existing 0, 12, 63) |

- **G52:** Published on valasr.app under زیارت حضرت فاطمه(ع) (Ansarian
  translation). The 24 published translation blocks were partitioned into
  consecutive verbatim slices across the 61 Arabic segments; every slice is an
  exact substring of its block and the slices jointly reproduce each block
  word-for-word (100% per-anchor audit: anchors verified in order against each
  block's Arabic; monotonic, no drift). One published word-order interleave is
  documented rather than silently reordered: segments 37–39 are rendered by
  valasr (and hawzah) as a single Persian sentence whose order interleaves
  anchors 37 and 38 («سلام و رحمت و برکات خدا بر تو ای فاطمه دختر رسول خدا»), so
  the consecutive partition places the salutation-and-mercy slice on 37 and the
  vocative slice on 38. Segment 56's Arabic (مُتَبَرِّئٌ) is spelled by valasr
  with U+0626 ئ where the app anchor normalizes the hamza letter away.
  Existing segments 0, 12, 63 and the merits text are preserved as-is.

### erfan.ir — E4, AH9 (2026-10-26)

Ostad Hossein Ansarian's published *Mafatih al-Jinan* translation on erfan.ir
was used to fill Persian translations for Dua Adeela (E4) and the
common ziyarat of Imam al-Kazim and Imam al-Jawad (AH9). Every filled segment is
an exact verbatim substring of the published translation of its own Arabic block.
Where published sentences spanned adjacent template segments, they were divided
cleanly by meaning at the Arabic phrase boundaries into contiguous, non-overlapping
slices without altering or composing any words. Per-anchor audit (2026-10-26):
E4 120/120 new segments verified as an ordered contiguous partition of the
erfan.ir Persian stream (117 strict own-block; segments 38, 60, 93 located by
their Persian at the exact monotonic slot in their own block — their Arabic
anchors differ from erfan's printed Arabic in spelling/word-order/recension as
noted below); AH9 38/38 strict own-block and ordered-partition verified.
Only split-boundary punctuation gaps (single «،») remain in the E4 partition,
plus the documented 250-character gap for blank segments 1–5.

| uid | Zikr | Source | Segments |
| --- | --- | --- | --- |
| E4 | Dua Adeela | https://erfan.ir/mafatih47 (Ansarian Mafatih; the valasr.app دعای-عدیله chapter ships Arabic-only contents — 51 Arabic / 3 Persian items — so erfan.ir is the operative Persian source, as with AH2/AL5) | 120 of 126 |
| AH9 | Ziyarat Common to Imam al-Kazim & Imam al-Jawad (a.s.) — Kazimayn | https://erfan.ir/mafatih285 | 50 of 94 |

- **E4 (Dua Adeela):** 120 verse segments were filled from Ostad Hossein Ansarian's
  published *Mafatih al-Jinan* translation on erfan.ir (`mafatih47`, 12 published
  blocks). The published translation blocks were cleanly partitioned
  into consecutive verbatim substrings matching the fine-grained app anchors.
  Audit notes: segment 38's anchor spells مَنجىٰ where erfan prints مَنْجٰا;
  segment 60's anchor orders اِلَيْهِ بِقَوْلِهٖ where erfan prints بِقَوْلِهِ... إِلَيْهِ;
  segment 93's anchor adds مُنْكَرٍ وَنَكِيرٍ فِي where erfan prints مُساءَلَةَ الْقَبْرِ
  alone, and erfan's Persian itself shares one «حق است» across segments 93–94
  («و سؤال قبر و برانگیخته شدن حق است»), so segment 93 ships «و سؤال قبر» exactly
  as published. Segment 82 restores the published leading «و» («و گواهی می‌دهم که
  گفتار آنان حجّت») dropped in the initial draft.
  Segments left blank:
  - Segments 1–5 (`شَهِدَ اللَّهُ اَنَّهٗ لَا اِلٰهَ اِلَّا هُوَ` through `اِنَّ الدِّينَ عِنْدَ اللَّهِ الاِسْلَامُ`)
    are left blank: in Ansarian's published Persian, the Quran 3:18–19 quotation places
    the adverbial hal clause «درحالی که... قائم به عدالت است» (segment 3) directly after the subject
    and prior to the governing verb «گواهی می دهد» (segment 1), and merges the second
    «لا اله الا هو» into segment 2, preventing contiguous, ordered partitioning without
    reordering or swapping phrases.
  - Segment 123 (`وَعِنْدَ مُسَاءَلَةِ مُنْكَرٍ وَنَكِيرٍ`) is left blank: this clause
    is absent from the published *Mafatih al-Jinan* editions (erfan.ir and
    hawzah.net), which conclude directly with «فَرُدَّهُ عَلَىَّ وَقْتَ حُضُورِ مَوْتِى، بِرَحْمَتِكَ يَا أَرْحَمَ الرَّاحِمِينَ».
  - Segment 0 takes the published opening basmala «به نام خدا که رحمتش بسیار و مهربانی‌اش همیشگی است؛».
  - Segment 125 takes the published closing supplication «خدایا من از عدیله به هنگام مرگ به تو پناه می‌آورم.» from the final erfan.ir block.
  - 120/126 segments translated (6 segments left blank: 1, 2, 3, 4, 5, 123).

- **AH9 (Ziyarat Common to Imam al-Kazim & Imam al-Jawad — Kazimayn):** 38 verse
  segments were filled from Ostad Hossein Ansarian's published *Mafatih al-Jinan* translation
  on erfan.ir (`mafatih285`).
  The 12 pre-existing segments (22, 30, 31, 32, 42, 43, 47, 89, 90, 91, 92, 93), comprising
  all chapter headings and instructional directives, were preserved byte-for-byte from the
  shipped file.
  - Segments 0–21 (22 segments) and 23–29 (7 segments) cleanly partition the two parts of
    Passage B (بخش دوم: زیارتی است که به قرائتش، آن دو امام زیارت می‌شوند) into contiguous verbatim
    slices matching the app anchors.
  - Segments 33–41 (9 segments) cleanly partition Passage A (بخش اوّل: آنکه برای هر کدام جداگانه باید خواند)
    into contiguous verbatim slices.
  - Segments 44–46 (3 segments) and 48–88 (41 segments) are left blank: this extended common
    farewell (wida) text does not appear in published *Mafatih al-Jinan* editions for Kazimayn
    (which only include the individual wida from Tahdhib, `mafatih971`). In accordance with the
    verbatim published-source mandate, no translation was invented or composed.
  - 50/94 segments translated (44 segments left blank: 44–46, 48–88).

## Gujarati

| uid | Zikr | Deck | Segments |
| --- | --- | --- | --- |
| E31 | Dua Kumayl | https://www.duas.org/ppt/Dua_Kumayl_5languages.pptx | all 271 |
| G13 | Ziyarat Jamia Kabira | https://www.duas.org/ppt/Ziyarat-jamia-kabira-eng-urdu-hindi-guj.pptx | 0-98 of 414 |
| G1 | Ziyarat Aal-e-Yasin | Jafri Library book 6687 (Hadi Library / Haji Naji) | all 159 |
| E24 | Dua Tawassul | https://mafatihuljinan.org/daily-dua-gujarati/duatawassul/ (read via its archived capture; the live site was in maintenance) | all 88 |

**Dua Tawassul.** The page prints the dua as 48 timed Arabic /
transliteration / Gujarati blocks. The app's 88 segments were mapped
onto those blocks in order; where one block carries two or three
segments its Gujarati is split at the exact clause boundary. Repeated
refrain segments (يا حجة الله على خلقه يا سيدنا ومولانا) take only the
vocative printed in their own block; the vocative's continuation is
printed at the head of the next block and belongs to that block's
segment. Segments 81 and 83 each span two blocks and join the two
printed halves. Segment 78 (the "state your need" instruction) was
already in the app and is unchanged. Zero-width joiners in the page
text are dropped, as in every other Gujarati file.

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

Not to use, for the same reason: "Muntakhab Mafateehul Jinan" (Jafri 5859,
Allama Haji Naji, 2,077 pp). Its "Gujarati" column is likewise Urdu
written in Gujarati script throughout (checked on page renders of the
Thursday supplication, Dua Simat and Dua Ihtijab sections, 2026-10). So
Q1 (Thursday supplication), E26 (Dua Simat) and E154 (Dua Ihtijab) stay
untranslated in Gujarati until a genuine Gujarati source turns up. The
Salawat of Abul Hasan al-Zarrab (E144) is not in the book at all, and no
other Gujarati source for it is known.

### Jafri Library (jafrilibrary.com)

Jafri Library hosts Gujarati booklets of the Haji Naji Trust and
hadilibrary.org (Bhavnagar) as free PDFs. Its listing filters by language
(`/books/browse/all?language=5` is Gujarati) and category, and
`/api/books/<id>` gives a book's metadata. A download needs the site's
reCAPTCHA token, so it works from a browser (10 a day without an account)
but not from curl or a cloud session.

| uid | Zikr | Book | Segments |
| --- | --- | --- | --- |
| E14 | Hadith al-Kisa | 6666 *Hadees E Kisa* (Ishaat-e-Ilm-e-Deen Committee, Bhavnagar; ed. Nasirhusain G. Nurani), pp. 21-44 | all 132 |
| G4 | Ziyarat Ashura | 6685 *Ziarat E Ashura Arabic Gujarati* (Haji Naji / hadilibrary.org) | all 128 |
| G6 | Ziyarat Warith | 6684 *Ziarat E Warisa* (Haji Naji; typeset by Maulana Rizwanali Palsaniya) | all 80 |
| E37 | Dua Sanamay Quraish | 118431 *Dua E Sanam E Quraish* (Allama Haji Naji; *Tohfa-e-Mahdi* pp. 226-229) | all 64 |
| H17 | Munajat of Amir al-Mu'minin | 6678 *Munajaat E Ali* (typeset by Maulana Rizwanali Palsaniya) | all 69 |
| G1 | Ziyarat Aal-e-Yasin | 6687 *Ziarat E Ale Yasin* (Hadi Library / Haji Naji), 36 pp | all 159 |
| E18 | Dua Ahad | 118429 *Dua E Ahad* (Allama Haji Naji), 25 pp | 41 of 42 (40 already in the app) |
| Q3 | Thursday ziyarat (Imam Hasan al-Askari) | 6693 *Weekly Ziarat* (Haji Naji), p. 16 | 12 of 13 (0 already in the app) |

These were asked for by readers (2026-10). Unlike the Mukhtasar Mafatih
above, they are real Gujarati. None of the PDFs' Gujarati copies out as
Unicode:

- **6684 and 6678** use Arial Unicode MS glyph ids with no Unicode map;
  `gu_pdf.py arialunicode` maps them back through the system font.
- **6666 and 6685** use the LMG-Arun key layout (fonts LMG ArunA and
  InvGuj); `gu_pdf.py legacy` decodes them with `lmg_arun.py` plus the
  keys these PDFs add. In 6685 InvGuj holds the Arabic spelled in
  Gujarati letters and LMG ArunA the translation; in 6666 it is the other
  way round.
- **118431** is in Shree-Lipi, which `gu_pdf.py` does not decode. It was
  transcribed by hand from the page images (220 dpi), and every word was
  checked against the PDF's raw Shree-Lipi keys. No word was unclear.
- **118429** uses the same LMG-Arun layout (LMG ArunA and InvGuj);
  `gu_pdf.py legacy` decodes it, and InvGuj holds the translation. The
  decoded wording was checked against the page images, which fixed a
  handful of decoder slips (long ઈ in થઈ and ફેલાઈ, and કાઢજે, which the
  decoder splits).
- **6693** was read from the page images (Thursday section, p. 16).

Each zikr was then aligned to our segments by reading our Arabic, and every
segment was checked by hand, as with the Urdu decks. Throughout, honorifics
are in our style ((અ.સ.), (સ.અ.વ.), (સ.અ.)), decoding slips were fixed
against the page images, and Quran citations and intention lines ("હું ...
પઢું છું કુર્બતન એલલ્લાહ") were dropped. None of the five books gives merits
for these zikrs.

- **E18 Dua Ahad.** Book 118429 prints each Arabic phrase with its
  Gujarati gloss; the segments tile the book's gloss passage end to end,
  in order, with nothing skipped. Quote marks are the book's own ('…'
  round a quoted epithet, "…" round the Quran verse in 28/29, where the
  cut falls inside the quote). Three splits sit next to the anchor
  boundary because the book's word order fuses clauses: 16 keeps
  "મારી ગરદન ઉપર રહેલ વાયદા-કરાર" and 17 opens with the book's "અને
  બયઅતને" (the shipped Urdu splits the same way); 21 keeps the book's
  relative clause whole, so it also carries "નિશ્ચિત મુકર્રર કરી છે"
  (حتما مقضيا, the head of our 22); 28/29 splits the Quran quote after
  "સમુદ્રમાં", as the Urdu does. Segment 40 (the thigh-striking
  instruction) was already in the app from another source and is
  unchanged; the book's own wording for it differs. The book prints a
  merits hadith (p. 3); our E18 has no merits field filled, and none was
  taken.
- **Q3 Thursday ziyarat.** Book 6693, p. 16 (Imam Hasan al-Askari). The
  page's eight Gujarati lines tile segments 1-12 exactly. The book
  prints a doubled comma in segment 2, written once here, and bare
  "અ.સ." honorifics, written in our (અ.સ.) style. The book gives no
  Gujarati for its Basmala or closing salawat, and Q3 has no segments
  for them.
- **E14 Hadith al-Kisa.**
  - The booklet's chain starts at Fatimah. Segments 1-4 add Jabir and
    "daughter of the Messenger" in its wording.
  - Our own: 34 (يا من اختاره الله), 48 (a dropped السلام عليك), 95
    (وعزتي وجلالي; the booklet has "about you" for يقول لك), and 119 and
    131 (ورب الكعبة).
  - 77-80 and 96-99 follow the booklet: "I made the sky ... only for their
    love". The Arabic says "I did not create the sky ... except for their
    love".
  - The booklet's quotation marks, which open in one segment and close in
    another, were removed, as the Urdu has none.
- **G4 Ziyarat Ashura.**
  - The booklet says it gives the sense (ભાવાર્થ), not word for word.
  - Our own:
    - 14 (في السماوات);
    - 32: تنقبت is "નકાબ પહેર્યા", where the booklet has "advanced";
    - 34, 59 and 61: الذي اكرم / اكرمني / رزقني in the past tense, where
      the booklet makes them requests;
    - 67: امام هدى, where the booklet has "ઇમામે ઝમાના" from the reading
      امام مهدي;
    - 93: "them", where the booklet has "your enemies" in a line addressed
      to Allah;
    - 96, 102, 112 and 121: our earlier instruction lines.
  - Dua Alqama is not in the booklet.
- **G6 Ziyarat Warith.**
  - Our own: 31, where الْمَهْدِىُّ is "હિદાયત પામેલા" (the booklet has
    "guide" twice), and 68, where عَظِيْمًا is missing in the booklet.
  - The booklet's three salutations before وارث آدم are not in our G6.
- **E37 Dua Sanamay Quraish.**
  - The booklet follows a slightly different Arabic and skips some
    phrases. Our own: 17, 19, 23, 26, 31, 32, 45, 47, 50, 54 and 61.
  - 47: the booklet's "made false claims" reverses دعوى أبطلوها.
  - 45: its "changed" is "abandoned" for تركوها.
- **H17 Munajat of Amir al-Mu'minin.** 66: كرمك is "તારા કરમ", where the
  booklet has "mercy".

- **G1 Ziyarat Aal-e-Yasin.** Book 6687's PDF has a full text layer set
  in the legacy LMG-Arun font, decoded with `lmg_arun.py`. Each
  translation block was aligned via the booklet's Gujarati
  transliteration block (a phonetic anchor for its Arabic segment) and
  cross-checked against the Arabic and the verified Urdu. Segment 85
  ("ઝિયારત પછી પઢવાની દુઆ") is preserved from the existing heading.
  Multi-segment sentences are partitioned cleanly across segment
  boundaries (1/2, 3/4, 5/6, 7/8, 9/10, 11/12, 18/19, 29/30, 34/35,
  38/39, 40/41, 42/43, 44/45, 46/47, 48/49, 50/51, 52/53, 54-56, 59/60,
  66/67, 69/70, 72/73, 74/75, 78/79, 86/87, 97/98, 99/100, 121/122,
  128/129, 130/131, 135/136, 145/146, 147/148, 150/151, 152/153). Two
  split second halves are restored in our own Gujarati to complete the
  Arabic: 98 ("હઝરત મોહમ્મદ(સ.) અને તેમની આલ (અ.સ.) માટે") and 151
  ("સલ્લલ્લાહો અલય્હે વ આલેહ"). Hand-corrected legacy-decode artifacts:
  - `Ò` (dropped by `lmg_arun.py`'s `DROP` set): represented `જી` in the
    font, hand-restored in `રાજી` (74), `ફરજિયાત` (125), and `વાજિબ` (126);
  - `Ô` (Latin character representing `જા` / `જો` glyph in the font):
    hand-corrected in `દરવાજા` (3), `છવાઇ જાય છે` (29), `પ્રકાશિત થઇ જાય છે.`
    (30), `સજા` (68), `રહેજો` (71), `માનવજાતની` (118), `ઈજાથી` (134),
    `વંશજોનું` (138), `જાહેર` (139), and `કમજોર` (143);
  - Vocalic r / ru-matra (decoded as apostrophe `'`): corrected in
    `મૃત્યુ` (57);
  - Ligature `Þ` (glyph for `ક્ક` conjunct): corrected in `'મક્કમ'` (90, 91);
  - Ligature `w` (glyph for half-dha): corrected in `ધ્વજ` (16);
  - Conjunct `ચ્ચ` (typed as `rR`, decoded with `ઇ` for `r`): corrected in
    `સચ્ચાઇના` (93) and `સચ્ચાઇની` (112);
  - Conjunct `ક્ત` (LMG-Arun sequence decoded as `કિત`): corrected in
    `પરખશક્તિ` (94), `મુક્તિની` (116) and `શક્તિશાળી` (140);
  - Opening/closing quotation marks (decoded as `—` and dropped `˜`):
    restored in `'મુન્કર'` (77) and `'મક્કમ ઇરાદા'` (90);
  - Original book typo: duplicated `અને અને` corrected to single `અને` (137).

  One correction to the book itself: segment 114. Book 6687 prints
  "ડરી ગયેલાઓનું રક્ષણ કરનાર છે" (protector of the frightened) for
  الْمُرْتَقِبِ الْخَائِفِ, but the Arabic describes the Imam himself, as
  do the published Urdu ("نگراں اور خوفِ خدا رکھنے والے"), Persian and
  English translations. Corrected to "નિગરાન અને ખૌફે ખુદા રાખનાર છે"
  (watchful, and God-fearing).

Other Gujarati books in the listing, by number:
- 84725 Munajat Shabaniyah. An earlier search found it as scanned
  images; its PDF was likewise obtained, and its text layer is a
  different legacy font ("Gujrati"), decode pending.
- 6690 and 122353 Jamia Kabira (60 and 41 pages; our G13 has only
  segments 0-98).
- 90862 Ziyarat Nahiya.
- 6663 Dua Tauba.

Its Dua category has no Gujarati Dua Tawassul, and the catalog has no Dua
Alqama.


### Seasonal small gaps (2026-10-25)

- **W1 segment 3; W3 segments 6, 8, 10, 12:** no Gujarati text of the
  Jumada II aamal could be verified in the sources this project uses.
  mafatihuljinan.org carries dated Gujarati aamal pages, but the text of
  these chapters could not be retrieved for verification in this pass,
  and Jafri Library's *Muntakhab Mafateeh* is Urdu in Gujarati script
  (see "Not to use" above), not a Gujarati translation. Left blank.
- **G64 Ziyarat of Imam Zayn al-Abidin (as) (11 segments) and G81
  Ziyarat of Lady Umm al-Baneen (sa) (8 segments):** neither text is in
  *Mafatih al-Jinan*, and no published Gujarati translation was found in
  mafatihuljinan.org or the Jafri Library books used by this project.
  Left blank; no G81 Gujarati file created.
### Jannat ni Chaavio (web.hajinaji.com) — G52 attempted, not usable (2026-10-25)

- **G52:** The only Ziyarat of Lady Fatimah (sa) in Haji Naji Memorial
  Trust's *Jannat ni Chaavio* (compiled by Maulana Rizwan Ali Palsaniya;
  genuine Gujarati *Mafatih al-Jinan*) is the weekly chapter «રવિવારના
  દિવસે ઝિયારતે બીબી ફાતેમા ઝહરા સ.» (Sunday Ziyarat, in the topic
  «અઠવાડીયાની 14 માસૂમીન (અ.) ની ઝીયારતો»). The book's full chapter list
  (63 chapters, checked on the web.hajinaji.com overview page,
  2026-10-25) contains no tomb ziyarat and no shahadat/wiladat chapter
  for her — no fuller version exists in this book.
  The Sunday chapter is a shorter, divergent recension of the app's
  *Mafatih* text. Its two Arabic blocks were mapped against all 64 app
  anchors (folded-text matching): only anchors 1 and 4 occur verbatim.
  Anchor 3 (قَبْلَ اَنْ يَخْلُقَكِ) is absent; anchor 2 is printed without
  اللّٰهُ; anchors 5, 6, 7, 8, 9 and 10 are reworded or fused (6 and 8
  merge as صَابِرٌ عَلَىٰ مَا أَتَىٰ بِهِ أَبُوكِ وَوَصِيُّهُ); anchor 11 is
  replaced by لِتُسَرَّ نَفْسِىْ; the chapter closes with فَاشْهَدِىْ اَنِّىْ
  ظَاهِرٌ بِوِلَايَتِكِ, which has no app anchor; anchors 12-63 have no
  counterpart in the chapter at all.
  The Gujarati also fails the split/partition gate: anchors 1 and 2 are
  rendered as one fused relative clause («જેમનું ઈમ્તેહાન ખુદાએ લીધું»)
  with no clause boundary between them, so no verbatim split exists; and
  with anchors 1-2 unassignable, the block's translation cannot be
  jointly partitioned in order — anchor 4's clause («તો તે ઈમ્તેહાનમાં
  તમને સબર કરવાવાળા જોયા») cannot be taken alone without orphaning the
  text before it. **Result: 0 segments filled; Gujarati G52 stays at
  3/64 (existing 0, 12, 63).** Do not re-extract this chapter for G52.
  The remaining segments need the mafatihuljinan.org Gujarati *Mafatih*
  page (post 2285), whose body is JS-rendered and still unextracted.
