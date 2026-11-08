#!/usr/bin/env python3
"""Build the Ziyarat Guide's shrine plans from OpenStreetMap.

A plan is a roof-plan drawing of a shrine and its surroundings: the precinct,
courtyards, buildings, gold domes, minarets, walkways and walls, as polygons
and lines in metres around an origin. The app draws it (no map tiles, works
offline) and puts the plan's tappable features - the zarih, the gates, the
tombs inside - on top of it.

    python3 -I scripts/ziyarat_maps/build_plans.py [<plan id> ...]

For every plan in `assets/ziyarat_guide.json` (a city's `plans`) this

- downloads the OSM data of the plan's `bbox` (cached under
  `build/osm_cache/`; pass --refresh to download again),
- writes `assets/ziyarat_plans/<plan id>.json` (see docs/ZIYARAT_GUIDE.md,
  "Shrine plans"), and
- fills each feature's `location` from its `osm` id ("n123", "w123",
  "r123": a node's position, a way's or relation's centroid), writing the
  guide back in its canonical form (json.dumps, indent 2).

With --candidates it also prints the named gates, doors, tombs and other
points inside the bbox that no feature uses yet, to help curate a new plan.

The data is (c) OpenStreetMap contributors, under the ODbL; the app shows
that attribution on every plan.
"""

from __future__ import annotations

import json
import math
import os
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GUIDE = ROOT / 'assets' / 'ziyarat_guide.json'
OUT_DIR = ROOT / 'assets' / 'ziyarat_plans'
CACHE = ROOT / 'build' / 'osm_cache'
API = 'https://api.openstreetmap.org/api/0.6'
USER_AGENT = 'ShiaCompanion-plan-builder/1.0'

# Metres per degree, as lib/models/shrine_plan.dart projects them: an
# equirectangular projection around the plan's origin, plenty for a few
# hundred metres.
M_PER_DEG_LAT = 110574.0
M_PER_DEG_LNG = 111320.0

# Douglas-Peucker tolerance in metres; coordinates are stored in decimetres.
SIMPLIFY_M = 0.25

GOLD = {'gold', '#ffd700', '#ffcc00', '#d4af37', 'yellow', 'golden'}


def fetch(url: str, cache_name: str, refresh: bool) -> dict:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / cache_name
    if path.exists() and not refresh:
        return json.loads(path.read_text())
    request = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
    with urllib.request.urlopen(request, timeout=120) as response:
        body = response.read()
    path.write_bytes(body)
    return json.loads(body)


class Osm:
    def __init__(self, elements: list[dict]):
        self.nodes: dict[int, tuple[float, float]] = {}
        self.node_tags: dict[int, dict] = {}
        self.ways: dict[int, dict] = {}
        self.relations: dict[int, dict] = {}
        self.add(elements)

    def add(self, elements: list[dict]) -> None:
        for e in elements:
            if e['type'] == 'node':
                self.nodes[e['id']] = (e['lat'], e['lon'])
                if e.get('tags'):
                    self.node_tags[e['id']] = e['tags']
            elif e['type'] == 'way':
                self.ways[e['id']] = e
            elif e['type'] == 'relation':
                self.relations[e['id']] = e

    def way_points(self, way_id: int) -> list[tuple[float, float]]:
        way = self.ways.get(way_id)
        if way is None:
            return []
        return [self.nodes[n] for n in way['nodes'] if n in self.nodes]

    def relation_rings(self, rel: dict) -> list[list[tuple[float, float]]]:
        """The closed rings of a multipolygon, outer and inner alike (the
        app fills them even-odd), joining member ways end to end."""
        pieces = []
        for m in rel.get('members', []):
            if m['type'] == 'way' and m.get('role') in ('outer', 'inner', ''):
                pts = self.way_points(m['ref'])
                if len(pts) >= 2:
                    pieces.append(pts)
        rings = []
        while pieces:
            ring = pieces.pop(0)
            changed = True
            while ring[0] != ring[-1] and changed:
                changed = False
                for i, p in enumerate(pieces):
                    if p[0] == ring[-1]:
                        ring = ring + p[1:]
                    elif p[-1] == ring[-1]:
                        ring = ring + p[::-1][1:]
                    elif p[-1] == ring[0]:
                        ring = p + ring[1:]
                    elif p[0] == ring[0]:
                        ring = p[::-1] + ring[1:]
                    else:
                        continue
                    pieces.pop(i)
                    changed = True
                    break
            if len(ring) >= 4:
                rings.append(ring)
        return rings

    def location_of(self, ref: str) -> tuple[float, float] | None:
        kind, ident = ref[0], int(ref[1:])
        if kind == 'n':
            return self.nodes.get(ident)
        if kind == 'w':
            pts = self.way_points(ident)
        elif kind == 'r':
            rel = self.relations.get(ident)
            pts = [p for ring in self.relation_rings(rel) for p in ring] if rel else []
            if rel and not pts:
                # A building relation: its outline, else all its parts.
                members = [m for m in rel['members'] if m['type'] == 'way']
                outline = [m for m in members if m.get('role') == 'outline'] or members
                pts = [p for m in outline for p in self.way_points(m['ref'])]
            if rel and not pts:
                pts = [self.nodes[m['ref']] for m in rel['members']
                       if m['type'] == 'node' and m['ref'] in self.nodes]
        else:
            return None
        if not pts:
            return None
        if len(pts) > 3 and pts[0] == pts[-1]:
            return polygon_centroid(pts[:-1])
        return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))


