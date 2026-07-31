import 'dart:math';

import 'package:shia_companion/utils/geo_utils.dart';
import 'package:shia_companion/utils/prayer_time_entries.dart';
import 'package:shia_companion/utils/prayer_times.dart';

/// Prayer-time computation for a moving aircraft.
///
/// Prayer times on the ground are a function of position alone: the sun reaches
/// a given angle at a fixed instant for a fixed place. In the air, position is
/// itself a function of time, so the prayer instant has to be *solved* for
/// rather than looked up.
///
/// For a prayer p we define
///
///     g(t) = prayerInstant(p, position(t), solarDate(t)) - t
///
/// `g` is positive while the prayer is still ahead of the aircraft and negative
/// once it has passed. The prayer comes in at the downward zero crossing of
/// `g`, which this file finds by scanning the flight at a coarse step and then
/// bisecting the bracketing interval.

/// Shia midnight, the end of the Isha window. Follows the seven names returned
/// by [PrayerTime.getTimeNames], matching how the rest of the app appends it.
const int prayerIndexMidnight = 7;

/// Cruise altitude assumed when none is given. Across the realistic band of
/// 30,000–41,000 ft the horizon dip only moves from 3.07° to 3.59°, worth about
/// three minutes, so a sensible constant is enough — there is no need to ask
/// the user for the flight level.
const double defaultCruiseAltitudeFeet = 38000;

/// Rough vertical profile of an airliner. Worth modelling because a prayer can
/// fall well inside the climb: on the SFO–IST example Maghrib arrives 45
/// minutes after take-off, and treating that as cruise altitude would overstate
/// the correction.
const Duration typicalClimbDuration = Duration(minutes: 25);
const Duration typicalDescentDuration = Duration(minutes: 30);

/// Angle by which the visible horizon sits below the astronomical horizontal
/// for an observer at [altitudeFeet]. Zero at sea level, ~3.45° at 38,000 ft.
double horizonDipDegrees(double altitudeFeet) {
  if (altitudeFeet <= 0) return 0;

  final altitudeKm = altitudeFeet * 0.3048 / 1000.0;
  return acos(earthRadiusKm / (earthRadiusKm + altitudeKm)) * 180.0 / pi;
}

/// Altitude at [elapsed] into a flight of [total], assuming a linear climb to
/// [cruiseAltitudeFeet], a level cruise, and a linear descent.
///
/// Short hops that cannot fit a full climb and descent get both phases scaled
/// down proportionally rather than a clipped cruise.
double altitudeFeetAt({
  required Duration elapsed,
  required Duration total,
  double cruiseAltitudeFeet = defaultCruiseAltitudeFeet,
}) {
  final totalMs = total.inMilliseconds;
  if (totalMs <= 0 || cruiseAltitudeFeet <= 0) return 0;

  final elapsedMs = elapsed.inMilliseconds.clamp(0, totalMs);

  // Never let climb and descent claim more than 70% of the flight between them.
  final maxPhaseMs = (totalMs * 0.35).round();
  final climbMs = min(typicalClimbDuration.inMilliseconds, maxPhaseMs);
  final descentMs = min(typicalDescentDuration.inMilliseconds, maxPhaseMs);

  if (climbMs > 0 && elapsedMs < climbMs) {
    return cruiseAltitudeFeet * elapsedMs / climbMs;
  }
  final descentStartMs = totalMs - descentMs;
  if (descentMs > 0 && elapsedMs > descentStartMs) {
    return cruiseAltitudeFeet * (totalMs - elapsedMs) / descentMs;
  }
  return cruiseAltitudeFeet;
}

