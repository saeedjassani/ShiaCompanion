# Project notes for Claude

## Subagents: pick the cheapest model and effort that will do the job

- **Do it inline when you already hold the context** or it is a handful of
  commands (a script run, a few greps, a small edit). A subagent starts cold
  and re-reads what you already know, so spawning for small work costs more.
- **Delegate large, separable work**, and on every `Agent` call set `model`
  and `effort` explicitly to the cheapest pair that will do it reliably:
  - broad read-only searches, counting, listing -> `Explore` on `haiku`,
    `low` effort;
  - mechanical bulk work with a clear spec (renames across files, batch
    edits, filling templates, first-draft titles) -> `sonnet`, `medium`;
  - judgement-heavy work (Arabic proofreading, zikr translation quality,
    religious-content accuracy, architecture, tricky debugging) -> `opus`,
    `high`.
- Give each agent a self-contained prompt: the files, the exact task, the
  conventions it must follow (point it at this file and
  `docs/TRANSLATIONS.md`), and the output you want back - conclusions or a
  summary, not file dumps.
- Split big jobs into independent batches and run them in parallel; review
  what comes back before committing it.

## TODO / follow-ups

- **Ziyarat Guide: on master, admin-only, not shipped.** A home feature
  listing the places pilgrims visit (regions -> cities -> shrines), each
  shrine linking its ziyarats in the zikr corpus, with about, burials,
  tips, directions and tappable shrine plans; the guide's text is in all
  four languages. Left: the owner's device check, the review items the
  doc lists, translations of the restored entries' merits and verses, the
  remaining missing ziyarats (Najaf, Kufa, Mada'in, Samarra, Kazimayn,
  Karbala, Madinah...), then ungating it. The checklist is "What's left"
  under "Status and resume here" in `docs/ZIYARAT_GUIDE.md`; read it
  before resuming.

- **Missing-zikr restoration is mid-way.** 118 unfavorited uids are still
  missing from the corpus. Before resuming, read the "Resume here" section at
  the top of `scripts/RESTORING_MISSING_ZIKRS.md`: next batches (taweez and
  funeral rites `I40`-`I126`, then calendar pages, then ziyarat last and
  checked against online sources), the per-batch workflow, and the tools
  `scripts/zikr_arabic/duas_org.py` and `scripts/zikr_arabic/translit.py`.

- **Restored zikrs that came back cut down: owner's calls done, review
  left.** Pass 7 (`e72d1bb3`) and `4c29a341` shipped stubs; all 29 are
  rebuilt (PR #362, #382) and the owner's decisions are applied (PR #411:
  retitles, X9 -> G74, Sahifa 44/45 as AA48/AA49, AC6 as the Wa Wa'adna
  prayer alone). Still open, each with its entry title and tab under
  "Still open after the owner's review" in `scripts/RESTORING_MISSING_ZIKRS.md`:
  - confirm AA22's Iqbal dua (tab 5) against Iqbal al-A'mal;
  - read the English written fresh for E102, E112, E90, E103, F7 and tabs
    of E42, E41, E84, E63;
  - three wrong-looking English lines in G77;
  - 14 suspected Arabic typos (F15, E102, E41, E84, E42, E63), each with a
    likely reading to check against a printed Mafatih;
  - the F14 (يَا عَظِيْمُ ×4/6/7) and F15 (al-Tawhid in each unit or the
    first) counts;
  - translations for the rewritten lines of 12 entries, and for AC6, AA48
    and AA49;
  - the smaller source gaps (AK5, AA21, D1, G52, ...).
  Check any restored entry with
  `python3 -I scripts/zikr_arabic/source_check.py . <uids>` before shipping it;
  `test/zikr_source_check_test.dart` fails on anything new it flags until
  you accept it with `source_check.py . baseline` (see "The check" there).

