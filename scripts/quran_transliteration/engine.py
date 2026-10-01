import re
from translit import *


def build_stream(words):
    stream = []
    pieces = []
    for wpos, w in enumerate(words):
        segs = [(t, tag, 'pre') for t, tag in w['prefixes']] + [(w['stem'], None, 'stem')]
        cuts = []
        pos = 0
        pids = []
        for si, (txt, tag, kind) in enumerate(segs):
            pid = len(pieces)
            pieces.append({'word': wpos, 'kind': kind, 'tag': tag, 'ar': txt,
                           'word_ar': w['ar'], 'has_al': w['has_al'] and kind == 'stem',
                           'widx': w['idx'], 'is_allah': w.get('is_allah'),
                           'stem_tag': stem_tag(w.get('segs', []))})
            pids.append(pid)
            pos += len(txt)
            cuts.append(pos)
        first = not stream
        us = parse_word(w['ar'], utt_initial=first, has_al=w['has_al'], is_allah=w.get('is_allah'))
        if first and us and us[0]['k'] == 'C':
            us[0]['gem'] = False
        for u in us:
            k = 0
            while k < len(cuts) - 1 and u.get('pos', 0) >= cuts[k]:
                k += 1
            u['piece'] = pids[k]
        stream.extend(us)
    return stream, pieces


def stem_tag(segs):
    for sg in segs:
        if sg[2] == 'STEM':
            feats = sg[4]
            if sg[3] == 'V':
                return 'V'
            if sg[3] == 'N':
                if feats[0].startswith('ROOT') or feats[0] in ('PN', 'ADJ'):
                    return 'PN' if feats[0] == 'PN' else 'N'
                return feats[0]
            return 'P'
    return None


ALLAH_RE = re.compile('(^|ٱ|^لِ|^فَ|^وَ|^تَ)للَّه')


def fix_allah(stream, pieces):
    for i, u in enumerate(stream):
        if u['k'] == 'C' and u['v'] == 'l' and u['gem'] and i + 2 < len(stream):
            p = pieces[u['piece']]
            if p['kind'] == 'stem' and p.get('is_allah') and stream[i+1]['k'] == 'V' \
                    and stream[i+1]['v'] == 'a' and stream[i+2]['k'] == 'C' and stream[i+2]['v'] == 'h':
                stream[i+1]['long'] = True
                stream[i+1]['allah'] = True


def assimilate(stream, pieces):
    out = []
    n = len(stream)
    for i, u in enumerate(stream):
        if u['k'] == 'C' and not u.get('iqlab') and (u['bare'] or u['tanween'] or
                                                    (u['v'] == 'n' and not u['gem'])):
            j = i + 1
            while j < n and stream[j]['k'] == 'W':
                j += 1
            # a hamzat al-wasl in between means a helper vowel follows (KHAYRANIL), no idgham
            if j < n and stream[j]['k'] == 'C' and j == i + 1:
                nxt = stream[j]
                nv = nxt['v']
                cross = pieces[nxt['piece']]['word'] != pieces[u['piece']]['word']
                is_nasal = u['v'] == 'n' and (u['bare'] or u['tanween'] or (i + 1 < n and stream[i+1]['k'] != 'V'))
                if is_nasal and cross and nv in ('w', 'y'):
                    nxt['gem'] = False
                    nxt['ghunna'] = True
                    u['ghunna_next'] = nv
                    out.append(u)
                    continue
                if is_nasal and cross and nv in ('m', 'n', 'l', 'r'):
                    nxt['gem'] = True
                    nxt['assim_from'] = 'n'
                    continue
                if (u['bare'] or u['tanween']) and nxt['gem']:
                    nxt['assim_from'] = u['v']
                    continue
        out.append(u)
    return out


def apply_wasl(stream):
    out = []
    for u in stream:
        if u['k'] == 'W':
            if out:
                p = out[-1]
                if p['k'] == 'V' and p['long']:
                    p['long'] = False
                    p['shortened'] = True
                    p['madd'] = False
                    p['silah'] = False
                elif p['k'] == 'C':
                    out.append(U('V', 'i', piece=p['piece'], helper=True))
            continue
        out.append(u)
    return out


def apply_pause(s):
    if not s:
        return s
    s = [dict(u) for u in s]
    last = s[-1]
    if last['k'] == 'C' and last['tanween']:
        tv = s[-2]['v']
        prevc = s[-3] if len(s) >= 3 else None
        s = s[:-1]
        if tv == 'a' and not (prevc and prevc['tm']):
            s[-1]['long'] = True
            s[-1]['pause_long'] = True
        else:
            s = s[:-1]
    elif last['k'] == 'V' and last.get('pause_only'):
        pass
    elif last['k'] == 'V' and (not last['long'] or last['silah']):
        s = s[:-1]
        # huwa / hiya at pause -> HOO / HEE
        if len(s) >= 2 and s[-1]['k'] == 'C' and s[-1]['v'] in ('w', 'y') and not s[-1]['gem'] \
                and s[-2]['k'] == 'V' and not s[-2]['long'] \
                and ((s[-1]['v'] == 'w' and s[-2]['v'] == 'u') or (s[-1]['v'] == 'y' and s[-2]['v'] == 'i')):
            s = s[:-1]
            s[-1]['long'] = True
    if s and s[-1]['k'] == 'C' and s[-1]['gem'] and s[-1]['v'] not in ('w', 'y'):
        s[-1]['gem'] = False  # HAQ, but A'DUWW / MUSREKHIYY keep it
    if s and s[-1]['k'] == 'C' and s[-1]['v'] == "'":
        s[-1]['silent'] = True
    if s and s[-1]['k'] == 'C' and s[-1]['tm']:
        s[-1]['v'] = 'h'
    return [u for i, u in enumerate(s) if not (u.get('pause_only') and i != len(s) - 1)]


def drop_pause_only(s):
    return [u for u in s if not u.get('pause_only')]


def mark_closed(stream):
    n = len(stream)
    for i, u in enumerate(stream):
        if u['k'] != 'V':
            continue
        closed = False
        j = i + 1
        if j < n and stream[j]['k'] == 'C':
            if stream[j]['gem']:
                closed = True
            elif j + 1 >= n:
                closed = True
            elif stream[j+1]['k'] == 'C':
                closed = True
            if closed and not stream[j]['gem'] and stream[j]['v'] in GUTTURAL_OPEN:
                closed = False
        u['closed'] = closed


GUTTURAL_OPEN = {'h', 'H', '`', "'"}


def assign_tokens(stream, pieces):
    """Move leading coda consonants / first half of geminates of a piece into
    the previous piece.  Returns list of (piece_id, unit, half) where half
    in (None,'first','second')."""
    out = []
    n = len(stream)
    seen = set()
    for i, u in enumerate(stream):
        pid = u['piece']
        first_of_piece = pid not in seen
        seen.add(pid)
        if first_of_piece and out and u['k'] == 'C':
            prev_pid = out[-1][0]
            if u['gem']:
                out.append((prev_pid, u, 'first'))
                out.append((pid, u, 'second'))
                continue
            if i + 1 < n and stream[i+1]['k'] == 'C':
                out.append((prev_pid, u, None))
                pieces[prev_pid]['absorbed'] = True
                if u['v'] in ('`', "'"):
                    pieces[prev_pid]['absorbed_glue'] = True
                # the next unit is the real start of this piece
                seen.discard(pid)
                continue
        if u['k'] == 'C' and u['gem']:
            out.append((pid, u, 'first'))
            out.append((pid, u, 'second'))
        else:
            out.append((pid, u, None))
    return out
