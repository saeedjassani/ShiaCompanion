#!/usr/bin/env python3
"""Regenerates test/data/solar_reference.csv.

The app computes solar events with a simplified approximation of the sun's
position (see the USNO reference in lib/utils/prayer_times.dart). This script
produces an independent reference using PyEphem, which carries the far more
precise libastro/VSOP87 solar model, so the Dart test can measure the
approximation's error rather than assume it.

The reference deliberately uses *geometric* altitudes with no atmospheric
refraction model (``pressure = 0``), because that is the convention the app's
angles follow: 0.833 degrees for sunrise and sunset already stands in for
refraction plus the solar semidiameter, and the twilight angles are geometric
by definition.

Usage:
    pip install ephem
    python3 scripts/generate_solar_reference.py
"""

import csv
import datetime
import os

import ephem

# (name, depression angle below the horizon, rising or setting).
# The angles are the Jafari values the app is configured with.
EVENTS = [
    ('Fajr', 16.0, 'rise'),
    ('Sunrise', 0.833, 'rise'),
    ('Sunset', 0.833, 'set'),
    ('Maghrib', 4.0, 'set'),
    ('Isha', 14.0, 'set'),
]

# Spread of latitudes, including two points on the SFO-Istanbul great circle,
# because that route is what exposed the high-latitude behaviour.
PLACES = [
    ('Makkah', 21.4225, 39.8262),
    ('Equator', 0.0, 0.0),
    ('SanFrancisco', 37.6190, -122.3750),
    ('Istanbul', 41.2622, 28.7278),
    ('London', 51.5074, -0.1278),
    ('Sydney', -33.8688, 151.2093),
    ('RouteFajrPt', 66.2000, -92.4000),
    ('RoutePeak', 73.0000, -52.6000),
]

# One northern-summer date and one northern-winter date, so each latitude is
# sampled on both sides of the year.
DATES = [datetime.date(2026, 7, 31), datetime.date(2026, 12, 21)]

OUTPUT = os.path.join('test', 'data', 'solar_reference.csv')


def event_utc(latitude, longitude, day, angle_degrees, kind):
    """The UTC instant of one solar event, or None if it never happens."""
    observer = ephem.Observer()
    observer.lat, observer.lon = str(latitude), str(longitude)
    observer.elevation = 0
    observer.pressure = 0  # geometric altitude; no refraction correction
    observer.horizon = str(-angle_degrees)
    # Start searching from local solar midnight so the event found belongs to
    # the requested day rather than to the UTC day.
    observer.date = ephem.Date(
        datetime.datetime.combine(day, datetime.time(0, 0))
    ) - longitude / 360.0

    sun = ephem.Sun()
    try:
        if kind == 'rise':
            found = observer.next_rising(sun, use_center=True)
        else:
            found = observer.next_setting(sun, use_center=True)
    except (ephem.AlwaysUpError, ephem.NeverUpError):
        return None
    return ephem.Date(found).datetime()


def main():
    rows = []
    for name, latitude, longitude in PLACES:
        for day in DATES:
            for event, angle, kind in EVENTS:
                instant = event_utc(latitude, longitude, day, angle, kind)
                rows.append([
                    name,
                    f'{latitude:.4f}',
                    f'{longitude:.4f}',
                    day.isoformat(),
                    event,
                    instant.strftime('%Y-%m-%dT%H:%M:%SZ') if instant else '',
                ])

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, 'w', newline='') as handle:
        writer = csv.writer(handle)
        writer.writerow(['place', 'lat', 'lon', 'date', 'event',
                         'reference_utc'])
        writer.writerows(rows)

    absent = sum(1 for row in rows if not row[5])
    print(f'{len(rows)} rows written to {OUTPUT}')
    print(f'{absent} of them have no event (sun never reaches the angle)')


if __name__ == '__main__':
    main()
