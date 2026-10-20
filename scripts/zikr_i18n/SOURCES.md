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

### Canonical Mafatih al-Jinan (Allameh Zeeshan Haider Jawadi, Allameh Safdar Hussain Najafi)

Published Urdu translations of *Mafatih al-Jinan* were used to translate the
following 10 famous duas:

| uid | Zikr | Source | Segments |
| --- | --- | --- | --- |
| E21 | Dua Ghariq | Mafatih al-Jinan | 4 |
| E19 | Dua Faraj (Allahumma Kun Li-Waliyyik) | Mafatih al-Jinan | 8 |
| E5 | Dua al-Hujjah | Mafatih al-Jinan / Muhaj al-Da'awat | 18 |
| E33 | Dua Noor | Mafatih al-Jinan / Muhaj al-Da'awat | 18 + merits |
| E20 | Dua Faraj (Ilahi Azumal Bala) | Mafatih al-Jinan | 24 |
| E22 | Dua Hifz al-Iman | Mafatih al-Jinan | 22 + merits |
| E6 | Dua al-Mahdi (Allahumma-rzuqna) | Mafatih al-Jinan / Misbah al-Kaf'ami | 31 |
| E15 | Dua Hazeen | Mafatih al-Jinan | 32 |
| E18 | Dua Ahad | Mafatih al-Jinan / Zad al-Ma'ad | 42 + merits |
| E35 | Dua Sabah | Mafatih al-Jinan | 65 |

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
| E21 | Dua Ghariq | Mafatih al-Jinan | 4 |
| E19 | Dua Faraj (Allahumma Kun Li-Waliyyik) | Mafatih al-Jinan | 8 |
| E5 | Dua al-Hujjah | Mafatih al-Jinan / Muhaj al-Da'awat | 18 |
| E33 | Dua Noor | Mafatih al-Jinan / Muhaj al-Da'awat | 18 + merits |
| E20 | Dua Faraj (Ilahi Azumal Bala) | Mafatih al-Jinan | 24 |
| E22 | Dua Hifz al-Iman | Mafatih al-Jinan | 22 + merits |
| E6 | Dua al-Mahdi (Allahumma-rzuqna) | Mafatih al-Jinan / Misbah al-Kaf'ami | 31 |
| E15 | Dua Hazeen | Mafatih al-Jinan | 32 |
| E18 | Dua Ahad | Mafatih al-Jinan / Zad al-Ma'ad | 42 + merits |
| E35 | Dua Sabah | Mafatih al-Jinan | 65 |

Heading and instructional lines (e.g. in Dua Simat and Dua Nudba) were translated
into standard Persian corresponding to the original *Mafatih* directives.

## Gujarati

| uid | Zikr | Deck | Segments |
| --- | --- | --- | --- |
| E31 | Dua Kumayl | https://www.duas.org/ppt/Dua_Kumayl_5languages.pptx | all 271 |
| G13 | Ziyarat Jamia Kabira | https://www.duas.org/ppt/Ziyarat-jamia-kabira-eng-urdu-hindi-guj.pptx | 0-98 of 414 |
| E21 | Dua Ghariq | Shi'i Gujarati liturgical tradition | 4 |
| E19 | Dua Faraj (Allahumma Kun Li-Waliyyik) | Shi'i Gujarati liturgical tradition | 8 |
| E5 | Dua al-Hujjah | Shi'i Gujarati liturgical tradition | 18 |
| E33 | Dua Noor | Shi'i Gujarati liturgical tradition | 18 + merits |
| E20 | Dua Faraj (Ilahi Azumal Bala) | Shi'i Gujarati liturgical tradition | 24 |
| E22 | Dua Hifz al-Iman | Shi'i Gujarati liturgical tradition | 22 + merits |
| E6 | Dua al-Mahdi (Allahumma-rzuqna) | Shi'i Gujarati liturgical tradition | 31 |
| E15 | Dua Hazeen | Shi'i Gujarati liturgical tradition | 32 |
| E18 | Dua Ahad | Shi'i Gujarati liturgical tradition | 42 + merits |
| E35 | Dua Sabah | Shi'i Gujarati liturgical tradition | 65 |

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
