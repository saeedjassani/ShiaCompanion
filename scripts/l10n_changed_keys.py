#!/usr/bin/env python3
"""Lists the UI strings a branch added or changed, in every language.

For the independent translation review (docs/TRANSLATIONS.md, "Every new
string is checked by another agent"): prints each key that differs from
BASE in any lib/l10n/app_<code>.arb, with the English, its @description and
placeholders, and each language's text, so a reviewer can read them side by
side without digging through diffs.

Usage: python3 -I scripts/l10n_changed_keys.py [BASE] [--lang CODE]

BASE defaults to origin/master. --lang limits the output to English and
that one language (for one reviewer per language).
"""

import json
import subprocess
import sys
from pathlib import Path

LANGS = ["ur", "fa", "ar", "gu"]
L10N = Path("lib/l10n")


def load_at(ref, path):
    try:
        text = subprocess.run(
            ["git", "show", f"{ref}:{path}"],
            check=True, capture_output=True, text=True,
        ).stdout
    except subprocess.CalledProcessError:
        return {}
    return json.loads(text)


def main(argv):
    base = "origin/master"
    only = None
    args = list(argv)
    while args:
        arg = args.pop(0)
        if arg == "--lang":
            only = args.pop(0)
        else:
            base = arg
    langs = [only] if only else LANGS

    now = {c: json.loads((L10N / f"app_{c}.arb").read_text("utf-8"))
           for c in ["en"] + LANGS}
    before = {c: load_at(base, L10N / f"app_{c}.arb") for c in ["en"] + LANGS}

    changed = [
        key for key in now["en"]
        if not key.startswith("@")
        and any(now[c].get(key) != before[c].get(key) for c in ["en"] + langs)
    ]
    if not changed:
        print(f"No strings added or changed since {base}.")
        return 0

    print(f"{len(changed)} string(s) added or changed since {base}:\n")
    for key in changed:
        meta = now["en"].get(f"@{key}", {})
        print(f"## {key}")
        if meta.get("description"):
            print(f"description: {meta['description']}")
        if meta.get("placeholders"):
            print(f"placeholders: {', '.join(meta['placeholders'])}")
        print(f"en: {now['en'][key]}")
        for code in langs:
            value = now[code].get(key)
            print(f"{code}: {value if value is not None else '(missing)'}")
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
