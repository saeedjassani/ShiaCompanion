# Translations

The app is prepared for **Urdu (`ur`), Persian (`fa`), Arabic (`ar`) and
Gujarati (`gu`)** alongside English. Nothing is translated yet: until a
language ships files of its own, the app looks and behaves exactly as it
always has, and no language picker appears anywhere.

There are two independent things to translate, each with its own files:

| What | Where | Picked in Settings as |
| --- | --- | --- |
| **App text** - menus, buttons, settings, dialogs, notifications | `lib/l10n/app_<code>.arb` | App language |
| **Zikr content** - each dua's translation, instructions, tab labels, merits and title, and recording labels | `assets/zikr_i18n/<code>/` | Translation language |

They are separate because readers need them separately: many want English
menus but a dua's meaning in Urdu. The translation language follows the app
language until the reader picks one of their own. Either side can ship
without the other, and a language is offered in a picker only once its files
exist. A missing ARB key shows in English; zikr content works differently -
see "No English outside English" below.

With no choice made, the app language follows the phone's: once
`app_ur.arb` ships, a phone set to Urdu opens the app in Urdu (the reader can
switch back to English in Settings).

The language catalog (names, which way each reads) is
`lib/l10n/app_language.dart`. The two choices are owned by
`LanguageProvider` (`lib/utils/language_provider.dart`).

## App text (`lib/l10n/*.arb`)

`lib/l10n/app_en.arb` holds every English string the app shows - about 870
of them - in Flutter's [ARB format](https://github.com/google/app-resource-bundle)
(JSON). Code reads them through the generated `AppLocalizations` class:
`context.l10n.someKey` in widgets, `L10n.current.someKey` where there is no
`BuildContext` (notifications, home screen widgets, model labels).

That class lives in `lib/l10n/app_localizations*.dart`, which `flutter
gen-l10n` generates from the ARB files. `flutter pub get`, `run`, `build` and
`test` all regenerate it (`generate: true` in `pubspec.yaml`), so the files
are gitignored: never commit them. Run `flutter pub get` after pulling a
change to any `.arb` file if your IDE shows missing `l10n` getters.

### Adding a language

1. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<code>.arb`, set
   `"@@locale": "<code>"`, translate the values and delete every `@key`
   metadata entry (those stay in the English file only). Keys you leave out
   fall back to English; `flutter gen-l10n` writes the list of what is still
   missing to `build/untranslated_messages.json`.
2. Keep every `{placeholder}` exactly as it is - the app fills them in.
   Plurals use ICU syntax: Arabic needs its `zero`/`one`/`two`/`few`/`many`
   forms, e.g.
   `"{count, plural, zero{...} one{...} two{...} few{...} many{...} other{...}}"`.
3. Run `flutter gen-l10n` (or `flutter pub get`/`run`/`build`, which do it
   too) to check the file compiles. Commit only the `.arb`.
4. Tell the platforms the app now speaks the language:
   - **iOS**: add the code to a `CFBundleLocalizations` array in
     `ios/Runner/Info.plist`.
   - **Android 13+ per-app language**: add the code to a
     `res/xml/locales_config.xml` (create it on the first language, and point
     `android:localeConfig` at it in `AndroidManifest.xml`).

Material's own strings (date pickers, "OK", tooltips) come from
`flutter_localizations`, which already covers all four languages, and dates
and numbers formatted with `intl` follow the app language automatically.

### Writing new UI text

Never put user-facing English in Dart. Add the string to `app_en.arb`
(with an `@key` description when the context is not obvious, and typed
`placeholders` for anything that is not a `String`), then use it through
`context.l10n`. Some English strings double as identifiers and must stay
English in code - prayer names (`"Fajr"`, `"Midnight"` key preferences and
notifications), home menu labels (analytics ids), Azan option ids - so each
has a display mapping instead: `localizedPrayerName`, `homeMenuDisplayLabel`,
`AzaanOption.name`. Analytics labels and `debugPrint` messages stay English.

### Keeping translations in step

UI work and translation work touch different files, so they never conflict:

- **Feature and design PRs** add, change or remove keys in `app_en.arb`
  only. They never edit an `app_<code>.arb`.
- **Translation PRs** edit `app_<code>.arb` only, one language per PR,
  each based on `master`.

A new English key simply shows in English in every other language until it
is translated, and a key removed from `app_en.arb` but still in an
`app_<code>.arb` is ignored, so either kind of PR can merge first. After a
feature lands, a catch-up PR per language fills in what is missing:
`flutter gen-l10n` lists it, per language, in
`build/untranslated_messages.json`. Hold off translating a screen that is
about to be redesigned - its strings are likely to change.

## Zikr content (`assets/zikr_i18n/<code>/`)

### No English outside English

**Someone reading zikrs in Urdu (or Persian, Arabic, Gujarati) never sees
English.** They see the Arabic, and whatever of the zikr has been translated
into their language. Everything else that is English is hidden, not shown in
its place:

| Not yet translated | What the reader sees |
| --- | --- |
| A verse's translation | The Arabic alone |
| An instruction, heading or citation | Nothing |
| A tab's label | The localized "Part 2" (an Arabic label stays as it is) |
| The merits note | No merits button |
| A recording's label | The zikr's (translated) title, or "Recording 2" |
| A reciter's name | The app's name on the lock screen, nothing in the list |
| Transliteration | Never shown outside English (and its switch is hidden) |

So translating is never all-or-nothing: Dua Ahad can ship with no Urdu at
all and be read in Arabic, and its Urdu added later. Titles are the one
exception - a title has to show something, so an untranslated one stays
English; translate all of a language's titles before shipping it.

Transliteration is the Arabic spelled out in English letters, an aid for
English readers; it is off whenever the translation language is not English,
whatever the reader's own setting (`transliterationShown` in
`lib/services/zikr_translations.dart`).

### Files

A language's zikr translations are laid **over** the corpus at render time.
They never copy the Arabic, so the Arabic proofreading pass and the
restored-zikr work keep going in one place.

```
assets/zikr_i18n/ur/
  index.json      titles, recording labels and reciters
  E1.json         one file per translated zikr, named by its content uid
  A2.json
  ...
