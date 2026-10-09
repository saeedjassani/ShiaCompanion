# Design spec: the 2026 revamp

The agreed look for the home, navigation, reading screens, setup flow and
tools, written so each implementation PR can be checked against it. The
agreed mockups are in [`design/mockups/`](design/mockups/) (one HTML file
per screen, with exact sizes and colours; see its README for which file is
which). They were drawn on the design canvas
https://claude.ai/artifact/AjdZLyGAdFC5faTXco6Um5 (pages **Round 2 · Phone /
Tablet / Web**, the round-1 pages for setup, the city picker, verse
picker, counters and settings, and **Round 3 · Remaining screens** for
search, lists and the other pages still in the old design). Where this file
and a mockup disagree, this file wins.

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
| Home title | 32 / 38 (36 / 43 tablet+) | 700 | "22 Rabi' al-Thani" |
| Section title | 20 / 24 | 700 | "Continue", "Coming up" |
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
- **Pushed pages** (everything that isn't a tab root or a reader): the
  reader's round 44 px Back button top-left, up to two round or text
  actions top-right, then a large title with an optional one-line sub-line
  (a count, a date, or what the page is for). Scrolling folds the title
  into the bar as a centred one-line title, like the reader. A page title
  may be shorter than its menu label ("Qaza" for Qaza Tracker); menu labels
  and analytics ids stay as they are.
- Settings and sign-in: the round profile button top-right of Home.
- Search: today's `DataSearch` in the layout under **Search** below, plus
  verse parsing ("2:255", "baqarah 255", "yasin 1") putting a **Go to
  verse** result first.
- Analytics: give every `HomeMenuItem` an explicit `analyticsId` equal to
  today's derived id before any label changes, so counters don't fork
  (e.g. Preferences → Settings).

## Screens

### Home (tab 1)
Top to bottom, each section hidden when it has nothing to show:

1. **Header** — today's Hijri day and month as the title ("22 Rabi'
   al-Thani"), then the year ("1448 AH") and the city button (opens the
   city picker) under it, and the profile button. No greeting and no
   Gregorian date. The city button is left out until there is a location;
   the prayer card asks for one instead. The Islamic day begins at
   Maghrib: from Maghrib until Fajr the title is the next Hijri day under
   a small **EVE OF** label (`islamicDayAt`, the same Maghrib/Fajr window
   as the "N" zikr patterns). Only with a location: without one, Maghrib
   is unknown and the date turns at midnight. The Calendar and a city's
   prayer times say "Eve of …" for today the same way. The compact bar
   that replaces the header on scroll reads "Shia Companion".
2. **Prayer card** — the 3–5 times the user picked (default Fajr,
   Sunrise, Zuhr, Sunset, Maghrib). The next one is large in its own
   panel: glyph, "Up next" over its name, its time over a countdown to the
   second ("in 3h 05m 09s"; not read by screen readers). The rest follow
   in one row, in order, with no "next day" marks: what follows is later.
   Once every time shown is tomorrow's, "Up next" reads "Tomorrow". The
   card's last row is the **next event** (see 5). Tap → Calendar & Prayer
   Times; long-press → "Prayer times shown" picker (as today). No-location
   state = the round-1 "Which city are you in?" card (time-zone guess, Use
   my location, Choose city), with the event row under it too.
3. **Continue** — up to 3 cards, newest first: Quran track
   (`RecitationTrackerManager`), dua bookmark (`ZikrBookmarksManager`),
   library chapter (`LibraryProgressStore`). Horizontal scroll on phone.
4. **Shortcuts** — no heading. Up to 11 user-picked + fixed **All
   features**, four to a row: two rows for up to 7 picks, a third from 8
   (no rows setting; the grid grows with the picks). Edited from **Edit
   shortcuts** on All features, which opens the editor sheet
   (remove/drag/add, max 11). Stored in prefs
   and synced via `PreferencesSyncService` as one list for every screen
   size. Defaults on a phone: Duas, Ziyarats, Today's Recitations,
   Taqibaat, Calendar, Tasbeeh, Qibla (two rows). From the tablet
   breakpoint up, Qaza Tracker, Playlists, Library and Namaz are added
   (three rows). Defaults are never synced; the first save replaces them
   on every device. A wide screen at least 900 tall (portrait tablets,
   1080p desktops) has room to spare, so it shows every feature instead:
   the reader's picks first in their order, then the rest in All features
   order, and no All features tile (nothing is left to pick; the order is
   the one saved on a phone or a smaller window).