- **Sahifa Sajjadiya (2026-11-12): in the app, a few readings to check.**
  The 54 supplications are a group at the top of Duas (`E~AS0`, opening
  the `AS` list). AS2-AS54 are Arabic and Chittick's English from the
  library copy (al-islam.org), one line per numbered verse, with
  machine-drafted transliteration proofread line by line by agents. AS1
  (an old "Dua No. 1") is Sahifa 1; Sahifa 7 is E9 (Dua Amaan, now split
  into verses), and 43-45 are AA21/AA48/AA49 - aliases in the group.
  Still worth a human with a printed Sahifa:
  - variant readings left as the source has them: AS20 بِالنَّظَرِ (Chittick's
    "ingratitude" fits بِالْبَطَرِ), AS37 شَكَرْتَهٗ (passive شُكِرْتَهُ?),
    AS16 الْخَلَائِقُ كُلُّهُمْ, AS24 الْحَفُوفِ (الْحُفُوفِ?);
  - English from the source with a dropped clause (AS19 verse 8) or odd
    words (AS39 "Senders", AS33 "chose", AS42 "He delivered");
  - AS6 (morning and evening) has no `day` tag; AS46/AS48 are tagged Eid
    and Friday, AS47 Arafah;
  - Urdu/Gujarati name the book صحیفہ سجادیہ / સહીફએ સજ્જાદિયા; the older
    titles said صحیفہ کاملہ / સહીફએ કામિલા. E9's translated titles
    ("Dua Amaan") are not what Arabic/Persian readers call Sahifa 7.

