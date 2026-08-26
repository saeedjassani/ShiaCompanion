# Analytics

Two sinks, one call site: `lib/services/analytics_service.dart`.

Everything goes to **Firebase Analytics**, which is where retention, geography
and funnels come for free. The events worth *ranking* also increment counters in
the **Realtime Database**, because GA4 will not slice a custom parameter until it
is registered as a custom dimension, lags a day behind, and thins out older data.
Those counters are what the in-app **Usage Dashboard** reads, and they are live.

## Seeing the numbers

Home grid → **Usage** (admin only; the tile is not built for anyone else).
Ranges: Today / 7 days / 30 days / All time. It shows most-opened zikrs,
features actually used, screens, library books by chapters read, and live
streams.

The tile comes from `adminHomeMenuItems`, kept out of `homeMenuItems` so the
grid every user gets stays a compile-time constant and admin state — which
arrives with the session refresh, not at startup — is read at build time. It
sets `countsAsFeatureUse: false`: the dashboard would otherwise appear in the
ranking it exists to display, and every visit to check the numbers would change
them.

Debug builds are excluded on purpose — developer traffic would skew the ranking.
Flip `AnalyticsService.recordUsageInDebug` to exercise the pipeline locally.

## Events

| Event | Fired from | Parameters |
|---|---|---|
| `screen_view` | `trackScreen()` on 22 pages | `screen_name`, `screen_class` |
| `zikr_view` | `ZikrPage.initState` | `zikr_uid`, `zikr_title`, `source` |
| `zikr_completed` | reader reaches the end *and* dwells | `zikr_uid`, `zikr_title` |
| `select_content` | alongside `zikr_view` | `content_type`, `item_id` |
| `library_view` | `ChapterPage`, book taps | `book_uid`, `book_title`, `chapter_uid` |
| `stream_view` | live streaming taps | `stream_title`, `link` |
| `feature_use` | everywhere below | `feature`, plus per-feature extras |
| `search` | `DataSearch`, once per settled query | `search_term` |

### `feature_use` values

`home_menu_*` (one per home menu item — Qibla, Tasbeeh, Qaza, Calendar, Flights,
Library, Favorites, …), `tasbeeh_session` (+`count`), `qaza_updated`
(+`operation`), `favorite_added` (+`content_type`), `zikr_shared` (+`zikr_uid`),
`azaan_selected` (+`azaan_id`), `rakaat_prayer_completed` (+`total_rakaat`),
`flight_added` / `flight_edited`, `prayer_times_selection_changed`
(+`prayer_times`), `search`, `search_opened`, `zikr_source_*`.

### `source` values

See `ZikrOpenSource`. The ids are database keys, so they never change; the
dashboard label for each is `AnalyticsService._sourceLabels`, because half of
them do not explain themselves.

| Id | What it means |
|---|---|
| `list` | Tapped in a category list |
| `search` | Tapped in the search results |
| `favorites` | Tapped in Favorites |
| `library` | Tapped from a library book |
| `todays_recitation` | Tapped in Today's Recitation |
| `live_streaming` | Declared, currently unused |
| `deep_link` | A URL from **outside** the app — a shared link, opened cold by the web launch route or while running by the home page's deep-link handler |
| `zikr_link` | A link **inside another zikr's own text**, resolved to a local uid by `extractZikrLinkSegment` and pushed by `ZikrPage._handleZikrLinkTap` |
| `admin` | Opened from the admin zikr list |
| `unknown` | Default — an entry point that forgot to pass a source |

The two link sources are worth keeping apart: `deep_link` measures sharing and
`zikr_link` measures cross-references in the corpus. A shared link that lands on
a zikr whose text then links onward produces one of each.

## Why `zikr_view` lives in `ZikrPage`, not in the tap handlers

A zikr is reachable from the category lists, search, favorites, today's
recitation, a shared deep link, and links inside another zikr. Logging at each
tap site meant new entry points silently went uncounted — which is exactly what
had happened to the home grid and to deep links. `ZikrPage.initState` is the one
place every route converges, so the count is complete by construction and
`source` carries the detail that used to be implied by *where* the log lived.

Keys are the **canonical** uid (`uid.split('|').last`), so an alias and its
target are one row rather than two.

## `search_opened` vs `search`

Tapping the search icon counts as `search_opened`; typing something that settles
counts as `search`. They answer different questions — how often people reach for
search at all, against how many searches they actually run — and with
`zikr_source_search` they read as a funnel: opened, searched, opened something.
An opened-but-never-typed search is a real signal on its own, and it is the only
one of the three that a user abandoning the screen still produces.

## Why a search is counted on a debounce, not on submit

`SearchDelegate.buildResults` — the obvious hook, and where `search()` used to
be its only caller — runs only when the query is *submitted*. Nobody submits:
`buildSuggestions` already renders tappable tiles that open the zikr, so the
normal path is type → tap → gone, and `buildResults` never builds. The counter
read one search against every zikr opened with `source: search`.

`DataSearch` now records a search when the query settles (900 ms), and
immediately when the user acts on it — taps a result, submits, or closes the
search. `isNewSearchTerm` keeps one refined query as one search: a term that
extends, or is extended by, the one already recorded does not count again, so
typing "kumayl" with a pause in the middle is one search and switching to
"ashura" is a second.

