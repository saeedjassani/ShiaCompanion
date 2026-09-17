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
