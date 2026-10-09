"""Decoder for the Gujarati Quran's PageMaker 6.5 file (GujQuran.p65).

The book is set in legacy 8-bit Gujarati fonts (GJ Falgun / GJ Patrkn), so
its text stream holds glyph codes, not Unicode. Most consonants are a
half-form glyph plus a vertical stem (0xC9), and the aa-sign is that same
stem glyph again; 0xC9 0xCA is the i-sign, drawn before its consonant; the
repha glyphs (0xC7, 0xC8, 0xE6, 0xE7, 0xD4) put RA+virama in front of the
syllable they sit over. decode()/dec2() turn one line of glyph codes into
Unicode Gujarati. This is what produced assets/zikr_i18n/gu/A5-A118.

The text stream is the run of printable bytes in the file's single
'PageMaker' OLE stream, with its zero padding removed; lines are split on
CR, and verse lines start with their number ("12. ").
"""
H={0x2b:'અ',0x78:'ન',0x69:'ત',0xdf:'મ',0xba:'સ',0xaa:'ય',0x7b:'પ',0xb6:'શ',0x8a:'વ',0x42:'લ',0x6c:'થ',0x68:'ણ',0x4d:'ગ',0x4a:'ખ',0xa4:'બ',0x9b:'ભ',0x50:'ઘ',0x76:'ધ',0x89:'ળ',0x44:'ષ',0x53:'ચ',0x59:'જ્ઞ',0x49:'ક્ષ',0xb8:'લ્લ',0xbf:'હ્ય',0x6a:'ત્ર',0x6b:'ત્ત',0x7a:'ન્ન',0x7c:'પ્ર',0x4f:'ગ્ર',0xa5:'બ્ર',0x92:'શ્ર',0x48:'સ્ત્ર',0x83:'ચ્ચ',0xa6:'શ્ચ',0xb7:'શ્વ',0x4c:'ખ્ર',0x77:'ધ્ર',0xa9:'મ્ર',0x3e:'ઊ',0x43:'પ',0xd8:'હ',0xa7:'ભ્ર',0xf0:'શ્ન',0xbb:'સ્ર'}
HSTEMLESS={0x2a:'જ'}
F={0x45:'ક',0x56:'જ',0x4e:'જી',0x55:'છ',0xae:'ર',0x46:'હ',0x6e:'દ',0x62:'ડ',0x5d:'ટ',0xf1:'ઠ',0x66:'ઢ',0x61:'ઠ્ઠ',0x9c:'ઝ',0xa1:'ફ',0x7d:'ફ',0x47:'ક્ર',0xaf:'ક્ક',0xa3:'ફ્ર',0x71:'હૃ',0x70:'દ્ર',0x72:'દ્ધ',0x75:'દ્વ',0x67:'દ્દ',0xe3:'જ્જ',0x93:'ષ્ટ',0xb0:'રૂ',0xe0:'રુ',0x3c:'ઈ',0x9a:'ઈ',0x3d:'ઉ',0x5e:'ટ્ટ',0xbe:'ઈં',0xb5:'ઈં'}
VOWELS={'અ','ઈ','ઉ','ઊ'}
MATRA={0xd6:'ુ',0xda:'ૂ',0xdd:'ૂ',0xd9:'ૂ',0x4b:'ૃ',0xe4:'ે',0xe5:'ેં',0xe8:'ૈ',0xe9:'ૈં',0xc6:'ં',0xc2:'્',0xc1:'્',0xd2:'ી',0xd3:'ીં'}
AFTER_STEM={0xd2:'ી',0xd3:'ીં',0xd4:'ી',0xe4:'ો',0xe5:'ોં',0xe6:'ો',0xe8:'ૌ',0xe9:'ૌં'}
REPHA={0xc7:'',0xc8:'ં',0xe6:'ે',0xe7:'ે',0xd4:''}
IGN={0xf2,0xf5,0xfb,0xfc,0xf3}
IMAT={0xca,0xcb,0xcc,0xce}
unknown={}
def decode(bs):
    out=[];syl=0;wait=None;pend_i=False
    def emit_cons(letter):
        nonlocal syl,pend_i
        if not (out and out[-1]=='્'): syl=len(out)
        out.append(letter)
        if pend_i: out.append('િ'); pend_i=False
    def flush():
        nonlocal wait,syl
        if wait is not None:
            if not (out and out[-1]=='્'): syl=len(out)
            out.append(wait); out.append('્'); wait=None
    i=0;n=len(bs)
    while i<n:
        b=bs[i]; nx=bs[i+1] if i+1<n else None
        if b in IGN: i+=1; continue
        if b==0xc9:
            if nx in IMAT: flush(); pend_i=True; i+=2; continue
            if wait is not None:
                l=wait; wait=None; emit_cons(l); i+=1
                continue
            if nx in AFTER_STEM:
                out.append(AFTER_STEM[nx])
                if nx in (0xd4,0xe6): out.insert(syl,'ર્')
                i+=2; continue
            out.append('ા'); i+=1; continue
        if b in H or b in HSTEMLESS:
            flush()
            if b in HSTEMLESS:
                if nx==0xc9: emit_cons(HSTEMLESS[b]); out.append('ા'); i+=2; continue
                wait=HSTEMLESS[b]; i+=1; continue
            wait=H[b]; i+=1; continue
        if b in F:
            flush(); emit_cons(F[b]); i+=1; continue
        flush()
        if b in REPHA: out.insert(syl,'ર્'); out.append(REPHA[b]); i+=1; continue
        if b in MATRA: out.append(MATRA[b]); i+=1; continue
        if b==0x22 and nx==0x22: out.append('“'); i+=2; continue
        if b==0x27 and nx==0x27: out.append('”'); i+=2; continue
        if b==0x60 and nx==0x60: out.append('“'); i+=2; continue
        if 0x20<=b<0x7f and chr(b) in ' .,;:!?()-"\'0123456789[]/*': out.append(chr(b)); i+=1; continue
        unknown[b]=unknown.get(b,0)+1; out.append('�'); i+=1
    flush()
    s=''.join(out)
    return s
STEMLESS_LETTERS_PENDING=set()
import re as _re
NORM=[('ાેં','ોં'),('ાે','ો'),('ાૈં','ૌં'),('ાૈ','ૌ'),('અાં','આં'),('અા','આ'),('અેં','એં'),('અે','એ'),('અોં','ઓં'),('અો','ઓ'),('અૈ','ઐ'),('અૌ','ઔ')]
def dec(bs):
    s=decode(bs)
    for a,b in NORM: s=s.replace(a,b)
    return s
_M='ાિીુૂેૈોૌંૃ'
def dec2(bs):
    s=dec(bs)
    s=_re.sub('(['+_M+'])\\1+',r'\1',s)
    s=s.replace('ોે','ો').replace('ેો','ો')
    return s
