"""House-style transliteration for vocalised du'a Arabic.

Produces the ALL-CAPS style the restored zikrs use (F13-F25, E128-E136):
long vowels AA/EE/OO and short A/I/U; ' for hamza and 'ayn (A'LAA, NA'BUDU,
AS'ALUKA); ث ذ ش خ غ as TH DH SH KH GH and ص ض ط ظ as S D T Z; the article
and hamzat al-wasl run on from the previous word (MINAL KHAASIREEN,
FIZ ZULUMAAT, ALLADHIS TAJABTA); Allah is glued (ILLALLAAHU, A'BDILLAAH,
WALLAAHU); WA is written as its own word (WA RUSULIK); FA/BI/LI take a
hyphen before a hamza (FA-INNA, BI-ANNAKA, LI-AADAMA); the pronoun -hu/-hi
is long after a short vowel (LAHOO, BIHEE); and the last word of the line is
pausal (KULLAH, ABADAA, RAHEEM, -AH for ta marbuta, -AAT for plurals).

It is a drafting aid, not an oracle. Splitting a leading و into WA is a
heuristic (WAW_STEMS lists words whose و is a root letter), and Arabic that
is under-vowelled in the source comes out wrong. Read every line it
produces against the Arabic before it ships.

    python3 scripts/zikr_arabic/translit.py "اَللّٰهُمَّ صَلِّ عَلٰى مُحَمَّدٍ"
    python3 scripts/zikr_arabic/translit.py --check [-v]   # vs hand-written F16-F25
"""
import json
import re
import sys

FATHA, DAMMA, KASRA, SUKUN, SHADDA = 'َ', 'ُ', 'ِ', 'ْ', 'ّ'
FATHATAN, DAMMATAN, KASRATAN = 'ً', 'ٌ', 'ٍ'
DAGGER = 'ٰ'
VOWELS = {FATHA: 'A', DAMMA: 'U', KASRA: 'I', 'ٗ': 'U', 'ٖ': 'I'}
SILAH_MARKS = {'ٗ': 'OO', 'ٖ': 'EE'}
TANWEEN = {FATHATAN: 'AN', DAMMATAN: 'UN', KASRATAN: 'IN'}
TM = 'Ŧ'   # placeholder for ta marbuta: H at a pause, T otherwise
CONS = {'ب': 'B', 'ت': 'T', 'ث': 'TH', 'ج': 'J', 'ح': 'H', 'خ': 'KH', 'د': 'D', 'ذ': 'DH',
        'ر': 'R', 'ز': 'Z', 'س': 'S', 'ش': 'SH', 'ص': 'S', 'ض': 'D', 'ط': 'T', 'ظ': 'Z',
        'ع': "'", 'غ': 'GH', 'ف': 'F', 'ق': 'Q', 'ك': 'K', 'ک': 'K', 'ل': 'L', 'م': 'M',
        'ن': 'N', 'ه': 'H', 'ہ': 'H', 'ھ': 'H', 'و': 'W', 'ي': 'Y', 'ی': 'Y', 'ء': "'",
        'أ': "'", 'إ': "'", 'ؤ': "'", 'ئ': "'", 'ة': TM, 'ۃ': TM}
HAMZA_SEATS = set('أإءؤئ')
SUN = set('تثدذرزسشصضطظلن')
MARKS = set(VOWELS) | set(TANWEEN) | {SUKUN, SHADDA, DAGGER}
# anything else that is not a base letter (Quranic annotation, tatweel, madda...)
def _ignorable(ch):
    return 'ؐ' <= ch <= 'ؚ' or 'ۖ' <= ch <= 'ۭ' or ch in 'ـٕٓٔ‌‍'
# stems whose leading و is a root letter, not the conjunction (consonant skeleton after the و)
WAW_STEMS = ('صو', 'لي', 'حي', 'صي', 'زي', 'قع', 'ضع', 'صف', 'رث', 'كي',
             'لد', 'قت', 'رق', 'زن', 'جل', 'هن', 'طن', 'ثق')