```

`index.json`:

```json
{
  "titles": {
    "E1": "دعائے کمیل",
    "G17|L4": "..."
  },
  "audio": {
    "labels": {"quran/shakernejad/surah-001.mp3": "سورہ فاتحہ"},
    "reciters": {"Hamed Shakernejad": "حامد شاکرنژاد"}
  }
}
```

- Search folds what people type one way or another in Arabic script
  (harakat, hamza seats, Arabic/Persian/Urdu ya, kaf and ha, Arabic-Indic
  and Persian digits - `foldSearchText`), so write titles in correct
  orthography; don't strip letters to make them searchable. A surah's
  translated title (`"N: <name>"`) is also the name the Quran screens show
  for it (`SurahInfo.displayName`), without its number.
- `titles` is keyed by the `assets/zikr.json` key, alias keys
  (`"<uid>|<targetUid>"`) included, since an alias's title often differs
  from its canonical's. Translated titles show in lists, search, favorites,
  playlists and the reader; search still matches the English title and
  slugs too.
- `audio.labels` is keyed by a recording's `file` in
  `assets/zikr_audio.json`; `audio.reciters` by the reciter's name as that
  file spells it.

`<uid>.json`, for the uid whose `assets/zikr/<uid>` file holds the content
(an alias's target, a retired uid's redirect target):

```json
{
  "merits": "...the whole merits note, translated as one piece...",
  "segments": {
    "0": "...",
    "1": "...",
    "3": "..."
  }
}
```

### Segments

**A zikr's translation is keyed by segment number, not by its English.** The
reader reads a zikr as a run of segments, numbered `0, 1, 2...` through the
whole zikr, tab after tab:

- each **tab's label**, when the zikr has more than one tab (first in its
  tab);
- each **Arabic verse** - its Arabic line together with the transliteration
  and English translation under it. The verse's translation is drawn where
  its English translation is;
- each **line that stands on its own** - an instruction, a heading, a
  citation. Its translation is drawn in its place.

Keying a verse to the verse, not to its English line, is deliberate: an Urdu
translation translates the Arabic, so correcting the English never orphans
it, and two verses with the same English can be translated differently.
Keep `[label](href)` link markup in a translated line if the English has it.

Lines are classified into Arabic / transliteration / translation from the
corpus, never from translated text, so an Urdu, Persian or Arabic
translation - all in Arabic script - is never mistaken for a verse. Each
translated line is drawn in its language's direction.

### Editing a translated zikr

Numbers shift when a zikr's content changes shape - a restored verse, a
split line, a new instruction. So every translated zikr's segments are
pinned in `scripts/zikr_i18n/segment_anchors.json` (a short fingerprint of
each segment, shared by every language), and `test/zikr_translations_test.dart`
fails when a translated zikr no longer matches. Then run

```sh
python3 scripts/zikr_i18n/zikr_i18n.py rebase
```

which follows the edit - a translation moves with its verse, one whose verse
was removed is dropped (and reported) - in every language, and re-pins the
zikr. Commit the renumbered files and anchors with the content edit. The
fingerprint ignores diacritics and Arabic spelling variants (hamza seats,
Persian/Arabic ya and kaf), so the Arabic proofreading pass does not trip it;
an English instruction that is reworded does, and `rebase` carries its
translation over and asks you to check it.

### Producing and checking zikr translations

`scripts/zikr_i18n/zikr_i18n.py` numbers segments exactly as the app does
(it ports the reader's own line classification; the test checks the two
agree on every translated zikr):

```sh
# One template per zikr - every segment there is somewhere to translate,
# with its Arabic and English for reference, plus merits - merged with
# anything already translated. A verse already translated in another zikr
# (the Bismillah, the salawat) is filled in. Written to
# build/zikr_i18n_templates/ur/ unless --out is given; index.json carries
# titles and recording labels.
python3 scripts/zikr_i18n/zikr_i18n.py template ur
python3 scripts/zikr_i18n/zikr_i18n.py template ur --uids E1 E5 A2