/// A calculator that measures the sun's depression from the horizon seen at
/// altitude rather than from the horizon at ground level.
///
/// The dip is added to every angle that is defined against the horizon —
/// sunrise, sunset, and the Fajr/Maghrib/Isha twilight angles — and left off
/// Zuhr and Asr, which are fixed by the sun's own altitude and so do not move
/// with the observer's height.
///
/// For sunrise and sunset this is exact geometry. For the twilight angles it is
/// an approximation: it assumes the whole dawn/dusk geometry rotates with the
/// observer's horizon, which is the usual practical treatment but not a
/// rigorous atmospheric model.
class HorizonAdjustedPrayerTime extends PrayerTime {
  HorizonAdjustedPrayerTime(PrayerTime source, this.dipDegrees) {
    setCalcMethod(source.getCalcMethod());
    setAsrJuristic(source.getAsrJuristic());
    setAdjustHighLats(source.getAdjustHighLats());
    setDhuhrMinutes(source.getDhuhrMinutes());
    setTimeFormat(source.getTimeFormat());
    setNumIterations(source.getNumIterations());
    methodParams = {
      for (final entry in source.methodParams.entries)
        entry.key: List<double>.of(entry.value),
    };
    tune(List<int>.of(source.offsets));
  }

  final double dipDegrees;

  /// Mirrors [PrayerTime.computeTimes], with the dip folded into the angles
  /// that are measured from the horizon.
  @override
  List<double> computeTimes(List<double> times) {
    final t = dayPortion(times);
    final params = mParams;

    final fajr = computeTime(180.0 - (params[0] + dipDegrees), t[0]);
    final sunrise = computeTime(180.0 - (0.833 + dipDegrees), t[1]);
    final dhuhr = computeMidDay(t[2]);
    final asr = computeAsr(1.0 + getAsrJuristic(), t[3]);
    final sunset = computeTime(0.833 + dipDegrees, t[4]);
    // In minutes-after-sunset mode adjustTimes overwrites these from the
    // already-adjusted sunset, so the dip still carries through.
    final maghrib = computeTime(params[2] + dipDegrees, t[5]);
    final isha = computeTime(params[4] + dipDegrees, t[6]);

    return [fajr, sunrise, dhuhr, asr, sunset, maghrib, isha];
  }
}

/// The prayers surfaced for a flight, in the order they are displayed.
const List<int> flightPrayerIndices = [
  prayerIndexFajr,
  prayerIndexSunrise,
  prayerIndexZuhr,
  prayerIndexAsr,
  prayerIndexMaghrib,
  prayerIndexIsha,
  prayerIndexMidnight,
];

/// How the prayer relates to the flight window.
enum FlightPrayerStatus {
  /// The prayer comes in while airborne. [FlightPrayerEvent.instantUtc] is set.
  duringFlight,

  /// The prayer was already in when the aircraft took off.
  alreadyInAtDeparture,

  /// The prayer does not come in before landing.
  afterArrival,

  /// The sun never reaches the required angle along the route — polar day or
  /// persistent twilight at high latitude. No time can be computed.
  sunAngleNeverReached,
}

class FlightPrayerEvent {
  const FlightPrayerEvent({
    required this.prayerIndex,
    required this.name,
    required this.status,
    this.instantUtc,
    this.position,
    this.qiblaBearingDegrees,
    this.courseBearingDegrees,
    this.altitudeFeet,
    this.groundHorizonInstantUtc,
  });

  final int prayerIndex;
  final String name;
  final FlightPrayerStatus status;

  /// The moment the prayer comes in, in UTC. Non-null only when [status] is
  /// [FlightPrayerStatus.duringFlight].
  final DateTime? instantUtc;

  /// Aircraft position at [instantUtc].
  final GeoPoint? position;

  /// Direction of the Kaaba from [position], degrees clockwise from true north.
  final double? qiblaBearingDegrees;

  /// Direction the aircraft is travelling at [instantUtc], degrees clockwise
  /// from true north. Combined with [qiblaBearingDegrees] this gives the qibla
  /// relative to the cabin, which is what you can actually judge from a seat.
  final double? courseBearingDegrees;

  /// Modelled altitude at [instantUtc], in feet.
  final double? altitudeFeet;

  /// The same prayer solved against the horizon of the ground below instead of
  /// the horizon seen from the cabin. Null when the two cannot be paired up.
  final DateTime? groundHorizonInstantUtc;

  bool get hasInstant => instantUtc != null;

  /// How much later this prayer falls than it would using the ground horizon.
  /// Negative for Fajr and sunrise, which arrive earlier from altitude.
  Duration? get shiftFromGroundHorizon {
    final aircraft = instantUtc;
    final ground = groundHorizonInstantUtc;
    if (aircraft == null || ground == null) return null;
    return aircraft.difference(ground);
  }

