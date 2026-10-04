# Design spec: the 2026 revamp

The agreed look for the home, navigation, reading screens, setup flow and
tools, written so each implementation PR can be checked against it. The
agreed mockups are in [`design/mockups/`](design/mockups/) (one HTML file
per screen, with exact sizes and colours; see its README for which file is
which). They were drawn on the design canvas
https://claude.ai/artifact/AjdZLyGAdFC5faTXco6Um5 (pages **Round 2 · Phone /
Tablet / Web**, plus the round-1 pages for setup, the city picker, verse
picker, counters and settings). Where this file and a mockup disagree, this
file wins.

## Principles

1. **One design on every platform.** Same layout, colours and navigation on
   Android, iOS, tablets and web. Only fonts (system fonts) and small
   platform behaviours (back-swipe, adaptive switches and dialogs) differ.
2. **Built for people who are not tech-savvy.** Words over symbols ("Rakaat
   2 of 4", not "2.–"), visible buttons over hidden gestures (an Edit
   button, not long-press), 44 px minimum touch targets, nothing that moves
   on its own.
3. **Calm.** Warm neutral ground, one brown, one gold. No gradients, no
   tinted-pink surfaces, no decorative circles.
4. **Never a dead end.** Every empty or failed state offers a way forward
   (no location → choose a city; signed out → sign in where the data lives).
5. **Reuse what exists.** Every section on the new home is backed by a
   service the app already has; nothing here needs new backend work except
   the city list.

## Colour tokens

Defined once in a `ShiaColors` theme extension plus an explicit
`ColorScheme` (not `ColorScheme.fromSeed`, which is what tints today's
surfaces pink). Contrast ratios are measured against the token in the
"on" column.

| Token | Light | Dark | Used for | Contrast |
|---|---|---|---|---|
| `ground` | `#F8F5F0` | `#15110D` | Page background | — |
| `readerGround` | `#FBF8F3` | `#15110D` | Zikr / Quran reading background | — |
| `surface` | `#FFFFFF` | `#221B16` | Cards, lists, sheets' rows | — |
| `well` | `#F2EBE1` | `#2E251E` | Icon tiles, date blocks, inputs | — |
| `line` | `#E8E0D5` | `#3A3029` | Card borders | — |
| `divider` | `#EFE7DC` / `#E6DDD0` (reader) | `#3A3029` | Row and line-group dividers | — |
| `text` | `#2A1E16` | `#F2EBE2` | Primary text | 14.9 : 1 / 15.9 : 1 on ground |
| `textMuted` | `#6A5A4D` | `#BFB0A2` | Secondary text, captions | 6.1 : 1 / 8.9 : 1 on ground |
| `translation` | `#4E4036` | `#CDBFAE` | Translation lines in the reader | 9.4 : 1 / 10.4 : 1 |
| `accent` | `#6D4C35` | `#E2C39A` | Links, icons, selected states, primary buttons | 7.1 : 1 / 11.2 : 1 on ground |
| `onAccent` | `#FFFFFF` | `#2A1E16` | Text/icons on an accent fill | 7.7 : 1 / 9.7 : 1 |
| `prayerCard` | `#4A3426` | `#3A2A1F` + 1 px `#4A3A2E` border | The prayer card | — |
| `onPrayerCard` | `#FBF6EE`, muted `#D9CBB8` | same | Prayer card text | 10.8 : 1, 7.3 : 1 |
| `gold` | `#E4C27A` | `#E4C27A` | Primary button on the prayer card ("Yes, I'm in London") | dark text on it 9.5 : 1 |
| `tintedNotice` | `#EFE4D6` | `#3A2D22` | Back-up banner | text 12.9 : 1 |
| `chevron` | `#9A8A7C` | `#8C7B6B` | Chevrons and drag handles only | 3.3 : 1 (icons only, never text) |
| `success` | `#2F6B45` | `#7FBF95` | "Backed up", setup ticks | 6.3 : 1 on white |
| `danger` | `#B3261E` | `#F2B8B5` | Remove buttons, Delete account | 6.5 : 1 on white |

Glass (tab bar, search button, reader tools): light
`rgba(255,255,255,0.84)`, dark `rgba(44,36,29,0.86)`, 1 px border
`rgba(42,30,22,0.10)` / `rgba(255,255,255,0.10)`, blur sigma 16–20, shadow
`0 8 28 rgba(42,30,22,0.14)` / `rgba(0,0,0,0.45)`.

**Theme setting.** Replace the Dark mode switch with three choices:
Light / Dark / **Same as phone** (`ThemeMode.system`, the new default for
fresh installs). Existing users keep whatever `darkMode` holds today.

## Typography

- **UI text:** platform system fonts, which Flutter already picks (SF on
  iOS/macOS, Roboto on Android). No bundled UI font.
