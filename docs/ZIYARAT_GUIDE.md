# Ziyarat Guide

A home-screen feature for pilgrims: the places Shia Muslims visit for
ziyarat, city by city, and for each shrine everything a pilgrim needs while
standing there - which ziyarats to recite (links into the zikr corpus), what
the place is, who else is buried there, practical tips, and directions.

Started 2026-11-07 on branch `claude/festive-mendel-y1kzr5`. See "Status and
resume here" at the bottom before continuing.

## What the reader sees

```
Home ▸ All features ▸ Ziyarat Guide
  Ziyarat Guide            (large title; "Before you go" card list + regions)
    Before you go          rows: Etiquettes of Ziyarat (B3), Izn-e-Dukhool (B6),
                           Supplications after the Ziyarat (G26), ...
    Iraq                   group label, then one row per city
      Najaf al-Ashraf  ›   "3 places · 9 ziyarats"
      Karbala          ›
    Iran / Saudi Arabia / Syria ...
  City page                about, tips, then one row per site
  Site page                header (name, Arabic name, kind, city),
                           Directions / Compass buttons,
                           Map of the shrine (a card; opens the plan page),
                           Ziyarat (rows opening ZikrPage, optionally a tab),
                           About, Also buried here, Tips for pilgrims
  Plan page                the shrine drawn from above, pinch and drag; the
                           zarih, tombs, gates and doors as markers; tap one
                           for its card (side of the shrine, distance from
                           you, its ziyarats, Directions to it, the next
                           site's page); "Places on the map" lists them all;
                           north/qibla dial, "show where I am", scale bar
```

- The existing zikr groups (`G0~B` -> `B~AF8` Iraq -> `AF~AK1` Najaf ...)
  stay as they are: favorites, links and search keep working. The guide is
  a second, richer way in that links to the same entries; it never copies
  zikr text.
- Directions open the platform maps app (`geo:` / Apple Maps / Google Maps
  URL) via `url_launcher`; no map SDK, no tiles, works offline-first. The
  shrine plans (below) are drawn by the app itself from bundled data, so
  they need neither.
- A site with a `holySiteId` also offers "Point the compass", which opens
  the Qibla Finder aimed at that `HolySite` (`lib/data/holy_sites.dart`).

## Data: `assets/ziyarat_guide.json`

English source of truth. Every `id` is stable forever (translations,
analytics and any future deep links key on it) - never derive it from a
name, never rename it.

```jsonc
{
  "general": [                       // "Before you go" on the front page
    { "uid": "B3" },
    { "uid": "B6" }
  ],
  "regions": [
    {
      "id": "iraq",                  // lowercase snake_case, unique per kind
      "name": "Iraq",
      "arabicName": "العراق",
      "cities": [
        {
          "id": "najaf",
          "name": "Najaf al-Ashraf",
          "arabicName": "النجف الأشرف",
          "about": "One or two short paragraphs. Markdown links [text](uid) allowed.",
          "tips": ["One practical tip per string, one or two sentences."],
          "sites": [
            {
              "id": "imam_ali_shrine",
              "name": "Shrine of Imam Ali (a.s.)",
              "arabicName": "العتبة العلوية المقدسة",
              "kind": "shrine",      // shrine | mosque | cemetery | tomb | maqam | other
              "location": [32.0297, 44.3145],   // [lat, lng] of the tomb/mosque itself
              "holySiteId": "imam_ali_najaf",   // optional: a HolySite id
              "about": "What the place is and why it is visited; short.",
              "ziyarat": [
                { "uid": "AK5" },                         // whole entry, its title shown
                { "uid": "AK5", "tab": 2, "label": "Ziyarat Aminullah" },
                { "uid": "G26", "note": "After any ziyarat." }
              ],
              "buried": [
                {
                  "id": "allamah_hilli",
                  "name": "Allamah al-Hilli",
                  "arabicName": "العلامة الحلي",
                  "diedAh": 726,     // optional integer, Hijri year of death
                  "note": "Jurist and theologian, author of Tadhkirat al-Fuqaha. Buried in the northern iwan."
                }
              ],
              "tips": ["..."],
              "sources": ["https://..."]   // for reviewers only, never shown
            }
          ]
        }
      ]
    }
  ]
}
```

Rules:

