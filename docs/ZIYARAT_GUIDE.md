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
never by English text (`python3 -I scripts/ziyarat_maps/guide_keys.py`
prints every key with its English; `... check <code>` lists an overlay's
missing and stale keys):

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

**Plans so far (10, 151 features):** `karbala_haramayn` (41: Imam
Husayn, Hazrat Abbas, Bayn al-Haramayn, Tall al-Zaynabiyya, al-Mukhayyam),
`najaf_haram` (11: the five courtyard gates, the tombs of Allamah
al-Hilli and Muqaddas Ardabili, Sahn Fatimah al-Zahra), `kufa_mosque` (17: nine maqams linked to their AI3/AI4/
AI5/AI11 tabs, Muslim, Hani, al-Mukhtar), `sahla_mosque` (3),
`kazimayn_haram` (7), `samarra_haram` (2: the zarih and the Sardab),
`mashhad_haram` (20, mostly courtyards and basts), `qom_haram` (32: 22 of them the
shrine's numbered gates),
`damascus_old_city` (7: Lady Ruqayya, Ras al-Husayn, the Umayyad Mosque's
gates), `madinah_haram` (11: the Prophet's tomb, Rawdah, gates, al-Baqi's
gate and the Imams' graves). Plans use `layers` where OSM tags a dome
without its colour (Samarra, Mashhad, Qom gold; Madinah's Green Dome).

**No plan, and why:** Lady Zainab's shrine and Bab al-Saghir (OSM maps
almost nothing there: someone would have to map them in OSM first);
Jamkaran, Rey, Shiraz, Uhud, Makkah (not attempted yet).

**Owner's answers (2026-11-08, session 3):** the Esri-read locations stay
(accepted); Qom's numbered doors are added as "Gate N" with B6; the rest
of the list below the owner asked Claude to research and verify itself
(session 3's two plan agents - see "Status and resume here" for what
they found). The owner also found Najaf's plan incomplete (no Bab
al-Rida, no Sahn Fatimah al-Zahra, only two scholars) and asked for the
site page's Directions/Compass buttons to move into the app bar and the
map preview to shrink to a row (done).

**As listed for the owner in session 2:**

- `madinah_haram.baqi_imams`, `mashhad_haram.sahn_payambar_azam` and
  `qom_haram.sahn_atiq` have `location`s read off Esri's satellite
  imagery, not OSM; Esri's terms may not allow taking positions from it.
  Confirm or replace (e.g. by mapping them in OSM first). Typed, not from
  OSM, too: `madinah_haram.house_of_fatimah` and
  `damascus_old_city.ras_al_husayn` (from descriptions, a few metres out).
- Al-Baqi's other graves (Fatimah bint Asad, Umm al-Banin, the aunts,
  Ibrahim...) stay off the plan: no current plan of the cemetery places
  them, and the one old description (Ibn Battuta's, quoted on duas.org)
  goes by a gate that has since moved. They are `buried` entries of
  `jannat_al_baqi`, each noting that its exact spot is not marked today.
- Najaf (reworked 2026-11-09 after the owner's device check; see "Najaf:
  what the shrine's own sources say" below): Bab Muslim ibn Aqil is OSM's
  node, 5 m north of Bab al-Sa'a's. The direction is right (the shrine's
  site and its library both put it to the right of Bab al-Sa'a, Wikipedia
  north of it), but the true gap is probably larger, so its marker hides
  under Bab al-Sa'a's until zoomed right in. Sahn Fatimah is OSM's unnamed
  courtyard building west of the shrine (r14118576, tagged name:fa "صحن
  حضرت زهرا" in 2023, reverted only because the name was Persian).

**Checked 2026-11-09** (sites in Iran - razavi.ir, news.razavi.ir,
amfm.ir, WikiShia - and web.archive.org's copies of them refuse a cloud
session; what they say came from search snippets only):

- Qom: the shrine numbers its gates 1-24 itself: a guide (lastsecond.ir)
  puts gates 1-11 on Eram Street, 12-16 on Shabestan Street and 17-24 on
  the Arak side, which is where OSM has them, and the shrine's virtual
  tour (snippet) names gate 24 Bab al-Jawad. OSM has 22 of them (no 16,
  no 20), added as "Gate N" (`arabicName` "درب N") with B6. Their names
  (Bab al-Jawad, Bab al-Karama, Bab al-Kawthar, Bab al-Shifa...) are not
  added: no two sources tie a name to a number (gate 24 is Bab al-Jawad in
  the virtual tour, but another guide calls the entrance of Sahn Jawad
  al-A'imma Bab al-Karama).
- Samarra: the Sardab marker is right. The tiled dome west-north-west of
  the zarih is Masjid al-Sahib, built over the cellar and long used by
  Samarra's Sunni community for Friday prayer (Arabic Wikipedia, العتبة
  العسكرية), which is why OSM tags its polygon as the Great Mosque;
  WikiShia (snippet) puts the Sardab north-west of the tomb, about 15 m
  from the shrine building.
- Kufa: AI3 tab 1 is the text for entering the mosque (stop at the gate,
  enter by Bab al-Fil), so the gates keep it. The mosque's own site
  (masjed-alkufa.com) puts Ibrahim at the seventh column toward the Kinda
  gates, after Imam al-Sadiq (a.s.), where AI3 (Mafatih) says the fourth;
  for Adam (seventh) and Jibra'il (fifth) both agree. The plan follows the
  markers on the ground and says so on Ibrahim's. The mosque's site gives
  at the Station of Nuh, beside Amir al-Mu'minin's minbar, the same
  prayers AI3 tab 7 gives for his Seat, so Nuh's marker keeps tab 7.
- Mashhad: the shrine's English news (snippets) writes Enqelab, Ghadir,
  Kowsar and Quds Courtyard: Kawthar and Qods became Kowsar and Quds.
  Jomhouri Islami, Azadi, Navvab Safavi and Naqqara Khana are unchecked.
  Sahn Hidayat and Sahn Imam Khomeini are not in OSM, so not on the plan
  (one source says the latter is now roofed as Riwaq Imam Khomeini, which
  OSM has south of the tomb; another puts that riwaq north-west). Shaykh
  Baha'i's tomb "opening off Sahn Azadi" was dropped: sources disagree.
- Missing but not added (no OSM feature, or no second source): in Qom the
  tombs of Allamah Tabatabai, Ayatollah Bahjat and Shaykh Abd al-Karim
  Ha'iri (OSM has Borujerdi's only) and Ali ibn Babawayh (an OSM "ruins"
  node); in Mashhad Shaykh Baha'i's and al-Hurr al-Amili's tombs, the
  Steel Window and the Saqqakhana; in Samarra the shrine's gates (OSM names
  none); in Kufa Safinat Nuh and Dar al-Imara (OSM has both) and Maqam
  al-Khizr as a marker of its own; in Madinah Bayt al-Ahzan.

**To grow a plan**, or add one: fetch, print candidates with
`--candidates`, pick and name the features (verify names on the shrine's
own site), link their ziyarats, build, run the two tests, and look at it
with `flutter test scripts/ziyarat_maps/plan_shots_test.dart
--dart-define=SITE=<site> --dart-define=OUT=<dir>
[--dart-define=FEATURES=<ids>]` (PNGs with real fonts). Missing tombs
inside the shrines (Shaykh Baha'i, al-Hurr al-Amili, al-Mufid, Ibn
Qulawayh, Khoei...) need OSM to map them, or two agreeing sources.

### Najaf: what the shrine's own sources say

Checked 2026-11-09 against the shrine's site (imamali.net ?id=8604, the
gates; en.imamali.net, the courtyard, Sahn Fatimah and the deceased) and a
description by its library, Maktabat al-Rawda al-Haydariyya (almohsinlibrary
PDF SerEAli1497):

