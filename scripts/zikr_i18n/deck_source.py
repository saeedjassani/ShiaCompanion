"""Draft a zikr translation from a published source that pairs each Arabic
phrase with its translation - a duas.org PowerPoint deck (Arabic / English /
Urdu / Hindi, one phrase per slide) - aligned to our segments through the
Arabic.

The source's lines rarely break where our segments do, so the alignment is
only a worksheet: dividing one source line's translation between two of our
segments, catching a deck that put a line's Urdu on the neighbouring slide,
and translating instructions, all need a person (or a careful model) reading
the Arabic. Never ship a mechanical cut - that is what made the first duas.pro
batch inaccurate.

    # 1. The deck's rows: Arabic and translation per slide. Convert .ppt/.pps
    #    first: soffice --headless --convert-to pptx deck.ppt
    python3 scripts/zikr_i18n/deck_source.py rows deck.pptx rows.json

    # 2. A worksheet for one zikr: groups of our segments and the rows their
    #    Arabic matched (one / split / none / line - see align()).
    python3 scripts/zikr_i18n/deck_source.py align E31 rows.json work.json

    # 3. Write the draft (format below) from the worksheet, then check it.
    python3 scripts/zikr_i18n/deck_source.py validate E31 draft.json

    # 4. Ship it: applies any proposed line splits to assets/zikr/<uid> and
    #    writes assets/zikr_i18n/<lang>/<uid>.json under the new numbering.
    python3 scripts/zikr_i18n/deck_source.py apply E31 draft.json --lang ur
    python3 scripts/zikr_i18n/zikr_i18n.py rebase

A draft:

    {"segments": {"0": "...", "1": "..."},
     "splits": [{"n": 12, "parts": [{"ar", "tr", "en", "<lang>"}, ...]}],
     "own": [5, 96],
     "notes": ["..."]}

`splits` breaks one of our verses into several where the source does, when
its transliteration and English break at the same point: the parts must
rejoin to the original lines exactly (English compared letters and digits
only), so a split re-breaks lines and never changes the text. `own` lists
segments translated by us rather than taken from the source (instructions,
a phrase the source skipped); `notes` records typo fixes and the like.
"""
import argparse
import collections
import difflib
import html
import json
import os
import re
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zikr_i18n as z  # noqa: E402

# ---------------------------------------------------------------------------
# rows
# ---------------------------------------------------------------------------

_HARAKAT = re.compile('[ً-ْٰ]')
_AR_LETTER = re.compile('[ء-يٱ-ۓ]')
_LATIN = re.compile('[A-Za-z]')


def _slide_paragraphs(path):
    deck = zipfile.ZipFile(path)
    names = sorted(
        (n for n in deck.namelist() if re.match(r'ppt/slides/slide\d+\.xml$', n)),
        key=lambda n: int(re.search(r'(\d+)', n.split('/')[-1]).group(1)))
    slides = []
    for name in names:
        xml = deck.read(name).decode('utf-8')
        paragraphs = []
        for p in re.findall(r'<a:p>.*?</a:p>|<a:p .*?</a:p>', xml, re.S):
            runs = [html.unescape(t) for t in re.findall(r'<a:t>(.*?)</a:t>', p, re.S)]
            if any(r.strip() for r in runs):
                paragraphs.append(runs)
        slides.append(paragraphs)
    return slides


def _script(text):
    """'ar' for vowelled Arabic, 'translation' for Arabic-script text with
    few harakat (the Urdu or Persian), 'lat' for Latin, else None."""
    letters = len(_AR_LETTER.findall(text))
    latin = len(_LATIN.findall(text))
    if letters >= 2 and letters >= latin:
        return 'ar' if len(_HARAKAT.findall(text)) / letters >= 0.3 else 'translation'
    return 'lat' if latin >= 2 else None


def _pieces(runs):
    """A paragraph as (script, text) pieces. Some decks put every language
    of a slide in one paragraph, one run each."""
    pieces = []
    for run in runs:
        script = _script(run) if run.strip() else None
        if script is None:
            if pieces:
                pieces[-1][1] += run
        elif pieces and pieces[-1][0] == script:
            pieces[-1][1] += run
        else:
            pieces.append([script, run])
    if len({s for s, _ in pieces}) <= 1:
        whole = ''.join(runs)
        script = _script(whole)
        return [[script, whole]] if script else []
    return pieces


