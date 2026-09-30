import re
from engine import *

LAT = {'b': 'B', 't': 'T', 'th': 'S', 'j': 'J', 'H': 'H', 'kh': 'KH', 'd': 'D', 'dh': 'Z',
       'r': 'R', 'z': 'Z', 's': 'S', 'sh': 'SH', 'S': 'S', 'D': 'Z', 'T': 'T', 'Z': 'Z',
       'gh': 'GH', 'f': 'F', 'q': 'Q', 'k': 'K', 'l': 'L', 'm': 'M', 'n': 'N', 'h': 'H',
       'w': 'W', 'y': 'Y', "'": '', '`': '’'}

AP = '’'

CFG = {
    'pause_marks': {'toa', 'salaa', 'qalaa', 'jeem', 'meem', 'pe01a', 'pe01b', 'pe01c', 'pe01e'},
    'comma_marks': {'toa', 'salaa', 'qalaa', 'jeem', 'meem', 'muanaqa', 'laa',
                    'pe01a', 'pe01b', 'pe01c', 'pe01e', 'pe01f'},
}


def vowel_str(u):
    v = u['v']
    if v == 'a':
        if u['long']:
            return 'AAA' if u['madd'] else 'AA'
        return 'A'
    if v == 'i':
        if u['long']:
            return 'I' if u['silah'] else 'EE'
        return 'I' if u.get('closed') else 'E'
    if v == 'u':
        if u['long']:
            return 'U' if u['silah'] else 'OO'
        return 'U' if u.get('closed') else 'O'
    return '?'


def render_piece(items):
    s = ''
    k = 0
    n = len(items)
    while k < n:
        u, half = items[k]
        nxt = items[k+1][0] if k + 1 < n else None
        if u['k'] == 'C':
            c = u['v']
            if c == '`':
                if nxt is not None and nxt['k'] == 'V' and half != 'first':
                    vs = vowel_str(nxt)
                    if s:
                        s += '-'
                    s += vs[0] + AP + vs[1:]
                    k += 2
                    continue
                if re.fullmatch(r'-?[AEIOU]', s):
                    s += '-' + s[-1] + AP
                else:
                    s += AP
                k += 1
                continue
            if c == "'":
                if nxt is not None and nxt['k'] == 'V' and half != 'first':
                    if s:
                        s += '-'
                    s += vowel_str(nxt)
                    k += 2
                    continue
                if half != 'first' and not u.get('silent'):
                    s += 'A'   # hamza sakin: YOAMENOON, SHEATUM, YAATEEKUM
                k += 1
                continue
            L = LAT.get(c, '?')
            if half == 'second' and len(L) > 1 and s:
                s += '-'
            elif L == 'H' and re.search(r'(SH|KH|GH)$', s):
                s += '-'
            s += L
            if u.get('al_initial'):
                s += '-'
            if u.get('ghunna_next') == 'w' and nxt is None:
                s += 'W'
            elif u.get('ghunna_next') == 'y' and nxt is None:
                s += '-Y'
            k += 1
            continue
        if u['k'] == 'V':
            s += vowel_str(u)
            k += 1
            continue
        k += 1
    return s


JOIN_DEBUG = False
JOIN_LOG = []


FUNCTION_TAGS = {'PRON', 'DEM', 'REL', 'COND', 'INTG', 'T', 'LOC', 'P', None}


def join_for(piece, nxtpiece, left, right):
    if piece.get('absorbed_glue'):
        return ''
    if nxtpiece['word'] != piece['word']:
        return ' '
    if JOIN_DEBUG:
        return '\x01'
    tag = piece['tag']
    letter = piece['ar'][0]
    if piece.get('absorbed_glue'):
        return ''
    if letter == 'و' or tag == 'VOC':
        return ' '
    if nxtpiece['kind'] != 'stem':
        return ''
    if right[:1] in ('A', 'E', 'I', 'O', 'U', AP):
        return '-'
    content = nxtpiece['stem_tag'] not in FUNCTION_TAGS and not nxtpiece.get('is_allah')
    if nxtpiece.get('is_allah'):
        return '-' if letter == 'ب' else ''
    if nxtpiece['has_al']:
        return '-' if letter in 'بلك' else ''
    if piece.get('absorbed'):
        return ''
    if not content:
        return ''
    if letter in 'ب':
        return '-'
    if letter == 'ل':
        if tag == 'EMPH':
            return '' if nxtpiece['stem_tag'] in ('V', 'IMPV') else '-'
        return '-'
    if letter == 'ف':
        return '-'
    return ''


def render_utterance(words, pause=True, comma_words=()):
    stream, pieces = build_stream(words)
    fix_allah(stream, pieces)
    stream = assimilate(stream, pieces)
    # madd only counts when a hamza follows in the same piece (muttasil)
    for i, u in enumerate(stream):
        if u['k'] == 'V' and u['madd']:
            nx = stream[i+1] if i + 1 < len(stream) else None
            if not (nx and nx['k'] == 'C' and nx['v'] == "'" and nx['piece'] == u['piece']):
                u['madd'] = False
    stream = apply_wasl(stream)
    mark_closed(stream)
    if pause:
        stream = apply_pause(stream)
    items = assign_tokens(stream, pieces)
    per = {}
    order = []
    for pid, u, half in items:
        if pid not in per:
            per[pid] = []
            order.append(pid)
        per[pid].append((u, half))
    order.sort()
    out = ''
    toks = []
    for idx, pid in enumerate(order):
        txt = render_piece(per[pid])
        toks.append((pid, txt))
    for idx, (pid, txt) in enumerate(toks):
        out += txt
        if idx + 1 < len(toks):
            j = join_for(pieces[pid], pieces[toks[idx+1][0]], txt, toks[idx+1][1])
            if JOIN_DEBUG and j == '\x01':
                JOIN_LOG.append((pieces[pid], pieces[toks[idx+1][0]], txt, toks[idx+1][1]))
            if j == ' ' and pieces[pid]['word'] != pieces[toks[idx+1][0]]['word'] \
                    and pieces[pid]['word'] in comma_words:
                j = ', '
            out += j
    return out, pieces


MUQATTAAT = {}


def transliterate(s, a, cfg=CFG):
    if (s, a) in MUQATTAAT:
        return MUQATTAAT[(s, a)]
    words = ayah_words(s, a)
    if cfg.get('use_indopak', True):
        from marks import indopak_marks
        im = indopak_marks(s, a, [w['ar'] for w in words])
        if im or marks_file_has(s, a):
            for i, w in enumerate(words):
                w['marks'] = im.get(i, set())
        else:
            for w in words:
                w['marks'] = {w['pause_after']} if w['pause_after'] else set()
    else:
        for w in words:
            w['marks'] = {w['pause_after']} if w['pause_after'] else set()
    # utterances split at pausing marks; commas also at non-pausing comma marks
    utts = []
    cur = []
    for i, w in enumerate(words):
        cur.append(w)
        last = i == len(words) - 1
        if not last and w['marks'] & cfg['pause_marks']:
            utts.append(cur)
            cur = []
    if cur:
        utts.append(cur)
    out_parts = []
    for ui, ws in enumerate(utts):
        cw = {i for i, w in enumerate(ws) if w['marks'] & cfg['comma_marks'] and i != len(ws) - 1}
        txt, pieces = render_utterance(ws, pause=True, comma_words=cw)
        out_parts.append(txt)
    out = ', '.join(p for p in out_parts if p)
    return out + '.'


def marks_file_has(s, a):
    from marks import file_arabic
    return a in file_arabic(s)