- **Zikr translations: Urdu has the first famous duas; Persian and
  Gujarati have none yet.** See `scripts/zikr_i18n/SOURCES.md` for what is
  done, which sources were turned down and why, and what's next. The rest:
  - Urdu for Jamia Kabira (no trustworthy deck), and for Abu Hamza, Arafah
    and Jawshan Kabir (decks exist). The Urdu Mafatih on mafatih.duas.co
    supplied Dua Ahad, Ziyarat Warith, Istighatha, Adeela, Arbaeen,
    Ziyarat Aal-e-Yasin, Munajat Shabaniyah and Dua Alqama; its pages scrape
    cleanly into `deck_source.py` rows (Arabic/Urdu box pairs);
  - Persian beyond the nine famous duas (PR #326), G12 and the Quran:
    Ansarian's Mafatih on erfan.ir loads
    from the user's Mac but not from cloud sessions;
  - Gujarati: G1 Ziyarat Aal-e-Yasin complete (Jafri Library book 6687
    decoded from LMG-Arun); Y4 (book 84725) PDF obtained with text layer in
    legacy "Gujrati" font, decode pending; E8 not in Jafri catalog;
  - merits notes.

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

- **Use tab-level aliases on the duplicates they were built for.** Links
  can name a tab (`/zikr/<slug>?tab=N`), an alias can show only some tabs
  of its target (`"tabs": [N]` on its `assets/zikr.json` entry) and a
  retired uid can too (`RetiredZikrRedirect(..., tabs: [...])`, now used by
  E50 -> I24); see "One text lives in one place" in
  `docs/ZIKR_STRUCTURE.md`. Not yet applied to the cases that motivated it,
  from the 2026-09-17 duplicate sweep (`scripts/RESTORING_MISSING_ZIKRS.md`,
  PR #104): **AK5/G2, D3/I83, E15/F2/F3** - a famous dua living both as its
  own entry and as one tab of a compilation. Each needs its two texts
  compared before the standalone copy becomes an alias of the tab (and its
  `assets/zikr_i18n/` translations are checked against the compilation's,
  which then serve both).

- **Hijri months: publish announced month starts (step 3).** Settings'
  "Automatic" (the default unless someone had moved the date by hand)
  predicts each month's start from naked-eye crescent visibility at the
  reader's location (`lib/utils/moon_sighting.dart`, Yallop's criterion).
  Every Hijri date goes through `hijriForCivilDate` in
  `lib/utils/hijri_date.dart`, so announced dates can override it in one
  place. The idea is a small Firestore doc of month starts per region
  (e.g. from Sistani's office), applied on top of the prediction. Someone
  has to fill that doc in each month.

- **Gujarati for the other famous duas: in progress.** Kumayl (E31) and
  Jamia Kabira's first 99 segments (G13) are done from duas.org's decks
  (`scripts/zikr_i18n/lmg_arun.py`). Hadith al-Kisa (E14), Ziyarat
  Ashura (G4), Ziyarat Warith (G6), Sanamay Quraish (E37) and Munajat
  Amir al-Mu'minin (H17) are done from Jafri Library PDFs
  (`scripts/zikr_i18n/gu_pdf.py`). See `scripts/zikr_i18n/SOURCES.md`.
  - Jafri Library (jafrilibrary.com, Gujarati is `?language=5`) is the
    easiest source. Its PDFs download from a browser without signing in.
    It also has Aal-e-Yasin, Munajat Shabaniyah, the rest of Jamia Kabira,
    Nahiya and Tauba (book numbers in SOURCES.md).
  - Still no Gujarati source for Dua Tawassul (E24, asked for twice), or
    for E16, E92 and I29.
  - Don't use the Haji Naji Trust's "Mukhtasar Mafatih al-Jinan" PDF
    (Tohafa-e-Saiyada, `book_96.pdf`, 2,077 pages).
    - Its translations are Urdu written in Gujarati script, e.g.
      "અય અલ્લાહ! મેરે દિલ પર હિજાબ હૈ". That doesn't match the app's Gujarati
      Quran, which is in Gujarati.
    - Its Arabic is only spelled out in Gujarati letters.
    - It is set in two legacy 8-bit fonts that `gu_quran_decoder.py` doesn't
      cover.
  - Use **"જન્નતની ચાવીઓ"** instead (Keys of Paradise, compiled by Maulana
    Rizwanali Palsaniya) on web.hajinaji.com.
    - Book overview:
      `web.hajinaji.com/books/overview/alFYUkZPQ01hbDV3ZWZHVnU4VWFuUT09/1/12`.
    - It has Kumayl, Nudba, Tawassul, Ahad, Hadith al-Kisa, Ziyarat Ashura,
      Warith, Aminullah, Aal-e-Yasin and Munajat Shabaniyah as Unicode
      chapters.
    - Its chapter titles are Gujarati ("નમાઝે ઝોહર પછી પઢવાની દુઆ"). Its dua
      translations haven't been seen yet, so confirm they are Gujarati too.
    - Its chapter pages need a sign-in (Google or a phone code), so a cloud
      session can't read them. Get its text from the user (a PDF or an
      export from the HajiNaji app), then follow PR #281's workflow.
  - The same site's "દુઆએ નુદબા", "દુઆ-એ-ઈફ્તેતાહ" and "ઝિયારતે આશુરા અને
    તેના ફાયદા" are single-dua books worth checking for Gujarati too.

- **Android smart actions: untested on a device.** Google Assistant's App
  Actions (`res/xml/shortcuts.xml`, `SmartActions.kt`, `SmartActionsService`
  in Dart: open a feature, search, play/open a dua or playlist by name) and
  a playlist's "Add to Home screen" only compile and unit-test here. Pinning
  can be checked on any phone; the App Actions need the App Actions Test
  Tool in Android Studio, then a Play Console upload for Assistant to pick
  them up, and whether Gemini honours them as Assistant did is not known.
  `shortcuts.xml` has no `<shortcut>`s on purpose: the actions under the app
  icon are `AppShortcutsService`'s (quick_actions), whose
  `setDynamicShortcuts` replaces every dynamic shortcut. A debug build has
  its own `src/debug/res/xml/shortcuts.xml` (its package differs) -
  `test/android_shortcuts_test.dart` keeps it in step.

- **Wear OS app: merged, not shipped.** `android/wear` is a standalone
  Gradle build (Compose for Wear OS: prayer times, calendar, tasbeeh, a tile,
  complications) fed from the phone over the Data Layer by `WearSync`, which
  stays dormant until a watch has the app. `internal-testing.yml` with
  *platforms* `wear` uploads it to Play's `wear:internal` track, in its own
  version-code range (100000+). Before shipping: the device checks and the
  Play Console steps in `docs/WEAR_OS.md`. Its UI strings
  live in `android/wear/app/src/main/res/values*/strings.xml` - keep all five
  languages in step there.

- **Move iOS to Swift Package Manager before the next Firebase update.**
  Firebase has deprecated CocoaPods: no new Firebase iOS versions go to
  CocoaPods trunk after October 2026, and `pubspec.yaml` still sets
  `enable-swift-package-manager: false`. The eMudhra fix (PR #410) already
  showed the gap: Firebase iOS 12.19.3 reached trunk only as `Firebase`,
  `FirebaseCore` and `FirebaseFirestore(Internal)`. The next Firebase security
  fix may not reach CocoaPods at all. To switch:
  - turn the flag on;
  - check that every iOS plugin supports SPM, including the app's own targets
    (widgets, watch app, watch widgets);
  - keep `geolocator_apple`'s `BYPASS_PERMISSION_LOCATION_ALWAYS` define from
    the Podfile's `post_install`;
  - make sure Crashlytics' dSYM upload still runs.

  It needs a Mac or CI's `iOS build` to verify; a cloud session can only
  resolve pods, not build.

- **Drop the material_ui stopgaps once dependencies catch up.** Flutter
  3.47 moved Material and Cupertino into the `material_ui` and
  `cupertino_ui` packages; the app imports those, never
  `package:flutter/material.dart`. Two temporary pieces remain:
  - `MaterialUiCompatibilityBridge` in `main.dart`'s `MaterialApp.builder`
    (and `legacy.Theme.of` in `lib/utils/reader_style.dart`), because
    `flutter_markdown_plus` and `fl_chart` still read the framework's
    `Theme`. Remove them once both depend on `material_ui`.
  - `findTooltip` (`test/helpers/finders.dart`) instead of `find.byTooltip`,
    which misses `material_ui` tooltips with `excludeFromSemantics`. Go
    back once flutter_test recognises them.

- **Drop the `firebase_analytics` pin workaround once FlutterFire fixes it.**
  `RelaxFirebaseAnalyticsPin` in `ios/Podfile` exists because
  `firebase_analytics` 13.0.1 pins `FirebaseAnalytics` to exactly
  firebase_core's SDK version (12.19.3), which was never published; the
  Podfile relaxes it to `~> 12.19.0`. When a newer `firebase_analytics` is
  out, upgrade, delete the block and run `pod install`. If it resolves, the
  workaround can go. Moving to SPM (above) retires it too. A cloud session
  can run `pod install` on Linux:
  - `gem install cocoapods json` (json 3.x, so plugin checksums match a
    Mac's);
  - `apt-get install rsync`;
  - run it with `LANG=C.UTF-8 RUBYOPT=-EUTF-8 pod install --allow-root`;
  - create empty `ios/` and `ios-release/` `Flutter.xcframework` dirs under
    `/opt/flutter/bin/cache/artifacts/engine/` for Flutter's post-install
    hook, and remove them afterwards;
  - commit only `Podfile.lock`, never the Linux-rewritten
    `project.pbxproj`.

## Translations

The app is set up for Urdu, Persian, Arabic and Gujarati; see
`docs/TRANSLATIONS.md`. **Never hardcode user-facing English in Dart**: add
it to `lib/l10n/app_en.arb` and read it with `context.l10n.key` (or
`L10n.current.key` where there is no `BuildContext`), then run
`flutter gen-l10n` (`flutter pub get` does it too). The generated
`lib/l10n/app_localizations*.dart` are gitignored - never commit them.
**A PR that adds or changes a key adds it to every `app_<code>.arb` too**
(Urdu, Persian, Arabic, Gujarati), in the same PR, using the wording those
files already use for the same ideas; `build/untranslated_messages.json`
(written by `flutter gen-l10n`) should list none of the new keys. See
"Keeping translations in step" in `docs/TRANSLATIONS.md`.
**Before committing new or changed strings, have an independent agent
review them in every language** - a fresh subagent per language
(`opus`, `high`) that did not write them, given
`python3 -I scripts/l10n_changed_keys.py --lang <code>`'s output; see
"Every new string is checked by another agent" in `docs/TRANSLATIONS.md`.
Analytics labels, `trackScreen` names, preference keys and `debugPrint` text
stay English literals. Zikr translations are overlays in
`assets/zikr_i18n/<code>/` keyed by **segment number** (each verse, standalone
line and tab label of a zikr, numbered 0, 1, 2...), never by English text -
see "Zikr content" in `docs/TRANSLATIONS.md`. **Outside English the reader
sees no English at all**: untranslated lines, merits and labels are hidden
(the Arabic alone shows), and transliteration is off. If you change the
content of a translated zikr (one with a file under `assets/zikr_i18n/`),
run `python3 scripts/zikr_i18n/zikr_i18n.py rebase` and commit what it
renumbers; `test/zikr_translations_test.dart` fails until you do.

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
  Munajat, Istikhara, Taqibaat, Nafilah, Watr, Namaz-e-Ayat, Zuhr, Maghrib,
  Wudu, Aamal, Husayn,
  Muhammad, Musa, Reza, Zayn al-Abidin, Fatimah al-Zahra, Amir al-Mu'minin,
  Hadith al-Kisa, Ayat al-Kursi.
- Named duas drop the Urdu izafat: `Dua Ahad`, `Dua Nudba`, `Ziyarat
  Ashura` (not `Dua-e-…`/`Ziyarat e …`); `Namaz-e-X` keeps its hyphens.
- **Retitling never changes a `slug`.** Slugs keep the old spelling so old
  links resolve, and search (`filterDataSearchResults`'s `slugsFor`) matches
  slugs too, so someone typing the old spelling still finds the entry.
