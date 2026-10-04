#!/usr/bin/env python3
"""Builds assets/cities.tsv, the offline city list behind the city picker.

Source: GeoNames (https://www.geonames.org), licensed CC BY 4.0. Uses the
cities15000 dump (every populated place of 15,000+ people), countryInfo.txt
for country names and admin1CodesASCII.txt for state/province names.

    python3 scripts/build_city_list.py            # downloads the dumps
    python3 scripts/build_city_list.py --dir DIR  # uses dumps already in DIR

Output, one record per line, tab separated (see lib/models/city.dart):

    C  <country code>  <country name>
    A  <country code>.<admin1 code>  <admin1 name>
    P  <name>  <ascii name, if different>  <country code>  <admin1 code>
       <lat>  <lng>  <population>  <IANA time zone>  <aliases, |-separated>

Coordinates are rounded to 3 decimals (about 100 m), which moves a prayer time
by well under a second. Aliases are other Latin-script spellings ("Kerbala",
"Mecca", "Bombay") so the search finds a city by the name people use; they
are kept for cities of 100,000+ only, which is where the size goes otherwise.
"""

import argparse
import io
import os
import re
import sys
import urllib.request
import zipfile

BASE = 'https://download.geonames.org/export/dump/'
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'cities.tsv')

# Sections of a populated place, historical, abandoned or destroyed places:
# none is somewhere to pick as "the city I am in".
SKIPPED_FEATURE_CODES = {'PPLX', 'PPLH', 'PPLQ', 'PPLW'}

ALIAS_MIN_POPULATION = 100000
ALIAS_PATTERN = re.compile(r"^[A-Za-z][A-Za-z .'\-]{2,39}$")

# Places people pray in that GeoNames files as part of a bigger city rather
# than as cities of their own. Coordinates are the shrine's.
CURATED_EXTRAS = [
    # name, ascii, country, admin1, lat, lng, population, time zone, aliases
    ('Kadhimiya', '', 'IQ', '07', 33.380, 44.338, 300000, 'Asia/Baghdad',
     ['Kazimiyah', 'Al Kadhimiya', 'Kadhimain', 'Kazimain']),
    ('Sayyidah Zaynab', '', 'SY', '08', 33.444, 36.341, 136000,
     'Asia/Damascus', ['Sayyida Zaynab', 'Sayeda Zainab', 'Zaynabiyah']),
]


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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dir', help='directory holding the GeoNames dumps')
    args = parser.parse_args()

    countries = {}
    for line in text_lines(fetch('countryInfo.txt', args.dir)):
        if line.startswith('#') or not line.strip():
            continue
        fields = line.split('\t')
        countries[fields[0]] = fields[4]

    admin1 = {}
    for line in text_lines(fetch('admin1CodesASCII.txt', args.dir)):
        fields = line.split('\t')
        if len(fields) >= 2:
            admin1[fields[0]] = fields[1]

    archive = zipfile.ZipFile(io.BytesIO(fetch('cities15000.zip', args.dir)))
    rows = [line.split('\t')
            for line in text_lines(archive.read('cities15000.txt'))]

    places = []
    for row in rows:
        if row[7] in SKIPPED_FEATURE_CODES:
            continue
        places.append((
            row[1],
            row[2] if row[2] != row[1] else '',
            row[8],
            row[10],
            float(row[4]),
            float(row[5]),
            int(row[14] or 0),
            row[17],
            aliases_for(row),
        ))
    places.extend(CURATED_EXTRAS)
    # Biggest first: the app's search breaks ties by population anyway, and
    # this keeps the file readable.
    places.sort(key=lambda place: (-place[6], place[0]))

    used_countries = sorted({place[2] for place in places})
    used_admin1 = sorted({f'{place[2]}.{place[3]}' for place in places
                          if f'{place[2]}.{place[3]}' in admin1})

    lines = [
        '# Cities of 15,000+ people, from GeoNames (geonames.org), CC BY 4.0.',
        '# Built by scripts/build_city_list.py; do not edit by hand.',
    ]
    lines += [f'C\t{code}\t{countries.get(code, code)}'
              for code in used_countries]
    lines += [f'A\t{code}\t{admin1[code]}' for code in used_admin1]
    for name, ascii_name, country, adm1, lat, lng, population, zone, aliases \
            in places:
        lines.append('\t'.join([
            'P', name, ascii_name, country, adm1,
            f'{lat:.3f}', f'{lng:.3f}', str(population), zone,
            '|'.join(aliases),
        ]))

    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    print(f'Wrote {len(places)} places, {len(used_countries)} countries '
          f'to {os.path.relpath(OUT)}', file=sys.stderr)


if __name__ == '__main__':
    main()