## Why `zikr_completed` needs a dwell gate

`zikrTabScrollFraction` treats a zikr too short to scroll as fully read the
moment it lays out. Scroll position alone would therefore rank a stray tap on a
two-line dua above a real recitation of Dua Kumayl. Completion additionally
requires time on the page of at least half the estimated reciting duration,
floored at 10 seconds.

## Database layout

```
usage/
  totals/{metric}/{key}          -> int, all time
  daily/{yyyy-MM-dd}/{metric}/{key} -> int
  labels/{metric}/{key}          -> display string
```

`{metric}` is one of `zikr`, `screen`, `feature`, `library`, `stream`. Adding a
metric means adding it to the whitelist in `database.rules.json` too, or the
writes bounce.

Counters are written unauthenticated, because most users are guests and a
signed-out reader is still a reader. The rules bound the damage: writes must be
an increment of exactly one, keys must match `^[A-Za-z0-9_~-]{1,60}$`, the
metric must be whitelisted, and deletions are refused. Only an admin can read.

Every one of those conditions sits in the `.validate` on the **leaf** node, not
spread across the wildcard ancestors it reads more naturally on. `.validate`
does not cascade the way `.read`/`.write` do, and the guarantee that an
ancestor's `.validate` runs for a write aimed at a descendant is not one worth
leaning on for the only publicly writable path in the database — so `$day`,
`$metric` and `$key` are all checked at the node actually being written. The
`"$nested": {".validate": false}` under each leaf closes the matching hole from
the other side: `.write` *does* cascade downward, so without it a client could
write arbitrary structure at `usage/totals/zikr/G1/anything`.

`pruneUsageCounters` (in `functions/src/index.ts`) drops day buckets older than
400 days. All-time totals are never pruned.

### Deploying the rules

`database.rules.json` is the source of truth and is wired into `firebase.json`,
so `firebase deploy` now publishes rules along with everything else. The file
was seeded from the rules that were live in the console on 2026-08-22 and is a
faithful superset of them — `new_favs`, `hadiths` and `favorites` are reproduced
exactly as they were, with only `usage` added.

Deploy rules alone with:

```
firebase deploy --only database --project shia-comapnion
```

**Known issue, deliberately preserved:** `new_favs` carries `".read": true` at
the subtree root, so anyone — signed in or not — can read every user's legacy
favorites. Both code paths that touch it (`_loadLegacyRealtimeFavorites` and
`_deleteLegacyRealtimeFavorites`) are only ever called with the signed-in
`user.uid`, so scoping the read would not break the migration:

```json
"new_favs": {
  "$user_id": {
    ".read": "$user_id === auth.uid",
    ".write": "$user_id === auth.uid"
  }
}
```

It is left as-is here because the analytics change should not quietly alter an
unrelated access rule. `hadiths` and `favorites` are vestigial — nothing in
`lib/` reads or writes either path.

## GA4 setup, one time

Custom parameters do not appear in any GA4 report until they are registered.
Admin → Custom definitions → Create custom dimension, scope **Event**:

| Dimension name | Event parameter |
|---|---|
| Zikr UID | `zikr_uid` |
| Zikr title | `zikr_title` |
| Source | `source` |
| Feature | `feature` |
| Book title | `book_title` |
| Stream title | `stream_title` |
| Menu item | `menu_item` |
| Azaan | `azaan_id` |
| Prayer times shown | `prayer_times` |

The cap is 50 event-scoped dimensions, so there is plenty of headroom.
Registration is **not** retroactive — data only appears from the day you create
each dimension, which is the argument for doing it before the next release
rather than after.

`screen_name` needs no registration: `logScreenView` fills the parameters GA4's
built-in screen reports already read.

## What is deliberately not counted

### Unique users

The RTDB counters are plain `ServerValue.increment(1)` writes made
unauthenticated, so every number here is **events, not people**. Nothing in the
schema can tell one device from another, and nothing should be added lightly:
de-duplicating per person means a `seen/{metric}/{key}/{identity}` marker per
identity per key per day, which multiplies the write volume by the fan-out of
the ranking and hands an unauthenticated client a path it can pad indefinitely.

GA4 already answers this. Every event carries an app-instance id, so *Users* is
reported next to *Event count* for free — once the custom dimensions above are
registered, "how many people used Qibla" is a report, not a schema change.
Treat the dashboard as the live ranking and GA4 as the source for reach.

### Apple Watch

`ios/ShiaCompanion Watch App` and `ios/ShiaCompanionWatchWidgets` reach neither
sink. A watchOS target cannot call `AnalyticsService` — it runs no Flutter
engine, and the Firebase watchOS SDK is not in the Podfile. Counting it means
relaying: the watch already talks to the phone over `WCSession`, and
`AppDelegate.m`'s `didReceiveMessage:replyHandler:` already answers the
`{"request": "snapshot"}` the watch sends on launch and on reachability, so
that handler is where a watch-side signal would be turned into a phone-side
event. Nothing is wired up today.