- **Five courtyard gates**: Bab al-Sa'a (east, the largest; renamed Bab
  al-Imam al-Reza when it reopened in 2023 - imamali.net and an almerja.com
  report of the reopening; there is no separate Bab al-Reza), Bab Muslim
  ibn Aqil (beside it, to its right/north; once Bab al-Abayjiyya), Bab
  al-Tusi (north), Bab al-Qibla (south, the smallest main gate), Bab
  al-Faraj (west; also al-Bab al-Sultani, Bab al-Amara; faces Sahn
  Fatimah). No gates of Sahn Fatimah are named anywhere found.
- **Great iwans of the courtyard**: Yazdi Iwan (north, the old Safavid
  Tusi gate), Hububi Iwan (south, the old qibla gate), Bab al-Sa'a Iwan
  (east). In gate notes, not markers: each is beside its gate.
- **Doors of the haram**: the Golden Door in the Golden Iwan; Bab
  al-Murad, the riwaq's south door, facing Bab al-Qibla; a north door
  facing Bab al-Tusi. Not on the plan: OSM has no door nodes and their
  exact place along the haram's walls is not given.
- **Sahn Fatimah al-Zahra**: west of the shrine, between the Abu Talib
  riwaq and the Maqam of Imam Zayn al-Abidin (en.imamali.net, Shafaq News),
  about 61,000 m2 with halls below ground.
