/// Which north a heading is measured from.
///
/// Worth modelling rather than assuming, because the platforms disagree: Core
/// Location on iOS hands back a heading already corrected for declination,
/// while Android's rotation vector points at magnetic north and leaves the
/// correction to us. Losing track of which one a number is produces an error
/// of exactly the local declination — invisible in Makkah, badly wrong in
/// California.
enum NorthReference {
  /// Measured from magnetic north; needs the local declination added.
  magnetic,

  /// Measured from true (geographic) north; usable as-is.
  geographic,
}

/// One heading sample from the device's compass.
class CompassReading {
  const CompassReading({
    required this.headingDegrees,
    required this.reference,
    this.accuracyDegrees,
  });

  /// Where the top of the device points, in degrees clockwise from
  /// [reference] north.
  final double headingDegrees;

  final NorthReference reference;

  /// Plus-or-minus error the platform claims, in degrees. Null when it will
  /// not say — which is most Android devices, since the sensor framework only
  /// reports a coarse three-level accuracy.
  final double? accuracyDegrees;
}