def deck_rows(path):
    slides = _slide_paragraphs(path)
    seen = collections.Counter()
    for paragraphs in slides:
        for text in {''.join(r).strip() for r in paragraphs}:
            seen[text] += 1
    # Deck titles and footers repeat on most slides and already sit on the
    # first ones; a refrain repeats too, but never on the title slides.
    early = {''.join(r).strip() for paragraphs in slides[:3] for r in paragraphs}
    boilerplate = {t for t, k in seen.items()
                   if k > max(3, len(slides) * 0.15) and t in early}
    rows = []
    for number, paragraphs in enumerate(slides, 1):
        found = {'ar': [], 'translation': [], 'lat': []}
        for runs in paragraphs:
            if ''.join(runs).strip() in boilerplate:
                continue
            for script, text in _pieces(runs):
                text = ' '.join(text.split())
                if text:
                    found[script].append(text)
        if found['ar'] or found['translation']:
            rows.append({'slide': number, 'ar': ' '.join(found['ar']),
                         'translation': ' '.join(found['translation']),
                         'other': ' / '.join(found['lat'])})
    return rows


def cmd_rows(args):
    rows = deck_rows(args.deck)
    z.write_json(args.out, rows)
    print(f'{len(rows)} rows, {sum(1 for r in rows if r["ar"] and r["translation"])} '
          f'with Arabic and a translation -> {args.out}')


# ---------------------------------------------------------------------------
# Our segments, with each verse's transliteration and raw line position
# ---------------------------------------------------------------------------


def _tab_keys(doc):
    """('data', None) / ('tabs', i) for each tab visible_tabs() keeps."""
    extra = doc.get('tabs') or []
    keys = []
    if (doc.get('data') or '').strip() or all(not (t or '').strip() for t in extra):
        keys.append(('data', None))
    keys.extend(('tabs', i) for i, t in enumerate(extra) if (t or '').strip())
    return keys


def _tab_text(doc, key):
    return doc['data'] if key[0] == 'data' else doc['tabs'][key[1]]


def verse_lines(doc):
    """For each segment (numbered as document_segments), None or, for a
    verse, (tab key, raw line index of its Arabic, transliteration or None).
    Mirrors parse_segments."""
    keys = _tab_keys(doc)
    has_headers = len(keys) > 1
    out = []
    for key in keys:
        lines = [line.strip() for line in _tab_text(doc, key).split('\n')]
        offset = 1 if has_headers and lines else 0
        if has_headers:
            out.append(None)
        body = lines[offset:]
        arabic = {i for i, line in enumerate(body) if line and z.is_arabic(line)}
        has_translit = z._has_transliteration(arabic)
        translit, transla, translit_of = set(), set(), {}
        for i in arabic:
            t1 = i + 1 if has_translit else None
            t2 = i + 2 if has_translit else i + 1
            if t1 is not None and t1 < len(body) and t1 not in arabic:
                translit.add(t1)
                translit_of[i] = body[t1]
            if t2 < len(body) and t2 not in arabic:
                transla.add(t2)
        for i, line in enumerate(body):
            if not line or i in translit or i in transla:
                continue
            out.append((key, i + offset, translit_of.get(i)) if i in arabic else None)
    assert len(out) == len(z.document_segments(doc))
    return out


# ---------------------------------------------------------------------------
# align
# ---------------------------------------------------------------------------


def _words(text):
    return [w for w in (z._fold_arabic(t) for t in text.split()) if w]


