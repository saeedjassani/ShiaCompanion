#!/usr/bin/env python3
"""Gathers the city list's names in Arabic, Persian, Urdu and Gujarati into
scripts/city_names/<code>.tsv, the reviewed source that build_city_list.py
turns into assets/cities_<code>.tsv.

    python3 scripts/build_city_names.py            # downloads everything
    python3 scripts/build_city_names.py --dir DIR  # GeoNames dumps in DIR

Where each name comes from, best first:

  kept    a name already in the file whose source is `tr` (transliterated
          by hand for want of any published one) or `fix` (a published
          name corrected by hand): never overwritten;
  wd      Wikidata's label for the place (CC0), found through GeoNames'
          own link to it or Wikidata's GeoNames id (P1566);
  gn      a GeoNames alternate name in that language (CC BY 4.0);
  cldr    country names, from the Unicode CLDR (Unicode License v3).

Published names are cleaned - vowel marks dropped, letters normalized to
the language's own forms (Persian and Urdu ی ک, Urdu ہ), a trailing
disambiguator such as "(شہر)" or "، کیلیفورنیا" cut - and thrown out if
anything but the language's own script is left. Places that end up with no
name are written with an empty one, the worklist for transliterating by
hand; names that look like a district or province rather than the town
("ضلع", "استان", "જિલ્લો"), or whose Wikidata item's English name is not
the place's, are written with `check` in the flag column; once looked at and
found right, `reviewed` (kept while the name stays the same).

To fill the worklist, write each name into its line with source `tr`; to
correct a published name, with source `fix`. Both survive later runs.

File format, tab separated, in list order (countries, provinces, cities):

    <key>  <name>  <source>  <English name>  <flag>

where <key> is `C:<country code>`, `A:<country code>.<admin1 code>` or a
city's GeoNames id. The English name is there for whoever reviews it.
"""

import argparse
import difflib
import io
import json
import os
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
import zipfile

sys.path.insert(0, os.path.dirname(__file__))
from build_city_list import fetch, load_places  # noqa: E402

LANGUAGES = ['ar', 'fa', 'ur', 'gu']
OUT_DIR = os.path.join(os.path.dirname(__file__), 'city_names')
CLDR = ('https://cdn.jsdelivr.net/npm/cldr-localenames-full@45.0.0/main/'
        '{}/territories.json')
SPARQL = 'https://query.wikidata.org/sparql'
USER_AGENT = 'ShiaCompanionCityNames/1.0 (scripts/build_city_names.py)'
KEPT_SOURCES = {'tr', 'fix'}

# Vowel marks and tatweel: names are shown without them, as everywhere else.
HARAKAT = re.compile('[ً-ْٰـ]')
ARABIC_SCRIPT = re.compile('^[؀-ۿ‌ ]+$')
GUJARATI_SCRIPT = re.compile('^[\u0A80-\u0AFF -]+$')
LETTER_FORMS = {
    'fa': {'ي': 'ی', 'ى': 'ی', 'ك': 'ک', 'ە': 'ه'},
    'ur': {'ي': 'ی', 'ى': 'ی', 'ك': 'ک', 'ه': 'ہ', 'ە': 'ہ'},
    'ar': {'ی': 'ي', 'ک': 'ك', 'ہ': 'ه', 'ۀ': 'ه'},
}
# Words marking an administrative unit rather than the town itself.
UNIT_WORDS = {
    'ar': ['محافظة', 'مقاطعة', 'قضاء', 'ناحية', 'إقليم', 'ولاية', 'منطقة'],
    'fa': ['استان', 'شهرستان', 'بخش', 'ناحیه', 'منطقه', 'ایالت'],
    'ur': ['ضلع', 'صوبہ', 'تحصیل', 'ریاست', 'علاقہ', 'شہرستان'],
    'gu': ['જિલ્લો', 'જિલ્લા', 'તાલુકો', 'તાલુકા', 'પ્રાંત', 'રાજ્ય'],
}


def clean(name, language):
    """[name] in the language's own letters, or None if it is not one."""
    if not name:
        return None
    name = name.strip()
    # A disambiguator: "سورت (شہر)", "چیکو، کیلیفورنیا", "Lida, Belarus".
    name = re.sub(r'\s*\([^()]*\)$', '', name)
    name = re.split(r'\s*[،,]\s*', name)[0].strip()
    if language == 'gu':
        name = re.sub(r'\s+', ' ', name)
        return name if GUJARATI_SCRIPT.match(name) else None
    name = HARAKAT.sub('', name)
    name = name.replace('-', ' ').replace('‐', ' ')
    for wrong, right in LETTER_FORMS[language].items():
        name = name.replace(wrong, right)
    name = re.sub(r'\s+', ' ', name).strip()
    return name if name and ARABIC_SCRIPT.match(name) else None


def needs_check(name, language):
    return any(re.search(rf'(^|\s){re.escape(word)}(\s|$)', name)
               for word in UNIT_WORDS[language])


