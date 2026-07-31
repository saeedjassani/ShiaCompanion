import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/flight_prayer_times.dart';
import 'package:shia_companion/utils/geo_utils.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/prayer_times.dart';

/// Measures the app's solar model against an independent reference.
///
/// `lib/utils/prayer_times.dart` computes the sun's position with a simplified
/// approximation. `test/data/solar_reference.csv` holds the same events
/// computed with PyEphem's far more precise model — regenerate it with
/// `scripts/generate_solar_reference.py`. The gap between the two is the
/// approximation's error, and these tests pin how large it is allowed to get.
///
/// Two distinct properties are checked, and the second matters more than the
/// first: that the times agree, and that the two models agree on whether the
/// event *happens at all*. Claiming a dawn that never breaks would be a far
/// worse failure than being a minute out.

const _eventIndices = {
  'Fajr': prayerIndexFajr,
  'Sunrise': prayerIndexSunrise,
  'Sunset': prayerIndexSunset,
  'Maghrib': prayerIndexMaghrib,
  'Isha': prayerIndexIsha,
};

class _ReferenceRow {
  const _ReferenceRow({
    required this.place,
    required this.position,
    required this.date,
    required this.event,
    required this.referenceUtc,
  });

  final String place;
  final GeoPoint position;
  final DateTime date;
  final String event;

  /// Null where the sun never reaches the angle on that day.
  final DateTime? referenceUtc;

  String get label => '$place ${date.toIso8601String().substring(0, 10)} $event';
}

List<_ReferenceRow> _loadReference() {
  final file = File('test/data/solar_reference.csv');
  final rows = <_ReferenceRow>[];

  for (final line in file.readAsLinesSync().skip(1)) {
    if (line.trim().isEmpty) continue;
    final fields = line.split(',');
    rows.add(_ReferenceRow(
      place: fields[0],
      position: GeoPoint(double.parse(fields[1]), double.parse(fields[2])),
      date: DateTime.parse(fields[3]),
      event: fields[4],
      referenceUtc: fields[5].isEmpty ? null : DateTime.parse(fields[5]),
    ));
  }
  return rows;
}

/// Raw astronomy, with the high-latitude substitution switched off.
///
/// The app itself runs with the angle-based rule, which invents a time whenever
/// the real event does not occur. That rule is a juristic convention and has no
/// astronomical truth to be compared against, so it is disabled here in order
/// to measure the solar model on its own.
PrayerTime buildUnadjustedCalculator() {
  final prayerTime = PrayerTime();
  prayerTime.setCalcMethod(prayerTime.getJafari());
  prayerTime.setAsrJuristic(prayerTime.getHanafi());
  prayerTime.setAdjustHighLats(prayerTime.getNone());
  return prayerTime;
}

DateTime? _computed(PrayerTime prayerTime, _ReferenceRow row) {
  // Probe near local solar noon so the solar-day frame lands on the right day.
  final probe = DateTime.utc(row.date.year, row.date.month, row.date.day, 12)
      .subtract(Duration(minutes: (row.position.longitude * 4).round()));

  return prayerInstantsUtc(
    prayerTime: prayerTime,
    instantUtc: probe,
    position: row.position,
  )[_eventIndices[row.event]!];
}