- **Tombs placed**: Allamah al-Hilli in the room on the north side of the
  Golden Iwan by the northern minaret, Muqaddas Ardabili in the room
  opposite (south side) - the library's description, a 2021 shrine news
  item on al-Hilli's tomb by the northern minaret, a Babylon University
  paper. Shaykh al-Ansari's room (No. 11 on the shrine's site) adjoins Bab
  al-Qibla (areq.net, alkafeel forum citing a biography, WikiShia) but its
  side of the gate is not given, so he is in `buried` only.

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

## Restored in session 3: for the owner to review

Transliteration of all of these is `translit.py` output read line by line,
not native-checked. Instruction lines and tab labels are new English.

- **AE3 Imam Reza.** Tab 1 (izn) is duas.org's (Sahifa Radawiyya),
  Mafatih's general izn with his name; its ending «فَاَنْتَ اَهْلٌ لَهٗ» may
  read «لِذٰلِكَ» in Mafatih - check. Tab 4 (al-Jawadiyya) rests on
  duas.org alone (Bihar 102); six vowel slips fixed from grammar, «اِمَامَ
  قَصِيْبٍ» left as is, bracketed alternates dropped (two named in
  merits), nine English lines written fresh. Tab 6's first line ("May
  Allah not make this my last greeting to you.") was written fresh: the
  Prophet's farewell it opens with is now AP2 tab 2 - compare. AE6's
  salawat (tab 5) also sits in G68 («تامة»/«نامية»). Three translators
  (session 4) found its instruction "pray the two-unit prayer of the
  ziyarat, glorify Allah, and offer them as a gift" vague: if the source
  means the Tasbih of Lady Fatimah (s.a.), say so (and link it); the four
  translations say only "glorify".
- **AP8 al-Baqi / AP2.** History checked against duas.org's
  ziaratbaqi.htm; three small fixes (AP13 «السَّلَامَ», AQ1 and AP8 stray
  marks). AP13's "to send blessings upon you" for «وَاَقْرَاُ عَلَيْكَ
  السَّلَامَ» kept from the source (it means "greet you with peace").
  Fatimah bint Asad's variants «الْمَرْضِيَّةُ» and «مُؤْثِرَةً هَوَاهُ»
  not carried over. `silah.py` skips words ending in «اله» (fixed
  «حَلَالَهُ» by hand). Not added: ziaratbaqi.htm's ziyarats of the
  Prophet's wives, daughters, Aqil and Abdullah ibn Ja'far.
- **AQ2 Uhud.** Two phrases added from duas.org that our history lacked
  («اِلَى اللّٰهِ عَزَّ وَجَلَّ بِزِيَارَتِكَ وَمُتَقَرِّبًا», «وَسَخَطِكَ
  وَمَقْتِكَ»); al-Qadr placed after the martyrs (Mafatih), not after
  Hamzah's dua (duas.org). `day` 15 Shawwal.