def fold(value):
    value = unicodedata.normalize('NFKD', value)
    return re.sub(r'[^a-z]', '', value.lower())


def same_place(english, wikidata_english):
    """Whether Wikidata's English label plausibly names the GeoNames place:
    a link to the wrong item ("Louga" -> "Nguer Malal") reads as a
    different name altogether."""
    if not wikidata_english:
        return True
    a, b = fold(english), fold(wikidata_english)
    if not a or not b or a in b or b in a:
        return True
    return difflib.SequenceMatcher(None, a, b).ratio() >= 0.6


def sparql(query, cache_dir, cache_name):
    if cache_dir:
        path = os.path.join(cache_dir, cache_name)
        if os.path.exists(path):
            with open(path, encoding='utf-8') as f:
                return json.load(f)
    request = urllib.request.Request(
        SPARQL,
        data=urllib.parse.urlencode({'query': query,
                                     'format': 'json'}).encode(),
        headers={'User-Agent': USER_AGENT})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(request, timeout=180) as response:
                result = json.load(response)['results']['bindings']
            break
        except Exception as error:  # noqa: BLE001 - retried, then raised
            # A malformed query fails the same way every time.
            if attempt == 4 or getattr(error, 'code', None) == 400:
                raise
            print(f'Wikidata: {error}; retrying', file=sys.stderr)
            time.sleep(10 * (attempt + 1))
    time.sleep(1)
    if cache_dir:
        with open(os.path.join(cache_dir, cache_name), 'w',
                  encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False)
    return result


def wikidata_labels(geoname_ids, linked_qids, links, cache_dir):
    """{geoname id: {language: label}}, through GeoNames' own Wikidata
    link where it has one, otherwise Wikidata's P1566, otherwise the
    English Wikipedia article GeoNames names."""
    ids = sorted(geoname_ids)
    by_p1566 = {}
    for start in range(0, len(ids), 300):
        values = ' '.join(f'"{i}"' for i in ids[start:start + 300])
        rows = sparql(
            f'SELECT ?g ?item WHERE {{ VALUES ?g {{ {values} }} '
            f'?item wdt:P1566 ?g . }}',
            cache_dir, f'wd_p1566_{start}.json')
        for row in rows:
            qid = row['item']['value'].rsplit('/', 1)[-1]
            by_p1566.setdefault(row['g']['value'], qid)

    # Last, through the English Wikipedia article GeoNames links to.
    by_article = {}
    unlinked = {g: wikipedia_url(links[g]) for g in ids
                if g in links and not linked_qids.get(g)
                and not by_p1566.get(g)}
    articles = sorted(unlinked.items())
    for start in range(0, len(articles), 200):
        values = ' '.join(f'<{url}>' for _, url in articles[start:start + 200])
        rows = sparql(
            f'SELECT ?article ?item WHERE {{ VALUES ?article {{ {values} }} '
            f'?article schema:about ?item . }}',
            cache_dir, f'wd_articles_{start}.json')
        qid_by_url = {row['article']['value']:
                      row['item']['value'].rsplit('/', 1)[-1] for row in rows}
        for g, url in articles[start:start + 200]:
            if url in qid_by_url:
                by_article[g] = qid_by_url[url]

    qid_for = {g: linked_qids.get(g) or by_p1566.get(g) or by_article.get(g)
               for g in ids}
    qids = sorted({q for q in qid_for.values() if q})
    labels = {}
    languages = ', '.join(f'"{l}"' for l in LANGUAGES + ['en'])
    for start in range(0, len(qids), 300):
        values = ' '.join(f'wd:{q}' for q in qids[start:start + 300])
        rows = sparql(
            f'SELECT ?item ?label WHERE {{ VALUES ?item {{ {values} }} '
            f'?item rdfs:label ?label . '
            f'FILTER(LANG(?label) IN ({languages})) }}',
            cache_dir, f'wd_labels_{start}.json')
        for row in rows:
            qid = row['item']['value'].rsplit('/', 1)[-1]
            labels.setdefault(qid, {})[row['label']['xml:lang']] = \
                row['label']['value']
    return {g: labels.get(q, {}) for g, q in qid_for.items() if q}


def wikipedia_url(link):
    """[link] the way Wikidata writes article URLs: https, percent-encoded,
    underscores for spaces."""
    title = urllib.parse.unquote(link.split('/wiki/', 1)[1]).replace(' ', '_')
    return ('https://en.wikipedia.org/wiki/'
            + urllib.parse.quote(title, safe="_(),'!*:;@$&+=-.~"))


