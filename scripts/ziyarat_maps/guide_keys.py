"""The Ziyarat Guide's translatable strings, keyed as the overlays key them.

    python3 -I scripts/ziyarat_maps/guide_keys.py            # all keys -> JSON on stdout
    python3 -I scripts/ziyarat_maps/guide_keys.py check ur   # keys missing from / stale in an overlay

Mirrors `sourceKeys()` in test/ziyarat_guide_test.dart (keep the two in step).
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def source_keys():
    guide = json.loads((ROOT / 'assets/ziyarat_guide.json').read_text())
    keys = {}

    def refs(prefix, raw):
        for i, ref in enumerate(raw or []):
            for field in ('label', 'note'):
                if isinstance(ref.get(field), str):
                    keys[f'{prefix}.{i}.{field}'] = ref[field]

    def tips(prefix, raw):
        for i, tip in enumerate(raw or []):
            keys[f'{prefix}.tips.{i}'] = tip

    refs('general', guide.get('general'))
    for region in guide['regions']:
        keys[f"region.{region['id']}.name"] = region['name']
        for city in region['cities']:
            c = f"city.{city['id']}"
            keys[f'{c}.name'] = city['name']
            if isinstance(city.get('about'), str):
                keys[f'{c}.about'] = city['about']
            tips(c, city.get('tips'))
            for site in city['sites']:
                s = f"site.{site['id']}"
                keys[f'{s}.name'] = site['name']
                if isinstance(site.get('about'), str):
                    keys[f'{s}.about'] = site['about']
                tips(s, site.get('tips'))
                refs(f'{s}.ziyarat', site.get('ziyarat'))
                for person in site.get('buried') or []:
                    b = f"{s}.buried.{person['id']}"
                    keys[f'{b}.name'] = person['name']
                    if isinstance(person.get('note'), str):
                        keys[f'{b}.note'] = person['note']
            for plan in city.get('plans') or []:
                for feature in plan['features']:
                    f = f"plan.{plan['id']}.{feature['id']}"
                    keys[f'{f}.name'] = feature['name']
                    if isinstance(feature.get('note'), str):
                        keys[f'{f}.note'] = feature['note']
                    refs(f'{f}.ziyarat', feature.get('ziyarat'))
    return keys


def main(argv):
    keys = source_keys()
    if argv[:1] == ['check']:
        code = argv[1]
        overlay = json.loads((ROOT / f'assets/ziyarat_guide_i18n/{code}.json').read_text())
        missing = [k for k in keys if k not in overlay]
        stale = [k for k in overlay if k not in keys]
        print(f'{code}: {len(keys)} keys, {len(missing)} missing, {len(stale)} stale')
        for k in stale:
            print('  stale', k)
        return 1 if stale else 0
    json.dump(keys, sys.stdout, ensure_ascii=False, indent=1)
    print()
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
