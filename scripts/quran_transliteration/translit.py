"""Rule-based Quran transliteration in the house style of the existing
(hand-made) transliterations in assets/zikr/A*.

Input: Tanzil Uthmani text (fully vocalised, Hafs), plus Quranic Arabic
Corpus morphology for prefix segmentation.
"""
import re, sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import tanzil
import morph

FATHA, KASRA, DAMMA = 'َ', 'ِ', 'ُ'
FATHATAN, KASRATAN, DAMMATAN = 'ً', 'ٍ', 'ٌ'
SHADDA, SUKUN = 'ّ', 'ْ'
DAGGER = 'ٰ'
MADDAH = 'ٓ'
HAMZA_ABOVE = 'ٔ'
SILENT0 = '۟'      # small high rounded zero: letter never pronounced
SILENT_RECT = '۠'  # small high upright rectangular zero: silent in wasl, pronounced at pause
IQLAB_HI = 'ۢ'
IQLAB_LO = 'ۭ'
SMALL_WAW = 'ۥ'
SMALL_YEH = 'ۦ'
SMALL_HIGH_YEH = 'ۧ'
TATWEEL = 'ـ'
WASLA = 'ٱ'
PAUSE_MARKS = {'ۖ': 'salaa', 'ۗ': 'qalaa', 'ۚ': 'jeem',
               'ۘ': 'meem', 'ۛ': 'muanaqa', 'ۙ': 'laa'}
SKIP_TOKENS = {'۞', '۩'}

CONS = {
    'ب': 'b', 'ت': 't', 'ث': 'th', 'ج': 'j', 'ح': 'H', 'خ': 'kh', 'د': 'd',
    'ذ': 'dh', 'ر': 'r', 'ز': 'z', 'س': 's', 'ش': 'sh', 'ص': 'S', 'ض': 'D',
    'ط': 'T', 'ظ': 'Z', 'ع': '`', 'غ': 'gh', 'ف': 'f', 'ق': 'q', 'ك': 'k',
    'ل': 'l', 'م': 'm', 'ن': 'n', 'ه': 'h', 'و': 'w', 'ي': 'y', 'ى': 'y',
    'ء': "'", 'أ': "'", 'إ': "'", 'ؤ': "'", 'ئ': "'", 'ة': 't',
}
SUN = set('tTdDthdhrzsshSZln'.split()) | {'t', 'th', 'd', 'dh', 'r', 'z', 's', 'sh', 'S', 'D', 'T', 'Z', 'l', 'n'}

MARKS = set([FATHA, KASRA, DAMMA, FATHATAN, KASRATAN, DAMMATAN, SHADDA, SUKUN,
             DAGGER, MADDAH, HAMZA_ABOVE, SILENT0, SILENT_RECT, IQLAB_HI, IQLAB_LO,
             SMALL_HIGH_YEH, 'ۜ', 'ۣ', 'ۨ', '۪', '۫', '۬'])


def clusters(word):
    out = []
    for i, ch in enumerate(word):
        if ch in MARKS and out:
            out[-1][1].append(ch)
        else:
            out.append([ch, [], i])
    return out


def U(k, v, **kw):
    d = {'k': k, 'v': v, 'gem': False, 'long': False, 'madd': False, 'silah': False,
         'tanween': False, 'bare': False, 'tm': False, 'iqlab': False}
    d.update(kw)
    return d


def last_vowel(units):
    for u in reversed(units):
        if u['k'] == 'V':
            return u
        return None
    return None


