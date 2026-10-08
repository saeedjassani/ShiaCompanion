"""Templates, checks and upkeep for zikr translations (assets/zikr_i18n/<lang>/).

A translation is keyed by *segment number*, not by English text - see
docs/TRANSLATIONS.md and lib/services/zikr_translations.dart. A zikr is read
as a run of segments, numbered 0, 1, 2... through the whole zikr, tab after
tab:

  - each tab's label, when the zikr has more than one tab (first in its tab);
  - each Arabic verse - its translation translates the Arabic, and is drawn
    where the English translation line is;
  - each line that stands on its own: an instruction, a heading, a citation.

Transliteration is never translated (it is not shown outside English).
This script numbers segments exactly as the app does: it ports
ZikrContentParser's line classification. Keep the two in step.

Because a corpus edit (a restored verse, a split line) can shift the
numbering, every translated zikr's segments are pinned in
scripts/zikr_i18n/segment_anchors.json - one short fingerprint per segment,
shared by every language. test/zikr_translations_test.dart fails when a
translated zikr no longer matches its anchors; `rebase` then renumbers every
language's translation of it to follow the edit and re-pins it.

    # A template per zikr to fill in, merged with what is already
    # translated. Written to build/zikr_i18n_templates/<lang>/ unless --out.
    python3 scripts/zikr_i18n/zikr_i18n.py template ur [--uids A1 E5 ...] [--out DIR]

    # Coverage and problems in the shipped translations. Exits non-zero on
    # errors (bad JSON, unknown uids or segments, unpinned or drifted
    # zikrs); untranslated segments are reported, and fail only with --strict.
    python3 scripts/zikr_i18n/zikr_i18n.py check [ur fa ...] [--strict] [-v]

    # After editing a translated zikr's content: renumber its translations
    # in every language to follow the edit, and re-pin it. Also run it after
    # adding a translation of a zikr nobody had translated before - that pins
    # it.
    python3 scripts/zikr_i18n/zikr_i18n.py rebase

    # One-off: convert files in the old English-keyed format
    # ({"lines": {"<English line>": "..."}}) to segment keys, and pin them.
    python3 scripts/zikr_i18n/zikr_i18n.py migrate ur [fa ...]

A zikr's file:

    {"merits": "...", "segments": {"0": "...", "3": "..."}}

and the language's index.json:

    {"titles": {"<zikr.json key>": "..."},
     "audio": {"labels": {"<zikr_audio.json file>": "..."},
               "reciters": {"<reciter>": "..."}}}

Empty values are ignored by the app, and keys starting with "_" (the
template's English and Arabic for reference) are too.
"""
import argparse
import difflib
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ZIKR_DIR = os.path.join(ROOT, 'assets', 'zikr')
ZIKR_INDEX = os.path.join(ROOT, 'assets', 'zikr.json')
ZIKR_AUDIO = os.path.join(ROOT, 'assets', 'zikr_audio.json')
I18N_DIR = os.path.join(ROOT, 'assets', 'zikr_i18n')
ANCHORS = os.path.join(ROOT, 'scripts', 'zikr_i18n', 'segment_anchors.json')
DEFAULT_OUT = os.path.join(ROOT, 'build', 'zikr_i18n_templates')

# Mirrors lib/l10n/app_language.dart.
LANGUAGES = {'ur', 'fa', 'ar', 'gu'}

# ---------------------------------------------------------------------------
# A port of ZikrContentParser (lib/pages/zikr/zikr_content_parser.dart):
# parseContent's line classification and segments, and segmentOffsets.
# Keep the two in step.
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


def parse_segments(content, hide_header_line):
    """ZikrContentParser.parseContent(...).segments, as dicts:
    {'kind': 'verse', 'arabic', 'english' (None without a translation line)}
    or {'kind': 'line', 'text'}."""
    lines = [line.strip() for line in content.split('\n')]
    if hide_header_line and lines:
        lines = lines[1:]
    arabic = {i for i, line in enumerate(lines) if line and is_arabic(line)}
    has_translit = _has_transliteration(arabic)
    translit, transla, slot_of = set(), set(), {}
    for i in arabic:
        t1 = i + 1 if has_translit else None
        t2 = i + 2 if has_translit else i + 1
        if t1 is not None and t1 < len(lines) and t1 not in arabic:
            translit.add(t1)
        if t2 < len(lines) and t2 not in arabic:
            transla.add(t2)
            slot_of[i] = t2
    segments = []
    for i, line in enumerate(lines):
        if not line or i in translit or i in transla:
            continue
        if i in arabic:
            slot = slot_of.get(i)
            segments.append({'kind': 'verse', 'arabic': line,
                             'english': lines[slot] if slot is not None else None})
        else:
            segments.append({'kind': 'line', 'text': line})
    return segments