  /// Qibla direction relative to the nose of the aircraft, in degrees.
  /// Positive is to the right, negative to the left.
  double? get qiblaRelativeToCourseDegrees {
    final qibla = qiblaBearingDegrees;
    final course = courseBearingDegrees;
    if (qibla == null || course == null) return null;
    return relativeBearingDegrees(course, qibla);
  }
}

class FlightPrayerPlan {
  const FlightPrayerPlan({
    required this.events,
    required this.departureUtc,
    required this.arrivalUtc,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.crossesHighLatitude,
    required this.cruiseAltitudeFeet,
    required this.usesAircraftHorizon,
    this.isValid = true,
  });

  /// Cruise altitude the vertical profile was built from.
  final double cruiseAltitudeFeet;

  /// True when times are measured from the horizon seen at altitude.
  final bool usesAircraftHorizon;

  /// False when the flight window itself is unusable (zero or negative
  /// duration), in which case no prayer could be solved for.
  final bool isValid;

  final List<FlightPrayerEvent> events;
  final DateTime departureUtc;
  final DateTime arrivalUtc;
  final GeoPoint origin;
  final GeoPoint destination;
  final double distanceKm;

  /// True when any part of the route passes above 48.5°, the latitude beyond
  /// which the underlying calculator switches to its high-latitude estimate.
  final bool crossesHighLatitude;

  Duration get duration => arrivalUtc.difference(departureUtc);

  /// Events that come in while airborne, in chronological order.
  List<FlightPrayerEvent> get eventsDuringFlight => events
      .where((event) => event.status == FlightPrayerStatus.duringFlight)
      .toList()
    ..sort((a, b) => a.instantUtc!.compareTo(b.instantUtc!));

  List<FlightPrayerEvent> get eventsOutsideFlight => events
      .where((event) => event.status != FlightPrayerStatus.duringFlight)
      .toList();

  bool get hasUncomputablePrayer => events
      .any((event) => event.status == FlightPrayerStatus.sunAngleNeverReached);
}