def polygon_centroid(pts: list[tuple[float, float]]) -> tuple[float, float]:
    # Relative to the first point: in raw degrees the cross products of a
    # ring a few metres wide cancel to noise.
    oy, ox = pts[0]
    rel = [(y - oy, x - ox) for y, x in pts]
    area = cx = cy = 0.0
    for (y0, x0), (y1, x1) in zip(rel, rel[1:] + rel[:1]):
        cross = x0 * y1 - x1 * y0
        area += cross
        cx += (x0 + x1) * cross
        cy += (y0 + y1) * cross
    if abs(area) < 1e-14:
        return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))
    return (oy + cy / (3 * area), ox + cx / (3 * area))


def classify(tags: dict, closed: bool) -> str | None:
    """The plan layer a way or relation draws in, or None to leave it out."""
    get = tags.get
    if get('indoor') or get('highway') == 'corridor' or get('location') == 'underground':
        return None
    if get('building') == 'gate':
        return 'gate'
    if get('man_made') == 'tower' or get('building') == 'minaret' or get('tower:type') == 'minaret':
        return 'minaret' if closed else None
    if get('building') or get('building:part'):
        if not closed:
            return None
        if get('building') == 'roof' and get('amenity') == 'place_of_worship':
            return 'court'
        colours = {str(get(k, '')).lower() for k in
                   ('material', 'roof:material', 'roof:colour', 'building:colour')}
        if colours & GOLD:
            return 'gold'
        return 'building'
    if closed and (get('amenity') == 'place_of_worship' or get('landuse') in ('religious', 'cemetery')
                   or get('amenity') == 'grave_yard'):
        return 'precinct'
    if closed and (get('leisure') in ('garden', 'park') or get('landuse') in ('grass', 'garden')
                   or get('natural') in ('scrub', 'grassland')):
        return 'green'
    if closed and (get('natural') == 'water' or get('amenity') == 'fountain'):
        return 'water'
    if closed and (get('area:highway') or (get('highway') in ('pedestrian', 'footway') and get('area') == 'yes')
                   or get('place') == 'square'):
        return 'walk'
    if get('highway') in ('pedestrian', 'footway', 'steps', 'path'):
        return 'path'
    if get('highway') in ('primary', 'secondary', 'tertiary', 'residential', 'unclassified',
                          'service', 'living_street', 'trunk'):
        return 'road'
    if get('barrier') in ('wall', 'fence', 'city_wall'):
        return 'wall'
    return None


# Drawing order: earlier layers lie underneath.
LAYERS = ['precinct', 'green', 'walk', 'court', 'road', 'path', 'water', 'building',
          'gate', 'gold', 'minaret', 'wall']
LINE_LAYERS = {'road', 'path', 'wall'}


def height_of(tags: dict) -> float:
    for key in ('height', 'min_height'):
        try:
            return float(str(tags.get(key, '')).split()[0])
        except (ValueError, IndexError):
            continue
    try:
        return float(tags.get('building:levels', 0)) * 3
    except ValueError:
        return 0.0