- `ziyarat[].uid` is a live zikr uid (a key of `assets/zikr.json`, or an
  alias's canonical uid). `tab` is counted from 1 as the reader shows tabs
  (the `?tab=N` number); a ref with a `tab` must have a `label`. Without a
  `label` the row shows the zikr's own (translated) title.
- Only link entries whose text is really for that place. A ziyarat the
  corpus lacks is listed under "Missing ziyarats" in this doc, not invented.
- `about`, `tips`, `note` are short, plain, respectful English: what to do
  and what the place is. No polemics, no unverifiable miracle claims stated
  as fact, no volatile facts (opening hours, prices, visa rules, phone
  numbers, which gate is open this year).
- Burials: only people whose burial *at that site* is well attested; when
  a place is disputed say so in the note ("one of the places where ... is
  said to be buried"). Every site's facts carry `sources`.
- Honorifics and spellings follow "Zikr title conventions" in `CLAUDE.md`
  ((a.s.), (s.a.), (s.a.w.a.), (a.t.f.s.), Husayn, Zainab, Reza, Masuma...);
  scholars and companions get (r.a.) only where the corpus already does
  (e.g. Salman); otherwise none.
- `test/ziyarat_guide_test.dart` checks all of the above that a script can:
  unique ids, live uids, tab ranges, labels on tab refs, coordinates in
  range, `holySiteId`s that exist, overlay keys that exist in the source.

## Translations: `assets/ziyarat_guide_i18n/<code>.json`

Flat `{ "<key>": "<text>" }` per language (ur, fa, ar, gu), keyed by ids,
never by English text:

| key | text |
| --- | --- |
| `region.<regionId>.name` | region name |
| `city.<cityId>.name` / `.about` / `.tips.<n>` | city fields (`n` from 0) |
| `site.<siteId>.name` / `.about` / `.tips.<n>` | site fields |
| `site.<siteId>.ziyarat.<n>.label` / `.note` | a ziyarat ref's label/note |
| `site.<siteId>.buried.<personId>.name` / `.note` | a burial |

Outside English, as in the zikr reader, no English is shown: an
untranslated name falls back to its `arabicName` (ur, fa, ar) and an
untranslated about/tip/note is hidden. Inserting or removing a tip shifts
the `.tips.<n>` keys after it - renumber the overlays in the same change.
UI strings (section headings, buttons, kinds) are ARB keys `ziyaratGuide*`
in all five `lib/l10n/app_<code>.arb`.

## Code

- `lib/models/ziyarat_guide.dart` - the model and its JSON parsing, plus
  the overlay lookup.
- `lib/services/ziyarat_guide_repository.dart` - loads the asset and the
  app language's overlay once (rootBundle), cached.
- `lib/pages/ziyarat_guide/` - `ziyarat_guide_page.dart` (front page),
  `ziyarat_city_page.dart`, `ziyarat_site_page.dart`.
- `lib/navigation/home_menu.dart` - `ziyaratGuideMenuItem`, admin-gated in
  `visibleHomeMenuItems` until content and translations are reviewed
  (remove the gate to ship).

## Phases

1. Infrastructure, UI, l10n keys, test, first content for Iraq, Iran,
   Saudi Arabia (Hijaz) and Syria. Admin-only.
2. Owner review of content (facts, burials, tips) - reviewers read
   `sources`.
3. Missing ziyarats: import the ones the guide lists as missing (duas.org
   via `scripts/extract_ziyarat_sections.js`, then the `zikr-structure`
   skill and `source_check.py`), and link them in.
4. Translations of the guide content (ur, fa, ar, gu) - judgement-heavy,
   opus/high agents, one language each.
5. Point the Ziyarats list's `G0~B` row at the guide, ungate, What's New
   note, ship.
6. Optional: more regions (Egypt, Jordan - Ja'far al-Tayyar,
   Lebanon, Saudi Ghadir/Juhfa), shrine audio/live streams links
   (`lib/data/live_streaming_data.dart`).

## Shrine plans

An interactive plan of a shrine and its neighbours: the precinct,
courtyards, buildings, gold domes and minarets drawn from above, with the
places a pilgrim looks for as tappable markers - the zarih, the other tombs
and maqams, the courtyard gates, the doors of the haram, and the next site
(Bayn al-Haramayn, Tall al-Zaynabiyya). Tapping one shows what it is, which
side of the shrine it is on, how far it is from the reader (once they ask
to be located), the ziyarats to recite there, Directions to that very gate,
and a link to the next site's page. The owner asked for this (2026-11-08):
"click on a gate or a shrine ... and that opens the respective ziyarat".

Two parts:

- **The drawing**, `assets/ziyarat_plans/<plan id>.json`, generated - never
  edit it by hand. `python3 -I scripts/ziyarat_maps/build_plans.py [<plan
  id>]` downloads OpenStreetMap's data for the plan's `bbox` (cached in
  `build/osm_cache/`, `--refresh` to download again), sorts ways into layers
  (precinct, green, walk, court, road, path, water, building, gate, gold,
  minaret, wall), clips and simplifies them and writes them in decimetres
  around the bbox's centre. About 30 KB a plan. The data is © OpenStreetMap
  contributors (ODbL); the plan page shows that line, keep it.
- **The features**, in the guide, on the city: `plans`, one or more per
  city, each covering one or more neighbouring sites.

```jsonc
"plans": [
  {
    "id": "karbala_haramayn",            // stable; names the asset
    "bbox": [32.6138, 44.0296, 32.6192, 44.0390],   // south, west, north, east
    "sites": ["imam_husayn_shrine", "abbas_shrine", "bayn_al_haramayn"],
    "features": [
      {
        "id": "husayn_tomb",
        "kind": "zarih",       // zarih | tomb | maqam | place | gate | door | landmark
        "name": "Zarih of Imam Husayn (a.s.)",
        "arabicName": "ضريح الإمام الحسين (ع)",
        "osm": "w1156225811",  // n/w/r + id: the script sets `location` from it
        "location": [32.616356, 44.032544],
        "site": "imam_husayn_shrine",   // the site it belongs to (or, for a place, is)
        "person": "ali_al_akbar",       // optional: a `buried` id of that site
        "note": "...",                  // optional, short
        "ziyarat": [{ "uid": "AG14" }]  // as a site's ziyarat refs
      }
    ]
  }
]
```

- A site page shows the plan whose `sites` lists it, opened on that site's
  `zarih` (else its first feature). Every listed site needs a feature.
- Prefer an OSM id over a typed `location`, and check what OSM says: Hazrat
  Abbas's tomb node is 43 m south of his dome, so `abbas_tomb` uses the
  dome's way. A feature without `osm` keeps the `location` typed in.
- Gates link Izn-e-Dukhool (B6); tombs link their own ziyarat; a maqam
  without a ziyarat gets a one-line `note` ("by tradition" where it is).
- Markers appear by zoom (doors only close up) and labels by priority
  (zarih, place, tomb, gate, maqam, landmark, door) where they fit.
- Translations: `plan.<plan id>.<feature id>.name` / `.note` /
  `.ziyarat.<n>.label` / `.note` in the overlays; an untranslated name
  falls back to `arabicName` as elsewhere.
- `test/ziyarat_guide_test.dart` checks plans (sites in the city, kinds,
  osm ids, locations inside the bbox and the drawing, persons, refs, a
  feature per site, the asset exists); `test/ui/shrine_plan_test.dart`
  renders the Karbala plan at three sizes and taps through it.

**Plans so far (10, 126 features):** `karbala_haramayn` (41: Imam
Husayn, Hazrat Abbas, Bayn al-Haramayn, Tall al-Zaynabiyya, al-Mukhayyam),
`najaf_haram` (8), `kufa_mosque` (17: nine maqams linked to their AI3/AI4/
AI5/AI11 tabs, Muslim, Hani, al-Mukhtar), `sahla_mosque` (3),
`kazimayn_haram` (7), `samarra_haram` (2: the zarih and the Sardab),
`mashhad_haram` (20, mostly courtyards and basts), `qom_haram` (10),
`damascus_old_city` (7: Lady Ruqayya, Ras al-Husayn, the Umayyad Mosque's
gates), `madinah_haram` (11: the Prophet's tomb, Rawdah, gates, al-Baqi's
gate and the Imams' graves). Plans use `layers` where OSM tags a dome
without its colour (Samarra, Mashhad, Qom gold; Madinah's Green Dome).

**No plan, and why:** Lady Zainab's shrine and Bab al-Saghir (OSM maps
almost nothing there: someone would have to map them in OSM first);
Jamkaran, Rey, Shiraz, Uhud, Makkah (not attempted yet).

**For the owner to confirm before shipping:**

- `madinah_haram.baqi_imams`, `mashhad_haram.sahn_payambar_azam` and
  `qom_haram.sahn_atiq` have `location`s read off Esri's satellite
  imagery, not OSM; Esri's terms may not allow taking positions from it.
  Confirm or replace (e.g. by mapping them in OSM first). Typed, not from
  OSM, too: `madinah_haram.house_of_fatimah` and
  `damascus_old_city.ras_al_husayn` (from descriptions, a few metres out).
- Al-Baqi's other graves (Fatimah
  bint Asad, Umm al-Banin, the aunts, Ibrahim...) are left out: sources
  disagree on where they lie.
- Samarra: the Sardab marker is on an unnamed tiled dome west-north-west
  of the shrine, inside an OSM polygon tagged as the Great Mosque.
- Najaf: Allamah al-Hilli is placed at the northern minaret (from the
  guide's own note); Bab Muslim ibn Aqil left out (5 m from Bab al-Sa'a in
  OSM).
- Kufa: the gates link AI3 tab 1 (entering the mosque), not B6; Mafatih's
  column numbers for Ibrahim/Adam disagree with the mosque's own site, the
  plan follows the markers on the ground; AI3 tab 7 ("Station of Prophet
  Nuh") also holds the Seat of Amir al-Mu'minin's acts.
- Qom: OSM numbers 23 gates "درب ۱"-"درب ۲۴"; if that is the shrine's own
  numbering they can be added as "Gate N" with B6.
- Mashhad: English names of courtyards and basts (Enqelab, Jomhouri
  Islami, Kawthar, Navvab Safavi, Naqqara Khana) are common spellings, not
  checked against razavi.ir (unreachable from a cloud session).

**To grow a plan**, or add one: fetch, print candidates with
`--candidates`, pick and name the features (verify names on the shrine's
own site), link their ziyarats, build, run the two tests, and look at it
with `flutter test scripts/ziyarat_maps/plan_shots_test.dart
--dart-define=SITE=<site> --dart-define=OUT=<dir>
[--dart-define=FEATURES=<ids>]` (PNGs with real fonts). Missing tombs
inside the shrines (Shaykh Baha'i, al-Hurr al-Amili, al-Mufid, Ibn
Qulawayh, Khoei...) need OSM to map them, or two agreeing sources.

## Content audit (2026-11-07)

Did the zikr-structure commits (2e563e3c, 2c32ff77, 4eb9c7a3, 3f1f1734,
475bacb9, 08884d4d) lose shrine-ziyarat text? **No Arabic was lost.**
Every Arabic line is still in the corpus. AK5's Aminullah tab moved to G2,
with one typo fixed. About 120 English sentences were dropped, almost all
book scaffolding ("Ninth:", "as mentioned above", attributions and chains).
Only the provenance lines in AG2, AK5/G2 and G26 might be worth putting back
into merits.

The real gaps come from the import and retirement steps, not from structure:

- **Divine Pearls text never re-imported** (all on the restoration list in
  `scripts/unfavorited_missing_zikrs.json`):
  - Mashhad AE3, AE4, AE7, AE8, AE17 (Abd al-Azim);
  - Karbala AG21 (soil of Husayn), AG15;
  - AJ3 Taq Kasra;
  - AI13 Muslim ibn Aqil (partial);
  - Najaf AK17, AK19 (Prophet's birthday, Be'that);
  - Samarra AL8 (Lady Narjis), AL4;
  - Baghdad AM3 (Four Deputies);
  - Madinah AP5-AP14 and Uhud AQ1-AQ4 (absent entirely);
  - B1, B5, G31 (farewell to the Imams), G32 (Niyabat).
- **Weak retirements:** G8 (Imam Reza, Ya Gharib) -> G76 tab 1 keeps about
  28% of its text. G9 -> G76 tab 2 keeps about 37%. G17/L4 -> L3 keeps about
  45%. AK9-AK11 -> AK5 are each missing 100-230 letters.
- **Live entries short of their source:** AK5 lacks 39% of the Divine Pearls
  text: the First Ziyarah's pre-departure dua, the takbirs and the poem.
  The duas.org import never had them. G11 Nahiya lacks about 720 letters,
  AG14 about 330, AL15 about 360.
- **Duplicates (share of Arabic overlapping):** AK13 is 99% inside AK5's
  "Seventh Ziyarat" tab. AE15 and G78 (Masuma) overlap 97%/99%. AK8 and G2
  overlap 91%/89%. G69 is 97% inside AH5 tab 1. G78 and G82 (Sakina)
  overlap 91%/71%. G57 is 87% inside AG18, G6 78% inside AG14, G71 73%
  inside AL6 tab 1. Each pair is a candidate for a tab-level alias
  (`ZIKR_STRUCTURE.md` rule 5) once the texts are compared.

The audit scripts are not kept. To redo it, compare Arabic lines (strict,
then diacritic-insensitive) per entry across those commits, against the
whole HEAD corpus, with `assets/items/*` at `d11c1f16^` for Divine Pearls.

## Missing ziyarats (phase 3 work list)

Found while writing phase 1's content. Uids are from
`scripts/unfavorited_missing_zikrs.json` (their old text is in git history,
see `scripts/RESTORING_MISSING_ZIKRS.md`); URLs hold a text to check against.

- **Imam Reza (the biggest gap):** G68 is only the head-side salutation.
  Missing: the main first ziyarat AE3, the dua after it AE4, Ziyarat
  Jawadiyya AE5, other forms AE6/AE7, the farewell AE8, his own
  Izn-e-Dukhool, the "Seven Hadith" ziyarat, Imam al-Zaman's ziyarat at his
  shrine. All on https://www.duas.org/ziaratimamreza_sr.htm.
- **Iran, other:** Abd al-Azim al-Hasani AE17 (Arabic in history);
  farewell to Lady Masuma (AE14 was prose only); descendants of the Imams in
  general G28 (prose only, would serve Rey and Shiraz).
- **Madinah**, all on https://www.duas.org/mobile/madina-mecca-rites.html:
  the four Baqi Imams AP8 (https://www.duas.org/ziaratbaqi.htm), farewell to
  them AP9, farewell to the Prophet AP13, Ibrahim son of the Prophet AP11,
  Fatimah bint Asad AQ1, acts in
  Madinah's mosques AP12, ziyarat of the Prophet from a distance AP5/AP6;
  no uid: Abbas ibn Abd al-Muttalib, Aqil and Abdullah ibn Ja'far, the
  Prophet's wives, daughters and aunts, Isma'il ibn Ja'far, Halimah.
  (Hamzah and the martyrs of Uhud are restored: AQ2, with AQ3/AQ4 retired
  into it.)
- **Makkah (no uid):** Abd Manaf, Qasim (both on madina-mecca-rites.html).
  Lady Khadijah is restored as AQ5.
- **Baghdad:** the Four Deputies AM3 (+AM2)
  (https://duas.org/mobile/ziyarat-deputies-imam.html), Masjid Buratha AM1,
  al-Kulayni AM4.
- **Kazimayn:** AH3 (another ziyarat of Imam al-Kazim), AH1, AH11.
- **Samarra:** Lady Narjis AL8, Lady Hakimah AL9, AL4, AL10, AL16.
- **Mada'in:** prayer at Taq Kasra AJ3, Hudhayfah AJ4, AJ1.
- **Najaf:** ziyarat of Imam Ali on the Prophet's birthday AK17
  (duas.org/ziaratimamali17ra.htm) and on the Mab'ath AK19
  (duas.org/pdfs/27rajabmafatih.pdf); the First Ziyarat's own izn (AK5's
  first tab starts at the tomb, so the guide links B6); the short ziyarat
  of Imam Husayn at Masjid al-Hannanah (Ibn al-Mashhadi, in Mafatih after
  the head ziyarat).
- **Kufa:** AI13/AI14 (Muslim, Hani - G60/G61 cover them), AI17 (Zayd and
  Sa'sa'ah, prose only).
- **Karbala:** AG21 (soil of Husayn), AG20 (special occasions), AG15, G31
  (farewell to the Imams), B5 (izn).

## Corpus problems found (owner's review)

**Owner's decisions (2026-11-08), applied in session 2:** G82 retitled
"Ziyarat of Lady Ruqayya (s.a.) of Damascus"; AE15 retired into G78 (G78
took AE15's English and its three tasbih lines); AJ2 retitled "Ziyarat of
Salman al-Farsi (r.a.) — Mada'in" and G63 retired into it; the stub lines
of AG14, AK6, AK7, AI5, AI15 and AL1 removed; AL6 tab 1 relabelled "Ziyarat
of Imam Hasan al-Askari (a.s.)" (the lint's 40-character limit dropped the
"al-"); G68 retitled "Short Ziyarat of Imam Ali al-Reza (a.s.)". The owner
chose to leave AH5's entry rites where they are. Still open from these:

- G82's `day` 02-10 matches `events.json`'s Sakina date; Lady Ruqayya's
  death is mostly marked on 5 Safar - owner to decide.
- G78's line «السلام عليكما يا سبطي نبي الرحمة…» has no English: AE15 read
  «يا سبطي الرحمة», so its translation didn't fit.
- G78's three new tasbih lines have no ur/fa/ar/gu translation; the
  Ruqayya spellings in the four `index.json` titles (رقیہ / رقیه / رقية /
  રુકૈયા) need a native speaker's check.
- G63's four one-word variants against AJ2 (ابن/بن, وَسَيِّدِ, الملٰئكة,
  السادات/السادة) were not carried over.
- Other heading-like lines remain in AG14, AI5, AL1 ("Permission to enter",
  "Z I Y A R A T", ...); not part of the decision.

The list as found in session 1:

- **G82** is titled "Ziyarat of Lady Sakina (s.a.)" but is the ziyarat of
  Lady Ruqayya of Damascus; check its `day`s (02-10, 07-20) too. The guide
  labels it Ruqayya.
- **AE15 / G78** are one Lady Masuma ziyarat: AE15 has the English, G78 the
  34/33/33 takbir instruction, `day`s and all four overlays. Merge, alias
  one to the other.
- **G68**'s title reads as the full ziyarat of Imam Reza; it is a short form.
- **AH5 tab 1** opens with Kazimayn's general entry rites, which belong
  before AH2 (AH2 starts "You may then stop...").
- **AL6 tab 1** is labelled "Entry Permission & Combined Ziyarat" but is
  Imam al-Askari's own ziyarat; **AL1** has a stray "Farewell Ziyarat"
  heading on line 2.
- **AJ2**'s title names Hudhayfah, Tahir and "Abdullah ibn Jabir" (likely
  Jabir ibn Abd Allah) but its text is Salman's alone; **G63** is a 10-line
  excerpt of AJ2 and gives Salman "(a.s.)" where AJ2 has "(r.a.)".
- Overlaps the guide resolved by linking the shrine entry: G69/G70/G71
  inside AH5 tab 1 / AL5 tab 1 / AL6 tab 1, G67 partly AH2, G72 partly
  G5/AL11 tab 3.
- **AG14** ends with leftover stub lines ("Other Ziarat inside shrine
  complex", "[Hz.Habib Ibn Mazahir](G58)", "Ibrahim Mujab...", "Katalgah...",
  "Mueseum - First floor"). Scaffolding also in AK6 ("Salat -Dua after
  Ziarat..."), AK7 ("Ziarat Imam Hussain(as) from..."), AI5 ("Alt :"), AI15
  tabs ("ENTRANCE", "Hz.Khizr", "Ambiya and Saleheen").
- **AK8** is G2 (89%) with a bare link as its first line; **AK13** repeats
  AK5's seventh tab; **G7** and **G57** share a title, G7 ~66% inside AG18;
  G6 ~62% inside AG14; G55/G56 repeat Ziyarat Warith's Ali al-Akbar and
  martyrs parts.
- **H17** doesn't say it is Imam Ali's munajat in Masjid al-Kufa (the guide
  labels it); **G51** gives no source.
- Fixed in session 1, in `holy_sites.dart` (the compass): Imam Ali's shrine
  was 3.7 km north of the tomb, Masjid al-Sahla 4.6 km off, Jamkaran 3.5 km
  east, Hazrat Abbas, Lady Zainab and Lady Ruqayya 90-180 m off.

## Unverified, left out of phase 1

- Tombs of Uthman ibn Sa'id, Husayn ibn Ruh and Ali al-Samarri (no
  coordinates; mentioned in Baghdad's text), Ali ibn Babawayh in Qom, Hujr
  ibn Adi at Adra (shrine desecrated 2013), Ghadir Khumm/al-Juhfa, Hilla/
  al-Kifl, Nishapur.
- OSM-only coordinates: the Sardab (Samarra), Balad. Masjid Zayd has none:
  it shares Masjid Sa'sa'ah's site. The Maqam of Imam al-Mahdi in Wadi
  al-Salam is in the text only (no coordinates). Awn ibn Abdullah's shrine
  left out (who lies there is disputed).
- Najaf's room positions near Bab al-Qibla (Ansari, Nuri, Qummi) rest on a
  single weak source (a duas.org PDF chapter of an AI-written book): check
  them. WikiShia was down all session, so its URLs in `sources` were seen
  only as search snippets.
- Death years where sources disagree (Shaykh Baha'i 1030/1031) or are not
  established are omitted.

## Status and resume here

(Updated at the end of every session.)

**Session 1 (2026-11-07): phase 1 done.**

- Infrastructure: model, repository, the three pages,
  `ziyaratGuideMenuItem` (admin-only, after Ziyarats), ARB keys in all five
  languages, `QiblaFinder(initialTarget:)`, `mapsUriFor`, tests
  (`ziyarat_guide_test.dart`, `maps_links_test.dart`, guide screens in
  `ui/page_render_test.dart`), analytics events in `docs/analytics.md`.
- Content: 52 places in 16 cities - Madinah, Makkah; Najaf, Kufa, Karbala,
  Musayyib, Kazimayn, Baghdad, Samarra, Balad, Mada'in; Mashhad, Qom, Rey,
  Shiraz; Damascus. Researched by one opus agent per region, with sources
  per site. Full suite passed (2116 tests).
- The audit, the missing-ziyarat list and the corpus problems are above.

**Session 2 (2026-11-08):**

- Step 1 done: the owner's corpus decisions are applied (see "Corpus
  problems found" for what each became and what is still open). The owner
  has not yet reviewed the guide's facts on a device.
- Shrine plans (the owner asked for maps a pilgrim can tap: "click on a
  gate or a shrine ... and that opens the respective ziyarat"): built,
  with 10 plans over Iraq, Iran, Syria and Madinah - see "Shrine plans",
  including what the owner should confirm before shipping.

**Next:**

1. The owner tries the plans on a device as an admin (pinch, tap a gate
   or tomb, open its ziyarat, "show where I am") and answers "For the
   owner to confirm before shipping" under "Shrine plans".
2. Phase 3, restore missing ziyarats, biggest first: Imam Reza (AE3-AE8),
   the Baqi Imams (AP8, AP9, AP11), Fatimah bint Asad (AQ1), the Four
   Deputies (AM3), Abd al-Azim (AE17) - Uhud (AQ2) and Lady Khadijah (AQ5) are done. Follow
   `scripts/RESTORING_MISSING_ZIKRS.md`'s per-batch workflow and check each
   with `source_check.py`; then link each new uid from its site in
   `assets/ziyarat_guide.json` (the test checks the links), and from the
   plan feature it is recited at (a zarih, a tomb).
3. Phase 4, translations: one opus/high agent per language (ur, fa, ar,
   gu) writes `assets/ziyarat_guide_i18n/<code>.json` for every key the
   test's `sourceKeys()` lists (names, about, tips, notes, labels, and the
   plans' `plan.<id>.<feature>.*` keys), using the wording the app's ARB
   files and zikr titles already use.
4. Phase 5: point the Ziyarats list's `G0~B` row at the guide, ungate
   `ziyaratGuideMenuItem` (move it into `homeMenuItems` after Ziyarats,
   update `test/widget_test.dart`), What's New note, ship.

Re-running a region's content: the agents' brief is below; they write
`{"regions": [...]}` fragments that merge into the asset (Iraq's cities in
pilgrim order: najaf, kufa, karbala, musayyib, kazimayn, baghdad, samarra,
balad, madain).

**Content brief for agents** (what session 1 used): read this doc and
`CLAUDE.md`; research each site on the shrines' own sites, al-islam.org,
duas.org, wikishia.net, Mafatih al-Jinan; verify each burial and
coordinate on two sources; link only live zikr uids whose text is for that
place (open the file first; `tab` from 1 + `label`); write
`{"regions": [...]}` for the region only; report the ziyarats the corpus
lacks (with a uid from `scripts/unfavorited_missing_zikrs.json` when one
matches) and anything unverifiable left out.
