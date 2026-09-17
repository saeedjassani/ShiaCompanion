# Project notes for Claude

## TODO / follow-ups

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