void main() {
  late List<_ReferenceRow> reference;

  setUpAll(() => reference = _loadReference());

  test('the reference covers a spread of latitudes and both solstice sides',
      () {
    expect(reference, hasLength(80));
    expect(
      reference.map((row) => row.place).toSet(),
      containsAll(['Equator', 'Makkah', 'London', 'RoutePeak', 'Sydney']),
    );
    // Some rows must have no event, or the polar cases are not being exercised.
    expect(reference.where((row) => row.referenceUtc == null), isNotEmpty);
  });

  test('agrees with the reference on whether an event happens at all', () {
    final prayerTime = buildUnadjustedCalculator();
    final disagreements = <String>[];

    for (final row in reference) {
      final computed = _computed(prayerTime, row);
      final referenceHappens = row.referenceUtc != null;
      if ((computed != null) != referenceHappens) {
        disagreements.add(
          '${row.label}: app=${computed == null ? "none" : "occurs"}, '
          'reference=${referenceHappens ? "occurs" : "none"}',
        );
      }
    }

    expect(disagreements, isEmpty,
        reason: 'existence of a solar event must never be invented or lost');
  });

  test('is within 30 seconds below 50 degrees latitude', () {
    final prayerTime = buildUnadjustedCalculator();
    var worst = Duration.zero;
    var worstLabel = '';

    for (final row in reference) {
      if (row.position.latitude.abs() >= 50) continue;
      final computed = _computed(prayerTime, row);
      if (computed == null || row.referenceUtc == null) continue;

      final delta = computed.difference(row.referenceUtc!).abs();
      if (delta > worst) {
        worst = delta;
        worstLabel = row.label;
      }
    }

    expect(worst.inSeconds, lessThanOrEqualTo(30),
        reason: 'worst case was $worstLabel at ${worst.inSeconds}s');
  });

  test('is within three minutes up to 70 degrees latitude', () {
    // The error grows towards the poles: near the horizon the sun's altitude
    // changes slowly, so a fixed angular error buys a much larger time error.
    final prayerTime = buildUnadjustedCalculator();
    var worst = Duration.zero;
    var worstLabel = '';

    for (final row in reference) {
      if (row.position.latitude.abs() >= 70) continue;
      final computed = _computed(prayerTime, row);
      if (computed == null || row.referenceUtc == null) continue;

      final delta = computed.difference(row.referenceUtc!).abs();
      if (delta > worst) {
        worst = delta;
        worstLabel = row.label;
      }
    }

    expect(worst.inSeconds, lessThanOrEqualTo(180),
        reason: 'worst case was $worstLabel at ${worst.inSeconds}s');
  });

  test('confirms polar day on the SFO-Istanbul route in late July', () {
    // The great circle peaks near 73N, where at the end of July the sun does
    // not set at all. Any Fajr, Maghrib or Isha the app shows there comes from
    // the high-latitude substitution, not from astronomy — which is exactly
    // why the flight page warns about it.
    final polarRows = reference.where((row) =>
        row.place == 'RoutePeak' && row.date.month == 7 && row.date.day == 31);

    expect(polarRows, hasLength(5));
    for (final row in polarRows) {
      expect(row.referenceUtc, isNull, reason: '${row.label} should not occur');
    }

    final prayerTime = buildUnadjustedCalculator();
    for (final row in polarRows) {
      expect(_computed(prayerTime, row), isNull, reason: row.label);
    }
  });

  test('the app default substitutes a time where astronomy gives none', () {
    // Documents the behaviour rather than endorsing it. At 66N in late July
    // the sun still sets, but it never reaches the 16 degree depression that
    // defines dawn — so the angle-based rule fills in a Fajr from a fraction
    // of the night instead. That number is an estimate, not an observation,
    // and it is the one the flight page shows on this route.
    final appDefault = PrayerTime()
      ..setCalcMethod(0)
      ..setAsrJuristic(1)
      ..setAdjustHighLats(3); // angle-based, as configured in constants.dart

    final noTrueDawn = reference.firstWhere((row) =>
        row.place == 'RouteFajrPt' &&
        row.event == 'Fajr' &&
        row.date.month == 7);
    expect(noTrueDawn.referenceUtc, isNull,
        reason: 'no true dawn at 66N on 31 July');

    // Raw astronomy declines to answer; the app's configuration answers anyway.
    expect(_computed(buildUnadjustedCalculator(), noTrueDawn), isNull);
    expect(_computed(appDefault, noTrueDawn), isNotNull,
        reason: 'the high-latitude rule is expected to fill this in');

    // Sunset at the same place and time is real, which is why the rule has a
    // night length to work from here but not at the polar peak.
    final realSunset = reference.firstWhere((row) =>
        row.place == 'RouteFajrPt' &&
        row.event == 'Sunset' &&
        row.date.month == 7);
    expect(realSunset.referenceUtc, isNotNull);

    // At the polar peak there is no night at all, so even the rule gives up
    // rather than inventing a time.
    final polarFajr = reference.firstWhere((row) =>
        row.place == 'RoutePeak' &&
        row.event == 'Fajr' &&
        row.date.month == 7);
    expect(_computed(appDefault, polarFajr), isNull);
  });
}