# Coverage and errors in what has shipped: unknown zikrs, segments that do
# not exist or have nothing to translate, zikrs not pinned or changed since.
# Non-zero exit on errors; --strict also fails on untranslated segments.
python3 scripts/zikr_i18n/zikr_i18n.py check -v

# Pin newly translated zikrs, or renumber after a content edit.
python3 scripts/zikr_i18n/zikr_i18n.py rebase

# One-off: convert files in the old English-keyed format
# ({"lines": {"<English line>": "..."}}, and index.json "lines") to segments.
python3 scripts/zikr_i18n/zikr_i18n.py migrate ur fa
```

A worked example is in `docs/zikr_i18n_template/ur/`: the template for
Ziyarat Ashura (`G4.json` - 124 verses and 4 instructions such as "Then say
100 times:", each a numbered segment, plus the merits) and the index entries
that go with it (its title, alias title, recording label and reciter).

Fill in the empty strings and copy the files into `assets/zikr_i18n/<code>/`,
then run `rebase`. Keys starting with `_` in a template (`_reference` - each
segment's Arabic and English - `_englishMerits`, `_englishTitles`) are there
to translate from, and never ship: every file under `assets/zikr_i18n/` is
bundled into the app, and the reference would copy the zikr into it a second
time. `rebase` strips them, along with the empty strings of anything left
untranslated, so a partly translated file is safe to ship; `check` and
`test/zikr_translations_test.dart` fail on any left behind.

### Shipping a language's zikr translations

1. Put the files in `assets/zikr_i18n/<code>/`, including `index.json` -
   its presence is what makes the app offer the language. Translate every
   title first (see "No English outside English").
2. Add `- assets/zikr_i18n/<code>/` to the `assets:` list in
   `pubspec.yaml` (asset folders are not recursive).
   `test/zikr_translations_test.dart` fails if you forget, and also checks
   every file is well-formed, names a real zikr and is pinned.
3. Run `python3 scripts/zikr_i18n/zikr_i18n.py rebase` and then
   `check <code>`.

## Not covered yet

- **A juz** (the Quran read by juz rather than by surah) is assembled from
  the surahs and has no content file of its own, so it has no translation:
  outside English it shows the Arabic alone.
- **Other content**: hadith (`assets/hadith/`), library books, calendar
  events (`assets/events.json`), the Quran collections in `lib/data/`
  (`quran_duas.dart`, prophet stories, verses about Imam Ali and Imam
  al-Mahdi, holy sites) and the What's New notes are English content, not
  UI text, and would each need a translation overlay of their own.
- **Fonts**: Urdu, Persian, Arabic and Gujarati translation text uses the
  platform's system fonts. A bundled Nastaliq font for Urdu would be a
  separate, deliberate choice.
- **Right-to-left polish**: Flutter mirrors layouts automatically for an
  RTL app language, but ~85 spots use left/right-specific padding or
  alignment (`EdgeInsets.only(left:)`, `Alignment.centerLeft`) and should be
  checked once Urdu, Persian or Arabic app text ships.
- **Background isolates**: the Azan alarm callback runs before
  `LanguageProvider` exists, so its media-notification title is English.
- **Flight times** are formatted by hand (`lib/utils/flight_formatting.dart`)
  with English month and weekday abbreviations.
- **Cross-device sync**: both language choices are per device; they are not
  part of the synced reading preferences.
