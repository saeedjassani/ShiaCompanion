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

- Locations for the owner to confirm (Esri-read and typed `location`s,
  Najaf's Bab Muslim ibn Aqil and Sahn Fatimah): `docs/ZIYARAT_GUIDE_REVIEW.md`,
  section "Shrine plans: locations".
- Al-Baqi's other graves (Fatimah bint Asad, Umm al-Banin, the aunts,
  Ibrahim...) stay off the plan: no current plan of the cemetery places
  them, and the one old description (Ibn Battuta's, quoted on duas.org)
  goes by a gate that has since moved. They are `buried` entries of
  `jannat_al_baqi`, each noting that its exact spot is not marked today.

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

Transliteration of all of these is `translit.py` output read line by
line, not native-checked. Instruction lines and tab labels are new English.
Restored: AE3 Imam Reza (duas.org's Sahifa Radawiyya, Mafatih's izn,
al-Jawadiyya from Bihar 102), AP8 al-Baqi and AP2's farewell (history
checked against duas.org's ziaratbaqi.htm), AQ2 Uhud, AQ5 Lady Khadijah
(new uid; duas.org checked against alkafeel's post of Kashif al-Ghita's
Murshid al-Anam), AM3 Four Deputies (duas.org's Tahdhib text, resolved to
mafatih.duas.co) and AE17 Abd al-Azim (matches mafatih.duas.co line for
line; AE16, the biography, retired into its merits). Review items:
`docs/ZIYARAT_GUIDE_REVIEW.md`, sections "AE3 Imam Reza, AE6 and G68
(session 3)", "AP8 al-Baqi and AP2", "AQ2 Uhud", "AQ5 Lady Khadijah", "AM3
Four Deputies" and "AE17 Abd al-Azim".

## Restored in session 6: for the owner to review

Each agent's source disagreements and choices are in its commit message.
Restored: AK4 (rites on the way to Najaf), AK17 (the Prophet's birthday),
AK19 (the Mab'ath, Mafatih's third form), AK7 tab 2 (Masjid al-Hannanah,
history's Arabic and English), G60 Muslim ibn Aqil and G61 Hani (Kufa)
completed. `translit.py` errors the agents fixed by hand (the tool still
makes them): WA glued or split wrongly (WAQUTILTA, WA A'DAKUM for
وَعَدَكُمْ, WA FAA for وَفٰى, WA QAFT), BI-SAL for بِئْسَ, AN-NAASIHOO,
final ح read as the pronoun (FAATIHEE). Review items:
`docs/ZIYARAT_GUIDE_REVIEW.md`, sections "AK4 rites on the way to Najaf",
"AK17 the Prophet's birthday", "AK19 the Mab'ath" and "AK7 tab 2, G60 and
G61".

## Restored in session 7: for the owner to review

The Mada'in batch, checked against our history (Ansariyan's English) and
mafatih.duas.co's three Mada'in pages (`ziarat-salman-farsi`,
`eewan-kisra-visit`, `ziarat-huzaifa-yamani`); duas.org's data store has
no Mada'in page. Details are in commits `d53fa6cd` and `6ea6745c`.
Restored: AJ3 (prayer at Taq Kasra, new: the prayer, Ad-Dukhan 44:25-29
and Imam Ali's words); AJ2 (Salman) with AJ1 and AJ4 retired into its
merits and Mafatih's closing line added (segment 73, "Then supplicate
Allah at length before you leave."; "bid farewell farewell" fixed). Review
items: `docs/ZIYARAT_GUIDE_REVIEW.md`, section "AJ3 Prayer at Taq Kasra and
AJ2 Salman (session 7)".

## Restored in session 8: for the owner to review

The Samarra batch, checked against our history (Ansariyan) and
mafatih.duas.co's Samarra pages (`ziarat-bibi-narjis`,
`ziarat-bibi-hakima`, `ziarat-imam-naqi`, `ziarat-syed-hussain-merits`);
duas.org's data store has no Samarra page. Details are in commits
`4f5b2430` (AL8), `ccc130b0` (AL9) and `974218ed` (the rest).
Transliteration is `translit.py` output read line by line. Restored: AL8
(Lady Narjis), AL9 (Lady Hakimah, Lady Masuma's G78 text with her names,
as Mafatih records none of her own), AL5's permission to enter (AL4)
with the fatha on the names, and AL1's and AL11's new merits. `translit.py`
errors fixed by hand (the tool still makes them): ATAWAJJAHOO for
«اَتَوَجَّهُ», WAZIYAARATIHAA; `batch.py plan` vowelled the hamzat al-wasl
of «اتَّكَلْتُ»; `silah.py` skips «وَاٰلِهٖ» and a hā ending the last
line. Review items: `docs/ZIYARAT_GUIDE_REVIEW.md`, sections "AL8 Lady
Narjis", "AL9 Lady Hakimah", "AL5, AL1, AL11" (session 8) and "G78 Lady
Masuma".

## Restored in session 9: for the owner to review

The Kazimayn batch, checked against our history (Ansariyan's
`assets/items/AH1`, `AH2`, `AH3`, `AH11`), mafatih.duas.co's Kazimayn
pages (`ziarat-imam-kazim`, `ziarat-imam-kazim-2`, `ziarat-kazmain-merits`,
`ali-baghdadi-story`) and duas.org's `ziyarat-of-imam-musa-al-kazim`.
Details are in the commit "AH2: Ibn Tawus's ziyarat completed; AH3
(al-Mufid's) replaces the duplicate tab". AH2 tab 1 is now Ibn Tawus's
ziyarat with its lost opening restored, tab 2 is AH3 (al-Mufid's); AH9's
merits condense AH1 and AH11. The rebase dropped the stale labels (old 0
and 101) and the duplicate's prayer line in all four languages, and the
Persian of the duplicate's verses, except seven that recur in al-Mufid's
form (148, 153-155, 165-167). Review items:
`docs/ZIYARAT_GUIDE_REVIEW.md`, sections "AH2 Kazimayn (session 9)", "AH9
Kazimayn merits (session 9)" and "Translations" (the Gujarati read).

## Restored in session 10: for the owner to review

The Karbala batch, checked against our history (Ansariyan's
`assets/items/AG15`, `AG20`, `AG21`, `G31`, `B5`), mafatih.duas.co's
`additions-ziarat-warisa`, `ziarat-imam-hussain-times`, `khake-shifa`,
`izn-dukhool-common` and `ziarat-imams-wida` (in its Mulhiqat list), and
duas.org's `izn-e-dukhool`. Details are in the commits "AG21: restore the
soil of Imam Husayn (a.s.)", "G31: restore the farewell to the Holy Imams
(a.s.)" and "B6: Kaf'ami's permission to enter (B5) as the first tab".
Restored: AG14's merits gain AG15's tail; AG1 gains AG20 (merits and the
greeting from far away); AG21 (the soil of Imam Husayn, four parts); G31
(the farewell for any Imam's shrine, in the guide's general list); B6 is
now both forms of permission to enter, Kaf'ami's (B5) as tab 1 and
al-Majlisi's as tab 2; AP2's izn line links B6 once. Review items:
`docs/ZIYARAT_GUIDE_REVIEW.md`, section "AG14, AG1, AG21, G31 (Karbala,
session 10)" and "B6 permission to enter (session 10)".

## Restored in session 12: for the owner to review

The Baghdad batch, checked against our history (Ansariyan's
`assets/items/AM1`, `AM4`) and mafatih.duas.co's `masjid-burasa` and
`ziarat-nawab-arba`; duas.org's data store has neither. Details are in
the commit "Baghdad batch: restore AM1 (Masjid Buratha); AM4 retires
into AM3". AM1 (Masjid Buratha) was restored, then dropped on the owner's
word (2026-11-23), retired with no redirect (its draft is in commit
49996fe8); AM4 (al-Kulayni) is now the last paragraph of AM3's merits,
and al-Kulayni's tomb links AM3 after G29. Review items:
`docs/ZIYARAT_GUIDE_REVIEW.md`, sections "AM3 Four Deputies" and "Baghdad
(session 12)".

### Madinah (session 12)

Checked against our history (Ansariyan's `assets/items/AP1`-`AP14`) and
mafatih.duas.co's Madinah pages (`ziaraat-madina-intro`,
`ziarat-bibi-fatima`, `ziarat-rasoolullah-distance`,
`ziarat-rasoolullah-juma`, `salawat-rasool-by-imam-ali`, `madina-masajid`,
`wazaef-zawaar-madina`), one opus agent per entry in its own worktree.
Details are in the commits "AP1 and AP3 retire into...", "Madinah batch:
AP12..." and "Madinah batch: AP5...". Restored: AP5 (the Prophet from a
distance, al-Majlisi's ziyarat from Zad al-Ma'ad, with AP6 and AP7 as its
tabs), AP12 (the acts in Madinah and its mosques, AP14 its main part, the
mosques its tabs), AP1 and AP3 (prose) into the merits of AP2, AP4 and AP8;
AP10 (al-Uzri's qasida) dropped on the owner's word, no redirect.
Review items: `docs/ZIYARAT_GUIDE_REVIEW.md`, section "AP5, AP12, AP1, AP3,
AP10 Madinah (session 12)".

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
- **Iran, other: done (session 15)** - AE17 (Abd al-Azim, session 3,
  AE16's biography in its merits); AE14 (Lady Masuma's shrine and
  merits, prose: there is no farewell to her in Mafatih) and G28 (the
  introduction to visiting the Imams' descendants, prose leading into
  Lady Masuma) are G78's merits; AE18 (Imamzadeh Hamzah) closes AE17's
  merits, and Abd al-Azim's shrine links AE17 as his ziyarat too. Still
  prose in history, all Mashhad and all on mafatih.duas.co's `mashhad`
  list: AE2 (merits and how to visit, `ziarat-imam-reza-merits`), AE9
  (requests granted at the tomb), AE10 (the journey to Khurasan,
  `imam-reza-khorasan-journey`), AE11 (a king's visit,
  `shah-abbas-mashhad-visit`), AE12 (miracles, `imam-reza-miracles`),
  AE13 (al-Jami's verses) and AE1 (Safi the servant's story, with
  Arabic) - candidates for AE3's merits. Shiraz's shrines (Shah Cheragh,
  Alaeddin Husayn) link nothing: Mafatih has no ziyarat for them.
- **Madinah: done (session 12)** but for the graves without uids -
  AP5 (from a distance, AP6 and AP7 its tabs), AP12 (the acts and the
  mosques, AP14 its main part), AP1/AP3 in the merits of AP2, AP4 and
  AP8, AP10 dropped. Still without a uid, all on
  https://www.duas.org/mobile/madina-mecca-rites.html: Abbas ibn Abd al-Muttalib, Aqil and Abdullah ibn
  Ja'far, the Prophet's wives, daughters and aunts, Isma'il ibn Ja'far,
  Halimah (duas.org's ziaratbaqi.htm has texts for the first three).
  Restored: al-Baqi as AP8's tabs (the four Imams, their farewell,
  Ibrahim, Fatimah bint Asad; AP9/AP11/AQ1 redirect there), the farewell
  to the Prophet as AP2's second tab (AP13 redirects there), and Hamzah
  and the martyrs of Uhud as AQ2 (AQ3/AQ4 retired into it).
- **Makkah: done (session 14)** - Abd Manaf (AQ6) and Qasim, son of the
  Prophet (AQ7), new uids as AQ5 (Lady Khadijah) was, linked from Jannat
  al-Mu'alla after G80. Review items: `docs/ZIYARAT_GUIDE_REVIEW.md`,
  "AQ6 Abd Manaf and AQ7 Qasim (session 14)". Not in the corpus, on the
  same duas.org page and al7ajj.wordpress.com's `aadab-ziyarat-makka`: the
  ziyarat of Isma'il, his mother and the prophets at the Hijr Isma'il (the
  guide's `ismail_and_hajar` at Masjid al-Haram links nothing), Lady
  Aminah's (buried at al-Abwa', not Makkah) and the martyrs of Fakhkh
  (al7ajj: with Isma'il ibn al-Sadiq's ziyarat).
- **Baghdad: done (session 12)** - the Four Deputies AM3 (session 3, AM2
  retired into it, linked from Muhammad ibn Uthman's tomb); AM4
  (al-Kulayni) is the end of AM3's merits; AM1 (Masjid Buratha, prose
  with nothing to recite) was dropped, the guide's page covers it. Not in the corpus:
  Allamah al-Majlisi's own ziyarat of Uthman ibn Sa'id (Bihar al-Anwar
  102:292 - duas.org's mobile page has its English but its Arabic lacks
  the first seven salutations, so it was left out).
- **Kazimayn: done (session 9)** - AH3 (al-Mufid's ziyarat of Imam
  al-Kazim) is AH2's second tab, in place of a duplicate of its first,
  and AH2's first tab (Ibn Tawus's, not al-Mufid's as it was labelled)
  gets back the opening the import lost; AH1 (the merits of visiting the
  two Imams) and AH11 (the story of Hajj Ali al-Baghdadi) are AH9's
  merits. The shrine lists Ziyarat Aminullah (G2) and Ziyarat Warith (G6)
  from the story. Not done: Imam al-Jawad's other forms on
  mafatih.duas.co (`ziarat-imam-taqi-2` to `-4`) against AH5's tabs, and
  the shared forms and farewell (`ziarat-kazmain-common`,
  `ziarat-kazmain-wida`) against AH9.
- **Samarra: done (session 8)** - AL8 (Lady Narjis) and AL9 (Lady
  Hakimah, Lady Masuma's ziyarat with her names) restored and linked at
  the shrine and its zarih; AL4 was AL5's opening (its permission to
  enter) and redirects there; AL2, AL3 and AL10 (the house and its
  mosque, which forms to recite, Sayyid Husayn son of Imam al-Naqi) are
  AL1's merits; AL16 (Ibn Tawus's Sardab appendix) is AL11's merits, and
  the Sardab now lists Dua Nudba (E34) and the dua on leaving (E12).
  Not in the corpus: mafatih.duas.co's `ziarat-samara-wida` (compare
  with AL7's farewell), the Sardab etiquette page
  (`samara-basement-adaab`), Sayyid Muhammad's merits page (Balad).
- **Mada'in: done (session 7)** - AJ3 (the prayer at Taq Kasra, linked
  from its site); AJ1 (Salman's merits) and AJ4 (Hudhayfah, the mosque of
  al-Mada'in) are AJ2's merits now and redirect there. Mafatih has no
  text for Hudhayfah's tomb; not in the corpus: the Arabic of the poem
  and Khaqani's Persian verses in the Taq Kasra narration (not recited).
- **Najaf: restored (session 6)** - AK4 (the rites on the way and the
  permission at the door of the dome; the shrine and its gates link it
  instead of B6), AK17 (the Prophet's birthday), AK19 (the Mab'ath), and
  the dua of Masjid al-Hannanah as AK7's second tab. Not in the corpus,
  seen on mafatih.duas.co's Najaf list and duas.org: the ziyarat of
  Prophets Hud and Salih (duas.org `ziyarat-hud-saleh`; the guide's
  `hud_salih_tomb` links nothing), the Mafatih's farewell remarks
  (`ziarat-najaf-wida`, AK15 may cover it) and al-Uzri's qasida verses at
  the sight of the dome (AK4's merits mention them, without the verses).
- **Kufa: done (session 6)** - G60 (Muslim) and G61 (Hani) now carry
  Mafatih's full texts (AI13/AI14 retired into them); AI17 was AI16's
  merits word for word (retired). Not in the corpus: Maytham al-Tammar's
  ziyarat (duas.org `ziyarat-maitham-al-tammar`; the guide's
  `maytham_al_tammar_tomb` links nothing).
- **Karbala: done (session 10)** - AG21 (the soil of Imam Husayn) and
  G31 (the farewell to the Imams) restored; AG15 is AG14's merits, AG20 is
  AG1's merits and greeting from far away, B5 (Kaf'ami's izn) is B6's
  first tab. Not in the corpus: mafatih.duas.co's `karbala-haram-amaal`
  (the acts in the shrine - compare with AG5 and AG2),
  `modifications-in-hadees` (prose) and `marsiya-ummul-baneen` (Umm
  al-Baneen's elegy, not recited); al-Hurr al-Riyahi, the Mukhayyam and
  Tall al-Zaynabiyya have no ziyarat in the corpus.

## Corpus problems found (owner's review)

**Owner's decisions (2026-11-08), applied in session 2:** G82 retitled
"Ziyarat of Lady Ruqayya (s.a.) of Damascus"; AE15 retired into G78 (G78
took AE15's English and its three tasbih lines); AJ2 retitled "Ziyarat of
Salman al-Farsi (r.a.) — Mada'in" and G63 retired into it; the stub lines
of AG14, AK6, AK7, AI5, AI15 and AL1 removed; AL6 tab 1 relabelled "Ziyarat
of Imam Hasan al-Askari (a.s.)" (the lint's 40-character limit dropped the
"al-"); G68 retitled "Short Ziyarat of Imam Ali al-Reza (a.s.)". The owner
chose to leave AH5's entry rites where they are. What was still open from these, and the session-1 items not decided yet, is in `docs/ZIYARAT_GUIDE_REVIEW.md`, sections "Corpus problems: still open ..." and "Corpus problems: session-1 items not decided yet".

The list as found in session 1 (history; the items not decided yet are
in `docs/ZIYARAT_GUIDE_REVIEW.md`):

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

What phase 1 left out as unverified (tombs without coordinates, OSM-only
coordinates, single-source Najaf burials, disputed death years) is one
item in `docs/ZIYARAT_GUIDE_REVIEW.md`, section "Unverified, left out of
phase 1": add any the owner can confirm.

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
- Urdu: the Jamkaran tahiyyat label is a question for the owner, now in
  `docs/ZIYARAT_GUIDE_REVIEW.md`, section "Translations".

**Session 5 (2026-11-13): merged to master, still admin-only.**

- Session 4 ran out of usage while its agents were restoring the Najaf,
  Kufa and Mada'in ziyarats; none of that work was committed, so those
  batches start from scratch (they are in "Missing ziyarats" below).
- Master merged in (Sahifa Sajjadiya titles in the four `index.json`s, the
  move to `material_ui`: the guide's files import it now and its tests use
  `findTooltip`). Full suite passed; PR #421 merged once CI was green.
- The owner is trying the guide on a device next.

**Session 6 (2026-11-15): Najaf and Kufa batches.**

- Restored, one opus agent per entry in its own worktree, each checked
  against our history, duas.org's data store and mafatih.duas.co (the
  Urdu Mafatih, whose Najaf/Kufa pages list every text): AK4, AK17,
  AK19, AK7's Hannanah tab, and G60/G61 completed. Retired: AK1 -> AK4,
  AK18 -> AK17, AI13 -> G60, AI14 -> G61, AI17 -> AI16. Linked in the
  guide (Imam Ali's shrine, its zarih and gates; Masjid al-Hannanah).
  Review items: "Restored in session 6".
- The session ran out of usage while its translators were working, so
  the entries' translations were not committed (only AK7's rebase and
  the guide keys were).

**Session 7 (2026-11-16): session 6's translations; Mada'in.**

- Titles of AK4, AK17 and AK19 and the instruction lines of AK4, AK17,
  AK19, G60 and G61 (33 segments) translated in all four languages,
  each language then read by an independent reviewer (opus) and its
  fixes applied. Verses and merits are not translated.
- Mada'in batch (phase 3): AJ3 Prayer at Taq Kasra restored; AJ1 and AJ4
  retired into AJ2's merits, AJ2 gains Mafatih's closing line; Taq
  Kasra links AJ3 and the Mada'in tips were corrected. Review items:
  "Restored in session 7". Translated in all four languages, each read
  by an independent reviewer: AJ3's title and instruction lines
  (segments 0, 1, 7), AJ2's segment 73, and the four Mada'in guide keys
  (two new, two changed). AJ3's Quran lines carry the app's own Quran
  translations (Urdu's 44:27-28 is one sentence, so 44:28's line shows
  the Arabic alone); the Imam's words (8-10) and the merits are not
  translated (mafatih.duas.co has Urdu for the Imam's words).

**Session 8 (2026-11-19): Samarra batch.**

- Restored, one opus agent per entry in its own worktree: AL8 (Lady
  Narjis) and AL9 (Lady Hakimah). Retired: AL4 -> AL5 (whose permission
  to enter it was; AL5's name endings fixed), AL2, AL3, AL10 -> AL1's
  merits, AL16 -> AL11's merits. Linked in the guide: the ladies at the
  shrine and its zarih (before the farewell), Dua Nudba (E34) and the
  dua on leaving (E12) at the Sardab; the "no ziyarats yet" tip
  rewritten. Overlay keys after the inserted links were shifted (the
  guide's keys are positional).
- Translated in all four languages, each language then read by an
  independent reviewer (opus) and its fixes applied: the titles of AL8
  and AL9, their instruction lines (AL8 0, 39; AL9 0), AL5's new label
  and instruction (0, 1) and 14 guide keys plus the changed tip. Verses
  and merits are not translated. Review items: "Restored in session 8".

**Session 9 (2026-11-19, finished 2026-11-22): Kazimayn batch.**

- AH2 rebuilt by an opus agent in its own worktree: tab 1 is Ibn
  Tawus's ziyarat with its lost opening restored, and tab 2 is now AH3
  (al-Mufid's) in place of a duplicate of tab 1. Retired: AH3 -> AH2
  tab 2, AH1 and AH11 -> AH9's merits (slugAliases keep their slugs).
  Guide: the AH2 labels name Ibn Tawus and al-Mufid (at the shrine and
  on the plan's tomb), and the shrine lists Ziyarat Aminullah (G2) and
  Ziyarat Warith (G6), as in Hajj Ali al-Baghdadi's story. The Arabic
  "أي> سورة" typo in AH2's prayer line was fixed.
- Translated in all four languages, each language then read by an
  independent reviewer (opus) and its fixes applied: AH2's two labels
  and 14 instruction lines (0, 1, 17, 24, 37, 122, 123, 141, 142, 147,
  168, 178, 186, 189, 194, 196) and 8 guide keys (5 new, 3 changed).
  Verses and merits are not translated. Review items: "Restored in
  session 9".
- The session ran out of usage during the reviews, before anything was
  pushed; its work was replayed from the transcript on 2026-11-22 and
  every step reproduced its recorded output.

**Session 10 (2026-11-22): Karbala batch.**

- Started without the repository selected: it could clone master and
  reach mafatih.duas.co, but pushing needed the repo attached (allowed by
  the owner), and Flutter came from running the startup hook by hand.
- Restored, one opus agent per entry in its own worktree: AG21 (the soil
  of Imam Husayn, four parts) and G31 (the farewell to the Imams); B6 is
  now both forms of permission to enter, Kaf'ami's (B5) as tab 1.
  Retired: AG15 -> AG14's merits, AG20 -> AG1 (merits and the greeting
  from far away), B5 -> B6. Linked in the guide: AG1 and AG21 at Imam
  Husayn's shrine (before the farewell, so no key shifted), G31 in the
  general list, and the Sardab's two B6 links on tab 2 (al-Majlisi's).
- The session ran out of usage while its translators were working, so
  nothing of the translations was committed. Review items: "Restored in
  session 10".

**Session 11 (2026-11-23): session 10's write-up and translations.**

- Session 10's doc updates (its review items, status and counts) were
  replayed from its transcript.
- Translated in all four languages, each language then read by an
  independent reviewer (opus) and its fixes applied: the titles of AG21
  and G31, their labels and instruction lines (AG21 0, 1, 9-13, 18, 21,
  22, 24-26, 45, 51, 52; G31 0), B6's new labels and instructions (0, 1,
  13, 20, 24), AG1's 1, AP2's changed 2 (its izn link) and 4 guide keys.
  Verses and merits are not translated.
- The reviewers' questions for the owner (all small): Urdu and Persian
  call the soil تربت where the Urdu Mafatih says خاک شفا; Arabic
  «برواية الشيخ الكفعمي» (he recorded the form rather than narrated it -
  «كما أورده»?) and «تربة قبره (تربة الشفاء)» («التربة الحسينية»?);
  B6.13 keeps (ع) inside the quoted name, as the English does; Gujarati
  spells ઇમામ in the index and guide but ઈમામ in most zikr files (486 to
  188) - one pass to standardise would help.

**Session 12 (2026-11-23): Baghdad batch.**

- AM4 (al-Kulayni) is the last paragraph of AM3's merits and redirects
  there; al-Kulayni's tomb links AM3 after G29 (for al-Samarri, no key
  shifted), its note translated in all four languages and read by an
  independent reviewer each. AM1 (Masjid Buratha) was restored, then
  dropped on the owner's word: nothing to recite, never favorited, no
  redirect. Review items: "Restored in session 12".
- Madinah batch (the owner: "continue with the Madinah batch"), one opus
  agent per entry in its own worktree: AP5 (the Prophet from a distance;
  AP6, AP7 its tabs), AP12 (the acts in Madinah and its mosques; AP14 its
  main part), AP1 and AP3 into the merits of AP2, AP4 and AP8; AP10
  dropped. Linked in the guide: the Prophet's Mosque (AP12 before the
  farewell, AP5 last), Masjid Quba and Masjid al-Fath (AP12's tabs).
  Review items: "Madinah (session 12)".
- Translated in all four languages: AP5's and AP12's titles, labels
  and instruction lines and nine guide notes. The session ran out of
  usage while its reviewers were reading them.

**Session 13 (2026-11-24): session 12's reviews.**

- Each language of the Madinah translations read by an independent
  reviewer (opus) and its fixes applied (wording only, no link or
  meaning changes). Verses and merits are not translated; the Urdu
  Mafatih has them (`ziarat-rasoolullah-distance`, `-juma`,
  `madina-masajid`, `salawat-rasool-by-imam-ali`).
- The reviewers' questions for the owner: Persian AP12 25 says مسجد
  ردّالشمس where the guide says مسجد شمس for Masjid al-Fadikh; Gujarati
  spells Mubahalah three ways (મુબાહેલા in AP12 27, મુબાહિલા, and AC21's
  મુબાહલા), and AP5 257's "desert" is ખુલ્લા મેદાન (some books: સહરા).
- `zikr_i18n.py check <code>` fails in all four languages on
  `unknown reciter 'Shahriar Parhizkar'` (PR #450's Quran reciter in each
  `index.json`): the check knows only `zikr_audio.json`'s reciters. Not
  from this batch.

**Session 14 (2026-11-26): the review checklist; Makkah batch.**

- `docs/ZIYARAT_GUIDE_REVIEW.md` is now the one list of everything
  waiting on the owner (gathered from the "for the owner to review"
  sections, the open corpus problems, the plan locations and the
  reviewers' questions); those sections here summarise and point to it.
- Makkah batch: AQ6 (Abd Manaf) and AQ7 (Qasim, son of the Prophet),
  from duas.org's `madina-mecca-rites` page checked against
  al7ajj.wordpress.com (Abd Manaf, full) and ar.al-shia.org (Qasim's first
  six salutations, citing al-Golpayegani's Manasik al-Hajj p. 171).
  WikiHaj, hajj.ir and shiaonlinelibrary.com (the Manasik itself) refuse
  a cloud session. Linked from Jannat al-Mu'alla; titles and instruction
  lines translated in all four languages, each read by an independent
  reviewer (opus); verses and merits not translated (no published source).
  The new uids are not on the missing-uid list, so its counts stand.

**Session 15 (2026-11-26): Iran batch.**

- AE14 and G28 (Mafatih's prose on Lady Masuma and on the Imams'
  descendants) retired into G78's merits, with the third narration
  (Sa'd al-Ash'ari) the takbir instruction comes from; AE18 (Imamzadeh
  Hamzah, Abu al-Futuh, al-Saduq) into AE17's merits. Checked against
  history and mafatih.duas.co's `qum-tehran` pages. Abd al-Azim's shrine
  links AE17 a second time as the ziyarat of Imamzadeh Hamzah (appended,
  no key shifts). AE3's farewell opening checked against
  `ziarat-wida-imam-reza`: it is Mafatih's line word for word (noted on
  its review item).
- Translated in all four languages, each read by an independent reviewer
  (opus): the two new guide keys. G78's merits are in Urdu, from the
  Urdu Mafatih (adapted to the English: third person, the AE17 link);
  AE17's new paragraphs and G78's merits in the other languages are not.
  Review items: "Iran (session 15)".

**What's left (start here):**

1. **The owner's device check** (as an admin): the three pages, the ten
   shrine plans (tap a gate or tomb, its card opens the ziyarat), the
   restored entries. Anything found comes first.
2. **Reviews waiting on the owner or a native reader:** all in
   `docs/ZIYARAT_GUIDE_REVIEW.md` (154 items). Apply any the owner has
   answered (ticked or a decision written next to it) before new work.
3. **Translations still missing:** merits and verses of AE3, AP8, AQ2,
   AQ5, AM3, AE17, AK4, AK17, AK19, G60, G61, AJ3 (its Quran lines are
   done; the Imam's words are not), AL8, AL9, AJ2's new merits and
   AM3's al-Kulayni paragraph (and
   AK7's Hannanah dua), the new merits of AL1, AL5, AL11 and AH9, AH2's
   verses (tab 1's new opening, 2-38, and all of tab 2 but Persian's
   seven; mafatih.duas.co's `ziarat-imam-kazim` and `-2` have the Urdu),
   AG21's verses and merits (`khake-shifa` has the Urdu), G31's
   (`ziarat-imams-wida`), B6's Kaf'ami tab (`izn-dukhool-common`), AG1's
   new merits and greeting, AG14's new merits paragraph,
   AQ6's and AQ7's verses and merits (no published Urdu, Persian or
   Gujarati found), G78's merits in fa/ar/gu and AE17's whole merits
   (`ziarat-shah-abdul-azeem` and `ziarat-imamzadah-hamza` have the
   Urdu), and AP2's Arabic lines - mafatih.duas.co's Urdu pages for the session-6
   entries are in "Najaf"/"Kufa" there, AL8's and AL9's are
   `ziarat-bibi-narjis` and `ziarat-bibi-hakima`, and all scrape with
   `scripts/zikr_i18n/web_source.py duasco` (verses need a published
   source, `scripts/zikr_i18n/SOURCES.md`). Any guide key added later
   needs all four (`python3 -I scripts/ziyarat_maps/guide_keys.py check
   <code>`); any entry restored later needs its labels and instructions
   in `assets/zikr_i18n/<code>/`, segment-keyed (`docs/TRANSLATIONS.md`),
   each language read by an independent agent.
4. **Phase 3, the rest of "Missing ziyarats"** (Najaf and Kufa done in
   session 6, but for Hud and Salih and Maytham, which the corpus never
   had; Mada'in in session 7; Samarra in session 8; Kazimayn in session
   9, but for the Kazimayn leftovers in its entry: Imam al-Jawad's other
   forms against AH5, the shared forms and farewell against AH9; Karbala
   in session 10, but for the leftovers in its entry; Baghdad in session
   12; Madinah in session 12, but for the graves without uids; Makkah in
   session 14, but for the Hijr Isma'il; Iran in session 15, but for
   Imam Reza's other forms, which are not in Mafatih): **next is
   Mashhad's prose** (AE1, AE2, AE9-AE13 into AE3's merits, against
   mafatih.duas.co's `mashhad` pages; see "Iran, other"), then the
   leftovers listed in each city's entry under "Missing ziyarats"
   (Najaf's Hud and Salih, Kufa's Maytham, Kazimayn's al-Jawad forms
   and farewell, Samarra's farewell, Karbala's acts in the shrine,
   Makkah's Hijr Isma'il, Madinah's graves without uids, Imam Reza's
   Sahifa Radawiyya forms). One batch per city, each checked
   against an online copy, `source_check.py` baselined, linked from its
   site and plan feature, counts recounted in
   `scripts/RESTORING_MISSING_ZIKRS.md`. Re-run `source_check.py .
   baseline` after the merits and links are final, too: a new link can
   make an older accepted flag stop firing, which also fails
   `test/zikr_source_check_test.dart` (PR #444's first CI run).
5. **Phase 5, ship:** point the Ziyarats list's `G0~B` row at the
   guide, ungate `ziyaratGuideMenuItem` (move it into `homeMenuItems`
   after Ziyarats, update `test/widget_test.dart`), What's New note.

**Before a batch:** sessions 4, 6 and 9 ran out of usage mid-batch and
lost what was not pushed (session 9's was recovered from its
transcript). Commit and push after each step, before long agent runs,
not at the end. A batch needs mafatih.duas.co (the Urdu Mafatih, the
main online check), Flutter (the tests) and push access. Start the
session **with this repository selected**, best in the **"Shia
Companion"** cloud environment: only a selected (or attached) repository
can be pushed, and the startup hook that installs Flutter runs only for
a selected one. Check all three before any work:
- push: `git push` of a scratch branch, or `gh api repos/saeedjassani/ShiaCompanion`;
  a session started without the repo can clone it (it is public) but
  not push, and attaching it later (`add_repo`) was blocked by the
  permission check on 2026-11-22 until the owner allowed it;
- Flutter: `flutter --version`; if missing, run the hook by hand:
  `CLAUDE_CODE_REMOTE=true CLAUDE_PROJECT_DIR=$PWD bash .claude/hooks/session-start.sh`;
- mafatih.duas.co: `curl -s https://mafatih.duas.co/ | head -c 200`
  (refused once in "Default" on 2026-11-22, loaded there later that day).

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