def clusters(word):
    out = []
    for ch in word.replace('ٱ', 'ا').replace('ﭐ', 'ا'):
        if _ignorable(ch):
            continue
        if ch in MARKS:
            if out:
                out[-1][1].append(ch)
            continue
        if 'ء' <= ch <= 'ۿ':
            out.append([ch, []])
    # Indo-Pak text writes every final yā' as ى, so ى is only an alif maqsura
    # when it is bare and does not follow a kasra: فِىْ, عَلِىٍّ, وَهِىَ are yā'.
    for i, (ch, mk) in enumerate(out):
        if ch == 'ى' and (set(mk) - {DAGGER} or (i and KASRA in out[i - 1][1])):
            out[i][0] = 'ي'
    return out


def vowel(mk):
    return next((VOWELS[m] for m in mk if m in VOWELS), None)


def tanween(mk):
    return next((TANWEEN[m] for m in mk if m in TANWEEN), None)


def skeleton(cl):
    return ''.join(c for c, _ in cl)


def phonemes(cl):
    """Phoneme string for a list of clusters (no prefix/article handling)."""
    out = ''
    sk = skeleton(cl)
    silent_waw = re.match(r'^ا?ول(ي|و|ئ|ا|ٰ)', sk) is not None and len(cl) > 1 and SUKUN not in cl[1][1] \
        and vowel(cl[0][1]) in ('U', None)   # اُولِي، اُولُو، اُولٰئِكَ
    prev_bare = False
    for i, (ch, mk) in enumerate(cl):
        v, tan = vowel(mk), tanween(mk)
        last = i == len(cl) - 1
        if ch == 'و' and silent_waw and i == 1:
            continue
        if ch == 'آ':
            out += 'A' if out.endswith('A') and not out.endswith('AA') else (("'" if out else '') + 'AA')
            prev_bare = False
            continue
        if ch in 'اى':
            if DAGGER in mk and ch == 'ا':
                out += ("'" if out else '') + 'AA'
            elif ch == 'ا' and SUKUN in mk:
                out += "'"
            elif ch == 'ا' and tan and not v and out:
                if not out.endswith('AN'):
                    out += 'AN'                        # ـاً : the alif only carries the tanween
            elif ch == 'ا' and (v or tan):
                out += ("'" if out else '') + (v or '') + (tan or '')
            elif out.endswith('AA') or out.endswith('OO') or out.endswith('EE'):
                pass
            elif out.endswith("'") and len(out) == 2:
                out += 'A'                             # initial 'ayn + alif: A'ABID
            elif out.endswith('A'):
                out += 'A'
            elif out.endswith('AN') or (out.endswith('U') and last):
                pass                                   # -an + silent alif; waw al-jama'a
            elif prev_bare or (out and out[-1] not in 'AIU'):
                out += 'AA'                            # under-vowelled source: لا -> LAA
            prev_bare = False
            continue
        nxt = cl[i + 1] if i + 1 < len(cl) else None
        if ch == 'و' and nxt and nxt[0] == 'ا' and tanween(nxt[1]):
            out += 'WW' if SHADDA in mk else 'W'       # كُفُواً، عُلُوّاً
            continue
        if ch in 'وي' and not v and not tan and SHADDA not in mk and DAGGER not in mk:
            if re.fullmatch(r"[AIU]'", out) and {'I': 'ي', 'U': 'و'}.get(out[0]) == ch:
                out += {'I': 'EE', 'U': 'OO'}[out[0]]       # initial 'ayn + long vowel: I'EESAA
                prev_bare = False
                continue
            if out.endswith('U') and ch == 'و':
                out = out[:-1] + 'OO'
                prev_bare = False
                continue
            if out.endswith('I') and ch == 'ي':
                out = out[:-1] + 'EE'
                prev_bare = False
                continue
            if prev_bare and ch == 'ي':
                out += 'EE'
                prev_bare = False
                continue
            if out.endswith('A') and SUKUN not in mk and last and ch == 'ي':
                out += 'A'                              # ى written as ي: عَلَي
                continue
        if ch == 'ي' and DAGGER in mk:
            out += 'A' if out.endswith('A') else 'AA'
            continue
        c = CONS.get(ch, '')
        if not out and (ch in HAMZA_SEATS or ch == 'ع'):
            # word-initial hamza is silent; word-initial 'ayn is written vowel-first (A'LAA)
            if not v and not tan:
                v = {'إ': 'I', 'أ': 'A'}.get(ch, '')
            out += (v or (tan or '')) + ("'" if ch == 'ع' else '')
            if DAGGER in mk:
                out += 'A'
            prev_bare = False
            continue
        if ch == 'ع' and SUKUN not in mk and (v or tan) and out and out[-1] not in "AIU'":
            pass
        if c == 'H' and i > 0 and cl[i - 1][0] in 'سشكدتغذثخطصض' and not vowel(cl[i - 1][1]):
            out += '-'                                 # ASH-HADU, not ASHHADU
        if SHADDA in mk:
            out += c
        out += c
        if v:
            out += v
        if tan:
            out += tan
        if DAGGER in mk:
            out += 'A' if v == 'A' or not v else ''
            if not v:
                out += 'A'
        prev_bare = not (v or tan or SUKUN in mk or SHADDA in mk or DAGGER in mk)
        if any(m in SILAH_MARKS for m in mk) and ch in 'هہ':
            out = out[:-1] + SILAH_MARKS[next(m for m in mk if m in SILAH_MARKS)]
    return out