def clip_polygon(ring, box):
    """Sutherland-Hodgman clip of [ring] (x, y metres) to box."""
    x0, y0, x1, y1 = box
    edges = [
        (lambda p: p[0] >= x0, lambda a, b: (x0, a[1] + (b[1] - a[1]) * (x0 - a[0]) / (b[0] - a[0]))),
        (lambda p: p[0] <= x1, lambda a, b: (x1, a[1] + (b[1] - a[1]) * (x1 - a[0]) / (b[0] - a[0]))),
        (lambda p: p[1] >= y0, lambda a, b: (a[0] + (b[0] - a[0]) * (y0 - a[1]) / (b[1] - a[1]), y0)),
        (lambda p: p[1] <= y1, lambda a, b: (a[0] + (b[0] - a[0]) * (y1 - a[1]) / (b[1] - a[1]), y1)),
    ]
    out = ring
    for inside, cross in edges:
        if not out:
            break
        points, out = out, []
        for i, cur in enumerate(points):
            prev = points[i - 1]
            if inside(cur):
                if not inside(prev):
                    out.append(cross(prev, cur))
                out.append(cur)
            elif inside(prev):
                out.append(cross(prev, cur))
    return out


def simplify(points, tolerance):
    if len(points) < 3:
        return points
    (ax, ay), (bx, by) = points[0], points[-1]
    dx, dy = bx - ax, by - ay
    length = math.hypot(dx, dy)
    best, index = -1.0, 0
    for i in range(1, len(points) - 1):
        px, py = points[i]
        if length == 0:
            d = math.hypot(px - ax, py - ay)
        else:
            d = abs(dy * px - dx * py + bx * ay - by * ax) / length
        if d > best:
            best, index = d, i
    if best <= tolerance:
        return [points[0], points[-1]]
    return simplify(points[:index + 1], tolerance)[:-1] + simplify(points[index:], tolerance)


def simplify_ring(ring, tolerance):
    if len(ring) < 4:
        return ring
    # Split the ring at its farthest point so the closing seam survives.
    far = max(range(len(ring)), key=lambda i: math.hypot(ring[i][0] - ring[0][0], ring[i][1] - ring[0][1]))
    first = simplify(ring[:far + 1], tolerance)
    second = simplify(ring[far:] + [ring[0]], tolerance)
    return first[:-1] + second[:-1]


def ring_area(ring):
    return abs(sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(ring, ring[1:] + ring[:1]))) / 2


def build_plan(plan: dict, osm: Osm, origin: tuple[float, float]) -> dict:
    lat0, lng0 = origin
    cos0 = math.cos(math.radians(lat0))

    def project(p):
        return ((p[1] - lng0) * M_PER_DEG_LNG * cos0, (p[0] - lat0) * M_PER_DEG_LAT)

    s, w, n, e = plan['bbox']
    box = (*project((s, w)), *project((n, e)))
    shapes = []

    def add_polygon(layer, rings, tags):
        out = []
        for ring in rings:
            pts = [project(p) for p in ring]
            if pts and pts[0] == pts[-1]:
                pts = pts[:-1]
            pts = clip_polygon(pts, box)
            pts = simplify_ring(pts, SIMPLIFY_M)
            if len(pts) >= 3 and ring_area(pts) >= 0.5:
                out.append(pts)
        if out:
            shapes.append((LAYERS.index(layer), height_of(tags), layer, out, False))

    def add_line(layer, pts, tags):
        pts = [project(p) for p in pts]
        x0, y0, x1, y1 = box
        if not any(x0 <= x <= x1 and y0 <= y <= y1 for x, y in pts):
            return
        pts = simplify(pts, SIMPLIFY_M)
        if len(pts) >= 2:
            shapes.append((LAYERS.index(layer), 0.0, layer, [pts], True))

    in_relation = set()
    for rel in osm.relations.values():
        tags = rel.get('tags', {})
        if tags.get('type') not in ('multipolygon', 'building'):
            continue
        layer = classify(tags, True)
        if tags.get('type') == 'building':
            # A building relation groups parts that are drawn on their own.
            continue
        if layer is None:
            continue
        rings = osm.relation_rings(rel)
        if rings:
            add_polygon(layer, rings, tags)
            for m in rel['members']:
                if m['type'] == 'way':
                    in_relation.add(m['ref'])

    for way in osm.ways.values():
        tags = way.get('tags', {})
        if not tags:
            continue
        pts = osm.way_points(way['id'])
        if len(pts) < 2:
            continue
        closed = pts[0] == pts[-1] and len(pts) >= 4
        layer = classify(tags, closed)
        if layer is None:
            continue
        if way['id'] in in_relation and layer not in LINE_LAYERS:
            # Its relation already drew it, unless the way is a part of its own.
            if not (tags.get('building') or tags.get('building:part')):
                continue
        if layer in LINE_LAYERS:
            add_line(layer, pts, tags)
        elif closed:
            add_polygon(layer, [pts], tags)

    shapes.sort(key=lambda s: (s[0], s[1]))
    dm = lambda v: int(round(v * 10))
    out_shapes = []
    for _, _, layer, rings, is_line in shapes:
        flat = [[c for x, y in ring for c in (dm(x), dm(y))] for ring in rings]
        out_shapes.append({'k': layer, ('l' if is_line else 'r'): flat[0] if is_line else flat})
    return {
        'origin': [round(lat0, 7), round(lng0, 7)],
        'bounds': [dm(box[0]), dm(box[1]), dm(box[2]), dm(box[3])],
        'attribution': '© OpenStreetMap contributors',
        'shapes': out_shapes,
    }


