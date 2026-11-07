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
                           Ziyarat (rows opening ZikrPage, optionally a tab),
                           About, Also buried here, Tips for pilgrims
```

- The existing zikr groups (`G0~B` -> `B~AF8` Iraq -> `AF~AK1` Najaf ...)
  stay as they are: favorites, links and search keep working. The guide is
  a second, richer way in that links to the same entries; it never copies
  zikr text.
- Directions open the platform maps app (`geo:` / Apple Maps / Google Maps
  URL) via `url_launcher`; no map SDK, no tiles, works offline-first. An
  in-app map (flutter_map + a tile provider) is a possible later phase and
  needs the owner's call (new dependency, tile usage policy).
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
6. Optional: in-app map, more regions (Egypt, Jordan - Ja'far al-Tayyar,
   Lebanon, Saudi Ghadir/Juhfa), shrine audio/live streams links
   (`lib/data/live_streaming_data.dart`).

## Status and resume here

(Updated at the end of every session.)