class Word:
    """One space-separated Arabic word, split into prefix + body."""

    def __init__(self, raw):
        cl = clusters(raw)
        self.idgham = bool(cl) and SHADDA in cl[0][1] and cl[0][0] != 'ا' and not (len(cl) > 1 and cl[0][0] == 'ل' and cl[1][0] == 'ل')
        if self.idgham:
            cl[0][1] = [m for m in cl[0][1] if m != SHADDA]   # Indo-Pak idgham mark: مِّنْ, وَّ
        self.tanween_end = bool(cl) and any(m in TANWEEN for m in cl[-1][1]) or \
            (len(cl) > 1 and cl[-1][0] == 'ا' and any(m in TANWEEN for m in cl[-1][1] + cl[-2][1]))
        self.quta = bool(cl) and cl[0][0] == 'ا' and vowel(cl[0][1]) == 'A'
        self.prefix = ''        # WA / FA / BI / LI / KA
        self.kind = 'plain'     # plain | article | wasl | allah
        self.sep = ' '          # how the prefix attaches: ' ', '-', ''
        self.inner = ''         # BI-/LI-/FA- before a hamza, after any WA
        if not cl:
            self.cl = cl
            return
        sk = skeleton(cl)
        # Allah / Allahumma, possibly with a prefix
        m = re.match(r'^([وفبل]?)(ا?لل|لل)ه(م?)$', sk.replace('ٰ', ''))
        if m and (m.group(2) == 'الل' or m.group(1) == 'ل' or m.group(2) == 'لل'):
            self.kind = 'allah'
            self.prefix = {'و': 'WA', 'ف': 'FA', 'ب': 'BI', 'ل': 'LI'}.get(m.group(1), '')
            if not m.group(1) and m.group(2) == 'لل' and vowel(cl[0][1]) == 'I':
                self.prefix = 'LI'
            # suffix after the ه
            hi = max(i for i, (c, _) in enumerate(cl) if c in 'هہ')
            self.allah_tail = (vowel(cl[hi][1]) or '') + phonemes([['م', cl[hi + 1][1]]] + cl[hi + 2:])[0:] if hi + 1 < len(cl) else (vowel(cl[hi][1]) or '')
            if hi + 1 < len(cl):
                self.allah_tail = (vowel(cl[hi][1]) or '') + phonemes(cl[hi + 1:])
            self.cl = cl
            return
        # prefix + article: وَالْ بِالْ فَالْ كَالْ ; لِلْ
        if len(cl) > 3 and cl[0][0] in 'وفبك' and cl[1][0] == 'ا' and not vowel(cl[1][1]) and cl[2][0] == 'ل' \
                and not vowel(cl[2][1]):
            self.prefix = {'و': 'WA', 'ف': 'FA', 'ب': 'BI', 'ك': 'KA'}[cl[0][0]]
            cl = cl[1:]
        elif len(cl) > 2 and cl[0][0] == 'ل' and cl[1][0] == 'ل' and vowel(cl[0][1]) == 'I' \
                and (SUKUN in cl[1][1] or not cl[1][1] or SHADDA in cl[2][1]):
            self.prefix = 'LI'
            cl = [['ا', []]] + cl[1:]
        # prefix + hamzat al-wasl (فَاسْتَجَبْتَ / وَاغْفِرْ)
        elif len(cl) > 3 and cl[0][0] in 'وف' and vowel(cl[0][1]) == 'A' and cl[1][0] == 'ا' \
                and not vowel(cl[1][1]) and not tanween(cl[1][1]) and DAGGER not in cl[1][1] \
                and (SUKUN in cl[2][1] or (SHADDA in cl[2][1] and cl[2][0] != 'ل') or (len(cl) > 3 and cl[2][0] == 'ل' and SHADDA in cl[3][1])):
            self.prefix = {'و': 'WA', 'ف': 'FA'}[cl[0][0]]
            self.sep = ''
            cl = cl[1:]
        # wa + word (the word may itself start with bi-/li-/fa- + hamza)
        elif len(cl) > 2 and cl[0][0] == 'و' and vowel(cl[0][1]) == 'A' and SHADDA not in cl[0][1] \
                and (vowel(cl[1][1]) or tanween(cl[1][1]) or SHADDA in cl[1][1] or DAGGER in cl[1][1] or cl[1][0] in HAMZA_SEATS
                     or (cl[1][0] == 'ا' and (vowel(cl[1][1]) or DAGGER in cl[1][1])) or cl[1][0] == 'آ') \
                and not (cl[1][0] != 'ا' and skeleton(cl[1:3]) in WAW_STEMS) \
                and not skeleton(cl[1:4]) in ('فات', 'فاء', 'فاة', 'فاي') \
                and not (skeleton(cl[1:3]) == 'صل' and len(cl) > 2 and SHADDA not in cl[2][1]) \
                and not (skeleton(cl[1:3]) == 'دو' and vowel(cl[1][1]) == 'U') \
                and not (skeleton(cl[1:3]) == 'جد' and len(cl) > 2 and SHADDA not in cl[2][1]) \
                and not (skeleton(cl[1:3]) == 'هب' and len(cl) > 2 and vowel(cl[2][1])) \
                and not (skeleton(cl[1:3]) == 'فق' and SHADDA in cl[1][1]) \
                and not (skeleton(cl[1:3]) == 'في' and vowel(cl[1][1]) == 'A'):
            self.prefix = 'WA'
            cl = cl[1:]
        # (fa/bi/li/ka) + hamza or (bi/li) + 'ayn: فَاِنَّ بِاَنَّ لِاٰدَمَ بِعَظَمَةِ
        if len(cl) > 2 and cl[0][0] in 'فبلك' and vowel(cl[0][1]) in ('A', 'I') \
                and (cl[1][0] in HAMZA_SEATS or cl[1][0] == 'آ' or (cl[1][0] == 'ا' and (vowel(cl[1][1]) or DAGGER in cl[1][1]))
                     or (cl[1][0] == 'ع' and cl[0][0] in 'بل' and vowel(cl[0][1]) == 'I' and vowel(cl[1][1]))):
            self.inner = {'ف': 'FA', 'ب': 'BI', 'ل': 'LI', 'ك': 'KA'}[cl[0][0]] + '-'
            cl = cl[1:]
        if cl and SUKUN in cl[0][1] and not self.prefix and len(cl) > 1:
            self.kind = 'glue'                 # بْنِ / بْنَ: alif elided, reads on from the previous word
        # wa + (bi/fa/ka/li) + article: وَبِالْاِسْمِ / وَلِلْ
        if self.prefix == 'WA' and len(cl) > 3 and cl[0][0] in 'بفك' and cl[1][0] == 'ا' and not vowel(cl[1][1]) \
                and cl[2][0] == 'ل' and not vowel(cl[2][1]):
            self.prefix = 'WA ' + {'ب': 'BI', 'ف': 'FA', 'ك': 'KA'}[cl[0][0]]
            cl = cl[1:]
        if cl and cl[0][0] == 'ا' and vowel(cl[0][1]) == 'A' and not self.prefix and not self.inner and len(cl) > 2 \
                and cl[1][0] == 'ل' and not vowel(cl[1][1]) and (SUKUN in cl[1][1] or SHADDA in cl[2][1]):
            self.kind = 'article'              # utterance-initial اَلسَّلَامُ / اَلْحَمْدُ
            self.sun = SHADDA in cl[2][1] and cl[2][0] in SUN
            cl = cl[2:]
        elif cl and cl[0][0] == 'ا' and not vowel(cl[0][1]) and not tanween(cl[0][1]) and DAGGER not in cl[0][1] and len(cl) > 1:
            if cl[1][0] == 'ل' and len(cl) > 2 and SHADDA in cl[1][1]:
                self.kind = 'article'          # الَّذِي / الَّتِي / اللَّيْل: the article's lam is assimilated
                self.sun = True
                cl = cl[1:]
            elif cl[1][0] == 'ل' and len(cl) > 2 and not vowel(cl[1][1]):
                self.kind = 'article'
                self.sun = cl[2][0] in SUN and (SHADDA in cl[2][1] or not cl[1][1])
                cl = cl[2:]
            else:
                self.kind = 'glue' if skeleton(cl) in ('ابن', 'ابنة') else 'wasl'
                cl = cl[1:]
        self.cl = cl

    def body(self):
        return self.inner + phonemes(self.cl)