def geonames_alternates(geoname_ids, directory):
    """({geoname id: {language: [names, preferred first]}},
    {geoname id: Wikidata id}, {geoname id: English Wikipedia URL})."""
    names = {}
    qids = {}
    links = {}
    archive = zipfile.ZipFile(io.BytesIO(
        fetch('alternateNamesV2.zip', directory)))
    with archive.open('alternateNamesV2.txt') as f:
        for line in io.TextIOWrapper(f, encoding='utf-8'):
            fields = line.rstrip('\n').split('\t')
            if fields[1] not in geoname_ids:
                continue
            language = fields[2]
            if language == 'link' and '://en.wikipedia.org/wiki/' in fields[3]:
                links.setdefault(fields[1], fields[3])
                continue
            if language == 'wkdt':
                if re.match(r'^Q\d+$', fields[3]):
                    qids.setdefault(fields[1], fields[3])
                continue
            if language not in LANGUAGES:
                continue
            historic = len(fields) > 7 and fields[7] == '1'
            colloquial = len(fields) > 6 and fields[6] == '1'
            if historic or colloquial:
                continue
            found = names.setdefault(fields[1], {}).setdefault(language, [])
            if fields[4] == '1':
                found.insert(0, fields[3])
            else:
                found.append(fields[3])
    return names, qids, links


def read_existing(language):
    path = os.path.join(OUT_DIR, f'{language}.tsv')
    existing = {}
    if os.path.exists(path):
        with open(path, encoding='utf-8') as f:
            for line in f:
                if line.startswith('#') or not line.strip():
                    continue
                fields = line.rstrip('\n').split('\t')
                if len(fields) >= 3:
                    existing[fields[0]] = (
                        fields[1], fields[2],
                        fields[4] if len(fields) > 4 else '')
    return existing


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dir', help='directory holding the GeoNames dumps; '
                        'Wikidata answers are cached there too')
    args = parser.parse_args()

    rows, countries, admin1, province = load_places(args.dir)
    admin1_ids = {}
    for line in fetch('admin1CodesASCII.txt', args.dir).decode().splitlines():
        fields = line.split('\t')
        if len(fields) >= 4:
            admin1_ids[fields[0]] = fields[3]

    used_countries = sorted({row[8] for row in rows})
    used_admin1 = sorted({f'{row[8]}.{province(row)}' for row in rows
                          if province(row)
                          and f'{row[8]}.{province(row)}' in admin1})
    # (key, geoname id or None, English name), in list order.
    places = [(f'C:{code}', None, countries.get(code, code))
              for code in used_countries]
    places += [(f'A:{code}', admin1_ids.get(code), admin1[code])
               for code in used_admin1]
    places += [(row[0], row[0], row[1]) for row in rows]

    geoname_ids = {g for _, g, _ in places if g}
    alternates, linked_qids, links = geonames_alternates(geoname_ids,
                                                         args.dir)
    wikidata = wikidata_labels(geoname_ids, linked_qids, links, args.dir)

    os.makedirs(OUT_DIR, exist_ok=True)
    for language in LANGUAGES:
        with urllib.request.urlopen(urllib.request.Request(
                CLDR.format(language),
                headers={'User-Agent': USER_AGENT})) as response:
            territories = json.load(response)['main'][language][
                'localeDisplayNames']['territories']
        existing = read_existing(language)
        lines = [
            f'# City list names in {language}; see '
            'scripts/build_city_names.py. Sources: tr = transliterated by '
            'hand, fix = corrected by hand, wd = Wikidata (CC0), gn = '
            'GeoNames (CC BY 4.0), cldr = Unicode CLDR (Unicode License '
            'v3, (c) Unicode, Inc.).',
        ]
        counts = {}
        for key, geoname_id, english in places:
            name, source = None, ''
            kept = existing.get(key)
            if kept and kept[1] in KEPT_SOURCES and kept[0]:
                name, source = kept[:2]
            elif key.startswith('C:'):
                name = clean(territories.get(key[2:]), language)
                source = 'cldr' if name else ''
            mismatch = False
            if not name and geoname_id:
                labels = wikidata.get(geoname_id, {})
                name = clean(labels.get(language), language)
                source = 'wd' if name else ''
                mismatch = bool(name) and not same_place(
                    english, labels.get('en', ''))
                if not name:
                    for candidate in alternates.get(geoname_id, {}).get(
                            language, []):
                        name = clean(candidate, language)
                        if name:
                            source = 'gn'
                            break
            name = name or ''
            flag = ('check' if name and source not in KEPT_SOURCES
                    and (mismatch or needs_check(name, language)) else '')
            # A doubted name someone has since looked at and kept.
            if flag and kept and kept[2] == 'reviewed' and kept[0] == name:
                flag = 'reviewed'
            counts[source or 'missing'] = counts.get(source or 'missing',
                                                     0) + 1
            lines.append('\t'.join([key, name, source, english, flag]))
        with open(os.path.join(OUT_DIR, f'{language}.tsv'), 'w',
                  encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(lines) + '\n')
        print(f'{language}: ' + ', '.join(f'{k} {v}' for k, v in
                                          sorted(counts.items())),
              file=sys.stderr)


if __name__ == '__main__':
    main()