def visible_tabs(document):
    """buildVisibleZikrTabContents (lib/pages/zikr/zikr_form_helpers.dart)."""
    primary = document.get('data') or ''
    extra = [tab or '' for tab in (document.get('tabs') or [])]
    tabs = []
    if primary.strip() or all(not tab.strip() for tab in extra):
        tabs.append(primary)
    tabs.extend(tab for tab in extra if tab.strip())
    return tabs


def document_segments(document):
    """Every segment of [document], numbered as the app numbers them (the
    list index is the segment number). A tab label is
    {'kind': 'header', 'text'} (text None for a tab with no lines)."""
    tabs = visible_tabs(document)
    has_headers = len(tabs) > 1
    segments = []
    for tab in tabs:
        if has_headers:
            header = next((l.strip() for l in tab.split('\n') if l.strip()), None)
            segments.append({'kind': 'header', 'text': header})
        segments.extend(parse_segments(tab, hide_header_line=has_headers))
    return segments


def translatable(segment):
    """Whether the app has somewhere to draw a translation of [segment]:
    a verse with a translation line, an English line, an English tab label."""
    if segment['kind'] == 'verse':
        return segment['english'] is not None
    text = segment['text']
    return bool(text) and not is_arabic(text)


def english_of(segment):
    """The English the reader sees for [segment] today, if any."""
    return segment['english'] if segment['kind'] == 'verse' else segment['text']


# ---------------------------------------------------------------------------
# Anchors: one short fingerprint per segment. Mirrored, for the test, by
# segmentAnchor() in test/zikr_translations_test.dart.
# ---------------------------------------------------------------------------

_ARABIC_FOLD = {
    'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ؤ': 'و', 'ئ': 'ي', 'ى': 'ي',
    'ی': 'ي', 'ے': 'ي', 'ې': 'ي', 'ک': 'ك', 'ہ': 'ه', 'ھ': 'ه', 'ة': 'ه',
    'ۃ': 'ه', 'ۀ': 'ه', 'ء': '',
}
ANCHOR_LENGTH = 32


def _fold_arabic(text):
    """Arabic letters only, spelling variants folded together, so the Arabic
    proofreading pass (diacritics, hamza seats, Persian/Arabic ya and kaf)
    does not count as a change."""
    out = []
    for ch in text:
        ch = _ARABIC_FOLD.get(ch, ch)
        if not ch:
            continue
        code = ord(ch)
        if 0x0621 <= code <= 0x063A or 0x0641 <= code <= 0x064A or 0x0671 <= code <= 0x06D3:
            out.append(ch)
    return ''.join(out)


def _fold_english(text):
    return re.sub(r'[^a-z0-9]', '', text.lower())


def anchor(segment):
    if segment['kind'] == 'verse':
        text = segment['arabic']
    else:
        text = segment['text']
        if text is None:
            return 'h:'
    if is_arabic(text):
        return 'a:' + _fold_arabic(text)[:ANCHOR_LENGTH]
    return 'e:' + _fold_english(text)[:ANCHOR_LENGTH]


def anchors_of(document):
    return [anchor(s) for s in document_segments(document)]


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


def shipped_languages():
    if not os.path.isdir(I18N_DIR):
        return []
    return sorted(d for d in os.listdir(I18N_DIR)
                  if os.path.isdir(os.path.join(I18N_DIR, d)))


def translation_files(lang):
    """uid -> path of each zikr translation shipped for [lang]."""
    lang_dir = os.path.join(I18N_DIR, lang)
    if not os.path.isdir(lang_dir):
        return {}
    return {
        name[:-len('.json')]: os.path.join(lang_dir, name)
        for name in sorted(os.listdir(lang_dir))
        if name.endswith('.json') and name != 'index.json'
    }


def translated_uids():
    uids = set()
    for lang in shipped_languages():
        uids.update(translation_files(lang))
    return uids


def load_anchors():
    return load_json(ANCHORS) if os.path.exists(ANCHORS) else {}


def write_anchors(anchors):
    write_json(ANCHORS, {uid: anchors[uid] for uid in sorted(anchors)})


def audio_index():
    return load_json(ZIKR_AUDIO) if os.path.exists(ZIKR_AUDIO) else {}