/// Computes when each prayer comes in over the course of a flight.
///
/// [departureUtc] and [arrivalUtc] must both be UTC instants. [prayerTime] is
/// used for its configured calculation method (Jafari, Hanafi asr, and the
/// high-latitude rule) — its time format is saved and restored.
/// When [useAircraftHorizon] is true (the default) the sun's depression is
/// measured from the horizon visible at the aircraft's altitude, which puts
/// Maghrib roughly twenty minutes later and Fajr roughly twenty minutes earlier
/// than the horizon of the ground below. Each event also carries the
/// ground-horizon time for comparison. Whether the cabin or the ground horizon
/// governs the prayer is a question of jurisprudence, not of astronomy.
FlightPrayerPlan computeFlightPrayerPlan({
  required PrayerTime prayerTime,
  required GeoPoint origin,
  required GeoPoint destination,
  required DateTime departureUtc,
  required DateTime arrivalUtc,
  Duration scanStep = const Duration(minutes: 2),
  double cruiseAltitudeFeet = defaultCruiseAltitudeFeet,
  bool useAircraftHorizon = true,
}) {
  assert(departureUtc.isUtc && arrivalUtc.isUtc,
      'Flight endpoints must be UTC instants');

  final names = [...prayerTime.getTimeNames(), 'Midnight'];
  final originalFormat = prayerTime.getTimeFormat();
  prayerTime.setTimeFormat(prayerTime.getFloating());

  try {
    final durationMs = arrivalUtc.difference(departureUtc).inMilliseconds;
    // A non-positive duration cannot be scanned; report the flight as unusable
    // rather than looping forever over an empty window.
    if (durationMs <= 0) {
      return FlightPrayerPlan(
        events: [
          for (final index in flightPrayerIndices)
            FlightPrayerEvent(
              prayerIndex: index,
              name: names[index],
              status: FlightPrayerStatus.afterArrival,
            ),
        ],
        departureUtc: departureUtc,
        arrivalUtc: arrivalUtc,
        origin: origin,
        destination: destination,
        distanceKm: greatCircleDistanceKm(origin, destination),
        crossesHighLatitude: false,
        cruiseAltitudeFeet: cruiseAltitudeFeet,
        usesAircraftHorizon: useAircraftHorizon,
        isValid: false,
      );
    }

    final duration = Duration(milliseconds: durationMs);

    GeoPoint positionAt(DateTime instant) {
      final fraction =
          instant.difference(departureUtc).inMilliseconds / durationMs;
      return interpolateGreatCircle(origin, destination, fraction);
    }

    double altitudeAt(DateTime instant) {
      return altitudeFeetAt(
        elapsed: instant.difference(departureUtc),
        total: duration,
        cruiseAltitudeFeet: cruiseAltitudeFeet,
      );
    }

    double dipAt(DateTime instant) {
      if (!useAircraftHorizon) return 0;
      return horizonDipDegrees(altitudeAt(instant));
    }

    /// g(t) in milliseconds for every prayer index, or null where the sun never
    /// reaches that prayer's angle at this position.
    List<double?> offsetsAt(DateTime instant) {
      final instants = prayerInstantsUtc(
        prayerTime: prayerTime,
        instantUtc: instant,
        position: positionAt(instant),
        dipDegrees: dipAt(instant),
      );
      return [
        for (final prayerInstant in instants)
          prayerInstant == null
              ? null
              : prayerInstant.difference(instant).inMilliseconds.toDouble(),
      ];
    }

    var stepMs = scanStep.inMilliseconds;
    if (stepMs < 1000) stepMs = 1000;
    if (stepMs > durationMs) stepMs = durationMs;

    var previousInstant = departureUtc;
    var previousOffsets = offsetsAt(departureUtc);
    final departureOffsets = previousOffsets;

    // Every downward crossing, not just the first: an ultra-long-haul flight
    // can outlast a full solar day and see the same prayer come in twice.
    final crossings = <int, List<DateTime>>{
      for (final index in flightPrayerIndices) index: <DateTime>[],
    };
    final sawFiniteOffset = <int, bool>{
      for (final index in flightPrayerIndices)
        index: previousOffsets[index] != null,
    };

    var maxAbsLatitude = origin.latitude.abs() > destination.latitude.abs()
        ? origin.latitude.abs()
        : destination.latitude.abs();

    for (var elapsedMs = stepMs;; elapsedMs += stepMs) {
      final clampedMs = elapsedMs > durationMs ? durationMs : elapsedMs;
      final instant = departureUtc.add(Duration(milliseconds: clampedMs));
      final latitude = positionAt(instant).latitude.abs();
      if (latitude > maxAbsLatitude) maxAbsLatitude = latitude;
      final offsets = offsetsAt(instant);

      for (final index in flightPrayerIndices) {
        final previous = previousOffsets[index];
        final current = offsets[index];
        if (current != null) sawFiniteOffset[index] = true;
        if (previous == null || current == null) continue;

        // A downward crossing of zero is the prayer coming in. Rising
        // crossings are the solar date rolling over to the next day's prayer.
        if (previous > 0 && current <= 0) {
          crossings[index]!.add(_refineCrossing(
            prayerIndex: index,
            prayerTime: prayerTime,
            lower: previousInstant,
            upper: instant,
            positionAt: positionAt,
            dipAt: dipAt,
          ));
        }
      }

      previousInstant = instant;
      previousOffsets = offsets;
      if (clampedMs >= durationMs) break;
    }

    // Solve again against the ground horizon so every event can say how far the
    // altitude correction moved it. Guarded by the flag, so the recursive call
    // cannot recurse a second time.
    final groundCrossings = <int, List<DateTime>>{};
    if (useAircraftHorizon) {
      final groundPlan = computeFlightPrayerPlan(
        prayerTime: prayerTime,
        origin: origin,
        destination: destination,
        departureUtc: departureUtc,
        arrivalUtc: arrivalUtc,
        scanStep: scanStep,
        cruiseAltitudeFeet: cruiseAltitudeFeet,
        useAircraftHorizon: false,
      );
      for (final event in groundPlan.eventsDuringFlight) {
        groundCrossings
            .putIfAbsent(event.prayerIndex, () => <DateTime>[])
            .add(event.instantUtc!);
      }
    }

    final events = <FlightPrayerEvent>[];
    for (final index in flightPrayerIndices) {
      final prayerCrossings = crossings[index]!;
      if (prayerCrossings.isNotEmpty) {
        final ground = groundCrossings[index];
        for (var occurrence = 0;
            occurrence < prayerCrossings.length;
            occurrence++) {
          final crossing = prayerCrossings[occurrence];
          final position = positionAt(crossing);
          events.add(FlightPrayerEvent(
            prayerIndex: index,
            name: names[index],
            status: FlightPrayerStatus.duringFlight,
            instantUtc: crossing,
            position: position,
            altitudeFeet: altitudeAt(crossing),
            groundHorizonInstantUtc:
                ground != null && occurrence < ground.length
                    ? ground[occurrence]
                    : null,
            qiblaBearingDegrees: qiblaBearingDegrees(position),
            courseBearingDegrees: _courseAt(
              crossing: crossing,
              departureUtc: departureUtc,
              arrivalUtc: arrivalUtc,
              positionAt: positionAt,
            ),
          ));
        }
        continue;
      }

      final FlightPrayerStatus status;
      if (sawFiniteOffset[index] != true) {
        status = FlightPrayerStatus.sunAngleNeverReached;
      } else if ((departureOffsets[index] ?? 1) <= 0) {
        status = FlightPrayerStatus.alreadyInAtDeparture;
      } else {
        status = FlightPrayerStatus.afterArrival;
      }

      events.add(FlightPrayerEvent(
        prayerIndex: index,
        name: names[index],
        status: status,
      ));
    }

    return FlightPrayerPlan(
      events: events,
      departureUtc: departureUtc,
      arrivalUtc: arrivalUtc,
      origin: origin,
      destination: destination,
      distanceKm: greatCircleDistanceKm(origin, destination),
      crossesHighLatitude: maxAbsLatitude > 48.5,
      cruiseAltitudeFeet: cruiseAltitudeFeet,
      usesAircraftHorizon: useAircraftHorizon,
    );
  } finally {
    prayerTime.setTimeFormat(originalFormat);
  }
}