- **AQ5 Lady Khadijah** (new uid; AQ was history's Makkah series). From
  duas.org checked against alkafeel's post of Kashif al-Ghita's Murshid
  al-Anam; the first four salutations are alkafeel's alone, with fresh
  English; readings «وَمَلِكَةَ الْبَطْحَاۤءِ», «الْعِقْيَانِ», «وَاَنَّ
  اللّٰهَ» kept from duas.org; «الْمُزَوَّجَةِ» may want a fatha. A shorter
  form by Muhsin al-Amin (alkafeel node/1005886) is a possible second tab.
  `day` 10 Ramadan. Its four `index.json` titles need a native check.
- **AM3 Four Deputies.** The 15 opening salutations' Arabic is duas.org's
  (Tahdhib); two-reading brackets resolved to mafatih.duas.co's text;
  the greeting "O (name) son of (name)" and instructions are new English.
- **AE17 Abd al-Azim.** Matches mafatih.duas.co line for line; English
  edits: «السلام على العبد الصالح» as "Peace be upon the righteous
  servant", a clause with no Arabic («وبه راض») dropped. AE16 (biography)
  retired into its merits.

## Missing ziyarats (phase 3 work list)

Found while writing phase 1's content. Uids are from
`scripts/unfavorited_missing_zikrs.json` (their old text is in git history,
see `scripts/RESTORING_MISSING_ZIKRS.md`); URLs hold a text to check against.

- **Imam Reza: restored** as AE3 "Ziyarat of Imam Ali al-Reza (a.s.) —
  Mashhad (All Forms)", six tabs: permission to enter, the first ziyarat,
  the dua after its prayer, al-Jawadiyya, Ibn Qulawayh's and al-Mufid's
  forms, the farewell (AE4-AE8 redirect to their tabs). Still missing: the
  "Seven Hadith" ziyarat and the other forms of duas.org's Sahifa Radawiyya
  page (not in Mafatih); Imam al-Zaman's ziyarat at his shrine (its only
  source is Sahifa-e-Mahdiyya, p. 610; G76 tab 2 has a short form); the
  farewell tab's first line was written fresh because AP13 was missing
  then; it is now AP2's second tab, so that line can be checked against it.
- **Iran, other:** (Abd al-Azim al-Hasani AE17 is restored, with AE16's
  biography in its merits, and linked); farewell to Lady Masuma (AE14 was prose only); descendants of the Imams in
  general G28 (prose only, would serve Rey and Shiraz).
- **Madinah**, all on https://www.duas.org/mobile/madina-mecca-rites.html:
  acts in Madinah's mosques AP12, ziyarat of the Prophet from a distance
  AP5/AP6; no uid: Abbas ibn Abd al-Muttalib, Aqil and Abdullah ibn
  Ja'far, the Prophet's wives, daughters and aunts, Isma'il ibn Ja'far,
  Halimah (duas.org's ziaratbaqi.htm has texts for the first three).
  Restored: al-Baqi as AP8's tabs (the four Imams, their farewell,
  Ibrahim, Fatimah bint Asad; AP9/AP11/AQ1 redirect there), the farewell
  to the Prophet as AP2's second tab (AP13 redirects there), and Hamzah
  and the martyrs of Uhud as AQ2 (AQ3/AQ4 retired into it).
- **Makkah (no uid):** Abd Manaf, Qasim (both on madina-mecca-rites.html).
  Lady Khadijah is restored as AQ5.
- **Baghdad:** (the Four Deputies AM3 is restored, AM2 retired into it,
  and linked from Muhammad ibn Uthman's tomb); Allamah al-Majlisi's own
  ziyarat of Uthman ibn Sa'id (Bihar al-Anwar 102:292 - duas.org's mobile
  page has its English but its Arabic lacks the first seven salutations, so
  it was left out); Masjid Buratha AM1, al-Kulayni AM4.
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

