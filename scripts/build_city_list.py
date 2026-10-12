#!/usr/bin/env python3
"""Builds assets/cities.tsv, the offline city list behind the city picker.

Source: GeoNames (https://www.geonames.org), licensed CC BY 4.0. Uses the
cities15000 dump, countryInfo.txt for country names and admin1CodesASCII.txt
for state/province names.

    python3 scripts/build_city_list.py            # downloads the dumps
    python3 scripts/build_city_list.py --dir DIR  # uses dumps already in DIR

The picker is the fallback for when the phone's own location is unavailable
or refused, so the list is kept small: cities of 100,000+ people, plus every
capital (GeoNames counts Kuwait City at 60,000). Anyone in a smaller town picks
the nearest of these; within a few tens of kilometres, prayer times differ by
a minute or two.

Output, one record per line, tab separated (see lib/models/city.dart):

    C  <country code>  <country name>
    A  <country code>.<admin1 code>  <admin1 name>
    Z  <IANA time zone>                      (numbered from 0, in order)
    P  <name>  <ascii name, if different>  <country code>
       <admin1 code, only where two cities share a name in one country>
       <lat>  <lng>  <population>  <time zone number>  <aliases, |-separated>

Coordinates are rounded to 2 decimals (about 1 km), which moves a prayer time
by a few seconds. Aliases are other Latin-script spellings ("Kerbala", "Qum",
"Mecca") so the search finds a city by the name people use; they are kept for
cities of 250,000+ only.

It also writes assets/cities_<code>.tsv for each of the app's other
languages, from the reviewed names in scripts/city_names/<code>.tsv (built by
scripts/build_city_names.py), line for line with cities.tsv:

    N  <number of places>
    C  <country code>  <country name>
    A  <country code>.<admin1 code>  <admin1 name>
    <city name>                              (one line per P line, in order)
"""

import argparse
import io
import os
import re
import sys
import urllib.request
import zipfile
from collections import Counter

BASE = 'https://download.geonames.org/export/dump/'
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'cities.tsv')

NAMES_DIR = os.path.join(os.path.dirname(__file__), 'city_names')
# The app's other languages; see scripts/build_city_names.py.
NAME_LANGUAGES = ['ar', 'fa', 'ur', 'gu']

MIN_POPULATION = 100000
ALIAS_MIN_POPULATION = 250000

# Sections of a populated place, historical, abandoned or destroyed places:
# none is somewhere to pick as "the city I am in".
SKIPPED_FEATURE_CODES = {'PPLX', 'PPLH', 'PPLQ', 'PPLW'}
CAPITAL_FEATURE_CODE = 'PPLC'

ALIAS_PATTERN = re.compile(r"^[A-Za-z][A-Za-z .'\-]{2,39}$")


def fetch(name, directory):
    if directory:
        with open(os.path.join(directory, name), 'rb') as f:
            return f.read()
    with urllib.request.urlopen(BASE + name) as response:
        return response.read()


def text_lines(data):
    return data.decode('utf-8').splitlines()


def fold(value):
    return re.sub(r'[^a-z]', '', value.lower())


def aliases_for(row):
    name, ascii_name, alternates, population = row[1], row[2], row[3], row[14]
    if int(population or 0) < ALIAS_MIN_POPULATION:
        return []
    seen = {fold(name), fold(ascii_name)}
    found = []
    for alternate in alternates.split(','):
        alternate = alternate.strip()
        if not ALIAS_PATTERN.match(alternate):
            continue
        # IATA and ICAO codes ride along in alternatenames.
        if alternate.isupper() and len(alternate) <= 4:
            continue
        # All-lowercase entries are machine romanizations of other scripts
        # ("lun dun", "lwndwn"), not spellings anyone types.
        if alternate == alternate.lower() or '  ' in alternate:
            continue
        key = fold(alternate)
        if len(key) < 3 or key in seen:
            continue
        seen.add(key)
        found.append(alternate)
    return found