def parse_word(word, utt_initial, has_al=False, is_allah=False):
    """Return list of units."""
    cl = clusters(word)
    units = []
    n = len(cl)
    tagged = 0
    skip_next = False
    for ci, (base, marks, pos) in enumerate(cl):
        for u in units[tagged:]:
            u.setdefault('pos', cl[ci - 1][2])
        tagged = len(units)
        if skip_next:
            skip_next = False
            continue
        ms = set(marks)
        vowel = None
        if FATHA in ms: vowel = 'a'
        elif KASRA in ms: vowel = 'i'
        elif DAMMA in ms: vowel = 'u'
        tan = None
        if FATHATAN in ms: tan = 'a'
        elif KASRATAN in ms: tan = 'i'
        elif DAMMATAN in ms: tan = 'u'
        iq = IQLAB_HI in ms or IQLAB_LO in ms
        prev = units[-1] if units else None

        if base == TATWEEL and HAMZA_ABOVE not in ms:
            if SMALL_HIGH_YEH in ms and prev and prev['k'] == 'V':
                prev['long'] = True; prev['v'] = 'i'
            continue
        if base == WASLA:
            if utt_initial and not units:
                # vowel for initial hamzat al-wasl
                nxt = cl[ci + 1][0] if ci + 1 < n else ''
                if has_al or nxt == 'ل':
                    v = 'a'
                    lam_marks = cl[ci + 1][1] if ci + 1 < n else []
                    if (not lam_marks and ci + 2 < n and SHADDA in cl[ci + 2][1] and not is_allah) or \
                            (SHADDA in lam_marks and not is_allah):
                        # sun letter at the start of an ayah: dad drops the A (LAZEENA)
                        if not lam_marks:
                            skip_next = True  # the assimilated lam too
                        continue
                    if SUKUN in lam_marks:
                        units.append(U('C', "'", wasl=True))
                        units.append(U('V', v, wasl=True))
                        units.append(U('C', 'l', al_initial=True, pos=cl[ci + 1][2]))
                        skip_next = True
                        continue
                else:
                    # third letter (after the sukun'd consonant) damma -> u
                    v = 'i'
                    if ci + 2 < n and DAMMA in cl[ci + 2][1]:
                        v = 'u'
                units.append(U('C', "'", wasl=True))
                units.append(U('V', v, wasl=True))
            else:
                units.append(U('W', '', wasl=True))  # marker for wasl junction
            continue
        if base == 'ا':
            if SILENT0 in ms:
                continue
            if SILENT_RECT in ms:
                if prev and prev['k'] == 'V':
                    prev['long'] = True
                continue
            if prev and prev['k'] == 'V' and prev['v'] == 'a' and not prev['long']:
                prev['long'] = True
                if MADDAH in ms: prev['madd'] = True
                continue
            if prev and prev['k'] == 'C' and prev.get('tanween'):
                continue  # tanween fatha seat
            if prev and prev['k'] == 'V' and prev['long'] and prev['v'] == 'a':
                continue
            # alif after dagger etc.; ignore
            continue
        if base in ('ى', 'ي', 'و') and not vowel and not tan and SHADDA not in ms and SUKUN not in ms:
            want = {'ى': ('i', 'a'), 'ي': ('i',), 'و': ('u',)}[base]
            if DAGGER in ms:
                if prev and prev['k'] == 'V':
                    prev['long'] = True; prev['v'] = 'a'
                    if MADDAH in ms: prev['madd'] = True
                continue
            if SILENT0 in ms:
                if base == 'و' and prev and prev['k'] == 'V' and prev['v'] == 'u':
                    prev['long'] = True  # أُو۟لَٰٓئِكَ -> OOLAAA-EKA
                continue
            if prev and prev['k'] == 'V' and prev['v'] in want and not prev['long']:
                prev['long'] = True
                if MADDAH in ms: prev['madd'] = True
                continue
            if prev and prev['k'] == 'C' and prev.get('tanween'):
                continue  # huda-n seat
            if base == 'ى' and prev and prev['k'] == 'V' and prev['long']:
                continue
            if SMALL_HIGH_YEH in ms and prev and prev['k'] == 'V':
                prev['long'] = True
                continue
            if base == 'و' and ci == 0:
                units.append(U('C', 'w'))
                continue
            # fall through as consonant without vowel
        if base == SMALL_WAW:
            if prev and prev['k'] == 'V':
                prev['long'] = True
                if len(units) >= 2 and units[-2]['v'] == 'h':
                    prev['silah'] = True
                if MADDAH in ms: prev['madd'] = True
            continue
        if base == SMALL_YEH:
            if prev and prev['k'] == 'V':
                prev['long'] = True
                if len(units) >= 2 and units[-2]['v'] == 'h':
                    prev['silah'] = True
                if MADDAH in ms: prev['madd'] = True
            continue
        if base in CONS or HAMZA_ABOVE in ms:
            c = CONS.get(base, "'")
            if HAMZA_ABOVE in ms: c = "'"
            u = U('C', c, letter=base)
            if base == 'ة': u['tm'] = True
            if SHADDA in ms: u['gem'] = True
            if not vowel and not tan and SHADDA not in ms and SUKUN not in ms:
                u['bare'] = True
            if base == 'إ' and not vowel: vowel = 'i'
            if iq and not tan:
                u['v'] = 'm'; u['iqlab'] = True
            units.append(u)
            if vowel:
                units.append(U('V', vowel))
                if DAGGER in ms:
                    units[-1]['long'] = True; units[-1]['v'] = 'a'
                    if MADDAH in ms: units[-1]['madd'] = True
            elif DAGGER in ms:
                units.append(U('V', 'a', long=True, madd=MADDAH in ms))
            if tan:
                units.append(U('V', tan))
                units.append(U('C', 'm' if iq else 'n', tanween=True, iqlab=iq))
            # mark prefix end
            continue
        # unknown char
        units.append(U('?', base))
    for u in units[tagged:]:
        u.setdefault('pos', cl[-1][2])
    return units