def ordered_segments(mapping):
    """[mapping] with its segment keys in numeric order."""
    return dict(sorted(mapping.items(), key=lambda kv: int(kv[0])
                       if str(kv[0]).isdigit() else -1))


# ---------------------------------------------------------------------------
# template
# ---------------------------------------------------------------------------


def _translation_memory(lang, docs):
    """Folded Arabic -> a translation of it already shipped in [lang], so a
    verse many zikrs share (the Bismillah, the salawat) is translated once."""
    memory = {}
    for uid, path in translation_files(lang).items():
        doc = docs.get(uid)
        if doc is None:
            continue
        done = load_json(path).get('segments', {})
        for number, segment in enumerate(document_segments(doc)):
            text = (done.get(str(number)) or '').strip()
            if text and segment['kind'] == 'verse':
                memory.setdefault(_fold_arabic(segment['arabic']), text)
    return memory


def cmd_template(args):
    lang = args.language
    if lang not in LANGUAGES:
        sys.exit(f'Unknown language {lang!r}; expected one of {sorted(LANGUAGES)}')
    docs = corpus()
    uids = args.uids or list(docs)
    out = os.path.join(args.out or DEFAULT_OUT, lang)
    shipped_dir = os.path.join(I18N_DIR, lang)
    memory = _translation_memory(lang, docs)

    index_path = os.path.join(shipped_dir, 'index.json')
    shipped_index = load_json(index_path) if os.path.exists(index_path) else {}
    shipped_titles = shipped_index.get('titles', {})
    shipped_audio = shipped_index.get('audio', {})
    zikr_index = load_json(ZIKR_INDEX)
    titles, english_titles = {}, {}
    for key, entry in zikr_index.items():
        if not (isinstance(entry, dict) and entry.get('title')):
            continue
        if args.uids and key.split('|')[-1] not in uids and key not in uids:
            continue
        titles[key] = shipped_titles.get(key, '')
        english_titles[key] = entry['title']
    labels, english_labels, reciters = {}, {}, {}
    for uid, tracks in audio_index().items():
        if args.uids and uid not in uids:
            continue
        for track in tracks:
            if track.get('label'):
                labels[track['file']] = shipped_audio.get('labels', {}).get(track['file'], '')
                english_labels[track['file']] = track['label']
            if track.get('reciter'):
                reciters[track['reciter']] = shipped_audio.get(
                    'reciters', {}).get(track['reciter'], '')
    write_json(os.path.join(out, 'index.json'), {
        '_englishTitles': english_titles,
        'titles': titles,
        'audio': {
            '_englishLabels': english_labels,
            'labels': labels,
            'reciters': reciters,
        },
    })

    written = 0
    for uid in uids:
        doc = docs.get(uid)
        if doc is None:
            print(f'skipping {uid}: no assets/zikr/{uid}', file=sys.stderr)
            continue
        shipped_path = os.path.join(shipped_dir, f'{uid}.json')
        shipped = load_json(shipped_path) if os.path.exists(shipped_path) else {}
        done = shipped.get('segments', {})
        template = {}
        english_merits = (doc.get('merits') or '').strip()
        if english_merits:
            template['_englishMerits'] = english_merits
            template['merits'] = shipped.get('merits', '')
        reference, segments = {}, {}
        for number, segment in enumerate(document_segments(doc)):
            if not translatable(segment):
                continue
            key = str(number)
            ref = {'en': english_of(segment)}
            if segment['kind'] == 'verse':
                ref = {'ar': segment['arabic'], **ref}
            reference[key] = ref
            value = done.get(key, '')
            if not value and segment['kind'] == 'verse':
                value = memory.get(_fold_arabic(segment['arabic']), '')
            segments[key] = value
        template['_reference'] = reference
        template['segments'] = segments
        write_json(os.path.join(out, f'{uid}.json'), template)
        written += 1
    print(f'Wrote {written} zikr template(s) and index.json to {out}')
    print('Keys starting with "_" are reference only; the app ignores them.')
    print('Drop the "_" keys (or not) and copy into assets/zikr_i18n/'
          f'{lang}/, then run `rebase` to pin the new zikrs.')


# ---------------------------------------------------------------------------
# check
# ---------------------------------------------------------------------------


def _is_string_map(table):
    return isinstance(table, dict) and all(
        isinstance(k, str) and isinstance(v, str) for k, v in table.items())