- **Arabic:** the reader's existing choice (`Qalam` or `Scheherazade`) for
  zikr; `QuranWBW IndoPak` for Quran text. Arabic line height ≈ 2.0× the
  font size.
- **Hadith quote:** the platform serif (`New York` on iOS, `Noto Serif` /
  fallback elsewhere), the only serif use in the app.
- Every size below scales with the existing App text size (0.8–1.5×) and the
  system text scale. Nothing below 11 px at 1.0×.

| Role | Size / line height | Weight | Example |
|---|---|---|---|
| Large title | 34 / 41 | 700 | "Favorites", "Quran", "Settings" |
| Greeting | 32 / 38 (36 / 43 tablet+) | 700 | "Assalamu alaykum" |
| Section title | 20 / 24 | 700 | "Shortcuts", "Coming up" |
| Card title | 17 / 21–22 | 600 | "Al-Baqarah", list rows |
| Body | 17 / 22 | 400 | List rows, buttons |
| Secondary | 15 / 20 | 400–600 | Dates, sub-lines |
| Caption | 13 / 17 | 400–600 | Prayer names/times, card labels |
| Tab / tool label | 11 / 13 | 500 (700 selected) | "Home", "Bookmark" |
| Transliteration | 15 / 21 | 600, uppercase as stored | Reader |
| Translation | 16 / 23 | 400 | Reader |
| Zikr Arabic | user setting (default 30) | — | Reader |

## Spacing, shape and size

- 4 px base unit. Phone page gutter **16**, tablet **32**, web content
  centred at **1120** max (the existing `wideContentWidth`).
- Gaps: 18–20 between home sections, 10 between a section title and its
  card, 12–14 inside cards.
- Radii: inputs 12 · icon tiles 16–17 · list cards 16–18 · feature cards
  20–24 · sheets 16 (top corners) · pills and capsules fully rounded.
- Touch targets ≥ 44 × 44 everywhere, including icon-only buttons; row
  heights 50–56.
- Icons: existing `HomeGlyph` / `PrayerGlyph` painters for content;
  1.8 px-stroke outline icons for everything else. Icon tiles are 52–56 px
  wells holding a 30–32 px glyph — no filled brown circles.

## Navigation

- **Three tabs:** Home · Quran · Favorites, plus a separate round
  **Search** button to the right of the bar. Floating glass capsule,
  62 px tall, 16 px from the sides and 26 px from the bottom (above the
  safe area); centred with a fixed width on tablet/web.
- The bar shows **only on the three tab roots.** Every other page (lists,
  readers, tools, settings) is pushed on the root navigator, so it gets
  the full screen and today's deep-link handling (`pushRootPageRoute`,
  `routeObserver`, web URL sync) keeps working unchanged.
- Tab roots live in an `IndexedStack` so each keeps its scroll position.
- Settings and sign-in: the round profile button top-right of Home.
- Search: today's `DataSearch`, plus verse parsing ("2:255",
  "baqarah 255", "yasin 1") putting a **Go to verse** result first.
- Analytics: give every `HomeMenuItem` an explicit `analyticsId` equal to
  today's derived id before any label changes, so counters don't fork
  (e.g. Preferences → Settings).

## Screens

### Home (tab 1)
Top to bottom, each section hidden when it has nothing to show:

1. **Header** — Gregorian date (secondary), "Assalamu alaykum", profile button.
2. **Prayer card** — Hijri date + city button (opens the city picker);
   today's behaviour for the times: the 3–5 the user picked, starting with
   the upcoming one, "next day" under the first time that's tomorrow. No
   "next prayer" headline. Tap → Calendar & Prayer Times; long-press →
   "Prayer times shown" picker (as today). No-location state = the
   round-1 "Which city are you in?" card (time-zone guess, Use my location,
   Choose city).
3. **Continue** — up to 3 cards, newest first: Quran track
   (`RecitationTrackerManager`), dua bookmark (`ZikrBookmarksManager`),
   library chapter (`LibraryProgressStore`). Horizontal scroll on phone.
4. **Shortcuts** — 4 × 2 grid: 7 user-picked + fixed **All features**.
   "Edit" opens the editor sheet (remove/drag/add, max 7). Stored in prefs
   and synced via `PreferencesSyncService`. Defaults: Duas, Ziyarats,
   Today's Recitations, Munajaat, Calendar, Tasbeeh, Qibla.
5. **Coming up** — next 2 events from `buildUpcomingCalendarWidgetEvents`;
   a row says "Today" only when the event is today.
6. **Hadith of the day** — full text, source, Share button.

### All features
One 3-column grid in today's home order (minus Quran and Favorites, which
are tabs), My Stats added, Preferences renamed Settings. A small check on
items already on Home; "Edit shortcuts" top-right.