def align(doc, rows):
    """Groups of our segments, in reading order, with the source rows their
    Arabic words matched:
      one   - one segment, one or more whole rows (join the rows);
      split - several segments share rows (divide the translation);
      none  - no row matched;
      line  - an English-only segment (instruction, heading, tab label)."""
    segments = z.document_segments(doc)
    where = verse_lines(doc)
    ours, our_seg = [], []
    for n, s in enumerate(segments):
        if s['kind'] == 'verse':
            for w in _words(s['arabic']):
                ours.append(w)
                our_seg.append(n)
    theirs, their_row = [], []
    for i, row in enumerate(rows):
        for w in _words(row['ar']):
            theirs.append(w)
            their_row.append(i)
    matcher = difflib.SequenceMatcher(None, ours, theirs, autojunk=False)
    rows_of = collections.defaultdict(set)
    matched = collections.Counter()
    for op, a0, a1, b0, b1 in matcher.get_opcodes():
        if op == 'equal' or (op == 'replace' and a1 - a0 == b1 - b0):
            for k in range(a1 - a0):
                rows_of[our_seg[a0 + k]].add(their_row[b0 + k])
                if op == 'equal':
                    matched[our_seg[a0 + k]] += 1
    total = collections.Counter(our_seg)
    groups = []
    for n, s in enumerate(segments):
        if not z.translatable(s):
            continue
        if s['kind'] != 'verse':
            groups.append({'kind': 'line', 'segs': [{'n': n, 'en': s['text']}]})
            continue
        found = rows_of[n]
        entry = {'n': n, 'ar': s['arabic'], 'tr': where[n][2], 'en': s['english'],
                 'match': round(matched[n] / max(1, total[n]), 2)}
        last = groups[-1] if groups else None
        if last and last['kind'] in ('one', 'split') and found & set(last['rows']):
            last['segs'].append(entry)
            last['rows'] = sorted(set(last['rows']) | found)
            last['kind'] = 'split'
        elif found:
            groups.append({'kind': 'one', 'segs': [entry], 'rows': sorted(found)})
        else:
            groups.append({'kind': 'none', 'segs': [entry]})
    for g in groups:
        if 'rows' in g:
            g['rows'] = list(range(min(g['rows']), max(g['rows']) + 1))
            g['src'] = [{'slide': rows[i]['slide'], 'ar': rows[i]['ar'],
                         'translation': rows[i]['translation']} for i in g['rows']]
    return groups


def cmd_align(args):
    doc = z.load_json(os.path.join(z.ZIKR_DIR, args.uid))
    groups = align(doc, z.load_json(args.rows))
    counts = collections.Counter()
    for g in groups:
        counts[g['kind']] += len(g['segs'])
    z.write_json(args.out, {'uid': args.uid, 'counts': counts, 'groups': groups})
    print(f'{args.uid}: {dict(counts)} -> {args.out}')


# ---------------------------------------------------------------------------
# validate / apply
# ---------------------------------------------------------------------------


def _spaces(text):
    return ' '.join((text or '').split())


def _letters(text):
    return re.sub(r'[^a-z0-9]', '', (text or '').lower())


def check_draft(doc, draft, lang):
    """(errors, untranslated segment numbers)."""
    segments = z.document_segments(doc)
    where = verse_lines(doc)
    wanted = {n for n, s in enumerate(segments) if z.translatable(s)}
    errors, done = [], set()
    for key, value in draft.get('segments', {}).items():
        if not key.isdigit() or int(key) not in wanted:
            errors.append(f'segment {key}: not a translatable segment')
        elif not isinstance(value, str) or not value.strip():
            errors.append(f'segment {key}: empty')
        else:
            if re.search(r'[A-Za-z]', re.sub(r'\]\([^)]*\)', '', value)):
                errors.append(f'segment {key}: Latin letters in the translation')
            done.add(int(key))
    for split in draft.get('splits', []):
        n, parts = split.get('n'), split.get('parts', [])
        if n not in wanted or segments[n]['kind'] != 'verse':
            errors.append(f'split {n}: not a translatable verse')
            continue
        if n in done:
            errors.append(f'split {n}: also in "segments"')
        if len(parts) < 2:
            errors.append(f'split {n}: needs two or more parts')
            continue
        translit = where[n][2]
        if _spaces(' '.join(p.get('ar', '') for p in parts)) != _spaces(segments[n]['arabic']):
            errors.append(f'split {n}: the Arabic parts do not rejoin to the original')
        if translit is not None and _spaces(' '.join(p.get('tr', '') for p in parts)) != _spaces(translit):
            errors.append(f'split {n}: the transliteration parts do not rejoin to the original')
        if _letters(''.join(p.get('en', '') for p in parts)) != _letters(segments[n]['english']):
            errors.append(f'split {n}: the English parts do not rejoin to the original')
        for i, p in enumerate(parts):
            needed = ('ar', 'en', lang) + (('tr',) if translit is not None else ())
            if any(not _spaces(p.get(k)) for k in needed):
                errors.append(f'split {n} part {i}: empty {"/".join(needed)}')
        done.add(n)
    return errors, sorted(wanted - done)