def shorten(s):
    for a, b in (('AA', 'A'), ('EE', 'I'), ('OO', 'U')):
        if s.endswith(a):
            return s[:-2] + b
    return s


def head(s):
    m = re.match(r"(TH|DH|SH|KH|GH|[A-Z'])", s)
    return m.group(1) if m else ''


def pausal(s):
    if s.endswith(TM + 'AN') or re.search(TM + '(IN|UN|A|I|U)$', s):
        return re.sub(TM + '(AN|IN|UN|A|I|U)$', 'H', s)
    if s.endswith(TM):
        return s[:-1] + 'H'
    if s.endswith('AN') and not s.endswith('AAN'):
        return s[:-2] + 'AA'
    if re.search(r'[^AIU](IN|UN)$', s) or s.endswith("'IN") or s.endswith("'UN"):
        return s[:-2]
    if re.search(r'(HOO|HEE)$', s):
        return s[:-2]
    if re.search(r'[AIU]$', s) and not re.search(r'(AA|EE|OO)$', s):
        return s[:-1]
    return s


def silah(s, next_runs_on):
    if next_runs_on:
        return s
    if re.search(r'[AIU]H[UI]$', s) and not re.search(r'(AA|EE|OO)H[UI]$', s):
        return s[:-1] + ('OO' if s.endswith('U') else 'EE')
    return s