### Quran (tab 2)
Large title + Recent sessions and My Stats buttons; reading-track cards
(default track shown as "My reading"); **Go to a verse** button (opens the
two-step picker: surah list with quick picks → verse number grid in
groups of 50); Surahs / Juz / Collections as a segmented switcher; surah
list.

### Favorites (tab 3)
Large title + Edit; segmented **Duas & more / Quran verses**; back-up
banner while signed out; list.

### Reading (zikr and Quran)
- Top bar: round back button, one-line title, small sub-line ("12% read",
  "Part 3 of 4", "Verse 255 of 286 · My reading"), favourite button, 3 px
  progress line along the bottom edge.
- Multi-part zikrs: parts as chips under the title; swiping still changes
  part.
- Content unchanged in behaviour: dividers between line groups, Merits
  button, paragraph mode, verse medallions, selection menu (Suggest a
  Correction), links between zikrs, previous/next surah footer.
- Tools capsule (same style as the tab bar): Bookmark · Listen (only when
  audio exists) · Text · Counter · Share. Quran: tapping a verse opens Save
  verse / Copy verse / Copy link / Share verse.
- **Text** opens one sheet with every reading setting: font cards with live
  sample, Arabic and English size, transliteration, translation, Arabic as
  one paragraph (disabled with the rule spelled out), keep screen on,
  focus mode, share as image.
- Focus mode hides both bars as today.

### First-run setup
Welcome → 1 Prayer times (location or city) → 2 Azan (per-prayer toggles,
sample) → 3 Arabic style (font cards + size) → 4 Light / Dark / Same as
phone → 5 Back up (Google, Apple on iOS, Maybe later). "Skip" on every
step; defaults apply when skipped. Replaces the location explainer and azan
dialogs; the OS prompts only follow an explicit tap. No setup checklist on
Home. Existing users get a short "What's new" built from steps 3–5 plus the
Quran and My Stats introduction.

### Settings
Sign-in card first (signed out: what's at stake + Google/Apple buttons;
signed in: name, email, "Backed up · 2 minutes ago", opens Account with Log
out / Delete account). Then Appearance (Theme, Arabic font with sample,
Text size), Prayer times (Location, Azan, Adjust Hijri date, Prayer times
shown), Notifications, Reading, Offline audio, Support.

### Back-up nudges
One-line banner where synced data is created — Favorites, bookmarks, Quran
tracks, My Stats — only while signed out; "Not now" hides it for a week.

### Tools
- **Tasbeeh:** segmented Tasbih al-Zahra / Free count; in Zahra mode the
  current phrase in Arabic + transliteration, "12 of 34", three phase bars
  (34/33/33). Whole panel is the tap target. −1, total, Reset with
  confirmation. Beep/vibration/targets behind the settings button.
- **Rakaat:** 2/3/4 switcher, sensor status pill, "Rakaat N of M" in large
  type, rakaat bars, sajdah dots + "1 of 2 sajdahs"; Undo / Start over;
  placement help as a link. **Dim mode** after a few seconds without
  touches: numbers only on black, tap to brighten.
- **City picker:** offline search over a bundled GeoNames city list
  (≈25k cities, CC BY; the airports list misses Karbala, Qom, Kuwait City
  and others), "Use my current location instead" row. A chosen city is
  stored as manual and never overwritten by GPS refreshes.

## Responsive behaviour

| Width | Layout |
|---|---|
| < 600 | Phone: single column, pickers as bottom sheets |
| 600–1023 | Tablet: Home in two columns (prayer card, Continue, Coming up · Shortcuts, hadith); readers in a 640 px column; pickers and city search as centred dialogs |
| ≥ 1024 | Web/desktop and tablet landscape: same two columns inside 1120 px; readers in a 720 px column; slimmer top bars |

The tab bar stays bottom-centre at every width.

## Accessibility

- Contrast as in the token table; text never uses `chevron`.
- Real buttons with semantics labels for every icon-only control
  (profile, search, back, favourite, remove/add shortcut).
- Respect the system "reduce motion" (no capsule animations) and provide a
  solid fallback for the glass when blur is unavailable or expensive.
- Everything must reflow at 1.5× app text size; labels wrap to two lines
  rather than truncate where they can.

## Build order

1. Theme tokens + `ThemeMode.system` + three-tab shell with glass bar and
   search button.
2. Home sections (prayer card, Continue, Shortcuts + editor, Coming up,
   hadith) and All features.
3. City fallback and bundled city list.
4. Verse search parsing and the Go-to-verse picker.
5. Reader top bar, tools capsule, Text sheet, part chips (Quran and zikr).
6. Settings sign-in card, Account page, back-up nudges.
7. First-run setup and the "What's new" flow.
8. Tasbeeh and Rakaat redesign, dim mode.
9. Tablet and web layouts.

Each PR ships with before/after screenshots in `docs/pr-screenshots/`.
