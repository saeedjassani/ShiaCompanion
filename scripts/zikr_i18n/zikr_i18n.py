"""Templates and checks for zikr translations (assets/zikr_i18n/<lang>/).

The app lays a translation over a zikr's English at render time, matching
each English line by its exact (trimmed) text - see
lib/services/zikr_translations.dart and docs/TRANSLATIONS.md. This script
knows which lines those are, the same way the app does: it classifies every
line of `data` and each `tabs[]` entry as Arabic, transliteration,
translation or a standalone line exactly as ZikrContentParser does, and
offers the translation and standalone lines (plus each tab's header line)
for translating. Arabic and transliteration are never translated.

    # A template per zikr to fill in, merged with anything already
    # translated. Written to build/zikr_i18n_templates/<lang>/ unless --out.
    python3 scripts/zikr_i18n/zikr_i18n.py template ur [--uids A1 E5 ...] [--out DIR]

    # Coverage and staleness of the shipped translations - every language
    # under assets/zikr_i18n/, or just the ones named. Exits non-zero on
    # structural errors (bad JSON, unknown uids, wrong value types); stale
    # or missing lines are reported but are not errors unless --strict.
    python3 scripts/zikr_i18n/zikr_i18n.py check [ur fa ...] [--strict] [-v]

A template file has the shape the app reads, with empty strings where a
translation is still needed:

    {"merits": "", "lines": {"<English line>": ""}}

and the language's index template:

    {"titles": {"<zikr.json key>": ""}, "lines": {}}

Empty values are ignored by the app (that line simply stays English), so a
partly filled file is safe to ship. Before shipping, add the language folder
to pubspec.yaml's assets (see docs/TRANSLATIONS.md).
"""
import argparse
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ZIKR_DIR = os.path.join(ROOT, 'assets', 'zikr')
ZIKR_INDEX = os.path.join(ROOT, 'assets', 'zikr.json')
I18N_DIR = os.path.join(ROOT, 'assets', 'zikr_i18n')
DEFAULT_OUT = os.path.join(ROOT, 'build', 'zikr_i18n_templates')

# Mirrors lib/l10n/app_language.dart.
LANGUAGES = {'ur', 'fa', 'ar', 'gu'}

# ---------------------------------------------------------------------------
# A port of ZikrContentParser.parseContent's line classification
# (lib/pages/zikr/zikr_content_parser.dart). Keep the two in step.
# ---------------------------------------------------------------------------

_ARABIC_RANGES = (
    (0x0600, 0x06FF),
    (0x0750, 0x077F),
    (0x08A0, 0x08FF),
    (0xFB50, 0xFDFF),
    (0xFE70, 0xFEFF),
)


def is_arabic(line):
    for scanned, ch in enumerate(line):
        if scanned >= 35:
            break
        code = ord(ch)
        if any(lo <= code <= hi for lo, hi in _ARABIC_RANGES):
            return True
    return False


def _has_transliteration(arabic_indexes):
    ordered = sorted(arabic_indexes)
    two = three = 0
    for prev, cur in zip(ordered, ordered[1:]):
        gap = cur - prev
        if gap == 2:
            two += 1
        if gap == 3:
            three += 1
    return two <= three


def translatable_lines(content, hide_header_line):
    """The trimmed lines of [content] a translation may replace, in order:
    translation lines and standalone lines - never Arabic or
    transliteration."""
    lines = [line.strip() for line in content.split('\n')]
    if hide_header_line and lines:
        lines = lines[1:]
    arabic = {i for i, line in enumerate(lines) if line and is_arabic(line)}
    translit = set()
    if _has_transliteration(arabic):
        for i in arabic:
            if i + 1 < len(lines) and (i + 1) not in arabic:
                translit.add(i + 1)
    return [
        line for i, line in enumerate(lines)
        if line and i not in arabic and i not in translit
    ]


def visible_tabs(document):
    """buildVisibleZikrTabContents (lib/pages/zikr/zikr_form_helpers.dart)."""
    primary = document.get('data') or ''
    extra = [tab or '' for tab in (document.get('tabs') or [])]
    tabs = []
    if primary.strip() or all(not tab.strip() for tab in extra):
        tabs.append(primary)
    tabs.extend(tab for tab in extra if tab.strip())
    return tabs


def english_lines(document):
    """Every English line of [document] the app may look a translation up
    for, de-duplicated, in reading order."""
    tabs = visible_tabs(document)
    has_headers = len(tabs) > 1
    seen = []
    for tab in tabs:
        if has_headers:
            # The tab's label: its first non-empty line, shown in the tab
            # strip and looked up like any other line.
            header = next((l.strip() for l in tab.split('\n') if l.strip()), '')
            if header and not is_arabic(header) and header not in seen:
                seen.append(header)
        for line in translatable_lines(tab, hide_header_line=has_headers):
            if line not in seen:
                seen.append(line)
    return seen


# ---------------------------------------------------------------------------


