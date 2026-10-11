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

### Turned down

- **duas.org's Ziyarat Jamia Kabira and Dua Alqama decks**: their Urdu is
  machine-translated from the English. For example, عيبة علمه comes out as
  "اس کے علم کی شرمندگی" and المستغيثين as "مدد کے لئے فون کرنے والوں".
- **duas.pro** (the first batch, never merged): its Persian is a machine
  translation of the English.

## Persian, Gujarati

Not started.
- **Persian:** the published translations (Ansarian's, Elahi Qomshei's
  Mafatih) are on Iranian sites, which the cloud sessions cannot reach.
- **Gujarati:** duas.org's Kumayl and Jamia Kabira decks have Gujarati in the
  legacy LMG-Arun font, which would need a decoder like
  `gu_quran_decoder.py`.