5. **Next event** — the prayer card's last row, not a section: the next
   event from `buildUpcomingCalendarWidgetEvents`, counted from the Islamic
   day in effect. Date box, "In 9 days · 5 Jumada al-Awwal" (or
   "Tomorrow · …"), the title; two events on one day come joined in one
   title. While the event's day is the one in effect the row turns gold
   and says **TODAY**, or **TONIGHT** from Maghrib on its eve. Tap →
   Calendar.
6. **Hadith of the day** — full text, source, Share button.
7. **Get the app** — web only: a card with the official App Store and
   Google Play badges (both, whatever the browser), under the prayer card
   and Continue from the tablet breakpoint up, last on a phone.

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

- **Messages** ("Saved for offline", "Copied", Undo) are a **toast**, not
  a Material snack bar: a glass capsule (52 px min, 26 px corners), 16 px
  from the sides and at most 640 px wide, floating 12 px above where the
  tab bar and find fields sit, with at most one action in accent text. One
  at a time; swipe down to dismiss; fades without sliding under reduce
  motion. It belongs to the page that raised it and goes when that page is
  covered, popped or swapped for another tab (a sheet or dialog over it
  doesn't count); a message about where the user lands ("Signed out") is
  shown after the pop (`showToast` in `lib/widgets/app_toast.dart`).

### Favorites (tab 3)
Large title + Edit; segmented **Duas & more / Quran verses**; back-up
banner while signed out; list.

### Search
A pushed full-screen page from the round Search button. **The field stays
at the bottom, where the button was**: the button grows into the field
(glass, 62 px tall, 16 px from the sides) and turns into a round **Close**
(×) beside it. Focused on open, the field sits just above the keyboard;
once the keyboard is dismissed it rests 26 px from the bottom, like the tab
bar. Results scroll behind it under the same fade.
- The field: search icon, placeholder "Dua, surah or book", accent border
  while focused, clear button once there is text. **It is the only
  control**: nothing sits at the top.
- **No source chips.** Every source is a section of the results, best
  match first (today's order), labelled with its name and count ("Duas &
  more · 6", "Zikr" renamed to match Favorites) and a **Hide** link. Library
  starts folded to one row, "11 matches in Library · Show", after the
  others. What is folded is remembered in `search_sources`, the pref the
  chips use today, with the same defaults, so Library stays folded until
  someone opens it.
- Before typing: the large title "Search", then **Try**: four examples in a
  2 × 2 grid (Kumayl, Yasin, 2:255, Mutahhari, each labelled with what it
  is) that fill in the field when tapped, so verse and author search are
  discoverable without a help page; then **Recent** (the last 3 searches,
  kept on this device, with Clear).
- A result row has the title with the matched text in bold, a title's
  trailing Arabic on its own line (as in Lists), where it lives on a
  sub-line ("Ziyarats", "Aamaal › Muharram", from the list or group its uid
  sits in) and the heart. A **Go to verse** result comes first when the
  query reads as a verse.
- No results: "Nothing called “…”", where it looked (duas & more, the
  Quran and the Library, folded or not), a tip to try one word or another
  spelling, and today's request flow as a card, "Still can't find it?" +
  **Request “…”** (`showContentRequestDialog`, pre-filled as today).

### Lists (Duas, Ziyarats and the rest)
`ItemList`, and Today's Recitations.
- Pushed-page chrome, large title + count ("138 duas"), and a **Find a
  dua** field floating at the bottom like Home's search: the same glass
  field, 62 px tall, 16 px from the sides and 26 px from the bottom, with
  the list scrolling behind it under the fade. It filters this list only
  (same matching as search, slugs included). Every list and the Library
  use the same field ("Find a ziyarat", "Find a book or author").
- One card list in today's order. Rows ≥ 54 px: the title; when it ends in
  Arabic (`Dua al-Hujjah اِلٰهِيْ …`) the Arabic moves to its own line,
  right-aligned, in the reader's Arabic font; the heart on the right.
- A **when** sub-line from the entry's `day` patterns, so occasion duas say
  so: "Every day", "Saturdays", "On 20 Safar", "On 17 and 29 Safar, 11 and
  23 Dhul Qa'dah". A **Today** pill when it matches today
  (`matchTodaysZikrs`); none on every-day entries, where it would be noise.
- Group rows (`~` uids such as "Ziyarat of Hijaz, Iran & Iraq" and the
  Aamaal months): a folder tile, bold title, what's inside on a sub-line, a
  chevron and no heart.
- **Today's Recitations:** title + today's civil and Hijri dates, then one
  labelled card per group in today's order (the date or night, the month,
  "For Saturday", "Every day"), and a note that special dates come first.

### Reading (zikr and Quran)
- Top bar: round back button, one-line title, small sub-line ("12% read",
  "Part 3 of 4", "Verse 255 of 286 · My reading"), reminder bell (the
  favourite heart on web, where reminders can't fire), 3 px progress line
  along the bottom edge.
- Multi-part zikrs: parts as chips under the title; swiping still changes
  part.
- Content unchanged in behaviour: dividers between line groups, Merits
  button, paragraph mode, verse medallions, selection menu (Suggest a
  Correction), links between zikrs, previous/next surah footer.
- Tools capsule (same style as the tab bar): Bookmark · Listen (only when
  audio exists) · Text · Counter · Share. Quran: tapping a verse opens Save
  verse / Copy verse / Copy link / Share verse.
- **Text** opens one sheet with every reading setting: font cards with live
  sample, Arabic and English size, an Auto-scroll row with a Start button
  (reader only, not from Settings), transliteration, translation, Arabic as
  one paragraph (disabled with the rule spelled out), keep screen on,
  focus mode, share as image; then the translation language (where more
  than one is offered). Setting a reminder is the top bar's bell.
- Auto-scroll adds no permanent control: once started, its controls take
  the tools capsule's place the way the player does - play/pause, "Speed
  N" with − and +, close. A finger on the text holds it; it pauses at the
  end of the text and when another page is opened over the reader. The
  speed is remembered and scales with the Arabic size; the screen stays on
  while it runs, and the bars stay put (even in Focus mode).
- Focus mode hides both bars as today.

### First-run setup
Welcome → 1 Prayer times (location or city) → 2 Azan (per-prayer toggles,
sample) → 3 Arabic style (font cards + size) → 4 Light / Dark / Same as
phone → 5 Back up (Google, Apple on iOS, Maybe later). "Skip" on every
step; defaults apply when skipped (Skip puts back whatever that step
changed; the Azan step's Skip is "Not now"). Replaces the location explainer and azan
dialogs; the OS prompts only follow an explicit tap. No setup checklist on
Home. Fresh installs on Android and iOS only: an install that has run an
earlier build skips it, and the web keeps its quiet first load. Existing users get a short "What's new" built from steps 3–5 plus the
Quran and My Stats introduction.

### Settings
Sign-in card first (signed out: what's at stake + Google/Apple buttons;
signed in: name, email, "Backed up · 2 minutes ago", opens Account with Log
out / Delete account). Then Appearance (Theme, Arabic font with sample,
Text size), Prayer times (Location, Azan, Adjust Hijri date, Prayer times
shown), Notifications, Reading, Offline audio, Support.

**Account** (`R3-Account`): name, email and provider, "Backed up · 2
minutes ago", what the backup holds with counts (favorites, bookmarks, Quran
progress, saved verses, qaza, My Stats and shortcuts), **Log out**, and
**Delete account…** in danger colour with one line on what deleting
removes; the confirmation stays a dialog.

### Back-up nudges
One-line banner where synced data is created — Favorites, bookmarks, Quran
tracks, My Stats — only while signed out; "Not now" hides it for a week.

### Calendar & Prayer Times
**One page, no tabs**: tap a day and everything under the month follows
it, its prayer times included (mockups `R5-Calendar`, `T-Calendar-R5`,
`W-Calendar-R5`).
- **Top:** the round Back button, and the city button on the right (as on
  Home, left out until there is a location).
- **Month:** the month as the large title ("October 2026"), the Hijri
  months it spans under it ("Rabi' al-Thani – Jumada al-Awwal 1448"), and
  round ‹ › buttons beside it. A **Today** button joins them whenever the
  picked day or the month on show is not today's. A sideways swipe on the
  grid also changes month.
- **Grid:** Sunday first, the days either side of the month muted (and
  tappable). The date sits top-left, the Hijri day bottom-right in
  Persian digits. Today has a 1.5 px accent ring; the picked day fills
  with the accent.
- **Event colours** — the whole cell is tinted, not a dot. `events.json`
  marks each event 0 (green) or 1 (red), the way the H. Karmali calendar
  of Mumbai does: **red for joy** (births, Eids), **green for mourning**
  (martyrdoms, deaths). Keep that reading; it has been swapped by mistake
  once. Light: green `#E1EFE4` / line `#BFDCC7`, red `#F9E2DE` /
  `#EDC3BC`; dark: green `#1E3325` / `#2F5A3C`, red `#3B201C` / `#6A302A`.
  An event with neither gets `well`. Hue is never the only signal: the
  event is written out below and read out by screen readers.
- **The picked day:** "Saturday 24 October", then a pill — Today,
  Tomorrow, Yesterday, "In 17 days", "3 days ago" — and its Hijri date.
  Today after Maghrib adds "Eve of …" (see Home). Its event follows in
  full in a card of its own colour.
- **Prayer card:** Home's brown card with the picked day's times: the
  five prayers across, then Sunrise, Sunset and Midnight. No "next"
  highlight here. Along its bottom edge two buttons that say what they
  hold: **Azan** · "On for 3 times" (or "Off"; not on the web) opens the
  Azan page, and **Times on Home** · "5 shown" (house icon) opens the
  "Prayer times shown" picker. No location: the card says so and offers
  **Choose city**.
- **Prayer times in another city** · "Times for 24 October somewhere
  else, e.g. Karbala": a card row opening the look-up city picker on that
  date. No footnote under it.
- **Tablet:** the month full width, then the day, its event and the city
  row on the left and the card on the right (340 px), listing all eight
  times top to bottom. **Desktop and web:** the month on the left, the day
  in a 360 px column on the right with the same vertical card. The cells
  are the phone's, 64 px tall: no event names in them on any screen.

### Azan
Today's prayer notifications page, from Settings → Prayer times → Azan:
a **Default sound** row ("Full Azan"), then the eight times in one card,
each a split row: the left part opens that time's sound, then a divider,
then the switch. An on row shows its sound; one with its own sound says
"Takbir Only · its own sound" in accent. Footnote on per-time sounds and
the iPhone takbir.

### Library
- Title + count, the bottom **Find a book or author** field (title or
  author, as search matches), the **Continue reading** card (book,
  chapter, "page 4 of 9", progress bar, × to remove;
  `LibraryProgressStore`), then **All books**
  with an author line and the heart. "Request a book" moves from after the
  1,162nd row to the section header.
- One book: title, author and chapter count; **Continue · Part 2, page 4**
  and **Save for offline** as labelled buttons instead of app-bar icons;
  Share stays top-right. Chapters are numbered in wells, the current one
  filled, with "Reading · page 4 of 9". The chapter page takes the reader's
  top bar.

### Playlists and downloads
- **Playlists:** **New playlist** and **Downloads** buttons, then one card:
  a 48 px play/pause button, the name, what's in it or what's playing
  ("Playing: Dua Ahad · 1 of 4"), a chevron.
- **One playlist:** "4 zikr · 3 downloaded", **Play all**/**Pause** and
  **Add zikr**, numbered rows (the playing one shows a speaker and "3:12 of
  9:40"), ⋯ per row (open text, choose recordings, download, remove) and ⋯
  top-right (rename, remove downloads, delete). "Download for offline · 1
  left" while any aren't downloaded.
- **Downloads:** the total size in the sub-line, one card (a download in
  progress shows its bar and Stop; the rest a remove button), the older
  recordings card, and "Remove all downloads" in danger text.

### My Stats
Streak card (days in a row, the best, today's state in words with a tick),
History card (Zikrs / Verses / Qaza chips, one bar per day with its value
on top, today in accent, Week / Month / All time), Your most recited, then
today's Quran progress, privacy note and community sections as cards.

### Zikr reminders
- List: **Add a reminder**, then one card; a row has a tile (the prayer's
  glyph when it's relative to a prayer, a clock otherwise), the title,
  "Thursdays · 15 min after Maghrib" and a switch. Tapping a row edits it;
  Remove moves into the edit page.
- Form: **What** (a zikr from the library, "From Duas"), **Repeat on** (seven
  44 px day buttons + "Every day"), **When** (At a set time / Around a
  prayer; the prayer, a minutes stepper in 5s, Before / After), and a
  plain-words summary above the pinned **Add reminder** button: "Thursdays,
  15 minutes after Maghrib (about 6:56 pm this week)".

### Tools
- **Tasbeeh:** segmented Tasbih al-Zahra / Free count; in Zahra mode the
  current phrase in Arabic + transliteration, "12 of 34", three phase bars
  (34/33/33). Whole panel is the tap target. −1, total, Reset with
  confirmation. Beep/vibration/targets behind the settings button. Each
  mode keeps its own count; the free count keeps today's `count` pref, so
  someone part-way through one opens on Free count. Zahra marks 34, 67 and
  100; the targets in settings are the free count's.
- **Rakaat:** 2/3/4 switcher, sensor status pill (tap it to turn automatic
  counting off or on), "Rakaat N of M" in large type, rakaat bars, sajdah
  dots + "1 of 2 sajdahs"; Undo / Start over; placement help as a link.
  N is the rakaat being prayed: once both sajdahs of a rakaat are counted
  the next one shows ("Rakaat 2 of 4, 0 of 2 sajdahs"). **Dim mode** after
  6 seconds without touches: numbers only on black, tap to brighten. Only
  while the sensor counts (counting by hand means a tap after every
  sajdah, which the dim page would swallow), never under a screen reader,
  and the page brightens by itself when the prayer is complete.
- **Qibla:** "Pointing towards" as a labelled button (**Change** opens
  today's holy-sites sheet), the dial (today's `QiblaCompassDial`, round-3
  colours: Kaaba marker, the phone's forward line), the instruction in
  large words ("Turn right 12°", "Facing the Kaaba"), and Distance /
  Direction / You face tiles. "About this compass" behind the ⓘ button;
  permission and calibration states keep today's copy, as cards above the
  dial.
- **Qaza:** a summary card (left to make up in large type, done, a progress
  bar) with **Prayed a full day** and **Work out how many I owe** (today's
  "Calculate my qaza" sheet) as buttons rather than an app-bar icon. One
  row per prayer: the name, "248 left · 12 done", one **Prayed** button, and
  ⋯ for Add a missed one / Undo / Edit count. "Dhuhr" becomes "Zuhr", as
  everywhere else. Namaz-e-Ayat and Other sit behind a header link until
  used; Fasts work the same with **Fasted**.
- **Prayer times in flight:** **Add a flight**, then a card per flight (the
  route in large type, the cities, date and departure, duration and landing
  time, a pill naming what comes in on board, ⋯ for edit / remove). One
  flight: a departs / arrives card, **In the air** (each time on both
  clocks, how long after take-off and where, the Qibla relative to the
  aircraft), **On the ground** (what to use instead), and "How these are
  worked out".
- **City picker:** offline search over a bundled GeoNames city list
  (≈25k cities, CC BY; the airports list misses Karbala, Qom, Kuwait City
  and others), "Use my current location instead" row. A chosen city is
  stored as manual and never overwritten by GPS refreshes.

## Responsive behaviour

One design at every width: the same tokens, cards, chrome and tab bar.
What changes is how much sits side by side. Three screen classes
(`ScreenClass` in `lib/widgets/responsive_content.dart`):

| Width | Class | Covers |
|---|---|---|
| < 600 | Phone | Phones, any orientation |
| 600–1023 | Tablet | Tablets in portrait, small browser windows |
| ≥ 1024 | Desktop | Web and desktop, tablets in landscape |

**Gutters and columns.** 16 px page gutter on a phone, 32 from tablet up.
Content is centred in one of three widths, so a page never stretches to
the window:

- **720 — one column** (`largeTitlePageWidth`, the default): forms,
  settings-like lists and tools — Azan, Zikr reminders and their form,
  Playlists, Downloads, Flights, About, News, Account, All features,
  Tasbeeh, Rakaat. Lines stay readable and a row's switch stays near its
  label.
- **1120 — wide** (`widePageWidth`, Home's width): pages with more to show
  at once — Home, the zikr lists, Favorites, Quran, Library and a book's
  chapters, Today's Recitations, Search results, Recent sessions, the zikr
  picker, Settings, My Stats, Qaza and Qibla.
- **Readers**: a 640 px column on a tablet, 720 from desktop up
  (`readerColumnWidth`), with the top bar running the full width — Back
  at the window's edge, the title centred — as in `W-Reader`.

The large title, Back button and actions line up with the content column
they head, at every width.

**Long lists go two to a line** where the column is 880 px or more (a
wide page on a desktop or a landscape tablet): one card, rows in reading
order left to right, a 1 px line between the columns, each pair as tall
as its taller row (`SliverCardList`). Below 880 the same card is one
column. Applies to every list built on `SliverCardList` (zikr lists,
surahs and juz, Favorites, books, chapters, search results, Today's
Recitations' groups).

**Dashboards go two columns** at the same 880 (`WideColumns`), most-used
on the left:

- **Home** — prayer card, Continue · Shortcuts, hadith (from
  600 already; see Home).
- **Settings** — the sign-in card, Appearance, Prayer times · Notifications,
  Reading, Offline audio, Support. The version line stays centred under
  both.
- **My Stats** — streak, history · most recited, Quran progress with the
  privacy note, community.
- **Qaza** — the summary card (or "Missed prayers for a while?") · the
  prayer rows and Fasts.
- **Qibla** — the dial (up to 380 px) and the turn instruction · Pointing
  towards, notices, the Distance / Direction / You face tiles and the
  location line. On a tablet in portrait the one column keeps its phone
  order with a 380 px dial; a phone keeps 300.
- **Quran** — the Surahs / Juz / Collections switcher and **Go to a verse**
  share a line, each over one of the list's columns, instead of two
  full-width bars.

**Floating fields keep a field's width.** A list's **Find** field and the
Search field stay centred and at most 640 px wide (Search's plus its
Close button), over whatever width the page has. The tab bar stays
bottom-centre at every width, 290 px from tablet up.

**Pickers are dialogs from tablet up.** Everything opened with
`showAdaptiveSheet` — theme, font, text size, Hijri adjustment and every
other choice sheet, Edit shortcuts, the verse menu, Merits, the reading
position picker — is a bottom sheet on a phone and a centred dialog
(560 px, 20 px corners, ground colour, no drag handle, at most 88 % of the
height) from 600 up; as are the city picker and Go to a verse. A sheet
stretched along the bottom of a wide window reads as a banner rather than
a question.

**Text & reading** stays a bottom sheet on phones and tablets, so the text
it changes is still in view above it, and from desktop up is a 400 px
panel down the window's end edge (16 px inset, 20 px corners, the glass
shadow, a light 12 % scrim) beside the reading column.

**Keyboard and mouse** (web, desktop, a tablet with a keyboard):

- **Esc** goes back a page, as Back does; it closes a dialog, sheet or
  menu first, never leaves the first page, and leaves a dialog that has
  to be answered alone.
- **/** and **Ctrl+K** (**⌘K** on Apple keyboards) open Search from the
  tab roots.
- A mouse can drag the sideways strips (Continue, reading tracks, part
  chips, quick picks) as a finger does; everywhere else a mouse drag
  still selects text.

Calendar & Prayer Times puts the day beside the month from tablet width
up; see its section.

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
2. Home sections (prayer card, Continue, Shortcuts + editor, next event,
   hadith) and All features.
3. City fallback and bundled city list.
4. Verse search parsing and the Go-to-verse picker.
5. Reader top bar, tools capsule, Text sheet, part chips (Quran and zikr).
6. Settings sign-in card, Account page, back-up nudges.
7. First-run setup and the "What's new" flow.
8. Tasbeeh and Rakaat redesign, dim mode.
9. Tablet and web layouts.
10. Search page and zikr lists (the bottom find field, when sub-lines,
    Arabic on its own line, Today's Recitations groups).
11. Azan.
12. Library, Playlists, Downloads, My Stats, Zikr reminders.
13. Qibla, Qaza, Prayer times in flight, Account.
14. Calendar & Prayer Times.

Each PR ships with before/after screenshots in `docs/pr-screenshots/`.