def cmd_check(args):
    languages = args.languages or shipped_languages()
    if not languages:
        print('No assets/zikr_i18n/ languages yet - nothing to check.')
        return 0
    docs = corpus()
    index_keys = set(load_json(ZIKR_INDEX))
    audio = audio_index()
    audio_files = {t['file'] for tracks in audio.values() for t in tracks}
    audio_reciters = {t['reciter'] for tracks in audio.values() for t in tracks
                      if t.get('reciter')}
    pinned = load_anchors()
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

    print('[anchors]')
    for uid in sorted(translated_uids()):
        doc = docs.get(uid)
        if doc is None:
            continue
        if uid not in pinned:
            error(f'{uid}: translated but not pinned - run `zikr_i18n.py rebase`')
        elif pinned[uid] != anchors_of(doc):
            error(f'{uid}: content changed since its translations were made - '
                  'run `zikr_i18n.py rebase`')

    for lang in languages:
        print(f'[{lang}]')
        lang_dir = os.path.join(I18N_DIR, lang)
        if lang not in LANGUAGES:
            error(f'{lang}: not a language the app knows (lib/l10n/app_language.dart)')
        index_path = os.path.join(lang_dir, 'index.json')
        if not os.path.exists(index_path):
            error('index.json is missing - the app will not offer this language')
        else:
            try:
                index = load_json(index_path)
            except ValueError as e:
                error(f'index.json: invalid JSON: {e}')
                index = {}
            if 'lines' in index:
                error('index.json: "lines" is the old English-keyed format - '
                      'run `zikr_i18n.py migrate`')
            titles = index.get('titles', {})
            audio_table = index.get('audio', {})
            if not isinstance(audio_table, dict):
                error('index.json: "audio" must be an object')
                audio_table = {}
            labels = audio_table.get('labels', {})
            reciters = audio_table.get('reciters', {})
            for name, table in (('titles', titles), ('audio.labels', labels),
                                ('audio.reciters', reciters)):
                if not _is_string_map(table):
                    error(f'index.json: "{name}" must map strings to strings')
            for key in titles:
                if key not in index_keys:
                    error(f'index.json: title for unknown zikr.json key {key!r}')
            for key in labels:
                if key not in audio_files:
                    error(f'index.json: label for unknown recording {key!r}')
            for key in reciters:
                if key not in audio_reciters:
                    error(f'index.json: unknown reciter {key!r}')
            done_titles = sum(1 for v in titles.values() if v.strip())
            print(f'  titles: {done_titles}/{len(index_keys)}')
            labelled = {t['file'] for tracks in audio.values() for t in tracks
                        if t.get('label')}
            done_labels = sum(1 for k in labelled if (labels.get(k) or '').strip())
            print(f'  audio labels: {done_labels}/{len(labelled)}, reciters: '
                  f'{sum(1 for v in reciters.values() if v.strip())}/{len(audio_reciters)}')
            if done_titles < len(index_keys):
                warn(f'{len(index_keys) - done_titles} titles untranslated')

        files = translation_files(lang)
        seg_total = seg_done = 0
        for uid, path in files.items():
            name = os.path.basename(path)
            doc = docs.get(uid)
            if doc is None:
                error(f'{name}: no assets/zikr/{uid} to translate')
                continue
            try:
                translation = load_json(path)
            except ValueError as e:
                error(f'{name}: invalid JSON: {e}')
                continue
            if 'lines' in translation:
                error(f'{name}: "lines" is the old English-keyed format - '
                      'run `zikr_i18n.py migrate`')
            segments = translation.get('segments', {})
            if not _is_string_map(segments):
                error(f'{name}: "segments" must map segment numbers to strings')
                continue
            merits = translation.get('merits')
            if merits is not None and not isinstance(merits, str):
                error(f'{name}: "merits" must be a string')
            doc_segments = document_segments(doc)
            for key in segments:
                if not key.isdigit() or int(key) >= len(doc_segments):
                    error(f'{name}: no segment {key!r} (it has {len(doc_segments)})')
                elif not translatable(doc_segments[int(key)]):
                    error(f'{name}: segment {key} has nothing to translate '
                          f'({anchor(doc_segments[int(key)])[:40]!r})')
            wanted = [str(n) for n, s in enumerate(doc_segments) if translatable(s)]
            done = sum(1 for k in wanted if (segments.get(k) or '').strip())
            seg_total += len(wanted)
            seg_done += done
            if done < len(wanted):
                warn(f'{name}: {len(wanted) - done} of {len(wanted)} segments untranslated')
            if (doc.get('merits') or '').strip() and not (merits or '').strip():
                warn(f'{name}: merits untranslated')
        print(f'  zikrs: {len(files)}/{len(docs)} with a file; '
              f'segments in those: {seg_done}/{seg_total} translated')

    print(f'{errors} error(s), {warnings} warning(s)'
          + ('' if args.verbose or args.strict else ' (-v to list warnings)'))
    if errors or (args.strict and warnings):
        return 1
    return 0


