import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/flight_prayer_times.dart';
import 'package:shia_companion/utils/geo_utils.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/prayer_times.dart';

/// The app's configured calculator: Jafari angles, Hanafi asr, angle-based
/// high-latitude adjustment. Rebuilt per test so state cannot leak.
PrayerTime buildCalculator() {
  final prayerTime = PrayerTime();
  prayerTime.setCalcMethod(prayerTime.getJafari());
  prayerTime.setAsrJuristic(prayerTime.getHanafi());
  prayerTime.setAdjustHighLats(prayerTime.getAngleBased());
  return prayerTime;
}

const sanFrancisco = GeoPoint(37.6190, -122.3750);
const istanbul = GeoPoint(41.2622, 28.7278);
const makkah = GeoPoint(21.4225, 39.8262);
const karachi = GeoPoint(24.9065, 67.1608);

void main() {
  group('prayerInstantsUtc', () {
    test('agrees with the stationary calculator for a fixed location', () {
      final prayerTime = buildCalculator();
      // Makkah, 16 June 2024, UTC+3.
      final instants = prayerInstantsUtc(
        prayerTime: prayerTime,
        instantUtc: DateTime.utc(2024, 6, 16, 9),
        position: makkah,
      );

      prayerTime.setTimeFormat(prayerTime.getTime24());
      final stationary = prayerTime.getPrayerTimes(
        DateTime(2024, 6, 16),
        makkah.latitude,
        makkah.longitude,
        3.0,
      );

      // Midnight is derived rather than returned by the calculator, so it is
      // checked separately below.
      for (final index in flightPrayerIndices) {
        if (index == prayerIndexMidnight) continue;
        final instant = instants[index];
        expect(instant, isNotNull, reason: 'no instant for index $index');

        // Convert the solved UTC instant back into Makkah local time.
        final local = instant!.add(const Duration(hours: 3));
        final expected = dateTimeForTime24(DateTime.utc(2024, 6, 16),
            stationary[index])!;
        expect(
          local.difference(expected).inMinutes.abs(),
          lessThanOrEqualTo(1),
          reason: 'index $index: got $local, expected $expected',
        );
      }
    });

    test('midnight matches the app\'s stationary Shia midnight', () {
      final prayerTime = buildCalculator();
      // Late evening in Makkah, so the "current" night is the one in progress.
      final instants = prayerInstantsUtc(
        prayerTime: prayerTime,
        instantUtc: DateTime.utc(2024, 6, 16, 19), // 22:00 local
        position: makkah,
      );

      // Given a UTC date, shiaMidnightForDate computes against a zero offset
      // and answers on the UTC timeline, so there is nothing to shift and
      // nothing that depends on where the machine running this happens to be.
      final expectedUtc = shiaMidnightForDate(
        prayerTime: prayerTime,
        date: DateTime.utc(2024, 6, 16),
        latitude: makkah.latitude,
        longitude: makkah.longitude,
      )!;

      expect(
        instants[prayerIndexMidnight]!.difference(expectedUtc).inMinutes.abs(),
        lessThanOrEqualTo(2),
      );
    });

    test('midnight is the midpoint of sunset and the following dawn', () {
      final prayerTime = buildCalculator();

      final sunset = prayerInstantsUtc(
        prayerTime: prayerTime,
        instantUtc: DateTime.utc(2024, 6, 16, 19), // 22:00 local
        position: makkah,
      )[prayerIndexSunset]!;
      final midnight = prayerInstantsUtc(
        prayerTime: prayerTime,
        instantUtc: DateTime.utc(2024, 6, 16, 19),
        position: makkah,
      )[prayerIndexMidnight]!;
      // Past solar midnight, so the returned Fajr is the upcoming dawn.
      final dawn = prayerInstantsUtc(
        prayerTime: prayerTime,
        instantUtc: DateTime.utc(2024, 6, 16, 22), // 01:00 local
        position: makkah,
      )[prayerIndexFajr]!;

      expect(dawn.isAfter(sunset), isTrue);
      final expected = sunset.add(
        Duration(milliseconds: dawn.difference(sunset).inMilliseconds ~/ 2),
      );
      expect(
        midnight.difference(expected).inMinutes.abs(),
        lessThanOrEqualTo(1),
      );
    });

    test('midnight stays on the same night either side of solar midnight', () {
      // The frame is anchored at noon precisely so that a moment just before
      // and just after 00:00 local resolve to the same night's midnight.
      final prayerTime = buildCalculator();

      final before = prayerInstantsUtc(
        prayerTime: prayerTime,
        instantUtc: DateTime.utc(2024, 6, 16, 20, 50), // 23:50 local
        position: makkah,
      )[prayerIndexMidnight]!;
      final after = prayerInstantsUtc(
        prayerTime: prayerTime,
        instantUtc: DateTime.utc(2024, 6, 16, 21, 10), // 00:10 local
        position: makkah,
      )[prayerIndexMidnight]!;

      expect(after.difference(before).inMinutes.abs(), lessThanOrEqualTo(2));
    });

    test('midnight sits between sunset and the following dawn', () {
      final prayerTime = buildCalculator();
      final instants = prayerInstantsUtc(
        prayerTime: prayerTime,
        instantUtc: DateTime.utc(2024, 6, 16, 19),
        position: makkah,
      );

      final sunset = instants[prayerIndexSunset]!;
      final midnight = instants[prayerIndexMidnight]!;
      expect(midnight.isAfter(sunset), isTrue);
      // Comfortably before the next dawn, roughly 8 hours after sunset here.
      expect(midnight.difference(sunset).inHours, inInclusiveRange(3, 6));
    });

    test('returns null where the sun never reaches the angle', () {
      // Svalbard in midsummer: no sunrise, no sunset, no true dawn.
      final instants = prayerInstantsUtc(
        prayerTime: buildCalculator(),
        instantUtc: DateTime.utc(2024, 6, 21, 12),
        position: const GeoPoint(78.2232, 15.6469),
      );

      expect(instants[prayerIndexSunrise], isNull);
      expect(instants[prayerIndexFajr], isNull);
      // Midday is always defined, even under a midnight sun.
      expect(instants[prayerIndexZuhr], isNotNull);
    });
  });

  group('horizonDipDegrees', () {
    test('is zero at sea level and grows with altitude', () {
      expect(horizonDipDegrees(0), 0);
      expect(horizonDipDegrees(-500), 0);
      expect(horizonDipDegrees(30000), closeTo(3.07, 0.02));
      expect(horizonDipDegrees(35000), closeTo(3.31, 0.02));
      expect(horizonDipDegrees(38000), closeTo(3.45, 0.02));
      expect(horizonDipDegrees(41000), closeTo(3.59, 0.02));
    });

    test('is insensitive across the realistic cruise band', () {
      // Half a degree over 11,000 ft is why a fixed default is defensible.
      final spread = horizonDipDegrees(41000) - horizonDipDegrees(30000);
      expect(spread, lessThan(0.6));
    });
  });

  group('altitudeFeetAt', () {
    const total = Duration(hours: 13, minutes: 10);

    test('climbs, cruises, and descends', () {
      expect(altitudeFeetAt(elapsed: Duration.zero, total: total), 0);
      expect(
        altitudeFeetAt(elapsed: const Duration(minutes: 12, seconds: 30),
            total: total),
        closeTo(19000, 1),
      );
      expect(
        altitudeFeetAt(elapsed: const Duration(minutes: 25), total: total),
        closeTo(38000, 1),
      );
      expect(
        altitudeFeetAt(elapsed: const Duration(hours: 6), total: total),
        closeTo(38000, 1),
      );
      expect(altitudeFeetAt(elapsed: total, total: total), closeTo(0, 1));
    });

    test('never exceeds cruise or goes negative', () {
      for (var minute = 0; minute <= total.inMinutes; minute++) {
        final altitude =
            altitudeFeetAt(elapsed: Duration(minutes: minute), total: total);
        expect(altitude, inInclusiveRange(0, 38000), reason: 'at $minute min');
      }
    });

    test('scales both phases down on a hop too short for them', () {
      // A 40 minute flight cannot fit a 25 minute climb and 30 minute descent.
      const short = Duration(minutes: 40);
      final peak = altitudeFeetAt(
          elapsed: const Duration(minutes: 20), total: short);
      expect(peak, closeTo(38000, 1));
      for (var minute = 0; minute <= 40; minute++) {
        expect(
          altitudeFeetAt(elapsed: Duration(minutes: minute), total: short),
          inInclusiveRange(0, 38000),
        );
      }
    });

    test('degenerate inputs give zero rather than NaN', () {
      expect(altitudeFeetAt(elapsed: Duration.zero, total: Duration.zero), 0);
      expect(
        altitudeFeetAt(
            elapsed: const Duration(hours: 1),
            total: const Duration(hours: 2),
            cruiseAltitudeFeet: 0),
        0,
      );
    });
  });

  group('HorizonAdjustedPrayerTime', () {
    test('delays Maghrib and advances Fajr, leaving Zuhr and Asr alone', () {
      final ground = buildCalculator();
      const position = GeoPoint(41.2622, 28.7278);
      final instant = DateTime.utc(2026, 7, 31, 12);

      final atGround = prayerInstantsUtc(
          prayerTime: ground, instantUtc: instant, position: position);
      final atAltitude = prayerInstantsUtc(
        prayerTime: ground,
        instantUtc: instant,
        position: position,
        dipDegrees: horizonDipDegrees(38000),
      );

      Duration shift(int index) =>
          atAltitude[index]!.difference(atGround[index]!);

      // Horizon-referenced prayers move, and in opposite directions.
      expect(shift(prayerIndexMaghrib).inMinutes, inInclusiveRange(15, 30));
      expect(shift(prayerIndexSunset).inMinutes, inInclusiveRange(10, 25));
      expect(shift(prayerIndexFajr).inMinutes, inInclusiveRange(-35, -15));
      expect(shift(prayerIndexSunrise).inMinutes, inInclusiveRange(-25, -10));

      // Zuhr is meridian transit and Asr is a solar-altitude rule, so neither
      // depends on where the observer's horizon is.
      expect(shift(prayerIndexZuhr).inSeconds.abs(), lessThanOrEqualTo(1));
      expect(shift(prayerIndexAsr).inSeconds.abs(), lessThanOrEqualTo(1));
    });

    test('a zero dip reproduces the ground times exactly', () {
      final ground = buildCalculator();
      const position = GeoPoint(41.2622, 28.7278);
      final instant = DateTime.utc(2026, 7, 31, 12);

      final plain = prayerInstantsUtc(
          prayerTime: ground, instantUtc: instant, position: position);
      final zeroDip = prayerInstantsUtc(
          prayerTime: ground,
          instantUtc: instant,
          position: position,
          dipDegrees: 0);

      for (final index in flightPrayerIndices) {
        expect(zeroDip[index], plain[index], reason: 'index $index');
      }
    });

    test('copies the source settings rather than mutating it', () {
      final source = buildCalculator();
      final originalMethod = source.getCalcMethod();
      final originalAngles = List<double>.of(source.mParams);

      final adjusted = HorizonAdjustedPrayerTime(source, 3.45);
      expect(adjusted.getCalcMethod(), originalMethod);
      expect(adjusted.getAsrJuristic(), source.getAsrJuristic());
      expect(adjusted.getAdjustHighLats(), source.getAdjustHighLats());

      // The shared method-parameter table must not be written through.
      adjusted.mParams[0] = 99;
      expect(source.mParams, originalAngles);
    });
  });

  group('computeFlightPrayerPlan', () {
    test('a stationary "flight" reproduces the ground prayer times', () {
      final prayerTime = buildCalculator();
      // Origin and destination are the same point, so the solver must land on
      // exactly the times a person standing in Makkah would use. The ground
      // horizon is required for that comparison — the aircraft horizon is
      // deliberately different.
      final plan = computeFlightPrayerPlan(
        prayerTime: prayerTime,
        origin: makkah,
        destination: makkah,
        departureUtc: DateTime.utc(2024, 6, 16, 0),
        arrivalUtc: DateTime.utc(2024, 6, 16, 21),
        useAircraftHorizon: false,
      );

      prayerTime.setTimeFormat(prayerTime.getTime24());
      final stationary = prayerTime.getPrayerTimes(
        DateTime(2024, 6, 16),
        makkah.latitude,
        makkah.longitude,
        3.0,
      );

      for (final event in plan.eventsDuringFlight) {
        if (event.prayerIndex == prayerIndexMidnight) continue;
        final local = event.instantUtc!.add(const Duration(hours: 3));
        final expected = dateTimeForTime24(
            DateTime.utc(2024, 6, 16), stationary[event.prayerIndex])!;
        expect(
          local.difference(expected).inMinutes.abs(),
          lessThanOrEqualTo(1),
          reason: '${event.name}: got $local, expected $expected',
        );
      }

      // Fajr through midnight all fall inside a 00:00–21:00 UTC window in
      // Makkah, so every tracked prayer produces an event.
      expect(plan.eventsDuringFlight.length, flightPrayerIndices.length);
      expect(plan.isValid, isTrue);
    });

    test('events come out in chronological order and inside the window', () {
      // SFO 22:35 (UTC-7) → IST 20:15 next day (UTC+3): the user's flight.
      final plan = computeFlightPrayerPlan(
        prayerTime: buildCalculator(),
        origin: sanFrancisco,
        destination: istanbul,
        departureUtc: DateTime.utc(2024, 7, 31, 5, 35),
        arrivalUtc: DateTime.utc(2024, 7, 31, 17, 15),
      );

      final events = plan.eventsDuringFlight;
      expect(events, isNotEmpty);

      for (final event in events) {
        expect(event.instantUtc!.isBefore(plan.departureUtc), isFalse);
        expect(event.instantUtc!.isAfter(plan.arrivalUtc), isFalse);
        expect(event.position, isNotNull);
        expect(event.qiblaBearingDegrees, inInclusiveRange(0, 360));
      }

      for (var i = 1; i < events.length; i++) {
        expect(events[i].instantUtc!.isBefore(events[i - 1].instantUtc!),
            isFalse);
      }

      // The great circle from California to Turkey runs well into the Arctic.
      expect(plan.crossesHighLatitude, isTrue);
    });

    test('a solved prayer instant is self-consistent at its own position', () {
      // The defining property: at the moment the prayer comes in, the prayer
      // time computed for the aircraft's position at that moment is that same
      // moment. This is what makes the answer correct rather than merely
      // plausible.
      final prayerTime = buildCalculator();
      final plan = computeFlightPrayerPlan(
        prayerTime: prayerTime,
        origin: sanFrancisco,
        destination: istanbul,
        departureUtc: DateTime.utc(2024, 7, 31, 5, 35),
        arrivalUtc: DateTime.utc(2024, 7, 31, 17, 15),
      );

      for (final event in plan.eventsDuringFlight) {
        // Re-solve with the same horizon dip the plan used at that moment,
        // otherwise this compares an aircraft-horizon time against a
        // ground-horizon one.
        final instants = prayerInstantsUtc(
          prayerTime: prayerTime,
          instantUtc: event.instantUtc!,
          position: event.position!,
          dipDegrees: horizonDipDegrees(event.altitudeFeet ?? 0),
        );
        final selfConsistent = instants[event.prayerIndex];
        expect(selfConsistent, isNotNull, reason: event.name);
        expect(
          selfConsistent!.difference(event.instantUtc!).inSeconds.abs(),
          lessThanOrEqualTo(60),
          reason: '${event.name} is not a fixed point of the prayer equation',
        );
      }
    });

    test('flying east into the sunset brings Maghrib in early', () {
      // Due east along the equator, so latitude effects drop out entirely and
      // only the longitude change is left. Chasing the sunset eastwards must
      // bring Maghrib in well before the origin's own Maghrib.
      final prayerTime = buildCalculator();
      const origin = GeoPoint(0, 0);
      const destination = GeoPoint(0, 60);
      final departureUtc = DateTime.utc(2024, 3, 20, 12);

      final plan = computeFlightPrayerPlan(
        prayerTime: prayerTime,
        origin: origin,
        destination: destination,
        departureUtc: departureUtc,
        arrivalUtc: DateTime.utc(2024, 3, 20, 18),
      );

      final maghrib = plan.events
          .firstWhere((event) => event.prayerIndex == prayerIndexMaghrib);
      expect(maghrib.status, FlightPrayerStatus.duringFlight);

      final stationaryMaghrib = prayerInstantsUtc(
        prayerTime: prayerTime,
        instantUtc: departureUtc,
        position: origin,
      )[prayerIndexMaghrib]!;

      expect(
        maghrib.instantUtc!.isBefore(stationaryMaghrib),
        isTrue,
        reason: 'eastbound flight should reach Maghrib before the origin does',
      );
      // This case has a closed form worth pinning down. The aircraft covers
      // 60° of longitude in 6 hours, so with M as the origin's Maghrib in
      // hours UTC, the prayer instant solves
      //     M - (10·(t-12))/15 = t   →   t = 0.6·(M + 8),
      // leaving the aircraft ahead of the origin by 0.4·M - 4.8 hours. For an
      // equatorial Maghrib near 18:30 UTC that is a little over 2.5 hours.
      expect(
        stationaryMaghrib.difference(maghrib.instantUtc!).inMinutes,
        inInclusiveRange(140, 165),
      );
      // The prayer must land at a longitude the aircraft has actually reached.
      expect(maghrib.position!.longitude, greaterThan(0));
      expect(maghrib.position!.longitude, lessThan(60));
    });

    test('a prayer already in at departure is reported, not invented', () {
      // SFO → IST leaving at 22:35 local: Maghrib passed before boarding.
      final plan = computeFlightPrayerPlan(
        prayerTime: buildCalculator(),
        origin: sanFrancisco,
        destination: istanbul,
        departureUtc: DateTime.utc(2024, 7, 31, 5, 35),
        arrivalUtc: DateTime.utc(2024, 7, 31, 17, 15),
      );

      final maghrib = plan.events
          .firstWhere((event) => event.prayerIndex == prayerIndexMaghrib);
      expect(maghrib.status, FlightPrayerStatus.alreadyInAtDeparture);
      expect(maghrib.instantUtc, isNull);
    });

    test('reports prayers that fall outside the flight window', () {
      // A short hop within one afternoon cannot contain Fajr.
      final plan = computeFlightPrayerPlan(
        prayerTime: buildCalculator(),
        origin: karachi,
        destination: const GeoPoint(25.2528, 55.3644), // Dubai
        departureUtc: DateTime.utc(2024, 7, 31, 6),
        arrivalUtc: DateTime.utc(2024, 7, 31, 8),
      );

      final fajr = plan.events
          .firstWhere((event) => event.prayerIndex == prayerIndexFajr);
      expect(fajr.status, FlightPrayerStatus.alreadyInAtDeparture);
      expect(fajr.instantUtc, isNull);

      final isha = plan.events
          .firstWhere((event) => event.prayerIndex == prayerIndexIsha);
      expect(isha.status, FlightPrayerStatus.afterArrival);
    });

    test('flags an unusable window instead of hanging', () {
      final plan = computeFlightPrayerPlan(
        prayerTime: buildCalculator(),
        origin: sanFrancisco,
        destination: istanbul,
        departureUtc: DateTime.utc(2024, 7, 31, 10),
        arrivalUtc: DateTime.utc(2024, 7, 31, 10),
      );

      expect(plan.isValid, isFalse);
      expect(plan.eventsDuringFlight, isEmpty);
    });

    test('defaults to the aircraft horizon and reports the shift', () {
      final plan = computeFlightPrayerPlan(
        prayerTime: buildCalculator(),
        origin: sanFrancisco,
        destination: istanbul,
        departureUtc: DateTime.utc(2026, 7, 31, 2, 55),
        arrivalUtc: DateTime.utc(2026, 7, 31, 16, 5),
      );

      expect(plan.usesAircraftHorizon, isTrue);
      expect(plan.cruiseAltitudeFeet, defaultCruiseAltitudeFeet);

      final maghrib = plan.eventsDuringFlight
          .firstWhere((event) => event.prayerIndex == prayerIndexMaghrib);
      expect(maghrib.groundHorizonInstantUtc, isNotNull);
      // Maghrib lands 45 minutes in, so the aircraft is already at cruise.
      expect(maghrib.altitudeFeet, closeTo(38000, 1));
      expect(maghrib.shiftFromGroundHorizon!.inMinutes, greaterThan(10));

      final fajr = plan.eventsDuringFlight
          .firstWhere((event) => event.prayerIndex == prayerIndexFajr);
      expect(fajr.shiftFromGroundHorizon!.inMinutes, lessThan(0));
    });

    test('the aircraft-horizon plan is shifted from the ground-horizon plan',
        () {
      final departureUtc = DateTime.utc(2026, 7, 31, 2, 55);
      final arrivalUtc = DateTime.utc(2026, 7, 31, 16, 5);

      FlightPrayerPlan planFor({required bool aircraft}) =>
          computeFlightPrayerPlan(
            prayerTime: buildCalculator(),
            origin: sanFrancisco,
            destination: istanbul,
            departureUtc: departureUtc,
            arrivalUtc: arrivalUtc,
            useAircraftHorizon: aircraft,
          );

      final ground = planFor(aircraft: false);
      final air = planFor(aircraft: true);

      expect(ground.usesAircraftHorizon, isFalse);
      // The ground plan is the comparison baseline, so it carries no shift.
      for (final event in ground.eventsDuringFlight) {
        expect(event.groundHorizonInstantUtc, isNull, reason: event.name);
      }

      final groundMaghrib = ground.eventsDuringFlight
          .firstWhere((event) => event.prayerIndex == prayerIndexMaghrib);
      final airMaghrib = air.eventsDuringFlight
          .firstWhere((event) => event.prayerIndex == prayerIndexMaghrib);

      expect(airMaghrib.instantUtc!.isAfter(groundMaghrib.instantUtc!), isTrue);
      // Each event's reported baseline must be the ground plan's own answer.
      expect(
        airMaghrib.groundHorizonInstantUtc,
        groundMaghrib.instantUtc,
      );
    });

    test('a prayer during the climb gets a smaller correction than at cruise',
        () {
      // Departure timed so the eastbound equatorial Maghrib lands ten minutes
      // in, less than halfway up the climb.
      FlightPrayerEvent maghribFor(DateTime departureUtc) {
        final plan = computeFlightPrayerPlan(
          prayerTime: buildCalculator(),
          origin: const GeoPoint(0, 0),
          destination: const GeoPoint(0, 60),
          departureUtc: departureUtc,
          arrivalUtc: departureUtc.add(const Duration(hours: 6)),
        );
        return plan.eventsDuringFlight
            .firstWhere((event) => event.prayerIndex == prayerIndexMaghrib);
      }

      final climbing = maghribFor(DateTime.utc(2026, 3, 20, 18, 15));
      final cruising = maghribFor(DateTime.utc(2026, 3, 20, 17, 30));

      expect(climbing.altitudeFeet, greaterThan(0));
      expect(climbing.altitudeFeet, lessThan(defaultCruiseAltitudeFeet / 2));
      expect(cruising.altitudeFeet, closeTo(defaultCruiseAltitudeFeet, 1));

      // Still corrected, but by strictly less than a cruising aircraft.
      expect(climbing.shiftFromGroundHorizon!.inMinutes, greaterThan(0));
      expect(
        climbing.shiftFromGroundHorizon!,
        lessThan(cruising.shiftFromGroundHorizon!),
      );
      expect(
        horizonDipDegrees(climbing.altitudeFeet!),
        lessThan(horizonDipDegrees(defaultCruiseAltitudeFeet)),
      );
    });

    test('restores the calculator time format', () {
      final prayerTime = buildCalculator();
      final originalFormat = prayerTime.getTimeFormat();

      computeFlightPrayerPlan(
        prayerTime: prayerTime,
        origin: sanFrancisco,
        destination: istanbul,
        departureUtc: DateTime.utc(2024, 7, 31, 5, 35),
        arrivalUtc: DateTime.utc(2024, 7, 31, 17, 15),
      );

      expect(prayerTime.getTimeFormat(), originalFormat);
    });
  });
}