- G82's `day`s: the owner chose 5 Safar (Lady Ruqayya's death as mostly
  marked) *and* kept 10 Safar / 20 Rajab (`events.json`'s Sakina dates,
  as many treat them as one person): `["02-05", "02-10", "07-20"]`.
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
- Najaf: Muhaddith al-Nuri and Shaykh Abbas al-Qummi are said by WikiShia
  alone to be in room 15 / "the third iwan on the right entering from the
  qibla side", so their notes say only "a chamber of the courtyard".
  Mirza al-Na'ini (WikiShia: fifth room south of the bazaar gate),
  al-Hububi (the southern iwan bears his name), Mirza Hasan Ashtiani (the
  shrine's site: Chamber of Abu Talib) and Adud al-Dawla's exact place are
  single-source; left out or kept general. WikiShia was down again
  (2026-11-09), so it was seen only as search snippets.
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
- Plans checked against sources (2026-11-09): Qom's 22 numbered gates
  added; the Sardab, Kufa's maqams and al-Baqi's burials confirmed or
  qualified; two Mashhad spellings changed. See "Checked 2026-11-09".

**Session 3 (2026-11-08/09):**

- The owner's answers applied (see "Shrine plans" and "Corpus problems
  found"); the site page's Directions and Compass are app-bar buttons and
  the plan card is a one-line row.
- Plans: Najaf completed from the shrine's own sources ("Najaf: what the
  shrine's own sources say"; Bab al-Sa'a is also Bab al-Rida, so the gate
  is named "Bab al-Sa'a (Bab al-Rida)"); Qom's 22 numbered gates; the
  Sardab, Kufa, al-Baqi's burials and Mashhad's names checked ("Checked
  2026-11-09").
- Phase 3 done for the listed batches, each checked against online
  copies, as tabbed shrine entries: **AE3** Imam Reza (izn, first
  ziyarat, dua after, al-Jawadiyya, other forms, farewell; AE4-AE8
  retired into it), **AP8** al-Baqi (the four Imams, their farewell,
  Ibrahim, Fatimah bint Asad; AP9/AP11/AQ1), **AP2** gains the Prophet's
  farewell (AP13), **AQ2** Hamzah and the martyrs of Uhud (AQ3/AQ4),
  **AQ5** Lady Khadijah (new uid), **AM3** the Four Deputies (AM2),
  **AE17** Abd al-Azim (AE16). Each is linked from its site and plan
  feature; `source_check` baselined; counts recounted. What the owner
  should review in them: "Restored in session 3: for the owner to
  review". Tab labels, instruction
  lines and new merits of these entries have no ur/fa/ar/gu yet.
- Phase 4 started: one opus agent per language writes
  `assets/ziyarat_guide_i18n/<code>.json` (918 keys);
  `python3 -I scripts/ziyarat_maps/guide_keys.py [check <code>]` dumps the
  keys / checks an overlay.

**Session 4 (2026-11-09):**

- Phase 4's overlays done: all four have every key, and each was read
  in full by an independent reviewer (opus, a fresh agent per language)
  against the English, together with the PR's 39 ARB keys. Their fixes
  are in the "apply the independent ... review" commits; besides wording
  they restored a link every language had dropped (`[his
  ziyarat](AJ2)`), brought the overlays in line with English edits
  (martyred, not died), and found three English slips (the Mukhayyam is
  south-west of the shrine, Bayn al-Haramayn no longer "open", Sukayna's
  tomb "twelfth century CE").
- AP2's farewell tab: its two instruction lines translated and reviewed
  in all four languages (its Arabic lines stay untranslated, as the rest
  of AP2's do: verses need a published source, `scripts/zikr_i18n/SOURCES.md`).
- Tab labels and instruction lines of AE3, AP8, AQ2, AQ5, AM3 and AE17,
  and the ur/fa/ar/gu titles of AM3 and AE17, translated, each language
  then read by an independent reviewer; their merits and verses are not.

**For the owner (translations):**

- Persian: Salman al-Farsi's honorific is (ره) (the owner's call,
  2026-11-09), in the guide and AJ2's Persian title. Urdu keeps (رض) as
  the corpus does.
- Gujarati: Fiddah stays "જનાબે ફિઝ્ઝા" (the owner's call, 2026-11-09).
  Muharram is મોહર્રમ everywhere, as the community's own texts write it
  (the owner: "whichever is widely used"); the app's month names, the
  events overlay and four zikr titles followed.
- Urdu: the Jamkaran tahiyyat label reads `تحیۃ المسجد` while tips say
  `نماز تحیت مسجد`; left as it is.

**Session 5 (2026-11-13): merged to master, still admin-only.**

- Session 4 ran out of usage while its agents were restoring the Najaf,
  Kufa and Mada'in ziyarats; none of that work was committed, so those
  batches start from scratch (they are in "Missing ziyarats" below).
- Master merged in (Sahifa Sajjadiya titles in the four `index.json`s, the
  move to `material_ui`: the guide's files import it now and its tests use
  `findTooltip`). Full suite passed; PR #421 merged once CI was green.
- The owner is trying the guide on a device next.

**What's left (start here):**

1. **The owner's device check** (as an admin): the three pages, the ten
   shrine plans (tap a gate or tomb, its card opens the ziyarat), the
   restored entries. Anything found comes first.
2. **Reviews waiting on the owner or a native reader:**
   - "Restored in session 3: for the owner to review" - every item there:
     AE3's izn ending (لِذٰلِكَ?), al-Jawadiyya resting on duas.org alone,
     the fresh English lines, and the vague "glorify Allah" instruction
     (if the source means the Tasbih of Lady Fatimah (s.a.), say so and
     link it, then fix the four translations); AQ5's four titles, its
     الْمُزَوَّجَةِ fatha and a possible second tab; AP13's "send
     blessings" line; transliteration of all of them (`translit.py`
     output, not native-checked).
   - "Corpus problems found": the "Still open from these" list (G82's
     `day`s, G78's untranslated line and tasbih lines, the Ruqayya
     spellings, G63's variants, heading-like lines in AG14/AI5/AL1) and
     the session-1 items not decided yet (AK8 = G2, AK13 = AK5 tab 7,
     G7/G57/AG18, G6 in AG14, G55/G56, H17's label, G51's source).
   - "Shrine plans": the Esri-read and typed `location`s (confirm or
     replace), Bab Muslim ibn Aqil's position in Najaf, Sahn Fatimah.
   - "Unverified, left out of phase 1": add any the owner can confirm.
   - "For the owner (translations)" above: the Urdu Jamkaran label.
3. **Translations still missing:** merits and verses of AE3, AP8, AQ2,
   AQ5, AM3 and AE17, and AP2's Arabic lines (verses need a published
   source, `scripts/zikr_i18n/SOURCES.md`). Any guide key added later
   needs all four (`python3 -I scripts/ziyarat_maps/guide_keys.py check
   <code>`); any entry restored later needs its labels and instructions
   in `assets/zikr_i18n/<code>/`, segment-keyed (`docs/TRANSLATIONS.md`),
   each language read by an independent agent.
4. **Phase 3, the rest of "Missing ziyarats"**: Najaf (AK17, AK19, the
   First Ziyarat's izn, al-Hannanah), Kufa (AI13/AI14/AI17), Mada'in
   (AJ3, AJ4, AJ1), Samarra (AL8, AL9, AL4, AL10, AL16), Kazimayn (AH3,
   AH1, AH11), Karbala (AG21, AG20, AG15, G31, B5), Baghdad (AM1, AM4),
   Madinah (AP12, AP5/AP6, the graves without uids), Makkah, Iran (Imam
   Reza's other forms, AE14, G28). One batch per city, each checked
   against an online copy, `source_check.py` baselined, linked from its
   site and plan feature, counts recounted in
   `scripts/RESTORING_MISSING_ZIKRS.md`.
5. **Phase 5, ship:** point the Ziyarats list's `G0~B` row at the
   guide, ungate `ziyaratGuideMenuItem` (move it into `homeMenuItems`
   after Ziyarats, update `test/widget_test.dart`), What's New note.

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
