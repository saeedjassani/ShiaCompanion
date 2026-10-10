#!/usr/bin/env python3
"""Remove a zikr entry the safe way (docs/ZIKR_STRUCTURE.md, rule 6).

    python3 scripts/zikr_structure/retire.py <uid> <target> "<why, one line>"
    python3 scripts/zikr_structure/retire.py <uid> <target> "<why>" --tab 2

Deletes assets/zikr/<uid> and its assets/zikr.json key, redirects the uid to
<target> in lib/data/retired_zikr_redirects.dart (so an old favorite still
opens something), adds the uid's slug to <target>'s slugAliases (so an old
link resolves), drops its title from every assets/zikr_i18n/<code>/index.json,
and lists any [..](<uid>) link in the corpus that now needs pointing at
<target>. Refuses an entry that has audio, an alias pointing at it, or a
target that is not live.
"""
import argparse
import json
import os
import re
import sys
import textwrap

import corpus


def dump_json(path, data, indent):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=indent) + '\n')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('uid')
    ap.add_argument('target')
    ap.add_argument('why')
    ap.add_argument('--tab', type=int, help="index into the target's tabs array")
    a = ap.parse_args()

    index = corpus.load_index()
    if a.uid not in index:
        sys.exit(f'{a.uid} is not a zikr.json key')
    if a.target not in index or not os.path.exists(os.path.join(corpus.ZIKR_DIR, a.target)):
        sys.exit(f'{a.target} is not a live entry')
    aliases = [k for k in index if k.endswith('|' + a.uid)]
    if aliases:
        sys.exit(f'{a.uid} is the target of {aliases} - repoint them first')
    with open(os.path.join(corpus.ROOT, 'assets', 'zikr_audio.json'), encoding='utf-8') as f:
        if a.uid in json.load(f):
            sys.exit(f'{a.uid} has audio in assets/zikr_audio.json - move it first')

    slug = index[a.uid].get('slug')
    del index[a.uid]
    if slug:
        target = index[a.target]
        aliases = target.setdefault('slugAliases', [])
        if slug not in aliases and slug != target.get('slug'):
            aliases.append(slug)
    dump_json(corpus.INDEX, index, 2)
    os.remove(os.path.join(corpus.ZIKR_DIR, a.uid))

    with open(corpus.REDIRECTS, encoding='utf-8') as f:
        src = f.read()
    tab = f', tabIndex: {a.tab}' if a.tab is not None else ''
    why = '\n'.join(textwrap.wrap(a.why, 80, initial_indent='  /// ', subsequent_indent='  /// '))
    entry = f"\n{why}\n  '{a.uid}': RetiredZikrRedirect('{a.target}'{tab}),\n"
    end = src.rindex('};')
    src = src[:end].rstrip('\n') + '\n' + entry + src[end:]
    with open(corpus.REDIRECTS, 'w', encoding='utf-8') as f:
        f.write(src)

    i18n = os.path.join(corpus.ROOT, 'assets', 'zikr_i18n')
    for code in sorted(os.listdir(i18n)):
        path = os.path.join(i18n, code, 'index.json')
        if not os.path.exists(path):
            continue
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
        changed = False
        for section in data.values():
            if isinstance(section, dict) and a.uid in section:
                del section[a.uid]
                changed = True
        if changed:
            dump_json(path, data, 2)

    link = re.compile(r'\]\(' + re.escape(a.uid) + r'(#[^)]*)?\)')
    for uid in sorted(os.listdir(corpus.ZIKR_DIR)):
        with open(os.path.join(corpus.ZIKR_DIR, uid), encoding='utf-8') as f:
            if link.search(f.read()):
                print(f'  {uid} links to {a.uid} - point it at {a.target}')
    print(f'retired {a.uid} -> {a.target}')


if __name__ == '__main__':
    main()
