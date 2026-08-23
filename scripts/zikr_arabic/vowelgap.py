#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Vowels on a word-initial alif: missing where required, present where elided.

Two hamzas behave differently and the corpus conflates them.

  hamzat al-qat`   أَشْهَدُ  أَكْبَر  أَبَا  أَيُّهَا
      always pronounced, so always carries its vowel, at any position.

  hamzat al-wasl   the article, form-I imperatives اِغْفِرْ اُدْخُلْ,
                   forms VII/VIII/X, and ابن اسم امرأة
      pronounced only when it OPENS the utterance. Mid-phrase it elides:
      اَللّٰهُمَّ اغْفِرْ is read allahumma-ghfir, so the alif stays bare.
      Its vowel when it is initial is kasra, or damma when the imperfect
      stem vowel is u (اُدْخُلْ from يَدْخُلُ).

Measured on the corpus: qat` is vowelled 86% line-initial and 84% mid-line --
position-independent, as expected. Wasl is 70% vowelled line-initial but
599/619 mid-line.

A mid-line wasl alif that DOES carry a vowel is reported as `leave-wasl-vowel`
and must never be auto-stripped. Elision needs genuinely continuous speech:
اَللّٰهُمَّ اغْفِرْ elides, but يَا سَرِيْعَ الرِّضَا اِغْفِرْ has a pause after
the vocative, and a pause restores the hamza. Pauses are not marked in the
text, so the two cases are indistinguishable here. Reported for information,
never actioned.

The vowel is not guessed. For each bare word the corpus is used as its own
dictionary: every other spelling of the same skeleton that DOES carry a vowel
on the initial alif is collected, and that vowel is proposed. This keeps the
fill consistent with the author's own usage rather than with a general rule,
and it reports its own confidence — a skeleton spelled two different ways
elsewhere is flagged rather than filled.

  python3 scripts/zikr_arabic/vowelgap.py [--json out.json] [uid …]
