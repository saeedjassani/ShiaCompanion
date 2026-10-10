#!/usr/bin/env python3
"""Print a zikr entry with its raw line numbers, part by part.

    python3 scripts/zikr_structure/dump.py J8           # full lines
    python3 scripts/zikr_structure/dump.py J8 --short   # lines cut to 70 chars

Each line is tagged A (Arabic), t (transliteration), T (translation),
N (standalone note) or blank. Line numbers are indexes into that part's
raw text split on '\\n' (label included), so a build script can slice
`entry['data'].split('\\n')[a:b]` / `entry['tabs'][k].split('\\n')[a:b]`.
"""
import sys

import corpus

TAG = {'arabic': 'A', 'translit': 't', 'translation': 'T', 'note': 'N', 'blank': ' '}


def main():
    import signal
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    uid = sys.argv[1]
    short = '--short' in sys.argv
    entry = corpus.load_entry(uid)
    raw = corpus.parts_of(entry)
    names = (['data'] if (entry.get('data') or '').strip() else []) + \
        [f'tabs[{i}]' for i, t in enumerate(entry.get('tabs') or []) if (t or '').strip()]
    print(f"# {uid}: {entry['title']}")
    for name, text, part in zip(names, raw, corpus.parse_parts(entry)):
        print(f'\n## {name}' + (f'  label: {part.label!r}' if part.label is not None else ''))
        offset = 1 if part.label is not None else 0
        if offset:
            print(f'   0 L {text.split(chr(10))[0]}')
        for i, (k, line) in enumerate(zip(part.kind, part.lines)):
            if short and len(line) > 70:
                line = line[:70] + f'... [{len(line)}c]'
            print(f'{i + offset:4} {TAG[k]} {line}')
    if (entry.get('merits') or '').strip():
        print('\n## merits')
        for i, line in enumerate(entry['merits'].split('\n')):
            if short and len(line) > 70:
                line = line[:70] + f'... [{len(line)}c]'
            print(f'{i:4} {line}')


if __name__ == '__main__':
    main()
