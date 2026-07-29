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

      // shiaMidnightForDate returns a wall-clock time in the device's own zone,
      // so shift it onto the UTC timeline before comparing.
      final date = DateTime(2024, 6, 16);
      final expectedUtc = shiaMidnightForDate(
        prayerTime: prayerTime,
        date: date,
        latitude: makkah.latitude,
        longitude: makkah.longitude,
      )!
          .subtract(date.timeZoneOffset);

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

  group('computeFlightPrayerPlan', () {
    test('a stationary "flight" reproduces the ground prayer times', () {
      final prayerTime = buildCalculator();
      // Origin and destination are the same point, so the solver must land on
      // exactly the times a person standing in Makkah would use.
      final plan = computeFlightPrayerPlan(
        prayerTime: prayerTime,
        origin: makkah,
        destination: makkah,
        departureUtc: DateTime.utc(2024, 6, 16, 0),
        arrivalUtc: DateTime.utc(2024, 6, 16, 21),
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
        final instants = prayerInstantsUtc(
          prayerTime: prayerTime,
          instantUtc: event.instantUtc!,
          position: event.position!,
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
