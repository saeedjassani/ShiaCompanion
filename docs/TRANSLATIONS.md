# Translations

The app is prepared for **Urdu (`ur`), Persian (`fa`), Arabic (`ar`) and
Gujarati (`gu`)** alongside English. Nothing is translated yet: until a
language ships files of its own, the app looks and behaves exactly as it
always has, and no language picker appears anywhere.

There are two independent things to translate, each with its own files:

| What | Where | Picked in Settings as |
| --- | --- | --- |
| **App text** - menus, buttons, settings, dialogs, notifications | `lib/l10n/app_<code>.arb` | App language |
| **Zikr content** - each dua's translation lines, instructions, merits and title | `assets/zikr_i18n/<code>/` | Translation language |

They are separate because readers need them separately: many want English
menus but a dua's meaning in Urdu. The translation language follows the app
language until the reader picks one of their own. Either side can ship
without the other, and a language is offered in a picker only once its files
exist. Anything not translated - a missing ARB key, a zikr line nobody has
done yet - simply shows in English.

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
3. Run `flutter gen-l10n` (or any `flutter run`/`build`, which does it too)
   and commit the regenerated `lib/l10n/app_localizations*.dart`.
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

## Zikr content (`assets/zikr_i18n/<code>/`)

A language's zikr translations are laid **over** the English corpus at render
time. They never copy the Arabic or the transliteration, so the Arabic
proofreading pass and the restored-zikr work keep going in one place.

```
assets/zikr_i18n/ur/
  index.json      titles, and lines shared across the corpus
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
  "lines": {
    "In the Name of Allah, the All-beneficent, the All-merciful": "..."
  }
}
```

- `titles` is keyed by the `assets/zikr.json` key, alias keys
  (`"<uid>|<targetUid>"`) included, since an alias's title often differs
  from its canonical's. Translated titles show in lists, search, favorites
  and the reader; search still matches the English title and slugs too.
- `lines` translates a line once for every zikr it appears in (the
  Bismillah, the salawat).

`<uid>.json`, for the uid whose `assets/zikr/<uid>` file holds the content
(an alias's target, a retired uid's redirect target):

```json
{
  "merits": "...the whole merits note, translated as one piece...",
  "lines": {
    "O Allah, bless Muhammad and his Household": "...",
    "Recite the following three times:": "..."
  }
}
```

**Lines are matched by their English text, not by position.** Each key is
an English line exactly as it appears in the zikr's `data` or `tabs`
(trimmed): a translation line under an Arabic verse, a standalone line
(instruction, heading, citation), or a tab's header line. The corpus is
still being edited, and an inserted verse would shift every positional
translation after it onto the wrong line; matched by text, an English line
that later changes just shows in English until its translation is updated.
A zikr's own `lines` win over the shared ones. Keep `[label](href)` link
markup in a translated line if the English has it.

Lines are matched against the English *after* the app has sorted them into
Arabic / transliteration / translation, so an Urdu, Persian or Arabic
translation - all in Arabic script - is never mistaken for a verse. Each
translated line is drawn in its language's direction; untranslated English
stays left-to-right even when the app itself is right-to-left.

### Producing and checking zikr translations

`scripts/zikr_i18n/zikr_i18n.py` knows exactly which lines the app will
look up (it ports the reader's own line classification, and agrees with it
on all 683 zikrs):

```sh
# One template per zikr - the English lines to translate, plus merits -
# merged with anything already translated. Written to
# build/zikr_i18n_templates/ur/ unless --out is given.
python3 scripts/zikr_i18n/zikr_i18n.py template ur
python3 scripts/zikr_i18n/zikr_i18n.py template ur --uids E1 E5 A2

# Coverage, stale keys (English that has since changed) and structural
# errors in what has shipped. Non-zero exit on errors; --strict also fails
# on stale or untranslated lines.
python3 scripts/zikr_i18n/zikr_i18n.py check -v
```

Fill in the empty strings and copy the files into `assets/zikr_i18n/<code>/`.
Keys starting with `_` in a template (`_english`, `_englishMerits`) are
reference only and ignored by the app; empty values are ignored too, so a
partly translated file is safe to ship.

### Shipping a language's zikr translations

1. Put the files in `assets/zikr_i18n/<code>/`, including `index.json` -
   its presence is what makes the app offer the language.
2. Add `- assets/zikr_i18n/<code>/` to the `assets:` list in
   `pubspec.yaml` (asset folders are not recursive).
   `test/zikr_translations_test.dart` fails if you forget, and also checks
   every file is well-formed and names a real zikr.
3. Run `python3 scripts/zikr_i18n/zikr_i18n.py check <code>`.

## Not covered yet

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
