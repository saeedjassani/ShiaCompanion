"""Shared reading of the zikr corpus for the structure tools.

Mirrors lib/pages/zikr/zikr_content_parser.dart closely enough to tell an
Arabic line, its transliteration and translation, and a standalone note
apart - see docs/ZIKR_STRUCTURE.md.
"""
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ZIKR_DIR = os.path.join(ROOT, 'assets', 'zikr')
INDEX = os.path.join(ROOT, 'assets', 'zikr.json')
REDIRECTS = os.path.join(ROOT, 'lib', 'data', 'retired_zikr_redirects.dart')

_AR = re.compile('[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]')
QURAN_UID = re.compile(r'^A\d+$')


def is_arabic(line):
    return bool(_AR.search(line[:35]))


def load_index():
    with open(INDEX, encoding='utf-8') as f:
        return json.load(f)


def load_entry(uid, text=None):
    if text is None:
        with open(os.path.join(ZIKR_DIR, uid), encoding='utf-8') as f:
            text = f.read()
    return json.loads(text)


def entry_uids():
    return sorted(u for u in os.listdir(ZIKR_DIR) if not QURAN_UID.match(u))


def load_redirects():
    """Retired uid -> target uid."""
    return {u: t for u, (t, _) in load_redirects_full().items()}


def load_redirects_full():
    """Retired uid -> (target uid, tabIndex or None)."""
    with open(REDIRECTS, encoding='utf-8') as f:
        src = f.read()
    out = {}
    for uid, target, tab in re.findall(
            r"'([^']+)':\s*RetiredZikrRedirect\(\s*'([^']+)'(?:,\s*tabIndex:\s*(\d+))?", src):
        out[uid] = (target, int(tab) if tab else None)
    return out


def parts_of(entry):
    """[data, *tabs], as the reader shows them (empty data dropped)."""
    parts = []
    if (entry.get('data') or '').strip():
        parts.append(entry['data'])
    parts += [t for t in (entry.get('tabs') or []) if (t or '').strip()]
    return parts


class Part:
    """One tab: its label (when there are several) and classified lines."""

    def __init__(self, content, has_header):
        lines = [l.strip() for l in content.split('\n')]
        self.label = None
        self.header_blank = False
        if has_header:
            # The reader labels the tab with the first non-blank line but
            # drops line 0 from the body outright, blank or not - so a part
            # opening with a blank line shows its label twice.
            self.label = next((l for l in lines if l), '')
            self.header_blank = bool(lines) and not lines[0]
            lines = lines[1:]
        self.lines = lines
        ar = [i for i, l in enumerate(lines) if l and is_arabic(l)]
        gaps = [b - a for a, b in zip(ar, ar[1:])]
        has_translit = gaps.count(2) <= gaps.count(3)
        self.kind = ['blank' if not l else 'note' for l in lines]
        arset = set(ar)
        for i in ar:
            self.kind[i] = 'arabic'
            t1 = i + 1 if has_translit else None
            t2 = i + 2 if has_translit else i + 1
            if t1 is not None and t1 < len(lines) and t1 not in arset and lines[t1]:
                self.kind[t1] = 'translit'
            if t2 < len(lines) and t2 not in arset and lines[t2]:
                self.kind[t2] = 'translation'

    def notes(self):
        return [(i, l) for i, l in enumerate(self.lines) if self.kind[i] == 'note']

    def note_runs(self):
        """Runs of consecutive standalone lines (blank lines don't break a run)."""
        runs, cur = [], []
        for i, l in enumerate(self.lines):
            k = self.kind[i]
            if k == 'note':
                cur.append(l)
            elif k != 'blank' and cur:
                runs.append(cur)
                cur = []
        if cur:
            runs.append(cur)
        return runs


def parse_parts(entry):
    raw = parts_of(entry)
    return [Part(p, len(raw) > 1) for p in raw]


def write_entry(uid, title, parts, merits=''):
    """Write assets/zikr/<uid> in the corpus's own format.

    [parts] is a list of parts, each a list of lines; with more than one part,
    each part's first line must be its tab label.
    """
    entry = {'title': title, 'data': '\n'.join(parts[0])}
    if len(parts) > 1:
        entry['tabs'] = ['\n'.join(p) for p in parts[1:]]
    if merits.strip():
        entry['merits'] = merits.strip()
    with open(os.path.join(ZIKR_DIR, uid), 'w', encoding='utf-8') as f:
        f.write(json.dumps(entry, ensure_ascii=False, indent=2) + '\n')