# ---------------------------------------------------------------------------
# rebase
# ---------------------------------------------------------------------------


def _renumbering(old, new):
    """Old segment number -> new, following the edit that turned anchor list
    [old] into [new]; and the old numbers whose segment changed in place
    (carried over, but worth a look)."""
    mapping, changed = {}, []
    matcher = difflib.SequenceMatcher(a=old, b=new, autojunk=False)
    for op, a0, a1, b0, b1 in matcher.get_opcodes():
        if op == 'equal' or (op == 'replace' and a1 - a0 == b1 - b0):
            for k in range(a1 - a0):
                mapping[a0 + k] = b0 + k
                if op == 'replace':
                    changed.append(a0 + k)
    return mapping, changed


def cmd_rebase(args):
    docs = corpus()
    pinned = load_anchors()
    uids = translated_uids()
    problems = 0
    for uid in sorted(uids | set(pinned)):
        doc = docs.get(uid)
        if doc is None or uid not in uids:
            pinned.pop(uid, None)
            continue
        current = anchors_of(doc)
        old = pinned.get(uid)
        if old is None:
            print(f'{uid}: pinned')
            pinned[uid] = current
            continue
        if old == current:
            continue
        mapping, changed = _renumbering(old, current)
        segments = document_segments(doc)
        for lang in shipped_languages():
            path = translation_files(lang).get(uid)
            if path is None:
                continue
            translation = load_json(path)
            renumbered = {}
            for key, value in translation.get('segments', {}).items():
                if not key.isdigit():
                    continue
                target = mapping.get(int(key))
                if target is None or not translatable(segments[target]):
                    if value.strip():
                        problems += 1
                        print(f'{lang}/{uid}: dropped segment {key} - its '
                              f'{old[int(key)][:40]!r} is gone')
                    continue
                if int(key) in changed and value.strip():
                    print(f'{lang}/{uid}: segment {key} -> {target} changed in '
                          f'place, check it: now {current[target][:40]!r}')
                renumbered[str(target)] = value
            translation['segments'] = ordered_segments(renumbered)
            write_json(path, translation)
        print(f'{uid}: renumbered ({len(old)} -> {len(current)} segments)')
        pinned[uid] = current
    write_anchors(pinned)
    print(f'Pinned {len(pinned)} translated zikr(s) in '
          f'{os.path.relpath(ANCHORS, ROOT)}'
          + (f'; {problems} translation(s) dropped' if problems else ''))
    return 0


# ---------------------------------------------------------------------------
# migrate
# ---------------------------------------------------------------------------


def cmd_migrate(args):
    docs = corpus()
    for lang in args.languages:
        lang_dir = os.path.join(I18N_DIR, lang)
        index_path = os.path.join(lang_dir, 'index.json')
        index = load_json(index_path) if os.path.exists(index_path) else {}
        shared = index.pop('lines', {}) or {}
        if os.path.exists(index_path):
            write_json(index_path, index)
        moved = left = 0
        for uid, path in translation_files(lang).items():
            doc = docs.get(uid)
            translation = load_json(path)
            lines = translation.pop('lines', None)
            if lines is None or doc is None:
                continue
            segments = dict(translation.get('segments', {}))
            used = set()
            for number, segment in enumerate(document_segments(doc)):
                if not translatable(segment) or segments.get(str(number)):
                    continue
                english = (english_of(segment) or '').strip()
                value = lines.get(english) or shared.get(english) or ''
                if value.strip():
                    segments[str(number)] = value
                    used.add(english)
                    moved += 1
            left += sum(1 for k, v in lines.items() if v.strip() and k not in used)
            translation['segments'] = ordered_segments(segments)
            write_json(path, translation)
        print(f'[{lang}] {moved} segment(s) migrated; {left} English-keyed '
              'line(s) matched nothing and were dropped')
    return cmd_rebase(args)


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
    sub.add_parser('rebase', help='renumber translations after a corpus edit, and pin them')
    m = sub.add_parser('migrate', help='convert English-keyed files to segment keys')
    m.add_argument('languages', nargs='+')
    args = parser.parse_args()
    if args.command == 'template':
        cmd_template(args)
        return 0
    if args.command == 'rebase':
        return cmd_rebase(args)
    if args.command == 'migrate':
        return cmd_migrate(args)
    return cmd_check(args)


if __name__ == '__main__':
    sys.exit(main())