/// Narrows a bracketed crossing down to the second by bisection.
DateTime _refineCrossing({
  required int prayerIndex,
  required PrayerTime prayerTime,
  required DateTime lower,
  required DateTime upper,
  required GeoPoint Function(DateTime) positionAt,
  required double Function(DateTime) dipAt,
}) {
  var low = lower;
  var high = upper;

  // ~2 minutes down to under a second takes at most 8 halvings; 24 is a cheap
  // ceiling that also covers a caller passing a very coarse scan step.
  for (var iteration = 0; iteration < 24; iteration++) {
    if (high.difference(low).inSeconds <= 1) break;

    final midpoint = low.add(
      Duration(milliseconds: high.difference(low).inMilliseconds ~/ 2),
    );
    final instants = prayerInstantsUtc(
      prayerTime: prayerTime,
      instantUtc: midpoint,
      position: positionAt(midpoint),
      dipDegrees: dipAt(midpoint),
    );
    final prayerInstant = instants[prayerIndex];
    // Losing the sun angle mid-bisection means the bracket straddles a
    // discontinuity; the coarse upper bound is the best answer available.
    if (prayerInstant == null) return high;

    if (prayerInstant.isAfter(midpoint)) {
      low = midpoint;
    } else {
      high = midpoint;
    }
  }

  return high;
}

/// Direction of travel at [crossing], measured over a short arc so it reflects
/// the local course rather than the origin-to-destination average.
double _courseAt({
  required DateTime crossing,
  required DateTime departureUtc,
  required DateTime arrivalUtc,
  required GeoPoint Function(DateTime) positionAt,
}) {
  const probe = Duration(minutes: 5);
  var before = crossing.subtract(probe);
  var after = crossing.add(probe);
  if (before.isBefore(departureUtc)) before = departureUtc;
  if (after.isAfter(arrivalUtc)) after = arrivalUtc;
  if (!after.isAfter(before)) return 0;

  return initialBearingDegrees(positionAt(before), positionAt(after));
}