def cmd_validate(args):
    doc = z.load_json(os.path.join(z.ZIKR_DIR, args.uid))
    errors, missing = check_draft(doc, z.load_json(args.draft), args.lang)
    for e in errors:
        print(f'  ERROR {e}')
    if missing:
        print(f'  warn  {len(missing)} segment(s) untranslated: {missing[:40]}')
    print(f'{args.uid}: {len(errors)} error(s)')
    return 1 if errors else 0


def cmd_apply(args):
    path = os.path.join(z.ZIKR_DIR, args.uid)
    doc = z.load_json(path)
    draft = z.load_json(args.draft)
    errors, _ = check_draft(doc, draft, args.lang)
    if errors:
        sys.exit(f'{args.uid}: draft has errors - run `validate` first')
    segments = z.document_segments(doc)
    where = verse_lines(doc)
    splits = {s['n']: s['parts'] for s in draft.get('splits', [])}
    by_tab = collections.defaultdict(list)
    for n, parts in splits.items():
        key, line, translit = where[n]
        by_tab[key].append((line, translit is not None, n, parts))
    for key, edits in by_tab.items():
        lines = _tab_text(doc, key).split('\n')
        for line, has_translit, n, parts in sorted(edits, reverse=True):
            width = 3 if has_translit else 2
            assert lines[line].strip() == segments[n]['arabic'], n
            assert lines[line + width - 1].strip() == segments[n]['english'], n
            new = []
            for p in parts:
                new.append(p['ar'].strip())
                if has_translit:
                    new.append(p['tr'].strip())
                new.append(p['en'].strip())
            lines[line:line + width] = new
        if key[0] == 'data':
            doc['data'] = '\n'.join(lines)
        else:
            doc['tabs'][key[1]] = '\n'.join(lines)
    renumber, shift = {}, 0
    for n in range(len(segments)):
        count = len(splits.get(n, [None]))
        renumber[n] = [n + shift + k for k in range(count)]
        shift += count - 1
    result = {renumber[int(k)][0]: v.strip() for k, v in draft.get('segments', {}).items()}
    for n, parts in splits.items():
        for new_n, part in zip(renumber[n], parts):
            result[new_n] = part[args.lang].strip()
    new_segments = z.document_segments(doc)
    for n, parts in splits.items():
        for new_n, part in zip(renumber[n], parts):
            assert new_segments[new_n]['arabic'] == part['ar'].strip(), new_n
    if splits:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(json.dumps(doc, ensure_ascii=False, indent=2) + '\n')
    target = os.path.join(z.I18N_DIR, args.lang, f'{args.uid}.json')
    translation = z.load_json(target) if os.path.exists(target) else {}
    translation['segments'] = z.ordered_segments({str(k): v for k, v in result.items()})
    z.write_json(target, translation)
    print(f'{args.uid}: {len(result)} segment(s) -> {os.path.relpath(target, z.ROOT)}'
          + (f'; {len(splits)} line(s) split in assets/zikr/{args.uid}' if splits else ''))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    r = sub.add_parser('rows', help="a deck's Arabic and translation, row per slide")
    r.add_argument('deck')
    r.add_argument('out')
    a = sub.add_parser('align', help='worksheet: our segments against the rows')
    a.add_argument('uid')
    a.add_argument('rows')
    a.add_argument('out')
    v = sub.add_parser('validate', help='check a draft')
    v.add_argument('uid')
    v.add_argument('draft')
    v.add_argument('--lang', default='ur')
    p = sub.add_parser('apply', help='apply a draft (splits and translation)')
    p.add_argument('uid')
    p.add_argument('draft')
    p.add_argument('--lang', default='ur')
    args = parser.parse_args()
    return {'rows': cmd_rows, 'align': cmd_align, 'validate': cmd_validate,
            'apply': cmd_apply}[args.command](args) or 0


if __name__ == '__main__':
    sys.exit(main())