"""
import sys, re, json, collections
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from corpus import arabic_strings, MARKS, skeleton

# Buckets cleared to be written. leave-wasl-vowel is never actioned (a pause
# before the word restores the hamza and pauses are not marked in the text);
# no-precedent and wasl-imperative await a decision.
ACTIONABLE = {'confident', 'qat-imperfect', 'qat-double-hamza', 'ambiguous'}

VOWELS = 'َُِ'
LETTERS = re.compile(r'[^ء-ي]')

# Hamzat al-wasl: correctly written with a bare alif, so NOT a missing vowel.
# The definite article, plus the handful of wasl nouns and the derived verb
# forms (VII/VIII/X) whose imperative and perfect both take wasl.
WASL_STEM = re.compile(r'^(ابن|ابنة|اسم|امرا|امرء|اثن|امرؤ'
                      r'|ان[تفقدص]|است|اجت|اخت|اعت|ارت|ازد|اصط|اضط|اهت|اقت|افت|احت|ابت|اتت'
                      r'|ات[خقبصفحسع])')

WASL = re.compile(r'^(ال'
                  r'|ابن|ابنة|اسم|امرا|امرء|اثن|امرؤ'
                  r'|ان[تفقدص]|است|اجت|اخت|اعت|ارت|ازد|اصط|اضط|اهت|اقت|افت|احت|ابت|اتت'
                  r'|ات[خقبصفحسع])')

def key(word):
    return LETTERS.sub('', skeleton(word))

SUFFIX = re.compile(r'(نِ?ىْ?|نَا|هُ|هٗ|هَا|هُمْ|كَ|كُمْ|نِيْ|نِیْ)$')

def verb_shape(word):
    """اِجْعَلْ (imperative, hamzat al-wasl -> bare alif is defensible) and
    اَشْهَدُ (1st-person imperfect, hamzat al-qat` -> genuinely missing its
    zabar) have the same consonant skeleton. The final vowel separates them:
    an imperative is jussive and ends in sukun, the imperfect is indicative
    and ends in damma."""
    w = SUFFIX.sub('', word).rstrip('،.:؛')
    letters = LETTERS.sub('', skeleton(w))
    # Form-I imperative: alif + exactly three root letters, sukun on the first
    # root letter, jussive sukun at the end -- اِغْفِرْ, اُدْخُلْ, اِرْحَمْ.
    # Length matters: without it every particle ending in sukun (اَنْ, اَوْ,
    # اَمْ, اِذْ) is swept up as an imperative and wrongly treated as wasl.
    sukun_on_root1 = re.match(r'^ا[\u064E\u064F\u0650]?[ء-ي]ْ', w)
    if sukun_on_root1 and len(letters) == 4 and w.endswith('ْ'):
        return 'imperative'
    # Defective (final-weak) verbs lose the last radical in the jussive, so the
    # imperative is three letters and ends on a bare short vowel rather than a
    # sukun: اِقْضِ from قضى, اُدْعُ from دعا, اِرْمِ from رمى.
    if sukun_on_root1 and len(letters) == 3 and w[-1] in '\u0650\u064F':
        return 'imperative'
    if w.endswith('ُ'):
        return 'imperfect'           # hamzat al-qat`, needs a zabar
    return 'other'

def is_wasl(k, w):
    """Hamzat al-wasl: the wasl nouns and forms VII/VIII/X have a recognisable
    stem, but a form-I imperative is just ا + three root letters, so it has to
    be caught by shape (jussive, ends in sukun) instead."""
    return bool(WASL_STEM.match(k)) or verb_shape(w) == 'imperative'

def survey(uids=None):
    """(bare, vowelled) — occurrences of each skeleton with and without a
    vowel on its initial alif."""
    bare = collections.Counter()
    extra = collections.Counter()
    where = collections.defaultdict(list)
    where_x = collections.defaultdict(list)
    vowelled = collections.defaultdict(collections.Counter)
    for uid, path, s in arabic_strings(uids):
        for line in s.split('\n'):
            for i, w in enumerate(line.split()):
                if not w or w[0] != 'ا':
                    continue
                k = key(w)
                if len(k) < 2 or WASL.match(k):
                    continue
                initial = (i == 0)
                if len(w) > 1 and w[1] in VOWELS:
                    vowelled[k][w[1]] += 1
                    # A fatha PROVES hamzat al-qat`: wasl only ever takes
                    # kasra or damma. اَصْلِحْ / اَظْهِرْ are form-IV
                    # imperatives (qat`), structurally identical to the form-I
                    # اِغْفِرْ (wasl) but for that vowel, and nothing else in
                    # the orthography separates them.
                    if is_wasl(k, w) and not initial and w[1] != 'َ':
                        extra[k] += 1
                        if len(where_x[k]) < 3:
                            where_x[k].append((uid, line.strip(), w))
                elif len(w) < 2 or w[1] not in MARKS:
                    if is_wasl(k, w) and not initial:
                        continue          # correct: elided mid-phrase
                    bare[k] += 1
                    if len(where[k]) < 3:
                        where[k].append((uid, line.strip(), w, initial))
    return bare, vowelled, where, extra, where_x

def proposals(uids=None):
    bare, vowelled, where, extra, where_x = survey(uids)
    out = []
    for k, n in bare.most_common():
        v = vowelled.get(k)
        if not v:
            state, mark = 'no-precedent', None
        elif len(v) == 1:
            state, mark = 'confident', next(iter(v))
        else:
            top, second = v.most_common(2)
            state = 'confident' if top[1] >= 5 * second[1] else 'ambiguous'
            mark = top[0]
        ex = where[k][0]
        shape = verb_shape(ex[2])
        if k.startswith('اا'):
            # Interrogative hamza on a 1st-person imperfect: أَ + أَدْخُلُ, the
            # isti'dhan formula "may I enter?". Both hamzas are qat`, so both
            # take a fatha -- not a doubled-alif typo.
            w = ex[2]
            out.append(dict(skeleton=k, n=n, state='qat-double-hamza',
                            mark='َ', shape='interrogative', precedent={},
                            uid=ex[0], word=w, after=w[0] + 'َ' + w[1] + 'َ' + w[2:],
                            line=ex[1]))
            continue
        if not ex[3] and shape == 'imperative':
            continue          # mid-line wasl imperative: bare is correct
        if state == 'no-precedent' and shape == 'imperative':
            state = 'wasl-imperative'
        elif state == 'no-precedent' and shape == 'imperfect' and not mark:
            state, mark = 'qat-imperfect', 'َ'
        out.append(dict(skeleton=k, n=n, state=state, mark=mark, shape=shape,
                        precedent=dict(v) if v else {},
                        uid=ex[0], word=ex[2],
                        after=(ex[2][0] + mark + ex[2][1:]) if mark else None,
                        line=ex[1]))
    for k, n in extra.most_common():
        ex = where_x[k][0]
        out.append(dict(skeleton=k, n=n, state='leave-wasl-vowel', mark=None,
                        shape='wasl', precedent={}, uid=ex[0], word=ex[2],
                        after=ex[2][0] + ex[2][2:], line=ex[1]))
    return out

def main(argv):
    out = None
    if '--json' in argv:
        i = argv.index('--json'); out = argv[i + 1]; argv = argv[:i] + argv[i + 2:]
    from batch import expand
    rows = proposals(set(expand(argv)) or None)
    by = collections.Counter(r['state'] for r in rows)
    tot = sum(r['n'] for r in rows)
    print(f'{tot} bare word-initial alif, {len(rows)} distinct words')
    for st in ('confident', 'qat-imperfect', 'qat-double-hamza', 'ambiguous',
               'wasl-imperative', 'leave-wasl-vowel', 'no-precedent'):
        rs = [r for r in rows if r['state'] == st]
        print(f'  {st:<13} {len(rs):>4} words / {sum(r["n"] for r in rs):>5} occurrences')
    print()
    for st in ('qat-imperfect', 'ambiguous', 'no-precedent'):
        rs = [r for r in rows if r['state'] == st][:12]
        if rs:
            print(f'-- {st}:')
            for r in rs:
                print(f'   {r["word"]:<16} x{r["n"]:<4} precedent={r["precedent"]}')
    if out:
        json.dump(rows, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        print(f'\n-> {out}')
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