/// Prayer instants (UTC) for a fixed [position], for the solar day containing
/// [instantUtc]. Indices match [PrayerTime.getTimeNames] with Shia midnight
/// appended at [prayerIndexMidnight]; entries are null where the sun never
/// reaches the required angle.
///
/// The underlying calculator works in a wall-clock frame chosen by the caller.
/// Passing `longitude / 15` as the zone puts the results in mean solar time at
/// [position], where noon really is around 12:00 regardless of political time
/// zones. That keeps the returned values away from the midnight wrap that
/// makes a UTC-framed calculation discontinuous mid-ocean.
/// [dipDegrees] shifts every horizon-referenced angle, so passing the horizon
/// dip for the aircraft's altitude gives the times as seen from the cabin
/// rather than from the ground below. Zero reproduces the ground-level times.
List<DateTime?> prayerInstantsUtc({
  required PrayerTime prayerTime,
  required DateTime instantUtc,
  required GeoPoint position,
  double dipDegrees = 0,
}) {
  final calculator = dipDegrees <= 0
      ? prayerTime
      : HorizonAdjustedPrayerTime(prayerTime, dipDegrees);

  final solarOffsetHours = position.longitude / 15.0;
  final solarOffset = Duration(
    milliseconds: (solarOffsetHours * Duration.millisecondsPerHour).round(),
  );
  final solarNow = instantUtc.toUtc().add(solarOffset);
  final solarDate = DateTime.utc(solarNow.year, solarNow.month, solarNow.day);

  final raw = _solarHours(calculator, solarDate, position, solarOffsetHours);

  return [
    for (final value in raw) _solarHoursToUtc(value, solarDate, solarOffset),
    _midnightInstantUtc(
      prayerTime: calculator,
      solarNow: solarNow,
      position: position,
      solarOffsetHours: solarOffsetHours,
      solarOffset: solarOffset,
    ),
  ];
}

/// Shia midnight — the midpoint between sunset and the following true dawn,
/// and the end of the Isha window.
///
/// Anchored to solar *noon* rather than solar midnight. A night runs from
/// sunset through to the next dawn, so a midnight-anchored frame would split it
/// in half and leave the answer jumping a whole day as the aircraft crosses the
/// boundary. Breaking the frame at noon keeps each night intact.
DateTime? _midnightInstantUtc({
  required PrayerTime prayerTime,
  required DateTime solarNow,
  required GeoPoint position,
  required double solarOffsetHours,
  required Duration solarOffset,
}) {
  final nightAnchor = solarNow.subtract(const Duration(hours: 12));
  final eveningDate =
      DateTime.utc(nightAnchor.year, nightAnchor.month, nightAnchor.day);
  final morningDate = eveningDate.add(const Duration(days: 1));

  final sunsetHours = double.tryParse(
    _solarHours(prayerTime, eveningDate, position, solarOffsetHours)[
        prayerIndexSunset],
  );
  final fajrHours = double.tryParse(
    _solarHours(prayerTime, morningDate, position, solarOffsetHours)[
        prayerIndexFajr],
  );

  if (sunsetHours == null ||
      fajrHours == null ||
      sunsetHours.isNaN ||
      fajrHours.isNaN) {
    return null;
  }

  // Fajr belongs to the following day, so it sits past 24h on the evening
  // date's clock.
  final midnightHours = (sunsetHours + fajrHours + 24) / 2;
  return _solarHoursToUtc('$midnightHours', eveningDate, solarOffset);
}

List<String> _solarHours(
  PrayerTime prayerTime,
  DateTime solarDate,
  GeoPoint position,
  double solarOffsetHours,
) {
  final originalFormat = prayerTime.getTimeFormat();
  prayerTime.setTimeFormat(prayerTime.getFloating());
  try {
    return prayerTime.getPrayerTimes(
      solarDate,
      position.latitude,
      position.longitude,
      solarOffsetHours,
    );
  } finally {
    prayerTime.setTimeFormat(originalFormat);
  }
}

DateTime? _solarHoursToUtc(
  String rawHours,
  DateTime solarDate,
  Duration solarOffset,
) {
  final hours = double.tryParse(rawHours);
  if (hours == null || hours.isNaN || hours.isInfinite) return null;

  return solarDate
      .add(Duration(
        milliseconds: (hours * Duration.millisecondsPerHour).round(),
      ))
      .subtract(solarOffset);
}