def load_json(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')


def corpus():
    """uid -> content document, for every file in assets/zikr/."""
    return {
        uid: load_json(os.path.join(ZIKR_DIR, uid))
        for uid in sorted(os.listdir(ZIKR_DIR))
        if not uid.startswith('.')
    }


def zikr_index():
    return load_json(ZIKR_INDEX)


def cmd_template(args):
    lang = args.language
    if lang not in LANGUAGES:
        sys.exit(f'Unknown language {lang!r}; expected one of {sorted(LANGUAGES)}')
    docs = corpus()
    uids = args.uids or list(docs)
    out = os.path.join(args.out or DEFAULT_OUT, lang)
    shipped_dir = os.path.join(I18N_DIR, lang)

    index_path = os.path.join(shipped_dir, 'index.json')
    shipped_index = load_json(index_path) if os.path.exists(index_path) else {}
    shipped_titles = shipped_index.get('titles', {})
    titles = {}
    for key, entry in zikr_index().items():
        if isinstance(entry, dict) and entry.get('title'):
            if args.uids and key.split('|')[-1] not in uids and key not in uids:
                continue
            titles[key] = shipped_titles.get(key, '')
    write_json(os.path.join(out, 'index.json'), {
        '_english': {k: zikr_index()[k]['title'] for k in titles},
        'titles': titles,
        'lines': shipped_index.get('lines', {}),
    })

    written = 0
    for uid in uids:
        doc = docs.get(uid)
        if doc is None:
            print(f'skipping {uid}: no assets/zikr/{uid}', file=sys.stderr)
            continue
        shipped_path = os.path.join(shipped_dir, f'{uid}.json')
        shipped = load_json(shipped_path) if os.path.exists(shipped_path) else {}
        done = shipped.get('lines', {})
        template = {}
        english_merits = (doc.get('merits') or '').strip()
        if english_merits:
            template['_englishMerits'] = english_merits
            template['merits'] = shipped.get('merits', '')
        template['lines'] = {line: done.get(line, '') for line in english_lines(doc)}
        write_json(os.path.join(out, f'{uid}.json'), template)
        written += 1
    print(f'Wrote {written} zikr template(s) and index.json to {out}')
    print('Keys starting with "_" are reference only; the app ignores them.')


def cmd_check(args):
    if not os.path.isdir(I18N_DIR):
        print('No assets/zikr_i18n/ yet - nothing to check.')
        return 0
    languages = args.languages or sorted(
        d for d in os.listdir(I18N_DIR) if os.path.isdir(os.path.join(I18N_DIR, d)))
    docs = corpus()
    index_keys = set(zikr_index())
    errors = warnings = 0

    def error(msg):
        nonlocal errors
        errors += 1
        print(f'  ERROR {msg}')

    def warn(msg):
        nonlocal warnings
        warnings += 1
        if args.verbose or args.strict:
            print(f'  warn  {msg}')

    for lang in languages:
        print(f'[{lang}]')
        lang_dir = os.path.join(I18N_DIR, lang)
        if lang not in LANGUAGES:
            error(f'{lang}: not a language the app knows (lib/l10n/app_language.dart)')
        index_path = os.path.join(lang_dir, 'index.json')
        shared = {}
        if not os.path.exists(index_path):
            error('index.json is missing - the app will not offer this language')
        else:
            try:
                index = load_json(index_path)
            except ValueError as e:
                error(f'index.json: invalid JSON: {e}')
                index = {}
            titles = index.get('titles', {})
            shared = index.get('lines', {})
            for name, table in (('titles', titles), ('lines', shared)):
                if not isinstance(table, dict) or not all(
                        isinstance(k, str) and isinstance(v, str) for k, v in table.items()):
                    error(f'index.json: "{name}" must map strings to strings')
            for key in titles:
                if key not in index_keys:
                    error(f'index.json: title for unknown zikr.json key {key!r}')
            translated_titles = sum(1 for v in titles.values() if v.strip())
            print(f'  titles: {translated_titles}/{len(index_keys)}')

        all_english = set()
        files = sorted(f for f in os.listdir(lang_dir) if f.endswith('.json') and f != 'index.json')
        line_total = line_done = 0
        for name in files:
            uid = name[:-len('.json')]
            path = os.path.join(lang_dir, name)
            doc = docs.get(uid)
            if doc is None:
                error(f'{name}: no assets/zikr/{uid} to translate')
                continue
            try:
                translation = load_json(path)
            except ValueError as e:
                error(f'{name}: invalid JSON: {e}')
                continue
            lines = translation.get('lines', {})
            if not isinstance(lines, dict) or not all(
                    isinstance(k, str) and isinstance(v, str) for k, v in lines.items()):
                error(f'{name}: "lines" must map strings to strings')
                continue
            merits = translation.get('merits')
            if merits is not None and not isinstance(merits, str):
                error(f'{name}: "merits" must be a string')
            english = english_lines(doc)
            all_english.update(english)
            wanted = set(english)
            for key in lines:
                if key.strip() not in wanted:
                    warn(f'{name}: no English line matches {key[:70]!r} (stale?)')
            done = sum(1 for line in english
                       if (lines.get(line) or shared.get(line) or '').strip())
            line_total += len(english)
            line_done += done
            if done < len(english):
                warn(f'{name}: {len(english) - done} of {len(english)} lines untranslated')
            if (doc.get('merits') or '').strip() and not (merits or '').strip():
                warn(f'{name}: merits untranslated')
        for key in shared:
            if all_english and key not in all_english and not any(
                    key in english_lines(d) for d in docs.values()):
                warn(f'index.json: shared line matches no zikr {key[:70]!r}')
        print(f'  zikrs: {len(files)}/{len(docs)} with a file; '
              f'lines in those: {line_done}/{line_total} translated')

    print(f'{errors} error(s), {warnings} warning(s)'
          + ('' if args.verbose or args.strict else ' (-v to list warnings)'))
    if errors or (args.strict and warnings):
        return 1
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    t = sub.add_parser('template', help='write translation templates for a language')
    t.add_argument('language')
    t.add_argument('--uids', nargs='+')
    t.add_argument('--out')
    c = sub.add_parser('check', help='report coverage and problems in shipped translations')
    c.add_argument('languages', nargs='*')
    c.add_argument('--strict', action='store_true')
    c.add_argument('-v', '--verbose', action='store_true')
    args = parser.parse_args()
    if args.command == 'template':
        cmd_template(args)
        return 0
    return cmd_check(args)


if __name__ == '__main__':
    sys.exit(main())