# ---------- ayah assembly ----------

def word_prefixes(s, a, w, word):
    """Return list of (prefix_text, tag) for non-DET prefixes, and has_al."""
    segs = morph.load().get((s, a, w), [])
    pre = []
    has_al = False
    for text, tag, kind, pos, feats in segs:
        if kind != 'PREF':
            break
        if tag == 'DET':
            has_al = True
            break
        pre.append((text, tag))
    return pre, has_al


def split_word(word, prefixes):
    """Split tanzil word into prefix strings + remainder (by char lengths)."""
    parts = []
    rest = word
    for text, tag in prefixes:
        # compare ignoring tatweel
        n = len(text)
        if rest[:n].replace(TATWEEL, '') == text.replace(TATWEEL, '') or True:
            # prefix consists of letter + marks; take base char + following marks
            cl = clusters(rest)
            if not cl:
                break
            k = 1
            # some prefixes are two letters (e.g. يَٰٓ, هَٰ); count base letters in text
            nb = len([ch for ch in text if ch not in MARKS])
            k = nb
            cut = cl[k][2] if k < len(cl) else len(rest)
            parts.append((rest[:cut], tag))
            rest = rest[cut:]
    return parts, rest


def ayah_words(s, a, text=None):
    """List of dicts: {ar, pieces:[(text,tag)], pause_after}"""
    if text is None:
        text = tanzil()[(s, a)]
    toks = text.split()
    words = []
    wi = 0
    for t in toks:
        if t in SKIP_TOKENS:
            continue
        if t in PAUSE_MARKS:
            if words:
                words[-1]['pause_after'] = PAUSE_MARKS[t]
            continue
        wi += 1
        prefixes, has_al = word_prefixes(s, a, wi, t)
        parts, rest = split_word(t, prefixes)
        segs = morph.load().get((s, a, wi), [])
        is_allah = any(f.startswith('LEM:') and re.sub('[^ء-ي]', '', f[4:]) in ('الله', 'اللهم')
                       for sg in segs for f in sg[4])
        words.append({'ar': t, 'idx': wi, 'prefixes': parts, 'stem': rest,
                      'has_al': has_al, 'pause_after': None, 'is_allah': is_allah,
                      'segs': segs})
    return words
