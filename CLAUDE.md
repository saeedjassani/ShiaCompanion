# Project notes for Claude

## TODO / follow-ups

- **Missing-zikr restoration is mid-way.** 137 unfavorited uids are still
  missing from the corpus. Before resuming, read the "Resume here" section at
  the top of `scripts/RESTORING_MISSING_ZIKRS.md`: next batches (taweez and
  funeral rites `I40`-`I126`, then calendar pages, then ziyarat last and
  checked against online sources), the per-batch workflow, and the tools
  `scripts/zikr_arabic/duas_org.py` and `scripts/zikr_arabic/translit.py`.

- **Trim Firestore cost of the synced-data managers.** Zikr bookmarks
  (`lib/services/zikr_bookmarks_manager.dart`, PR #176) copied
  `SavedVersesManager`'s sync pattern, including two avoidable costs:
  - **Migration writes one transaction per item.** `_importDeviceBookmarks`
    (and `SavedVersesManager._importDeviceSavedVerses`) queue each device
    item separately, and `syncPendingOperations` replays them one
    transaction each - a user with 30 old bookmarks costs 30 reads + 30
    writes on first launch. Merge them into the remote doc in a single
    transaction instead (one read + one write), then clear the queue.
  - **Each launch reads the doc twice.** `loadX()` does a `get()` and then
    attaches a snapshot listener whose first server snapshot is billed
    again. Relying on the listener alone would save one read per manager
    per launch - but every synced manager (favorites, qaza, recitation
    tracker, saved verses, bookmarks) does the same, so change them
    together, not one at a time.
  - Related correctness gap, not cost: removals leave no tombstone, so a
    save queued offline on device B resurrects a bookmark (or saved verse)
    removed meanwhile on device A when B reconnects.

- **Add tab support to the `|`-alias mechanism and to deep links.**
  Two related content-reuse tools in the zikr corpus only work at
  whole-entry granularity today:
  - The `zikr.json` alias key convention (`"<uid>|<targetUid>"`, read by
    `UidTitleData.getFirstUId()`/`getId()` in `lib/data/uid_title_data.dart`)
    swaps in a target's *entire* content - there's no way to alias a key to
    one specific `tabs[]` entry of the target.
  - Deep links (`lib/services/deep_link_resolver.dart`) resolve to a zikr's
    top-level content but have no notion of landing on a specific tab
    either.

  Only `lib/data/retired_zikr_redirects.dart`'s `RetiredZikrRedirect`
  (`targetUid` + optional `tabIndex`) supports tab-level targeting, and only
  for retired/removed uids, not for live aliasing or for deep links.

  This gap showed up concretely during a 2026-09-17 full-corpus duplicate
  sweep (see `scripts/RESTORING_MISSING_ZIKRS.md`'s "Full-corpus duplicate
  sweep" section and PR #104):
  - **E50 → I24**: E50's content spans I24's `tabs[2]` *and* `tabs[3]`, but
    `RetiredZikrRedirect` only takes one `tabIndex`, so the redirect can
    only land on tab 2 - tab 3 needs an extra swipe.
  - **AK5/G2, D3/I83, E15/F2/F3**: found to be a named, independently-famous
    dua/ziyarah that's also embedded as *one tab/step* inside a larger
    multi-tab compilation (AK5's "(All Forms)" Najaf ziyarahs, D3's
    ta'qeebaat tabs, F2/F3's full prayer procedures). These can't be
    aliased or retired today without either losing the compilation's other
    tabs or showing irrelevant extra content to someone who wants just the
    one dua - tab-aware aliasing/deep-linking would let these be properly
    cross-referenced instead of living as separate, drift-prone content
    files forever.

- **The alias/canonical slug-collision guard is gone; watch for new
  `-2`-suffixed slugs.** Commit `cce1219` ("Let alias zikr entries reuse
  their canonical slug") taught the slug-index builder that an alias
  (`"<uid>|<targetUid>"`) sharing its canonical's exact title should inherit
  the canonical's slug instead of minting its own colliding one. That logic
  lived in `functions/src/index.ts`'s `buildZikrIndex` Cloud Function, which
  `d74a4e0` ("Remove Firestore as the zikr content source of truth") deleted
  wholesale three days later - the client-side replacement
  (`lib/utils/slug_registry.dart`) has no equivalent, it just reads whatever
  `slug` string is on each `zikr.json` entry.
  Found 14 entries still carrying the exact bug this was meant to prevent
  (alias/canonical pairs whose titles are the same, or differ only in
  punctuation that normalizes away - e.g. `(...)` vs `[...]` - so they'd
  slugify identically anyway) and manually cleaned them up in PR #104:
  **the rule applied was cce1219's original one - an alias reuses its
  canonical's exact slug string when the title is the same, and only gets
  a slug of its own when the title genuinely differs.** No new slug text
  was minted for any of the 14; each old `-2` string was preserved via
  `slugAliases` on the canonical side so no old link breaks. This was a
  one-time manual fix, not a mechanism - if a *new* alias is added later
  sharing its canonical's title without deliberately copying the
  canonical's slug, nothing stops the same `-2` collision from
  reappearing. Either restore the inherit-canonical-slug behavior
  somewhere in the client (e.g. in `setLocalSlugData`/`applySlugLookupMap`
  in `lib/utils/slug_registry.dart`), or make it a habit: same title ->
  copy the canonical's slug verbatim; different title -> give it its own.

- **Name a GPS fix offline from the bundled city list.** The place name on
  the prayer card comes from an online reverse-geocode (bigdatacloud, in
  `initializeLocation` in `lib/constants.dart`). Offline, prayer times are
  still right - they are worked out from the coordinates - but the card
  keeps the last name it had, or says "Your location" on a first run. When
  the lookup can't be reached, fall back to the nearest city in
  `assets/cities.tsv` (`CityRepository`). Caveat: that list only has
  cities of 100,000+ people and capitals, so someone in a small town would
  see the nearest big city's name; their times stay their own.

## Translations

The app is set up for Urdu, Persian, Arabic and Gujarati; see
`docs/TRANSLATIONS.md`. **Never hardcode user-facing English in Dart**: add
it to `lib/l10n/app_en.arb` and read it with `context.l10n.key` (or
`L10n.current.key` where there is no `BuildContext`), then run
`flutter gen-l10n` (`flutter pub get` does it too). The generated
`lib/l10n/app_localizations*.dart` are gitignored - never commit them.
Design/feature PRs touch only `app_en.arb`; translation PRs touch only
`app_<code>.arb`, and new English keys are translated afterwards in a
catch-up PR (see "Keeping translations in step" in `docs/TRANSLATIONS.md`).
Analytics labels, `trackScreen` names, preference keys and `debugPrint` text
stay English literals. Zikr translations are overlays in
`assets/zikr_i18n/<code>/` keyed by the English line they translate - so
editing a zikr's English line orphans its translations (they fall back to
English); `python3 scripts/zikr_i18n/zikr_i18n.py check -v` lists them.

## Zikr title conventions

Titles (`assets/zikr.json` *and* the matching `assets/zikr/<uid>` file's
`title` - keep both in sync) were normalized in one pass on 2026-09-27. New
entries should follow the same house style:

- **Surahs**: `"N: Name Arabic"` using Quran.com's English transliteration
  with a capital `Al-`/`An-`/`Ash-`… prefix (e.g. `2: Al-Baqarah البقرة`,
  `36: Ya-Sin يس`).
- **Title Case**, with honorifics spelled out consistently: `(s.a.w.a.)` for
  the Prophet, `(a.s.)` for Imams/prophets, `(s.a.)` for Lady Fatimah, Lady
  Zainab etc., `(a.t.f.s.)` for Imam al-Mahdi.
- **Most common English spelling, not a letter-by-letter Urdu/Persian
  romanization** - except Ramazan, kept deliberately as the audience's own
  spelling: Muharram, Dhul Qa'dah, Dhul Hijjah, Jumada al-Awwal/al-Akhirah,
  Ashura, Ghadir, Eid al-Adha, Ziyarat (never Ziyaarat/Ziyarah), Ziyarat
  Warith, Aal-e-Yasin, Jamia Kabira, Aminullah,
  Munajat, Istikhara, Taqibaat, Nafilah, Zuhr, Maghrib, Wudu, Aamal, Husayn,
  Muhammad, Musa, Reza, Zayn al-Abidin, Fatimah al-Zahra, Amir al-Mu'minin,
  Hadith al-Kisa, Ayat al-Kursi.
- Named duas drop the Urdu izafat: `Dua Ahad`, `Dua Nudba`, `Ziyarat
  Ashura` (not `Dua-e-…`/`Ziyarat e …`); `Namaz-e-X` keeps its hyphens.
- **Retitling never changes a `slug`.** Slugs keep the old spelling so old
  links resolve, and search (`filterDataSearchResults`'s `slugsFor`) matches
  slugs too, so someone typing the old spelling still finds the entry.