def osm_ref_of(kind: str, ident: int) -> str:
    return {'node': 'n', 'way': 'w', 'relation': 'r'}[kind] + str(ident)


def print_candidates(plan: dict, osm: Osm) -> None:
    used = {f.get('osm') for f in plan.get('features', [])}
    interesting = ('entrance', 'door', 'barrier', 'historic', 'amenity', 'building', 'tourism', 'man_made')
    rows = []
    for nid, tags in osm.node_tags.items():
        if tags.get('name') and any(k in tags for k in interesting):
            rows.append((osm_ref_of('node', nid), tags))
    for kind, table in (('way', osm.ways), ('relation', osm.relations)):
        for ident, el in table.items():
            tags = el.get('tags', {})
            if tags.get('name') and not tags.get('highway') and tags.get('type') != 'restriction':
                rows.append((osm_ref_of(kind, ident), tags))
    for ref, tags in rows:
        if ref in used:
            continue
        kinds = {k: tags[k] for k in interesting if k in tags}
        print(f"  {ref:14} {tags.get('name')} | {tags.get('name:en', '')} {kinds}")


def main(argv: list[str]) -> int:
    refresh = '--refresh' in argv
    candidates = '--candidates' in argv
    wanted = {a for a in argv if not a.startswith('--')}
    guide = json.loads(GUIDE.read_text())
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    built = 0
    for region in guide['regions']:
        for city in region['cities']:
            for plan in city.get('plans', []):
                if wanted and plan['id'] not in wanted:
                    continue
                s, w, n, e = plan['bbox']
                data = fetch(f'{API}/map.json?bbox={w},{s},{e},{n}', f"{plan['id']}.json", refresh)
                osm = Osm(data['elements'])
                for feature in plan.get('features', []):
                    ref = feature.get('osm')
                    if not ref:
                        continue
                    loc = osm.location_of(ref)
                    if loc is None and ref[0] in 'wr':
                        kind = 'way' if ref[0] == 'w' else 'relation'
                        full = fetch(f'{API}/{kind}/{ref[1:]}/full.json', f'{ref}.json', refresh)
                        osm.add(full['elements'])
                        loc = osm.location_of(ref)
                    if loc is None:
                        print(f"{plan['id']}: {feature['id']}: {ref} not found", file=sys.stderr)
                        return 1
                    feature['location'] = [round(loc[0], 6), round(loc[1], 6)]
                origin = ((s + n) / 2, (w + e) / 2)
                result = build_plan(plan, osm, origin)
                path = OUT_DIR / f"{plan['id']}.json"
                path.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
                print(f"{plan['id']}: {len(result['shapes'])} shapes, {path.stat().st_size // 1024} KB")
                if candidates:
                    print_candidates(plan, osm)
                built += 1
    GUIDE.write_text(json.dumps(guide, ensure_ascii=False, indent=2) + '\n')
    if wanted and not built:
        print('no such plan: ' + ', '.join(sorted(wanted)), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