MUQATTAAT = {'عسق': "A'YN SEEN QAAAF", 'كهيعص': "KAAAF HAA YAA A'YN SAAAD", 'يس': 'YAA SEEN', 'طه': 'TAA HAA', 'حم': 'HAA MEEM',
             'الم': 'ALIF LAAAM MEEM', 'المص': 'ALIF LAAAM MEEM SAAAD', 'الر': 'ALIF LAAAM RAA',
             'طس': 'TAA SEEN', 'طسم': 'TAA SEEN MEEM', 'ص': 'SAAAD', 'ق': 'QAAAF', 'ن': 'NOON'}


def _muqattaat(word):
    sk = re.sub('[^\u0621-\u064a]', '', word.replace('ٰ', ''))
    pre = ''
    if sk[:1] == 'و' and sk[1:] in MUQATTAAT and ('\u0653' in word or not re.search('[\u064b-\u0652]', word[2:])):
        pre, sk = 'WA ', sk[1:]
    rest = word[2:] if pre else word
    if sk in MUQATTAAT and ('\u0653' in word or 'ٰ' in word or not re.search('[\u064b-\u0652]', rest)):
        return pre + MUQATTAAT[sk]
    return None


def transliterate(line, pause=True):
    special = {i: _muqattaat(t) for i, t in enumerate(line.split())}
    if any(special.values()):
        parts, buf = [], []
        for i, t in enumerate(line.split()):
            if special[i]:
                if buf:
                    parts.append(transliterate(' '.join(buf), pause=False))
                    buf = []
                parts.append(special[i])
            else:
                buf.append(t)
        if buf:
            parts.append(transliterate(' '.join(buf), pause))
        return ' '.join(parts)
    words = [Word(t) for t in line.split()]
    words = [w for w in words if w.cl]
    toks = []    # rendered tokens; a join rewrites the previous one
    tanw = []    # whether each token ends in tanween

    def run_on(extra):
        """Previous token flows into a hamzat al-wasl: shorten a long vowel, or
        give tanween its helping kasra (MUHAMMADINIS SAADIQ)."""
        prev = toks[-1]
        prev = prev + 'I' if tanw[-1] else shorten(silah(prev, True))
        toks[-1] = prev + extra
        tanw[-1] = False

    for w in words:
        b = w.body() if w.kind != 'allah' else ''
        if w.kind == 'allah':
            body = 'LLAAH' + w.allah_tail
            if w.prefix == 'WA':
                toks.append('WA' + body)
            elif w.prefix == 'FA':
                toks.append('FA' + body)
            elif w.prefix in ('BI', 'LI'):
                toks.append(w.prefix[0] + 'I' + body)
            elif toks and not w.quta:
                run_on(body)
                continue
            else:
                toks.append('A' + body)
            tanw.append(False)
            continue
        if w.kind == 'article':
            c = head(b) if w.sun else 'L'
            rest = b[len(c):] if w.sun else b
            if w.prefix:
                toks.append(w.prefix + c + ' ' + rest)
            elif toks:
                run_on(c)
                toks.append(rest)
            else:
                toks.append('A' + c + ('' if c == 'L' or not w.sun else '-') + rest if w.sun else 'AL-' + rest)
            tanw.append(w.tanween_end)
            continue
        if w.kind in ('wasl', 'glue'):
            if w.kind == 'glue':
                if w.prefix:
                    toks.append(w.prefix + b)
                    tanw.append(w.tanween_end)
                elif toks:
                    run_on(b)
                    tanw[-1] = w.tanween_end
                else:
                    toks.append('I' + b)
                    tanw.append(w.tanween_end)
                continue
            c = head(b)
            rest = b[len(c):]
            if re.match(r"'[AIU]", rest) and not w.prefix:
                rest = rest[1] + "'" + rest[2:]
            if w.prefix:
                toks.append(w.prefix + c + rest)
            elif toks:
                run_on(c)
                toks.append(rest)
            else:
                toks.append('I' + c + rest)
            tanw.append(w.tanween_end)
            continue
        # tanween assimilates into a following ر ل م ن (AHADIM MIN, GHAFOORUR RAHEEM)
        if toks and (tanw[-1] or re.search(r'[AIU]N$', toks[-1])) and w.idgham and not w.prefix and head(b) in ('R', 'L', 'M', 'N'):
            c = head(b)
            toks[-1] = toks[-1][:-1] + c
            if b.startswith(c + c):
                b = b[1:]
        if w.prefix:
            if w.sep == '':
                toks.append(w.prefix + b)
            else:
                toks.append(w.prefix)
                tanw.append(False)
                toks.append(b)
        else:
            toks.append(b)
        tanw.append(w.tanween_end)
    out = [silah(t, False) if i < len(toks) - 1 else t for i, t in enumerate(toks)]
    if out and pause:
        out[-1] = pausal(out[-1])
    return ' '.join(t for t in out if t).replace(TM, 'T')


def check():
    tot = same = 0
    for u in 'F16 F17 F18 F19 F20 F21 F22 F23 F24 F25'.split():
        L = json.load(open(f'assets/zikr/{u}'))['data'].split('\n')
        for i in range(len(L) - 1):
            if re.search('[؀-ۿ]', L[i]) and re.fullmatch(r"[A-Z' \-,.!?()]+", L[i + 1].strip() or '#'):
                tot += 1
                got = transliterate(L[i])
                if got == L[i + 1].strip():
                    same += 1
                elif '-v' in sys.argv:
                    print(f'{u}: {L[i]}\n   want {L[i + 1]}\n   got  {got}')
    print(f'{same}/{tot} identical')


if __name__ == '__main__':
    if '--check' in sys.argv:
        check()
    else:
        for a in sys.argv[1:]:
            print(transliterate(a))
