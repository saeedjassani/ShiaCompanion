# -*- coding: utf-8 -*-
"""Shared helpers: load rules, walk the zikr corpus, Arabic character classes."""
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RULES = json.load(open(os.path.join(ROOT, 'scripts/zikr_arabic/rules.json'), encoding='utf-8'))
ZIKR_DIR = os.path.join(ROOT, 'assets/zikr')
BACKUP_DIR = os.path.join(ROOT, '.zikr-backups')

def latest_snapshot():
    """Newest Firestore snapshot from backup.js, or None.

    Patches must be built from Firestore, not from assets/zikr: the assets are a
    lossy projection (build_zikr_release.js computes `slug` and copies only
    title/code/data/merits/tabs), and a local build can leave them out of step
    with the cloud. apply_patch.js verifies `before` against the live document,
    so an assets-built patch gets rejected as drifted.
    """
    if not os.path.isdir(BACKUP_DIR):
        return None
    snaps = sorted(f for f in os.listdir(BACKUP_DIR)
                   if f.startswith('zikr-') and f.endswith('.json'))
    return os.path.join(BACKUP_DIR, snaps[-1]) if snaps else None

_SNAP = None
def snapshot_docs():
    global _SNAP
    if _SNAP is None:
        f = latest_snapshot()
        _SNAP = json.load(open(f, encoding='utf-8')) if f else {}
    return _SNAP

HA = 'هہھ'
ULTA, KHARI = 'ٗ', 'ٖ'          # ulta pesh, khari zer
DAMMA, KASRA, FATHA, SUKUN, SHADDA = 'ُ', 'ِ', 'َ', 'ْ', 'ّ'
TANWEEN, DAGGER = 'ًٌٍ', 'ٰ'
SHORT = FATHA + DAMMA + KASRA + TANWEEN
MARKS = set(ULTA + KHARI + SHORT + SUKUN + SHADDA + DAGGER + 'ٕٓٔۡ')
PUNCT = '“”"‏‎,.:;!?،۔ۚۖۗۙۘۛ()[]'

def is_arabic(ch):
    o = ord(ch)
    return (0x600 <= o <= 0x6FF or 0x750 <= o <= 0x77F or 0x8A0 <= o <= 0x8FF
            or 0xFB50 <= o <= 0xFDFF or 0xFE70 <= o <= 0xFEFF)

AR = re.compile(r'[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]')

def skeleton(w):
    return ''.join(c for c in w if c not in MARKS)

def iter_strings(obj, path=()):
    """Yield (json_path, string) for every string in a loaded zikr document."""
    if isinstance(obj, str):
        yield path, obj
    elif isinstance(obj, dict):
        for k, v in obj.items():
            yield from iter_strings(v, path + (k,))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from iter_strings(v, path + (i,))

QURAN_UID = re.compile(r'^A\d+$')
QURAN_TITLE = re.compile(r'^\d+\s*:')

def is_quran(uid, title=''):
    """Quran surah text — a separate lineage, copied from a mushaf rather than
    authored here. Excluded from every editing pass; still audited, because it
    ships and still has to render."""
    return bool(QURAN_UID.match(uid) or QURAN_TITLE.match(str(title)))

def uid_key(uid):
    """Sort key giving natural order: E1, E2, … E10 rather than E1, E10, E2."""
    m = re.match(r'^([A-Za-z]*)(\d*)', uid)
    return (m.group(1), int(m.group(2) or 0), uid)

def load_corpus(uids=None, include_quran=False, source='auto'):
    """Yield (uid, document) in natural uid order.

    source='auto'      newest Firestore snapshot if one exists, else the assets
    source='firestore' snapshot only (raises if there is none)
    source='assets'    the bundled assets, for render/audit checks
    """
    if source in ('auto', 'firestore'):
        docs = snapshot_docs()
        if not docs and source == 'firestore':
            raise SystemExit('No snapshot in .zikr-backups/. Run: node scripts/zikr_arabic/backup.js')
        if docs:
            for uid in sorted(docs, key=uid_key):
                if uids and uid not in uids:
                    continue
                if not include_quran and is_quran(uid, docs[uid].get('title', '')):
                    continue
                yield uid, docs[uid]
            return
    for fn in sorted(os.listdir(ZIKR_DIR), key=uid_key):
        if uids and fn not in uids:
            continue
        if not include_quran and not uids and QURAN_UID.match(fn):
            continue
        p = os.path.join(ZIKR_DIR, fn)
        if not os.path.isfile(p):
            continue
        try:
            doc = json.load(open(p, encoding='utf-8'))
        except (ValueError, UnicodeDecodeError):
            continue
        if not include_quran and is_quran(fn, doc.get('title', '')):
            continue
        yield fn, doc

def arabic_strings(uids=None, include_quran=False, source='auto'):
    """Yield (uid, json_path, string) for strings that contain Arabic."""
    for uid, doc in load_corpus(uids, include_quran, source):
        for path, s in iter_strings(doc):
            if AR.search(s):
                yield uid, path, s

def font_cmaps():
    """{font_name: set(codepoints)} for the three bundled fonts."""
    from fontTools.ttLib import TTFont
    out = {}
    for name, rel in RULES['fonts'].items():
        f = TTFont(os.path.join(ROOT, rel), fontNumber=0, lazy=True)
        cps = set()
        for t in f['cmap'].tables:
            cps |= set(t.cmap.keys())
        out[name] = cps
    return out

def _clean(d):
    return {k: v for k, v in d.items() if not k.startswith('_')}

def render_for_font(s, font):
    """Mirror of ZikrContentParser.formatArabicText for `font`."""
    if font == 'Qalam':
        return s
    for a, b in _clean(RULES['font_runtime'][font]).items():
        s = s.replace(a, b)
    for a, b in _clean(RULES['font_runtime_sequence']).items():
        s = s.replace(a, b)
    return s

LAM_ALIF = re.compile('\u0644\u0627([\u064E\u0651]+)')

def fix_lam_alif(s):
    """Move fatha/shadda written after a lam-alif to before the alif.

    لاَ -> لَا and لاَّ -> لَّا. The mark belongs to the lam; left after the alif
    the ligature draws it on the wrong stroke. Output is shadda-first.
    """
    def swap(m):
        marks = m.group(1)
        ordered = ''.join(sorted(marks, key=lambda c: c != '\u0651'))
        return '\u0644' + ordered + '\u0627'
    return LAM_ALIF.sub(swap, s)

def normalize_source(s):
    """Apply the source-normalization rules. Returns (new_string, [(old,new),...])."""
    changes = []
    for a, b in _clean(RULES['source_normalization']['sequence']).items():
        if a in s:
            changes.append((a, b)); s = s.replace(a, b)
    for a, b in _clean(RULES['source_normalization']['single']).items():
        if a in s:
            changes.append((a, b)); s = s.replace(a, b)
    fixed = fix_lam_alif(s)
    if fixed != s:
        changes.append(('لاَ', 'لَا')); s = fixed
    return s, changes