def load_places(directory=None):
    """The places the list keeps, biggest first, with the country and
    province names they need: (rows, countries, admin1, province), where
    each row is a GeoNames cities15000 record and province(row) is its
    admin1 code where two cities share a name in one country, else ''."""
    countries = {}
    for line in text_lines(fetch('countryInfo.txt', directory)):
        if line.startswith('#') or not line.strip():
            continue
        fields = line.split('\t')
        countries[fields[0]] = fields[4]

    admin1 = {}
    for line in text_lines(fetch('admin1CodesASCII.txt', directory)):
        fields = line.split('\t')
        if len(fields) >= 2:
            admin1[fields[0]] = fields[1]

    archive = zipfile.ZipFile(io.BytesIO(fetch('cities15000.zip', directory)))
    rows = [
        row for row in (line.split('\t')
                        for line in text_lines(archive.read('cities15000.txt')))
        if row[7] not in SKIPPED_FEATURE_CODES
        and (int(row[14] or 0) >= MIN_POPULATION
             or row[7] == CAPITAL_FEATURE_CODE)
    ]
    # Biggest first: the app's search breaks ties by list order.
    rows.sort(key=lambda row: (-int(row[14] or 0), row[1]))

    # A province is only worth its bytes where it tells two cities apart.
    shared_names = Counter((row[1], row[8]) for row in rows)
    def province(row):
        return row[10] if shared_names[(row[1], row[8])] > 1 else ''

    return rows, countries, admin1, province


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dir', help='directory holding the GeoNames dumps')
    args = parser.parse_args()

    rows, countries, admin1, province = load_places(args.dir)

    zones = sorted({row[17] for row in rows})
    zone_numbers = {zone: index for index, zone in enumerate(zones)}
    used_countries = sorted({row[8] for row in rows})
    used_admin1 = sorted({f'{row[8]}.{province(row)}' for row in rows
                          if province(row)
                          and f'{row[8]}.{province(row)}' in admin1})

    lines = [
        '# Cities of 100,000+ people and all capitals, from GeoNames '
        '(geonames.org), CC BY 4.0.',
        '# Built by scripts/build_city_list.py; do not edit by hand.',
    ]
    lines += [f'C\t{code}\t{countries.get(code, code)}'
              for code in used_countries]
    lines += [f'A\t{code}\t{admin1[code]}' for code in used_admin1]
    lines += [f'Z\t{zone}' for zone in zones]
    for row in rows:
        lines.append('\t'.join([
            'P',
            row[1],
            row[2] if row[2] != row[1] else '',
            row[8],
            province(row),
            f'{float(row[4]):.2f}',
            f'{float(row[5]):.2f}',
            str(int(row[14] or 0)),
            str(zone_numbers[row[17]]),
            '|'.join(aliases_for(row)),
        ]))

    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    size = os.path.getsize(OUT)
    print(f'Wrote {len(rows)} places in {len(used_countries)} countries to '
          f'{os.path.relpath(OUT)} ({size // 1024} KB)', file=sys.stderr)

    for language in NAME_LANGUAGES:
        write_names(language, rows, used_countries, used_admin1)


def write_names(language, rows, used_countries, used_admin1):
    """Writes assets/cities_<language>.tsv from scripts/city_names: the
    list's names in that language, line for line with cities.tsv."""
    source = os.path.join(NAMES_DIR, f'{language}.tsv')
    names = {}
    with open(source, encoding='utf-8') as f:
        for line in f:
            if line.startswith('#') or not line.strip():
                continue
            fields = line.rstrip('\n').split('\t')
            names[fields[0]] = fields[1]
    missing = []

    def name(key, english):
        found = names.get(key, '')
        if not found:
            missing.append(english)
        return found

    lines = [
        f'# The city list in {language}, line for line with cities.tsv: '
        'country, province and city names, an empty line where there is '
        'none (the English is shown).',
        '# Built by scripts/build_city_list.py from '
        f'scripts/city_names/{language}.tsv; do not edit by hand. Sources: '
        'Wikidata (CC0), GeoNames (CC BY 4.0), Unicode CLDR (Unicode '
        'License v3, (c) Unicode, Inc.), and transliteration.',
        f'N\t{len(rows)}',
    ]
    lines += [f'C\t{code}\t{name(f"C:{code}", code)}'
              for code in used_countries]
    lines += [f'A\t{code}\t{name(f"A:{code}", code)}' for code in used_admin1]
    lines += [name(row[0], row[1]) for row in rows]
    out = os.path.join(os.path.dirname(OUT), f'cities_{language}.tsv')
    with open(out, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    print(f'Wrote {os.path.relpath(out)} '
          f'({os.path.getsize(out) // 1024} KB); '
          f'{len(missing)} without a name: {missing[:10]}', file=sys.stderr)


if __name__ == '__main__':
    main()
