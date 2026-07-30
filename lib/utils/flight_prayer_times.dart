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

  bool get hasInstant => instantUtc != null;

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
    this.isValid = true,
  });

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
FlightPrayerPlan computeFlightPrayerPlan({
  required PrayerTime prayerTime,
  required GeoPoint origin,
  required GeoPoint destination,
  required DateTime departureUtc,
  required DateTime arrivalUtc,
  Duration scanStep = const Duration(minutes: 2),
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
        isValid: false,
      );
    }

    GeoPoint positionAt(DateTime instant) {
      final fraction =
          instant.difference(departureUtc).inMilliseconds / durationMs;
      return interpolateGreatCircle(origin, destination, fraction);
    }

    /// g(t) in milliseconds for every prayer index, or null where the sun never
    /// reaches that prayer's angle at this position.
    List<double?> offsetsAt(DateTime instant) {
      final instants = prayerInstantsUtc(
        prayerTime: prayerTime,
        instantUtc: instant,
        position: positionAt(instant),
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
          ));
        }
      }

      previousInstant = instant;
      previousOffsets = offsets;
      if (clampedMs >= durationMs) break;
    }

    final events = <FlightPrayerEvent>[];
    for (final index in flightPrayerIndices) {
      final prayerCrossings = crossings[index]!;
      if (prayerCrossings.isNotEmpty) {
        for (final crossing in prayerCrossings) {
          final position = positionAt(crossing);
          events.add(FlightPrayerEvent(
            prayerIndex: index,
            name: names[index],
            status: FlightPrayerStatus.duringFlight,
            instantUtc: crossing,
            position: position,
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
List<DateTime?> prayerInstantsUtc({
  required PrayerTime prayerTime,
  required DateTime instantUtc,
  required GeoPoint position,
}) {
  final solarOffsetHours = position.longitude / 15.0;
  final solarOffset = Duration(
    milliseconds: (solarOffsetHours * Duration.millisecondsPerHour).round(),
  );
  final solarNow = instantUtc.toUtc().add(solarOffset);
  final solarDate = DateTime.utc(solarNow.year, solarNow.month, solarNow.day);

  final raw = _solarHours(prayerTime, solarDate, position, solarOffsetHours);

  return [
    for (final value in raw) _solarHoursToUtc(value, solarDate, solarOffset),
    _midnightInstantUtc(
      prayerTime: prayerTime,
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
